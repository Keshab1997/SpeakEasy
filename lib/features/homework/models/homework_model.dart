class HomeworkQuestion {
  final String banglaSentence;
  String? userTranslation;
  String? correctTranslation;
  bool? isCorrect;
  String? feedback;

  HomeworkQuestion({
    required this.banglaSentence,
    this.userTranslation,
    this.correctTranslation,
    this.isCorrect,
    this.feedback,
  });
}

enum HomeworkStep { topic, generating, translating, reviewing, completed }
