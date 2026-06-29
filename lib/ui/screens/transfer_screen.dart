import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:beam/ui/theme.dart';
import 'package:beam/core/discovery.dart';
import 'package:beam/ui/state/app_state.dart';
import 'package:pico/pico.dart';
import 'package:beam/ui/state/store.dart';
import 'package:beam/ui/state/actions.dart' as actions;
import 'package:beam/core/transfer_client.dart';
import 'package:beam/core/peer_state.dart';
import 'package:beam/android/file_picker_helper.dart';
import 'dart:io';
import 'dart:async';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:beam/core/speed_calculator.dart';
import 'package:beam/core/protocol.dart';
class TransferScreen extends StatefulWidget {
  final BeamPeer peer;

  const TransferScreen({super.key, required this.peer});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final List<File> _selectedFiles = [];
  bool _isSending = false;
  TransferClient? _client;
  final Map<String, SpeedCalculator> _speedCalcs = {};
  final TextEditingController _textController = TextEditingController();
  Timer? _textDebounce;

  @override
  void initState() {
    super.initState();
    _connect();
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _textController.text;
    if (store.state.sharedText == text) return;
    actions.setSharedText(text);
    
    _textDebounce?.cancel();
    _textDebounce = Timer(const Duration(milliseconds: 500), () {
      _client?.sendText(widget.peer.ip, widget.peer.port, text);
    });
  }

  Future<void> _connect() async {
    _client = TransferClient();
    _client!.events.listen((event) {
      final id = event.filePath ?? event.fileName ?? 'unknown_send';
      SpeedCalculator? calc = _speedCalcs[id];
      if (calc == null) {
        calc = SpeedCalculator();
        _speedCalcs[id] = calc;
      }

      TransferStatus status = TransferStatus.active;
      if (event.status.name == 'completed') status = TransferStatus.completed;
      if (event.status.name == 'failed') status = TransferStatus.failed;

      final transferred = event.bytesTransferred;
      calc.update(transferred);
      final totalBytes = event.totalBytes;

      actions.upsertTransfer(
        (
          id: id,
          fileName: event.fileName ?? 'Unknown',
          totalBytes: totalBytes,
          transferredBytes: transferred,
          speedBytesPerSec: calc.currentSpeed,
          eta: calc.eta(totalBytes > transferred ? totalBytes - transferred : 0),
          direction: TransferDirection.send,
          status: status,
          errorReason: event.error,
        ),
        peerName: widget.peer.name,
        peerIp: widget.peer.ip,
      );

      if (status != TransferStatus.active) {
        _speedCalcs.remove(id);
      }
    });
    actions.setPeerState(widget.peer.id, PeerState.connected);
  }

  @override
  void dispose() {
    _textDebounce?.cancel();
    _textController.dispose();
    _client?.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final files = await FilePickerHelper.pickFiles();
    if (files.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(files);
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _sendFiles() async {
    if (_selectedFiles.isEmpty) return;
    
    setState(() {
      _isSending = true;
    });

    try {
      await _client?.sendFiles(widget.peer.ip, widget.peer.port, _selectedFiles);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ Sent ${_selectedFiles.length} file(s)')),
      );
      setState(() {
        _selectedFiles.clear();
        _isSending = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send files: $e')),
      );
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<bool> _onWillPop() async {
    final hasActiveTransfers = store.state.transfers.any(
      (t) => t.status == TransferStatus.active
    );

    if (hasActiveTransfers) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Cancel transfer and disconnect?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Stay"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Disconnect"),
            ),
          ],
        ),
      );
      if (result == true) {
        actions.setPeerState(widget.peer.id, PeerState.offline);
        actions.setSharedText(null);
        return true;
      }
      return false;
    }
    actions.setPeerState(widget.peer.id, PeerState.offline);
    actions.setSharedText(null);
    return true;
  }

  Widget _buildSharedTextCard() {
    return PicoBuilder<AppState, String?>(
      store: store,
      selector: (state) => state.sharedText,
      builder: (context, sharedText) {
        if (sharedText != null && _textController.text != sharedText) {
          final cursorPos = _textController.selection;
          _textController.text = sharedText;
          if (cursorPos.start <= sharedText.length && cursorPos.end <= sharedText.length) {
            _textController.selection = cursorPos;
          } else {
            _textController.selection = TextSelection.collapsed(offset: sharedText.length);
          }
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Shared Text", style: BeamTextStyles.headline),
                    if (_textController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.copy, color: BeamColors.accent),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: _textController.text));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to clipboard')),
                          );
                        },
                      )
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _textController,
                  maxLines: 15,
                  minLines: 6,
                  decoration: InputDecoration(
                    hintText: "Type or paste text to share...",
                    hintStyle: BeamTextStyles.body.copyWith(color: BeamColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: BeamColors.accent, width: 2),
                    ),
                    filled: true,
                    fillColor: BeamColors.background,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSendCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Send Files", style: BeamTextStyles.headline),
                TextButton.icon(
                  onPressed: _isSending ? null : _pickFiles,
                  icon: const Icon(Icons.add, color: BeamColors.accent),
                  label: Text("Add", style: BeamTextStyles.body.copyWith(color: BeamColors.accent)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedFiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Text("No files selected", style: BeamTextStyles.body.copyWith(color: BeamColors.textSecondary)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedFiles.length,
                itemBuilder: (context, index) {
                  final file = _selectedFiles[index];
                  final name = p.basename(file.path);
                  final size = file.lengthSync();
                  
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.insert_drive_file, color: BeamColors.accent),
                    title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text("${(size / 1024 / 1024).toStringAsFixed(2)} MB"),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: BeamColors.textSecondary),
                      onPressed: _isSending ? null : () => _removeFile(index),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _selectedFiles.isEmpty || _isSending ? null : _sendFiles,
              child: _isSending
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Send Files"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransfersCard() {
    return PicoBuilder<AppState, List<TransferItem>>(
      store: store,
      selector: (state) => state.transfers.toList(),
      builder: (context, transfers) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Transfers", style: BeamTextStyles.headline),
                const SizedBox(height: 16),
                if (transfers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(
                      child: Text("Waiting for files...", style: BeamTextStyles.body.copyWith(color: BeamColors.textSecondary)),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transfers.length,
                    itemBuilder: (context, index) {
                      final t = transfers[index];
                      if (t.status == TransferStatus.active) {
                        final progress = t.totalBytes > 0 ? t.transferredBytes / t.totalBytes : 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(t.fileName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  Text(
                                    "${(t.speedBytesPerSec / 1024 / 1024).toStringAsFixed(1)} MB/s · ~${t.eta.inSeconds}s",
                                    style: BeamTextStyles.caption.copyWith(color: BeamColors.textSecondary),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: () {
                                      // Cancel logic
                                    },
                                  )
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: BeamColors.accent.withOpacity(0.2),
                                color: BeamColors.accent,
                              ),
                            ],
                          ),
                        );
                      }

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          t.status == TransferStatus.completed
                              ? Icons.check_circle
                              : Icons.error,
                          color: t.status == TransferStatus.completed
                              ? Colors.green
                              : Colors.red,
                        ),
                        title: Text(t.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          t.status == TransferStatus.completed
                              ? "${(t.totalBytes / 1024 / 1024).toStringAsFixed(2)} MB${t.direction == TransferDirection.send ? ' (Sent)' : ' (Received)'}"
                              : (t.errorReason ?? 'Failed'),
                        ),
                        trailing: TextButton(
                          onPressed: () {
                            if (t.errorReason != null && t.errorReason!.isNotEmpty) {
                              OpenFile.open(t.errorReason); 
                            } else {
                              OpenFile.open(t.fileName);
                            }
                          },
                          child: const Text("Open", style: TextStyle(color: BeamColors.accent)),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: BeamColors.background,
        appBar: AppBar(
          backgroundColor: BeamColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: BeamColors.textPrimary),
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) Navigator.of(context).pop();
              }
            },
          ),
          title: Text(widget.peer.name, style: BeamTextStyles.headline),
          centerTitle: true,
          actions: [
            PicoBuilder<AppState, PeerState?>(
              store: store,
              selector: (state) => state.peerStates[widget.peer.id],
              builder: (context, state) {
                final isConnected = state == PeerState.connected || state == PeerState.transferring;
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isConnected ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildSharedTextCard(),
              const SizedBox(height: 16),
              _buildSendCard(),
              const SizedBox(height: 16),
              _buildTransfersCard(),
            ],
          ),
        ),
      ),
    );
  }
}
