import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    FlutterSkillBinding.ensureInitialized();
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // If Firebase is already initialized, just log and continue
    debugPrint('main: Firebase init note — $e');
  }

  await HiveService.initialize();

  // Open the in-app update Hive box for snooze persistence
  await Hive.openBox('in_app_update');

  ApiKeyManager.instance.initialize();

  // Initialize local notification system (uses native AlarmManager/UNUserNotificationCenter)
  await NotificationService().initialize();
  // Reschedule daily notifications on app open
  await NotificationService().rescheduleOnAppOpen();

  // Initialize OneSignal for push notifications
  await _initOneSignal();

  // Initialize WorkManager for background notification tasks
  await Workmanager().initialize(
    workmanagerCallbackDispatcher,
    isInDebugMode: false,
  );

  // Register daily re-engagement check task
  await Workmanager().registerPeriodicTask(
    'reEngagement',
    reEngagementTaskName,
    frequency: const Duration(hours: 24),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  // Register idle reminder background check (every 6 hours)
  await Workmanager().registerPeriodicTask(
    'idleReminder',
    idleReminderTaskName,
    frequency: const Duration(hours: 6),
    constraints: Constraints(
      networkType: NetworkType.notRequired,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  // Track app open for re-engagement logic
  await HiveService.setLastAppOpenDate(DateTime.now());

  // Initialize idle tracker with initial activity timestamp
  await IdleTrackerService.recordActivity();

  // Pre-warm remote config cache on app start
  RemoteConfigService.seedDefaultConfig();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
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
        .get();

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
