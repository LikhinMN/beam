import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';

import 'protocol.dart';
import 'checksum.dart';

class TransferClient {
  final StreamController<TransferEvent> _eventController = StreamController<TransferEvent>.broadcast();

  /// Exposes a stream of TransferEvents.
  Stream<TransferEvent> get events => _eventController.stream;

  /// Sends a file to the specified host and port.
  Future<void> sendFile(String host, int port, File file) async {
    Socket? socket;
    try {
      final fileSize = await file.length();
      
      _eventController.add(TransferEvent(
        status: TransferEventType.started,
        totalBytes: fileSize,
      ));

      // 1. Compute checksum first
      final checksum = await computeChecksum(file);
      final checksumBytes = utf8.encode(checksum);

      // 2. Connect to the server
      socket = await Socket.connect(host, port);

      // 3. Send header
      final fileName = file.path.split(Platform.pathSeparator).last;
      final header = BinaryHeader(
        magic: BinaryHeader.magicNumber,
        op: BinaryHeader.opSend,
        fileSize: fileSize,
        fileName: fileName,
      );
      socket.add(header.encode());

      // 4. Stream file in 256KB chunks
      final chunkSize = 256 * 1024;
      int bytesSent = 0;
      final raf = await file.open(mode: FileMode.read);
      
      try {
        while (bytesSent < fileSize) {
          final bytesToRead = (fileSize - bytesSent < chunkSize) ? fileSize - bytesSent : chunkSize;
          final chunk = await raf.read(bytesToRead);
          socket.add(chunk);
          await socket.flush(); // Ensure chunks are sent continuously
          
          bytesSent += chunk.length;
          _eventController.add(TransferEvent(
            status: TransferEventType.progress,
            bytesTransferred: bytesSent,
            totalBytes: fileSize,
          ));
        }
      } finally {
        await raf.close();
      }

      // 5. Send checksum as final 64-byte block
      socket.add(checksumBytes);
      await socket.flush();

      // 6. Wait for ACK or REJECT
      final responseBuffer = BytesBuilder();
      await for (final data in socket) {
        responseBuffer.add(data);
        if (responseBuffer.length >= 269) {
          break;
        }
      }

      if (responseBuffer.length >= 269) {
        final responseData = responseBuffer.takeBytes().sublist(0, 269);
        final responseHeader = BinaryHeader.decode(Uint8List.fromList(responseData));
        
        if (responseHeader.op == BinaryHeader.opAck) {
          _eventController.add(TransferEvent(
            status: TransferEventType.completed,
            bytesTransferred: fileSize,
            totalBytes: fileSize,
          ));
        } else if (responseHeader.op == BinaryHeader.opReject) {
          throw Exception('Server rejected the file (checksum mismatch)');
        } else {
          throw Exception('Unknown server response op: ${responseHeader.op}');
        }
      } else {
         throw Exception('Connection closed before response received');
      }

    } catch (e) {
      _eventController.add(TransferEvent(
        status: TransferEventType.failed,
        error: e.toString(),
      ));
    } finally {
      socket?.destroy();
    }
  }
}
