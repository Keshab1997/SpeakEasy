import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'hive_service.dart';
import 'daily_word_service.dart';
import 'dart:math';
import '../models/notification_history_model.dart';

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

  // Sample vocabulary words for daily notifications
  static const List<Map<String, String>> _sampleWords = [
    {'word': 'Eloquent', 'meaning': 'Fluent or persuasive in speaking'},
    {'word': 'Resilient', 'meaning': 'Able to recover quickly from difficulties'},
    {'word': 'Ambition', 'meaning': 'Strong desire to achieve something'},
    {'word': 'Diligent', 'meaning': 'Hardworking and careful'},
    {'word': 'Empathy', 'meaning': 'Ability to understand others\' feelings'},
    {'word': 'Gratitude', 'meaning': 'Feeling of thankfulness'},
    {'word': 'Persevere', 'meaning': 'Continue despite difficulties'},
    {'word': 'Confident', 'meaning': 'Feeling sure of oneself'},
    {'word': 'Curious', 'meaning': 'Eager to learn or know'},
    {'word': 'Generous', 'meaning': 'Willing to give and share'},
    {'word': 'Humble', 'meaning': 'Modest about one\'s importance'},
    {'word': 'Optimistic', 'meaning': 'Hopeful about the future'},
    {'word': 'Patient', 'meaning': 'Able to wait without frustration'},
    {'word': 'Sincere', 'meaning': 'Genuine and honest'},
    {'word': 'Thoughtful', 'meaning': 'Showing consideration for others'},
    {'word': 'Adaptable', 'meaning': 'Able to adjust to new conditions'},
    {'word': 'Brave', 'meaning': 'Ready to face danger or pain'},
    {'word': 'Creative', 'meaning': 'Using imagination to create'},
    {'word': 'Determined', 'meaning': 'Having firmness of purpose'},
    {'word': 'Enthusiastic', 'meaning': 'Showing intense enjoyment'},
    {'word': 'Friendly', 'meaning': 'Kind and pleasant'},
    {'word': 'Honest', 'meaning': 'Truthful and sincere'},
    {'word': 'Innovative', 'meaning': 'Introducing new ideas'},
    {'word': 'Joyful', 'meaning': 'Feeling great happiness'},
    {'word': 'Kind', 'meaning': 'Generous and caring'},
    {'word': 'Loyal', 'meaning': 'Faithful to commitments'},
    {'word': 'Mindful', 'meaning': 'Attentive and aware'},
    {'word': 'Noble', 'meaning': 'Having high moral qualities'},
    {'word': 'Organized', 'meaning': 'Arranged in a systematic way'},
    {'word': 'Passionate', 'meaning': 'Showing strong emotions'},
  ];

  bool get isInitialized => _initialized;

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  Future<void> initialize() async {
    if (_initialized) return;

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
    );

    // Explicitly create all notification channels with proper sound settings.
    // Using new channel IDs (_v2) because Android channels are immutable once created.
    // This ensures all channels have Importance.high + sound enabled.
    await _createNotificationChannels();

    _initialized = true;

    // Request permissions on first launch (for Android 13+ and iOS)
    await requestPermissions();

    // Schedule daily repeating notifications using native scheduler
    if (HiveService.isNotificationEnabled()) {
      await _scheduleAll();
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    // Mark notification as read when tapped
    _markNotificationAsReadByPayload(payload);

    // Try to navigate based on payload
    _navigateFromPayload(payload);
  }

  void _navigateFromPayload(String payload) {
    try {
      final history = HiveService.getNotificationHistory();
      for (final json in history) {
        if (json['payload'] == payload) {
          final item = NotificationHistoryItem.fromJson(json);
          // Navigation from system tray requires a global navigator key.
          // Since the app doesn't have one, navigation is handled when the user
          // opens the notification from the in-app history screen.
          // Log the intent for debugging.
          debugPrint('NotificationRouter would navigate to: ${item.actionType}');
          break;
        }
      }
    } catch (_) {
      // Silently handle — navigation from background is best-effort
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

  /// Request notification permissions (Android 13+ and iOS)
  Future<bool> requestPermissions() async {
    try {
      final androidPlatform = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        final granted = await androidPlatform.requestNotificationsPermission();
        if (granted != true) {
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
      try {
        // Fetch today's word for the rich notification content
        final todayWord = await DailyWordService.getTodayWord();
        final richTitle = '📚 Word of the Day';
        final richBody = '${todayWord.word} → ${todayWord.banglaMeaning}';

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
          ? "🔥 আপনার $currentStreak দিনের স্ট্রিক ভাঙার পথে! এখনই প্র্যাকটিস শুরু করুন!"
          : "🔥 আজকে কি প্র্যাকটিস করেছেন? স্ট্রিক ধরে রাখুন!";
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
      // Use inexactAllowWhileIdle for Doze mode compatibility
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Pick a random word for today's notification (called at schedule time)
  String _getRandomWordTitle() {
    final word = _sampleWords[DateTime.now().day % _sampleWords.length];
    return '📖 Word of the Day: ${word['word']}';
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
    // Request permissions again if needed (in case user revoked)
    await requestPermissions();
    await _scheduleAll();
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
      final androidDetails = AndroidNotificationDetails(
        'speakeasy_idle_reminder_v2',
        'স্পিকইজি রিমাইন্ডার',
        channelDescription: 'ইউজারকে অ্যাপে ফিরিয়ে আনার জন্য রিমাইন্ডার',
        importance: Importance.high,
        priority: Priority.high,
        sound: const RawResourceAndroidNotificationSound('speakeasy_notification'),
        icon: '@mipmap/ic_launcher',
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'speakeasy_notification.caf',
      );

      final details = NotificationDetails(
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
