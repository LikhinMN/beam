import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:beam/ui/theme.dart';
import 'package:beam/core/discovery.dart';
import 'package:beam/core/pairing.dart';
import 'package:beam/core/settings_store.dart';
import 'package:beam/ui/screens/transfer_screen.dart';
import 'qr_scanner_stub.dart' if (dart.library.io) 'qr_scanner_android.dart';

enum _DeviceScreenState { showingQR, scanning, pairing, done }

class DeviceScreen extends StatefulWidget {
  final BeamPeer peer;

  const DeviceScreen({super.key, required this.peer});

  @override
  State<DeviceScreen> createState() => _DeviceScreenStateWidget();
}

class _DeviceScreenStateWidget extends State<DeviceScreen> with SingleTickerProviderStateMixin {
  _DeviceScreenState _state = _DeviceScreenState.showingQR;
  String? _errorMessage;
  late AnimationController _pulseController;
  bool _isDisposed = false;
  late StreamSubscription _pairingSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    if (Platform.isAndroid) {
      _state = _DeviceScreenState.scanning;
    }

    _checkTrust();

    _pairingSub = BeamPairing.instance.onDevicePaired.listen((device) {
      if (!mounted || _isDisposed) return;
      if (device.ip == widget.peer.ip || device.deviceName == widget.peer.name) {
        setState(() {
          _state = _DeviceScreenState.done;
        });
        Future.delayed(const Duration(milliseconds: 800), () {
          _navigateToTransfer();
        });
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pairingSub.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkTrust() async {
    final trusted = await BeamPairing.instance.isTrusted(widget.peer.ip, widget.peer.name);
    if (!mounted || _isDisposed) return;
    if (trusted) {
      _navigateToTransfer();
    }
  }

  void _navigateToTransfer() {
    if (!mounted || _isDisposed) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TransferScreen(peer: widget.peer)),
    );
  }

  Future<void> _handleScan(String data) async {
    if (_state != _DeviceScreenState.scanning) return;

    setState(() {
      _state = _DeviceScreenState.pairing;
      _errorMessage = null;
    });

    try {
      final json = jsonDecode(data);
      final secret = json['secret'] as String?;
      final deviceId = json['deviceId'] as String?;
      final deviceName = json['deviceName'] as String?;

      if (secret == null || deviceId == null || deviceName == null) {
        throw Exception("Invalid QR payload");
      }

      final result = await BeamPairing.instance.initiateQRPairing(
        widget.peer.ip,
        widget.peer.port,
        secret,
        deviceId,
        deviceName,
      );

      if (!mounted || _isDisposed) return;

      if (result == PairingResult.success) {
        setState(() {
          _state = _DeviceScreenState.done;
        });
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted || _isDisposed) return;
        _navigateToTransfer();
      } else {
        setState(() {
          _errorMessage = "Pairing failed. Try again.";
          _state = _DeviceScreenState.scanning;
        });
      }
    } catch (e) {
      if (!mounted || _isDisposed) return;
      setState(() {
        _errorMessage = "Invalid QR code. Try again.";
        _state = _DeviceScreenState.scanning;
      });
    }
  }

  Future<void> _handleManualPin(String pin) async {
    if (pin.length != 6) return;
    if (_state != _DeviceScreenState.scanning) return;

    setState(() {
      _state = _DeviceScreenState.pairing;
      _errorMessage = null;
    });

    try {
      final result = await BeamPairing.instance.initiateQRPairing(
        widget.peer.ip,
        widget.peer.port,
        pin,
        widget.peer.id,
        widget.peer.name,
      );

      if (!mounted || _isDisposed) return;

      if (result == PairingResult.success) {
        setState(() {
          _state = _DeviceScreenState.done;
        });
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted || _isDisposed) return;
        _navigateToTransfer();
      } else {
        setState(() {
          _errorMessage = "Pairing failed. Try again.";
          _state = _DeviceScreenState.scanning;
        });
      }
    } catch (e) {
      if (!mounted || _isDisposed) return;
      setState(() {
        _errorMessage = "Error occurred. Try again.";
        _state = _DeviceScreenState.scanning;
      });
    }
  }

  String _getQrPayload() {
    return jsonEncode({
      "deviceId": SettingsStore.instance.deviceId,
      "deviceName": SettingsStore.instance.deviceName,
      "ip": "0.0.0.0", // Payload doesn't need real IP
      "port": SettingsStore.instance.port,
      "platform": Platform.operatingSystem,
      "secret": BeamPairing.instance.sessionSecret,
    });
  }

  Widget _buildQR() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            "Scan this code on ${widget.peer.name}",
            style: BeamTextStyles.headline.copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: BeamColors.accent.withOpacity(_pulseController.value * 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: QrImageView(
                  data: _getQrPayload(),
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Open beam on the other device and scan",
          style: BeamTextStyles.body.copyWith(color: BeamColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Text(
          "Or enter PIN: ${BeamPairing.instance.sessionSecret}",
          style: BeamTextStyles.title.copyWith(color: BeamColors.accent),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: BeamColors.accent),
            ),
            const SizedBox(width: 12),
            Text(
              "Waiting for ${widget.peer.name} to scan...",
              style: BeamTextStyles.body,
            ),
          ],
        )
      ],
    );
  }

  Widget _buildScanner() {
    return Column(
      children: [
        Expanded(
          flex: 6,
          child: Stack(
            children: [
              buildQrScanner(onDetect: _handleScan),
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: BeamColors.accent, width: 4),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      "Point at the QR code on ${widget.peer.name}",
                      style: BeamTextStyles.headline.copyWith(fontSize: 22),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 16.0),
                    child: TextField(
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: BeamTextStyles.title,
                      decoration: InputDecoration(
                        hintText: "Or enter 6-digit PIN",
                        counterText: "",
                      ),
                      onSubmitted: _handleManualPin,
                      onChanged: (val) {
                        if (val.length == 6) _handleManualPin(val);
                      },
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: BeamTextStyles.body.copyWith(color: BeamColors.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_state == _DeviceScreenState.done) {
      content = const Center(
        child: Icon(Icons.check_circle, color: Colors.green, size: 80),
      );
    } else if (_state == _DeviceScreenState.pairing) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: BeamColors.accent),
            const SizedBox(height: 24),
            Text("Pairing...", style: BeamTextStyles.headline),
          ],
        ),
      );
    } else if (_state == _DeviceScreenState.scanning) {
      content = _buildScanner();
    } else {
      content = _buildQR();
    }

    return Scaffold(
      backgroundColor: BeamColors.background,
      appBar: AppBar(
        title: Text(widget.peer.name, style: BeamTextStyles.headline),
        backgroundColor: BeamColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: BeamColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: content,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _state = _state == _DeviceScreenState.scanning
                ? _DeviceScreenState.showingQR
                : _DeviceScreenState.scanning;
          });
        },
        backgroundColor: BeamColors.accent,
        child: Icon(
          _state == _DeviceScreenState.scanning
              ? Icons.qr_code
              : (Platform.isAndroid ? Icons.camera_alt : Icons.keyboard),
          color: Colors.white,
        ),
      ),
    );
  }
}
