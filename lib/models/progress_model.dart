import 'package:cloud_firestore/cloud_firestore.dart';

class ProgressModel {
  final String userId;
  final int lessonsCompleted;
  final int quizScore;
  final int speakingScore;
  final int studyTime; // in minutes
  final int streakDays;
  final int weeklyStreak;
  final int longestStreak;
  final int missedDays;
  final int totalActiveDays;
  final int totalCoins;
  final int totalXP;
  final int currentLevel;
  final DateTime lastActiveDate;
  final List<String> completedLessonIds;

  ProgressModel({
    required this.userId,
    this.lessonsCompleted = 0,
    this.quizScore = 0,
    this.speakingScore = 0,
    this.studyTime = 0,
    this.streakDays = 0,
    this.weeklyStreak = 0,
    this.longestStreak = 0,
    this.missedDays = 0,
    this.totalActiveDays = 0,
    this.totalCoins = 0,
    this.totalXP = 0,
    this.currentLevel = 1,
    required this.lastActiveDate,
    this.completedLessonIds = const [],
  });

  factory ProgressModel.fromMap(Map<String, dynamic> map, String userId) {
    return ProgressModel(
      userId: userId,
      lessonsCompleted: map['lessonsCompleted'] ?? 0,
      quizScore: map['quizScore'] ?? 0,
      speakingScore: map['speakingScore'] ?? 0,
      studyTime: map['studyTime'] ?? 0,
      streakDays: map['streakDays'] ?? 0,
      weeklyStreak: map['weeklyStreak'] ?? 0,
      longestStreak: map['longestStreak'] ?? 0,
      missedDays: map['missedDays'] ?? 0,
      totalActiveDays: map['totalActiveDays'] ?? 0,
      totalCoins: map['totalCoins'] ?? 0,
      totalXP: map['totalXP'] ?? 0,
      currentLevel: map['currentLevel'] ?? 1,
      lastActiveDate: (map['lastActiveDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedLessonIds: List<String>.from(map['completedLessonIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lessonsCompleted': lessonsCompleted,
      'quizScore': quizScore,
      'speakingScore': speakingScore,
      'studyTime': studyTime,
      'streakDays': streakDays,
      'weeklyStreak': weeklyStreak,
      'longestStreak': longestStreak,
      'missedDays': missedDays,
      'totalActiveDays': totalActiveDays,
      'totalCoins': totalCoins,
      'totalXP': totalXP,
      'currentLevel': currentLevel,
      'lastActiveDate': Timestamp.fromDate(lastActiveDate),
      'completedLessonIds': completedLessonIds,
    };
  }

  ProgressModel copyWith({
    String? userId,
    int? lessonsCompleted,
    int? quizScore,
    int? speakingScore,
    int? studyTime,
    int? streakDays,
    int? weeklyStreak,
    int? longestStreak,
    int? missedDays,
    int? totalActiveDays,
    int? totalCoins,
    int? totalXP,
    int? currentLevel,
    DateTime? lastActiveDate,
    List<String>? completedLessonIds,
  }) {
    return ProgressModel(
      userId: userId ?? this.userId,
      lessonsCompleted: lessonsCompleted ?? this.lessonsCompleted,
      quizScore: quizScore ?? this.quizScore,
      speakingScore: speakingScore ?? this.speakingScore,
      studyTime: studyTime ?? this.studyTime,
      streakDays: streakDays ?? this.streakDays,
      weeklyStreak: weeklyStreak ?? this.weeklyStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      missedDays: missedDays ?? this.missedDays,
      totalActiveDays: totalActiveDays ?? this.totalActiveDays,
      totalCoins: totalCoins ?? this.totalCoins,
      totalXP: totalXP ?? this.totalXP,
      currentLevel: currentLevel ?? this.currentLevel,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      completedLessonIds: completedLessonIds ?? this.completedLessonIds,
    );
  }
}
