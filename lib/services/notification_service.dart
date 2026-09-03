import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'hive_service.dart';
import 'daily_word_service.dart';
import 'dart:math';
import '../models/notification_history_model.dart';
import '../core/navigation/app_navigator.dart';
import '../features/home/widgets/notification_router.dart';

/// Handles a notification tap that arrives while the app is in the background
/// or terminated. Must be a top-level function tagged with `vm:entry-point`
/// so the Dart VM keeps it after tree-shaking.
///
/// The background isolate cannot touch the widget tree, so we only persist the
/// payload; the UI isolate picks it up on the next launch/resume via
/// [NotificationService.handleAppLaunchNotification].
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  // Best-effort: Hive may not be open in this isolate, so failures are ignored.
  try {
    HiveService.setPendingNotificationPayload(payload);
  } catch (_) {}
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Notification IDs
  static const int _dailyWordId = 1000;
  static const int _practiceReminderId = 1001;
  static const int _streakMilestoneId = 1002;
  static const int _streakAtRiskId = 1003;
  static const int _idleReminderId = 1004;

  bool get isInitialized => _initialized;

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  Future<void> initialize() async {
    if (_initialized) return;

    await _initPlugin();

    _initialized = true;

    // Request permissions on first launch (for Android 13+ and iOS)
    await requestPermissions();

    // Schedule daily repeating notifications using native scheduler
    if (HiveService.isNotificationEnabled()) {
      await _scheduleAll();
    }
  }

  /// Background-isolate-safe initialization.
  ///
  /// WorkManager runs task handlers in a separate isolate where there is **no
  /// Activity**, so [requestPermissions] (which needs one) can fail or hang,
  /// and [_scheduleAll] would perform a network call (Word of the Day) right
  /// after cancelling every pending alarm — if that call throws, the user ends
  /// up with *no* scheduled notifications at all.
  ///
  /// This variant only prepares the plugin + channels so background tasks can
  /// safely call `show()`.
  Future<void> initializeForBackground() async {
    if (_initialized) return;
    await _initPlugin();
    _initialized = true;
  }

  /// Shared plugin/channel setup used by both foreground and background init.
  Future<void> _initPlugin() async {
    // Initialize timezone data and use India time for the daily reminder clock.
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      // Taps that arrive while the app is killed/background land here.
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Explicitly create all notification channels with proper sound settings.
    // Using new channel IDs (_v2) because Android channels are immutable once created.
    // This ensures all channels have Importance.high + sound enabled.
    await _createNotificationChannels();
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    // Mark notification as read when tapped
    _markNotificationAsReadByPayload(payload);

    // Try to navigate based on payload
    _navigateFromPayload(payload);
  }

  /// Maps a local-notification payload to a [NotificationRouter] action type.
  static String? _actionTypeForPayload(String payload) {
    if (payload.startsWith('daily_word')) return 'vocabulary';
    if (payload.startsWith('practice_reminder')) return 'game';
    if (payload.startsWith('streak_saver') ||
        payload.startsWith('streak_milestone')) {
      return 'game';
    }
    if (payload.contains('re_engagement') || payload.contains('idle_reminder')) {
      return 'game';
    }
    return null;
  }

  void _navigateFromPayload(String payload) {
    try {
      // Prefer the exact history entry (it can carry actionType/actionPayload
      // coming from an admin push); fall back to a payload→screen mapping.
      NotificationHistoryItem? matched;
      for (final json in HiveService.getNotificationHistory()) {
        if (json['payload'] == payload) {
          matched = NotificationHistoryItem.fromJson(json);
          break;
        }
      }

      final actionType = matched?.actionType ?? _actionTypeForPayload(payload);
      if (actionType == null) return;

      final item = (matched ??
              NotificationHistoryItem(
                id: payload,
                title: '',
                body: '',
                type: payload,
                receivedAt: DateTime.now(),
                payload: payload,
              ))
          .copyWith(actionType: actionType);

      // The navigator may not exist yet if the app is cold-starting; retry
      // after the first frame.
      void go() {
        final context = appNavigatorContext;
        if (context == null) return;
        NotificationRouter.navigate(context, item);
      }

      if (appNavigatorContext != null) {
        go();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => go());
      }
    } catch (e) {
      debugPrint('NotificationService: navigation from payload failed — $e');
    }
  }

  /// Handles a notification that launched the app from a terminated state, plus
  /// any payload stashed by the background tap handler. Call this once the UI
  /// is ready (after `runApp`).
  Future<void> handleAppLaunchNotification() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      final launchPayload = details?.didNotificationLaunchApp == true
          ? details?.notificationResponse?.payload
          : null;

      final pending = HiveService.getPendingNotificationPayload();
      final payload = launchPayload ?? pending;
      if (pending != null) {
        await HiveService.clearPendingNotificationPayload();
      }
      if (payload == null || payload.isEmpty) return;

      _markNotificationAsReadByPayload(payload);
      _navigateFromPayload(payload);
    } catch (e) {
      debugPrint('NotificationService: launch-details handling failed — $e');
    }
  }

  void _markNotificationAsReadByPayload(String payload) {
    final history = HiveService.getNotificationHistory();
    for (final notification in history) {
      if (notification['payload'] == payload && notification['isRead'] != true) {
        HiveService.markNotificationAsRead(notification['id']);
        break;
      }
    }
  }

  /// Save notification to history
  Future<void> _saveNotificationToHistory({
    required String title,
    required String body,
    required String type,
    String? payload,
  }) async {
    final notification = {
      'id': '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
      'title': title,
      'body': body,
      'type': type,
      'receivedAt': DateTime.now().toIso8601String(),
      'isRead': false,
      'payload': payload,
    };
    await HiveService.saveNotificationToHistory(notification);
  }

  /// Opens the OS app-settings screen so the user can grant notification
  /// permission if it was permanently denied (Android 13+). Best-effort:
  /// uses the existing native `openAppDetailsSettings` MethodChannel handler
  /// in MainActivity; silently no-ops if the call is unsupported.
  Future<bool> openAppNotificationSettings() async {
    try {
      const channel = MethodChannel('com.speakeasy.english.learn/device');
      final result = await channel
          .invokeMethod<bool>('openAppDetailsSettings')
          .timeout(const Duration(seconds: 5));
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Returns true when the OS-level notification permission is currently
  /// granted. On Android <13 (no runtime permission) this is treated as
  /// granted. Useful for detecting a permanently-denied state.
  Future<bool> areNotificationsEnabled() async {
    try {
      final androidPlatform = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        final enabled = await androidPlatform.areNotificationsEnabled();
        return enabled ?? true;
      }
      return true;
    } catch (_) {
      // If the platform call is unsupported, assume allowed and proceed.
      return true;
    }
  }

  /// Request notification permissions (Android 13+ and iOS).
  ///
  /// Returns `true` when notifications can be shown. When the OS reports the
  /// permission is denied *and* can no longer be prompted (permanently
  /// denied), it attempts to open the app settings screen so the user can
  /// re-enable it there.
  Future<bool> requestPermissions() async {
    try {
      final androidPlatform = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        final granted = await androidPlatform.requestNotificationsPermission();
        if (granted != true) {
          // Detect permanently-denied state: if the OS says notifications are
          // globally disabled AND a re-prompt is no longer possible, guide the
          // user to settings instead of silently failing.
          final enabled = await areNotificationsEnabled();
          if (!enabled) {
            await openAppNotificationSettings();
          }
          return false;
        }

        final canScheduleExact = await androidPlatform.canScheduleExactNotifications();
        if (canScheduleExact == false) {
          await androidPlatform.requestExactAlarmsPermission();
        }
      }

      final iosPlatform = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlatform != null) {
        final granted = await iosPlatform.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        if (granted != true) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Create all notification channels with proper sound settings.
  /// Using new channel IDs (_v2) because Android notification channels are immutable
  /// once created — old channels created without sound must be replaced.
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    const channels = [
      AndroidNotificationChannel(
        'daily_word_v2',
        'Word of the Day',
        description: 'Daily word learning notifications',
        importance: Importance.high,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'practice_reminder_v2',
        'Practice Reminder',
        description: 'Reminders to practice English',
        importance: Importance.high,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'streak_saver_v2',
        'Streak Saver',
        description: 'Streak at risk notifications',
        importance: Importance.high,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'streak_milestone_v2',
        'Streak Milestone',
        description: 'Streak achievement celebrations',
        importance: Importance.high,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'general_v2',
        'General Notifications',
        description: 'General app notifications',
        importance: Importance.high,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'background_alerts_v2',
        'Background Alerts',
        description: 'Notifications delivered in background',
        importance: Importance.high,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'speakeasy_idle_reminder_v2',
        'Idle Reminder',
        description: 'User re-engagement reminders',
        importance: Importance.high,
        playSound: true,
      ),
      // OneSignal channel: created here but used by OneSignal native SDK
      // via onesignal_notification_service_channel_id in AndroidManifest.xml
      AndroidNotificationChannel(
        'speakeasy_onesignal_channel',
        'SpeakEasy Push',
        description: 'Push notifications from SpeakEasy',
        importance: Importance.high,
        playSound: true,
      ),
    ];

    for (final channel in channels) {
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  // ─── Show Immediate Notifications (for in-app use while streak) ───

  Future<void> showStreakMilestoneNotification(int streak) async {
    try {
      final title = '🔥 $streak Day Streak!';
      const body = 'Amazing! Keep up your daily practice to maintain your streak.';
      
      const androidDetails = AndroidNotificationDetails(
        'streak_milestone_v2',
        'Streak Milestone',
        channelDescription: 'Celebrate your streak milestones',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
      );
      const details = NotificationDetails(android: androidDetails);
      await _plugin.show(
        _streakMilestoneId,
        title,
        body,
        details,
        payload: 'streak_milestone',
      );
      
      // Save to history
      await _saveNotificationToHistory(
        title: title,
        body: body,
        type: 'streak_milestone',
        payload: 'streak_milestone',
      );
    } catch (_) {}
  }

  // ─── Schedule via Native AlarmManager / UNUserNotificationCenter ───
  // These work even when app is closed!

  /// Cancel all pending scheduled notifications
  Future<void> cancelAllScheduled() async {
    await _plugin.cancel(_dailyWordId);
    await _plugin.cancel(_practiceReminderId);
    await _plugin.cancel(_streakMilestoneId);
    await _plugin.cancel(_streakAtRiskId);
    await _plugin.cancel(_idleReminderId);
  }

  /// Schedule all notifications (respects sub-toggles from Hive)
  Future<void> _scheduleAll() async {
    // Cancel old scheduled ones first, then reschedule
    await cancelAllScheduled();

    if (!HiveService.isNotificationEnabled()) return;

    // Schedule Word of the Day at 9:00 AM (if enabled)
    if (HiveService.isDailyWordNotification()) {
      const richTitle = '📚 Word of the Day';
      // Generic fallback text — used when today's word can't be fetched
      // (offline / background isolate). Never leave the slot unscheduled.
      var richBody = 'আজকের নতুন শব্দটি দেখে নিন! 📖';
      BigTextStyleInformation? bigText;

      try {
        // Fetch today's word for the rich notification content
        final todayWord = await DailyWordService.getTodayWord();
        richBody = '${todayWord.word} → ${todayWord.banglaMeaning}';
        bigText = BigTextStyleInformation(
          '''
📖 *${todayWord.word}*${todayWord.pronunciation != null ? ' (${todayWord.pronunciation})' : ''}
━━━━━━━━━━━━━━━━
🔤 বাংলা অর্থ: ${todayWord.banglaMeaning}

📝 উদাহরণ:
${todayWord.exampleSentence}
━━━━━━━━━━━━━━━━
ℹ️ বিস্তারিত জানতে Tap করুন
            ''',
          contentTitle: richTitle,
          summaryText: richBody,
        );
      } catch (e) {
        debugPrint('NotificationService: Word of the Day fetch failed, '
            'scheduling generic body — $e');
      }

      try {
        await _scheduleDailyAt(
          id: _dailyWordId,
          hour: 9,
          minute: 0,
          channelId: 'daily_word_v2',
          channelName: 'Word of the Day',
          title: richTitle,
          body: richBody,
          payload: 'daily_word',
          isHighPriority: true,
          bigTextStyle: bigText,
        );
      } catch (e) {
        debugPrint('NotificationService: failed to schedule Word of the Day — $e');
      }
    }

    // Schedule Practice Reminder at 7:00 PM (if enabled)
    if (HiveService.isPracticeReminderNotification()) {
      await _scheduleDailyAt(
        id: _practiceReminderId,
        hour: 19,
        minute: 0,
        channelId: 'practice_reminder_v2',
        channelName: 'Practice Reminder',
        title: '⏰ Time to Practice! 🎯',
        body: "Don't break your streak! Practice English for 5 minutes.",
        payload: 'practice_reminder',
        isHighPriority: false,
      );
    }

    // Schedule Streak Saver at 8:00 PM (if streak notifications enabled)
    if (HiveService.isStreakNotification()) {
      final currentStreak = HiveService.getStreak();
      final streakMessage = currentStreak > 0
          ? '🔥 আপনার $currentStreak দিনের স্ট্রিক ভাঙার পথে! এখনই প্র্যাকটিস শুরু করুন!'
          : '🔥 আজকে কি প্র্যাকটিস করেছেন? স্ট্রিক ধরে রাখুন!';
      await _scheduleDailyAt(
        id: _streakAtRiskId,
        hour: 20,
        minute: 0,
        channelId: 'streak_saver_v2',
        channelName: 'Streak Saver',
        title: '⚠️ Streak at Risk!',
        body: streakMessage,
        payload: 'streak_saver',
        isHighPriority: true,
      );
    }
  }

  /// Schedule a notification that repeats daily at a specific time.
  /// [bigTextStyle] when provided renders an expandable rich notification.
  Future<void> _scheduleDailyAt({
    required int id,
    required int hour,
    required int minute,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required bool isHighPriority,
    String? payload,
    BigTextStyleInformation? bigTextStyle,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      styleInformation: bigTextStyle, // null → default small style
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      // Prefer an exact alarm so the notification fires on time even in Doze.
      // On Android 14+ the user can revoke "Alarms & reminders" at any time —
      // in that case an exact schedule throws and the notification would be
      // lost entirely, so fall back to the inexact (but always allowed) mode.
      androidScheduleMode: await _resolveScheduleMode(),
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Picks the strongest schedule mode the OS currently permits.
  Future<AndroidScheduleMode> _resolveScheduleMode() async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin == null) return AndroidScheduleMode.exactAllowWhileIdle;
      final canExact = await androidPlugin.canScheduleExactNotifications();
      return canExact == false
          ? AndroidScheduleMode.inexactAllowWhileIdle
          : AndroidScheduleMode.exactAllowWhileIdle;
    } catch (_) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  // ─── Update Notification Settings ───

  /// Enable/disable all notifications
  Future<void> updateNotificationEnabled(bool enabled) async {
    await HiveService.setNotificationEnabled(enabled);
    if (enabled) {
      await requestPermissions();
      await _scheduleAll();
    } else {
      await cancelAllScheduled();
    }
  }

  /// Schedule notification on next app launch (called from main)
  Future<void> rescheduleOnAppOpen() async {
    if (!HiveService.isNotificationEnabled()) return;
    // Request permissions again if needed (in case user revoked).
    // requestPermissions() already opens app settings when the OS reports
    // notifications are permanently disabled.
    await requestPermissions();
    if (!await areNotificationsEnabled()) {
      // Without the OS permission the scheduled notifications would never
      // display, so skip scheduling and let the user re-enable in settings.
      return;
    }
    await _scheduleAll();
  }

  /// Re-applies the current Hive preferences to the OS scheduler *immediately*.
  ///
  /// Call this from every settings toggle. Unlike [rescheduleOnAppOpen] it does
  /// **not** re-request permissions (which would pop a dialog / settings screen
  /// on every switch flip) — it just cancels and re-schedules, so turning a
  /// sub-toggle off actually stops the already-registered repeating alarm.
  Future<void> rescheduleNow() async {
    if (!_initialized) {
      await initialize();
      return;
    }
    if (!HiveService.isNotificationEnabled()) {
      await cancelAllScheduled();
      return;
    }
    await _scheduleAll();
  }

  /// Refreshes only the Word of the Day slot with today's word.
  ///
  /// `zonedSchedule(matchDateTimeComponents: time)` repeats the *same text*
  /// every day, so without this the notification would show a frozen word for
  /// users who don't open the app. Called daily by a WorkManager task.
  Future<void> refreshDailyWordSchedule() async {
    if (!HiveService.isNotificationEnabled()) return;
    if (!HiveService.isDailyWordNotification()) return;

    try {
      final todayWord = await DailyWordService.getTodayWord();
      const richTitle = '📚 Word of the Day';
      final richBody = '${todayWord.word} → ${todayWord.banglaMeaning}';

      await _plugin.cancel(_dailyWordId);
      await _scheduleDailyAt(
        id: _dailyWordId,
        hour: 9,
        minute: 0,
        channelId: 'daily_word_v2',
        channelName: 'Word of the Day',
        title: richTitle,
        body: richBody,
        payload: 'daily_word',
        isHighPriority: true,
        bigTextStyle: BigTextStyleInformation(
          '''
📖 *${todayWord.word}*${todayWord.pronunciation != null ? ' (${todayWord.pronunciation})' : ''}
━━━━━━━━━━━━━━━━
🔤 বাংলা অর্থ: ${todayWord.banglaMeaning}

📝 উদাহরণ:
${todayWord.exampleSentence}
━━━━━━━━━━━━━━━━
ℹ️ বিস্তারিত জানতে Tap করুন
            ''',
          contentTitle: richTitle,
          summaryText: richBody,
        ),
      );
    } catch (e) {
      debugPrint('NotificationService: daily word refresh failed — $e');
    }
  }

  // ─── History backfill for OS-scheduled notifications ───

  /// Daily slots that are delivered by the OS scheduler. Because the alarm can
  /// fire while the app process is dead, no Dart code runs at delivery time and
  /// nothing can be written to the history box. We therefore reconstruct the
  /// entries the next time the app runs.
  static const List<Map<String, dynamic>> _dailySlots = [
    {
      'type': 'daily_word',
      'hour': 9,
      'title': '📚 Word of the Day',
      'body': 'আজকের নতুন শব্দটি দেখে নিন! 📖',
      'payload': 'daily_word',
    },
    {
      'type': 'practice_reminder',
      'hour': 19,
      'title': '⏰ Time to Practice! 🎯',
      'body': "Don't break your streak! Practice English for 5 minutes.",
      'payload': 'practice_reminder',
    },
    {
      'type': 'streak_saver',
      'hour': 20,
      'title': '⚠️ Streak at Risk!',
      'body': '🔥 আজকে কি প্র্যাকটিস করেছেন? স্ট্রিক ধরে রাখুন!',
      'payload': 'streak_saver',
    },
  ];

  bool _isSlotEnabled(String type) {
    switch (type) {
      case 'daily_word':
        return HiveService.isDailyWordNotification();
      case 'practice_reminder':
        return HiveService.isPracticeReminderNotification();
      case 'streak_saver':
        return HiveService.isStreakNotification();
      default:
        return false;
    }
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Adds history entries for every daily notification slot that has already
  /// fired since the last time this ran (max 7 days back). Entries are
  /// de-duplicated by a deterministic id (`daily_word_2026-08-27`), so calling
  /// it on every resume is safe.
  Future<void> backfillScheduledHistory() async {
    try {
      if (!HiveService.isNotificationEnabled()) return;

      final now = DateTime.now();
      final last = HiveService.getLastHistoryBackfillDate();
      // First run: only look at today, so existing users don't get a week of
      // notifications dumped into their history at once.
      final since = last ?? DateTime(now.year, now.month, now.day);
      final from = now.difference(since).inDays > 7
          ? now.subtract(const Duration(days: 7))
          : since;

      for (var day = DateTime(from.year, from.month, from.day);
          !day.isAfter(DateTime(now.year, now.month, now.day));
          day = day.add(const Duration(days: 1))) {
        for (final slot in _dailySlots) {
          final type = slot['type'] as String;
          if (!_isSlotEnabled(type)) continue;

          final firedAt = DateTime(day.year, day.month, day.day, slot['hour'] as int);
          if (firedAt.isAfter(now)) continue; // hasn't fired yet today
          if (firedAt.isBefore(since)) continue; // already covered

          await HiveService.saveNotificationToHistoryIfNew({
            'id': '${type}_${_dateKey(day)}',
            'title': slot['title'],
            'body': slot['body'],
            'type': type,
            'receivedAt': firedAt.toIso8601String(),
            'isRead': false,
            'payload': slot['payload'],
          });
        }
      }

      await HiveService.setLastHistoryBackfillDate(now);
    } catch (e) {
      debugPrint('NotificationService: history backfill failed — $e');
    }
  }

  /// Show custom notification immediately (for in-app use)
  Future<void> showCustomNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'general_v2',
        'General Notifications',
        channelDescription: 'General app notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
      );
      const details = NotificationDetails(android: androidDetails);
      await _plugin.show(id, title, body, details, payload: payload);
      
      // Save to history
      await _saveNotificationToHistory(
        title: title,
        body: body,
        type: 'custom',
        payload: payload,
      );
    } catch (_) {}
  }

  /// Shows a local notification immediately. Used by background tasks
  /// (WorkManager) and in-app re-engagement triggers.
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'background_alerts_v2',
        'Background Alerts',
        channelDescription: 'Notifications delivered in background',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
      );
      const details = NotificationDetails(android: androidDetails);
      await _plugin.show(id, title, body, details, payload: payload);

      // Save to history
      await _saveNotificationToHistory(
        title: title,
        body: body,
        type: payload?.startsWith('type=re_engagement') == true
            ? 're_engagement'
            : payload?.startsWith('type=admin_announcement') == true
                ? 'admin_announcement'
                : 'custom',
        payload: payload,
      );
    } catch (_) {
      // Silently handle — background notification delivery is best-effort
    }
  }

  /// Schedule an idle reminder notification with custom sound
  Future<void> scheduleIdleReminder({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'speakeasy_idle_reminder_v2',
        'স্পিকইজি রিমাইন্ডার',
        channelDescription: 'ইউজারকে অ্যাপে ফিরিয়ে আনার জন্য রিমাইন্ডার',
        importance: Importance.high,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('speakeasy_notification'),
        icon: '@mipmap/ic_launcher',
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.show(
        _idleReminderId,
        title,
        body,
        details,
        payload: payload,
      );

      await _saveNotificationToHistory(
        title: title,
        body: body,
        type: 'idle_reminder',
        payload: payload,
      );
    } catch (_) {
      // Silently handle
    }
  }

  /// Cancel idle reminder notification
  Future<void> cancelIdleReminder() async {
    await _plugin.cancel(_idleReminderId);
  }

  /// Get notification history
  List<Map<String, dynamic>> getNotificationHistory() {
    return HiveService.getNotificationHistory();
  }

  /// Get unread notification count
  int getUnreadNotificationCount() {
    return HiveService.getUnreadNotificationCount();
  }
}
