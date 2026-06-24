import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:beam/core/discovery.dart';
import 'package:beam/core/transfer_server.dart';
import 'package:beam/core/settings_store.dart';
import 'package:beam/core/transfer_history.dart';
import 'package:beam/ui/state/actions.dart' as actions;
import 'package:beam/ui/state/app_state.dart';
import 'package:beam/core/speed_calculator.dart';
import 'package:beam/core/protocol.dart';
import 'package:beam/core/pairing.dart';
import 'package:beam/linux/firewall_helper.dart';
import 'package:pico/pico.dart';

final BeamDiscovery discovery = BeamDiscovery();
final TransferServer server = TransferServer();
final Map<String, SpeedCalculator> _speedCalcs = {};

Future<void> initAppServices() async {
  // 1. Init SettingsStore
  await SettingsStore.instance.init();

  // 2. Auto-delete old history entries (30 days)
  await TransferHistory.instance.deleteOlderThan(const Duration(days: 30));

  final port = SettingsStore.instance.port;
  final deviceName = SettingsStore.instance.deviceName;
  final deviceId = SettingsStore.instance.deviceId;

  // 3. Start TransferServer (check firewall first on Linux)
  if (Platform.isLinux) {
    final canBind = await FirewallHelper.checkPortAccessible(port);
    if (!canBind) {
      actions.setFirewallError(FirewallHelper.getFirewallInstructions(port));
    }
  }

  // Wire up TransferServer
  server.events.listen((event) {
    final id = event.fileName ?? 'unknown';
    SpeedCalculator? calc = _speedCalcs[id];
    if (calc == null) {
      calc = SpeedCalculator();
      _speedCalcs[id] = calc;
    }

    TransferStatus status = TransferStatus.active;
    if (event.status.name == 'completed') status = TransferStatus.completed;
    if (event.status.name == 'failed') status = TransferStatus.failed;

    final transferred = event.bytesTransferred ?? 0;
    calc.update(transferred);
    final totalBytes = event.totalBytes ?? 0;

    actions.upsertTransfer(
      (
        id: id,
        fileName: event.fileName ?? 'Unknown',
        totalBytes: totalBytes,
        transferredBytes: transferred,
        speedBytesPerSec: calc.currentSpeed,
        eta: calc.eta(totalBytes > transferred ? totalBytes - transferred : 0),
        direction: TransferDirection.receive,
        status: status,
        errorReason: event.error,
      ),
      peerName: 'Sender', // Basic fallback
      peerIp: event.senderIp,
    );

    if (status != TransferStatus.active) {
      _speedCalcs.remove(id);
    }
  });

  try {
    await server.start(port: port);
  } catch (e) {
    print('Failed to start server: $e');
  }

  // 4. Init QR pairing session secret
  BeamPairing.instance.init();

  // 5 & 6. Start mDNS advertising and scanning
  await discovery.startAdvertising(deviceName, port, deviceId);

  Future.delayed(const Duration(milliseconds: 500), () async {
    await discovery.startScanning();
  });
}

Future<void> shutdownAppServices() async {
  await discovery.stopAdvertising();
  await discovery.stopScanning();
  await server.stop();
}
