# Mock Test Unlock Celebration Overlay

**Date:** 2026-07-02
**Status:** Approved Design

## 1. Problem Statement

Currently when a student scores 20/20 (perfect score) on a mock test, the result screen
merely shows a text message: "🎉 Perfect score! You have mastered this test. Next test
is now unlocked!" There is no animation, no confetti, and no celebratory feel to
acknowledge the achievement. The student receives no motivational boost to encourage
them to continue to the next test.

## 2. Goals

1. **Celebratory overlay** — When a student achieves a perfect score (20/20), show a
   beautiful animated overlay on top of the result screen.
2. **Motivational content** — The overlay should congratulate the student and encourage
   them to take the next test.
3. **Progress awareness** — Show overall progress (X/70 tests completed) so the student
   sees how far they've come.
4. **Reward display** — Show XP and coin rewards earned for completing the test.
5. **Clear call to action** — Provide a "Take Next Test" button to keep momentum going.
6. **Confetti particles** — Full celebration with gold/amber confetti.

## 2. Approach

Create a new dedicated `MockTestUnlockOverlay` widget (Approach 1 as selected).
This keeps mock test logic independent from the existing game achievement overlay.

## 3. New File: `MockTestUnlockOverlay`

### 3.1 Location

`lib/features/mock_test/widgets/mock_test_unlock_overlay.dart`

### 3.2 Props / Constructor

```dart
class MockTestUnlockOverlay extends StatefulWidget {
  final int completedTestNumber;
  final String completedTestTitle;
  final int nextTestNumber;
  final int totalCompleted;       // total tests completed so far
  final int totalTests;           // total tests (70)
  final int xpReward;
  final int coinReward;
  final VoidCallback onTakeNextTest;
  final VoidCallback onDismiss;

  const MockTestUnlockOverlay({...});
}
```

### 3.3 Layout Structure

```
┌─────────────────────────────────────┐
│       Semi-transparent backdrop       │
│         (black, 55% opacity)          │
│    ┌─────────────────────────────┐    │
│    │     Celebration Card        │    │
│    │   ┌───────────────────┐     │    │
│    │   │    🏆 (Trophy)    │     │    │  ← 72px, bounce animation
│    │   │  PERFECT SCORE!   │     │    │  ← Gold text, bold, letter-spaced
│    │   │                   │     │    │
│    │   │  🎉 You scored    │     │    │
│    │   │  20/20!           │     │    │  ← Score highlight
│    │   │                   │     │    │
│    │   │  Mock Test X      │     │    │
│    │   │  ✅ Completed     │     │    │
│    │   │                   │     │    │
│    │   │  ─────────────    │     │    │  ← Divider
│    │   │  Next: Test X+1   │     │    │
│    │   │  🔓 Unlocked!     │     │    │  ← Unlock notification
│    │   │  ─────────────    │     │    │
│    │   │                   │     │    │
│    │   │  ████████░░ X/70 │     │    │  ← Progress bar
│    │   │                   │     │    │
│    │   │  ⚡ +50 XP        │     │    │
│    │   │  🪙 +25 Coins     │     │    │  ← Reward chips
│    │   │                   │     │    │
│    │   │ [ TAKE NEXT TEST ]│     │    │  ← Primary button
│    │   │   Stay & Review   │     │    │  ← Text button (dismiss)
│    │   └───────────────────┘     │    │
│    │                             │    │
│    └─────────────────────────────┘    │
│      ✨ Confetti particles (gold)      │
└─────────────────────────────────────┘
```

### 3.4 Animation Timeline

| Time | Animation | Duration |
|------|-----------|----------|
| 0ms | Backdrop fade-in (opacity 0→0.55) | 300ms ease-in |
| 0ms | Confetti start (explosive, star path) | 3s duration |
| 100ms | Card scale 0→1.1→1.0 (spring effect) | 500ms elasticOut |
| 300ms | Trophy icon bounce (scale 0.8→1.2→1.0) | 400ms elasticOut |
| 500ms | Title "PERFECT SCORE!" fade + slide up | 300ms ease-out |
| 700ms | Score + completion status fade in | 300ms |
| 900ms | Progress bar + rewards fade in | 300ms |
| 1100ms | Buttons fade in | 300ms |
| Tap | Dismiss: fade-out all | 200ms |

### 3.5 Color Scheme

| Element | Color |
|---------|-------|
| Card background | Theme cardColor |
| Card border + glow | Amber `#FF9800` (Legendary rarity feel) |
| "PERFECT SCORE" text | `AppColors.secondary` (green) |
| Confetti particles | Gold, amber, white, green |
| Next Test button | `AppColors.secondary` background |
| Progress bar fill | `AppColors.secondary` |

### 3.6 Edge Cases

| Scenario | Behavior |
|----------|----------|
| Last test (Test 70) completed | Show "🎉 You completed all 70 tests!" — no "Next Test" button, just "Back to List" |
| Already completed previous tests | Normal overlay with accurate progress count |
| User presses back | Overlay dismissed, result screen visible |
| All 70 tests completed | Show completion message with congratulations |

## 4. Modified Files

### 4.1 `lib/features/mock_test/screens/mock_test_result_screen.dart`

Changes:
- Convert from `ConsumerWidget` to `ConsumerStatefulWidget` to manage overlay state
- Add `_showCelebration` boolean state
- In `initState`, if `score == total` (isPerfect), set `_showCelebration = true` after a brief delay (300ms to let the result screen render first)
- Wrap Scaffold body in a `Stack` to overlay the celebration on top
- Add reward calculation: XP = testNumber * 10, Coins = testNumber * 5 (or similar formula)

```dart
// New state
bool _showCelebration = false;

@override
void initState() {
  super.initState();
  if (score == total) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showCelebration = true);
    });
  }
}
```

Build method:
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  return Stack(
    children: [
      Scaffold(
        // ... existing content
      ),
      if (_showCelebration)
        MockTestUnlockOverlay(
          completedTestNumber: testNumber,
          completedTestTitle: testTitle,
          nextTestNumber: nextTestNumber,
          totalCompleted: totalCompleted,
          totalTests: 70,
          xpReward: testNumber * 10,
          coinReward: testNumber * 5,
          onTakeNextTest: () {
            setState(() => _showCelebration = false);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => MockTestQuizScreen(
                  testNumber: nextTestNumber,
                  testTitle: 'Mock Test $nextTestNumber',
                ),
              ),
            );
          },
          onDismiss: () => setState(() => _showCelebration = false),
        ),
    ],
  );
}
```

### 4.2 `lib/providers/mock_test_provider.dart`

No major changes needed. The `saveResult()` method already handles unlock logic.
The result screen can read `getTotalCompleted()` and `isTestUnlocked()` from the provider.

## 5. Dependencies

- `confetti: ^0.7.0` — already added in pubspec.yaml (used by `AchievementUnlockOverlay`)
- No new packages needed

## 6. Success Criteria

- [ ] Perfect score (20/20) triggers celebration overlay on result screen
- [ ] Overlay shows with animated entrance (scale, fade, bounce)
- [ ] Confetti particles appear and play for 3 seconds
- [ ] Card displays: trophy, "PERFECT SCORE!", score, test name, next test info
- [ ] Progress bar shows X/70 completed
- [ ] XP and coin rewards displayed
- [ ] "Take Next Test" button navigates to the next test
- [ ] "Stay & Review" button dismisses overlay
- [ ] Last test (70) shows completion message instead of next test button
- [ ] Overlay dismisses cleanly without affecting result screen state
- [ ] All existing mock test functionality preserved (no regressions)
