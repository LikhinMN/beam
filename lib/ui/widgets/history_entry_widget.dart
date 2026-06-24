import 'package:flutter/material.dart';
import 'package:beam/ui/theme.dart';
import 'package:beam/core/transfer_history.dart';
import 'package:beam/core/utils.dart';
import 'package:intl/intl.dart';

class HistoryEntryWidget extends StatelessWidget {
  final HistoryEntry entry;

  const HistoryEntryWidget({super.key, required this.entry});

  String _formatRelativeTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return 'Just now';
        }
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BeamColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final date = DateTime.fromMillisecondsSinceEpoch(entry.timestamp);
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transfer Details', style: BeamTextStyles.headline),
              const SizedBox(height: 16),
              _DetailRow('File', entry.fileName),
              _DetailRow('Size', UIUtils.formatBytes(entry.fileSize)),
              _DetailRow('Direction', entry.direction == 'send' ? 'Sent' : 'Received'),
              _DetailRow('Peer', '${entry.peerName} (${entry.peerIp})'),
              _DetailRow('Date', DateFormat('MMM d, yyyy h:mm a').format(date)),
              _DetailRow('Speed', '${UIUtils.formatBytes(entry.speedBytesPerSec?.toInt() ?? 0)}/s'),
              _DetailRow('Status', entry.status),
              if (entry.errorReason != null)
                _DetailRow('Error', entry.errorReason!, color: BeamColors.error),
              const SizedBox(height: 24),
              if (entry.direction == 'send') ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: trigger send again
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BeamColors.accent,
                      foregroundColor: BeamColors.background,
                    ),
                    child: const Text('Send Again'),
                  ),
                )
              ]
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSend = entry.direction == 'send';
    final isCompleted = entry.status == 'completed';

    return InkWell(
      onTap: () => _showDetails(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: BeamColors.textSecondary.withValues(alpha: 0.1))),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted
                    ? BeamColors.success.withValues(alpha: 0.1)
                    : BeamColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSend ? Icons.arrow_upward : Icons.arrow_downward,
                color: isCompleted ? BeamColors.success : BeamColors.error,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    UIUtils.truncateMiddle(entry.fileName),
                    style: BeamTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.peerName} • ${UIUtils.formatBytes(entry.fileSize)}',
                    style: BeamTextStyles.caption.copyWith(color: BeamColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatRelativeTime(entry.timestamp),
                  style: BeamTextStyles.caption.copyWith(color: BeamColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  isCompleted ? 'Completed' : 'Failed',
                  style: BeamTextStyles.caption.copyWith(
                    color: isCompleted ? BeamColors.success : BeamColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _DetailRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: BeamTextStyles.body.copyWith(color: BeamColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: BeamTextStyles.body.copyWith(color: color ?? BeamColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
