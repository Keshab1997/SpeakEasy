import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'hive_service.dart';
import 'dart:math';

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

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data (required for zonedSchedule)
    tz_data.initializeTimeZones();

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

    _initialized = true;

    // Request permissions on first launch (for Android 13+ and iOS)
    await requestPermissions();

    // Schedule daily repeating notifications using native scheduler
    if (HiveService.isNotificationEnabled()) {
      _scheduleAll();
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap - could navigate to specific screen
    final payload = response.payload;
    if (payload == null) return;
    
    // Mark notification as read when tapped
    _markNotificationAsReadByPayload(payload);
    // Future: Navigate based on payload
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

  // ─── Show Immediate Notifications (for in-app use while streak) ───

  Future<void> showStreakMilestoneNotification(int streak) async {
    try {
      final title = '🔥 $streak Day Streak!';
      final body = 'Amazing! Keep up your daily practice to maintain your streak.';
      
      final androidDetails = AndroidNotificationDetails(
        'streak_milestone',
        'Streak Milestone',
        channelDescription: 'Celebrate your streak milestones',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      );
      final details = NotificationDetails(android: androidDetails);
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
  }

  /// Schedule all notifications (respects sub-toggles from Hive)
  void _scheduleAll() {
    // Cancel old scheduled ones first, then reschedule
    cancelAllScheduled();

    if (!HiveService.isNotificationEnabled()) return;

    // Schedule Word of the Day at 9:00 AM (if enabled)
    if (HiveService.isDailyWordNotification()) {
      _scheduleDailyAt(
        id: _dailyWordId,
        hour: 9,
        minute: 0,
        channelId: 'daily_word',
        channelName: 'Word of the Day',
        title: _getRandomWordTitle(),
        body: 'Tap to learn today\'s vocabulary word!',
        payload: 'daily_word',
        isHighPriority: true,
      );
    }

    // Schedule Practice Reminder at 7:00 PM (if enabled)
    if (HiveService.isPracticeReminderNotification()) {
      _scheduleDailyAt(
        id: _practiceReminderId,
        hour: 19,
        minute: 0,
        channelId: 'practice_reminder',
        channelName: 'Practice Reminder',
        title: '⏰ Time to Practice! 🎯',
        body: "Don't break your streak! Practice English for 5 minutes.",
        payload: 'practice_reminder',
        isHighPriority: false,
      );
    }
  }

  /// Schedule a notification that repeats daily at a specific time
  void _scheduleDailyAt({
    required int id,
    required int hour,
    required int minute,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required bool isHighPriority,
    String? payload,
  }) {
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
      importance: isHighPriority ? Importance.high : Importance.defaultImportance,
      priority: isHighPriority ? Priority.high : Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      // AndroidAlarmClock uses native AlarmManager (works when app closed)
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at same time
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
    
    // Note: Scheduled notifications will be added to history when they are actually delivered
    // Not when they are scheduled, to avoid cluttering history with future notifications
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
      _scheduleAll();
    } else {
      await cancelAllScheduled();
    }
  }

  /// Schedule notification on next app launch (called from main)
  Future<void> rescheduleOnAppOpen() async {
    if (!HiveService.isNotificationEnabled()) return;
    // Request permissions again if needed (in case user revoked)
    await requestPermissions();
    _scheduleAll();
  }

  /// Show custom notification immediately (for in-app use)
  Future<void> showCustomNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'general',
        'General Notifications',
        channelDescription: 'General app notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      );
      final details = NotificationDetails(android: androidDetails);
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

  /// Get notification history
  List<Map<String, dynamic>> getNotificationHistory() {
    return HiveService.getNotificationHistory();
  }

  /// Get unread notification count
  int getUnreadNotificationCount() {
    return HiveService.getUnreadNotificationCount();
  }
}
