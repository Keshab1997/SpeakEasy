# Daily Quiz — Full Replacement of Daily Quest

**Date:** 2026-07-08
**Status:** Design Approved

## Overview

Replace the existing task-based Daily Quest system with a dedicated Daily Quiz feature. Users get 10 questions daily (5 vocabulary + 5 grammar) from a curated bank, with per-question timed answering, time-based scoring, and a daily leaderboard.

## Key Requirements

1. Replace current Daily Quest (5 random tasks) entirely
2. 10 questions daily: 5 vocabulary + 5 grammar
3. Questions change daily (date-seeded deterministic selection from a pool of 300+)
4. Quiz available from 6:00 AM until midnight
5. Per-question countdown timer (30s each)
6. Time-based scoring: faster correct answers = more points
7. Daily leaderboard showing rank, score, and time
8. Notifications: 6 AM ready alert, leaderboard rank after submission
9. Streak stays — completing quiz counts as daily activity

## Models

### DailyQuiz

| Field | Type | Description |
|---|---|---|
| `id` | `String` | `quiz_YYYY-MM-DD` |
| `date` | `String` | YYYY-MM-DD format |
| `questions` | `List<DailyQuizQuestion>` | 10 questions for today |
| `isCompleted` | `bool` | User submitted all answers |
| `score` | `int` | Total points earned |
| `totalTime` | `int` | Total elapsed seconds |
| `correctCount` | `int` | Number correct |
| `wrongCount` | `int` | Number wrong / timed out |
| `earnedXP` | `int` | XP earned this quiz |
| `earnedCoins` | `int` | Coins earned this quiz |
| `startedAt` | `DateTime?` | When user started |
| `completedAt` | `DateTime?` | When user submitted |
| `answers` | `List<DailyQuizAnswer>` | Per-question responses |
| `seed` | `int` | Date seed for question selection |

### DailyQuizQuestion

| Field | Type | Description |
|---|---|---|
| `id` | `String` | `dq_{v/g}_NNN` |
| `type` | `String` | `vocabulary` or `grammar` |
| `question` | `String` | Question text |
| `options` | `List<String>` | 4 answer choices |
| `correctAnswer` | `int` | Index of correct option (0-3) |
| `explanation` | `String` | Shown after answering |
| `timeLimit` | `int` | Seconds per question (default 30) |
| `difficulty` | `String` | `easy` / `medium` / `hard` |
| `category` | `String` | e.g. `general`, `present_indefinite` |

### DailyQuizAnswer

| Field | Type | Description |
|---|---|---|
| `questionId` | `String` | Links to question |
| `selectedAnswer` | `int?` | Index chosen (null = timeout) |
| `isCorrect` | `bool` | Whether answer was correct |
| `timeTaken` | `int` | Seconds spent on this question |
| `pointsEarned` | `int` | Points for this question |

## Scoring Formula

```
Per-question scoring:
  Correct answer        → 100 base points
  Time bonus (correct only):
    ≤10s  → +50  (total: 150)
    ≤20s  → +30  (total: 130)
    ≤30s  → +10  (total: 110)
  Wrong / timeout       → 0

Max total: 10 × 150 = 1,500 points

Tiebreaker: total_time (lower wins)
```

XP & Coins awarded:
- Per correct answer: 10 XP + 5 coins
- Completion bonus (all 10 answered): 20 XP + 10 coins
- Total possible: 120 XP + 60 coins

## Timer Design

- **Per-question countdown:** 30 seconds visible (circular progress indicator)
- **Visual states:** Normal (>10s) → Warning yellow (≤10s) → Danger red (≤5s)
- **On timeout:** Auto-advance to next question, answer recorded as incorrect (selectedAnswer: null)
- **Total timer:** Tracks from start to last submission, shown on result screen

## Question Bank

**Location:** `assets/json/daily_quiz/questions.json`

**Structure:**
```json
{
  "version": 1,
  "questions": [
    {
      "id": "dq_v_001",
      "type": "vocabulary",
      "question": "What is the meaning of 'Eloquent'?",
      "options": [
        "Fluent or persuasive speaking",
        "Quiet and reserved",
        "Easily angered",
        "Confused or puzzled"
      ],
      "correctAnswer": 0,
      "explanation": "'Eloquent' means fluent or persuasive in speaking or writing.",
      "timeLimit": 30,
      "difficulty": "medium",
      "category": "general"
    },
    {
      "id": "dq_g_001",
      "type": "grammar",
      "question": "She ____ to school every day.",
      "options": ["go", "goes", "going", "gone"],
      "correctAnswer": 1,
      "explanation": "Third person singular takes 'goes' in Present Indefinite.",
      "timeLimit": 30,
      "difficulty": "easy",
      "category": "present_indefinite"
    }
  ]
}
```

**Target pool size:** 150 vocabulary + 150 grammar = 300+ total

**Daily selection algorithm:**
1. Use `DateTime.now().toIso8601String()` hash as seed
2. From vocabulary pool, pick 5 using seeded shuffle (positions [0..4])
3. From grammar pool, pick 5 using seeded shuffle (positions [0..4])
4. Interleave: V, G, V, G, V, G, V, G, V, G

## Screens

### Screen 1 — DailyQuizScreen (replaces DailyQuestScreen)

States:
- **Not started:** Hero card with "Start Quiz" CTA, shows today's leaderboard top 3
- **In progress:** Shows progress bar, "Resume Quiz" button, current rank
- **Completed:** Shows final score, rank highlight, leaderboard preview

Components:
- Header: date, streak flame, notification bell
- Quiz card: icon, question count, estimated time, start/resume button
- Leaderboard mini: top 3 with current user highlighted
- Progress bar (if in progress)

### Screen 2 — DailyQuizPlayScreen (new)

Layout:
- Top bar: "Question X of 10" + total elapsed timer
- Progress indicator (segmented bar showing answered/current/remaining)
- Question type badge: 📖 Vocabulary / 📝 Grammar
- Question text (large, centered)
- 4 option cards (tap to select)
- After selection: highlight green/red, show explanation for 2s, auto-advance
- Circular countdown in corner (turns red at 5s)

Edge cases:
- Back button: confirm dialog "Quit quiz? Progress will be lost"
- App background: pause timer (resume on foreground)
- Timeout: shake animation, show "Time's up!", auto-advance

### Screen 3 — DailyQuizResultScreen (new)

Layout:
- Score circle: total points center
- Stats row: correct/wrong/accuracy
- Time display: total duration
- Rewards: XP + coins earned
- Leaderboard: rank highlight card + top 3 podium
- CTA buttons: [Home] [View Leaderboard] [Share Score]

## Data Flow

```
6:00 AM ──► NotificationService schedules local notification
                │
                ▼ (user opens app)
        DailyQuizScreen loads
          │  DailyQuizProvider.loadTodayQuiz()
          │    → Check Hive 'daily_quiz_cache' for today's quiz
          │    → If missing: load questions.json → seed pick 10 → save to Hive
          │    → If exists (incomplete): resume from saved state
          │
          ▼ (user taps Start/Resume)
        DailyQuizPlayScreen
          │  For q in 1..10:
          │    Display question + start per-question timer
          │    Wait for answer / timeout
          │    Record DailyQuizAnswer (timeTaken, selectedAnswer, isCorrect)
          │    Calculate pointsEarned → accumulate score
          │    Show explanation (2s)
          │    Advance to next
          │
          ▼ (all 10 answered)
        DailyQuizProvider.completeQuiz()
          │  Calculate final score + totalTime
          │  Award XP + coins via existing XpNotifier/CoinNotifier
          │  Update streak via StreakNotifier
          │  Save completed quiz to Hive
          │  Upload results to Firestore 'daily_quiz_results/{userId}/{date}'
          │  Fetch leaderboard rank
          │
          ▼
        DailyQuizResultScreen
          │  Show score, stats, rewards, leaderboard position
          │  Schedule notification for leaderboard update
```

## File Structure

### New files (8)

| # | File | Purpose |
|---|------|---------|
| 1 | `lib/features/daily_quiz/models/daily_quiz_model.dart` | DailyQuiz, DailyQuizQuestion, DailyQuizAnswer models |
| 2 | `lib/features/daily_quiz/services/daily_quiz_service.dart` | Load quiz, seed selection, scoring, persistence |
| 3 | `lib/features/daily_quiz/services/daily_quiz_leaderboard_service.dart` | Firestore CRUD for quiz results & rankings |
| 4 | `lib/features/daily_quiz/providers/daily_quiz_provider.dart` | StateNotifier for full quiz lifecycle |
| 5 | `lib/features/daily_quiz/screens/daily_quiz_screen.dart` | Main quiz card / landing screen |
| 6 | `lib/features/daily_quiz/screens/daily_quiz_play_screen.dart` | Sequential question UI |
| 7 | `lib/features/daily_quiz/screens/daily_quiz_result_screen.dart` | Results + leaderboard |
| 8 | `assets/json/daily_quiz/questions.json` | Question bank (300+ questions) |

### Files to modify

| File | Change |
|------|--------|
| Route config (routes/) | Add quiz routes, deprecate old daily_quest routes |
| Home screen | Replace DailyQuest card → DailyQuiz card |
| `NotificationService` | Add 6 AM quiz-ready + leaderboard notifications |
| `pubspec.yaml` | Add `assets/json/daily_quiz/` |
| `game_service.dart` / `result_screen.dart` | Remove DailyQuestTaskTracker references |
| Streak / XP / Coin providers | Ensure quiz completion triggers streak update |

### Files to remove

| File | Reason |
|------|--------|
| `lib/features/daily_quest/` (folder) | Entirely replaced |
| `lib/features/daily_quest/providers/daily_quest_provider.dart` | Replaced by quiz provider |
| `lib/features/daily_quest/screens/daily_quest_screen.dart` | Replaced by quiz screen |
| `lib/features/daily_quest/services/daily_quest_service.dart` | Replaced by quiz service |
| `lib/features/daily_quest/models/daily_quest_model.dart` | Replaced by quiz models |
| `lib/features/daily_quest/models/daily_quest_task_model.dart` | Replaced by quiz question model |

## Leaderboard Integration

Leverage existing `LeaderboardType.daily` infrastructure:

1. **Upload:** After quiz completion, call `dailyQuizLeaderboardService.uploadResult(userId, userName, score, totalTime, correctCount)`
2. **Storage:** Firestore collection `daily_quiz_leaderboard` with docs keyed by `YYYY-MM-DD` containing subcollection of user entries
3. **Ranking:** Query ordered by `score DESC, totalTime ASC`, limit 100
4. **Caching:** Same Hive `leaderboard_cache` box, keyed by date

## Notification Schedule

| Trigger | Timing | Type | Message |
|---------|--------|------|---------|
| Quiz available | 6:00 AM | Local scheduled | 🌅 **Daily Quiz Ready!** 10 new questions waiting — complete by midnight |
| Quiz incomplete | 8:00 PM (weekdays) / 6:00 PM (weekends) | Local scheduled (if not completed) | ⏰ **Don't forget today's quiz!** Your streak is at risk 🔥 |
| After submission | Immediate | Local (on complete) | 🏆 **You're #{rank} today!** {top_name} leads with {score} pts |

All notifications use existing `FlutterLocalNotificationsPlugin` via `NotificationService`.

## State Management

`DailyQuizNotifier` extends `StateNotifier<DailyQuizState>`:

```dart
class DailyQuizState {
  final DailyQuiz? quiz;
  final int currentQuestionIndex;
  final bool isPlaying;
  final bool isLoading;
  final String? error;
  final int? leaderboardRank;
  final List<DailyQuizLeaderboardEntry> topEntries;
}
```

Methods:
- `loadTodayQuiz()` — load or generate today's quiz
- `startQuiz()` — mark startedAt, navigate to play
- `answerQuestion(int selectedIndex)` — record answer, calc points, advance
- `timeoutQuestion()` — record null answer, advance
- `completeQuiz()` — finalize score, upload, award rewards
- `getResult()` — navigate to result screen

## Scoring Implementation

```dart
int calculatePoints(bool isCorrect, int timeTaken) {
  if (!isCorrect) return 0;
  if (timeTaken <= 10) return 150;  // 100 base + 50 bonus
  if (timeTaken <= 20) return 130;  // 100 base + 30 bonus
  if (timeTaken <= 30) return 110;  // 100 base + 10 bonus
  return 100;  // Shouldn't happen (timer enforces 30s max)
}
```

## Error Handling

| Scenario | Handling |
|----------|----------|
| Questions JSON missing/corrupt | Show error state with retry button, fallback to cached version |
| Firestore upload failure | Retry 3x with exponential backoff, queue for later sync |
| Timer drift | Use `DateTime.now()` deltas, not `Timer` ticks |
| App killed mid-quiz | Progress saved to Hive after each answer → resume on reopen |
| Network offline | Quiz works fully offline; leaderboard shows "offline" badge, syncs when online |

## Testing Strategy

- Unit tests for scoring formula
- Unit tests for date-seeded question selection (deterministic)
- Unit tests for persistence (Hive save/load roundtrip)
- Widget tests for each screen state (not started, playing, completed)
- Integration test: full quiz flow from start to result

---

*Spec written per brainstorming process. Ready for review.*
