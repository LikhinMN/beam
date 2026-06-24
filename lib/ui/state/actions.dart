import 'dart:async';
import 'package:pico/pico.dart';
import 'package:beam/core/discovery.dart';
import 'app_state.dart';
import 'store.dart';

/// Actions to mutate the global state.
/// All state mutations must go through these functions.

void addPeer(BeamPeer peer) {
  final currentPeers = List<BeamPeer>.from(store.state.peers);
  final index = currentPeers.indexWhere((p) => p.ip == peer.ip);
  if (index >= 0) {
    currentPeers[index] = peer;
  } else {
    currentPeers.add(peer);
  }
  store.set((state) => state.copyWith(peers: currentPeers));
}

void removePeer(BeamPeer peer) {
  final currentPeers = List<BeamPeer>.from(store.state.peers);
  currentPeers.removeWhere((p) => p.ip == peer.ip);
  store.set((state) => state.copyWith(peers: currentPeers));
}

void setPeers(List<BeamPeer> peers) {
  store.set((state) => state.copyWith(peers: peers));
}

void setScanning(bool value) {
  store.set((state) => state.copyWith(isScanning: value));
}

void selectPeer(BeamPeer? peer) {
  store.set((state) => state.copyWith(
    selectedPeer: peer,
    clearSelectedPeer: peer == null,
  ));
}

void upsertTransfer(TransferItem item) {
  final currentTransfers = List<TransferItem>.from(store.state.transfers);
  final index = currentTransfers.indexWhere((t) => t.id == item.id);
  
  if (index >= 0) {
    currentTransfers[index] = item;
  } else {
    currentTransfers.insert(0, item);
  }
  
  store.set((state) => state.copyWith(transfers: currentTransfers));

  // If completed, schedule removal after 5 seconds
  if (item.status == TransferStatus.completed) {
    Timer(const Duration(seconds: 5), () {
      final latestTransfers = List<TransferItem>.from(store.state.transfers);
      latestTransfers.removeWhere((t) => t.id == item.id);
      store.set((state) => state.copyWith(transfers: latestTransfers));
    });
  }
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
