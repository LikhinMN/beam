import 'package:flutter/material.dart';
import 'package:pico/pico.dart';
import 'package:beam/ui/state/app_state.dart';
import 'package:beam/ui/state/store.dart';
import 'package:beam/ui/theme.dart';
import 'package:beam/core/utils.dart';

/// A widget that displays the queue of active, completed, and failed transfers.
class TransferQueueWidget extends StatelessWidget {
  const TransferQueueWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return PicoBuilder<AppState, List<TransferItem>>(
      store: store,
      selector: (state) => state.transfers,
      builder: (context, transfers) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transfers', style: BeamTextStyles.headline),
            const SizedBox(height: 16),
            if (transfers.isEmpty)
              _buildEmptyState()
            else
              Expanded(
                child: ListView.separated(
                  itemCount: transfers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = transfers[index];
                    return _TransferCard(item: item);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.swap_vert,
              size: 48,
              color: BeamColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No active transfers',
              style: BeamTextStyles.body.copyWith(color: BeamColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  final TransferItem item;

  const _TransferCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isSending = item.direction == TransferDirection.send;
    final directionIcon = isSending ? Icons.arrow_upward : Icons.arrow_downward;
    final fileName = UIUtils.truncateMiddle(item.fileName, maxLength: 28);
    
    double progress = 0.0;
    if (item.totalBytes > 0) {
      progress = item.transferredBytes / item.totalBytes;
      if (progress > 1.0) progress = 1.0;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(directionIcon, size: 20, color: BeamColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fileName,
                    style: BeamTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                _buildStatusIndicator(),
              ],
            ),
            const SizedBox(height: 12),
            Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: BeamColors.background,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: item.status == TransferStatus.failed ? BeamColors.error : BeamColors.accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${UIUtils.formatBytes(item.transferredBytes)} / ${UIUtils.formatBytes(item.totalBytes)}',
                  style: BeamTextStyles.caption,
                ),
                if (item.status == TransferStatus.active)
                  Text(
                    '${UIUtils.formatSpeed(item.speedBytesPerSec)} • ~${item.eta.inSeconds}s left',
                    style: BeamTextStyles.caption,
                  ),
              ],
            ),
            if (item.status == TransferStatus.failed && item.errorReason != null) ...[
              const SizedBox(height: 8),
              Text(
                item.errorReason!,
                style: BeamTextStyles.caption.copyWith(color: BeamColors.error),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    switch (item.status) {
      case TransferStatus.active:
        return IconButton(
          icon: const Icon(Icons.close, color: BeamColors.textSecondary, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () {
            // Cancel transfer logic not implemented in backend yet, just placeholder
          },
        );
      case TransferStatus.completed:
        return const Icon(Icons.check_circle, color: BeamColors.success, size: 20);
      case TransferStatus.failed:
        return const Icon(Icons.error, color: BeamColors.error, size: 20);
    }
  }
}
