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

complet

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

---

# Phase 16 : Streak System

Track:

Daily Streak

Weekly Streak

Longest Streak

Missed Day

Current Streak

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

---

# Phase 21 : Daily Challenge

Generate:

Random Questions

Special Reward

Bonus XP

Bonus Coins

Daily Reset

---

# Phase 22 : Boss Battle

Features:

Hard Questions

Limited Lives

Timer

Special Rewards

Boss Badge

---

# Phase 23 : Sound System

Correct Sound

Wrong Sound

Button Click

Level Complete

Achievement Unlock

Boss Battle

Mute Option

---

# Phase 24 : Animation System

Page Transition

Progress Animation

XP Animation

Coin Animation

Achievement Popup

Confetti

Lottie Support

---

# Phase 25 : Offline Mode

Use Hive.

Allow:

Play without internet

Save progress

Sync later

---

# Phase 26 : Firebase Preparation

Future support:

Firestore

Authentication

Leaderboard

Cloud Save

Remote Config

Analytics

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

---

# Development Order

1. Folder Structure
2. Models
3. Repositories
4. Services
5. Providers
6. Navigation
7. Screens
8. Widgets
9. State Management
10. Local Storage
11. Game Logic
12. XP System
13. Coin System
14. Achievement System
15. Statistics
16. Daily Challenge
17. Boss Battle
18. Firebase Preparation
19. Content Integration
20. Final Polish

Rule:

Architecture First.
Content Last.