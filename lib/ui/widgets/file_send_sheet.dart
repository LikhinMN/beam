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

/// A panel (bottom sheet on Android, side panel on Linux) to review and send files.
class FileSendSheet extends StatefulWidget {
  final List<File> initialFiles;
  final VoidCallback onDismiss;

  const FileSendSheet({
    super.key,
    required this.initialFiles,
    required this.onDismiss,
  });

  @override
  State<FileSendSheet> createState() => _FileSendSheetState();
}

class _FileSendSheetState extends State<FileSendSheet> {
  late List<File> _files;

  @override
  void initState() {
    super.initState();
    _files = List<File>.from(widget.initialFiles);
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
    });
    if (_files.isEmpty) {
      widget.onDismiss();
    }
  }

  void _sendFiles(BeamPeer peer) {
    for (var file in _files) {
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
        // Since we don't know the exact structure of TransferEvent from sprint 1 here,
        // we assume it provides status, bytesTransferred, error.
        // We map it to our TransferItem
        
        // This is a rough estimation of how the mapping looks.
        // We need to parse event status string or enum to TransferStatus
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
      
      client.sendFile(peer.ip, peer.port, file);
    }
    
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return PicoBuilder<AppState, BeamPeer?>(
      store: store,
      selector: (state) => state.selectedPeer,
      builder: (context, selectedPeer) {
        return Container(
          color: BeamColors.surface,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Send Files', style: BeamTextStyles.headline),
                  IconButton(
                    icon: const Icon(Icons.close, color: BeamColors.textPrimary),
                    onPressed: widget.onDismiss,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (selectedPeer != null)
                Text(
                  'To: ${selectedPeer.name} (${selectedPeer.ip})',
                  style: BeamTextStyles.body.copyWith(color: BeamColors.accent),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BeamColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BeamColors.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: BeamColors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Select a peer from the list to send files.',
                          style: BeamTextStyles.caption.copyWith(color: BeamColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
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
                  onPressed: selectedPeer == null || _files.isEmpty
                      ? null
                      : () => _sendFiles(selectedPeer),
                  child: const Text('Send'),
                ),
              ),
            ],
          ),
        );
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
          icon: const Icon(Icons.remove_circle_outline, color: BeamColors.error),
          onPressed: onRemove,
        ),
      ],
    );
  }
}
