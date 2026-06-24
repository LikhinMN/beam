import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'protocol.dart';
import 'checksum.dart';
import 'pairing.dart';

class TransferServer {
  final StreamController<TransferEvent> _eventController = StreamController<TransferEvent>.broadcast();
  ServerSocket? _serverSocket;

  /// Exposes a stream of TransferEvents.
  Stream<TransferEvent> get events => _eventController.stream;

  /// Binds the TCP server on the given port (default 9001).
  Future<void> start({int port = 9001}) async {
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    
    _serverSocket!.listen((Socket client) {
      _handleConnection(client);
    }, onError: (error) {
      _eventController.add(TransferEvent(
        status: TransferEventType.failed,
        error: error.toString(),
      ));
    });
  }

  /// Stops the TCP server.
  Future<void> stop() async {
    await _serverSocket?.close();
    await _eventController.close();
  }

  /// Spawns a new Isolate to handle the incoming connection.
  void _handleConnection(Socket client) async {
    final ip = client.remoteAddress.address;
    final buffer = BytesBuilder();
    late StreamSubscription<Uint8List> sub;
    bool headerProcessed = false;
    SendPort? isolateSendPort;
    
    final directory = await getApplicationDocumentsDirectory();
    final saveDir = directory.path;

    sub = client.listen(
      (Uint8List data) async {
        if (headerProcessed) {
          isolateSendPort?.send(data);
          return;
        }

        buffer.add(data);
        if (buffer.length >= 269 && !headerProcessed) {
          headerProcessed = true;
          sub.pause();

          final allData = buffer.takeBytes();
          final headerData = allData.sublist(0, 269);
          BinaryHeader header;
          try {
            header = BinaryHeader.decode(Uint8List.fromList(headerData));
          } catch (e) {
            client.destroy();
            return;
          }

          if (header.magic != BinaryHeader.magicNumber) {
            client.destroy();
            return;
          }

          if (header.op == BinaryHeader.opPair) {
            await BeamPairing().respondToPairing(client, header.fileName);
            client.destroy();
            return;
          }

          if (header.op == BinaryHeader.opSend) {
            final isTrusted = await BeamPairing().isTrusted(ip);
            if (!isTrusted) {
              _eventController.add(TransferEvent(
                status: TransferEventType.failed,
                error: 'Device not trusted. Please pair first.',
                fileName: header.fileName,
                senderIp: ip,
              ));
              client.destroy();
              return;
            }

            final receivePort = ReceivePort();
            await Isolate.spawn(
              _isolateWorker, 
              _IsolateArgs(receivePort.sendPort, saveDir, ip),
            );

            final streamIterator = StreamIterator(receivePort);
            await streamIterator.moveNext();
            isolateSendPort = streamIterator.current as SendPort;

            receivePort.listen((message) {
              if (message is TransferEvent) {
                _eventController.add(message);
              } else if (message is Map && message['action'] == 'send') {
                client.add(message['data']);
              } else if (message is Map && message['action'] == 'close') {
                client.destroy();
                receivePort.close();
              }
            });

            isolateSendPort?.send(allData);
            sub.resume();
          } else {
            client.destroy();
          }
        }
      },
      onDone: () {
        if (headerProcessed) isolateSendPort?.send(null); // Signal EOF
      },
      onError: (error) {
        if (headerProcessed) isolateSendPort?.send(error.toString()); // Signal error
      },
    );
  }
}

class _IsolateArgs {
  final SendPort sendPort;
  final String saveDir;
  final String senderIp;

  _IsolateArgs(this.sendPort, this.saveDir, this.senderIp);
}

/// The worker function for the isolate.
void _isolateWorker(_IsolateArgs args) async {
  final receivePort = ReceivePort();
  args.sendPort.send(receivePort.sendPort);

  final mainSendPort = args.sendPort;

  bool isHeaderReceived = false;
  late BinaryHeader header;
  late File partialFile;
  late IOSink fileSink;
  bool hasPartialFile = false;
  int bytesReceived = 0;
  List<int> checksumBuffer = [];

  final buffer = BytesBuilder();

  void cleanup() {
    if (hasPartialFile) {
      fileSink.close();
    }
    receivePort.close();
  }

  try {
    await for (final message in receivePort) {
      if (message == null) {
        // EOF received
        if (isHeaderReceived && bytesReceived < header.fileSize) {
          throw Exception('Connection closed prematurely');
        }
        break; // connection closed normally
      }

      if (message is String) {
        throw Exception(message);
      }

      final data = message as Uint8List;
      buffer.add(data);

      if (!isHeaderReceived) {
        if (buffer.length >= 269) {
          final allData = buffer.takeBytes();
          final headerData = allData.sublist(0, 269);
          header = BinaryHeader.decode(Uint8List.fromList(headerData));
          isHeaderReceived = true;

          if (header.magic != BinaryHeader.magicNumber || header.op != BinaryHeader.opSend) {
            throw FormatException('Invalid header magic or operation');
          }

          final partialPath = p.join(args.saveDir, '${header.fileName}.partial');
          partialFile = File(partialPath);
          fileSink = partialFile.openWrite();
          hasPartialFile = true;

          mainSendPort.send(TransferEvent(
            status: TransferEventType.started,
            totalBytes: header.fileSize,
            fileName: header.fileName,
            senderIp: args.senderIp,
          ));

          // Put remaining bytes back into buffer
          final remaining = allData.sublist(269);
          if (remaining.isNotEmpty) {
             buffer.add(remaining);
          }
        }
      } 
      
      if (isHeaderReceived && buffer.isNotEmpty) {
        final currentData = buffer.takeBytes();
        int neededForFile = header.fileSize - bytesReceived;
        
        if (neededForFile > 0) {
          if (currentData.length <= neededForFile) {
            fileSink.add(currentData);
            bytesReceived += currentData.length;
          } else {
            // We have received more than needed for the file (the extra is checksum)
            final fileData = currentData.sublist(0, neededForFile);
            fileSink.add(fileData);
            bytesReceived += fileData.length;

            final checksumData = currentData.sublist(neededForFile);
            checksumBuffer.addAll(checksumData);
          }
          mainSendPort.send(TransferEvent(
            status: TransferEventType.progress,
            bytesTransferred: bytesReceived,
            totalBytes: header.fileSize,
            fileName: header.fileName,
            senderIp: args.senderIp,
          ));
        } else {
          // File data is already complete; this is checksum data
          checksumBuffer.addAll(currentData);
        }

        // Check if we have received the full checksum (64 bytes) after file completes
        if (bytesReceived == header.fileSize && checksumBuffer.length >= 64) {
          final receivedChecksum = utf8.decode(checksumBuffer.sublist(0, 64));
          
          await fileSink.close();
          hasPartialFile = false;

          final computedChecksum = await computeChecksum(partialFile);
          if (computedChecksum == receivedChecksum) {
            final finalPath = p.join(args.saveDir, header.fileName);
            await partialFile.rename(finalPath);
            
            // Send ACK
            final ackHeader = BinaryHeader(
              magic: BinaryHeader.magicNumber,
              op: BinaryHeader.opAck,
              fileSize: 0,
              fileName: '',
            );
            mainSendPort.send({'action': 'send', 'data': ackHeader.encode()});

            mainSendPort.send(TransferEvent(
              status: TransferEventType.completed,
              bytesTransferred: bytesReceived,
              totalBytes: header.fileSize,
              fileName: header.fileName,
              filePath: finalPath,
              senderIp: args.senderIp,
            ));
          } else {
            // Checksum mismatch
            await partialFile.delete();
            
            // Send REJECT
            final rejectHeader = BinaryHeader(
              magic: BinaryHeader.magicNumber,
              op: BinaryHeader.opReject,
              fileSize: 0,
              fileName: '',
            );
            mainSendPort.send({'action': 'send', 'data': rejectHeader.encode()});

            mainSendPort.send(TransferEvent(
              status: TransferEventType.failed,
              error: 'Checksum mismatch',
              fileName: header.fileName,
              senderIp: args.senderIp,
            ));
          }
          break; // Done with this connection
        }
      }
    }
  } catch (e) {
    if (hasPartialFile && await partialFile.exists()) {
       await partialFile.delete();
    }
    mainSendPort.send(TransferEvent(
      status: TransferEventType.failed,
      error: e.toString(),
    ));
  } finally {
    cleanup();
    mainSendPort.send({'action': 'close'});
  }
}
