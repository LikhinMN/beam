import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Helper class to manage storage directories and file names on Android.
class StorageHelper {
  /// Gets the Downloads directory on external storage.
  /// Falls back to the app documents directory if external storage is unavailable.
  static Future<Directory> getDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (dirs != null && dirs.isNotEmpty) {
          return dirs.first;
        }
      }
    } catch (e) {
      print('Failed to get external downloads directory: $e');
    }
    
    // Fallback if external downloads folder is not accessible
    return await getApplicationDocumentsDirectory();
  }

}
