import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/theme/light_theme.dart';
import 'core/theme/dark_theme.dart';
import 'services/hive_service.dart';
import 'services/notification_service.dart';
import 'services/onesignal_service.dart';
import 'package:workmanager/workmanager.dart';
import 'services/workmanager_tasks.dart';
import 'services/remote_config_service.dart';
import 'providers/theme_provider.dart';
import 'features/auth/screens/splash_screen.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );

  // Track app open for re-engagement logic
  await HiveService.setLastAppOpenDate(DateTime.now());

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
/// (`config/app_settings → onesignal.appId`). If the config is missing or the
/// App ID is empty, OneSignal initialization is skipped gracefully.
Future<void> _initOneSignal() async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('config')
        .doc('app_settings')
        .get();

    final onesignalConfig =
        doc.data()?['onesignal'] as Map<String, dynamic>?;
    final appId = onesignalConfig?['appId'] as String? ?? '';

    await OneSignalService().initialize(appId);
  } catch (e) {
    // Firestore might not be available (offline first launch).
    // OneSignal init is deferred — it will be retried on next app open.
    debugPrint('main: OneSignal init deferred — config not available ($e)');
  }
}
