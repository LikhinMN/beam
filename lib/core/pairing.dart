import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beam/core/protocol.dart';
import 'package:beam/core/settings_store.dart';

enum PairingResult { success, failed, timeout, error }

class TrustedDevice {
  final String deviceId;
  final String deviceName;
  final String ip;
  final String secret;

  TrustedDevice({
    required this.deviceId,
    required this.deviceName,
    required this.ip,
    required this.secret,
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'ip': ip,
    'secret': secret,
    'pairedAt': DateTime.now().toIso8601String(),
  };

  factory TrustedDevice.fromJson(Map<String, dynamic> json) {
    return TrustedDevice(
      deviceId: json['deviceId'] ?? '',
      deviceName: json['deviceName'] ?? '',
      ip: json['ip'] ?? '',
      secret: json['secret'] ?? '',
    );
  }
}

class BeamPairing {
  static final BeamPairing _instance = BeamPairing._internal();
  static BeamPairing get instance => _instance;
  factory BeamPairing() => _instance;
  BeamPairing._internal();

  static const String _storeKey = 'beam_trusted_devices';

  late final String sessionSecret;
  
  final StreamController<TrustedDevice> _devicePairedController = StreamController<TrustedDevice>.broadcast();
  Stream<TrustedDevice> get onDevicePaired => _devicePairedController.stream;

  void init() {
    sessionSecret = (Random.secure().nextInt(900000) + 100000).toString();
  }

  // Called by scanner after reading QR
  Future<PairingResult> initiateQRPairing(
    String ip, int port, String theirSecret, 
    String theirDeviceId, String theirDeviceName
  ) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 10));
      final beamSocket = BeamSocket(socket);
      
      // Send OP_PAIR with our identity + their secret as challenge
      socket.add(BinaryHeader(
        magic: BinaryHeader.magicNumber,
        op: BinaryHeader.opPair,
        fileSize: 0,
        fileName: '',
        deviceId: SettingsStore.instance.deviceId,
        deviceName: SettingsStore.instance.deviceName,
        secret: theirSecret,  // echo their secret back as proof of scan
      ).encode());
      await socket.flush();

      final response = await beamSocket.readHeader(timeout: const Duration(seconds: 10));
      if (response.op == BinaryHeader.opPairOk) {
        // Store as trusted
        await _storeTrusted(TrustedDevice(
          deviceId: theirDeviceId,
          deviceName: theirDeviceName,
          ip: ip,
          secret: theirSecret,
        ));
        socket.destroy();
        return PairingResult.success;
      }
      socket.destroy();
      return PairingResult.failed;
    } on TimeoutException {
      return PairingResult.timeout;
    } catch (e) {
      return PairingResult.error;
    }
  }

  // Called by server when OP_PAIR arrives
  Future<void> respondToQRPairing(
    BeamSocket socket, BinaryHeader header
  ) async {
    try {
      // Validate: the secret they sent must match our sessionSecret
      if (header.secret == sessionSecret) {
        await _storeTrusted(TrustedDevice(
          deviceId: header.deviceId,
          deviceName: header.deviceName,
          ip: socket.socket.remoteAddress.address,
          secret: sessionSecret,
        ));
        socket.socket.add(BinaryHeader(
          magic: BinaryHeader.magicNumber,
          op: BinaryHeader.opPairOk,
          fileSize: 0,
          fileName: '',
        ).encode());
        await socket.socket.flush();
      } else {
        socket.socket.add(BinaryHeader(
          magic: BinaryHeader.magicNumber,
          op: BinaryHeader.opPairReject,
          fileSize: 0,
          fileName: '',
        ).encode());
        await socket.socket.flush();
      }
    } catch (e) {
      print('Error responding to QR pairing: $e');
    }
  }

  /// Checks the trusted store for a matching entry.
  Future<bool> isTrusted(String ip, [String? deviceName]) async {
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
  Future<void> _storeTrusted(TrustedDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> list = [];
    final listStr = prefs.getString(_storeKey);
    if (listStr != null) {
      try {
        list = jsonDecode(listStr);
      } catch (_) {}
    }

    // Remove old entries with same IP to avoid duplicates
    list.removeWhere((item) => item['ip'] == device.ip);

    list.add(device.toJson());

    await prefs.setString(_storeKey, jsonEncode(list));
    _devicePairedController.add(device);
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
