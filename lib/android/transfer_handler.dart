import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:beam/core/protocol.dart';
import 'package:beam/core/file_utils.dart';
import 'foreground_service.dart';
import 'storage_helper.dart';

/// Bridges the core transfer engine with Android-specific storage and notifications.
class TransferHandler {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Initializes the local notifications plugin.
  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    
    await _notificationsPlugin.initialize(initializationSettings);
  }

  /// Shows a standard system notification.
  static Future<void> _showSystemNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'beam_transfers',
      'Beam Transfers',
      channelDescription: 'Notifications for completed or failed transfers',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000, // Generate a unique ID
      title,
      body,
      platformChannelSpecifics,
    );
  }

  /// Handles incoming TransferEvents from the TransferServer.
  static Future<void> handleEvent(TransferEvent event) async {
    final fileName = event.fileName ?? 'Unknown file';
    
    switch (event.status) {
      case TransferEventType.started:
        await BeamForegroundService.updateNotification('Receiving $fileName — 0%');
        break;
        
      case TransferEventType.progress:
        final percentage = event.totalBytes > 0 
            ? ((event.bytesTransferred / event.totalBytes) * 100).toInt() 
            : 0;
        await BeamForegroundService.updateNotification('Receiving $fileName — $percentage%');
        break;
        
      case TransferEventType.completed:
        // Reset foreground service text
        await BeamForegroundService.updateNotification('Beam is ready to receive files');
        
        try {
          if (event.filePath != null) {
            final tempFile = File(event.filePath!);
            if (await tempFile.exists()) {
              // Retrieve downloads directory and sanitize/resolve file name
              final downloadsDir = await StorageHelper.getDownloadDirectory();
              final sanitizedName = FileUtils.sanitizeFileName(fileName);
              final finalName = FileUtils.resolveConflict(downloadsDir, sanitizedName);
              
              final finalPath = '${downloadsDir.path}${Platform.pathSeparator}$finalName';
              
              // Move file to the final destination (copy then delete to avoid cross-device link issues)
              await tempFile.copy(finalPath);
              await tempFile.delete(); 
              
              await _showSystemNotification('Transfer Complete', 'Received $finalName');
            }
          }
        } catch (e) {
          await _showSystemNotification('Transfer Error', 'Could not save $fileName: $e');
        }
        break;
        
      case TransferEventType.failed:
        // Reset foreground service text
        await BeamForegroundService.updateNotification('Beam is ready to receive files');
        await _showSystemNotification('Transfer Failed', 'Failed to receive $fileName');
        break;
    }
  }
}
