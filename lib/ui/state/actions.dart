import 'dart:async';
import 'package:pico/pico.dart';
import 'package:beam/core/discovery.dart';
import 'app_state.dart';
import 'store.dart';
import 'package:beam/core/transfer_history.dart';

/// Actions to mutate the global state.
/// All state mutations must go through these functions.

void upsertPeer(BeamPeer peer) {
  final existing = store.state.peers;
  final idx = existing.indexWhere((p) => p.id == peer.id);
  if (idx == -1) {
    store.set((s) => s.copyWith(peers: [...s.peers, peer]));
  } else {
    final updated = [...existing];
    updated[idx] = peer;
    store.set((s) => s.copyWith(peers: updated));
  }
}

void removePeer(BeamPeer peer) {
  final currentPeers = List<BeamPeer>.from(store.state.peers);
  currentPeers.removeWhere((p) => p.id == peer.id);
  store.set((state) => state.copyWith(peers: currentPeers));
}

void setPeers(List<BeamPeer> peers) {
  store.set((state) => state.copyWith(peers: peers));
}

Timer? _scanTimer;

void setScanning(bool value) {
  store.set((state) => state.copyWith(isScanning: value));
  _scanTimer?.cancel();
  if (value) {
    _scanTimer = Timer(const Duration(seconds: 5), () {
      store.set((state) => state.copyWith(isScanning: false));
    });
  }
}

void selectPeer(BeamPeer? peer) {
  store.set((state) => state.copyWith(
    selectedPeer: peer,
    clearSelectedPeer: peer == null,
  ));
}

void upsertTransfer(TransferItem item, {String? peerName, String? peerIp}) {
  final currentTransfers = List<TransferItem>.from(store.state.transfers);
  final index = currentTransfers.indexWhere((t) => t.id == item.id);
  
  if (index >= 0) {
    currentTransfers[index] = item;
  } else {
    currentTransfers.insert(0, item);
  }
  
  store.set((state) => state.copyWith(transfers: currentTransfers));

  if (item.status != TransferStatus.active) {
    TransferHistory.instance.record(item, peerName ?? 'Unknown', peerIp ?? '0.0.0.0').then((_) {
      loadHistory();
    });
  }

  // If completed, schedule removal after 5 seconds
  if (item.status == TransferStatus.completed) {
    Timer(const Duration(seconds: 5), () {
      final latestTransfers = List<TransferItem>.from(store.state.transfers);
      latestTransfers.removeWhere((t) => t.id == item.id);
      store.set((state) => state.copyWith(transfers: latestTransfers));
    });
  }
}

Future<void> loadHistory() async {
  store.set((state) => state.copyWith(history: const AsyncLoading()));
  try {
    final entries = await TransferHistory.instance.getAll();
    store.set((state) => state.copyWith(history: AsyncData(entries)));
  } catch (e) {
    store.set((state) => state.copyWith(history: AsyncError(e, StackTrace.current)));
  }
}

Future<void> clearHistory() async {
  await TransferHistory.instance.clear();
  store.set((state) => state.copyWith(history: const AsyncData([])));
}

void setFirewallError(String? message) {
  store.set((state) => state.copyWith(
    firewallError: message,
    clearFirewallError: message == null,
  ));
}

void setPairingState(AsyncValue<void> state) {
  store.set((s) => s.copyWith(pairingState: state));
}

void setIncomingPIN(String? pin) {
  store.set((state) => state.copyWith(
    incomingPIN: pin,
    clearIncomingPIN: pin == null,
  ));
}
