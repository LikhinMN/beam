import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper class to pick files on Android.
class FilePickerHelper {
  /// Requests necessary storage permissions.
  /// Handles the Android 13+ permission split by requesting media permissions
  /// along with standard storage permissions.
  static Future<bool> _requestPermissions() async {
    if (!Platform.isAndroid) return true;

    // Request older storage permissions
    final storage = await Permission.storage.request();
    
    // Request Android 13+ granular media permissions
    final photos = await Permission.photos.request();
    final videos = await Permission.videos.request();
    final audio = await Permission.audio.request();

    // If any of the relevant permissions are granted, we proceed.
    return storage.isGranted || photos.isGranted || videos.isGranted || audio.isGranted;
  }

  /// Opens the file picker allowing multiple file selection.
  /// Returns a list of dart:io File objects with valid paths.
  /// Handles permission denied gracefully by returning an empty list.
  static Future<List<File>> pickFiles() async {
    try {
      // file_picker uses the Android Storage Access Framework (SAF) which doesn't
      // require explicit READ_EXTERNAL_STORAGE permissions. The selected files are
      // automatically cached in the app's local cache directory.

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );

      if (result != null) {
        return result.files
            .where((f) => f.path != null)
            .map((f) {
              f.readStream?.drain();
              return File(f.path!);
            })
            .toList();
      }
    } catch (e) {
      print('Error picking files: $e');
    }
    
    return [];
  }
}
