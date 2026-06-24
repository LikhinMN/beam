import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Helper class to manage storage directories on Linux.
class StorageHelper {
  /// Gets the default download directory on Linux.
  /// 1. Checks $XDG_DOWNLOAD_DIR env variable.
  /// 2. Falls back to $HOME/Downloads.
  /// 3. Falls back to app documents directory.
  static Future<Directory> getDefaultDownloadDirectory() async {
    try {
      // 1. Check XDG_DOWNLOAD_DIR
      final xdgDownloadDir = Platform.environment['XDG_DOWNLOAD_DIR'];
      if (xdgDownloadDir != null && xdgDownloadDir.isNotEmpty) {
        final dir = Directory(xdgDownloadDir);
        if (await dir.exists()) {
          return dir;
        }
      }

      // 2. Fallback to $HOME/Downloads
      final homeDir = Platform.environment['HOME'];
      if (homeDir != null && homeDir.isNotEmpty) {
        final dir = Directory('$homeDir/Downloads');
        if (await dir.exists()) {
          return dir;
        }
      }
    } catch (e) {
      print('Error finding Linux download directory: $e');
    }

    // 3. Fallback to app documents directory
    return await getApplicationDocumentsDirectory();
  }
}
