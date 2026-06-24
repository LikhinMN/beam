import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

/// Represents the type of a transfer event.
enum TransferEventType {
  started,
  progress,
  completed,
  failed,
  retrying,
}

class TransferEvent {
  final TransferEventType status;
  final int bytesTransferred;
  final int totalBytes;
  final String? error;
  final String? fileName;
  final String? filePath;
  final String? senderIp;
  final int attempt;
  final int maxAttempts;

  TransferEvent({
    required this.status,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
    this.error,
    this.fileName,
    this.filePath,
    this.senderIp,
    this.attempt = 0,
    this.maxAttempts = 0,
  });
}

/// BinaryHeader used for TCP file transfers.
class BinaryHeader {
  static const int headerSize = 397;
  static const int magicNumber = 0x4245414D; // 0xBEAM
  static const int opSend = 0x01;
  static const int opAck = 0x02;
  static const int opReject = 0x03;
  static const int opPair = 0x04;
  static const int opPairOk = 0x05;
  static const int opPairReject = 0x06;
  static const int opPin = 0x07;
  static const int opConnect = 0x08;

  final int magic;
  final int op;
  final int fileSize;
  final String fileName;
  final String deviceId;
  final String deviceName;

  BinaryHeader({
    required this.magic,
    required this.op,
    required this.fileSize,
    required this.fileName,
    this.deviceId = '',
    this.deviceName = '',
  });

  /// Encodes the header to a Uint8List of exactly 397 bytes.
  Uint8List encode() {
    final buffer = Uint8List(headerSize);
    final byteData = ByteData.view(buffer.buffer);
    
    // magic (Uint32)
    byteData.setUint32(0, magic, Endian.big);
    // op (Uint8)
    byteData.setUint8(4, op);
    // fileSize (Uint64)
    byteData.setUint64(5, fileSize, Endian.big);

    // fileName (256 bytes UTF-8 null-padded)
    final nameBytes = utf8.encode(fileName);
    final maxLen = nameBytes.length < 256 ? nameBytes.length : 256;
    buffer.setRange(13, 13 + maxLen, nameBytes.sublist(0, maxLen));

    // deviceId (64 bytes UTF-8 null-padded)
    final deviceIdBytes = utf8.encode(deviceId);
    final maxDeviceIdLen = deviceIdBytes.length < 64 ? deviceIdBytes.length : 64;
    buffer.setRange(269, 269 + maxDeviceIdLen, deviceIdBytes.sublist(0, maxDeviceIdLen));

    // deviceName (64 bytes UTF-8 null-padded)
    final deviceNameBytes = utf8.encode(deviceName);
    final maxDeviceNameLen = deviceNameBytes.length < 64 ? deviceNameBytes.length : 64;
    buffer.setRange(333, 333 + maxDeviceNameLen, deviceNameBytes.sublist(0, maxDeviceNameLen));

    return buffer;
  }

  /// Decodes a Uint8List into a BinaryHeader.
  /// Expects the list to be at least 397 bytes long.
  static BinaryHeader decode(Uint8List data) {
    if (data.length < headerSize) {
      throw FormatException('Invalid header length: expected $headerSize bytes, got ${data.length}');
    }

    final byteData = ByteData.view(data.buffer, data.offsetInBytes, data.lengthInBytes);
    final magic = byteData.getUint32(0, Endian.big);
    final op = byteData.getUint8(4);
    final fileSize = byteData.getUint64(5, Endian.big);

    int nameLength = 0;
    for (int i = 0; i < 256; i++) {
      if (data[13 + i] == 0) {
        break;
      }
      nameLength++;
    }
    final fileName = utf8.decode(data.sublist(13, 13 + nameLength));

    int deviceIdLength = 0;
    for (int i = 0; i < 64; i++) {
      if (data[269 + i] == 0) break;
      deviceIdLength++;
    }
    final deviceId = utf8.decode(data.sublist(269, 269 + deviceIdLength));

    int deviceNameLength = 0;
    for (int i = 0; i < 64; i++) {
      if (data[333 + i] == 0) break;
      deviceNameLength++;
    }
    final deviceName = utf8.decode(data.sublist(333, 333 + deviceNameLength));

    return BinaryHeader(
      magic: magic,
      op: op,
      fileSize: fileSize,
      fileName: fileName,
      deviceId: deviceId,
      deviceName: deviceName,
    );
  }
}

/// A wrapper around Socket that uses StreamIterator to read headers and consume the stream safely
/// without triggering "Stream has already been listened to" exceptions.
class BeamSocket {
  final Socket socket;
  final StreamIterator<Uint8List> iterator;
  final BytesBuilder _buffer = BytesBuilder();

  BeamSocket(this.socket) : iterator = StreamIterator<Uint8List>(socket) {
    print('[Diagnostics] SOCKET_STREAM_OWNER BeamSocket attached to socket ${socket.remotePort}');
  }

  Future<BinaryHeader> readHeader({Duration? timeout}) async {
    while (_buffer.length < BinaryHeader.headerSize) {
      bool hasNext;
      if (timeout != null) {
        hasNext = await iterator.moveNext().timeout(timeout);
      } else {
        hasNext = await iterator.moveNext();
      }
      if (!hasNext) {
        throw Exception('Socket closed before full header received');
      }
      _buffer.add(iterator.current);
    }
    
    final allData = _buffer.takeBytes();
    final headerData = allData.sublist(0, BinaryHeader.headerSize);
    final header = BinaryHeader.decode(Uint8List.fromList(headerData));
    
    final remaining = allData.sublist(BinaryHeader.headerSize);
    if (remaining.isNotEmpty) {
      _buffer.add(remaining);
    }
    
    return header;
  }

  /// Consumes the rest of the stream, yielding buffered bytes first.
  Stream<Uint8List> consumeStream() async* {
    if (_buffer.isNotEmpty) {
      yield _buffer.takeBytes();
    }
    while (await iterator.moveNext()) {
      yield iterator.current;
    }
  }
}
