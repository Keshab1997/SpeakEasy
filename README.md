# 🗣️ SpeakEasy - Your AI English Speaking Partner

Learn English through Bengali with interactive lessons, games, AI-powered conversation practice, and more!

## ✨ Features

- **📚 70+ Grammar Lessons** — From alphabet to advanced writing structures
- **📖 Vocabulary Builder** — Beginner, Intermediate, and Advanced levels
- **🎮 Interactive Games** — 10+ game modes including quizzes, word match, sentence builder, and more
- **🤖 AI Teacher** — Practice conversations with AI-powered chat (bring your own API key)
- **🎤 Speaking Practice** — Speech recognition and pronunciation exercises
- **👂 Listening Practice** — Categorized listening exercises with comprehension tests
- **📝 Sentence Analyzer** — Analyze English sentence structure
- **🔥 Streak System** — Daily practice streaks with rewards and freeze options
- **🏆 Gamification** — XP points, coins, achievements, and leaderboard
- **🌙 Dark Mode** — Full dark theme support
- **📱 Cross-Platform** — Android and iOS

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.3.4+)
- Dart (3.3.4+)
- Firebase project (see Setup below)

### Installation

```bash
# Clone the repository
git clone https://github.com/Keshab1997/Flutter-Spoken-English-App.git

# Navigate to project directory
cd Flutter-Spoken-English-App

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add Android app with package name: `com.speakeasy.english`
3. Download `google-services.json` and place in `android/app/`
4. Add iOS app with bundle ID: `com.speakeasy.english`
5. Download `GoogleService-Info.plist` and place in `ios/Runner/`
6. (Optional) Run `flutterfire configure` to regenerate `lib/firebase_options.dart`

### Release Build

```bash
# Android
flutter build appbundle --release

# iOS
flutter build ios --release
```

## 🏗️ Architecture

```
lib/
├── core/              # Theme, constants, widgets, utils
├── features/          # Feature modules (auth, game, grammar, etc.)
├── models/            # Data models
├── providers/         # Riverpod state providers
├── repositories/      # Data layer
├── routes/            # Route definitions
├── services/          # Business logic (Firebase, AI, Hive, etc.)
├── utils/             # Utility functions
├── firebase_options.dart
└── main.dart          # App entry point
```

- **State Management**: Riverpod
- **Local Storage**: Hive
- **Backend**: Firebase (Auth, Firestore, Storage)
- **Speech**: speech_to_text, flutter_tts

## 📄 License

This project is private and not licensed for public distribution.

## 📞 Contact

For questions or support, please open an issue on GitHub.
