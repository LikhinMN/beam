import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beam/core/protocol.dart';

enum PairingEventType { pinGenerated, waitingForPin, pairingSuccess, pairingFailed, pairingTimeout }

class PairingEvent {
  final PairingEventType type;
  final String? pin;
  final String? message;
  PairingEvent(this.type, {this.pin, this.message});
}

enum PairingResult { success, rejected, timeout, error }

/// Handles PIN-based pairing and trust management.
class BeamPairing {
  static final BeamPairing _instance = BeamPairing._internal();
  factory BeamPairing() => _instance;
  BeamPairing._internal();

  static const String _storeKey = 'beam_trusted_devices';
  
  final _eventsController = StreamController<PairingEvent>.broadcast();
  Stream<PairingEvent> get pairingEvents => _eventsController.stream;

  Completer<String>? _pinCompleter;

  /// Generates a random 6-digit PIN.
  String generatePIN() {
    final random = Random.secure();
    return (random.nextInt(900000) + 100000).toString(); // 100000 to 999999
  }

  /// Called by the UI on the sender side to submit the user-entered PIN.
  void submitPin(String pin) {
    if (_pinCompleter != null && !_pinCompleter!.isCompleted) {
      _pinCompleter!.complete(pin);
    }
  }

  /// Sender side pairing flow.
  Future<PairingResult> initiatePairing(Socket socket, String deviceName) async {
    try {
      // 1. Send OP_PAIR + deviceName
      final pairHeader = BinaryHeader(
        magic: BinaryHeader.magicNumber,
        op: BinaryHeader.opPair,
        fileSize: 0,
        fileName: deviceName,
      );
      socket.add(pairHeader.encode());
      await socket.flush();

      // 2. Wait for PIN challenge (OP_PIN from receiver)
      final challengeHeader = await _readHeader(socket).timeout(const Duration(seconds: 10));
      if (challengeHeader.op != BinaryHeader.opPin) {
        throw Exception('Expected OP_PIN challenge');
      }

      // 3. User enters PIN
      _eventsController.add(PairingEvent(PairingEventType.waitingForPin));
      _pinCompleter = Completer<String>();
      
      final String pin;
      try {
        pin = await _pinCompleter!.future.timeout(const Duration(seconds: 60));
      } catch (e) {
        _eventsController.add(PairingEvent(PairingEventType.pairingTimeout));
        return PairingResult.timeout;
      }

      // 4. Send PIN to receiver
      final pinHeader = BinaryHeader(
        magic: BinaryHeader.magicNumber,
        op: BinaryHeader.opPin,
        fileSize: 0,
        fileName: pin,
      );
      socket.add(pinHeader.encode());
      await socket.flush();

      // 5. Wait for PAIR_OK or PAIR_REJECT
      final resultHeader = await _readHeader(socket).timeout(const Duration(seconds: 10));
      if (resultHeader.op == BinaryHeader.opPairOk) {
        _eventsController.add(PairingEvent(PairingEventType.pairingSuccess));
        await _trustDevice(socket.remoteAddress.address, resultHeader.fileName.isNotEmpty ? resultHeader.fileName : 'Receiver');
        return PairingResult.success;
      } else {
        _eventsController.add(PairingEvent(PairingEventType.pairingFailed, message: 'Rejected by receiver'));
        return PairingResult.rejected;
      }
    } on TimeoutException {
      _eventsController.add(PairingEvent(PairingEventType.pairingTimeout));
      return PairingResult.timeout;
    } catch (e) {
      _eventsController.add(PairingEvent(PairingEventType.pairingFailed, message: e.toString()));
      return PairingResult.error;
    }
  }

  /// Receiver side pairing flow.
  /// Expects the caller to have already verified the initial OP_PAIR header
  /// and passes the [senderName] extracted from it.
  Future<PairingResult> respondToPairing(Socket socket, String senderName) async {
    try {
      // 1. Generate PIN and show via stream
      final pin = generatePIN();
      _eventsController.add(PairingEvent(PairingEventType.pinGenerated, pin: pin));

      // 2. Send PIN challenge (OP_PIN)
      final challengeHeader = BinaryHeader(
        magic: BinaryHeader.magicNumber,
        op: BinaryHeader.opPin,
        fileSize: 0,
        fileName: 'CHALLENGE',
      );
      socket.add(challengeHeader.encode());
      await socket.flush();

      // 3. Wait for PIN from sender
      final pinHeader = await _readHeader(socket).timeout(const Duration(seconds: 60));
      if (pinHeader.op != BinaryHeader.opPin) {
        throw Exception('Expected OP_PIN');
      }

      final receivedPin = pinHeader.fileName.trim();
      
      // 4. Validate PIN
      if (receivedPin == pin) {
        final okHeader = BinaryHeader(
          magic: BinaryHeader.magicNumber,
          op: BinaryHeader.opPairOk,
          fileSize: 0,
          fileName: 'ReceiverDevice', 
        );
        socket.add(okHeader.encode());
        await socket.flush();

        await _trustDevice(socket.remoteAddress.address, senderName);
        _eventsController.add(PairingEvent(PairingEventType.pairingSuccess));
        return PairingResult.success;
      } else {
        final rejectHeader = BinaryHeader(
          magic: BinaryHeader.magicNumber,
          op: BinaryHeader.opPairReject,
          fileSize: 0,
          fileName: '',
        );
        socket.add(rejectHeader.encode());
        await socket.flush();

        _eventsController.add(PairingEvent(PairingEventType.pairingFailed, message: 'Invalid PIN'));
        return PairingResult.rejected;
      }
    } on TimeoutException {
      _eventsController.add(PairingEvent(PairingEventType.pairingTimeout));
      return PairingResult.timeout;
    } catch (e) {
      _eventsController.add(PairingEvent(PairingEventType.pairingFailed, message: e.toString()));
      return PairingResult.error;
    }
  }

  /// Helper to read a single BinaryHeader from a raw socket stream.
  Future<BinaryHeader> _readHeader(Socket socket) async {
    final completer = Completer<BinaryHeader>();
    final buffer = BytesBuilder();
    StreamSubscription? sub;

    sub = socket.listen((data) {
      buffer.add(data);
      if (buffer.length >= 269) {
        try {
          final headerData = buffer.takeBytes().sublist(0, 269);
          final header = BinaryHeader.decode(Uint8List.fromList(headerData));
          sub?.cancel();
          if (!completer.isCompleted) completer.complete(header);
        } catch (e) {
          sub?.cancel();
          if (!completer.isCompleted) completer.completeError(e);
        }
      }
    }, onError: (e) {
      sub?.cancel();
      if (!completer.isCompleted) completer.completeError(e);
    }, onDone: () {
      if (!completer.isCompleted) completer.completeError(Exception('Socket closed'));
    });

    return completer.future;
  }

  /// Checks the trusted store for a matching entry.
  Future<bool> isTrusted(String ip, {String? deviceName}) async {
    final prefs = await SharedPreferences.getInstance();
    final listStr = prefs.getString(_storeKey);
    if (listStr == null) return false;

    try {
      final List<dynamic> list = jsonDecode(listStr);
      for (var item in list) {
        if (item['ip'] == ip) {
          if (deviceName != null && item['deviceName'] != deviceName) {
            continue;
          }
          return true;
        }
      }
    } catch (e) {
      print('Error parsing trusted devices: $e');
    }
    return false;
  }

  /// Stores a trusted device.
  Future<void> _trustDevice(String ip, String deviceName) async {
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> list = [];
    final listStr = prefs.getString(_storeKey);
    if (listStr != null) {
      try {
        list = jsonDecode(listStr);
      } catch (_) {}
    }

    // Remove old entries with same IP to avoid duplicates
    list.removeWhere((item) => item['ip'] == ip);

    list.add({
      'deviceName': deviceName,
      'ip': ip,
      'publicKey': '',
      'pairedAt': DateTime.now().toIso8601String(),
    });

    await prefs.setString(_storeKey, jsonEncode(list));
  }

  /// Revokes trust for a given device name.
  Future<void> revokeTrust(String deviceName) async {
    final prefs = await SharedPreferences.getInstance();
    final listStr = prefs.getString(_storeKey);
    if (listStr == null) return;

    try {
      final List<dynamic> list = jsonDecode(listStr);
      list.removeWhere((item) => item['deviceName'] == deviceName);
      await prefs.setString(_storeKey, jsonEncode(list));
    } catch (_) {}
  }
}
