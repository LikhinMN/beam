import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'protocol.dart';
import 'checksum.dart';
import 'package:beam/core/settings_store.dart';

class ChunkSizeTuner {
  int chunkSize = 256 * 1024;
  int _chunkCount = 0;
  final _sw = Stopwatch();
  bool _locked = false;

  void onChunkStarted() {
    if (!_locked && _chunkCount == 0) {
      _sw.start();
    }
  }

  void onChunkCompleted() {
    if (_locked) return;
    _chunkCount++;
    if (_chunkCount == 10) {
      _sw.stop();
      final elapsedSec = _sw.elapsedMilliseconds / 1000.0;
      if (elapsedSec > 0) {
        final bytesSent = 10 * chunkSize;
        final throughput = bytesSent / elapsedSec; // bytes per sec

        if (throughput > 80 * 1024 * 1024) {
          chunkSize = 512 * 1024;
        } else if (throughput < 20 * 1024 * 1024) {
          chunkSize = 64 * 1024;
        }
      }
      _locked = true;
    }
  }
}

class TransferClient {
  final StreamController<TransferEvent> _eventController =
      StreamController<TransferEvent>.broadcast();

  /// Exposes a stream of TransferEvents.
  Stream<TransferEvent> get events => _eventController.stream;

  void dispose() {
    _eventController.close();
  }

  Future<void> sendFiles(String host, int port, List<File> files) async {
    Socket? rawSocket;
    BeamSocket? beamSocket;
    try {
      rawSocket = await Socket.connect(host, port);
      beamSocket = BeamSocket(rawSocket);

      final connectHeader = BinaryHeader(
        magic: BinaryHeader.magicNumber,
        op: BinaryHeader.opConnect,
        fileSize: 0,
        fileName: '',
        deviceId: SettingsStore.instance.deviceId,
        deviceName: SettingsStore.instance.deviceName,
      );
      rawSocket.add(connectHeader.encode());
      await rawSocket.flush();

      final response = await beamSocket.readHeader(timeout: const Duration(seconds: 10));
      if (response.op != BinaryHeader.opAck) {
        throw Exception("Session rejected by server");
      }
      
      // Close the connect socket, each file transfer will establish its own connection
      rawSocket.destroy();
      rawSocket = null;

      for (final file in files) {
        await sendFile(host, port, file);
      }
    } finally {
      rawSocket?.destroy();
    }
  }

  /// Sends a text message to the specified host and port.
  Future<void> sendText(String host, int port, String text) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port);
      final textBytes = utf8.encode(text);
      final header = BinaryHeader(
        magic: BinaryHeader.magicNumber,
        op: BinaryHeader.opText,
        fileSize: textBytes.length,
        fileName: '',
      );
      socket.add(header.encode());
      socket.add(textBytes);
      await socket.flush();
    } finally {
      socket?.destroy();
    }
  }

  /// Sends a file to the specified host and port.
  Future<void> sendFile(
    String host,
    int port,
    File file, {
    BeamSocket? existingSocket,
  }) async {
    BeamSocket? beamSocket = existingSocket;
    final fileName = file.path.split(Platform.pathSeparator).last;
    try {
      final fileSize = await file.length();

      _eventController.add(
        TransferEvent(status: TransferEventType.started, totalBytes: fileSize, fileName: fileName, filePath: file.path),
      );

      // 1. Compute checksum first
      final checksum = await computeChecksum(file);
      final checksumBytes = utf8.encode(checksum);

      // 2. Connect to the server with retries if no existing socket
      if (beamSocket == null) {
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            if (attempt > 1) {
              _eventController.add(
                TransferEvent(
                  status: TransferEventType.retrying,
                  attempt: attempt,
                  maxAttempts: 3,
                  totalBytes: fileSize,
                  fileName: fileName,
                  filePath: file.path,
                ),
              );
              await Future.delayed(const Duration(seconds: 2));
            }
            final socket = await Socket.connect(host, port);
            beamSocket = BeamSocket(socket);
            break; // Connected
          } catch (e) {
            if (attempt == 3) {
              throw Exception('Connection failed after 3 attempts');
            }
          }
        }
      }

      if (beamSocket == null) throw Exception('Socket is null');

      // 3. Send header
      final header = BinaryHeader(
        magic: BinaryHeader.magicNumber,
        op: BinaryHeader.opSend,
        fileSize: fileSize,
        fileName: fileName,
      );
      beamSocket.socket.add(header.encode());

      // 4. Stream file using ChunkSizeTuner
      final tuner = ChunkSizeTuner();
      int bytesSent = 0;
      final raf = await file.open(mode: FileMode.read);

      try {
        DateTime lastProgressTime = DateTime.now();
        while (bytesSent < fileSize) {
          final currentChunkSize = tuner.chunkSize;
          final bytesToRead = (fileSize - bytesSent < currentChunkSize)
              ? fileSize - bytesSent
              : currentChunkSize;

          tuner.onChunkStarted();
          final chunk = await raf.read(bytesToRead);
          beamSocket.socket.add(chunk);
          await beamSocket.socket
              .flush(); // Ensure chunks are sent continuously
          tuner.onChunkCompleted();

          bytesSent += chunk.length;
          final now = DateTime.now();
          if (now.difference(lastProgressTime).inMilliseconds >= 50) {
            lastProgressTime = now;
            _eventController.add(
              TransferEvent(
                status: TransferEventType.progress,
                bytesTransferred: bytesSent,
                totalBytes: fileSize,
                fileName: fileName,
                filePath: file.path,
              ),
            );
          }
        }
      } finally {
        await raf.close();
      }

      // 5. Send checksum as final 64-byte block
      beamSocket.socket.add(checksumBytes);
      await beamSocket.socket.flush();

      // 6. Wait for ACK or REJECT
      final responseHeader = await beamSocket.readHeader(
        timeout: const Duration(seconds: 30),
      );

      if (responseHeader.op == BinaryHeader.opAck) {
        _eventController.add(
          TransferEvent(
            status: TransferEventType.completed,
            bytesTransferred: fileSize,
            totalBytes: fileSize,
            fileName: fileName,
            filePath: file.path,
          ),
        );
      } else if (responseHeader.op == BinaryHeader.opReject) {
        throw Exception('Server rejected the file (checksum mismatch)');
      } else {
        throw Exception('Unknown server response op: ${responseHeader.op}');
      }
    } catch (e) {
      _eventController.add(
        TransferEvent(status: TransferEventType.failed, error: e.toString(), fileName: fileName, filePath: file.path),
      );
    } finally {
      if (existingSocket == null) {
        beamSocket?.socket.destroy();
      }
    }
  }
}
