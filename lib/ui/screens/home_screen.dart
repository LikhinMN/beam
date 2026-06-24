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
import 'pairing_screen.dart';
import 'package:beam/ui/state/app_state.dart';
import 'package:beam/core/app_services.dart';
import 'history_screen.dart';

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
      if (Platform.isAndroid) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return FractionallySizedBox(
              heightFactor: 0.8,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: FileSendSheet(
                  initialFiles: files,
                  onDismiss: () => Navigator.of(context).pop(),
                ),
              ),
            );
          },
        );
      } else {
        setState(() {
          _selectedFiles = files;
        });
      }
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
      content = Row(
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
          if (_selectedFiles != null) ...[
            Container(width: 1, color: BeamColors.textSecondary.withOpacity(0.2)),
            SizedBox(
              width: 350,
              child: FileSendSheet(
                initialFiles: _selectedFiles!,
                onDismiss: _dismissSidePanel,
              ),
            ),
          ]
        ],
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
        ],
      ),
      floatingActionButton: Platform.isAndroid
          ? FloatingActionButton(
              onPressed: _onFabPressed,
              child: const Icon(Icons.add),
            )
          : null,
    );

    if (Platform.isLinux && _dropHandler != null) {
      return _dropHandler!.init(child: scaffold);
    }

    return scaffold;
  }
}
