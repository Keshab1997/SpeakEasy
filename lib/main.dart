import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_skill/flutter_skill.dart';
import 'firebase_options.dart';
import 'core/theme/light_theme.dart';
import 'core/theme/dark_theme.dart';
import 'services/api_key_manager.dart';
import 'services/hive_service.dart';
import 'services/notification_service.dart';
import 'services/onesignal_service.dart';
import 'package:workmanager/workmanager.dart';
import 'services/workmanager_tasks.dart';
import 'services/idle_tracker_service.dart';
import 'services/remote_config_service.dart';
import 'providers/theme_provider.dart';


import 'features/auth/screens/splash_screen.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    // Best-effort, non-blocking dev harness: initialize shortly after the
    // first frame so a missing/broken flutter-skill server can NEVER block
    // app startup or leave the splash hanging.
    unawaited(Future<void>.delayed(const Duration(seconds: 3), () {
      try {
        FlutterSkillBinding.ensureInitialized();
      } catch (e) {
        debugPrint('main: flutter_skill init failed — $e');
      }
    }));
  }

  // ── Essentials the splash screen needs on its very first frame ──
  // Bound every call with a timeout so a stuck platform/channel can NEVER
  // prevent runApp() from being reached (which would freeze the splash).
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 8));
    }
  } catch (e) {
    // If Firebase is already initialized, just log and continue
    debugPrint('main: Firebase init note — $e');
  }

  try {
    await HiveService.initialize().timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('main: Hive init failed/bounded — $e');
  }

  // Open the in-app update Hive box for snooze persistence
  try {
    await Hive.openBox('in_app_update').timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('main: in_app_update box open failed — $e');
  }

  ApiKeyManager.instance.initialize();

  // ── Show the app IMMEDIATELY. Everything below this point is best-effort
  //    and fire-and-forget (each bounded by a timeout) so a hung notification,
  //    OneSignal or WorkManager plugin can never leave the splash stuck. The
  //    SplashScreen has its own 2s/10s safety navigation as a backstop.
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );

  // Best-effort background service init — runs concurrently, never blocks UI.
  await _initBackgroundServices();
}

/// Initializes all non-essential, potentially-slow services AFTER the app has
/// rendered. Every operation is wrapped in its own timeout so that a hanging
/// native plugin (OneSignal permission dialog, WorkManager, notification
/// scheduling) degrades gracefully instead of freezing the splash screen.
Future<void> _initBackgroundServices() async {
  // Local notification system (uses native AlarmManager/UNUserNotificationCenter)
  try {
    await NotificationService()
        .initialize()
        .timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint('main: Notification init failed/bounded — $e');
  }

  // Reschedule daily notifications on app open
  try {
    await NotificationService()
        .rescheduleOnAppOpen()
        .timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint('main: rescheduleOnAppOpen failed/bounded — $e');
  }

  // Initialize OneSignal for push notifications
  try {
    await _initOneSignal().timeout(const Duration(seconds: 15));
  } catch (e) {
    debugPrint('main: OneSignal init failed/bounded — $e');
  }

  // WorkManager background notification tasks
  try {
    await Workmanager()
        .initialize(workmanagerCallbackDispatcher)
        .timeout(const Duration(seconds: 10));

    // Register daily re-engagement check task
    await Workmanager()
        .registerPeriodicTask(
          'reEngagement',
          reEngagementTaskName,
          frequency: const Duration(hours: 24),
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        )
        .timeout(const Duration(seconds: 5));

    // Register idle reminder background check (every 6 hours)
    await Workmanager()
        .registerPeriodicTask(
          'idleReminder',
          idleReminderTaskName,
          frequency: const Duration(hours: 6),
          constraints: Constraints(
            networkType: NetworkType.notRequired,
          ),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        )
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('main: WorkManager init failed/bounded — $e');
  }

  // Track app open for re-engagement logic + idle tracker
  try {
    await HiveService.setLastAppOpenDate(DateTime.now());
    await IdleTrackerService.recordActivity();
  } catch (e) {
    debugPrint('main: app-open tracking failed — $e');
  }

  // Pre-warm remote config cache on app start
  try {
    await RemoteConfigService.seedDefaultConfig();
  } catch (e) {
    debugPrint('main: remote config seed failed — $e');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'SpeakEasy',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}

/// Initializes OneSignal push notifications.
///
/// Reads the OneSignal App ID from the Firestore config document
/// (`Config/app_settings → onesignal.AppId`). If the config is missing or the
/// App ID is empty, OneSignal initialization is skipped gracefully.
Future<void> _initOneSignal() async {
  var appId = '';

  // 1) Try the live Firestore config first (lets admins update the App ID
  //    remotely without shipping a new release).
  try {
    final doc = await FirebaseFirestore.instance
        .collection('Config')
        .doc('app_settings')
        .get()
        .timeout(const Duration(seconds: 8));

    if (doc.exists) {
      final data = doc.data();
      final onesignalRaw = data?['onesignal'];
      final onesignalConfig = onesignalRaw as Map<String, dynamic>?;
      appId = onesignalConfig?['AppId'] as String? ?? '';
      debugPrint('main: resolved appId="$appId" from Firestore');

      if (appId.isNotEmpty) {
        // Cache it so offline launches can still init push.
        await HiveService.setCachedOneSignalAppId(appId);
      }
    } else {
      debugPrint('main: app_settings doc not found in Config collection');
    }
  } catch (e) {
    debugPrint('main: Firestore config unavailable ($e) — trying cache');
  }

  // 2) Fallback to the cached App ID from a previous successful launch.
  //    Without this, an offline/slow first run would silently skip OneSignal
  //    init and the device would never register for push until the next open.
  if (appId.isEmpty) {
    appId = HiveService.getCachedOneSignalAppId() ?? '';
    if (appId.isNotEmpty) {
      debugPrint('main: using cached appId="$appId"');
    } else {
      debugPrint('main: no OneSignal App ID available (Firestore + cache empty)');
    }
  }

  await OneSignalService().initialize(appId);
}
