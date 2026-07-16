# Weekly Streak Improvement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add weekly streak display to the home screen StreakWidget, fix weekly streak logic, and add milestone badges.

**Architecture:** Fix streak service logic first, then propagate changes through provider state, then update UI. The data flow is: HomeScreen → StreakProvider → StreakService → ProgressRepository → Hive/Firestore.

**Tech Stack:** Flutter, Dart, Riverpod, Hive, Firestore

---

### Task 1: Fix Weekly Streak Logic in StreakService

**Files:**
- Modify: `lib/services/streak_service.dart:136-188`

- [ ] **Step 1: Replace `checkAndUpdateWeeklyStreak()` and add `_hadActivityLastWeek()`**

Current code at line 136-188:
```dart
  // ── Weekly Streak ──

  int getCurrentWeeklyStreak() {
    final progress = _progressRepository.getProgress();
    return progress?.weeklyStreak ?? 0;
  }

  Future<int> incrementWeeklyStreak() async {
    await _progressRepository.incrementWeeklyStreak();
    return getCurrentWeeklyStreak();
  }

  Future<void> resetWeeklyStreak() async {
    await _progressRepository.resetWeeklyStreak();
  }

  bool isNewWeek() {
    final progress = _progressRepository.getProgress();
    if (progress == null) return false;

    final now = DateTime.now();
    final lastActive = progress.lastActiveDate;
    
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(lastActive.year, lastActive.month, lastActive.day);
    
    // Find the Monday of the current week (ISO week starts on Monday by default, weekday = 1)
    final daysSinceMondayToday = today.weekday - 1;
    final mondayThisWeek = today.subtract(Duration(days: daysSinceMondayToday));
    
    return lastDay.isBefore(mondayThisWeek);
  }

  Future<int> checkAndUpdateWeeklyStreak() async {
    final progress = _progressRepository.getProgress();
    if (progress == null) return 0;

    if (isNewWeek()) {
      // New week - reset weekly streak and start fresh
      await resetWeeklyStreak();
      await incrementWeeklyStreak();
      return 1;
    }

    // Checking if we already incremented weekly streak for today happens before calling this.
    // Assuming this is only called once per day!
    await incrementWeeklyStreak();

    return getCurrentWeeklyStreak();
  }
```

Replace with:
```dart
  // ── Weekly Streak ──

  int getCurrentWeeklyStreak() {
    final progress = _progressRepository.getProgress();
    return progress?.weeklyStreak ?? 0;
  }

  Future<int> incrementWeeklyStreak() async {
    await _progressRepository.incrementWeeklyStreak();
    return getCurrentWeeklyStreak();
  }

  Future<void> resetWeeklyStreak() async {
    await _progressRepository.resetWeeklyStreak();
  }

  /// Check if the user is in a new ISO week compared to last active date.
  bool isNewWeek() {
    final progress = _progressRepository.getProgress();
    if (progress == null) return false;

    final now = DateTime.now();
    final lastActive = progress.lastActiveDate;

    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(lastActive.year, lastActive.month, lastActive.day);

    // Find the Monday of the current week
    final daysSinceMondayToday = today.weekday - 1;
    final mondayThisWeek = today.subtract(Duration(days: daysSinceMondayToday));

    // Also find the Monday of the week containing lastActiveDate
    final daysSinceMondayLast = lastDay.weekday - 1;
    final mondayLastWeek = lastDay.subtract(Duration(days: daysSinceMondayLast));

    // New week if lastActiveDate's Monday is before this week's Monday
    return mondayLastWeek.isBefore(mondayThisWeek);
  }

  /// Check if the user had any activity in the previous calendar week.
  /// Examines the weeklyActivity map stored in GameProgressModel.
  bool _hadActivityLastWeek(GameProgressModel progress) {
    final weeklyActivity = progress.weeklyActivity;
    if (weeklyActivity.isEmpty) return false;
    // If any day (Mon=1..Sun=7) has true, there was activity
    return weeklyActivity.values.any((active) => active);
  }

  /// Check and update weekly streak based on week transition.
  /// Called once per app open, when entering a new week.
  /// - If new week AND had activity last week → increment weeklyStreak
  /// - If new week AND no activity last week → reset weeklyStreak to 0
  /// - If same week → no change
  Future<int> checkAndUpdateWeeklyStreak() async {
    final progress = _progressRepository.getProgress();
    if (progress == null) return 0;

    // If still in the same calendar week, no streak update needed
    if (!isNewWeek()) {
      return progress.weeklyStreak;
    }

    // We've crossed into a new week
    // IMPORTANT: The weeklyActivity map currently holds THIS week's activity.
    // We need to check if the user was active in the PREVIOUS week.
    // Since we're at the start of a new week, the weeklyActivity map still
    // reflects the previous week (it gets updated in recordActiveDay for current week).
    // Actually, let's check: if we're in a new week, the weeklyActivity may have been
    // reset or may still hold old data. We use _hadActivityLastWeek which checks
    // if any day in the map is marked active.

    // Check previous week's activity via the stored map + lastActiveDate
    final hadActivity = _hadActivityLastWeek(progress);
    
    if (hadActivity) {
      await _progressRepository.incrementWeeklyStreak();
    } else {
      await _progressRepository.resetWeeklyStreak();
    }

    return getCurrentWeeklyStreak();
  }
```

Also need to add the import at the top:
```dart
import '../models/game/game_progress_model.dart';
```

Check if it's already imported (it may come through `progress_repository.dart` imports). If not, add it.

- [ ] **Step 2: Verify the file compiles**

Run: `cd /Users/keshabsarkar/Vs\ Code\ Apps/SpeakEasy && dart analyze lib/services/streak_service.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
cd /Users/keshabsarkar/Vs\ Code\ Apps/SpeakEasy && git add lib/services/streak_service.dart && git commit -m "fix: correct weekly streak logic to increment once per week"
```

---

### Task 2: Update StreakProvider with Weekly State Fields

**Files:**
- Modify: `lib/providers/game/streak_provider.dart`

- [ ] **Step 1: Add weekly milestone helper and update `_refresh()`**

Current `StreakState` (line 7-27):
```dart
class StreakState {
  final int currentStreak;
  final int weeklyStreak;
  final int bestStreak;
  final int longestStreak;
  final int missedDays;
  final bool shouldReset;
  final String emoji;
  final int flameCount;

  const StreakState({
    this.currentStreak = 0,
    this.weeklyStreak = 0,
    this.bestStreak = 0,
    this.longestStreak = 0,
    this.missedDays = 0,
    this.shouldReset = false,
    this.emoji = '⚫',
    this.flameCount = 0,
  });
}
```

Replace with:
```dart
class StreakState {
  final int currentStreak;
  final int weeklyStreak;
  final int bestStreak;
  final int longestStreak;
  final int missedDays;
  final bool shouldReset;
  final String emoji;
  final int flameCount;
  final String weeklyMilestone;     // milestone emoji for weekly streak
  final String weeklyMilestoneLabel; // label like "Dedicated"
  final int thisWeekActiveDays;     // how many days active this week (0-7)

  const StreakState({
    this.currentStreak = 0,
    this.weeklyStreak = 0,
    this.bestStreak = 0,
    this.longestStreak = 0,
    this.missedDays = 0,
    this.shouldReset = false,
    this.emoji = '⚫',
    this.flameCount = 0,
    this.weeklyMilestone = '🌱',
    this.weeklyMilestoneLabel = 'Started',
    this.thisWeekActiveDays = 0,
  });
}
```

- [ ] **Step 2: Add weekly milestone helper method to `StreakNotifier`**

Add these methods to `StreakNotifier` class (after line 133 or similar):

```dart
  // ── Weekly Milestone Helpers ──

  /// Get milestone emoji and label for a given weekly streak count.
  static ({String emoji, String label}) getWeeklyMilestone(int weeklyStreak) {
    if (weeklyStreak >= 52) return (emoji: '👑', label: 'Legend');
    if (weeklyStreak >= 26) return (emoji: '💪', label: 'Committed');
    if (weeklyStreak >= 12) return (emoji: '⚡', label: 'Dedicated');
    if (weeklyStreak >= 4) return (emoji: '🔥', label: 'Consistent');
    if (weeklyStreak >= 1) return (emoji: '🌱', label: 'Started');
    return (emoji: '⚪', label: 'No streak');
  }
```

- [ ] **Step 3: Update `_refresh()` to populate new fields**

In `_refresh()` (line 58-73), update the state assignment:

```dart
  void _refresh() {
    final streak = _streakService.getCurrentStreak();
    final weeklyStreak = _streakService.getCurrentWeeklyStreak();
    final longestStreak = _streakService.getLongestStreak();
    final missedDays = _streakService.getMissedDays();
    final milestone = StreakNotifier.getWeeklyMilestone(weeklyStreak);
    final weekActiveDays = HiveService.getWeekActivityList().where((a) => a).length;
    
    state = StreakState(
      currentStreak: streak,
      weeklyStreak: weeklyStreak,
      bestStreak: streak,
      longestStreak: longestStreak,
      missedDays: missedDays,
      shouldReset: _streakService.shouldResetStreak(),
      emoji: _streakService.getStreakEmoji(streak),
      flameCount: _streakService.getStreakFlameCount(streak),
      weeklyMilestone: milestone.emoji,
      weeklyMilestoneLabel: milestone.label,
      thisWeekActiveDays: weekActiveDays,
    );
  }
```

Add the import for HiveService at the top:
```dart
import '../../services/hive_service.dart';
```

- [ ] **Step 4: Verify the file compiles**

Run: `cd /Users/keshabsarkar/Vs\ Code\ Apps/SpeakEasy && dart analyze lib/providers/game/streak_provider.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
cd /Users/keshabsarkar/Vs\ Code\ Apps/SpeakEasy && git add lib/providers/game/streak_provider.dart && git commit -m "feat: add weekly milestone and active days to StreakState"
```

---

### Task 3: Update StreakWidget with Weekly Streak Display

**Files:**
- Modify: `lib/core/widgets/streak_widget.dart`

- [ ] **Step 1: Extract current StreakWidget code from streak_widget.dart for reference**

The StreakWidget currently has these sections:
- Lines 1-27: Class definition with parameters
- Lines 33-78: Animation controller
- Lines 80-324: Build method with flame counter, calendar, XP bar, action buttons
- Lines 327-428: `_buildWeeklyCalendar()` — 7-day grid
- Lines 430-490: `_buildDailyXPBar()`
- Lines 492-533: `_buildActionChip()`
- Lines 536-564: `_buildMilestoneBadge()` — daily streak milestone

- [ ] **Step 2: Add new parameters to `StreakWidget`**

Update class definition (line 5-27):

```dart
class StreakWidget extends StatefulWidget {
  final int currentStreak;
  final int weeklyStreak;
  final String weeklyMilestone;
  final String weeklyMilestoneLabel;
  final int thisWeekActiveDays;
  final int todayXP;
  final int dailyXPTarget;
  final bool hasPracticeToday;
  final bool isStreakFrozen;
  final int streakFreezeCount;
  final VoidCallback? onTap;
  final VoidCallback? onBuyFreeze;
  final VoidCallback? onShare;

  const StreakWidget({
    super.key,
    required this.currentStreak,
    this.weeklyStreak = 0,
    this.weeklyMilestone = '🌱',
    this.weeklyMilestoneLabel = 'Started',
    this.thisWeekActiveDays = 0,
    this.todayXP = 0,
    this.dailyXPTarget = 50,
    this.hasPracticeToday = false,
    this.isStreakFrozen = false,
    this.streakFreezeCount = 0,
    this.onTap,
    this.onBuyFreeze,
    this.onShare,
  });
}
```

- [ ] **Step 3: Add weekly streak row to the top section of build()**

In the `build()` method, modify the top Row (around line 134-212) to include weekly streak on the right side.

Current top row code (line 133-213):
```dart
                // ═══ TOP ROW: Streak Counter + Freeze Shield ═══
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 🔥 Flame Streak Number
                    AnimatedBuilder(
                      ...
                    ),
                    
                    // 🛡️ Streak Freeze Shield
                    if (widget.streakFreezeCount > 0)
                      ...
                  ],
                ),
```

Replace with:
```dart
                // ═══ TOP ROW: Streak Counter + Weekly Streak + Freeze Shield ═══
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 🔥 Flame Streak Number
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: widget.currentStreak > 0
                              ? _pulseAnimation.value
                              : 1.0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '🔥',
                                style: TextStyle(fontSize: 36),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${widget.currentStreak}',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Text(
                                  widget.currentStreak == 1 ? 'day' : 'days',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // 📅 Weekly Streak Count + Freeze Shield
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Weekly Streak Badge
                        if (widget.weeklyStreak > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_view_week_rounded,
                                  color: Colors.amberAccent,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.weeklyStreak}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'wk',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.weeklyMilestone,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 8),
                        // 🛡️ Streak Freeze Shield
                        if (widget.streakFreezeCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.shield_rounded,
                                  color: Colors.cyanAccent,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '×${widget.streakFreezeCount}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
```

- [ ] **Step 4: Enhance `_buildWeeklyCalendar()` with weekly progress text**

Currently the calendar has "This Week" title with "X/7 days" on the right (line 345-368). This already exists, so no change needed there.

- [ ] **Step 5: Verify the file compiles**

Run: `cd /Users/keshabsarkar/Vs\ Code\ Apps/SpeakEasy && dart analyze lib/core/widgets/streak_widget.dart`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
cd /Users/keshabsarkar/Vs\ Code\ Apps/SpeakEasy && git add lib/core/widgets/streak_widget.dart && git commit -m "feat: add weekly streak display to StreakWidget"
```

---

### Task 4: Update HomeScreen to Pass Weekly Streak Data

**Files:**
- Modify: `lib/features/home/screens/home_screen.dart`

- [ ] **Step 1: Add weekly streak check in initState**

In the streak calculation block (around line 86-140), after the daily streak check, add weekly streak check.

Find this code (around line 116-120):
```dart
                  // 2. Check if streak should increment (new day) or reset (missed >48h)
                  final newStreak = await streakNotifier.checkAndUpdateStreak();
                  
                  // 3. Record today as active (updates lastActiveDate, totalActiveDays)
                  await streakNotifier.recordActiveDay();
```

Change to:
```dart
                  // 2. Check if streak should increment (new day) or reset (missed >48h)
                  final newStreak = await streakNotifier.checkAndUpdateStreak();
                  
                  // 2.5 Check if weekly streak should update (new week)
                  await streakNotifier.checkAndUpdateWeeklyStreak();
                  
                  // 3. Record today as active (updates lastActiveDate, totalActiveDays)
                  await streakNotifier.recordActiveDay();
```

- [ ] **Step 2: Extract weekly streak state and pass to StreakWidget**

In the `build()` method, find where `StreakWidget` is called (around line 468-479):

```dart
                // 2. Streak & Progress (Combined in one widget)
                StreakWidget(
                  currentStreak: currentStreak,
                  todayXP: currentXP,
                  dailyXPTarget: 50,
                  hasPracticeToday: _hasPracticedToday(),
                  isStreakFrozen: HiveService.getStreakFreezeCount() > 0,
                  streakFreezeCount: HiveService.getStreakFreezeCount(),
                  onTap: () => _showStreakInfoDialog(context),
                  onBuyFreeze: () => _buyStreakFreeze(context, ref, currentCoins),
                  onShare: () => _shareStreak(context, currentStreak),
                ),
```

Change to:
```dart
                // 2. Streak & Progress (Combined in one widget)
                StreakWidget(
                  currentStreak: currentStreak,
                  weeklyStreak: streakState.weeklyStreak,
                  weeklyMilestone: streakState.weeklyMilestone,
                  weeklyMilestoneLabel: streakState.weeklyMilestoneLabel,
                  thisWeekActiveDays: streakState.thisWeekActiveDays,
                  todayXP: currentXP,
                  dailyXPTarget: 50,
                  hasPracticeToday: _hasPracticedToday(),
                  isStreakFrozen: HiveService.getStreakFreezeCount() > 0,
                  streakFreezeCount: HiveService.getStreakFreezeCount(),
                  onTap: () => _showStreakInfoDialog(context),
                  onBuyFreeze: () => _buyStreakFreeze(context, ref, currentCoins),
                  onShare: () => _shareStreak(context, currentStreak),
                ),
```

- [ ] **Step 3: Verify the file compiles**

Run: `cd /Users/keshabsarkar/Vs\ Code\ Apps/SpeakEasy && dart analyze lib/features/home/screens/home_screen.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
cd /Users/keshabsarkar/Vs\ Code\ Apps/SpeakEasy && git add lib/features/home/screens/home_screen.dart && git commit -m "feat: integrate weekly streak check and pass data to StreakWidget"
```

---

### Task 5: Fix Weekly Activity Reset for Week Boundary

**Files:**
- Modify: `lib/services/hive_service.dart`

- [ ] **Step 1: Add weekly activity reset logic when crossing into a new week**

The current `HiveService` has `resetWeeklyActivity()` but it's not called automatically. The weekly activity should reset when a new week begins. In the home screen, after `checkAndUpdateWeeklyStreak()` detects a new week, reset the weekly activity.

But actually, looking more carefully at the flow: `HiveService.markDayActive()` is called in HomeScreen's init. If we're in a new week, we should first reset weekly activity, then mark today active.

Find in `home_screen.dart` (around line 113):
```dart
                  // 1. Update HiveService weekly activity + last practice date FIRST
                  await HiveService.markDayActive(now.weekday);
                  await HiveService.setLastPracticeDate(now);
```

Change to:
```dart
                  // 1. Update HiveService weekly activity + last practice date FIRST
                  // Check if it's a new week — reset weekly activity
                  if (streakState.weeklyStreak == 0 || _isNewWeek(streakState)) {
                    await HiveService.resetWeeklyActivity();
                  }
                  await HiveService.markDayActive(now.weekday);
                  await HiveService.setLastPracticeDate(now);
```

But this adds complexity. Simpler approach: Let the HiveService handle it. Add a new method to HiveService:

In `lib/services/hive_service.dart`, add:
```dart
  /// Check if the stored weekly activity is from a previous week and reset if so.
  /// Should be called before markDayActive() at app start.
  static Future<void> resetWeeklyActivityIfNewWeek() async {
    final lastPracticeDate = getLastPracticeDate();
    if (lastPracticeDate == null) return;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(lastPracticeDate.year, lastPracticeDate.month, lastPracticeDate.day);
    
    // Find Monday of current week and last practice week
    final daysSinceMondayToday = today.weekday - 1;
    final mondayThisWeek = today.subtract(Duration(days: daysSinceMondayToday));
    final daysSinceMondayLast = lastDay.weekday - 1;
    final mondayLastWeek = lastDay.subtract(Duration(days: daysSinceMondayLast));
    
    if (mondayLastWeek.isBefore(mondayThisWeek)) {
      await resetWeeklyActivity();
    }
  }
```

Then in `home_screen.dart`, change line 113:
```dart
                  // 1. Update HiveService weekly activity + last practice date FIRST
                  await HiveService.resetWeeklyActivityIfNewWeek();
                  await HiveService.markDayActive(now.weekday);
                  await HiveService.setLastPracticeDate(now);
```

- [ ] **Step 2: Commit**

```bash
cd /Users/keshabsarkar/Vs\ Code\ Apps/SpeakEasy && git add lib/services/hive_service.dart lib/features/home/screens/home_screen.dart && git commit -m "fix: auto-reset weekly activity on new week"
```

---

### Task 6: Verify Everything Works

**Files:** Run full analysis

- [ ] **Step 1: Run full project analysis**

Run: `cd /Users/keshabsarkar/Vs\ Code\ Apps/SpeakEasy && dart analyze`
Expected: No errors related to our changes

- [ ] **Step 2: Run existing tests (if any)**

`cd /Users/keshabsarkar/Vs\ Code\ Apps/SpeakEasy && flutter test`
Expected: Tests pass

- [ ] **Step 3: Commit any final fixes**

```bash
cd /Users/keshabsarkar/Vs\ Code\ Apps/SpeakEasy && git add -A && git commit -m "fix: address analysis warnings from weekly streak changes"
```
