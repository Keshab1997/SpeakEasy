class SentenceAnalysis {
  final String banglaSentence;
  final String tense;
  final String subject;
  final String object;
  final String wordBreakdown;
  final String englishTranslation;
  final String explanation;

  SentenceAnalysis({
    required this.banglaSentence,
    required this.tense,
    required this.subject,
    required this.object,
    required this.wordBreakdown,
    required this.englishTranslation,
    required this.explanation,
  });

  factory SentenceAnalysis.fromJson(Map<String, dynamic> json) {
    return SentenceAnalysis(
      banglaSentence: json['banglaSentence'] as String? ?? '',
      tense: json['tense'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      object: json['object'] as String? ?? '',
      wordBreakdown: json['wordBreakdown'] as String? ?? '',
      englishTranslation: json['englishTranslation'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
    );
  }
}

class PracticeTask {
  final String instruction;
  final String correctAnswer;

  PracticeTask({
    required this.instruction,
    required this.correctAnswer,
  });

  factory PracticeTask.fromJson(Map<String, dynamic> json) {
    return PracticeTask(
      instruction: json['instruction'] as String? ?? '',
      correctAnswer: json['correctAnswer'] as String? ?? '',
    );
  }
}

class AnswerReview {
  final bool isCorrect;
  final String feedback;

  AnswerReview({
    required this.isCorrect,
    required this.feedback,
  });

  factory AnswerReview.fromJson(Map<String, dynamic> json) {
    return AnswerReview(
      isCorrect: json['isCorrect'] as bool? ?? false,
      feedback: json['feedback'] as String? ?? '',
    );
  }
}

enum AnalyzerStep { topic, analyzing, explanation, generatingTask, practicing, reviewing, completed }
