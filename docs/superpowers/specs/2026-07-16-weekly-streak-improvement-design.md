# Weekly Streak Improvement — Design Spec

## Overview

Improve the home screen's StreakWidget to display weekly streak count alongside the existing daily streak, fix the weekly streak calculation logic, enhance the weekly activity calendar, and add milestone badges. Inspired by Duolingo's streak system.

## Current State

- `StreakWidget` shows daily streak count (🔥), 7-day activity calendar (Mon-Sun), daily XP bar, streak freeze shield, and action buttons
- `GameProgressModel` has `weeklyStreak`, `weeklyActivity`, `weeklyActivityWeekStart` fields
- `StreakService.checkAndUpdateWeeklyStreak()` has a bug — it increments every time it's called instead of only once per week
- `StreakWidget` does **not** display the weekly streak count anywhere in the UI
- Weekly activity calendar shows active/inactive days but no streak context

## Changes

### 1. Fix Weekly Streak Logic (`lib/services/streak_service.dart`)

**Fix `checkAndUpdateWeeklyStreak()`:**

```dart
/// Check if the user completed a full week of activity.
/// A week is complete if the user was active at least 1 day in the previous week.
/// On a new week (Monday):
///   - If previous week had ≥1 active day → increment weeklyStreak
///   - If previous week had 0 active days → reset weeklyStreak to 0
Future<int> checkAndUpdateWeeklyStreak() async {
  final progress = _progressRepository.getProgress();
  if (progress == null) return 0;

  if (!isNewWeek()) {
    // Still in the same week — no weekly streak change
    return progress.weeklyStreak;
  }

  // Check if previous week had any activity
  final hadActivityLastWeek = _hadActivityLastWeek(progress);
  
  if (hadActivityLastWeek) {
    await _progressRepository.incrementWeeklyStreak();
  } else {
    await _progressRepository.resetWeeklyStreak();
  }

  return getCurrentWeeklyStreak();
}
```

**New method `_hadActivityLastWeek()`** — checks the `weeklyActivity` map to determine if the user was active on any day of the previous week.

**Fix `isNewWeek()`** — use ISO week number comparison for accuracy.

### 2. Add Weekly State to Provider (`lib/providers/game/streak_provider.dart`)

Add to `StreakState`:
- `weeklyMilestone` — milestone emoji based on weekly streak count
- `thisWeekActiveDays` — number of days active this week (derived from weekly calendar)
- `weeklyProgress` — progress toward next milestone (0.0 to 1.0)

Add provider methods:
- `getThisWeekActiveDays()` — returns count from HiveService
- `getWeeklyMilestone()` — returns emoji for current weekly streak

### 3. Update StreakWidget UI (`lib/core/widgets/streak_widget.dart`)

**Current layout:**
```
🔥 12 days
Today's practice done!
[M][T][W][T][F][S][S]  ← weekly calendar
[Daily Goal bar]
[Buy Freeze] [Share]
```

**New layout:**
```
🔥 12 days                📅 3-week streak 🌱
Today's practice done!
[M][T][W][T][F][S][S]    ← enhanced calendar
3/7 days this week       ← new progress text
[Daily Goal bar]
[Buy Freeze] [Share]
```

**Detailed UI changes:**

**a) Weekly Streak Row (top right, beside daily streak):**
- Shows calendar icon + "X-week streak"
- Milestone emoji badge at the end
- Small pulsing animation (subtler than the daily flame)

**b) Enhanced `_buildWeeklyCalendar()`:**
- Keep existing 7-day circle grid
- Add "X/7 days this week" text below the calendar
- Highlight consecutive streak days with a gradient/glow
- Show a thin connecting line between consecutive active days

**c) Weekly Milestone Badge:**
| Weeks | Emoji | Label |
|-------|-------|-------|
| 1     | 🌱    | Started |
| 4     | 🔥    | Consistent |
| 12    | ⚡    | Dedicated |
| 26    | 💪    | Committed |
| 52    | 👑    | Legend |

Milestone badge appears as a small pill next to the weekly streak count.

### 4. Home Screen Integration (`lib/features/home/screens/home_screen.dart`)

In the existing streak calculation block (around line 86-140):
- After `checkAndUpdateStreak()`, call `streakNotifier.checkAndUpdateWeeklyStreak()`
- Pass `weeklyStreak` and related data to `StreakWidget`

**New parameters for `StreakWidget`:**
```dart
final int weeklyStreak;
final int thisWeekActiveDays;
```

### 5. Files Modified

| File | Change |
|------|--------|
| `lib/services/streak_service.dart` | Fix weekly streak logic, add `_hadActivityLastWeek()` |
| `lib/providers/game/streak_provider.dart` | Add weekly state fields and methods |
| `lib/core/widgets/streak_widget.dart` | Add weekly streak display, enhance calendar |
| `lib/features/home/screens/home_screen.dart` | Pass weekly streak data, trigger weekly check |
| `lib/repositories/progress_repository.dart` | Ensure weekly streak CRUD methods work correctly |

### 6. Data Flow

```
App opens
  → HomeScreen.initState()
    → streakNotifier.checkAndUpdateStreak()      // daily streak
    → streakNotifier.checkAndUpdateWeeklyStreak() // weekly streak
    → streakNotifier.recordActiveDay()
    → streakNotifier.refresh()
      → StreakState updated with weeklyStreak, milestone, active days
  → StreakWidget rebuilds
    → Shows daily streak (existing) + weekly streak (new)
```

### 7. Edge Cases

- **First week ever**: weeklyStreak stays at 0 until a full calendar week passes
- **Mid-week install**: user starts on Wednesday — no weekly streak until next Monday
- **Week boundary**: when Monday comes, `checkAndUpdateWeeklyStreak()` evaluates the previous week
- **No activity in a week**: weeklyStreak resets to 0
- **Same week, multiple opens**: no duplicate weekly streak increment

## Out of Scope

- Weekly streak freeze (use existing daily streak freeze)
- Share weekly streak (share daily streak covers this)
- Push notifications for weekly streak milestones
