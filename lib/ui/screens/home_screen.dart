import 'dart:io';
import 'package:flutter/material.dart';
import 'package:beam/ui/theme.dart';
import 'package:beam/ui/widgets/peer_list_widget.dart';
import 'package:beam/ui/widgets/transfer_queue_widget.dart';
import 'package:beam/ui/widgets/file_send_sheet.dart';
import 'package:beam/core/discovery.dart';
import 'package:beam/linux/file_drop_handler.dart';
import 'package:beam/android/file_picker_helper.dart';
import 'settings_screen.dart';
import 'package:beam/ui/widgets/pairing_overlay.dart';
import 'package:beam/ui/widgets/incoming_transfer_banner.dart';
import 'package:beam/ui/state/app_state.dart';
import 'package:beam/core/peer_state.dart';
import 'package:beam/core/app_services.dart';
import 'history_screen.dart';
import 'package:pico/pico.dart';
import 'package:beam/ui/state/store.dart';
import 'package:beam/ui/state/actions.dart' as actions;

/// The main home screen of the Beam app.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FileDropHandler? _dropHandler;
  List<File>? _selectedFiles;

  @override
  void initState() {
    super.initState();
    if (Platform.isLinux) {
      _dropHandler = FileDropHandler();
      _dropHandler!.onFilesDropped.listen((files) {
        setState(() {
          _selectedFiles = files;
        });
      });
    }
  }

  @override
  void dispose() {
    _dropHandler?.dispose();
    super.dispose();
  }

  void _onFabPressed() async {
    final files = await FilePickerHelper.pickFiles();
    if (!mounted) return;
    if (files.isNotEmpty) {
      setState(() {
        _selectedFiles = files;
      });
    }
  }

  void _dismissSidePanel() {
    setState(() {
      _selectedFiles = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (Platform.isLinux) {
      content = PicoBuilder<AppState, BeamPeer?>(
        store: store,
        selector: (state) => state.selectedPeer,
        builder: (context, selectedPeer) {
          return Row(
            children: [
              Expanded(
                flex: 1,
                child: PeerListWidget(discovery: discovery),
              ),
              Container(width: 1, color: BeamColors.textSecondary.withOpacity(0.2)),
              Expanded(
                flex: 1,
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: TransferQueueWidget(),
                ),
              ),
              if (selectedPeer != null || _selectedFiles != null) ...[
                Container(width: 1, color: BeamColors.textSecondary.withOpacity(0.2)),
                SizedBox(
                  width: 350,
                  child: FileSendSheet(
                    peer: selectedPeer ?? store.state.peers.first,
                    initialFiles: _selectedFiles ?? [],
                    onDismiss: () {
                      actions.selectPeer(null);
                      _dismissSidePanel();
                    },
                  ),
                ),
              ]
            ],
          );
        },
      );
    } else {
      // Android layout
      content = Column(
        children: [
          Expanded(
            flex: 1,
            child: PeerListWidget(discovery: discovery),
          ),
          Container(height: 1, color: BeamColors.textSecondary.withOpacity(0.2)),
          const Expanded(
            flex: 1,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: TransferQueueWidget(),
            ),
          ),
        ],
      );
    }

    Widget scaffold = Scaffold(
      appBar: AppBar(
        title: Text(
          'beam',
          style: BeamTextStyles.headline.copyWith(color: BeamColors.accent),
        ),
        backgroundColor: BeamColors.background,
        elevation: 0,
        actions: [
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
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(Platform.isLinux ? 24.0 : 16.0),
              child: content,
            ),
          ),
          const PairingOverlayWidget(),
          const IncomingTransferBannerWidget(),
        ],
      ),
      floatingActionButton: Platform.isAndroid
          ? FloatingActionButton(
              onPressed: _onFabPressed,
              child: const Icon(Icons.add),
            )
          : null,
      bottomSheet: Platform.isAndroid
          ? PicoBuilder<AppState, ({BeamPeer? peer, PeerState? state})>(
              store: store,
              selector: (state) => (
                peer: state.selectedPeer,
                state: state.selectedPeer != null ? state.peerStates[state.selectedPeer!.id] : null,
              ),
              builder: (context, data) {
                if (data.peer != null && (data.state == PeerState.connected || data.state == PeerState.transferring)) {
                  return FractionallySizedBox(
                    heightFactor: 0.8,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: FileSendSheet(
                        peer: data.peer!,
                        initialFiles: _selectedFiles ?? [],
                        onDismiss: () {
                          actions.selectPeer(null);
                          _dismissSidePanel();
                        },
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            )
          : null,
    );

    if (Platform.isLinux && _dropHandler != null) {
      return _dropHandler!.init(child: scaffold);
    }

    return scaffold;
  }
}
