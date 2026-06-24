import 'package:flutter/material.dart';
import 'package:beam/ui/theme.dart';
import 'package:beam/core/discovery.dart';
import 'package:beam/core/pairing.dart';
import 'package:beam/ui/screens/device_screen.dart';

class PeerListTile extends StatelessWidget {
  final BeamPeer peer;

  const PeerListTile({super.key, required this.peer});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DeviceScreen(peer: peer),
        ));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: BeamColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: BeamColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                peer.platform == 'android' ? Icons.phone_android : Icons.laptop,
                color: BeamColors.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peer.name,
                    style: BeamTextStyles.body,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    peer.ip,
                    style: BeamTextStyles.caption.copyWith(color: BeamColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FutureBuilder<bool>(
              future: BeamPairing.instance.isTrusted(peer.ip, peer.name),
              builder: (context, snapshot) {
                final isTrusted = snapshot.data ?? false;
                return Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isTrusted ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            const Icon(Icons.chevron_right, color: BeamColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
