/// All Daily Quiz questions are standard multiple-choice questions (MCQ).
/// The earlier experimental types (fill_blanks, match_pairs,
/// sentence_rearrange) were removed — keep the bank MCQ-only.

class DailyQuizQuestion {
  final String id;
  final String type;
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

  factory DailyQuizQuestion.fromJson(Map<String, dynamic> json) =>
      DailyQuizQuestion(
        id: json['id'] as String,
        type: json['type'] as String,
        question: json['question'] as String,
        options: List<String>.from(json['options'] as List),
        correctAnswer: json['correctAnswer'] as int,
        explanation: json['explanation'] as String,
        timeLimit: (json['timeLimit'] as int?) ?? 30,
        difficulty: (json['difficulty'] as String?) ?? 'medium',
        category: (json['category'] as String?) ?? 'general',
      );
}

class DailyQuizAnswer {
  final String questionId;
  final int? selectedAnswer;
  final bool isCorrect;
  final int timeTaken;
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

  factory DailyQuizAnswer.fromJson(Map<String, dynamic> json) =>
      DailyQuizAnswer(
        questionId: json['questionId'] as String,
        selectedAnswer: json['selectedAnswer'] as int?,
        isCorrect: json['isCorrect'] as bool,
        timeTaken: json['timeTaken'] as int,
        pointsEarned: (json['pointsEarned'] as int?) ?? 0,
      );
}

class DailyQuiz {
  final String id;
  final String date;
  final String? userId;
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
    this.userId,
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
    String? userId,
    List<DailyQuizQuestion>? questions,
    List<DailyQuizAnswer>? answers,
    bool? isCompleted,
    int? earnedXP,
    int? earnedCoins,
    DateTime? startedAt,
    DateTime? completedAt,
    int? seed,
  }) =>
      DailyQuiz(
        id: id ?? this.id,
        date: date ?? this.date,
        userId: userId ?? this.userId,
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
        'userId': userId,
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
        userId: json['userId'] as String?,
        date: json['date'] as String,
        questions: (json['questions'] as List<dynamic>?)
                ?.map((q) =>
                    DailyQuizQuestion.fromJson(Map<String, dynamic>.from(q)))
                .toList() ??
            [],
        answers: (json['answers'] as List<dynamic>?)
                ?.map((a) =>
                    DailyQuizAnswer.fromJson(Map<String, dynamic>.from(a)))
                .toList() ??
            [],
        isCompleted: (json['isCompleted'] as bool?) ?? false,
        earnedXP: (json['earnedXP'] as int?) ?? 0,
        earnedCoins: (json['earnedCoins'] as int?) ?? 0,
        startedAt: json['startedAt'] != null
            ? DateTime.parse(json['startedAt'] as String)
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
        seed: json['seed'] as int,
      );
}

/// Lightweight summary of one completed Daily Quiz, stored per-user in Hive
/// so learners can browse their past results.
class DailyQuizHistoryEntry {
  final String date; // YYYY-MM-DD
  final int score;
  final int correctCount;
  final int totalQuestions;
  final int totalTime;
  final int earnedXP;
  final int earnedCoins;

  const DailyQuizHistoryEntry({
    required this.date,
    required this.score,
    required this.correctCount,
    required this.totalQuestions,
    required this.totalTime,
    this.earnedXP = 0,
    this.earnedCoins = 0,
  });

  /// Percentage of questions answered correctly (0-100).
  int get accuracy =>
      totalQuestions == 0 ? 0 : (correctCount * 100 ~/ totalQuestions);

  Map<String, dynamic> toJson() => {
        'date': date,
        'score': score,
        'correctCount': correctCount,
        'totalQuestions': totalQuestions,
        'totalTime': totalTime,
        'earnedXP': earnedXP,
        'earnedCoins': earnedCoins,
      };

  factory DailyQuizHistoryEntry.fromJson(Map<String, dynamic> json) =>
      DailyQuizHistoryEntry(
        date: json['date'] as String,
        score: (json['score'] as int?) ?? 0,
        correctCount: (json['correctCount'] as int?) ?? 0,
        totalQuestions: (json['totalQuestions'] as int?) ?? 0,
        totalTime: (json['totalTime'] as int?) ?? 0,
        earnedXP: (json['earnedXP'] as int?) ?? 0,
        earnedCoins: (json['earnedCoins'] as int?) ?? 0,
      );
}
