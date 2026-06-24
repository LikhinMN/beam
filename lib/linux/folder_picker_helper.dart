import 'dart:io';
import 'package:file_selector/file_selector.dart';

/// Helper class to pick folders and files on Linux desktop.
class FolderPickerHelper {
  /// Opens the native Linux folder picker dialog.
  /// Returns the selected [Directory], or null if the user cancels.
  static Future<Directory?> pickDestinationFolder() async {
    final String? directoryPath = await getDirectoryPath();
    if (directoryPath == null) {
      return null; // User cancelled
    }
    return Directory(directoryPath);
  }

  /// Opens the native Linux file picker, allowing multiple selection.
  /// Returns a list of dart:io [File] objects.
  static Future<List<File>> pickFiles() async {
    final List<XFile> xFiles = await openFiles();
    return xFiles.map((xfile) => File(xfile.path)).toList();
  }
}
