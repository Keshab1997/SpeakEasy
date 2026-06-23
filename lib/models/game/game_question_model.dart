import 'package:hive/hive.dart';

part 'game_question_model.g.dart';

@HiveType(typeId: 0)
class GameQuestionModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String tenseType;

  @HiveField(2)
  final String question;

  @HiveField(3)
  final List<String> options;

  @HiveField(4)
  final String correctAnswer;

  @HiveField(5)
  final String explanation;

  @HiveField(6)
  final String difficulty;

  @HiveField(7)
  final String mode;

  @HiveField(8)
  final int xpReward;

  @HiveField(9)
  final int coinReward;

  @HiveField(10)
  final List<String> optionBangla;

  GameQuestionModel({
    required this.id,
    required this.tenseType,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.difficulty,
    required this.mode,
    this.xpReward = 10,
    this.coinReward = 5,
    this.optionBangla = const [],
  });

  factory GameQuestionModel.fromMap(Map<String, dynamic> map, String docId) {
    return GameQuestionModel(
      id: docId,
      tenseType: map['tenseType'] as String? ?? '',
      question: map['question'] as String? ?? '',
      options: List<String>.from(map['options'] as List? ?? []),
      correctAnswer: map['correctAnswer'] as String? ?? '',
      explanation: map['explanation'] as String? ?? '',
      difficulty: map['difficulty'] as String? ?? 'beginner',
      mode: map['mode'] as String? ?? 'practice',
      xpReward: map['xpReward'] as int? ?? 10,
      coinReward: map['coinReward'] as int? ?? 5,
      optionBangla: List<String>.from(map['optionBangla'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tenseType': tenseType,
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'difficulty': difficulty,
      'mode': mode,
      'xpReward': xpReward,
      'coinReward': coinReward,
      'optionBangla': optionBangla,
    };
  }

  GameQuestionModel copyWith({
    String? id,
    String? tenseType,
    String? question,
    List<String>? options,
    String? correctAnswer,
    String? explanation,
    String? difficulty,
    String? mode,
    int? xpReward,
    int? coinReward,
    List<String>? optionBangla,
  }) {
    return GameQuestionModel(
      id: id ?? this.id,
      tenseType: tenseType ?? this.tenseType,
      question: question ?? this.question,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation ?? this.explanation,
      difficulty: difficulty ?? this.difficulty,
      mode: mode ?? this.mode,
      xpReward: xpReward ?? this.xpReward,
      coinReward: coinReward ?? this.coinReward,
      optionBangla: optionBangla ?? this.optionBangla,
    );
  }

  @override
  String toString() {
    return 'GameQuestionModel(id: $id, tenseType: $tenseType, difficulty: $difficulty, mode: $mode)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameQuestionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}