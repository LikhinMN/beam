import 'package:flutter/material.dart';
import 'package:beam/ui/theme.dart';
import 'package:beam/ui/widgets/peer_list_tile.dart';
import 'package:beam/core/discovery.dart';
import 'settings_screen.dart';
import 'package:beam/ui/state/app_state.dart';
import 'package:pico/pico.dart';
import 'package:beam/ui/state/store.dart';
import 'history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeamColors.background,
      appBar: AppBar(
        title: Text(
          'beam',
          style: BeamTextStyles.headline.copyWith(color: BeamColors.accent),
        ),
        backgroundColor: BeamColors.background,
        elevation: 0,
        actions: [
          PicoBuilder<AppState, bool>(
            store: store,
            selector: (state) => state.isScanning,
            builder: (context, isScanning) {
              if (isScanning) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: BeamColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.history, color: BeamColors.textPrimary),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const HistoryScreen(),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: BeamColors.textPrimary),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SettingsScreen(),
              ));
            },
          )
        ],
      ),
      body: SafeArea(
        child: PicoBuilder<AppState, List<BeamPeer>>(
          store: store,
          selector: (state) => state.peers,
          builder: (context, peers) {
            if (peers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_tethering, size: 64, color: BeamColors.accent),
                    const SizedBox(height: 24),
                    Text(
                      'Scanning for devices...',
                      style: BeamTextStyles.body.copyWith(color: BeamColors.textSecondary),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: peers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final peer = peers[index];
                return PeerListTile(peer: peer);
              },
            );
          },
        ),
      ),
    );
  }
}
