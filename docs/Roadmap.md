# Spoken English App Development Roadmap

## Important Rule

Connect Firebase at the beginning of the project.

Do not postpone Firebase integration until the end.

Build the application feature by feature using clean architecture and production-quality code.

---

# Phase 1: Project Setup

Create Flutter project.

Set up:

* Folder structure
* Theme system
* Route management
* Reusable widgets
* Riverpod state management

Install packages:

```yaml
firebase_core:
firebase_auth:
cloud_firestore:
firebase_storage:
flutter_riverpod:
hive:
hive_flutter:
speech_to_text:
flutter_tts:
audioplayers:
flutter_local_notifications:
google_sign_in:
http:
image_picker:
cached_network_image:
```

---

# Phase 2: Firebase Setup

Create Firebase project.

Connect Android application.

Configure:

* firebase_core
* Firebase Authentication
* Cloud Firestore
* Firebase Storage

Generate:

```text
firebase_options.dart
```

Initialize Firebase inside:

```text
main.dart
```

Verify Firebase connection before moving to the next phase.

---

# Phase 3: Authentication Module

Build:

* Splash Screen
* Login Screen
* Sign Up Screen
* Forgot Password
* Google Sign In

Features:

* Email Authentication
* Google Authentication
* Logout

Store user information in Firestore.

Collection:

```text
users
```

Fields:

```text
id
name
email
photoUrl
joinedAt
streak
currentLevel
```

---

# Phase 4: Main UI Development

Build Bottom Navigation.

Tabs:

1. Home
2. Learn
3. Practice
4. AI Teacher
5. Profile

Support:

* Light Theme
* Dark Theme

Use Material 3 design.

---

# Phase 5: Home Screen

Sections:

* Greeting
* Daily Streak
* Progress Card
* Today's Word
* Continue Learning
* Quick Practice
* Daily Challenge
* AI Teacher Banner
* Achievements

Use beautiful illustrations instead of plain icons.

---

# Phase 6: Course Module

Levels:

Beginner

Intermediate

Advanced

Lesson categories:

* Vocabulary
* Grammar
* Conversation
* Listening
* Speaking

Store lesson data in:

```text
lessons
```

---

# Phase 7: Vocabulary Module

Features:

* Search
* Favorites
* Flashcards
* Audio pronunciation

Collection:

```text
vocabulary
```

---

# Phase 8: Grammar Module

Topics:

* Parts of Speech
* Tense
* Articles
* Prepositions
* Voice Change
* Narration

---

# Phase 9: Conversation Module

Categories:

* Daily Conversation
* Restaurant Conversation
* Interview Conversation
* Office Conversation
* Travel Conversation

---

# Phase 10: Listening Module

Use audioplayers package.

Features:

* Native speaker audio
* Speed control
* Questions and answers

---

# Phase 11: Speaking Module

Use speech_to_text package.

Features:

* Speech recognition
* Voice to text
* Pronunciation score
* Accuracy percentage

---

# Phase 12: Quiz Module

Quiz types:

* MCQ
* Fill in the blanks
* Match the words
* Listening quiz
* Speaking quiz

Collection:

```text
quizzes
```

---

# Phase 13: Progress Tracking

Track:

* Lessons completed
* Quiz score
* Speaking score
* Study time
* Streak days

Collection:

```text
progress
```

---

# Phase 14: AI Teacher

Create AI Chat screen.

Features:

* Conversation with AI
* Grammar correction
* Vocabulary suggestions
* Sentence improvement
* Pronunciation guidance

Support:

* OpenAI API
* Gemini API

---

# Phase 15: Notifications

Daily reminders:

* Word of the Day
* Practice Reminder
* Streak Reminder

Use:

```text
flutter_local_notifications
```

---

# Phase 16: Local Storage

Use Hive.

Store:

* Favorites
* Downloaded lessons
* Recent history
* Settings

---

# Phase 17: Profile Module

Features:

* Profile photo
* Statistics
* Edit profile
* Logout

---

# Phase 18: Settings Module

Options:

* Dark Mode
* Language Selection
* Notification Settings

---

# Phase 19: Final Features

Add:

* Offline Mode
* Leaderboard
* Achievements
* Premium Subscription
* Certificates
* Video Lessons

---

# Phase 20: Testing and Release

Perform:

* Error handling
* Loading states
* Performance optimization
* Responsive UI
* Production-quality cleanup

Build scalable and maintainable Flutter code using clean architecture and reusable widgets.
