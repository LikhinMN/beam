import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pico/pico.dart';
import 'package:beam/ui/theme.dart';
import 'package:beam/ui/state/app_state.dart';
import 'package:beam/ui/state/store.dart';
import 'package:beam/ui/state/actions.dart' as actions;
import 'package:beam/core/transfer_history.dart';
import 'package:beam/ui/widgets/history_entry_widget.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    actions.loadHistory();
  }

  void _clearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BeamColors.surface,
        title: Text('Clear History', style: BeamTextStyles.headline),
        content: Text(
          'Are you sure you want to clear all transfer history?',
          style: BeamTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: BeamTextStyles.body),
          ),
          ElevatedButton(
            onPressed: () {
              actions.clearHistory();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: BeamColors.error),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer History'),
        actions: [
          if (Platform.isLinux)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => actions.loadHistory(),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearHistory,
          ),
        ],
      ),
      body: PicoBuilder<AppState, AsyncValue<List<HistoryEntry>>>(
        store: store,
        selector: (state) => state.history,
        builder: (context, historyAsync) {
          if (historyAsync is AsyncLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (historyAsync is AsyncError) {
            return Center(
              child: Text(
                'Error loading history: ${(historyAsync as AsyncError).error}',
                style: BeamTextStyles.body.copyWith(color: BeamColors.error),
              ),
            );
          }

          final entries = historyAsync.valueOrNull ?? <HistoryEntry>[];

          if (entries.isEmpty) {
            return Center(
              child: Text(
                'No transfer history yet',
                style: BeamTextStyles.body.copyWith(color: BeamColors.textSecondary),
              ),
            );
          }

          Widget list = ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              return HistoryEntryWidget(entry: entries[index]);
            },
          );

          if (Platform.isAndroid) {
            return RefreshIndicator(
              onRefresh: () async {
                await actions.loadHistory();
              },
              child: list,
            );
          }

          return list;
        },
      ),
    );
  }
}
