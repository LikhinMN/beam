import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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

  /// Sanitizes a file name for safe storage on the filesystem.
  /// - Strips leading dots.
  /// - Replaces path separators (/ \) with underscores.
  /// - Trims whitespace.
  /// - Truncates to a maximum of 200 characters.
  static String sanitizeFileName(String name) {
    // Trim whitespace
    String sanitized = name.trim();
    
    // Strip leading dots to prevent hidden files or traversal attempts
    while (sanitized.startsWith('.')) {
      sanitized = sanitized.substring(1);
    }
    
    // Replace path separators with underscores
    sanitized = sanitized.replaceAll('/', '_').replaceAll('\\', '_');
    
    // Truncate to 200 chars while attempting to preserve the file extension
    if (sanitized.length > 200) {
      final ext = p.extension(sanitized);
      final baseName = p.basenameWithoutExtension(sanitized);
      
      final charsLeft = 200 - ext.length;
      if (charsLeft > 0) {
        sanitized = baseName.substring(0, charsLeft) + ext;
      } else {
        // If the extension itself is too long, just truncate the whole string
        sanitized = sanitized.substring(0, 200);
      }
    }
    
    // Provide a default name if it becomes empty
    if (sanitized.isEmpty) {
      sanitized = 'unnamed_file';
    }
    
    return sanitized;
  }

  /// Resolves naming conflicts by appending an incremental counter.
  /// Ensures we never overwrite existing files.
  /// e.g. If "photo.jpg" exists, returns "photo_1.jpg", "photo_2.jpg", etc.
  static String resolveConflict(Directory dir, String fileName) {
    final baseName = p.basenameWithoutExtension(fileName);
    final ext = p.extension(fileName);
    
    String currentName = fileName;
    int counter = 1;
    
    while (File(p.join(dir.path, currentName)).existsSync()) {
      currentName = '${baseName}_$counter$ext';
      counter++;
    }
    
    return currentName;
  }
}
