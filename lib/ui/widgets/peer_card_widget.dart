import 'dart:async';
import 'package:flutter/material.dart';
import 'package:beam/core/discovery.dart';
import 'package:beam/core/peer_state.dart';
import 'package:beam/ui/theme.dart';
import 'package:beam/ui/state/app_state.dart';

class PeerCardWidget extends StatefulWidget {
  final BeamPeer peer;
  final PeerState state;
  final TransferItem? activeTransfer;
  final VoidCallback onPairTap;
  final VoidCallback onConnectTap;
  final VoidCallback onCardTap;
  final VoidCallback onCancelTransferTap;

  const PeerCardWidget({
    super.key,
    required this.peer,
    required this.state,
    this.activeTransfer,
    required this.onPairTap,
    required this.onConnectTap,
    required this.onCardTap,
    required this.onCancelTransferTap,
  });

  @override
  State<PeerCardWidget> createState() => _PeerCardWidgetState();
}

class _PeerCardWidgetState extends State<PeerCardWidget> {
  Timer? _debounceTimer;

  void _debounced(VoidCallback action) {
    if (_debounceTimer?.isActive ?? false) return;
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {});
    action();
  }

  void _handleTap() {
    _debounced(() {
      if (widget.state == PeerState.discovered) {
        widget.onPairTap();
      } else if (widget.state == PeerState.connected) {
        widget.onCardTap();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    IconData platformIcon = Icons.device_unknown;
    if (widget.peer.platform == 'android') platformIcon = Icons.phone_android;
    if (widget.peer.platform == 'linux') platformIcon = Icons.computer;

    bool isConnected = widget.state == PeerState.connected || widget.state == PeerState.transferring;
    bool isOffline = widget.state == PeerState.offline;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isOffline ? 0.5 : 1.0,
      child: InkWell(
        onTap: (widget.state == PeerState.discovered || widget.state == PeerState.connected) ? _handleTap : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BeamColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isConnected ? const Color(0xFF00C2FF) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(platformIcon, color: BeamColors.textSecondary, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: RepaintBoundary(
                    key: ValueKey(widget.state),
                    child: _buildStateContent(),
                  ),
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateContent() {
    switch (widget.state) {
      case PeerState.discovered:
        return _buildBasicContent(
          key: const ValueKey('discovered'),
          dotColor: Colors.grey,
          subtitle: widget.peer.ip,
          trailing: OutlinedButton(
            onPressed: () => _debounced(widget.onPairTap),
            style: OutlinedButton.styleFrom(
              foregroundColor: BeamColors.accent,
              side: const BorderSide(color: BeamColors.accent),
            ),
            child: const Text('Pair'),
          ),
        );
      case PeerState.pairing:
        return _buildBasicContent(
          key: const ValueKey('pairing'),
          dotColor: Colors.transparent, // spinner instead
          subtitle: 'Pairing...',
          showSpinner: true,
        );
      case PeerState.trusted:
        return _buildBasicContent(
          key: const ValueKey('trusted'),
          dotColor: BeamColors.success,
          subtitle: widget.peer.ip,
          showPairedChip: true,
          trailing: ElevatedButton(
            onPressed: () => _debounced(widget.onConnectTap),
            style: ElevatedButton.styleFrom(
              backgroundColor: BeamColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Connect'),
          ),
        );
      case PeerState.connecting:
        return _buildBasicContent(
          key: const ValueKey('connecting'),
          dotColor: Colors.transparent,
          subtitle: 'Connecting...',
          showSpinner: true,
        );
      case PeerState.connected:
        return _buildBasicContent(
          key: const ValueKey('connected'),
          dotColor: const Color(0xFF00C2FF),
          subtitle: 'Connected',
        );
      case PeerState.transferring:
        return _buildTransferContent(key: const ValueKey('transferring'));
      case PeerState.offline:
        return _buildBasicContent(
          key: const ValueKey('offline'),
          dotColor: Colors.grey,
          subtitle: 'Offline',
        );
    }
  }

  Widget _buildBasicContent({
    required Key key,
    required Color dotColor,
    required String subtitle,
    Widget? trailing,
    bool showSpinner = false,
    bool showPairedChip = false,
  }) {
    return Row(
      key: key,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.peer.name,
                      style: BeamTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: widget.state == PeerState.offline ? Colors.grey : BeamColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (showPairedChip)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: BeamColors.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Paired', style: TextStyle(fontSize: 10, color: BeamColors.accent)),
                      ),
                    ),
                  if (showSpinner)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(BeamColors.accent)),
                      ),
                    ),
                ],
              ),
              Text(
                subtitle,
                style: BeamTextStyles.caption.copyWith(color: widget.state == PeerState.offline ? Colors.grey : BeamColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: trailing != null ? 90 : 12,
          child: trailing ?? (dotColor != Colors.transparent && !showSpinner
              ? Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null),
        ),
      ],
    );
  }

  Widget _buildTransferContent({required Key key}) {
    final transfer = widget.activeTransfer;
    final progress = transfer == null || transfer.totalBytes == 0
        ? 0.0
        : transfer.transferredBytes / transfer.totalBytes;
    
    final speed = transfer?.speedBytesPerSec ?? 0;
    final speedStr = speed > 1024 * 1024
        ? '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s'
        : '${(speed / 1024).toStringAsFixed(1)} KB/s';
    
    final etaStr = transfer?.eta.inSeconds != null ? '~${transfer!.eta.inSeconds}s remaining' : '';

    return Row(
      key: key,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.peer.name,
                      style: BeamTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: BeamColors.surface.withValues(alpha: 0.5),
                valueColor: const AlwaysStoppedAnimation<Color>(BeamColors.accent),
              ),
              const SizedBox(height: 4),
              Text(
                '$speedStr · $etaStr',
                style: BeamTextStyles.caption,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => _debounced(widget.onCancelTransferTap),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ),
      ],
    );
  }
}
