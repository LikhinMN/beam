import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';

/// Handles drag-and-drop file events on Linux desktop.
class FileDropHandler {
  final _controller = StreamController<List<File>>.broadcast();

  /// Exposes a stream of dropped files.
  Stream<List<File>> get onFilesDropped => _controller.stream;

  /// Sets up a drop target for the entire app window.
  /// Wraps the main application widget with a [DropTarget].
  Widget init({required Widget child}) {
    if (!Platform.isLinux) return child;

    return DropTarget(
      onDragDone: (details) {
        final files = details.files
            .map((e) => File(e.path))
            // Filter out directories — only accept files
            .where((f) => FileSystemEntity.isFileSync(f.path))
            .toList();

        if (files.isNotEmpty) {
          _controller.add(files);
        }
      },
      child: child,
    );
  }

  /// Cleans up resources.
  void dispose() {
    _controller.close();
  }
}
