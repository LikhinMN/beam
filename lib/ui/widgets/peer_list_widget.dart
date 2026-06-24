import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pico/pico.dart';
import 'package:beam/core/discovery.dart';
import 'package:beam/ui/state/app_state.dart';
import 'package:beam/ui/state/store.dart';
import 'package:beam/ui/state/actions.dart' as actions;
import 'package:beam/ui/theme.dart';
import 'package:beam/core/peer_state.dart';
import 'package:beam/core/pairing.dart';
import 'package:beam/core/protocol.dart';
import 'package:beam/core/settings_store.dart';
import 'package:beam/ui/widgets/file_send_sheet.dart';
import 'peer_card_widget.dart';

/// A widget that displays a list of discovered peers.
class PeerListWidget extends StatelessWidget {
  final BeamDiscovery discovery;

  const PeerListWidget({super.key, required this.discovery});

  void _handlePair(BuildContext context, BeamPeer peer) async {
    actions.setPeerState(peer.id, PeerState.pairing);
    actions.setPairingState(const AsyncLoading());
    try {
      final socket = await Socket.connect(peer.ip, peer.port, timeout: const Duration(seconds: 5));
      final beamSocket = BeamSocket(socket);
      final pairing = BeamPairing();
      final result = await pairing.initiatePairing(beamSocket, SettingsStore.instance.deviceName);
      if (result == PairingResult.success) {
        actions.setPeerState(peer.id, PeerState.trusted);
      } else {
        actions.setPeerState(peer.id, PeerState.discovered);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pairing failed. Try again.')));
        }
      }
      socket.destroy();
    } catch (e) {
      actions.setPeerState(peer.id, PeerState.discovered);
      actions.setPairingState(AsyncError(e, StackTrace.current));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pairing failed. Try again.')));
      }
    }
  }

  void _handleConnect(BuildContext context, BeamPeer peer) async {
    actions.setPeerState(peer.id, PeerState.connecting);
    try {
      final socket = await Socket.connect(peer.ip, peer.port, timeout: const Duration(seconds: 5));
      final header = BinaryHeader(
        magic: BinaryHeader.magicNumber,
        op: BinaryHeader.opConnect,
        fileSize: 0,
        fileName: '',
      );
      socket.add(header.encode());
      await socket.flush();
      
      actions.setPeerState(peer.id, PeerState.connected);
      if (context.mounted) {
        _handleCardTap(context, peer);
      }
      // Assuming socket should stay open or can be closed if it's stateless connection
      socket.destroy();
    } catch (e) {
      actions.setPeerState(peer.id, PeerState.trusted);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not connect to ${peer.name}. Make sure both devices are on the same Wi-Fi.')));
      }
    }
  }

  void _handleCardTap(BuildContext context, BeamPeer peer) {
    actions.selectPeer(peer);
  }

  void _handleCancelTransfer(BuildContext context, BeamPeer peer, TransferItem? transfer) {
    // Ideally cancel the actual transfer using client or isolate.
    // For now, reset UI state.
    actions.setPeerState(peer.id, PeerState.connected);
  }

  @override
  Widget build(BuildContext context) {
    return PicoBuilder<AppState, ({List<BeamPeer> peers, bool isScanning, BeamPeer? selectedPeer, Map<String, PeerState> peerStates, List<TransferItem> transfers})>(
      store: store,
      selector: (state) => (
        peers: state.peers, 
        isScanning: state.isScanning,
        selectedPeer: state.selectedPeer,
        peerStates: state.peerStates,
        transfers: state.transfers,
      ),
      builder: (context, data) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Devices', style: BeamTextStyles.headline),
                Row(
                  children: [
                    if (data.isScanning)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(BeamColors.accent),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: BeamColors.textPrimary),
                      onPressed: actions.refreshDiscovery,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (data.peers.isEmpty)
              _buildEmptyState(data.isScanning)
            else
              Expanded(
                child: ListView.separated(
                  itemCount: data.peers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final peer = data.peers[index];
                    final state = data.peerStates[peer.id] ?? PeerState.discovered;
                    final activeTransfer = data.transfers.where((t) => t.status == TransferStatus.active).firstOrNull;

                    return PeerCardWidget(
                      peer: peer,
                      state: state,
                      activeTransfer: activeTransfer,
                      onPairTap: () => _handlePair(context, peer),
                      onConnectTap: () => _handleConnect(context, peer),
                      onCardTap: () => _handleCardTap(context, peer),
                      onCancelTransferTap: () => _handleCancelTransfer(context, peer, activeTransfer),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.add, color: BeamColors.accent),
              label: Text('Manual IP Entry', style: BeamTextStyles.body.copyWith(color: BeamColors.accent)),
              onPressed: () => _showManualIpDialog(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(bool isScanning) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // A simple animated pulse effect could be implemented here with TweenAnimationBuilder,
            // but a simple icon is used for brevity.
            Icon(
              isScanning ? Icons.radar : Icons.devices,
              size: 48,
              color: BeamColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              isScanning ? 'Scanning for devices...' : 'No devices found',
              style: BeamTextStyles.body.copyWith(color: BeamColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualIpDialog(BuildContext context) {
    final ipController = TextEditingController();
    final portController = TextEditingController(text: '9001');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Manual IP Entry', style: BeamTextStyles.headline),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ipController,
                decoration: InputDecoration(
                  labelText: 'IP Address',
                  labelStyle: BeamTextStyles.caption,
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: BeamColors.textSecondary)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: BeamColors.accent)),
                ),
                style: BeamTextStyles.body,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: portController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Port',
                  labelStyle: BeamTextStyles.caption,
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: BeamColors.textSecondary)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: BeamColors.accent)),
                ),
                style: BeamTextStyles.body,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Add Device'),
              onPressed: () {
                final ip = ipController.text.trim();
                final port = int.tryParse(portController.text.trim()) ?? 9001;
                if (ip.isNotEmpty) {
                  actions.upsertPeer(BeamPeer(
                    id: ip,
                    name: 'Manual Device',
                    ip: ip,
                    port: port,
                    platform: 'unknown',
                    isOnline: true,
                  ));
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
}
}
