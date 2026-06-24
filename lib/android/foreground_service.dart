import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(ForegroundTaskHandler());
}

/// Handler for the foreground task.
class ForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // The service has started.
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Required but unused
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Cleanup when the service is destroyed
  }
}

/// Helper class to manage the Android foreground service.
class BeamForegroundService {
  /// Initializes the foreground service settings.
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'beam_foreground_service',
        channelName: 'Beam Transfer Service',
        channelDescription: 'Keeps the TCP server running in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Starts the foreground service with the default ready message.
  static Future<void> start() async {
    if (await FlutterForegroundTask.isRunningService) {
      return;
    }
    await FlutterForegroundTask.startService(
      serviceId: 100,
      notificationTitle: 'Beam',
      notificationText: 'Beam is ready to receive files',
      callback: startCallback,
    );
  }

  /// Updates the notification text (e.g., during a file transfer).
  static Future<void> updateNotification(String text) async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Beam',
        notificationText: text,
      );
    }
  }

  /// Stops the foreground service cleanly when the app is explicitly closed.
  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
