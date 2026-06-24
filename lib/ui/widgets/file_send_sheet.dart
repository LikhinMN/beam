import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pico/pico.dart';
import 'package:path/path.dart' as p;
import 'package:beam/core/discovery.dart';
import 'package:beam/ui/state/app_state.dart';
import 'package:beam/ui/state/store.dart';
import 'package:beam/ui/theme.dart';
import 'package:beam/core/utils.dart';
import 'package:beam/core/transfer_client.dart';
import 'package:beam/core/speed_calculator.dart';
import 'package:beam/ui/state/actions.dart' as actions;
import 'package:beam/core/peer_state.dart';
import 'package:beam/android/file_picker_helper.dart';

class FileSendSheet extends StatefulWidget {
  final BeamPeer peer;
  final List<File> initialFiles;
  final VoidCallback onDismiss;

  const FileSendSheet({
    super.key,
    required this.peer,
    required this.initialFiles,
    required this.onDismiss,
  });

  @override
  State<FileSendSheet> createState() => _FileSendSheetState();
}

class _FileSendSheetState extends State<FileSendSheet> {
  late List<File> _files;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _files = List<File>.from(widget.initialFiles);
  }

  void _addFiles() async {
    final newFiles = await FilePickerHelper.pickFiles();
    if (newFiles.isNotEmpty) {
      setState(() {
        _files.addAll(newFiles);
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
    });
  }

  void _disconnect() {
    actions.setPeerState(widget.peer.id, PeerState.trusted);
    if (!_isDismissing) {
      _isDismissing = true;
      widget.onDismiss();
    }
  }

  void _sendFiles() async {
    if (_files.isEmpty) return;

    actions.setPeerState(widget.peer.id, PeerState.transferring);

    int successCount = 0;
    bool anyFailure = false;

    for (int i = 0; i < _files.length; i++) {
      final file = _files[i];
      final id = '${DateTime.now().millisecondsSinceEpoch}_${file.hashCode}';
      final size = file.lengthSync();
      final baseName = p.basename(file.path);

      actions.upsertTransfer((
        id: id,
        fileName: baseName,
        totalBytes: size,
        transferredBytes: 0,
        speedBytesPerSec: 0,
        eta: const Duration(),
        direction: TransferDirection.send,
        status: TransferStatus.active,
        errorReason: null,
      ));

      final speedCalc = SpeedCalculator();
      final client = TransferClient();

      client.events.listen((event) {
        TransferStatus status = TransferStatus.active;
        if (event.status.name == 'completed') status = TransferStatus.completed;
        if (event.status.name == 'failed') status = TransferStatus.failed;

        final transferred = event.bytesTransferred;
        speedCalc.update(transferred);

        actions.upsertTransfer((
          id: id,
          fileName: baseName,
          totalBytes: size,
          transferredBytes: transferred,
          speedBytesPerSec: speedCalc.currentSpeed,
          eta: speedCalc.eta(size - transferred),
          direction: TransferDirection.send,
          status: status,
          errorReason: event.error,
        ));
      });

      try {
        await client.sendFile(widget.peer.ip, widget.peer.port, file);
        successCount++;
      } catch (e) {
        anyFailure = true;
      }
    }

    if (mounted) {
      actions.setPeerState(widget.peer.id, PeerState.connected);
      if (anyFailure) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer failed.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✓ $successCount file(s) sent successfully')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PicoBuilder<AppState, PeerState>(
      store: store,
      selector: (state) => state.peerStates[widget.peer.id] ?? PeerState.discovered,
      builder: (context, peerState) {
        // Auto-close if peer is no longer connected or transferring
        if (peerState != PeerState.connected && peerState != PeerState.transferring) {
          if (!_isDismissing) {
            _isDismissing = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.onDismiss();
            });
          }
        }

        return RepaintBoundary(
          child: Container(
            color: BeamColors.surface,
            padding: const EdgeInsets.all(24),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Connected to ${widget.peer.name}', style: BeamTextStyles.headline.copyWith(fontSize: 18)),
                  IconButton(
                    icon: const Icon(Icons.close, color: BeamColors.textPrimary),
                    onPressed: _disconnect,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _addFiles,
                icon: const Icon(Icons.add, color: BeamColors.accent),
                label: const Text('Add Files'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BeamColors.accent,
                  side: const BorderSide(color: BeamColors.accent),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _files.isEmpty
                    ? Center(child: Text('Add files to send', style: BeamTextStyles.body.copyWith(color: BeamColors.textSecondary)))
                    : ListView.separated(
                        itemCount: _files.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final file = _files[index];
                          return _FileRow(
                            file: file,
                            onRemove: () => _removeFile(index),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _files.isEmpty || peerState != PeerState.connected ? null : _sendFiles,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BeamColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: const Text('SEND'),
                ),
              ),
            ],
          ),
        ));
      },
    );
  }
}

class _FileRow extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;

  const _FileRow({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final name = p.basename(file.path);
    int size = 0;
    try {
      size = file.lengthSync();
    } catch (_) {}

    return Row(
      children: [
        const Icon(Icons.insert_drive_file, color: BeamColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                UIUtils.truncateMiddle(name, maxLength: 30),
                style: BeamTextStyles.body,
              ),
              Text(
                UIUtils.formatBytes(size),
                style: BeamTextStyles.caption,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: BeamColors.error, size: 20),
          onPressed: onRemove,
        ),
      ],
    );
  }
}
