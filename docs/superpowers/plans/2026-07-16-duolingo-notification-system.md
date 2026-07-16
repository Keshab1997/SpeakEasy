# Duolingo-Style Notification System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) for tracking.

**Goal:** Build Duolingo-style notification system with custom musical sound that re-engages idle users and brings them back to SpeakEasy.

**Architecture:** Three-layer system: (1) `IdleTrackerService` tracks user activity via Hive timestamps, (2) In-app reminder overlay (Duolingo-style green banner) with custom audio for active sessions, (3) Extended `NotificationService` with custom sound channel for background native notifications. Riverpod providers connect state to UI.

**Tech Stack:** Flutter, Riverpod, `audioplayers`, `flutter_local_notifications`, Hive, WorkManager

**Design Spec:** `docs/superpowers/specs/2026-07-16-duolingo-notification-system-design.md`

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `lib/services/idle_tracker_service.dart` | Track last activity time, idle duration, decide when to show reminders |
| `lib/providers/idle_tracker_provider.dart` | Riverpod StateNotifier bridging IdleTrackerService to UI |
| `lib/core/widgets/reminder_overlay.dart` | Duolingo-style green banner overlay widget |

### Modified Files
| File | Changes |
|------|---------|
| `lib/services/hive_service.dart` | Add Hive keys for idle reminder settings + last activity time |
| `lib/services/notification_service.dart` | Add custom sound notification channel + idle reminder methods |
| `lib/services/sound_service.dart` | Add notification sound enum + play methods |
| `lib/providers/notification_provider.dart` | Already has refreshFromHive/notifyExternalUpdate — no changes needed |
| `lib/features/home/screens/home_screen.dart` | Add idle tracker observer + activity recording |
| `lib/features/settings/screens/settings_screen.dart` | Add idle reminder toggle + frequency selector |
| `lib/main.dart` | Initialize IdleTracker periodic check timer |
| `lib/core/constants/app_strings.dart` | Add reminder message strings (recreate file) |

---

### Task 1: Add Hive Keys for Idle Tracking

**Files:**
- Modify: `lib/services/hive_service.dart` (add ~30 lines after existing notification methods)

- [ ] **Step 1: Add idle reminder Hive keys and methods**

Add to `lib/services/hive_service.dart` after the `isReEngagementEnabled()` method (around line 262):

```dart
// ─── Idle Reminder Settings ───

static Future<void> setIdleReminderEnabled(bool value) async {
  await _settings.put('idle_reminder_enabled', value);
}

static bool isIdleReminderEnabled() {
  return _settings.get('idle_reminder_enabled', defaultValue: true) as bool;
}

static Future<void> setIdleReminderFrequencyHours(int hours) async {
  await _settings.put('idle_reminder_frequency', hours);
}

static int getIdleReminderFrequencyHours() {
  return _settings.get('idle_reminder_frequency', defaultValue: 4) as int;
}

static Future<void> setIdleReminderSoundEnabled(bool value) async {
  await _settings.put('idle_reminder_sound', value);
}

static bool isIdleReminderSoundEnabled() {
  return _settings.get('idle_reminder_sound', defaultValue: true) as bool;
}

// ─── Idle Tracker ───

static Future<void> setLastActivityTime(DateTime date) async {
  await _settings.put('last_activity_time', date.toIso8601String());
}

static DateTime? getLastActivityTime() {
  final raw = _settings.get('last_activity_time');
  if (raw == null) return null;
  return DateTime.tryParse(raw as String);
}

static Future<void> setConsecutiveIdleReminders(int count) async {
  await _settings.put('consecutive_idle_reminders', count);
}

static int getConsecutiveIdleReminders() {
  return _settings.get('consecutive_idle_reminders', defaultValue: 0) as int;
}

static Future<void> setLastInAppReminderTime(DateTime date) async {
  await _settings.put('last_in_app_reminder_time', date.toIso8601String());
}

static DateTime? getLastInAppReminderTime() {
  final raw = _settings.get('last_in_app_reminder_time');
  if (raw == null) return null;
  return DateTime.tryParse(raw as String);
}
```

- [ ] **Step 2: Verify the file compiles**

Run: `cd /Users/keshabsarkar/VsCodeApps/SpeakEasy && dart analyze lib/services/hive_service.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/services/hive_service.dart
git commit -m "feat: add Hive keys for idle reminder tracking"
```

---

### Task 2: Create IdleTrackerService

**Files:**
- Create: `lib/services/idle_tracker_service.dart`

- [ ] **Step 1: Create the service**

```dart
import 'hive_service.dart';

class IdleTrackerService {
  /// Max consecutive in-app reminders before switching to native notification
  static const int maxInAppReminders = 2;

  /// Minimum gap between in-app reminders (hours)
  static const int minGapBetweenInAppReminders = 2;

  /// Check if in-app reminder should be shown
  static Future<bool> shouldShowInAppReminder() async {
    if (!HiveService.isIdleReminderEnabled()) return false;

    final lastActivity = HiveService.getLastActivityTime();
    if (lastActivity == null) {
      await recordActivity();
      return false;
    }

    final idleDuration = DateTime.now().difference(lastActivity);
    final frequencyHours = HiveService.getIdleReminderFrequencyHours();

    // Not idle long enough
    if (idleDuration.inHours < frequencyHours) return false;

    // Check gap from last in-app reminder
    final lastReminder = HiveService.getLastInAppReminderTime();
    if (lastReminder != null) {
      final gap = DateTime.now().difference(lastReminder);
      if (gap.inHours < minGapBetweenInAppReminders) return false;
    }

    // Check consecutive count
    final consecutive = HiveService.getConsecutiveIdleReminders();
    if (consecutive >= maxInAppReminders) return false;

    return true;
  }

  /// Check if native notification should be sent
  static Future<bool> shouldSendNativeNotification() async {
    if (!HiveService.isIdleReminderEnabled()) return false;
    if (!HiveService.isNotificationEnabled()) return false;

    final lastActivity = HiveService.getLastActivityTime();
    if (lastActivity == null) return false;

    final idleDuration = DateTime.now().difference(lastActivity);

    // Send native notification after 2x frequency or when max in-app reached
    final frequencyHours = HiveService.getIdleReminderFrequencyHours();
    final consecutive = HiveService.getConsecutiveIdleReminders();

    if (idleDuration.inHours >= frequencyHours * 2) return true;
    if (consecutive >= maxInAppReminders && idleDuration.inHours >= frequencyHours) return true;

    return false;
  }

  /// Record user activity (called from screens)
  static Future<void> recordActivity() async {
    await HiveService.setLastActivityTime(DateTime.now());
    // Reset consecutive reminders when user is active
    await HiveService.setConsecutiveIdleReminders(0);
  }

  /// Record that an in-app reminder was shown
  static Future<void> markInAppReminderShown() async {
    await HiveService.setLastInAppReminderTime(DateTime.now());
    final consecutive = HiveService.getConsecutiveIdleReminders();
    await HiveService.setConsecutiveIdleReminders(consecutive + 1);
  }

  /// Get idle duration for display
  static Future<Duration> getIdleDuration() async {
    final lastActivity = HiveService.getLastActivityTime();
    if (lastActivity == null) return Duration.zero;
    return DateTime.now().difference(lastActivity);
  }

  /// Reset reminder state (called when user returns)
  static Future<void> resetReminderState() async {
    await recordActivity();
    await HiveService.setConsecutiveIdleReminders(0);
  }

  /// Get a random reminder message based on idle duration
  static String getReminderMessage(int hoursIdle) {
    final messages = [
      'সময় হয়েছে পড়ার! 📚 আপনার আজকের লেসন অপেক্ষা করছে!',
      'আজকে এখনো প্র্যাকটিস করেননি? 🎯 মাত্র ৫ মিনিট সময় নিন!',
      'আপনার Streak বাঁচান! 🔥 এখনই শুরু করুন!',
      'নতুন লেসন যোগ হয়েছে! 📖 দেখে আসুন?',
      'আপনার Daily Word অপেক্ষা করছে! 💪',
      'Time to practice! 📚 Your lesson is waiting!',
      "Haven't practiced today? 🎯 Just 5 minutes!",
      'Save your streak! 🔥 Start now!',
      'New lesson added! 📖 Check it out!',
    ];
    if (hoursIdle >= 24) {
      messages.addAll([
        '🚀 ${hoursIdle ~/ 24} দিন হয়ে গেছে! ফিরে আসুন!',
        '⚡ ${hoursIdle ~/ 24} দিন! আপনার প্রোগ্রেস অপেক্ষা করছে!',
      ]);
    }
    return messages[DateTime.now().millisecondsSinceEpoch % messages.length];
  }
}
```

- [ ] **Step 2: Run analyzer**

Run: `cd /Users/keshabsarkar/VsCodeApps/SpeakEasy && dart analyze lib/services/idle_tracker_service.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/services/idle_tracker_service.dart
git commit -m "feat: create IdleTrackerService for user activity tracking"
```

---

### Task 3: Add Notification Sounds to SoundService

**Files:**
- Modify: `lib/services/sound_service.dart`

- [ ] **Step 1: Add notification sound enum and play methods**

Add to the `GameSoundEffect` enum:
```dart
enum GameSoundEffect {
  correct,
  wrong,
  levelUp,
  achievement,
  countdown,
  gameOver,
  tick,
  buttonTap,
  coinCollect,
  streakBonus,
  notificationReminder,   // NEW
  notificationCharacter,  // NEW
}
```

Add asset path entries in `_getAssetPath`:
```dart
case GameSoundEffect.notificationReminder:
  return 'audio/notification_reminder.mp3';
case GameSoundEffect.notificationCharacter:
  return 'audio/notification_character.mp3';
```

Add new convenience methods:
```dart
Future<void> playNotificationReminder() =>
    playSound(GameSoundEffect.notificationReminder);

Future<void> playNotificationCharacter() =>
    playSound(GameSoundEffect.notificationCharacter);
```

- [ ] **Step 2: Run analyzer**

Run: `cd /Users/keshabsarkar/VsCodeApps/SpeakEasy && dart analyze lib/services/sound_service.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/services/sound_service.dart
git commit -m "feat: add notification reminder sounds to SoundService"
```

---

### Task 4: Add Custom Sound Notification Channel to NotificationService

**Files:**
- Modify: `lib/services/notification_service.dart`

- [ ] **Step 1: Add idle reminder channel + methods**

Add new notification ID constant (after existing IDs):
```dart
static const int _idleReminderId = 1004;
```

Add a new method to create the Android notification channel with custom sound (called during init):

In the `initialize()` method's Android settings, the channel is defined per-notification in `AndroidNotificationDetails`. The existing channels already exist. For custom sound, we need a new channel ID so Android creates a fresh channel with the custom sound.

Add method:
```dart
/// Schedule an idle reminder notification with custom sound
Future<void> scheduleIdleReminder({
  required String title,
  required String body,
  String? payload,
}) async {
  try {
    final androidDetails = AndroidNotificationDetails(
      'speakeasy_idle_reminder',
      'স্পিকইজি রিমাইন্ডার',
      channelDescription: 'ইউজারকে অ্যাপে ফিরিয়ে আনার জন্য রিমাইন্ডার',
      importance: Importance.high,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound('speakeasy_notification'),
      icon: '@mipmap/ic_launcher',
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
```

Add to `cancelAllScheduled()`:
```dart
await _plugin.cancel(_idleReminderId);
```

- [ ] **Step 2: Run analyzer**

Run: `cd /Users/keshabsarkar/VsCodeApps/SpeakEasy && dart analyze lib/services/notification_service.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/services/notification_service.dart
git commit -m "feat: add custom sound notification channel for idle reminders"
```

---

### Task 5: Create In-App Reminder Overlay Widget

**Files:**
- Create: `lib/core/widgets/reminder_overlay.dart`

- [ ] **Step 1: Create Duolingo-style reminder overlay**

```dart
import 'package:flutter/material.dart';
import '../../services/sound_service.dart';
import '../../services/idle_tracker_service.dart';
import '../../core/constants/app_colors.dart';

class ReminderOverlay extends StatefulWidget {
  final int hoursIdle;
  final VoidCallback onStartPractice;
  final VoidCallback onDismiss;

  const ReminderOverlay({
    super.key,
    required this.hoursIdle,
    required this.onStartPractice,
    required this.onDismiss,
  });

  @override
  State<ReminderOverlay> createState() => _ReminderOverlayState();
}

class _ReminderOverlayState extends State<ReminderOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // Play notification sound
    final soundService = SoundService();
    if (!soundService.isMuted) {
      soundService.playNotificationReminder();
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          color: AppColors.primary,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF43A047)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('🦜', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        IdleTrackerService.getReminderMessage(widget.hoursIdle),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: widget.onDismiss,
                      child: const Text(
                        '⏰ পরে',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: widget.onStartPractice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      child: const Text(
                        'শুরু করুন 🎯',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyzer**

Run: `cd /Users/keshabsarkar/VsCodeApps/SpeakEasy && dart analyze lib/core/widgets/reminder_overlay.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/core/widgets/reminder_overlay.dart
git commit -m "feat: create Duolingo-style reminder overlay widget"
```

---

### Task 6: Create IdleTracker Riverpod Provider

**Files:**
- Create: `lib/providers/idle_tracker_provider.dart`

- [ ] **Step 1: Create provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/idle_tracker_service.dart';

class IdleTrackerState {
  final bool isIdle;
  final Duration idleDuration;
  final bool showingReminder;
  final int hoursIdle;

  const IdleTrackerState({
    this.isIdle = false,
    this.idleDuration = Duration.zero,
    this.showingReminder = false,
    this.hoursIdle = 0,
  });

  IdleTrackerState copyWith({
    bool? isIdle,
    Duration? idleDuration,
    bool? showingReminder,
    int? hoursIdle,
  }) {
    return IdleTrackerState(
      isIdle: isIdle ?? this.isIdle,
      idleDuration: idleDuration ?? this.idleDuration,
      showingReminder: showingReminder ?? this.showingReminder,
      hoursIdle: hoursIdle ?? this.hoursIdle,
    );
  }
}

class IdleTrackerNotifier extends StateNotifier<IdleTrackerState> {
  IdleTrackerNotifier() : super(const IdleTrackerState());

  /// Check idle status and update state
  Future<void> checkIdleStatus() async {
    final shouldShow = await IdleTrackerService.shouldShowInAppReminder();
    final idleDuration = await IdleTrackerService.getIdleDuration();

    state = state.copyWith(
      isIdle: idleDuration.inHours >= 1,
      idleDuration: idleDuration,
      showingReminder: shouldShow,
      hoursIdle: idleDuration.inHours,
    );
  }

  /// Record user activity and dismiss reminder
  Future<void> recordActivity() async {
    await IdleTrackerService.recordActivity();
    state = state.copyWith(
      isIdle: false,
      showingReminder: false,
      idleDuration: Duration.zero,
      hoursIdle: 0,
    );
  }

  /// Dismiss reminder (keep idle state for native notification)
  Future<void> dismissReminder() async {
    await IdleTrackerService.markInAppReminderShown();
    state = state.copyWith(showingReminder: false);
  }

  /// Mark reminder shown
  Future<void> markReminderShown() async {
    await IdleTrackerService.markInAppReminderShown();
  }

  /// Reset everything (user returned to app)
  Future<void> reset() async {
    await IdleTrackerService.resetReminderState();
    state = const IdleTrackerState();
  }
}

final idleTrackerProvider =
    StateNotifierProvider<IdleTrackerNotifier, IdleTrackerState>((ref) {
  return IdleTrackerNotifier();
});
```

- [ ] **Step 2: Run analyzer**

Run: `cd /Users/keshabsarkar/VsCodeApps/SpeakEasy && dart analyze lib/providers/idle_tracker_provider.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/providers/idle_tracker_provider.dart
git commit -m "feat: create IdleTrackerProvider for Riverpod state management"
```

---

### Task 7: Integrate Idle Tracker into HomeScreen

**Files:**
- Modify: `lib/features/home/screens/home_screen.dart`

- [ ] **Step 1: Add imports and idle tracker integration**

Add import at top:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Already present
import '../../../providers/idle_tracker_provider.dart';    // NEW
import '../../../core/widgets/reminder_overlay.dart';      // NEW
import '../../../services/idle_tracker_service.dart';      // NEW
```

Add state variable in `_HomeScreenState`:
```dart
// Already has _tts, _isSpeaking — add after them:
Timer? _idleCheckTimer;
```

Add timer in `initState()` after the existing postFrameCallback (around line 164, before closing `});`):
```dart
// Start idle tracker periodic check (every 15 minutes)
_idleCheckTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
  final notifier = ref.read(idleTrackerProvider.notifier);
  await notifier.checkIdleStatus();
});

// Also check immediately on app open
WidgetsBinding.instance.addPostFrameCallback((_) async {
  // ... existing code ...
  
  // Add at end of existing postFrameCallback:
  // Record initial activity
  await IdleTrackerService.recordActivity();
});
```

Add dispose override:
```dart
@override
void dispose() {
  _idleCheckTimer?.cancel();
  // ... keep any existing dispose code from super
  super.dispose();
}
```

In the `build` method, watch the idle tracker provider (after existing watchers, around line 312):
```dart
final idleTrackerState = ref.watch(idleTrackerProvider);
```

Add the reminder overlay in the build method's body — wrap the `SafeArea` body in a `Stack`:

Replace current return from `Scaffold(body: SafeArea(...)` to use Stack:

```dart
return Scaffold(
  appBar: ...,
  body: Stack(
    children: [
      SafeArea(
        child: SingleChildScrollView(
          // ... existing body content ...
        ),
      ),
      // Reminder overlay at bottom
      if (idleTrackerState.showingReminder)
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.of(context).padding.bottom + 8,
          child: ReminderOverlay(
            hoursIdle: idleTrackerState.hoursIdle,
            onStartPractice: () async {
              // Dismiss reminder and navigate to lessons
              await ref.read(idleTrackerProvider.notifier).recordActivity();
              // Call existing lesson navigation
              widget.onNavigateToLessons?.call();
            },
            onDismiss: () async {
              await ref.read(idleTrackerProvider.notifier).dismissReminder();
            },
          ),
        ),
    ],
  ),
);
```

- [ ] **Step 2: Run analyzer**

Run: `cd /Users/keshabsarkar/VsCodeApps/SpeakEasy && dart analyze lib/features/home/screens/home_screen.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/screens/home_screen.dart
git commit -m "feat: integrate idle tracker and reminder overlay into HomeScreen"
```

---

### Task 8: Record Activity on Key Screens

**Files:**
- Modify: Key screens where user activity should be recorded

- [ ] **Step 1: Record activity on lesson screens, quiz screens, practice screens**

In `lib/features/lessons/screens/lesson_detail_screen.dart` — add to `initState` or `didChangeDependencies`:
```dart
@override
void initState() {
  super.initState();
  // Record user activity for idle tracker
  IdleTrackerService.recordActivity();
}
```

In `lib/features/quiz/screens/quiz_screen.dart`:
```dart
// Add to initState
IdleTrackerService.recordActivity();
```

In `lib/features/daily_quiz/screens/daily_quiz_screen.dart`:
```dart
// Add to initState
IdleTrackerService.recordActivity();
```

In `lib/features/speaking/screens/speaking_screen.dart`:
```dart
// Add to initState
IdleTrackerService.recordActivity();
```

In `lib/features/listening/screens/listening_screen.dart`:
```dart
// Add to initState
IdleTrackerService.recordActivity();
```

Add import to each:
```dart
import '../../../services/idle_tracker_service.dart';
```

- [ ] **Step 2: Run analyzer on each modified file**

Run: `cd /Users/keshabsarkar/VsCodeApps/SpeakEasy && dart analyze lib/features/lessons/screens/lesson_detail_screen.dart lib/features/quiz/screens/quiz_screen.dart lib/features/daily_quiz/screens/daily_quiz_screen.dart lib/features/speaking/screens/speaking_screen.dart lib/features/listening/screens/listening_screen.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/lessons/screens/lesson_detail_screen.dart lib/features/quiz/screens/quiz_screen.dart lib/features/daily_quiz/screens/daily_quiz_screen.dart lib/features/speaking/screens/speaking_screen.dart lib/features/listening/screens/listening_screen.dart
git commit -m "feat: record user activity on key screens for idle tracking"
```

---

### Task 9: Initialize Periodic Idle Check in main.dart

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add idle tracker initialization**

Add imports:
```dart
import 'dart:async';
import 'services/idle_tracker_service.dart';
import 'providers/idle_tracker_provider.dart';
```

After the existing `await HiveService.setLastAppOpenDate(DateTime.now())` (around line 67), add:
```dart
// Initialize idle tracker with initial activity timestamp
await IdleTrackerService.recordActivity();

// Start periodic idle check (fires every 15 minutes via Timer)
// Timer is managed by HomeScreen's idle tracker provider
```

- [ ] **Step 2: Run analyzer**

Run: `cd /Users/keshabsarkar/VsCodeApps/SpeakEasy && dart analyze lib/main.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: initialize idle tracker on app start"
```

---

### Task 10: Add Idle Reminder Settings to Settings Screen

**Files:**
- Modify: `lib/features/settings/screens/settings_screen.dart`

- [ ] **Step 1: Add idle reminder toggle and frequency selector**

Add new state variables (after existing booleans, around line 27):
```dart
bool _idleReminderEnabled = true;
int _idleReminderFrequency = 4;
bool _idleReminderSoundEnabled = true;
```

Load in `initState()` (after existing loads, around line 38):
```dart
_idleReminderEnabled = HiveService.isIdleReminderEnabled();
_idleReminderFrequency = HiveService.getIdleReminderFrequencyHours();
_idleReminderSoundEnabled = HiveService.isIdleReminderSoundEnabled();
```

In the `build` method's notifications section, after the re-engagement toggle (around line 157), add new idle reminder section:
```dart
if (_notifications) ...[
  const Divider(height: 1),
  SwitchListTile(
    title: const Text('⏳ Idle Reminder'),
    subtitle: const Text('Duolingo-style reminder when inactive'),
    secondary: const Icon(Icons.timer_outlined, color: AppColors.primary),
    value: _idleReminderEnabled,
    onChanged: (val) async {
      setState(() => _idleReminderEnabled = val);
      await HiveService.setIdleReminderEnabled(val);
    },
    activeColor: AppColors.primary,
  ),
  if (_idleReminderEnabled) ...[
    const Divider(height: 1),
    ListTile(
      leading: const Icon(Icons.schedule_rounded, color: AppColors.primary),
      title: const Text('Reminder Frequency'),
      subtitle: Text('Every $_idleReminderFrequency hours'),
      trailing: SizedBox(
        width: 120,
        child: Slider(
          value: _idleReminderFrequency.toDouble(),
          min: 2,
          max: 24,
          divisions: 5,
          label: '$_idleReminderFrequency hours',
          onChanged: (val) async {
            setState(() => _idleReminderFrequency = val.round());
            await HiveService.setIdleReminderFrequencyHours(val.round());
          },
          activeColor: AppColors.primary,
        ),
      ),
    ),
    const Divider(height: 1),
    SwitchListTile(
      title: const Text('🔊 Reminder Sound'),
      subtitle: const Text('Play custom notification sound'),
      secondary: const Icon(Icons.music_note_rounded, color: AppColors.primary),
      value: _idleReminderSoundEnabled,
      onChanged: (val) async {
        setState(() => _idleReminderSoundEnabled = val);
        await HiveService.setIdleReminderSoundEnabled(val);
      },
      activeColor: AppColors.primary,
    ),
  ],
],
```

- [ ] **Step 2: Run analyzer**

Run: `cd /Users/keshabsarkar/VsCodeApps/SpeakEasy && dart analyze lib/features/settings/screens/settings_screen.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/settings/screens/settings_screen.dart
git commit -m "feat: add idle reminder settings with frequency slider"
```

---

### Task 11: Background Native Notification via WorkManager

**Files:**
- Modify: `lib/services/workmanager_tasks.dart`

- [ ] **Step 1: Add idle reminder background check to WorkManager**

Read current `workmanager_tasks.dart` first:
```bash
cat /Users/keshabsarkar/VsCodeApps/SpeakEasy/lib/services/workmanager_tasks.dart
```

Add idle reminder check in the existing periodic task. Import and add at the end of the `_handleReEngagement` callback (or add a new callback):

```dart
// In the WorkManager callback dispatcher, after re-engagement check:
if (task == 'idleReminder') {
  await _handleIdleReminder();
}
```

Add handler:
```dart
Future<void> _handleIdleReminder() async {
  await HiveService.initialize();
  await NotificationService().initialize();
  
  final shouldNotify = await IdleTrackerService.shouldSendNativeNotification();
  if (!shouldNotify) return;
  
  final idleDuration = await IdleTrackerService.getIdleDuration();
  final message = IdleTrackerService.getReminderMessage(idleDuration.inHours);
  
  await NotificationService().scheduleIdleReminder(
    title: 'সময় হয়েছে! 📚',
    body: message,
    payload: 'type=idle_reminder',
  );
}
```

Register the periodic task in `main.dart`:
```dart
await Workmanager().registerPeriodicTask(
  'idleReminder',
  'idleReminder',
  frequency: const Duration(hours: 6),
  constraints: Constraints(
    networkType: NetworkType.not_required,
  ),
  existingWorkPolicy: ExistingWorkPolicy.keep,
);
```

- [ ] **Step 2: Run analyzer**

Run: `cd /Users/keshabsarkar/VsCodeApps/SpeakEasy && dart analyze lib/services/workmanager_tasks.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/services/workmanager_tasks.dart lib/main.dart
git commit -m "feat: add idle reminder background check via WorkManager"
```

---

### Task 12: Android Custom Sound Asset Setup

**Files:**
- New: `android/app/src/main/res/raw/` folder (user to add .mp3)

- [ ] **Step 1: Create placeholder and documentation**

No code change needed. Create a README or add instruction comment in the existing asset section.

Add placeholder instruction. Create a shell script that helps user convert:

```bash
# Create raw directory if not exists
mkdir -p android/app/src/main/res/raw

echo "Place your notification sound file as:
  android/app/src/main/res/raw/speakeasy_notification.mp3

Requirements:
  - Format: MP3 (or OGG)
  - Duration: < 5 seconds (short, snappy)
  - File size: < 50KB
  - Mono recommended for notification sounds
  - Name: lowercase, no spaces, no special chars

For iOS (convert if needed):
  ffmpeg -i your_sound.mp3 -c:a aac -b:a 16k -ar 16000 ios/Runner/speakeasy_notification.caf
"
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/res/raw/
git commit -m "docs: add Android custom sound asset directory with instructions"
```

---

### Task 13: Run Full App Analysis & Verify

**Files:**
- All modified files

- [ ] **Step 1: Run full dart analysis**

```bash
cd /Users/keshabsarkar/VsCodeApps/SpeakEasy && dart analyze
```

Expected: No errors related to our changes (existing warnings/errors may remain)

- [ ] **Step 2: Build test (dry run)**

```bash
cd /Users/keshabsarkar/VsCodeApps/SpeakEasy && flutter build apk --debug --target-platform android-arm64 2>&1 | tail -20
```

Expected: Build succeeds

- [ ] **Step 3: Final verification checklist**

- [ ] `IdleTrackerService` compiles and methods work
- [ ] `HiveService` has all new keys
- [ ] `SoundService` plays notification sounds
- [ ] `NotificationService` has custom sound channel
- [ ] `ReminderOverlay` shows/hides with animation
- [ ] `HomeScreen` shows reminder when idle
- [ ] Settings toggle enables/disables idle reminder
- [ ] Frequency slider changes idle threshold
- [ ] Sound toggle works
- [ ] Activity recorded on key screens
- [ ] WorkManager background task compiles

- [ ] **Step 4: Commit any final fixes**

```bash
git commit -am "chore: finalize duolingo notification system"
```

---

## Sound Asset Instructions (User Action Required)

After implementation, you need to add these files:

### Android
1. Convert your musical tune to a short MP3 (< 5 seconds, mono recommended)
2. Name it `speakeasy_notification.mp3` (lowercase, no spaces)
3. Place in: `android/app/src/main/res/raw/speakeasy_notification.mp3`
4. Rebuild the app

### iOS  
1. Convert your MP3 to CAF format (or use AAC/MP3 directly if iOS supports)
2. Name it `speakeasy_notification.caf`
3. Place in: `ios/Runner/speakeasy_notification.caf`
4. Add to Xcode project (if needed)

### In-App Sound
1. Place the same or different MP3 in: `assets/audio/notification_reminder.mp3`
2. Place character sound in: `assets/audio/notification_character.mp3`
3. Add to `pubspec.yaml` assets section if not already covered:
```yaml
assets:
  - assets/audio/
```
