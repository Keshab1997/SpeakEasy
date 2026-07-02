# Spoken English Learning App - Project Plan

## Project Overview

Build a modern Spoken English Learning App using Flutter and Firebase. The app should support English learning from Beginner to Advanced level with AI-powered speaking practice, quizzes, vocabulary, grammar, and conversation modules.

---

# Tech Stack

* Flutter (Latest Stable Version)
* Dart
* Firebase Authentication
* Cloud Firestore
* Firebase Storage
* Riverpod State Management
* Hive Local Database
* speech_to_text
* flutter_tts
* audioplayers
* flutter_local_notifications
* OpenAI API or Gemini API

---

# Architecture

Follow Clean Architecture and Feature-First Structure.

```
lib/
│
├── core/
├── services/
├── models/
├── providers/
├── routes/
├── features/
└── main.dart
```

---

# Theme

Support:

* Light Theme
* Dark Theme

Colors:

Primary Color:

* #2563EB

Secondary Color:

* #10B981

Background:

* White and Dark Gray

---

# Bottom Navigation

1. Home
2. Learn
3. Practice
4. AI Teacher
5. Profile

---

# Authentication Module

Features:

* Splash Screen
* Login Screen
* Sign Up Screen
* Forgot Password
* Google Sign In
* Logout

Firebase Authentication should be used.

---

# Home Module

Display:

* Daily Streak
* Progress Percentage
* Continue Learning
* Today's Word
* Recommended Lessons

---

# Course Module

Levels:

### Beginner

* Alphabet
* Basic Vocabulary
* Greetings
* Daily Sentences

### Intermediate

* Grammar
* Conversation
* Tense
* Prepositions

### Advanced

* Fluency Practice
* Interview English
* Business English
* Idioms and Phrases

---

# Vocabulary Module

Each word contains:

* English word
* Bengali meaning
* Pronunciation
* Example sentence
* Audio pronunciation

Features:

* Search
* Favorites
* Daily Words
* Flashcards

---

# Grammar Module

Topics:

* Parts of Speech
* Tense
* Articles
* Prepositions
* Voice Change
* Narration

---

# Conversation Module

Categories:

* Daily Conversation
* Restaurant Conversation
* Office Conversation
* Interview Conversation
* Phone Conversation
* Travel Conversation

Each lesson contains:

* English sentence
* Bengali meaning
* Audio support

---

# Listening Module

Features:

* Native audio clips
* Play/Pause
* Speed control
* Questions and answers

Use audioplayers package.

---

# Speaking Module

Use speech_to_text package.

Features:

* Speech Recognition
* Convert voice to text
* Compare with original sentence
* Accuracy percentage
* Pronunciation score

---

# AI Teacher Module

Create an AI Chat Screen.

Features:

* Conversation with AI
* Grammar correction
* Alternative sentence suggestions
* Pronunciation guidance
* Vocabulary recommendations

Example:

User:

How are you?

AI:

I am fine, thank you. How are you?

---

# Quiz Module

Types:

### MCQ

* Four options

### Fill in the blanks

### Match the words

### Listening quiz

### Speaking quiz

Store score history.

---

# Progress Module

Track:

* Lessons completed
* Quiz scores
* Speaking score
* Streak days
* Total study time

---

# Achievement Module

Badges:

* Beginner Badge
* 7-Day Streak
* Vocabulary Master
* Grammar Expert
* Conversation Champion

---

# Notification Module

Daily reminders:

* Word of the Day
* Practice Reminder
* Streak Reminder

Use flutter_local_notifications.

---

# Profile Module

Features:

* Profile photo
* Name
* Email
* Learning statistics
* Edit profile

---

# Settings Module

Options:

* Dark Mode
* Notification Settings
* Language Selection
* Logout

---

# Local Storage

Use Hive for:

* Downloaded lessons
* User settings
* Favorites
* Recent history

---

# Firebase Collections

users

```
id
name
email
photoUrl
currentLevel
streak
joinedAt
```

lessons

```
id
title
level
category
content
audioUrl
```

vocabulary

```
id
word
meaning
example
audioUrl
```

quizzes

```
id
question
options
correctAnswer
```

progress

```
userId
completedLessons
quizScore
speakingScore
studyTime
```

---

# Screens

Splash Screen

Login Screen

Sign Up Screen

Home Screen

Course Screen

Lesson Screen

Vocabulary Screen

Grammar Screen

Conversation Screen

Listening Screen

Speaking Screen

Quiz Screen

Result Screen

AI Chat Screen

Achievements Screen

Progress Screen

Profile Screen

Settings Screen

Premium Screen

---

# Packages

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
http:
image_picker:
cached_network_image:
google_sign_in:
```

---

# Code Requirements

* Use Riverpod for state management.
* Create reusable widgets.
* Follow clean architecture.
* Write scalable and maintainable code.
* Use null safety.
* Use responsive UI.
* Add proper loading states.
* Add error handling.
* Add comments where necessary.
* Keep code modular.

---

# Future Features

* AI Speaking Partner
* IELTS Preparation
* Leaderboard
* Certificates
* Premium Subscription
* Offline Mode
* Video Lessons
* Live Classes

Build the application with production-quality code and modern UI design.
