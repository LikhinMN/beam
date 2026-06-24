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
import 'package:beam/ui/state/actions.dart' as actions;
import 'package:beam/core/peer_state.dart';
import 'package:flutter/foundation.dart';
import 'package:beam/android/storage_helper.dart' as android_storage;
import 'package:beam/linux/storage_helper.dart' as linux_storage;

class TransferServer {
  final StreamController<TransferEvent> _eventController = StreamController<TransferEvent>.broadcast();
  ServerSocket? _serverSocket;
  bool _isRunning = false;
  final List<Socket> _activeSockets = [];

  /// Exposes a stream of TransferEvents.
  Stream<TransferEvent> get events => _eventController.stream;

  /// Binds the TCP server on the given port (default 9001).
  Future<void> start({int port = 9001}) async {
    _isRunning = true;
    _serverSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    print('[Resource] RESOURCE_OPEN ServerSocket on port $port');
    
    _serverSocket!.listen((Socket client) {
      print('[Resource] RESOURCE_OPEN Socket connection from ${client.remoteAddress.address}');
      if (!_isRunning) {
        client.destroy();
        return;
      }
      _activeSockets.add(client);
      _handleConnection(BeamSocket(client));
    }, onError: (error) {
      _eventController.add(TransferEvent(
        status: TransferEventType.failed,
        error: error.toString(),
      ));
    });
  }

  /// Stops the TCP server.
  Future<void> stop() async {
    _isRunning = false;
    print('[Resource] RESOURCE_CLOSE ServerSocket');
    await _serverSocket?.close();
    _serverSocket = null;
    for (final socket in _activeSockets) {
      print('[Resource] RESOURCE_CLOSE Socket (on stop)');
      await socket.close();
    }
    _activeSockets.clear();
  }

  /// Spawns a new Isolate to handle the incoming connection.
  Future<void> _handleConnection(BeamSocket beamSocket) async {
    final client = beamSocket.socket;
    final ip = client.remoteAddress.address;
    final port = client.remotePort;
    try {
      final header = await beamSocket.readHeader();
      print('[Diagnostics] HEADER_RECEIVED op=${header.op} ip=$ip port=$port');

      if (header.magic != BinaryHeader.magicNumber) {
        print('[Resource] RESOURCE_CLOSE Socket (invalid magic)');
        client.destroy();
        _activeSockets.remove(client);
        return;
      }

      switch (header.op) {
        case BinaryHeader.opPair:
          // Trigger pairing flow — do NOT close socket
          final result = await BeamPairing().respondToPairing(beamSocket, header.deviceName.isNotEmpty ? header.deviceName : header.fileName);
          if (result == PairingResult.success) {
            // After pairing succeeds, read the next header on same socket
            // The client will send OP_CONNECT immediately after PAIR_OK
            await _handleConnection(beamSocket);
          } else {
            print('[Resource] RESOURCE_CLOSE Socket (pairing failed)');
            client.destroy();
            _activeSockets.remove(client);
          }
          break;

        case BinaryHeader.opConnect:
          // Session establishment — check if sender is trusted
          final senderIp = ip;
          final senderName = header.deviceName;
          if (await BeamPairing().isTrusted(senderIp)) {
            // Send OP_ACK to confirm session
            client.add(BinaryHeader(magic: BinaryHeader.magicNumber, op: BinaryHeader.opAck, fileSize: 0, fileName: '').encode());
            // Update peer state to CONNECTED in the store
            if (header.deviceId.isNotEmpty) {
              actions.setPeerState(header.deviceId, PeerState.connected);
            }
            // Keep socket open — wait for next header (OP_SEND)
            await _handleConnection(beamSocket);
          } else {
            // Not trusted — send OP_PAIR to initiate pairing
            client.add(BinaryHeader(magic: BinaryHeader.magicNumber, op: BinaryHeader.opPair, fileSize: 0, fileName: '').encode());
            await _handleConnection(beamSocket);
          }
          break;

        case BinaryHeader.opSend:
          // Existing file receive logic
          await _handleFileReceive(beamSocket, header, ip, port);
          break;

        default:
          // Unknown op — log and close cleanly
          debugPrint('[Server] Unknown op: ${header.op} — closing socket');
          client.destroy();
          _activeSockets.remove(client);
          break;
      }
    } catch (e) {
      print('[Resource] RESOURCE_CLOSE Socket (exception: $e)');
      print('[Diagnostics] SOCKET_CLOSED ip=$ip port=$port');
      client.destroy();
      _activeSockets.remove(client);
    }
  }

  Future<void> _handleFileReceive(BeamSocket beamSocket, BinaryHeader header, String ip, int port) async {
    final client = beamSocket.socket;
    Directory directory;
    if (Platform.isAndroid) {
      directory = await android_storage.StorageHelper.getDownloadDirectory();
    } else if (Platform.isLinux) {
      directory = await linux_storage.StorageHelper.getDefaultDownloadDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    final saveDir = directory.path;
    ReceivePort? mainReceivePort;

    try {
      final isTrusted = await BeamPairing().isTrusted(ip);
      if (!isTrusted) {
        // If they didn't send OP_PAIR but we require trust, try pairing flow
        final result = await BeamPairing().respondToPairing(beamSocket, header.deviceName.isNotEmpty ? header.deviceName : header.fileName);
        if (result != PairingResult.success) {
          _eventController.add(TransferEvent(
            status: TransferEventType.failed,
            error: 'Device not trusted and pairing failed.',
            fileName: header.fileName,
            senderIp: ip,
          ));
          print('[Resource] RESOURCE_CLOSE Socket (trust failed)');
          client.destroy();
          _activeSockets.remove(client);
          return;
        }
      }

      print('[Resource] RESOURCE_OPEN ReceivePort (main)');
      mainReceivePort = ReceivePort();
      await Isolate.spawn(
        _isolateWorker, 
        _IsolateArgs(mainReceivePort.sendPort, saveDir, ip),
      );

      final isolateSendPortCompleter = Completer<SendPort>();

      mainReceivePort.listen((message) {
        if (message is SendPort) {
          isolateSendPortCompleter.complete(message);
        } else if (message is TransferEvent) {
          _eventController.add(message);
          if (message.status == TransferEventType.started) {
            print('[Diagnostics] TRANSFER_STARTED id=${header.fileName} ip=$ip port=$port');
          } else if (message.status == TransferEventType.completed) {
            print('[Diagnostics] TRANSFER_COMPLETED id=${header.fileName} ip=$ip port=$port');
          }
        } else if (message is Map && message['action'] == 'send') {
          client.add(message['data'] as Uint8List);
        } else if (message is Map && message['action'] == 'close') {
          print('[Resource] RESOURCE_CLOSE Socket (isolate request)');
          print('[Diagnostics] SOCKET_CLOSED ip=$ip port=$port');
          client.destroy();
          _activeSockets.remove(client);
          print('[Resource] RESOURCE_CLOSE ReceivePort (main)');
          mainReceivePort?.close();
          mainReceivePort = null;
        }
      });

      final isolateSendPort = await isolateSendPortCompleter.future;

      // Send the parsed OP_SEND header to the isolate
      isolateSendPort.send(header.encode());

      // Stream remaining data
      await for (final data in beamSocket.consumeStream()) {
        isolateSendPort.send(data);
      }
      isolateSendPort.send(null); // EOF
    } catch (e) {
      print('[Resource] RESOURCE_CLOSE Socket (exception: $e)');
      print('[Diagnostics] SOCKET_CLOSED ip=$ip port=$port');
      client.destroy();
      _activeSockets.remove(client);
    } finally {
      if (mainReceivePort != null) {
        print('[Resource] RESOURCE_CLOSE ReceivePort (main finally)');
        mainReceivePort?.close();
      }
    }
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

  Future<void> cleanup() async {
    if (hasPartialFile) {
      print('[Resource] RESOURCE_CLOSE fileSink');
      await fileSink.close();
    }
    print('[Resource] RESOURCE_CLOSE ReceivePort (isolate)');
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
        if (buffer.length >= BinaryHeader.headerSize) {
          final allData = buffer.takeBytes();
          final headerData = allData.sublist(0, BinaryHeader.headerSize);
          header = BinaryHeader.decode(Uint8List.fromList(headerData));
          isHeaderReceived = true;

          if (header.magic != BinaryHeader.magicNumber || header.op != BinaryHeader.opSend) {
            throw FormatException('Invalid header magic or operation');
          }

          final partialPath = p.join(args.saveDir, '${header.fileName}.partial');
          partialFile = File(partialPath);
          print('[Resource] RESOURCE_OPEN fileSink: $partialPath');
          fileSink = partialFile.openWrite();
          hasPartialFile = true;

          mainSendPort.send(TransferEvent(
            status: TransferEventType.started,
            totalBytes: header.fileSize,
            fileName: header.fileName,
            senderIp: args.senderIp,
          ));

          // Put remaining bytes back into buffer
          final remaining = allData.sublist(BinaryHeader.headerSize);
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
          
          print('[Resource] RESOURCE_CLOSE fileSink (success)');
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
    await cleanup();
    mainSendPort.send({'action': 'close'});
  }
}
