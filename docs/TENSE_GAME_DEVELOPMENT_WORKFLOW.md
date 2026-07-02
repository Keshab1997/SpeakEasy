# Tense Game Module Development Workflow

## Goal

Build a production-quality Tense Game Module using Flutter + Riverpod + Clean Architecture.

Important:

- Architecture first
- No hardcoded content
- Content will be added later
- Future Firebase sync ready
- Offline-first design

---

# STATUS LEGEND

- ✅ COMPLETE — fully implemented & verified
- 🟡 PARTIAL — scaffolding exists but has gaps (details below)
- ❌ NOT STARTED / MISSING — nothing usable yet
- ⛔ BLOCKING — must be fixed before the feature works at all

---

# PHASE COMPLETION SUMMARY

| Phase | Title | Status | Notes |
|------|-------|--------|-------|
| 1 | Feature Structure | ✅ | Under `lib/features/game/` (not `tense_game/`) |
| 2 | Models | ✅ | 6 models + `.g.dart` adapters generated |
| 3 | JSON Schema | 🟡 | Schemas exist; `game_questions` & `game_progress` EMPTY |
| 4 | Repository Layer | ✅ | 4 repos + Firestore paths |
| 5 | Service Layer | ✅ | All 8 services present |
| 6 | Providers | ✅ | All 10 providers present |
| 7 | Navigation / Screens | ✅ | All screens built |
| 8 | Home Screen UI | ✅ | GameHomeScreen built (overflow fixed) |
| 9 | Level System | ✅ | Beginner / Intermediate / Advanced in JSON |
| 10 | Tense Categories | ✅ | All 12 tenses defined |
| 11 | Game Modes | 🟡 | 6 modes built BUT depend on EMPTY questions JSON |
| 12 | Widgets | ✅ | All 17 widgets exist in `game_widgets.dart` |
| 13 | Question Flow | ✅ | Flow wired in modes |
| 14 | XP System | ✅ | xp_service + xpProvider |
| 15 | Coin System | ✅ | coin_service + coinProvider |
| 16 | Streak System | ✅ | streak_service + streakProvider |
| 17 | Achievement System | ✅ | 11 achievements in JSON + service |
| 18 | Statistics | ✅ | statistics_service + provider |
| 19 | Local Storage | 🟡 | Hive init OK; TypeAdapters NOT registered; no progress seed |
| 20 | Leaderboard | 🟡 | Local only; Firestore path stubbed |
| 21 | Daily Challenge | ✅ | Screen built; depends on questions |
| 22 | Boss Battle | ✅ | Screen built; depends on questions |
| 23 | Sound System | 🟡 | sound_service framework exists; NO sound files |
| 24 | Animation System | ❌ | Lottie/Confetti deps NOT in pubspec |
| 25 | Offline Mode | 🟡 | Hive present but adapters unregistered |
| 26 | Firebase Preparation | 🟡 | Sdk in pubspec; repos have Firestore calls |
| 27 | Content Integration | ⛔ | ZERO questions authored — game cannot be played |
| 28 | Final Polish | ❌ | Confetti/Lottie/sound missing |

**Overall: ~18 / 28 phases complete. The architecture is ~95% done, but the module is NOT playable yet because there are no questions.**

---

# CRITICAL ISSUES (fix first — these block a working game)

### ⛔ 1. `game_questions.json` is EMPTY — `questions: []`

Location: `assets/json/game/game_questions.json`

The entire game loads questions via:
`GameService.loadQuestions()` → `GameRepository.loadFromJson()` → reads this file.

Because the array is empty, **every game mode returns 0 questions** → nothing can be played.
This is the single most important thing to fix.

**Action:** Author real questions. See Phase 27 below for the order.

### ⛔ 2. Hive TypeAdapters are generated but NEVER registered

`grep Hive.registerAdapter lib/` returns ZERO hits, but 7 adapters exist in `*.g.dart`
(`GameQuestionModelAdapter`, `GameLevelModelAdapter`, `GameResultModelAdapter`,
`GameProgressModelAdapter`, `AchievementModelAdapter`, `LevelModelAdapter`,
`TenseCategoryAdapter`).

The app currently works around this by storing everything as raw `Map<String,dynamic>`
via `toMap()`/`fromMap()`, so the typed adapters are dead code.

**Action:** Either (a) register adapters in `main.dart` after `HiveService.initialize()`,
or (b) remove the `@HiveType` annotations + `.g.dart` files to stop maintaining dead code.

### ⛔ 3. No initial `GameProgressModel` seed

`progress_repository.dart` early-returns from `addXP`, `addCoins`, `incrementStreak`,
`spendCoins` when the progress box is null. So XP/coins/streak silently no-op until a
full progress object is first saved somewhere.

**Action:** Add a bootstrap seed in `main.dart` (or in the provider initializer) that
writes a default `GameProgressModel` to the `game_progress` box on first launch.

---

# REMAINING WORK (non-blocking, do after critical fixes)

- ❌ Phase 24: Add `lottie` + `confetti` (e.g. `flutter_animate`) to `pubspec.yaml`; wire into result/achievement screens.
- 🟡 Phase 23: Add actual sound asset files (`assets/sounds/*.mp3`) for correct/wrong/click/level-up/unlock/boss. Update `sound_service.dart` `_getAssetPath` to point at them.
- 🟡 Phase 20: Leaderboard is local-only. Firestore path is stubbed but not fed real data.
- 🟡 Phase 25/26: Offline/Firebase — adapters must be registered (see critical #2) before typed Hive storage works; Firestore calls exist in repos but are not the default source.

---

# WHERE TO RESTART

## 👉 START HERE → Phase 27 : Content Integration (author questions)

Because the architecture is complete, the only thing standing between you and a playable
game is content. Everything else is polish.

### Step 1 — Author questions in this exact order (from Phase 27):

1. Present Indefinite
2. Present Continuous
3. Present Perfect
4. Present Perfect Continuous
5. Past Indefinite
6. Past Continuous
7. Past Perfect
8. Past Perfect Continuous
9. Future Indefinite
10. Future Continuous
11. Future Perfect
12. Future Perfect Continuous

For each tense, write questions covering ALL 6 modes (fill_blank, choose_tense,
sentence_builder, error_detection, translation_challenge, speed_quiz) and 3 difficulties
(easy / medium / hard).

Recommended volume per tense: ~30–50 questions → ~400–600 total.

### Step 2 — Register Hive adapters (critical #2)

In `main.dart`, after `await HiveService.initialize();`:
```dart
Hive.registerAdapter(GameQuestionModelAdapter());
Hive.registerAdapter(GameLevelModelAdapter());
Hive.registerAdapter(GameResultModelAdapter());
Hive.registerAdapter(GameProgressModelAdapter());
Hive.registerAdapter(AchievementModelAdapter());
// ...etc for all 7
```
(Or delete the `@HiveType` annotations if you choose to keep Map-based storage.)

### Step 3 — Seed initial progress (critical #3)

Add a one-time default `GameProgressModel` write so XP/coin/streak mutations work.

### Step 4 — Then move to polish (Phase 28)

Sounds → Animations → Final polish.

---

# EXISTING CODE MAP (what is already built)

### Models — `lib/models/game/`
- `game_question_model.dart` (+`.g.dart`)
- `game_level_model.dart` (+`.g.dart`)
- `game_result_model.dart` (+`.g.dart`)
- `game_progress_model.dart` (+`.g.dart`)
- `achievement_model.dart` (+`.g.dart`)
- `level_model.dart` (+`.g.dart`)

### Repositories — `lib/repositories/`
- `game_repository.dart` (JSON cache + Firestore)
- `progress_repository.dart` (Hive box `game_progress`)
- `statistics_repository.dart` (Hive box `game_statistics`)
- `achievement_repository.dart` (Hive box `game_achievements`)
- `leaderboard_repository.dart` (Hive box `game_leaderboard`)

### Services — `lib/services/`
- `game_service.dart` (208 lines) — question loading + scoring
- `timer_service.dart` (124 lines)
- `sound_service.dart` (87 lines) — ⚠ no asset files yet
- `xp_service.dart` (158 lines)
- `coin_service.dart` (158 lines)
- `streak_service.dart` (350 lines)
- `achievement_service.dart` (179 lines)
- `statistics_service.dart` (275 lines)
- `game_mode_service.dart` (161 lines)
- `hive_service.dart` — Hive init + non-game boxes

### Providers — `lib/providers/game/`
- `game_provider.dart`, `score_provider.dart`, `timer_provider.dart`,
  `xp_provider.dart`, `coin_provider.dart`, `streak_provider.dart`,
  `achievement_provider.dart`, `statistics_provider.dart`,
  `leaderboard_provider.dart`, `sound_provider.dart`

### Screens — `lib/features/game/screens/`
- `game_home_screen.dart` (overflow fixed ✅)
- `mode_selection_screen.dart`, `game_mode_selection_screen.dart`
- `question_screen.dart`, `answer_review_screen.dart`, `result_screen.dart`
- `leaderboard_screen.dart`, `statistics_screen.dart`, `achievements_screen.dart`
- `settings_screen.dart`, `daily_challenge_screen.dart`, `boss_battle_screen.dart`
- `category_selection_screen.dart`, `level_selection_screen.dart`,
  `tense_categories_screen.dart`, `home_screen.dart`, `mode_game_screen.dart`

### Game Modes — `lib/features/game/screens/modes/`
- `fill_blank_mode.dart` (276 lines)
- `choose_tense_mode.dart` (257 lines)
- `sentence_builder_mode.dart` (257 lines)
- `error_detection_mode.dart` (257 lines)
- `translation_challenge_mode.dart` (257 lines)
- `speed_quiz_mode.dart` (257 lines)

### Widgets — `lib/core/widgets/game_widgets.dart` (1278 lines)
All 17 widgets present: QuestionCard, OptionButton, ProgressBar, TimerWidget,
ScoreCard, LifeIndicator, HintButton, ResultCard, AchievementCard, XPBar,
CoinCard, LevelCard, ModeCard, StatCard, StreakCard, DailyChallengeCard,
BossBattleCard.

### JSON Assets — `assets/json/game/`
- `game_questions.json` — ⛔ EMPTY (`questions: []`)
- `game_levels.json` — ✅ 3 levels (Beginner/Intermediate/Advanced) + 12 tenses + Boss
- `game_achievements.json` — ✅ 11 achievements
- `game_progress.json` — 🟡 EMPTY (`progress: []`) — seed needed

### Dependencies in `pubspec.yaml`
- ✅ `hive`, `hive_flutter`, `hive_generator`
- ✅ `firebase_core`, `firebase_auth`, `firebase_storage`
- ✅ `audioplayers`
- ❌ `lottie`, `confetti` / `flutter_animate` — MISSING

---

# ORIGINAL PHASE SPECIFICATIONS (kept for reference)

---

# Phase 1 : Feature Structure

Create:

lib/
└── features/
    └── tense_game/
        ├── models/
        ├── repositories/
        ├── providers/
        ├── screens/
        ├── widgets/
        ├── services/
        ├── data/
        ├── controllers/
        ├── enums/
        ├── constants/
        └── utils/

Goal:

Prepare scalable feature structure.

✅ COMPLETE — implemented under `lib/features/game/` instead of `tense_game/`.
Models live in `lib/models/game/`, repos in `lib/repositories/`, services in
`lib/services/`, providers in `lib/providers/game/`. Folder layout differs from
spec but is functionally complete.

---

# Phase 2 : Models

Create models:

### GameQuestionModel

Fields:

- id
- tenseType
- question
- options
- correctAnswer
- explanation
- difficulty
- mode
- xpReward
- coinReward

---

### GameLevelModel

Fields:

- id
- levelName
- unlocked
- completed
- progress
- totalStars

---

### GameResultModel

Fields:

- score
- correctAnswers
- wrongAnswers
- accuracy
- earnedXP
- earnedCoins
- completedTime

---

### GameProgressModel

Fields:

- currentLevel
- currentXP
- totalCoins
- streak
- unlockedModes

---

### AchievementModel

Fields:

- id
- title
- description
- unlocked
- unlockDate

Requirements:

- JSON Serializable
- Hive TypeAdapter
- Firebase ready
- No hardcoded values

✅ COMPLETE — all 5 models + `LevelModel` exist in `lib/models/game/`.
`.g.dart` adapters generated. ⚠ Adapters NOT registered yet (see critical #2).

---

# Phase 3 : JSON Schema

Create:

assets/json/game

game_questions.json

game_levels.json

game_achievements.json

game_progress.json

Only create structure.

Do not add content yet.

🟡 PARTIAL — 4 schema files exist:
- `game_levels.json` ✅ 3 levels + 15 categories
- `game_achievements.json` ✅ 11 achievements
- `game_questions.json` ⛔ EMPTY array (`questions: []`)
- `game_progress.json` 🟡 EMPTY array (`progress: []`)

---

# Phase 4 : Repository Layer

Create:

repositories/

game_repository.dart

statistics_repository.dart

achievement_repository.dart

progress_repository.dart

leaderboard_repository.dart

Responsibilities:

- Read JSON
- Read Hive
- Write Hive
- Firestore support

✅ COMPLETE — all 5 repositories exist in `lib/repositories/`.
Each has Hive box + Firestore fallback methods.

---

# Phase 5 : Service Layer

Create:

services/

game_service.dart

timer_service.dart

sound_service.dart

xp_service.dart

coin_service.dart

streak_service.dart

achievement_service.dart

statistics_service.dart

Responsibilities:

Business logic only.

✅ COMPLETE — all 8 services present in `lib/services/` (+ extra `game_mode_service.dart`).

---

# Phase 6 : Providers

Create Riverpod providers.

gameProvider

scoreProvider

timerProvider

xpProvider

coinProvider

streakProvider

achievementProvider

statisticsProvider

leaderboardProvider

themeProvider

Use:

StateNotifierProvider

AsyncNotifierProvider

FutureProvider

✅ COMPLETE — all 10 providers present in `lib/providers/game/`
(`themeProvider` in `lib/providers/theme_provider.dart`).

---

# Phase 7 : Navigation

Create screens:

GameHomeScreen

ModeSelectionScreen

QuestionScreen

AnswerReviewScreen

ResultScreen

LeaderboardScreen

StatisticsScreen

AchievementsScreen

SettingsScreen

BossBattleScreen

DailyChallengeScreen

✅ COMPLETE — all listed screens exist in `lib/features/game/screens/`.

---

# Phase 8 : Home Screen UI

Sections:

Continue Playing

Daily Challenge

Current Level

XP Progress

Streak

Achievements

Buttons:

Play Now

Leaderboard

Statistics

Requirements:

Material 3

Responsive

Dark Mode

Smooth Animation

✅ COMPLETE — `GameHomeScreen` built with player stats card, quick stats,
4 game-mode cards, and More options. RenderFlex overflow bug fixed ✅.

---

# Phase 9 : Level System

Levels:

Beginner

Intermediate

Advanced

Each level contains:

Present Tenses

Past Tenses

Future Tenses

Comparison

Special Usage

Boss Level

✅ COMPLETE — 3 levels in `game_levels.json`. Beginner lists all 12 tenses +
Comparison + Special Usage + Boss Level.

---

# Phase 10 : Tense Categories

Present:

Present Indefinite

Present Continuous

Present Perfect

Present Perfect Continuous

Past:

Past Indefinite

Past Continuous

Past Perfect

Past Perfect Continuous

Future:

Future Indefinite

Future Continuous

Future Perfect

Future Perfect Continuous

✅ COMPLETE — all 12 tenses present in `game_levels.json`.

---

# Phase 11 : Game Modes

Create six independent modes.

### Fill in the Blank

### Choose Correct Tense

### Sentence Builder

### Error Detection

### Translation Challenge

### Speed Quiz

Each mode contains:

Timer

Score

Lives

Hint

Pause

Resume

Result Page

🟡 PARTIAL — all 6 mode screens exist in `lib/features/game/screens/modes/`
(250–276 lines each, real question/scoring logic). BUT none can run because
`game_questions.json` is empty. They will work as soon as content is added.

---

# Phase 12 : Widgets

Create reusable widgets.

QuestionCard

OptionButton

ProgressBar

TimerWidget

ScoreCard

LifeIndicator

HintButton

ResultCard

AchievementCard

XPBar

CoinCard

LevelCard

ModeCard

StatCard

StreakCard

DailyChallengeCard

BossBattleCard

✅ COMPLETE — all 17 widgets in `lib/core/widgets/game_widgets.dart` (1278 lines).

---

# Phase 13 : Question Flow

Start Game

↓

Load Question

↓

Show Options

↓

Select Answer

↓

Check Answer

↓

Show Explanation

↓

Update Score

↓

Next Question

↓

Result Screen

✅ COMPLETE — flow wired through `gameProvider` in each mode screen.

---

# Phase 14 : XP System

Correct Answer

+10 XP

Wrong Answer

0 XP

Perfect Round

+50 XP

Daily Challenge

+100 XP

Boss Battle

+200 XP

✅ COMPLETE — `xp_service.dart` + `xpProvider`.

---

# Phase 15 : Coin System

Correct Answer

+5 Coins

Level Complete

+50 Coins

Boss Battle

+100 Coins

Daily Reward

+25 Coins

✅ COMPLETE — `coin_service.dart` + `coinProvider`.

---

# Phase 16 : Streak System

Track:

Daily Streak

Weekly Streak

Longest Streak

Missed Day

Current Streak

✅ COMPLETE — `streak_service.dart` (350 lines) + `streakProvider`.

---

# Phase 17 : Achievement System

Badges:

First Win

10 Correct Answers

100 XP

7-Day Streak

Present Tense Master

Past Tense Master

Future Tense Master

Tense Champion

Boss Slayer

Speed Master

Perfect Round

✅ COMPLETE — all 11 achievements in `game_achievements.json` +
`achievement_service.dart`.

---

# Phase 18 : Statistics

Track:

Games Played

Correct Answers

Wrong Answers

Accuracy %

Average Score

Total XP

Total Coins

Best Streak

Best Score

Boss Wins

Daily Challenge Wins

Time Played

✅ COMPLETE — `statistics_service.dart` (275 lines) + `statisticsProvider`.
Boss wins, daily wins, time_played persisted in Hive.

---

# Phase 19 : Local Storage

Use Hive.

Store:

Progress

XP

Coins

Achievements

Statistics

Current Level

Unlocked Levels

Unlocked Modes

Streak

Settings

Theme

Sound Preferences

🟡 PARTIAL:
- ✅ Hive initialized in `main.dart` via `HiveService.initialize()`.
- ✅ Settings/theme (darkMode) persisted in HiveService settings box.
- ✅ Game boxes (game_progress, game_cache, game_achievements, game_leaderboard,
  game_statistics) opened lazily in repositories.
- ❌ TypeAdapters NOT registered (see critical #2) — typed storage is dead code.
- ❌ No initial progress seed (see critical #3).

---

# Phase 20 : Leaderboard

Prepare structure for:

Global

Friends

Weekly

Monthly

All Time

Initially use local data.

Future:

Firebase Firestore

🟡 PARTIAL — `leaderboard_repository.dart` + `leaderboard_screen.dart` exist.
Local-only for now; Firestore path stubbed but not fed real data.

---

# Phase 21 : Daily Challenge

Generate:

Random Questions

Special Reward

Bonus XP

Bonus Coins

Daily Reset

✅ COMPLETE (structurally) — `daily_challenge_screen.dart` built.
⚠ Depends on questions JSON being populated.

---

# Phase 22 : Boss Battle

Features:

Hard Questions

Limited Lives

Timer

Special Rewards

Boss Badge

✅ COMPLETE (structurally) — `boss_battle_screen.dart` built.
⚠ Depends on questions JSON being populated.

---

# Phase 23 : Sound System

Correct Sound

Wrong Sound

Button Click

Level Complete

Achievement Unlock

Boss Battle

Mute Option

🟡 PARTIAL — `sound_service.dart` framework exists with `AudioPlayer` +
`_getAssetPath` mapping, BUT there are NO sound asset files in `assets/sounds/`.
Nothing will actually play until files are added.

---

# Phase 24 : Animation System

Page Transition

Progress Animation

XP Animation

Coin Animation

Achievement Popup

Confetti

Lottie Support

❌ NOT STARTED — `lottie`, `confetti`, and `flutter_animate` are NOT in
`pubspec.yaml`. No animation code in the game feature.

---

# Phase 25 : Offline Mode

Use Hive.

Allow:

Play without internet

Save progress

Sync later

🟡 PARTIAL — Hive present, but adapters must be registered (critical #2) before
typed local storage fully works. Questions load from JSON (offline) before
Firestore, so offline play works once content exists.

---

# Phase 26 : Firebase Preparation

Future support:

Firestore

Authentication

Leaderboard

Cloud Save

Remote Config

Analytics

🟡 PARTIAL — `firebase_core`, `firebase_auth`, `firebase_storage` in pubspec.
Firestore calls exist in repositories (`game_repository.dart`,
`achievement_repository.dart`, `progress_repository.dart`). NOT the default
data source; JSON is tried first.

---

# Phase 27 : Content Integration

Only after architecture is complete.

Order:

1. Present Indefinite
2. Present Continuous
3. Present Perfect
4. Present Perfect Continuous
5. Past Indefinite
6. Past Continuous
7. Past Perfect
8. Past Perfect Continuous
9. Future Indefinite
10. Future Continuous
11. Future Perfect
12. Future Perfect Continuous

Never add content before architecture.

⛔ BLOCKING — `game_questions.json` is empty (`questions: []`). This is the
#1 thing to do. Architecture is complete; this is the only thing preventing
the game from being playable.

---

# Phase 28 : Final Polish

Add:

Confetti

Lottie Animation

Sound Effects

Boss Battle

Leaderboard

Daily Challenge

Dark Mode

Offline Mode

Firebase Sync

Performance Optimization

❌ NOT STARTED — depends on Phase 24 (animations) and Phase 23 (sound files).

---

# Development Order

1. Folder Structure ✅
2. Models ✅
3. Repositories ✅
4. Services ✅
5. Providers ✅
6. Navigation ✅
7. Screens ✅
8. Widgets ✅
9. State Management ✅
10. Local Storage 🟡 (adapters + seed missing)
11. Game Logic ✅
12. XP System ✅
13. Coin System ✅
14. Achievement System ✅
15. Statistics ✅
16. Daily Challenge ✅
17. Boss Battle ✅
18. Firebase Preparation 🟡
19. Content Integration ⛔ ← START HERE
20. Final Polish ❌

Rule:

Architecture First.
Content Last.
