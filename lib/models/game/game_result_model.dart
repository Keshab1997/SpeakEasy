import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'game_result_model.g.dart';

@HiveType(typeId: 2)
class GameResultModel {
  @HiveField(0)
  final int score;

  @HiveField(1)
  final int correctAnswers;

  @HiveField(2)
  final int wrongAnswers;

  @HiveField(3)
  final double accuracy;

  @HiveField(4)
  final int earnedXP;

  @HiveField(5)
  final int earnedCoins;

  @HiveField(6)
  final DateTime completedTime;

  GameResultModel({
    this.score = 0,
    this.correctAnswers = 0,
    this.wrongAnswers = 0,
    this.accuracy = 0.0,
    this.earnedXP = 0,
    this.earnedCoins = 0,
    DateTime? completedTime,
  }) : completedTime = completedTime ?? DateTime.now();

  factory GameResultModel.fromMap(Map<String, dynamic> map) {
    return GameResultModel(
      score: map['score'] as int? ?? 0,
      correctAnswers: map['correctAnswers'] as int? ?? 0,
      wrongAnswers: map['wrongAnswers'] as int? ?? 0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      earnedXP: map['earnedXP'] as int? ?? 0,
      earnedCoins: map['earnedCoins'] as int? ?? 0,
      completedTime: (map['completedTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'score': score,
      'correctAnswers': correctAnswers,
      'wrongAnswers': wrongAnswers,
      'accuracy': accuracy,
      'earnedXP': earnedXP,
      'earnedCoins': earnedCoins,
      'completedTime': Timestamp.fromDate(completedTime),
    };
  }

  GameResultModel copyWith({
    int? score,
    int? correctAnswers,
    int? wrongAnswers,
    double? accuracy,
    int? earnedXP,
    int? earnedCoins,
    DateTime? completedTime,
  }) {
    return GameResultModel(
      score: score ?? this.score,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      wrongAnswers: wrongAnswers ?? this.wrongAnswers,
      accuracy: accuracy ?? this.accuracy,
      earnedXP: earnedXP ?? this.earnedXP,
      earnedCoins: earnedCoins ?? this.earnedCoins,
      completedTime: completedTime ?? this.completedTime,
    );
  }

  @override
  String toString() {
    return 'GameResultModel(score: $score, correct: $correctAnswers, wrong: $wrongAnswers, accuracy: ${accuracy.toStringAsFixed(2)})';
  }
}