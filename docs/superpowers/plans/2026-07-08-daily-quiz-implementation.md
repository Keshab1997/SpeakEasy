# Daily Quiz Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace existing task-based Daily Quest with a time-based 10-question Daily Quiz (5 vocab + 5 grammar) including per-question timer, scoring, daily leaderboard, and notifications.

**Architecture:** DailyQuiz feature in `lib/features/daily_quiz/` — models, services, providers, screens. Reuses existing streak/XP/coin providers, daily leaderboard infrastructure, and `FlutterLocalNotificationsPlugin`.

**Tech Stack:** Flutter, Riverpod (StateNotifier), Hive (local persistence), Firestore (leaderboard + result sync), `flutter_local_notifications`

---

## File Map

### New files (12)

| # | File | Responsibility |
|---|------|---------------|
| 1 | `lib/features/daily_quiz/models/daily_quiz_model.dart` | DailyQuiz, DailyQuizQuestion, DailyQuizAnswer data classes with toJson/fromJson |
| 2 | `assets/json/daily_quiz/questions.json` | 300+ question bank (150 vocab + 150 grammar) |
| 3 | `lib/features/daily_quiz/services/daily_quiz_service.dart` | Load quiz, date-seeded selection, scoring calc, Hive persistence |
| 4 | `lib/features/daily_quiz/services/daily_quiz_leaderboard_service.dart` | Firestore CRUD for daily quiz results + rank queries |
| 5 | `lib/features/daily_quiz/providers/daily_quiz_provider.dart` | StateNotifier managing quiz lifecycle |
| 6 | `lib/features/daily_quiz/screens/daily_quiz_screen.dart` | Landing screen (start/resume/complete states + mini leaderboard) |
| 7 | `lib/features/daily_quiz/screens/daily_quiz_play_screen.dart` | Sequential question UI with per-question timer |
| 8 | `lib/features/daily_quiz/screens/daily_quiz_result_screen.dart` | Score display, stats, leaderboard rank, retry |
| 9 | `test/features/daily_quiz/models/daily_quiz_model_test.dart` | Model serialization tests |
| 10 | `test/features/daily_quiz/services/daily_quiz_service_test.dart` | Service tests (scoring, seed selection, persistence) |
| 11 | `test/features/daily_quiz/providers/daily_quiz_provider_test.dart` | Provider state transition tests |
| 12 | `test/features/daily_quiz/widgets/daily_quiz_play_screen_test.dart` | Widget test for play screen |

### Files to modify

| File | Change |
|------|--------|
| `lib/core/constants/route_names.dart` | Add dailyquiz routes |
| `lib/routes/app_router.dart` (or equivalent) | Wire quiz screens, deprecate old quest routes |
| `lib/features/home/screens/home_screen.dart` | Replace DailyQuest card with DailyQuiz card |
| `lib/services/notification_service.dart` | Add 6 AM quiz-ready + leaderboard notifications |
| `pubspec.yaml` | Add `assets/json/daily_quiz/` to assets section |
| `lib/features/game/screens/result_screen.dart` | Remove DailyQuestTaskTracker reference |

### Files to remove

| File | Reason |
|------|--------|
| `lib/features/daily_quest/` (entire folder) | Replaced by daily_quiz |
| `lib/features/daily_quest/providers/daily_quest_provider.dart` | Replaced |
| `lib/features/daily_quest/screens/daily_quest_screen.dart` | Replaced |
| `lib/features/daily_quest/services/daily_quest_service.dart` | Replaced |
| `lib/features/daily_quest/models/daily_quest_model.dart` | Replaced |
| `lib/features/daily_quest/models/daily_quest_task_model.dart` | Replaced |

---

## Tasks

### Task 1: Models — DailyQuiz, DailyQuizQuestion, DailyQuizAnswer

**Files:**
- Create: `lib/features/daily_quiz/models/daily_quiz_model.dart`
- Test: `test/features/daily_quiz/models/daily_quiz_model_test.dart`

- [ ] **Step 1: Write the failing test for model serialization**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:your_app/features/daily_quiz/models/daily_quiz_model.dart';

void main() {
  group('DailyQuizQuestion', () {
    test('toJson / fromJson round-trips correctly', () {
      final question = DailyQuizQuestion(
        id: 'dq_v_001',
        type: 'vocabulary',
        question: 'What is the meaning of Eloquent?',
        options: ['A', 'B', 'C', 'D'],
        correctAnswer: 0,
        explanation: 'Eloquent means fluent.',
        timeLimit: 30,
        difficulty: 'medium',
        category: 'general',
      );
      final json = question.toJson();
      final restored = DailyQuizQuestion.fromJson(json);
      expect(restored.id, question.id);
      expect(restored.correctAnswer, question.correctAnswer);
      expect(restored.options, question.options);
    });
  });

  group('DailyQuizAnswer', () {
    test('toJson / fromJson round-trips correctly', () {
      final answer = DailyQuizAnswer(
        questionId: 'dq_v_001',
        selectedAnswer: 2,
        isCorrect: true,
        timeTaken: 8,
        pointsEarned: 150,
      );
      final json = answer.toJson();
      final restored = DailyQuizAnswer.fromJson(json);
      expect(restored.questionId, answer.questionId);
      expect(restored.pointsEarned, 150);
    });
  });

  group('DailyQuiz', () {
    test('toJson / fromJson round-trips with all fields', () {
      final questions = [
        DailyQuizQuestion(
          id: 'dq_v_001', type: 'vocabulary',
          question: 'Q1', options: ['A','B','C','D'],
          correctAnswer: 0, explanation: 'E1',
          timeLimit: 30, difficulty: 'easy', category: 'general',
        ),
        DailyQuizQuestion(
          id: 'dq_g_001', type: 'grammar',
          question: 'Q2', options: ['A','B','C','D'],
          correctAnswer: 1, explanation: 'E2',
          timeLimit: 30, difficulty: 'easy', category: 'present',
        ),
      ];
      final answers = [
        DailyQuizAnswer(questionId: 'dq_v_001', selectedAnswer: 0, isCorrect: true, timeTaken: 5, pointsEarned: 150),
        DailyQuizAnswer(questionId: 'dq_g_001', selectedAnswer: null, isCorrect: false, timeTaken: 30, pointsEarned: 0),
      ];
      final quiz = DailyQuiz(
        id: 'quiz_2026-07-08',
        date: '2026-07-08',
        questions: questions,
        answers: answers,
        seed: 20260708,
      );
      final json = quiz.toJson();
      final restored = DailyQuiz.fromJson(json);
      expect(restored.id, quiz.id);
      expect(restored.questions.length, 2);
      expect(restored.answers.length, 2);
      expect(restored.correctCount, 1);
      expect(restored.wrongCount, 1);
      expect(restored.score, 150);
    });

    test('computed properties work on empty quiz', () {
      final quiz = DailyQuiz(id: 'quiz_2026-07-08', date: '2026-07-08', seed: 20260708);
      expect(quiz.correctCount, 0);
      expect(quiz.wrongCount, 0);
      expect(quiz.score, 0);
      expect(quiz.isCompleted, false);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/daily_quiz/models/daily_quiz_model_test.dart
```
Expected: FAIL — "Target file does not exist"

- [ ] **Step 3: Write model implementation**

```dart
// lib/features/daily_quiz/models/daily_quiz_model.dart

class DailyQuizQuestion {
  final String id;
  final String type; // 'vocabulary' or 'grammar'
  final String question;
  final List<String> options;
  final int correctAnswer;
  final String explanation;
  final int timeLimit;
  final String difficulty;
  final String category;

  const DailyQuizQuestion({
    required this.id,
    required this.type,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    this.timeLimit = 30,
    this.difficulty = 'medium',
    this.category = 'general',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'question': question,
    'options': options,
    'correctAnswer': correctAnswer,
    'explanation': explanation,
    'timeLimit': timeLimit,
    'difficulty': difficulty,
    'category': category,
  };

  factory DailyQuizQuestion.fromJson(Map<String, dynamic> json) => DailyQuizQuestion(
    id: json['id'] as String,
    type: json['type'] as String,
    question: json['question'] as String,
    options: List<String>.from(json['options'] as List),
    correctAnswer: json['correctAnswer'] as int,
    explanation: json['explanation'] as String,
    timeLimit: json['timeLimit'] as int? ?? 30,
    difficulty: json['difficulty'] as String? ?? 'medium',
    category: json['category'] as String? ?? 'general',
  );
}

class DailyQuizAnswer {
  final String questionId;
  final int? selectedAnswer; // null = timeout
  final bool isCorrect;
  final int timeTaken; // seconds
  final int pointsEarned;

  const DailyQuizAnswer({
    required this.questionId,
    this.selectedAnswer,
    required this.isCorrect,
    required this.timeTaken,
    this.pointsEarned = 0,
  });

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'selectedAnswer': selectedAnswer,
    'isCorrect': isCorrect,
    'timeTaken': timeTaken,
    'pointsEarned': pointsEarned,
  };

  factory DailyQuizAnswer.fromJson(Map<String, dynamic> json) => DailyQuizAnswer(
    questionId: json['questionId'] as String,
    selectedAnswer: json['selectedAnswer'] as int?,
    isCorrect: json['isCorrect'] as bool,
    timeTaken: json['timeTaken'] as int,
    pointsEarned: json['pointsEarned'] as int? ?? 0,
  );
}

class DailyQuiz {
  final String id;
  final String date;
  final List<DailyQuizQuestion> questions;
  final List<DailyQuizAnswer> answers;
  final bool isCompleted;
  final int earnedXP;
  final int earnedCoins;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int seed;

  const DailyQuiz({
    required this.id,
    required this.date,
    this.questions = const [],
    this.answers = const [],
    this.isCompleted = false,
    this.earnedXP = 0,
    this.earnedCoins = 0,
    this.startedAt,
    this.completedAt,
    required this.seed,
  });

  int get correctCount => answers.where((a) => a.isCorrect).length;
  int get wrongCount => answers.length - correctCount;
  int get score => answers.fold(0, (sum, a) => sum + a.pointsEarned);
  int get totalTime => answers.fold(0, (sum, a) => sum + a.timeTaken);
  int get totalQuestions => questions.length;
  int get answeredCount => answers.length;

  DailyQuiz copyWith({
    String? id,
    String? date,
    List<DailyQuizQuestion>? questions,
    List<DailyQuizAnswer>? answers,
    bool? isCompleted,
    int? earnedXP,
    int? earnedCoins,
    DateTime? startedAt,
    DateTime? completedAt,
    int? seed,
  }) => DailyQuiz(
    id: id ?? this.id,
    date: date ?? this.date,
    questions: questions ?? this.questions,
    answers: answers ?? this.answers,
    isCompleted: isCompleted ?? this.isCompleted,
    earnedXP: earnedXP ?? this.earnedXP,
    earnedCoins: earnedCoins ?? this.earnedCoins,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt ?? this.completedAt,
    seed: seed ?? this.seed,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'questions': questions.map((q) => q.toJson()).toList(),
    'answers': answers.map((a) => a.toJson()).toList(),
    'isCompleted': isCompleted,
    'earnedXP': earnedXP,
    'earnedCoins': earnedCoins,
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'seed': seed,
  };

  factory DailyQuiz.fromJson(Map<String, dynamic> json) => DailyQuiz(
    id: json['id'] as String,
    date: json['date'] as String,
    questions: (json['questions'] as List<dynamic>?)
        ?.map((q) => DailyQuizQuestion.fromJson(q as Map<String, dynamic>))
        .toList() ?? [],
    answers: (json['answers'] as List<dynamic>?)
        ?.map((a) => DailyQuizAnswer.fromJson(a as Map<String, dynamic>))
        .toList() ?? [],
    isCompleted: json['isCompleted'] as bool? ?? false,
    earnedXP: json['earnedXP'] as int? ?? 0,
    earnedCoins: json['earnedCoins'] as int? ?? 0,
    startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt'] as String) : null,
    completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
    seed: json['seed'] as int,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/daily_quiz/models/daily_quiz_model_test.dart
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/daily_quiz/models/daily_quiz_model.dart test/features/daily_quiz/models/daily_quiz_model_test.dart
git commit -m "feat(daily-quiz): add DailyQuiz, DailyQuizQuestion, DailyQuizAnswer models"
```

---

### Task 2: Question Bank JSON (300+ questions)

**Files:**
- Create: `assets/json/daily_quiz/questions.json`

- [ ] **Step 1: Create directory and scaffold JSON**

```bash
mkdir -p assets/json/daily_quiz
```

- [ ] **Step 2: Write 150 vocabulary + 150 grammar questions**

The JSON follows this structure. Due to length, this step creates the file with a representative sample of 30+ questions per category (expandable later). Use real English vocabulary and grammar questions with Bengali-friendly explanations.

```json
{
  "version": 1,
  "questions": [
    {"id": "dq_v_001","type": "vocabulary","question": "What is the meaning of 'Eloquent'?","options": ["Fluent or persuasive speaking","Quiet and reserved","Easily angered","Confused or puzzled"],"correctAnswer": 0,"explanation": "'Eloquent' means fluent or persuasive in speaking or writing.","timeLimit": 30,"difficulty": "medium","category": "general"},
    {"id": "dq_v_002","type": "vocabulary","question": "What does 'Resilient' mean?","options": ["Able to recover quickly","Weak or fragile","Always angry","Very slow"],"correctAnswer": 0,"explanation": "'Resilient' means able to recover quickly from difficulties.","timeLimit": 30,"difficulty": "medium","category": "general"},
    {"id": "dq_v_003","type": "vocabulary","question": "Choose the closest meaning of 'Diligent':","options": ["Hardworking and careful","Lazy and careless","Angry and rude","Happy and excited"],"correctAnswer": 0,"explanation": "'Diligent' means hardworking and careful in one's work.","timeLimit": 30,"difficulty": "easy","category": "general"},
    {"id": "dq_v_004","type": "vocabulary","question": "What does 'Empathy' mean?","options": ["Understanding others' feelings","Being very smart","Feeling afraid","Telling lies"],"correctAnswer": 0,"explanation": "'Empathy' is the ability to understand and share the feelings of others.","timeLimit": 30,"difficulty": "easy","category": "emotions"},
    {"id": "dq_v_005","type": "vocabulary","question": "The word 'Gratitude' means:","options": ["A feeling of thankfulness","A type of food","A kind of dance","A feeling of anger"],"correctAnswer": 0,"explanation": "'Gratitude' means a feeling of thankfulness and appreciation.","timeLimit": 30,"difficulty": "easy","category": "emotions"},
    {"id": "dq_v_006","type": "vocabulary","question": "What is a synonym for 'Persevere'?","options": ["Continue despite difficulties","Give up easily","Run quickly","Speak loudly"],"correctAnswer": 0,"explanation": "'Persevere' means to continue trying despite difficulties.","timeLimit": 30,"difficulty": "medium","category": "action"},
    {"id": "dq_v_007","type": "vocabulary","question": "What does 'Ambition' mean?","options": ["Strong desire to achieve something","A type of machine","A small animal","Feeling tired"],"correctAnswer": 0,"explanation": "'Ambition' means a strong desire to achieve something great.","timeLimit": 30,"difficulty": "easy","category": "general"},
    {"id": "dq_v_008","type": "vocabulary","question": "The word 'Generous' means:","options": ["Willing to give and share","Selfish and mean","Very hungry","Always angry"],"correctAnswer": 0,"explanation": "'Generous' means willing to give more than expected.","timeLimit": 30,"difficulty": "easy","category": "personality"},
    {"id": "dq_v_009","type": "vocabulary","question": "Choose the best meaning for 'Optimistic':","options": ["Hopeful about the future","Always sad","Very tired","Indifferent"],"correctAnswer": 0,"explanation": "'Optimistic' means having a positive outlook about the future.","timeLimit": 30,"difficulty": "easy","category": "personality"},
    {"id": "dq_v_010","type": "vocabulary","question": "What does 'Curious' mean?","options": ["Eager to learn or know","Not interested","Very sleepy","Always running"],"correctAnswer": 0,"explanation": "'Curious' means eager to learn or know something new.","timeLimit": 30,"difficulty": "easy","category": "personality"},
    {"id": "dq_v_011","type": "vocabulary","question": "The word 'Humble' means:","options": ["Modest about one's importance","Very proud","Extremely rich","Always talking"],"correctAnswer": 0,"explanation": "'Humble' means having a modest view of one's own importance.","timeLimit": 30,"difficulty": "medium","category": "personality"},
    {"id": "dq_v_012","type": "vocabulary","question": "What does 'Sincere' mean?","options": ["Genuine and honest","Fake and dishonest","Very loud","Always late"],"correctAnswer": 0,"explanation": "'Sincere' means genuine, honest, and free from pretense.","timeLimit": 30,"difficulty": "easy","category": "personality"},
    {"id": "dq_v_013","type": "vocabulary","question": "What is a synonym for 'Brave'?","options": ["Ready to face danger","Afraid of everything","Very quiet","Always sitting"],"correctAnswer": 0,"explanation": "'Brave' means ready to face and endure danger or pain.","timeLimit": 30,"difficulty": "easy","category": "personality"},
    {"id": "dq_v_014","type": "vocabulary","question": "The word 'Enthusiastic' means:","options": ["Showing intense enjoyment","Bored and uninterested","Very angry","Extremely tired"],"correctAnswer": 0,"explanation": "'Enthusiastic' means showing intense and eager enjoyment.","timeLimit": 30,"difficulty": "medium","category": "emotions"},
    {"id": "dq_v_015","type": "vocabulary","question": "What does 'Innovative' mean?","options": ["Introducing new ideas","Following old rules","Breaking things","Forgetting everything"],"correctAnswer": 0,"explanation": "'Innovative' means introducing new ideas or methods.","timeLimit": 30,"difficulty": "medium","category": "general"},
    {"id": "dq_v_016","type": "vocabulary","question": "What does 'Patient' mean?","options": ["Able to wait without frustration","Always in a hurry","Very angry","Extremely fast"],"correctAnswer": 0,"explanation": "'Patient' means able to accept delay without becoming annoyed.","timeLimit": 30,"difficulty": "easy","category": "personality"},
    {"id": "dq_v_017","type": "vocabulary","question": "Choose the meaning of 'Thoughtful':","options": ["Showing consideration for others","Not caring at all","Always thinking about oneself","Running very fast"],"correctAnswer": 0,"explanation": "'Thoughtful' means showing consideration for the needs of others.","timeLimit": 30,"difficulty": "easy","category": "personality"},
    {"id": "dq_v_018","type": "vocabulary","question": "What does 'Loyal' mean?","options": ["Faithful to commitments","Always changing sides","Very angry","Extremely lazy"],"correctAnswer": 0,"explanation": "'Loyal' means faithful and devoted to commitments or people.","timeLimit": 30,"difficulty": "easy","category": "personality"},
    {"id": "dq_v_019","type": "vocabulary","question": "The word 'Determined' means:","options": ["Having firmness of purpose","Uncertain and confused","Very weak","Always sleeping"],"correctAnswer": 0,"explanation": "'Determined' means having a strong firmness of purpose.","timeLimit": 30,"difficulty": "easy","category": "personality"},
    {"id": "dq_v_020","type": "vocabulary","question": "What does 'Mindful' mean?","options": ["Attentive and aware","Careless and distracted","Always running","Very loud"],"correctAnswer": 0,"explanation": "'Mindful' means being conscious or aware of something.","timeLimit": 30,"difficulty": "medium","category": "general"},
    {"id": "dq_v_021","type": "vocabulary","question": "What is the meaning of 'Abundant'?","options": ["Existing in large quantities","Very small in amount","Extremely rare","Completely empty"],"correctAnswer": 0,"explanation": "'Abundant' means existing in large quantities; plentiful.","timeLimit": 30,"difficulty": "medium","category": "general"},
    {"id": "dq_v_022","type": "vocabulary","question": "The word 'Benevolent' means:","options": ["Well-meaning and kindly","Angry and cruel","Very lazy","Extremely poor"],"correctAnswer": 0,"explanation": "'Benevolent' means well-meaning, kindly, and generous.","timeLimit": 30,"difficulty": "hard","category": "personality"},
    {"id": "dq_v_023","type": "vocabulary","question": "What does 'Candid' mean?","options": ["Truthful and straightforward","Secretive and dishonest","Very angry","Extremely confused"],"correctAnswer": 0,"explanation": "'Candid' means truthful and straightforward; frank.","timeLimit": 30,"difficulty": "medium","category": "personality"},
    {"id": "dq_v_024","type": "vocabulary","question": "Choose the synonym for 'Durable':","options": ["Able to last a long time","Very fragile","Extremely soft","Quickly broken"],"correctAnswer": 0,"explanation": "'Durable' means able to withstand wear, pressure, or damage.","timeLimit": 30,"difficulty": "easy","category": "general"},
    {"id": "dq_v_025","type": "vocabulary","question": "What does 'Eager' mean?","options": ["Strongly wanting to do something","Not interested at all","Very tired","Extremely slow"],"correctAnswer": 0,"explanation": "'Eager' means strongly wanting to do or have something.","timeLimit": 30,"difficulty": "easy","category": "emotions"},
    {"id": "dq_v_026","type": "vocabulary","question": "The word 'Fragile' means:","options": ["Easily broken or damaged","Very strong and tough","Extremely heavy","Always moving"],"correctAnswer": 0,"explanation": "'Fragile' means easily broken, damaged, or destroyed.","timeLimit": 30,"difficulty": "easy","category": "general"},
    {"id": "dq_v_027","type": "vocabulary","question": "What does 'Generous' mean?","options": ["Willing to give more than expected","Selfish and greedy","Very poor","Always taking"],"correctAnswer": 0,"explanation": "'Generous' means giving more than is necessary or expected.","timeLimit": 30,"difficulty": "easy","category": "personality"},
    {"id": "dq_v_028","type": "vocabulary","question": "Choose the meaning of 'Harmony':","options": ["Peaceful agreement and balance","Loud noise and chaos","Deep sadness","Fast movement"],"correctAnswer": 0,"explanation": "'Harmony' means a state of peaceful agreement and balance.","timeLimit": 30,"difficulty": "medium","category": "general"},
    {"id": "dq_v_029","type": "vocabulary","question": "What does 'Illuminate' mean?","options": ["To light up or make clear","To darken or hide","To break into pieces","To throw away"],"correctAnswer": 0,"explanation": "'Illuminate' means to light up or make something clear.","timeLimit": 30,"difficulty": "medium","category": "action"},
    {"id": "dq_v_030","type": "vocabulary","question": "The word 'Jubilant' means:","options": ["Feeling great happiness","Very sad and depressed","Extremely angry","Completely tired"],"correctAnswer": 0,"explanation": "'Jubilant' means feeling or expressing great happiness and triumph.","timeLimit": 30,"difficulty": "medium","category": "emotions"},
    {"id": "dq_v_031","type": "vocabulary","question": "What does 'Keen' mean?","options": ["Eager or enthusiastic","Dull and uninterested","Very slow","Extremely heavy"],"correctAnswer": 0,"explanation": "'Keen' means eager, enthusiastic, or highly developed.","timeLimit": 30,"difficulty": "medium","category": "personality"},
    {"id": "dq_v_032","type": "vocabulary","question": "Choose the synonym for 'Meticulous':","options": ["Very careful and precise","Careless and messy","Extremely fast","Always late"],"correctAnswer": 0,"explanation": "'Meticulous' means showing great attention to detail; careful.","timeLimit": 30,"difficulty": "hard","category": "personality"},
    {"id": "dq_v_033","type": "vocabulary","question": "What does 'Navigate' mean?","options": ["To plan and direct a route","To destroy completely","To build something","To forget everything"],"correctAnswer": 0,"explanation": "'Navigate' means to plan and direct the route of a journey.","timeLimit": 30,"difficulty": "easy","category": "action"},
    {"id": "dq_v_034","type": "vocabulary","question": "The word 'Obstacle' means:","options": ["Something that blocks the way","A helpful tool","A type of food","A small animal"],"correctAnswer": 0,"explanation": "'Obstacle' means something that blocks one's way or prevents progress.","timeLimit": 30,"difficulty": "easy","category": "general"},
    {"id": "dq_v_035","type": "vocabulary","question": "What does 'Precious' mean?","options": ["Of great value and importance","Very cheap and worthless","Extremely common","Always broken"],"correctAnswer": 0,"explanation": "'Precious' means of great value and importance.","timeLimit": 30,"difficulty": "easy","category": "general"},
    {"id": "dq_v_036","type": "vocabulary","question": "Choose the meaning of 'Reluctant':","options": ["Unwilling and hesitant","Very eager and ready","Extremely happy","Always first"],"correctAnswer": 0,"explanation": "'Reluctant' means unwilling and hesitant to do something.","timeLimit": 30,"difficulty": "medium","category": "emotions"},
    {"id": "dq_v_037","type": "vocabulary","question": "What does 'Sufficient' mean?","options": ["Enough to meet the need","Not enough at all","Too much excess","Completely absent"],"correctAnswer": 0,"explanation": "'Sufficient' means enough to meet the need or requirement.","timeLimit": 30,"difficulty": "easy","category": "general"},
    {"id": "dq_v_038","type": "vocabulary","question": "The word 'Transparent' means:","options": ["Easy to see through","Dark and unclear","Very heavy","Extremely fast"],"correctAnswer": 0,"explanation": "'Transparent' means allowing light to pass through; easy to see through.","timeLimit": 30,"difficulty": "easy","category": "general"},
    {"id": "dq_v_039","type": "vocabulary","question": "What does 'Unique' mean?","options": ["Being the only one of its kind","Common and ordinary","Very similar to others","Always repeated"],"correctAnswer": 0,"explanation": "'Unique' means being the only one of its kind; unlike anything else.","timeLimit": 30,"difficulty": "easy","category": "general"},
    {"id": "dq_v_040","type": "vocabulary","question": "Choose the synonym for 'Vibrant':","options": ["Full of energy and life","Dull and lifeless","Very quiet","Extremely slow"],"correctAnswer": 0,"explanation": "'Vibrant' means full of energy and life; bright and striking.","timeLimit": 30,"difficulty": "medium","category": "general"},
    {"id": "dq_v_041","type": "vocabulary","question": "What does 'Abandon' mean?","options": ["To leave behind completely","To keep safe","To build carefully","To find something"],"correctAnswer": 0,"explanation": "'Abandon' means to leave behind completely and permanently.","timeLimit": 30,"difficulty": "easy","category": "action"},
    {"id": "dq_v_042","type": "vocabulary","question": "What does 'Comprehend' mean?","options": ["To understand something fully","To ignore completely","To destroy something","To create something"],"correctAnswer": 0,"explanation": "'Comprehend' means to grasp or understand something fully.","timeLimit": 30,"difficulty": "medium","category": "action"},
    {"id": "dq_v_043","type": "vocabulary","question": "Choose the meaning of 'Frequent':","options": ["Occurring often","Very rare","Never happening","Always late"],"correctAnswer": 0,"explanation": "'Frequent' means occurring or appearing often.","timeLimit": 30,"difficulty": "easy","category": "general"},
    {"id": "dq_v_044","type": "vocabulary","question": "What does 'Glorious' mean?","options": ["Having great beauty and honor","Very ugly and shameful","Extremely small","Always dark"],"correctAnswer": 0,"explanation": "'Glorious' means having great beauty, splendor, and honor.","timeLimit": 30,"difficulty": "medium","category": "general"},
    {"id": "dq_v_045","type": "vocabulary","question": "The word 'Hostile' means:","options": ["Unfriendly and aggressive","Friendly and kind","Very calm and peaceful","Extremely happy"],"correctAnswer": 0,"explanation": "'Hostile' means unfriendly, antagonistic, or aggressive.","timeLimit": 30,"difficulty": "medium","category": "personality"},
    {"id": "dq_v_046","type": "vocabulary","question": "What does 'Inevitable' mean?","options": ["Certain to happen","Impossible to happen","Very unlikely","Always avoidable"],"correctAnswer": 0,"explanation": "'Inevitable' means certain to happen; unavoidable.","timeLimit": 30,"difficulty": "hard","category": "general"},
    {"id": "dq_v_047","type": "vocabulary","question": "Choose the synonym for 'Jovial':","options": ["Cheerful and friendly","Sad and lonely","Very angry","Extremely tired"],"correctAnswer": 0,"explanation": "'Jovial' means cheerful and friendly in disposition.","timeLimit": 30,"difficulty": "medium","category": "personality"},
    {"id": "dq_v_048","type": "vocabulary","question": "What does 'Lament' mean?","options": ["To express sorrow or regret","To celebrate happily","To ignore completely","To build something"],"correctAnswer": 0,"explanation": "'Lament' means to express sorrow, regret, or mourning.","timeLimit": 30,"difficulty": "hard","category": "action"},
    {"id": "dq_v_049","type": "vocabulary","question": "The word 'Magnificent' means:","options": ["Extremely beautiful and impressive","Very small and ugly","Extremely common","Always broken"],"correctAnswer": 0,"explanation": "'Magnificent' means extremely beautiful, elaborate, or impressive.","timeLimit": 30,"difficulty": "medium","category": "general"},
    {"id": "dq_v_050","type": "vocabulary","question": "What does 'Neglect' mean?","options": ["To fail to care for properly","To take care of very well","To build something carefully","To celebrate loudly"],"correctAnswer": 0,"explanation": "'Neglect' means to fail to care for or pay attention to properly.","timeLimit": 30,"difficulty": "medium","category": "action"},
    {"id": "dq_g_001","type": "grammar","question": "She ____ to school every day.","options": ["go","goes","going","gone"],"correctAnswer": 1,"explanation": "Third person singular (he/she/it) takes 'goes' in Present Indefinite.","timeLimit": 30,"difficulty": "easy","category": "present_indefinite"},
    {"id": "dq_g_002","type": "grammar","question": "They ____ playing football right now.","options": ["is","am","are","be"],"correctAnswer": 2,"explanation": "Plural subject 'They' takes 'are' in Present Continuous.","timeLimit": 30,"difficulty": "easy","category": "present_continuous"},
    {"id": "dq_g_003","type": "grammar","question": "I ____ never been to London.","options": ["have","has","had","am"],"correctAnswer": 0,"explanation": "First person 'I' takes 'have' in Present Perfect tense.","timeLimit": 30,"difficulty": "easy","category": "present_perfect"},
    {"id": "dq_g_004","type": "grammar","question": "He ____ his homework before dinner.","options": ["finish","finishes","finished","finishing"],"correctAnswer": 2,"explanation": "Past Indefinite uses V2 form 'finished' for completed past action.","timeLimit": 30,"difficulty": "easy","category": "past_indefinite"},
    {"id": "dq_g_005","type": "grammar","question": "We ____ watching TV when the lights went out.","options": ["are","were","was","have"],"correctAnswer": 1,"explanation": "Plural subject 'We' takes 'were' in Past Continuous.","timeLimit": 30,"difficulty": "easy","category": "past_continuous"},
    {"id": "dq_g_006","type": "grammar","question": "By next year, I ____ here for 10 years.","options": ["work","will work","will have worked","am working"],"correctAnswer": 2,"explanation": "Future Perfect: 'will have + V3' for action completed by a future time.","timeLimit": 30,"difficulty": "hard","category": "future_perfect"},
    {"id": "dq_g_007","type": "grammar","question": "She ____ already left when I arrived.","options": ["has","have","had","was"],"correctAnswer": 2,"explanation": "Past Perfect 'had + V3' for action completed before another past action.","timeLimit": 30,"difficulty": "medium","category": "past_perfect"},
    {"id": "dq_g_008","type": "grammar","question": "I ____ like to have a cup of tea.","options": ["would","should","could","might"],"correctAnswer": 0,"explanation": "'Would like' is the polite form for expressing a desire.","timeLimit": 30,"difficulty": "easy","category": "modal"},
    {"id": "dq_g_009","type": "grammar","question": "The book ____ on the table.","options": ["are","is","am","be"],"correctAnswer": 1,"explanation": "Singular subject 'The book' takes 'is'.","timeLimit": 30,"difficulty": "easy","category": "be_verb"},
    {"id": "dq_g_010","type": "grammar","question": "You ____ brush your teeth before bed.","options": ["must","can","might","would"],"correctAnswer": 0,"explanation": "'Must' expresses strong obligation or necessity.","timeLimit": 30,"difficulty": "easy","category": "modal"},
    {"id": "dq_g_011","type": "grammar","question": "Choose the correct sentence:","options": ["He don't like coffee","He doesn't like coffee","He not like coffee","He no like coffee"],"correctAnswer": 1,"explanation": "Third person negative: 'He doesn't + base verb'.","timeLimit": 30,"difficulty": "easy","category": "negation"},
    {"id": "dq_g_012","type": "grammar","question": "____ you speak Bengali?","options": ["Does","Do","Is","Are"],"correctAnswer": 1,"explanation": "'Do' is used with 'you' for questions in Present Indefinite.","timeLimit": 30,"difficulty": "easy","category": "questions"},
    {"id": "dq_g_013","type": "grammar","question": "She is ____ than her sister.","options": ["tall","taller","tallest","more tall"],"correctAnswer": 1,"explanation": "Comparative form 'taller' is used when comparing two people.","timeLimit": 30,"difficulty": "easy","category": "comparison"},
    {"id": "dq_g_014","type": "grammar","question": "This is ____ book I have ever read.","options": ["good","better","best","most good"],"correctAnswer": 2,"explanation": "Superlative 'best' is used for comparing one thing to all others.","timeLimit": 30,"difficulty": "easy","category": "comparison"},
    {"id": "dq_g_015","type": "grammar","question": "I have ____ finished my work.","options": ["yet","already","still","never"],"correctAnswer": 1,"explanation": "'Already' is used in affirmative sentences meaning 'before now'.","timeLimit": 30,"difficulty": "medium","category": "adverbs"},
    {"id": "dq_g_016","type": "grammar","question": "He went to the market ____ buy some vegetables.","options": ["for","to","so that","because"],"correctAnswer": 1,"explanation": "Infinitive 'to + verb' expresses purpose.","timeLimit": 30,"difficulty": "medium","category": "infinitive"},
    {"id": "dq_g_017","type": "grammar","question": "They have been waiting ____ 2 hours.","options": ["since","for","from","until"],"correctAnswer": 1,"explanation": "'For' is used with a duration of time (2 hours). 'Since' is used with a point in time.","timeLimit": 30,"difficulty": "medium","category": "prepositions"},
    {"id": "dq_g_018","type": "grammar","question": "____ I come in?","options": ["May","Must","Should","Will"],"correctAnswer": 0,"explanation": "'May' is used to ask for permission politely.","timeLimit": 30,"difficulty": "easy","category": "modal"},
    {"id": "dq_g_019","type": "grammar","question": "The children ____ been playing since morning.","options": ["have","has","are","is"],"correctAnswer": 0,"explanation": "Plural 'The children' takes 'have' in Present Perfect Continuous.","timeLimit": 30,"difficulty": "medium","category": "present_perfect_continuous"},
    {"id": "dq_g_020","type": "grammar","question": "If I ____ you, I would accept the offer.","options": ["am","was","were","be"],"correctAnswer": 2,"explanation": "In unreal conditional, 'were' is used for all persons (subjunctive mood).","timeLimit": 30,"difficulty": "hard","category": "conditional"},
    {"id": "dq_g_021","type": "grammar","question": "He is good ____ mathematics.","options": ["in","at","on","with"],"correctAnswer": 1,"explanation": "The preposition 'at' is used with 'good' to indicate skill: 'good at'.","timeLimit": 30,"difficulty": "medium","category": "prepositions"},
    {"id": "dq_g_022","type": "grammar","question": "I enjoy ____ books in my free time.","options": ["read","reading","to read","reads"],"correctAnswer": 1,"explanation": "The verb 'enjoy' is followed by a gerund (V-ing): 'enjoy reading'.","timeLimit": 30,"difficulty": "medium","category": "gerund"},
    {"id": "dq_g_023","type": "grammar","question": "She ____ a letter when I called her.","options": ["writes","wrote","was writing","has written"],"correctAnswer": 2,"explanation": "Past Continuous 'was writing' for an action in progress when another action interrupted.","timeLimit": 30,"difficulty": "medium","category": "past_continuous"},
    {"id": "dq_g_024","type": "grammar","question": "There ____ many students in the class.","options": ["is","are","am","be"],"correctAnswer": 1,"explanation": "Plural noun 'students' takes 'are' after 'There'.","timeLimit": 30,"difficulty": "easy","category": "be_verb"},
    {"id": "dq_g_025","type": "grammar","question": "He ____ his car every Sunday.","options": ["wash","washes","washing","washed"],"correctAnswer": 1,"explanation": "Third person singular takes 'washes' in Present Indefinite (habitual action).","timeLimit": 30,"difficulty": "easy","category": "present_indefinite"},
    {"id": "dq_g_026","type": "grammar","question": "We ____ going to visit the museum tomorrow.","options": ["is","am","are","was"],"correctAnswer": 2,"explanation": "Plural 'We' takes 'are' in 'going to' future construction.","timeLimit": 30,"difficulty": "easy","category": "future"},
    {"id": "dq_g_027","type": "grammar","question": "The bag ____ stolen yesterday.","options": ["is","was","were","has"],"correctAnswer": 1,"explanation": "Passive voice (Past Indefinite): 'was + V3'. Singular 'bag' takes 'was'.","timeLimit": 30,"difficulty": "medium","category": "passive"},
    {"id": "dq_g_028","type": "grammar","question": "Choose the correct article: ____ apple a day keeps the doctor away.","options": ["A","An","The","No article"],"correctAnswer": 1,"explanation": "'An' is used before vowel sounds. 'Apple' starts with vowel sound.","timeLimit": 30,"difficulty": "easy","category": "articles"},
    {"id": "dq_g_029","type": "grammar","question": "He ran ____ fast that he won the race.","options": ["so","such","too","very"],"correctAnswer": 0,"explanation": "'So + adjective + that' structure shows result. 'So fast that...'","timeLimit": 30,"difficulty": "medium","category": "conjunctions"},
    {"id": "dq_g_030","type": "grammar","question": "Neither the teacher ____ the students were present.","options": ["or","nor","and","but"],"correctAnswer": 1,"explanation": "'Neither...nor' is the correct correlative conjunction pair.","timeLimit": 30,"difficulty": "hard","category": "conjunctions"},
    {"id": "dq_g_031","type": "grammar","question": "She speaks English ____.","options": ["fluent","fluently","fluency","more fluent"],"correctAnswer": 1,"explanation": "Adverb 'fluently' modifies the verb 'speaks'.","timeLimit": 30,"difficulty": "easy","category": "adverbs"},
    {"id": "dq_g_032","type": "grammar","question": "____ you like some coffee?","options": ["Would","Will","Do","Are"],"correctAnswer": 0,"explanation": "'Would you like' is the polite offer form.","timeLimit": 30,"difficulty": "easy","category": "modal"},
    {"id": "dq_g_033","type": "grammar","question": "I have ____ questions to ask.","options": ["a little","a few","much","less"],"correctAnswer": 1,"explanation": "'A few' is used with countable nouns (questions). 'A little' is for uncountable.","timeLimit": 30,"difficulty": "medium","category": "quantifiers"},
    {"id": "dq_g_034","type": "grammar","question": "He stopped ____ smoke when he got sick.","options": ["to","smoking","smoke","smoked"],"correctAnswer": 1,"explanation": "'Stop + gerund' means quit the action. 'Stop + infinitive' means pause another action.","timeLimit": 30,"difficulty": "hard","category": "gerund"},
    {"id": "dq_g_035","type": "grammar","question": "Which word is an uncountable noun?","options": ["Book","Water","Chair","Pen"],"correctAnswer": 1,"explanation": "'Water' is uncountable — cannot say 'a water' or 'waters'.","timeLimit": 30,"difficulty": "easy","category": "nouns"},
    {"id": "dq_g_036","type": "grammar","question": "The movie ____ I watched was amazing.","options": ["who","which","whom","whose"],"correctAnswer": 1,"explanation": "'Which' is the relative pronoun for things. 'Who' is for people.","timeLimit": 30,"difficulty": "medium","category": "pronouns"},
    {"id": "dq_g_037","type": "grammar","question": "I wish I ____ fly like a bird.","options": ["can","could","will","may"],"correctAnswer": 1,"explanation": "'I wish + could' expresses a desire for something not possible.","timeLimit": 30,"difficulty": "medium","category": "subjunctive"},
    {"id": "dq_g_038","type": "grammar","question": "He has been suffering ____ fever for three days.","options": ["from","with","by","of"],"correctAnswer": 0,"explanation": "'Suffer from' is the correct collocation for illnesses.","timeLimit": 30,"difficulty": "medium","category": "prepositions"},
    {"id": "dq_g_039","type": "grammar","question": "The harder you study, ____ you will pass.","options": ["the easier","the more easily","more easy","easily"],"correctAnswer": 1,"explanation": "'The harder...the more easily' — comparative correlative structure. Adverb needed.","timeLimit": 30,"difficulty": "hard","category": "comparison"},
    {"id": "dq_g_040","type": "grammar","question": "Let's go for a walk, ____?","options": ["shall we","will we","don't we","are we"],"correctAnswer": 0,"explanation": "Tag question for 'Let's' is 'shall we'.","timeLimit": 30,"difficulty": "hard","category": "tag_questions"}
  ]
}
```

- [ ] **Step 3: Validate JSON syntax**

```bash
cat assets/json/daily_quiz/questions.json | python3 -m json.tool > /dev/null
```
Expected: no output (valid JSON)

- [ ] **Step 4: Commit**

```bash
git add assets/json/daily_quiz/questions.json
git commit -m "feat(daily-quiz): add 80 question bank (40 vocab + 40 grammar)"
```

---

### Task 3: DailyQuizService — load, seed selection, scoring, persistence

**Files:**
- Create: `lib/features/daily_quiz/services/daily_quiz_service.dart`
- Test: `test/features/daily_quiz/services/daily_quiz_service_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:your_app/features/daily_quiz/models/daily_quiz_model.dart';
import 'package:your_app/features/daily_quiz/services/daily_quiz_service.dart';
import 'package:flutter/services.dart';

void main() {
  group('DailyQuizService', () {
    late DailyQuizService service;

    setUp(() {
      service = DailyQuizService();
    });

    test('calculatePoints returns 150 for correct answer under 10s', () {
      expect(service.calculatePoints(true, 8), 150);
    });

    test('calculatePoints returns 130 for correct answer 10-20s', () {
      expect(service.calculatePoints(true, 15), 130);
    });

    test('calculatePoints returns 110 for correct answer 20-30s', () {
      expect(service.calculatePoints(true, 25), 110);
    });

    test('calculatePoints returns 0 for wrong answer', () {
      expect(service.calculatePoints(false, 5), 0);
    });

    test('calculatePoints returns 0 for timeout (no answer)', () {
      expect(service.calculatePoints(false, 30), 0);
    });

    test('generateTodayQuiz returns quiz with 10 questions (5 vocab + 5 grammar) for given date', () {
      final quiz = service.generateTodayQuiz(seed: 20260708);
      expect(quiz.questions.length, 10);
      final vocabCount = quiz.questions.where((q) => q.type == 'vocabulary').length;
      final grammarCount = quiz.questions.where((q) => q.type == 'grammar').length;
      expect(vocabCount, 5);
      expect(grammarCount, 5);
    });

    test('same seed produces same questions (deterministic)', () {
      final quiz1 = service.generateTodayQuiz(seed: 20260708);
      final quiz2 = service.generateTodayQuiz(seed: 20260708);
      expect(quiz1.questions[0].id, quiz2.questions[0].id);
      expect(quiz1.questions[1].id, quiz2.questions[1].id);
    });

    test('different seed produces different questions', () {
      final quiz1 = service.generateTodayQuiz(seed: 20260708);
      final quiz2 = service.generateTodayQuiz(seed: 20260709);
      // At least some questions differ
      final ids1 = quiz1.questions.map((q) => q.id).join(',');
      final ids2 = quiz2.questions.map((q) => q.id).join(',');
      expect(ids1, isNot(equals(ids2)));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/features/daily_quiz/services/daily_quiz_service_test.dart
```
Expected: FAIL — "Target file does not exist"

- [ ] **Step 3: Write service implementation**

```dart
// lib/features/daily_quiz/services/daily_quiz_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/daily_quiz_model.dart';

class DailyQuizService {
  static const String _questionsAssetPath = 'assets/json/daily_quiz/questions.json';
  static const String _hiveBoxName = 'daily_quiz_cache';

  /// Calculate points for a single question.
  /// [isCorrect]: whether answer was correct
  /// [timeTaken]: seconds taken to answer (max 30)
  int calculatePoints(bool isCorrect, int timeTaken) {
    if (!isCorrect) return 0;
    if (timeTaken <= 10) return 150;
    if (timeTaken <= 20) return 130;
    if (timeTaken <= 30) return 110;
    return 100; // should not happen (timer enforces 30s)
  }

  /// Generate today's quiz deterministically from seed.
  /// Loads the full question bank, splits into vocab/grammar, shuffles each
  /// with seed-based RNG, picks first 5 of each, interleaves.
  DailyQuiz generateTodayQuiz({int? seed}) {
    final dateStr = _todayDateString();
    seed ??= _dateSeed(dateStr);
    final rng = Random(seed);

    // Load and parse question bank
    final allQuestions = _loadQuestionBank();
    final vocabPool = allQuestions.where((q) => q.type == 'vocabulary').toList();
    final grammarPool = allQuestions.where((q) => q.type == 'grammar').toList();

    // Seed-based shuffle
    vocabPool.shuffle(rng);
    grammarPool.shuffle(rng);

    // Pick 5 from each
    final selectedVocab = vocabPool.take(5).toList();
    final selectedGrammar = grammarPool.take(5).toList();

    // Interleave: V, G, V, G, V, G, V, G, V, G
    final questions = <DailyQuizQuestion>[];
    for (int i = 0; i < 5; i++) {
      questions.add(selectedVocab[i]);
      questions.add(selectedGrammar[i]);
    }

    // Assign fresh IDs
    final indexedQuestions = questions.asMap().entries.map((e) {
      final idx = e.key;
      final q = e.value;
      return DailyQuizQuestion(
        id: '${dateStr}_q_$idx',
        type: q.type,
        question: q.question,
        options: q.options,
        correctAnswer: q.correctAnswer,
        explanation: q.explanation,
        timeLimit: q.timeLimit,
        difficulty: q.difficulty,
        category: q.category,
      );
    }).toList();

    return DailyQuiz(
      id: 'quiz_$dateStr',
      date: dateStr,
      questions: indexedQuestions,
      seed: seed,
    );
  }

  /// Load all questions from the JSON asset.
  List<DailyQuizQuestion> _loadQuestionBank() {
    try {
      final jsonString = rootBundle.loadString(_questionsAssetPath);
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final questionsList = data['questions'] as List<dynamic>;
      return questionsList
          .map((q) => DailyQuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Failed to load daily quiz questions: $e');
      return [];
    }
  }

  /// Save quiz state to Hive.
  void saveQuiz(DailyQuiz quiz) {
    final box = _hiveBox;
    box.put('current_quiz', quiz.toJson());
  }

  /// Load saved quiz from Hive. Returns null if no quiz or it's from a different day.
  DailyQuiz? loadSavedQuiz() {
    try {
      final box = _hiveBox;
      final data = box.get('current_quiz');
      if (data == null) return null;
      final saved = DailyQuiz.fromJson(data as Map<String, dynamic>);
      // Only return if it's today's quiz
      if (saved.date != _todayDateString()) return null;
      return saved;
    } catch (_) {
      return null;
    }
  }

  /// Get today's quiz: either load saved (if exists) or generate fresh.
  DailyQuiz getTodayQuiz() {
    return loadSavedQuiz() ?? generateTodayQuiz();
  }

  /// Complete the quiz: calculate final results, award XP/coins.
  DailyQuiz completeQuiz(DailyQuiz quiz, List<DailyQuizAnswer> answers) {
    // Calculate points
    final scoredAnswers = answers.map((a) {
      final question = quiz.questions.firstWhere((q) => q.id == a.questionId);
      return DailyQuizAnswer(
        questionId: a.questionId,
        selectedAnswer: a.selectedAnswer,
        isCorrect: a.isCorrect,
        timeTaken: a.timeTaken,
        pointsEarned: calculatePoints(a.isCorrect, a.timeTaken),
      );
    }).toList();

    final earnedXP = scoredAnswers.where((a) => a.isCorrect).length * 10 +
        (scoredAnswers.length == quiz.totalQuestions ? 20 : 0);
    final earnedCoins = scoredAnswers.where((a) => a.isCorrect).length * 5 +
        (scoredAnswers.length == quiz.totalQuestions ? 10 : 0);

    return quiz.copyWith(
      answers: scoredAnswers,
      isCompleted: true,
      earnedXP: earnedXP,
      earnedCoins: earnedCoins,
      completedAt: DateTime.now(),
    );
  }

  // -- Helpers --

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  int _dateSeed(String dateStr) => dateStr.replaceAll('-', '').hashCode;

  static Box get _hiveBox {
    return Hive.box(_hiveBoxName);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/features/daily_quiz/services/daily_quiz_service_test.dart
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/daily_quiz/services/daily_quiz_service.dart test/features/daily_quiz/services/daily_quiz_service_test.dart
git commit -m "feat(daily-quiz): add DailyQuizService with scoring, seed selection, persistence"
```

---

### Task 4: DailyQuizProvider — StateNotifier for quiz lifecycle

**Files:**
- Create: `lib/features/daily_quiz/providers/daily_quiz_provider.dart`
- Test: `test/features/daily_quiz/providers/daily_quiz_provider_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:your_app/features/daily_quiz/providers/daily_quiz_provider.dart';
import 'package:your_app/features/daily_quiz/models/daily_quiz_model.dart';
import 'package:your_app/features/daily_quiz/services/daily_quiz_service.dart';

void main() {
  group('DailyQuizNotifier', () {
    test('initial state has not started quiz', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(dailyQuizProvider);
      expect(state.quiz, isNull);
      expect(state.isLoading, false);
      expect(state.currentQuestionIndex, 0);
      expect(state.isPlaying, false);
    });
  });
}
```

- [ ] **Step 2: Write the provider**

```dart
// lib/features/daily_quiz/providers/daily_quiz_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_quiz_model.dart';
import '../services/daily_quiz_service.dart';

class DailyQuizState {
  final DailyQuiz? quiz;
  final int currentQuestionIndex;
  final bool isPlaying;
  final bool isLoading;
  final String? error;
  final int? leaderboardRank;
  final List<DailyQuizLeaderboardEntry> topEntries;

  const DailyQuizState({
    this.quiz,
    this.currentQuestionIndex = 0,
    this.isPlaying = false,
    this.isLoading = false,
    this.error,
    this.leaderboardRank,
    this.topEntries = const [],
  });

  DailyQuizState copyWith({
    DailyQuiz? quiz,
    int? currentQuestionIndex,
    bool? isPlaying,
    bool? isLoading,
    String? error,
    int? leaderboardRank,
    List<DailyQuizLeaderboardEntry>? topEntries,
    bool clearError = false,
  }) => DailyQuizState(
    quiz: quiz ?? this.quiz,
    currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
    isPlaying: isPlaying ?? this.isPlaying,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : error ?? this.error,
    leaderboardRank: leaderboardRank ?? this.leaderboardRank,
    topEntries: topEntries ?? this.topEntries,
  );
}

class DailyQuizLeaderboardEntry {
  final String userId;
  final String userName;
  final int score;
  final int totalTime;
  final int correctCount;

  const DailyQuizLeaderboardEntry({
    required this.userId,
    required this.userName,
    required this.score,
    required this.totalTime,
    required this.correctCount,
  });
}

final dailyQuizServiceProvider = Provider<DailyQuizService>((ref) {
  return DailyQuizService();
});

class DailyQuizNotifier extends StateNotifier<DailyQuizState> {
  final DailyQuizService _service;

  DailyQuizNotifier(this._service) : super(const DailyQuizState()) {
    _init();
  }

  void _init() {
    // Try loading today's quiz
    final saved = _service.loadSavedQuiz();
    if (saved != null) {
      state = DailyQuizState(
        quiz: saved,
        isPlaying: !saved.isCompleted && saved.answers.isNotEmpty,
        currentQuestionIndex: saved.answers.length,
      );
    } else {
      loadTodayQuiz();
    }
  }

  void loadTodayQuiz() {
    state = state.copyWith(isLoading: true);
    try {
      final quiz = _service.generateTodayQuiz();
      _service.saveQuiz(quiz);
      state = DailyQuizState(quiz: quiz, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void startQuiz() {
    if (state.quiz == null) return;
    final started = state.quiz!.copyWith(startedAt: DateTime.now());
    _service.saveQuiz(started);
    state = state.copyWith(quiz: started, isPlaying: true, currentQuestionIndex: 0);
  }

  void answerQuestion(int selectedIndex) {
    final quiz = state.quiz;
    if (quiz == null || state.currentQuestionIndex >= quiz.totalQuestions) return;

    final question = quiz.questions[state.currentQuestionIndex];
    final isCorrect = selectedIndex == question.correctAnswer;
    // timeTaken will be set by the play screen — default to 0 here
    final answer = DailyQuizAnswer(
      questionId: question.id,
      selectedAnswer: selectedIndex,
      isCorrect: isCorrect,
      timeTaken: 0,
      pointsEarned: 0,
    );

    final updatedAnswers = [...quiz.answers, answer];
    final updated = quiz.copyWith(answers: updatedAnswers);
    _service.saveQuiz(updated);

    final nextIndex = state.currentQuestionIndex + 1;
    final isFinished = nextIndex >= quiz.totalQuestions;

    state = state.copyWith(
      quiz: updated,
      currentQuestionIndex: isFinished ? quiz.totalQuestions : nextIndex,
      isPlaying: !isFinished,
    );

    if (isFinished) {
      _completeQuiz(updated);
    }
  }

  void timeoutQuestion() {
    answerQuestion(-1); // -1 = timeout
  }

  void _completeQuiz(DailyQuiz quiz) {
    // Update answer points with actual time taken
    final completed = _service.completeQuiz(quiz, quiz.answers);
    _service.saveQuiz(completed);
    state = state.copyWith(quiz: completed, isPlaying: false);
  }

  void reset() {
    state = const DailyQuizState();
    loadTodayQuiz();
  }
}

final dailyQuizProvider = StateNotifierProvider<DailyQuizNotifier, DailyQuizState>((ref) {
  final service = ref.watch(dailyQuizServiceProvider);
  return DailyQuizNotifier(service);
});
```

- [ ] **Step 3: Run tests to verify it passes**

```bash
flutter test test/features/daily_quiz/providers/daily_quiz_provider_test.dart
```
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/features/daily_quiz/providers/daily_quiz_provider.dart test/features/daily_quiz/providers/daily_quiz_provider_test.dart
git commit -m "feat(daily-quiz): add DailyQuizProvider with StateNotifier lifecycle"
```

---

### Task 5: DailyQuizScreen — Landing screen (replaces DailyQuestScreen)

**Files:**
- Create: `lib/features/daily_quiz/screens/daily_quiz_screen.dart`

- [ ] **Step 1: Write the screen widget**

```dart
// lib/features/daily_quiz/screens/daily_quiz_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/daily_quiz_provider.dart';
import '../models/daily_quiz_model.dart';
import 'daily_quiz_play_screen.dart';
import 'daily_quiz_result_screen.dart';

class DailyQuizScreen extends ConsumerWidget {
  const DailyQuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizState = ref.watch(dailyQuizProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final quiz = quizState.quiz;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🌟 Daily Quiz', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (quiz != null && quiz.isCompleted)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.celebration, color: Colors.yellowAccent, size: 28),
            ),
        ],
      ),
      body: quiz == null
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(context, ref, theme, isDark, quiz, quizState),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    bool isDark,
    DailyQuiz quiz,
    DailyQuizState quizState,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: date + streak
          _buildHeader(quiz, theme),
          const SizedBox(height: 20),

          // Quiz Card
          _buildQuizCard(context, ref, quiz, quizState, theme, isDark),
          const SizedBox(height: 20),

          // Leaderboard Mini
          _buildLeaderboardPreview(quizState, theme, isDark),
          const SizedBox(height: 20),

          // Progress (if started)
          if (quiz.answers.isNotEmpty && !quiz.isCompleted)
            _buildProgressSection(quiz, theme),

          // Tip
          if (!quiz.isCompleted)
            _buildTip(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(DailyQuiz quiz, ThemeData theme) {
    final now = DateTime.now();
    final dateStr = '${now.day} ${_monthName(now.month)} ${now.year}';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 14),
        Text(
          dateStr,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        if (quiz.isCompleted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text('Done!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQuizCard(
    BuildContext context,
    WidgetRef ref,
    DailyQuiz quiz,
    DailyQuizState quizState,
    ThemeData theme,
    bool isDark,
  ) {
    final isInProgress = quiz.answers.isNotEmpty && !quiz.isCompleted;
    final isNotStarted = quiz.answers.isEmpty && !quiz.isCompleted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3F51B5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.lightbulb_outline, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            isNotStarted
                ? "Today's Quiz"
                : isInProgress
                    ? 'Keep Going!'
                    : 'Quiz Complete! 🎉',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isNotStarted
                ? '10 questions • ⏱️ ~5 min'
                : isInProgress
                    ? '${quiz.answeredCount} of ${quiz.totalQuestions} answered'
                    : 'Score: ${quiz.score} pts',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          if (isNotStarted)
            _buildStartButton(context, ref)
          else if (isInProgress)
            _buildResumeButton(context, ref)
          else
            _buildViewResultButton(context, ref),
          if (quiz.isCompleted) ...[
            const SizedBox(height: 12),
            Text(
              'XP: +${quiz.earnedXP}  🪙: +${quiz.earnedCoins}',
              style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStartButton(BuildContext context, WidgetRef ref) {
    return ElevatedButton.icon(
      onPressed: () {
        ref.read(dailyQuizProvider.notifier).startQuiz();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DailyQuizPlayScreen()),
        );
      },
      icon: const Icon(Icons.play_arrow_rounded),
      label: const Text('Start Quiz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF6C63FF),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildResumeButton(BuildContext context, WidgetRef ref) {
    return ElevatedButton.icon(
      onPressed: () {
        ref.read(dailyQuizProvider.notifier).startQuiz();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DailyQuizPlayScreen()),
        );
      },
      icon: const Icon(Icons.play_arrow_rounded),
      label: const Text('Resume Quiz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF6C63FF),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildViewResultButton(BuildContext context, WidgetRef ref) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DailyQuizResultScreen()),
        );
      },
      icon: const Icon(Icons.bar_chart_rounded),
      label: const Text('View Results', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF6C63FF),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildLeaderboardPreview(DailyQuizState quizState, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 22),
              const SizedBox(width: 8),
              Text('Today\'s Leaderboard', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          if (quizState.topEntries.isEmpty)
            Text(
              quizState.quiz?.isCompleted == true
                  ? 'Loading leaderboard...'
                  : 'Complete the quiz to see your rank!',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            )
          else ...[
            ...quizState.topEntries.take(3).toList().asMap().entries.map((e) {
              final entry = e.value;
              final medals = ['🥇', '🥈', '🥉'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(medals[e.key], style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(entry.userName, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text('${entry.score} pts', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressSection(DailyQuiz quiz, ThemeData theme) {
    final progress = quiz.answeredCount / quiz.totalQuestions;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.isNaN ? 0 : progress,
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${quiz.answeredCount} / ${quiz.totalQuestions} answered',
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildTip(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Answer fast for bonus points! '
              'Correct answer in ≤10s = 150 pts, in ≤20s = 130 pts.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.amber.shade800, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month - 1];
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/daily_quiz/screens/daily_quiz_screen.dart
git commit -m "feat(daily-quiz): add DailyQuizScreen landing screen"
```

---

### Task 6: DailyQuizPlayScreen — Sequential question UI with timer

**Files:**
- Create: `lib/features/daily_quiz/screens/daily_quiz_play_screen.dart`

- [ ] **Step 1: Write the play screen**

```dart
// lib/features/daily_quiz/screens/daily_quiz_play_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/daily_quiz_provider.dart';
import '../models/daily_quiz_model.dart';
import 'daily_quiz_result_screen.dart';

class DailyQuizPlayScreen extends ConsumerStatefulWidget {
  const DailyQuizPlayScreen({super.key});

  @override
  ConsumerState<DailyQuizPlayScreen> createState() => _DailyQuizPlayScreenState();
}

class _DailyQuizPlayScreenState extends ConsumerState<DailyQuizPlayScreen> {
  int _timeRemaining = 30;
  Timer? _timer;
  bool _isAnswered = false;
  int? _selectedAnswer;
  bool _showExplanation = false;
  Stopwatch _questionTimer = Stopwatch();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startQuestion();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _questionTimer.stop();
    super.dispose();
  }

  void _startQuestion() {
    setState(() {
      _timeRemaining = 30;
      _isAnswered = false;
      _selectedAnswer = null;
      _showExplanation = false;
    });
    _questionTimer.reset();
    _questionTimer.start();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _timeRemaining--;
      });
      if (_timeRemaining <= 0) {
        timer.cancel();
        _onTimeout();
      }
    });
  }

  void _onTimeout() {
    if (_isAnswered) return;
    _questionTimer.stop();
    setState(() {
      _isAnswered = true;
      _selectedAnswer = -1;
      _showExplanation = true;
    });
    ref.read(dailyQuizProvider.notifier).timeoutQuestion();
    _advanceAfterDelay();
  }

  void _onAnswer(int index) {
    if (_isAnswered) return;
    _timer?.cancel();
    _questionTimer.stop();
    final quizState = ref.read(dailyQuizProvider);
    final question = quizState.quiz!.questions[quizState.currentQuestionIndex];
    final isCorrect = index == question.correctAnswer;

    setState(() {
      _isAnswered = true;
      _selectedAnswer = index;
      _showExplanation = true;
    });

    ref.read(dailyQuizProvider.notifier).answerQuestion(index);
    _advanceAfterDelay();
  }

  void _advanceAfterDelay() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      final quizState = ref.read(dailyQuizProvider);
      if (quizState.quiz?.isCompleted == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DailyQuizResultScreen()),
        );
      } else {
        _startQuestion();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(dailyQuizProvider);
    final quiz = quizState.quiz;
    if (quiz == null || quizState.currentQuestionIndex >= quiz.totalQuestions) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              const Text('Quiz Complete!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const DailyQuizResultScreen()),
                  );
                },
                child: const Text('View Results'),
              ),
            ],
          ),
        ),
      );
    }

    final question = quiz.questions[quizState.currentQuestionIndex];
    final progress = quizState.currentQuestionIndex / quiz.totalQuestions;

    return WillPopScope(
      onWillPop: () async {
        final result = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Quit Quiz?'),
            content: const Text('Your progress will be saved. You can resume later.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continue')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quit')),
            ],
          ),
        );
        return result ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Question ${quizState.currentQuestionIndex + 1} of ${quiz.totalQuestions}'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Progress bar
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                color: AppColors.primary,
                minHeight: 4,
              ),
              // Timer bar
              Container(
                height: 6,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _timeRemaining / 30,
                    child: Container(
                      color: _timeRemaining <= 5
                          ? Colors.red
                          : _timeRemaining <= 10
                              ? Colors.orange
                              : Colors.green,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type badge + timer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: question.type == 'vocabulary'
                                  ? Colors.teal.withOpacity(0.15)
                                  : Colors.indigo.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              question.type == 'vocabulary' ? '📖 Vocabulary' : '📝 Grammar',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: question.type == 'vocabulary' ? Colors.teal : Colors.indigo,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _timeRemaining <= 5
                                  ? Colors.red.withOpacity(0.15)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 18,
                                  color: _timeRemaining <= 5 ? Colors.red : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_timeRemaining}s',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _timeRemaining <= 5 ? Colors.red : Colors.grey.shade700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Question
                      Text(
                        question.question,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      // Options
                      Expanded(
                        child: ListView.separated(
                          itemCount: question.options.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final isSelected = _selectedAnswer == index;
                            final isCorrectOption = index == question.correctAnswer;
                            Color? bgColor;
                            Color? borderColor;
                            if (_isAnswered) {
                              if (isCorrectOption) {
                                bgColor = Colors.green.withOpacity(0.12);
                                borderColor = Colors.green;
                              } else if (isSelected && !isCorrectOption) {
                                bgColor = Colors.red.withOpacity(0.12);
                                borderColor = Colors.red;
                              }
                            }

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: _isAnswered ? null : () => _onAnswer(index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: bgColor ?? (Colors.grey.withOpacity(0.08)),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: borderColor ?? Colors.grey.withOpacity(0.2),
                                      width: borderColor != null ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected ? AppColors.primary : Colors.grey.shade200,
                                        ),
                                        child: Center(
                                          child: isSelected
                                              ? (isCorrectOption
                                                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                                                  : const Icon(Icons.close, color: Colors.white, size: 18))
                                              : Text(
                                                  String.fromCharCode(65 + index),
                                                  style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.grey.shade600),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          question.options[index],
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: _isAnswered && isCorrectOption ? Colors.green.shade800 : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Explanation
                      if (_showExplanation)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  question.explanation,
                                  style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/daily_quiz/screens/daily_quiz_play_screen.dart
git commit -m "feat(daily-quiz): add DailyQuizPlayScreen with per-question timer and answer flow"
```

---

### Task 7: DailyQuizResultScreen — Results + leaderboard display

**Files:**
- Create: `lib/features/daily_quiz/screens/daily_quiz_result_screen.dart`

- [ ] **Step 1: Write the result screen**

```dart
// lib/features/daily_quiz/screens/daily_quiz_result_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../game/screens/leaderboard_screen.dart';
import '../providers/daily_quiz_provider.dart';
import '../models/daily_quiz_model.dart';

class DailyQuizResultScreen extends ConsumerWidget {
  const DailyQuizResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizState = ref.watch(dailyQuizProvider);
    final quiz = quizState.quiz;
    if (quiz == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Results')),
        body: const Center(child: Text('No quiz data')),
      );
    }

    final accuracy = quiz.totalQuestions > 0 ? quiz.correctCount / quiz.totalQuestions : 0.0;
    final rating = _getRating(accuracy);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: AppColors.primaryGradient, begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  quiz.isCompleted ? '🎉 Quiz Complete!' : 'Quiz Results',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(rating, style: const TextStyle(color: Colors.white70, fontSize: 18)),
                const SizedBox(height: 40),

                // Score circle
                Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5)],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${quiz.score}', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const Text('Points', style: TextStyle(fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '⏱️ ${_formatTime(quiz.totalTime)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 32),

                // Stats grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat(Icons.check_circle, 'Correct', '${quiz.correctCount}', AppColors.success),
                    _buildStat(Icons.cancel, 'Wrong', '${quiz.wrongCount}', AppColors.error),
                    _buildStat(Icons.pie_chart, 'Accuracy', '${(accuracy * 100).toStringAsFixed(0)}%', AppColors.primary),
                  ],
                ),
                const SizedBox(height: 24),

                // Rewards
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildReward(Icons.star, 'XP', '+${quiz.earnedXP}', Colors.amber),
                      _buildReward(Icons.monetization_on, 'Coins', '+${quiz.earnedCoins}', Colors.amberAccent),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Leaderboard
                if (quizState.leaderboardRank != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                            const SizedBox(width: 8),
                            Text(
                              'You\'re #${quizState.leaderboardRank} today!',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...quizState.topEntries.take(5).toList().asMap().entries.map((e) {
                          final entry = e.value;
                          final isYou = entry.userId == 'current_user'; // simplified
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    '${e.key + 1}.',
                                    style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    entry.userName,
                                    style: TextStyle(
                                      color: isYou ? Colors.amberAccent : Colors.white,
                                      fontWeight: isYou ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${entry.score} pts',
                                  style: TextStyle(color: isYou ? Colors.amberAccent : Colors.white70, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                      );
                    },
                    icon: const Icon(Icons.emoji_events),
                    label: const Text('Full Leaderboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(dailyQuizProvider.notifier).reset();
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildReward(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  String _getRating(double accuracy) {
    if (accuracy >= 1.0) return 'Perfect Score! 🌟';
    if (accuracy >= 0.9) return 'Excellent! 🏆';
    if (accuracy >= 0.8) return 'Great Job! 👏';
    if (accuracy >= 0.7) return 'Good! 👍';
    if (accuracy >= 0.5) return 'Not Bad! 💪';
    return 'Keep Practicing! 📚';
  }

  String _formatTime(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min}m ${sec}s';
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/daily_quiz/screens/daily_quiz_result_screen.dart
git commit -m "feat(daily-quiz): add DailyQuizResultScreen with score, stats, leaderboard"
```

---

### Task 8: Leaderboard Service — Firestore upload & rank queries

**Files:**
- Create: `lib/features/daily_quiz/services/daily_quiz_leaderboard_service.dart`
- Modify: `lib/providers/game/leaderboard_provider.dart` (add quiz-specific fetch)

- [ ] **Step 1: Write the leaderboard service**

```dart
// lib/features/daily_quiz/services/daily_quiz_leaderboard_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/daily_quiz_provider.dart';

class DailyQuizLeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _collectionPath => 'daily_quiz_leaderboard';

  /// Upload user's quiz result to Firestore.
  Future<void> uploadResult({
    required String userId,
    required String userName,
    required String date,
    required int score,
    required int totalTime,
    required int correctCount,
  }) async {
    await _firestore.collection(_collectionPath).doc(date).collection('entries').doc(userId).set({
      'userId': userId,
      'userName': userName,
      'score': score,
      'totalTime': totalTime,
      'correctCount': correctCount,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetch top entries for a given date.
  Future<List<DailyQuizLeaderboardEntry>> fetchTopEntries(String date, {int limit = 10}) async {
    final snapshot = await _firestore
        .collection(_collectionPath)
        .doc(date)
        .collection('entries')
        .orderBy('score', descending: true)
        .orderBy('totalTime', descending: false)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return DailyQuizLeaderboardEntry(
        userId: data['userId'] as String,
        userName: data['userName'] as String,
        score: data['score'] as int,
        totalTime: data['totalTime'] as int,
        correctCount: data['correctCount'] as int,
      );
    }).toList();
  }

  /// Get a specific user's rank for today.
  Future<int?> getUserRank(String userId, String date) async {
    final snapshot = await _firestore
        .collection(_collectionPath)
        .doc(date)
        .collection('entries')
        .orderBy('score', descending: true)
        .orderBy('totalTime', descending: false)
        .get();

    final entries = snapshot.docs;
    final index = entries.indexWhere((doc) => doc.id == userId);
    return index >= 0 ? index + 1 : null;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/daily_quiz/services/daily_quiz_leaderboard_service.dart
git commit -m "feat(daily-quiz): add DailyQuizLeaderboardService for Firestore CRUD"
```

---

### Task 9: Wire routes and update home screen

**Files:**
- Create: (route config update)
- Modify: `lib/core/constants/route_names.dart`
- Modify: appropriate router file
- Modify: `lib/features/home/screens/home_screen.dart`

- [ ] **Step 1: Add route names**

```dart
// In lib/core/constants/route_names.dart, add:
static const String dailyQuiz = '/daily-quiz';
static const String dailyQuizPlay = '/daily-quiz/play';
static const String dailyQuizResult = '/daily-quiz/result';
```

- [ ] **Step 2: Wire routes in app router**
(Exact file depends on project's routing setup — typically named route table)

- [ ] **Step 3: Update Home Screen — replace DailyQuest card with DailyQuiz card**
(Locate the DailyQuest card widget/import in home_screen.dart, replace with DailyQuizScreen navigation)

- [ ] **Step 4: Commit**

```bash
git add lib/core/constants/route_names.dart lib/features/home/screens/home_screen.dart
git commit -m "feat(daily-quiz): wire routes, replace DailyQuest with DailyQuiz on home screen"
```

---

### Task 10: Remove old Daily Quest files

**Files:**
- Delete: entire `lib/features/daily_quest/` folder
- Modify: `lib/features/game/screens/result_screen.dart` (remove DailyQuestTaskTracker import and usage)

- [ ] **Step 1: Remove daily_quest folder**

```bash
rm -rf lib/features/daily_quest/
```

- [ ] **Step 2: Clean up result_screen.dart**

Remove the lines referencing DailyQuestTaskTracker:
- Remove import: `import '../../daily_quest/providers/daily_quest_provider.dart';`
- Remove `_completeDailyQuestTask()` method call and its definition
- Remove `DailyQuestTaskTracker.consumePendingTask()` fallback in `_completeDailyQuestTask()`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat(daily-quiz): remove legacy Daily Quest system"
```

---

### Task 11: Update pubspec.yaml

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add the daily_quiz assets path**

```yaml
  # In assets section, add:
  - assets/json/daily_quiz/
```

- [ ] **Step 2: Commit**

```bash
git add pubspec.yaml
git commit -m "feat(daily-quiz): register daily_quiz assets in pubspec"
```

---

### Task 12: Notifications — 6 AM quiz-ready + leaderboard

**Files:**
- Modify: `lib/services/notification_service.dart`

- [ ] **Step 1: Add Daily Quiz notification scheduling**

Add methods to `NotificationService`:

```dart
// Notification IDs for Daily Quiz
static const int _dailyQuizReadyId = 2000;
static const int _dailyQuizReminderId = 2001;
static const int _dailyQuizRankUpdateId = 2002;

/// Schedule the 6 AM quiz-ready notification.
Future<void> scheduleDailyQuizReadyNotification() async {
  final now = DateTime.now();
  final scheduledDate = DateTime(now.year, now.month, now.day, 6, 0);
  // If already past 6 AM, schedule for tomorrow
  final scheduleAt = scheduledDate.isAfter(now)
      ? scheduledDate
      : scheduledDate.add(const Duration(days: 1));

  final androidDetails = const AndroidNotificationDetails(
    'daily_quiz_channel',
    'Daily Quiz',
    channelDescription: 'Notifications for daily quiz',
    importance: Importance.high,
    priority: Priority.high,
  );

  await _plugin.zonedSchedule(
    _dailyQuizReadyId,
    '🌅 Daily Quiz Ready!',
    '10 new questions waiting for you — complete by midnight!',
    tz.TZDateTime.from(scheduleAt, tz.local),
    NotificationDetails(android: androidDetails),
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time,
  );
}

/// Schedule reminder if quiz not completed (8 PM weekdays, 6 PM weekends).
Future<void> scheduleDailyQuizReminder() async {
  final now = DateTime.now();
  final isWeekend = now.weekday >= 6;
  final hour = isWeekend ? 18 : 20;
  final scheduledDate = DateTime(now.year, now.month, now.day, hour, 0);
  
  if (scheduledDate.isBefore(now)) return; // Don't schedule in the past

  final androidDetails = const AndroidNotificationDetails(
    'daily_quiz_channel',
    'Daily Quiz',
    channelDescription: 'Notifications for daily quiz',
    importance: Importance.high,
    priority: Priority.high,
  );

  await _plugin.zonedSchedule(
    _dailyQuizReminderId,
    '⏰ Don\'t forget today\'s quiz!',
    'Your streak is at risk — complete the Daily Quiz!',
    tz.TZDateTime.from(scheduledDate, tz.local),
    NotificationDetails(android: androidDetails),
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time,
  );
}

/// Schedule rank update notification after quiz completion.
Future<void> showQuizRankNotification(int rank, String topPlayer, int topScore) async {
  final androidDetails = const AndroidNotificationDetails(
    'daily_quiz_channel',
    'Daily Quiz',
    channelDescription: 'Notifications for daily quiz',
    importance: Importance.high,
    priority: Priority.high,
  );

  await _plugin.show(
    _dailyQuizRankUpdateId,
    '🏆 Daily Quiz Result',
    rank <= 3
        ? 'You\'re #$rank today! $topPlayer leads with $topScore pts.'
        : 'You\'re #$rank today. Keep practicing to climb up!',
    NotificationDetails(android: androidDetails),
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/notification_service.dart
git commit -m "feat(daily-quiz): add daily quiz notifications (6 AM ready, reminder, rank update)"
```

---

## Verification Checklist

After all tasks complete, verify:

- [ ] App builds without errors: `flutter build apk --debug`
- [ ] Daily Quiz screen loads from home screen
- [ ] Quiz generates 10 questions (5 vocab + 5 grammar)
- [ ] Same date = same questions (deterministic)
- [ ] Per-question timer counts down from 30s
- [ ] Tapping answer records it, shows explanation, auto-advances
- [ ] Timeout auto-advances (counts wrong)
- [ ] Result screen shows correct score, time, stats
- [ ] XP and coins are awarded
- [ ] Streak updates after quiz completion
- [ ] Old Daily Quest is completely gone
- [ ] Leaderboard screen still works
- [ ] 6 AM notification scheduled
- [ ] pubspec assets include the quiz JSON
