# Notification Background Delivery Improvement Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add WorkManager-based background admin notification sync, re-engagement notifications for inactive users, rich Daily Word notifications, and improved scheduling reliability — without FCM.

**Architecture:** WorkManager handles background periodic tasks (admin Firestore sync every 15 min, re-engagement check daily). `NotificationService` enhanced with rich BigTextStyle Daily Word and `reEngagementService` for inactivity detection. Settings screen gets re-engagement toggle.

**Tech Stack:** Flutter, Riverpod, flutter_local_notifications, workmanager, Hive, Firestore

---

## File Structure

| File | Status | Responsibility |
|------|--------|----------------|
| `pubspec.yaml` | MODIFY | Add `workmanager` dependency |
| `lib/main.dart` | MODIFY | Initialize WorkManager, register background tasks |
| `lib/services/workmanager_tasks.dart` | CREATE | Background task definitions (AdminSync, ReEngagement) |
| `lib/services/re_engagement_service.dart` | CREATE | Inactivity check, message bank |
| `lib/services/daily_word_service.dart` | CREATE | Fetch today's word (Firestore → local fallback) |
| `lib/services/notification_service.dart` | MODIFY | Rich Daily Word, `showLocalNotification()`, enhanced scheduling |
| `lib/services/hive_service.dart` | MODIFY | Add `lastAppOpenDate` getter/setter, re-engagement toggle |
| `lib/services/admin_notification_sync_service.dart` | MODIFY | Return `newCount` from `syncLatest()` (already done) |
| `lib/providers/notification_provider.dart` | MODIFY | Handle background-synced state |
| `lib/features/settings/screens/settings_screen.dart` | MODIFY | Add re-engagement toggle |

---

### Task 1: Add `workmanager` Dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add workmanager to pubspec.yaml**

Add after the `flutter_local_notifications` line:

```yaml
  workmanager: ^0.5.2
```

- [ ] **Step 2: Install the package**

Run: `cd /Users/keshabsarkar/Vs\ Code\ Apps/Flutter-Spoken-English-App && flutter pub get`
Expected: Resolves and downloads workmanager successfully.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add workmanager dependency for background tasks"
```

---

### Task 2: Create `workmanager_tasks.dart`

**Files:**
- Create: `lib/services/workmanager_tasks.dart`

- [ ] **Step 1: Create the file with both background task definitions**

```dart
import 'package:workmanager/workmanager.dart';
import 'admin_notification_sync_service.dart';
import 'notification_service.dart';
import 're_engagement_service.dart';

/// Unique task names registered with WorkManager
const String adminSyncTaskName = 'adminSyncTask';
const String reEngagementTaskName = 'reEngagementTask';

/// Unique notification IDs used by background tasks (avoid conflicts with
/// daily word (1000), practice reminder (1001), streak milestone (1002))
const int _adminBgNotifId = 2000;
const int _reEngagementNotifId = 2001;

/// Entry point called by WorkManager for all background tasks.
/// Must be tagged with @pragma('vm:entry-point') so the Dart VM
/// keeps it during tree-shaking.
@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      switch (task) {
        case adminSyncTaskName:
          return await _handleAdminSync();
        case reEngagementTaskName:
          return await _handleReEngagement();
        default:
          return false;
      }
    } catch (_) {
      return false;
    }
  });
}

/// Fetches new admin notifications from Firestore and shows a local
/// notification if any were found.
Future<bool> _handleAdminSync() async {
  final newCount = await AdminNotificationSyncService.syncLatest();
  if (newCount > 0) {
    final notifService = NotificationService();
    await notifService.showLocalNotification(
      id: _adminBgNotifId,
      title: '📢 নতুন ঘোষণা',
      body: 'অ্যাডমিন একটি নতুন নোটিফিকেশন পাঠিয়েছেন',
      payload: 'type=admin_announcement',
    );
  }
  return true;
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/workmanager_tasks.dart
git commit -m "feat: add WorkManager background task definitions for admin sync and re-engagement"
```

---

### Task 3: Create `re_engagement_service.dart`

**Files:**
- Create: `lib/services/re_engagement_service.dart`

- [ ] **Step 1: Create the file**

```dart
import 'hive_service.dart';

class InactivityResult {
  final int daysInactive;
  final bool shouldNotify;

  const InactivityResult({
    this.daysInactive = 0,
    required this.shouldNotify,
  });
}

class ReEngagementService {
  /// Checks whether the user has been inactive and should receive a
  /// motivational notification. Uses [HiveService] to read the last
  /// app open date. Returns [InactivityResult] with the number of
  /// inactive days and whether a notification should be sent.
  static Future<InactivityResult> checkInactivity() async {
    final lastOpenDate = HiveService.getLastAppOpenDate();
    final now = DateTime.now();

    // If no record exists yet (first install), treat as active today
    if (lastOpenDate == null) {
      await HiveService.setLastAppOpenDate(now);
      return const InactivityResult(shouldNotify: false);
    }

    // Already opened today → skip notification
    if (lastOpenDate.year == now.year &&
        lastOpenDate.month == now.month &&
        lastOpenDate.day == now.day) {
      return const InactivityResult(shouldNotify: false);
    }

    // Re-engagement toggle off → skip
    if (!HiveService.isReEngagementEnabled()) {
      return InactivityResult(shouldNotify: false);
    }

    final daysInactive = now.difference(lastOpenDate).inDays;

    return InactivityResult(
      daysInactive: daysInactive,
      shouldNotify: daysInactive >= 1,
    );
  }

  /// Returns a motivational message tailored to how many days the user
  /// has been inactive. [userName] is optional — if empty, uses a generic
  /// greeting.
  static String getMessage(int daysInactive, {String userName = ''}) {
    final greeting = userName.isNotEmpty ? userName : '';
    final prefix = greeting.isNotEmpty ? '$greeting, ' : '';

    if (daysInactive == 1) {
      return '${prefix}আপনার আজকের একটি Daily Word অপেক্ষা করছে! 🎯';
    } else if (daysInactive == 2) {
      return '$prefix🔥 ২ দিন ধরে আসেননি! আপনার streak বাঁচান — মাত্র ১ মিনিট সময় নিন!';
    } else if (daysInactive <= 5) {
      return '$prefix💪 $daysInactive দিন হয়ে গেছে! নতুন অধ্যায় যোগ হয়েছে, শুরু করে দেখুন!';
    } else if (daysInactive <= 7) {
      return '$prefix⚡ এক সপ্তাহ! ছেড়ে দেবেন না — ছোট করে হলেও আজই শুরু করুন!';
    } else {
      return '$prefix🚀 $daysInactive দিন! ফিরতে কখনো দেরি হয় না — আপনার জন্য নতুন কন্টেন্ট অপেক্ষা করছে!';
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/re_engagement_service.dart
git commit -m "feat: add re-engagement service with inactivity check and message bank"
```

---

### Task 4: Create `daily_word_service.dart`

**Files:**
- Create: `lib/services/daily_word_service.dart`

- [ ] **Step 1: Create the file**

```dart
import 'dart:math';

class DailyWordData {
  final String word;
  final String banglaMeaning;
  final String exampleSentence;
  final String? pronunciation;

  const DailyWordData({
    required this.word,
    required this.banglaMeaning,
    required this.exampleSentence,
    this.pronunciation,
  });

  factory DailyWordData.fromMap(Map<String, dynamic> map) {
    return DailyWordData(
      word: map['word'] as String? ?? '',
      banglaMeaning: map['banglaMeaning'] as String? ?? '',
      exampleSentence: map['example'] as String? ?? '',
      pronunciation: map['pronunciation'] as String?,
    );
  }
}

class DailyWordService {
  /// Fallback vocabulary pool used when Firestore has no word for today.
  static const List<DailyWordData> _fallbackWords = [
    DailyWordData(word: 'Eloquent', banglaMeaning: 'স্পষ্টভাষী', exampleSentence: 'She gave an eloquent speech.'),
    DailyWordData(word: 'Resilient', banglaMeaning: 'স্থিতিস্থাপক', exampleSentence: 'Children are remarkably resilient.'),
    DailyWordData(word: 'Ambition', banglaMeaning: 'উচ্চাকাঙ্ক্ষা', exampleSentence: 'His ambition drove him to succeed.'),
    DailyWordData(word: 'Diligent', banglaMeaning: 'পরিশ্রমী', exampleSentence: 'Be diligent in your studies.'),
    DailyWordData(word: 'Empathy', banglaMeaning: 'সহমর্মিতা', exampleSentence: 'She showed great empathy for others.'),
    DailyWordData(word: 'Gratitude', banglaMeaning: 'কৃতজ্ঞতা', exampleSentence: 'Express gratitude every day.'),
    DailyWordData(word: 'Persevere', banglaMeaning: 'অটল থাকা', exampleSentence: 'Persevere through challenges.'),
    DailyWordData(word: 'Confident', banglaMeaning: 'আত্মবিশ্বাসী', exampleSentence: 'Be confident in your abilities.'),
    DailyWordData(word: 'Curious', banglaMeaning: 'কৌতূহলী', exampleSentence: 'Stay curious about the world.'),
    DailyWordData(word: 'Generous', banglaMeaning: 'উদার', exampleSentence: 'Be generous with your time.'),
    DailyWordData(word: 'Humble', banglaMeaning: 'বিনয়ী', exampleSentence: 'Stay humble and kind.'),
    DailyWordData(word: 'Optimistic', banglaMeaning: 'আশাবাদী', exampleSentence: 'Stay optimistic about the future.'),
    DailyWordData(word: 'Patient', banglaMeaning: 'ধৈর্যশীল', exampleSentence: 'Be patient with yourself.'),
    DailyWordData(word: 'Sincere', banglaMeaning: 'আন্তরিক', exampleSentence: 'She gave a sincere apology.'),
    DailyWordData(word: 'Thoughtful', banglaMeaning: 'চিন্তাশীল', exampleSentence: 'That was a thoughtful gesture.'),
    DailyWordData(word: 'Adaptable', banglaMeaning: 'খাপখাওয়ানো', exampleSentence: 'Be adaptable to change.'),
    DailyWordData(word: 'Brave', banglaMeaning: 'সাহসী', exampleSentence: 'Be brave and take risks.'),
    DailyWordData(word: 'Creative', banglaMeaning: 'সৃজনশীল', exampleSentence: 'Think creative thoughts.'),
    DailyWordData(word: 'Determined', banglaMeaning: 'দৃঢ়প্রতিজ্ঞ', exampleSentence: 'She was determined to succeed.'),
    DailyWordData(word: 'Enthusiastic', banglaMeaning: 'উৎসাহী', exampleSentence: 'Be enthusiastic about learning.'),
    DailyWordData(word: 'Friendly', banglaMeaning: 'বন্ধুত্বপূর্ণ', exampleSentence: 'Stay friendly to everyone.'),
    DailyWordData(word: 'Honest', banglaMeaning: 'সৎ', exampleSentence: 'Always be honest.'),
    DailyWordData(word: 'Innovative', banglaMeaning: 'উদ্ভাবনী', exampleSentence: 'Think innovative solutions.'),
    DailyWordData(word: 'Joyful', banglaMeaning: 'আনন্দিত', exampleSentence: 'Find joyful moments every day.'),
    DailyWordData(word: 'Kind', banglaMeaning: 'দয়ালু', exampleSentence: 'Be kind to yourself and others.'),
    DailyWordData(word: 'Loyal', banglaMeaning: 'বিশ্বস্ত', exampleSentence: 'Stay loyal to your values.'),
    DailyWordData(word: 'Mindful', banglaMeaning: 'সচেতন', exampleSentence: 'Be mindful of the present.'),
    DailyWordData(word: 'Noble', banglaMeaning: 'মহৎ', exampleSentence: 'That was a noble cause.'),
    DailyWordData(word: 'Organized', banglaMeaning: 'সংগঠিত', exampleSentence: 'Stay organized and focused.'),
    DailyWordData(word: 'Passionate', banglaMeaning: 'আবেগী', exampleSentence: 'Follow your passionate dreams.'),
  ];

  /// Returns the word of the day. Tries Firestore first; falls back to a
  /// deterministic selection from the local pool based on the current date.
  static Future<DailyWordData> getTodayWord() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('daily_words')
          .doc(_todayDateString())
          .get();
      if (doc.exists && doc.data() != null) {
        return DailyWordData.fromMap(doc.data()!);
      }
    } catch (_) {
      // Firestore unavailable — use local fallback
    }

    // Deterministic selection from local pool using day-of-year
    final dayOfYear = DateTime.now().difference(
      DateTime(DateTime.now().year, 1, 1),
    ).inDays;
    return _fallbackWords[dayOfYear % _fallbackWords.length];
  }

  /// Returns today's date as "yyyy-MM-dd" for Firestore document lookup.
  static String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
```

Note: The import for `FirebaseFirestore` is at the top — add it:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/daily_word_service.dart
git commit -m "feat: add DailyWordService for fetching today's word with Firestore + local fallback"
```

---

### Task 5: Enhance `NotificationService` — Rich Daily Word + `showLocalNotification()`

**Files:**
- Modify: `lib/services/notification_service.dart`

- [ ] **Step 1: Add imports at top**

Add after the existing imports:

```dart
import 'daily_word_service.dart';
```

- [ ] **Step 2: Add new notification ID constants**

After `static const int _streakMilestoneId = 1002;` add:

```dart
static const int _adminBgNotifId = 2000; // matches workmanager_tasks
static const int _reEngagementNotifId = 2001;
```

- [ ] **Step 3: Add `showLocalNotification()` method**

Add this method before the `/// Get notification history` comment block (before line ~388):

```dart
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
        'background_alerts',
        'Background Alerts',
        channelDescription: 'Notifications delivered in background',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
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
```

- [ ] **Step 4: Update the Daily Word schedule to use rich content**

Replace the `_scheduleAll()` method's Daily Word section (lines 237-249):

```dart
    // Schedule Word of the Day at 9:00 AM (if enabled)
    if (HiveService.isDailyWordNotification()) {
      // Fetch today's word for the rich notification content
      final todayWord = await DailyWordService.getTodayWord();
      final richTitle = '📚 Word of the Day';
      final richBody = '${todayWord.word} → ${todayWord.banglaMeaning}';

      await _scheduleDailyAt(
        id: _dailyWordId,
        hour: 9,
        minute: 0,
        channelId: 'daily_word',
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
    }
```

- [ ] **Step 5: Update `_scheduleDailyAt()` to accept optional BigTextStyle**

Replace the existing `_scheduleDailyAt` method signature and body:

```dart
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
      importance: isHighPriority ? Importance.high : Importance.defaultImportance,
      priority: isHighPriority ? Priority.high : Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
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
```

Note the key change: `AndroidScheduleMode.alarmClock` → `AndroidScheduleMode.inexactAllowWhileIdle` for better Doze mode compatibility. This trades exact timing for reliability across all device states.

- [ ] **Step 6: Update `_getRandomWordTitle()` to remain as a fallback**

Keep the existing method — it's no longer called from _scheduleAll() but may be used elsewhere.

- [ ] **Step 7: Commit**

```bash
git add lib/services/notification_service.dart
git commit -m "feat: add rich Daily Word notification, showLocalNotification(), and Doze-friendly scheduling"
```

---

### Task 6: Update `HiveService` — Last App Open Date + Re-engagement Toggle

**Files:**
- Modify: `lib/services/hive_service.dart`

- [ ] **Step 1: Add `lastAppOpenDate` methods after the existing streak methods (after line ~232)**

```dart
  // ── Last App Open Date (for re-engagement tracking) ──

  static Future<void> setLastAppOpenDate(DateTime date) async {
    await _settings.put('last_app_open_date', date.toIso8601String());
  }

  static DateTime? getLastAppOpenDate() {
    final raw = _settings.get('last_app_open_date');
    if (raw == null) return null;
    return DateTime.tryParse(raw as String);
  }
```

- [ ] **Step 2: Add re-engagement toggle methods after the above**

```dart
  // ── Re-engagement Notification Toggle ──

  static Future<void> setReEngagementEnabled(bool value) async {
    await _settings.put('re_engagement_notifications', value);
  }

  static bool isReEngagementEnabled() {
    return _settings.get('re_engagement_notifications', defaultValue: true) as bool;
  }
```

- [ ] **Step 3: Commit**

```bash
git add lib/services/hive_service.dart
git commit -m "feat: add lastAppOpenDate storage and re-engagement toggle to HiveService"
```

---

### Task 7: Update `main.dart` — Initialize WorkManager + Register Tasks

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add import**

Add after `import 'services/notification_service.dart';`:

```dart
import 'package:workmanager/workmanager.dart';
import 'services/workmanager_tasks.dart';
import 'services/hive_service.dart';
```

- [ ] **Step 2: Initialize WorkManager and register background tasks**

After the `await NotificationService().rescheduleOnAppOpen();` line (line 36), add:

```dart
  // Initialize WorkManager for background notification tasks
  await Workmanager().initialize(
    workmanagerCallbackDispatcher,
    isInDebugMode: false,
  );

  // Register periodic admin sync task
  await Workmanager().registerPeriodicTask(
    'adminSync',
    adminSyncTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingWorkPolicy.keep,
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
```

Also update `lastAppOpenDate` every time the app opens — add after the above WorkManager registration:

```dart
  // Track app open for re-engagement logic
  await HiveService.setLastAppOpenDate(DateTime.now());
```

The resulting `main()` function will look like:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    if (e.toString().contains('[core/duplicate-app]')) {
      Firebase.initializeApp();
    } else {
      rethrow;
    }
  }

  await HiveService.initialize();

  // Initialize local notification system (uses native AlarmManager/UNUserNotificationCenter)
  await NotificationService().initialize();
  // Reschedule daily notifications on app open
  await NotificationService().rescheduleOnAppOpen();

  // Initialize WorkManager for background notification tasks
  await Workmanager().initialize(
    workmanagerCallbackDispatcher,
    isInDebugMode: false,
  );

  // Register periodic admin sync task
  await Workmanager().registerPeriodicTask(
    'adminSync',
    adminSyncTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingWorkPolicy.keep,
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
```

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: initialize WorkManager and register background tasks in main"
```

---

### Task 8: Update Settings Screen — Add Re-engagement Toggle

**Files:**
- Modify: `lib/features/settings/screens/settings_screen.dart`

- [ ] **Step 1: Add re-engagement state variable**

Add after `bool _streakNotification = true;` (line 26):

```dart
bool _reEngagementNotification = true;
```

- [ ] **Step 2: Load re-engagement setting in `initState`**

Add after `_streakNotification = HiveService.isStreakNotification();`:

```dart
_reEngagementNotification = HiveService.isReEngagementEnabled();
```

- [ ] **Step 3: Add re-engagement SwitchListTile after the Streak Reminder tile**

After the Streak Reminder `SwitchListTile` (closing at line 147), add:

```dart
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('🔔 Re-engagement'),
                  subtitle: const Text('Get notified to return when inactive'),
                  value: _reEngagementNotification,
                  onChanged: (val) async {
                    setState(() => _reEngagementNotification = val);
                    await HiveService.setReEngagementEnabled(val);
                  },
                  activeColor: AppColors.primary,
                ),
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/screens/settings_screen.dart
git commit -m "feat: add re-engagement notification toggle to settings"
```

---

### Task 9: Verify `AdminNotificationSyncService.syncLatest()` Returns Count

**Files:**
- Verify: `lib/services/admin_notification_sync_service.dart`

- [ ] **Step 1: Verify return value**

Check line 83: `return added;` — the method already returns the count of newly added notifications. No changes needed. The `workmanager_tasks.dart` already calls `syncLatest()` and uses the returned count.

- [ ] **Step 2: (If needed) Make sure new notification type is saved to history**

The `_handleAdminSync` function in `workmanager_tasks.dart` calls `showLocalNotification()` which internally calls `_saveNotificationToHistory()` with type `admin_announcement`. This is correct.

- [ ] **Step 3: Commit (if any changes made, otherwise skip)**

No changes needed for this task.

---

### Task 10: Update `NotificationProvider` to Handle Background State

**Files:**
- Modify: `lib/providers/notification_provider.dart`

- [ ] **Step 1: Add `toggleReEngagement` method**

Add after the `clearAll()` method:

```dart
  /// Refresh from Hive — called after background tasks add notifications
  Future<void> refreshFromHive() async {
    load();
  }
```

This is a lightweight reload that doesn't trigger Firestore sync (unlike `refresh()`). The provider already has `load()` which populates from Hive. Make it public as a convenience:

- [ ] **Step 2: Also add an `addSyncedNotifications` convenience**

Add after `refreshFromHive()`:

```dart
  /// Adds externally-synced notifications (from WorkManager background tasks)
  /// and updates state. [newItems] are already saved to Hive by the caller.
  void notifyExternalUpdate() {
    load();
  }
```

- [ ] **Step 3: Commit**

```bash
git add lib/providers/notification_provider.dart
git commit -m "feat: add refreshFromHive and notifyExternalUpdate to NotificationProvider"
```

---

### Task 11: Android WorkManager Configuration

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml` (if needed)

- [ ] **Step 1: Verify AndroidManifest has necessary permissions**

WorkManager requires `INTERNET` permission (already present for Firestore). For exact alarms, verify `SCHEDULE_EXACT_ALARM` and `USE_EXACT_ALARM` are present:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

These should already exist from the previous notification setup. No changes needed.

- [ ] **Step 2: Ensure `android/app/build.gradle` has minSdkVersion 21+**

WorkManager requires minSdk 21. If it's lower, update:

```gradle
minSdkVersion 21
```

- [ ] **Step 3: Commit (if any changes made)**

```bash
git add android/app/src/main/AndroidManifest.xml android/app/build.gradle
git commit -m "chore: ensure Android config for WorkManager compatibility"
```

---

### Task 12: Verify & Test

- [ ] **Step 1: Run analysis to catch compile errors**

Run: `cd /Users/keshabsarkar/Vs\ Code\ Apps/Flutter-Spoken-English-App && flutter analyze`
Expected: No errors related to the new/modified files. Any pre-existing warnings are acceptable.

- [ ] **Step 2: Build to verify compilation**

Run: `cd /Users/keshabsarkar/Vs\ Code\ Apps/Flutter-Spoken-English-App && flutter build apk --debug`
Expected: Build succeeds.

- [ ] **Step 3: Manual verification checklist**

Verify these behaviors:
1. ✅ App opens → HiveService.setLastAppOpenDate(now) called
2. ✅ WorkManager tasks registered (check via `adb shell dumpsys jobscheduler`)
3. ✅ Admin notification sent from admin panel → within 15 min, background task shows notification
4. ✅ Daily Word at 9:00 AM shows rich notification with word, meaning, example
5. ✅ Re-engagement toggle in Settings enables/disables inactivity notifications
6. ✅ Re-engagement notification appears after 1+ day of inactivity
7. ✅ Scheduling uses `inexactAllowWhileIdle` for Doze compatibility

---

## Self-Review

1. **Spec coverage check:**
   - ✅ WorkManager background tasks → Task 2, Task 7
   - ✅ Re-engagement system → Task 3, Task 6 (toggle), Task 8 (UI)
   - ✅ Rich Daily Word → Task 4 (service), Task 5 (notification)
   - ✅ Scheduling reliability → Task 5 (inexactAllowWhileIdle)
   - ✅ Admin notification background sync → Task 2, Task 9
   - ✅ HiveService updates → Task 6
   - ✅ Settings UI → Task 8

2. **Placeholder scan:** No TBD, TODO, or "implement later" found.

3. **Type consistency:**
   - `adminSyncTaskName` / `reEngagementTaskName` match between `workmanager_tasks.dart` and `main.dart` → consistent
   - Notification IDs `_adminBgNotifId = 2000`, `_reEngagementNotifId = 2001` match between `workmanager_tasks.dart` and `notification_service.dart` → consistent
   - `HiveService.setLastAppOpenDate()` / `getLastAppOpenDate()` → consistent across tasks
   - `HiveService.setReEngagementEnabled()` / `isReEngagementEnabled()` → consistent across re_engagement_service.dart and settings_screen.dart

4. **No missing tasks:** Every spec requirement has a corresponding task.
