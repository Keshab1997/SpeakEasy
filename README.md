# 🗣️ SpeakEasy - Your AI English Speaking Partner

**SpeakEasy** is a full-featured Flutter mobile app for Bengali speakers to learn English — covering grammar, vocabulary, speaking, listening, AI conversation, gamification, and more.

> **Package name:** `flutter_spoken_english_app`  
> **Version:** 1.0.0+1  
> **SDK:** Flutter 3.3.4+ / Dart 3.3.4+

---

## ✨ Features at a Glance

### 📚 Learning
- **70+ Grammar Lessons** (60+ JSON chapter files) — Beginner to Advanced, with formulas, examples & common mistakes
- **Vocabulary Builder** — Beginner / Intermediate / Advanced levels with pronunciation & Bangla meanings
- **Tense, Article, Preposition** — Dedicated deep-dive modules
- **Sentence Analyzer** — Break down English sentence structure
- **Verb Forms** — Full verb conjugation reference + practice

### 🗣️ Speaking & Listening
- **AI Teacher** — Practice conversations with an AI chat (bring your own API key)
- **Speech Recognition** — Pronunciation exercises via `speech_to_text`
- **Text-to-Speech** — Tap any word to hear it spoken (`flutter_tts`)
- **Listening Exercises** — Categorized audio with comprehension tests
- **Conversation Practice** — Daily / Restaurant / Interview scenarios

### 🎮 Gamification
- **🔥 Streak System** — Daily practice streaks with freeze protection
- **✨ XP & Levels** — Earn experience points and level up
- **🪙 Coin Economy** — Earn coins, buy streak freezes & rewards
- **🏆 Achievements** — Unlock badges for milestones
- **📊 Leaderboard** — Compare progress with others
- **🎯 10+ Game Modes** — Quizzes, word match, sentence builder, tense games & more

### 📝 Assessment
- **Mock Tests** — Full-length practice tests
- **Homework System** — Assignments with grading
- **Quiz Engine** — Multiple-choice & interactive quizzes
- **Common Mistakes** — Wrong-question tracking & review

### 🔧 Utilities
- **Banglish Translator** — Type Bangla in English script, translate
- **Study Plan (To-Do)** — Personalized learning roadmap
- **Guides & Resources** — Student guide, spoken rules, study routine
- **Dark Mode** — Full dark theme support
- **Notifications** — Local + push (OneSignal) + daily re-engagement
- **Feature Gates** — Remote-config-controlled feature toggles

### 📱 Cross-Platform
- Android • iOS • Web • macOS • Windows • Linux

---

## 🏗️ Architecture

### Pattern: **Feature-First + Layered Architecture**

```
lib/
├── core/                  # Shared foundation
│   ├── constants/         # Colors, images, strings, tense constants
│   ├── theme/             # Light & dark themes
│   ├── utils/             # Extensions, validators, helpers
│   └── widgets/           # Reusable widgets (streak, skeleton, etc.)
│
├── features/              # 24 feature modules (self-contained)
│   ├── auth/              # Splash, Login, SignUp
│   ├── home/              # Main 5-tab navigation + dashboard
│   ├── grammar/           # Grammar list, detail, tense, article, preposition
│   ├── vocabulary/        # Chapter words, test screens
│   ├── game/              # Game home, modes, widgets
│   ├── ai_teacher/        # AI chat screen
│   ├── speaking/          # Speaking practice
│   ├── listening/         # Listening exercises
│   ├── conversation/      # Daily/Restaurant/Interview
│   ├── practice/          # Bangla-English, quiz modes
│   ├── mock_test/         # Full-length tests
│   ├── sentence_analyzer/ # Sentence breakdown
│   ├── translator/        # Banglish translator
│   ├── verb_forms/        # Verb reference + practice
│   ├── homework/          # Homework assignments
│   ├── guides/            # Learning guides & resources
│   ├── learning/          # Learning hub screen
│   ├── lessons/           # Lesson viewer
│   ├── profile/           # User profile
│   ├── settings/          # App settings
│   ├── feedback/          # Feedback & admin review
│   ├── admin/             # Admin panel
│   ├── intro/             # Onboarding screens
│   └── quiz/              # Quiz engine
│
├── models/                # 17+ data models
│   ├── game/              # Achievement, level, question, result models
│   └── config/            # Config models
│
├── providers/             # Riverpod state (13 main + game sub-providers)
│   └── game/              # XP, coins, streak, statistics, game state
│
├── repositories/          # Data access layer (7 repos)
│
├── services/              # Business logic (28 services)
│
├── routes/                # Named route definitions
│
├── utils/                 # Utility helpers
│
├── firebase_options.dart  # Firebase config (auto-generated)
│
└── main.dart              # App entry point
```

### 📊 Data Flow

```
UI (ConsumerWidget)
  ── watches ──► Riverpod Provider
                    ── calls ──► Repository
                                    ── read/write ──► Firebase Firestore
                                    ── read/write ──► Hive (local cache)
                                    ── load ──► assets/json/grammar/*.json
```

---

## 🧰 Tech Stack

| Category          | Technology                              |
|-------------------|-----------------------------------------|
| **Framework**     | Flutter 3.3.4+                          |
| **State Mgmt**    | Riverpod 2.x (`flutter_riverpod`)       |
| **Auth**          | Firebase Authentication                 |
| **Database**      | Cloud Firestore + Firebase Storage      |
| **Local Storage** | Hive + Hive Flutter                     |
| **Speech I/O**    | `speech_to_text` + `flutter_tts`        |
| **Audio**         | `audioplayers`                          |
| **Notifications** | `flutter_local_notifications` + OneSignal |
| **Background**    | WorkManager                             |
| **Remote Config** | Firebase Remote Config                  |
| **Analytics**     | Firebase Analytics                      |
| **Animations**    | Confetti widget                         |
| **Ad Network**    | Banner ads (pluggable)                  |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.3.4+
- Dart 3.3.4+
- Firebase project

### Installation

```bash
# Clone
git clone https://github.com/Keshab1997/Flutter-Spoken-English-App.git
cd Flutter-Spoken-English-App

# Install dependencies
flutter pub get

# Run
flutter run
```

### Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add **Android** app → package: `com.speakeasy.english` → download `google-services.json` → place in `android/app/`
3. Add **iOS** app → bundle ID: `com.speakeasy.english` → download `GoogleService-Info.plist` → place in `ios/Runner/`
4. (Optional) Run `flutterfire configure` to regenerate `lib/firebase_options.dart`

### Build for Release

```bash
# Android
flutter build appbundle --release

# iOS
flutter build ios --release
```

---

## 📁 Key Folders Explained

| Folder | Description |
|--------|-------------|
| `lib/core/` | Colors, themes, shared widgets, validators, extensions |
| `lib/features/` | 24 feature modules — each with own screens/widgets |
| `lib/providers/` | Global Riverpod state providers |
| `lib/repositories/` | Firestore ↔ Hive sync layer |
| `lib/services/` | Firebase, AI, Hive, TTS, game logic, notifications |
| `lib/models/` | Data classes for all entities |
| `assets/json/grammar/` | 60+ grammar chapters as structured JSON |

---

## 🔑 Key Design Decisions

1. **Grammar via Local JSON** — Chapters stored in `assets/json/grammar/` (not Firestore) for instant loading, with cache-busting on version bump
2. **Offline-First with Hive** — Progress, favorites, game stats cached locally; Firestore used for cross-device sync
3. **Streak Calculation** — Complex 6-step flow: activity tracking → day check → increment/reset → freeze handling → Firestore upload → provider refresh
4. **Feature Gates** — `FeatureGateWidget` wraps experimental features; controlled via Remote Config
5. **Continue Learning** — Tracks last-opened chapter + pending to-do items; shows resume cards on home

---

## 📄 License

This project is private and not licensed for public distribution.

## 📞 Contact

For questions or support, please open an issue on [GitHub](https://github.com/Keshab1997/Flutter-Spoken-English-App).
