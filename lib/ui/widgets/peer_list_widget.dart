import 'package:flutter/material.dart';
import 'package:pico/pico.dart';
import 'package:beam/core/discovery.dart';
import 'package:beam/ui/state/app_state.dart';
import 'package:beam/ui/state/store.dart';
import 'package:beam/ui/state/actions.dart' as actions;
import 'package:beam/ui/theme.dart';

/// A widget that displays a list of discovered peers.
class PeerListWidget extends StatelessWidget {
  final BeamDiscovery discovery;

  const PeerListWidget({super.key, required this.discovery});

  @override
  Widget build(BuildContext context) {
    return PicoBuilder<AppState, ({List<BeamPeer> peers, bool isScanning, BeamPeer? selectedPeer})>(
      store: store,
      selector: (state) => (
        peers: state.peers, 
        isScanning: state.isScanning,
        selectedPeer: state.selectedPeer,
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
                      onPressed: () async {
                        actions.setScanning(false);
                        await discovery.stopScanning();
                        actions.setPeers([]);
                        await discovery.startScanning();
                        actions.setScanning(true);
                      },
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
                    final isSelected = data.selectedPeer?.ip == peer.ip;
                    return _PeerCard(
                      peer: peer,
                      isSelected: isSelected,
                      onTap: () => actions.selectPeer(peer),
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
                  actions.addPeer(BeamPeer(
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

class _PeerCard extends StatelessWidget {
  final BeamPeer peer;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeerCard({required this.peer, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    IconData platformIcon = Icons.device_unknown;
    if (peer.platform == 'android') platformIcon = Icons.phone_android;
    if (peer.platform == 'linux') platformIcon = Icons.computer;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BeamColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? BeamColors.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(platformIcon, color: BeamColors.textSecondary, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(peer.name, style: BeamTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                  Text(peer.ip, style: BeamTextStyles.caption),
                ],
              ),
            ),
            if (peer.isOnline)
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: BeamColors.success,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
