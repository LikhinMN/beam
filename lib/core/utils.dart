import 'dart:math';

/// Utility methods for UI formatting.
class UIUtils {
  /// Converts a byte count to a human readable format (e.g. 24.3 MB).
  static String formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    int i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Converts a speed in bytes/sec to a human readable format.
  static String formatSpeed(double speedBytesPerSec) {
    if (speedBytesPerSec <= 0) return "0 B/s";
    const suffixes = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"];
    int i = (log(speedBytesPerSec) / log(1024)).floor();
    return '${(speedBytesPerSec / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Truncates a string in the middle with an ellipsis if it exceeds [maxLength].
  static String truncateMiddle(String text, {int maxLength = 28}) {
    if (text.length <= maxLength) return text;
    final partLength = (maxLength - 3) ~/ 2;
    return '${text.substring(0, partLength)}...${text.substring(text.length - partLength)}';
  }
}
