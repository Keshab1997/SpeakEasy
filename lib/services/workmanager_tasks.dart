import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../firebase_options.dart';
import 'hive_service.dart';
import 'notification_service.dart';
import 're_engagement_service.dart';

/// Unique task names registered with WorkManager
const String reEngagementTaskName = 'reEngagementTask';

/// Unique notification IDs used by background tasks (avoid conflicts with
/// daily word (1000), practice reminder (1001), streak milestone (1002))
const int _reEngagementNotifId = 2001;

/// Initializes all required services when WorkManager runs in a background
/// isolate (i.e., after the app has been killed). In that scenario [main] is
/// never called, so Firebase, Hive, and the notification plugin must be set
/// up before any task handler runs.
Future<void> _initializeBackgroundServices() async {
  try {
    // On some Android versions the background isolate may inherit the
    // Firebase app from the main isolate, causing a duplicate-app error.
    // Check both apps.isEmpty and catch duplicate-app gracefully.
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      if (!e.toString().contains('[core/duplicate-app]')) {
        rethrow;
      }
      debugPrint('WorkManager: Firebase already initialized (duplicate-app ignored)');
    }
  } catch (e) {
    debugPrint('WorkManager: Firebase init failed — $e');
  }

  try {
    await HiveService.initialize();
  } catch (e) {
    debugPrint('WorkManager: Hive init failed — $e');
  }

  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('WorkManager: NotificationService init failed — $e');
  }
}

/// Entry point called by WorkManager for all background tasks.
/// Must be tagged with @pragma('vm:entry-point') so the Dart VM
/// keeps it during tree-shaking.
@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Critical: initialise all services before handling any task
      await _initializeBackgroundServices();

      switch (task) {
        case reEngagementTaskName:
          return await _handleReEngagement();
        default:
          return false;
      }
    } catch (e) {
      debugPrint('WorkManager: task "$task" failed — $e');
      return false;
    }
  });
}

/// Checks user inactivity and sends a motivational notification if the
/// user hasn't opened the app today.
Future<bool> _handleReEngagement() async {
  final result = await ReEngagementService.checkInactivity();
  if (result.shouldNotify) {
    final message = ReEngagementService.getMessage(result.daysInactive);
    final notifService = NotificationService();
    await notifService.showLocalNotification(
      id: _reEngagementNotifId,
      title: '⏰ ফিরে আসুন!',
      body: message,
      payload: 'type=re_engagement',
    );
  }
  return true;
}
