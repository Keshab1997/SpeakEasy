import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'game_progress_model.g.dart';

@HiveType(typeId: 3)
class GameProgressModel {
  @HiveField(0)
  final String userId;

  @HiveField(1)
  final int currentLevel;

  @HiveField(2)
  final int currentXP;

  @HiveField(3)
  final int totalCoins;

  @HiveField(4)
  final int streak;

  @HiveField(5)
  final List<String> unlockedModes;

  @HiveField(6)
  final int weeklyStreak;

  @HiveField(7)
  final int longestStreak;

  @HiveField(8)
  final int missedDays;

  @HiveField(9)
  final int totalActiveDays;

  @HiveField(10)
  final DateTime lastActiveDate;

  GameProgressModel({
    required this.userId,
    this.currentLevel = 1,
    this.currentXP = 0,
    this.totalCoins = 0,
    this.streak = 0,
    this.unlockedModes = const [],
    this.weeklyStreak = 0,
    this.longestStreak = 0,
    this.missedDays = 0,
    this.totalActiveDays = 0,
    DateTime? lastActiveDate,
  }) : lastActiveDate = lastActiveDate ?? DateTime.now();

  factory GameProgressModel.fromMap(Map<String, dynamic> map, String userId) {
    return GameProgressModel(
      userId: userId,
      currentLevel: map['currentLevel'] as int? ?? 1,
      currentXP: map['currentXP'] as int? ?? 0,
      totalCoins: map['totalCoins'] as int? ?? 0,
      streak: map['streak'] as int? ?? 0,
      unlockedModes: List<String>.from(map['unlockedModes'] as List? ?? []),
      weeklyStreak: map['weeklyStreak'] as int? ?? 0,
      longestStreak: map['longestStreak'] as int? ?? 0,
      missedDays: map['missedDays'] as int? ?? 0,
      totalActiveDays: map['totalActiveDays'] as int? ?? 0,
      lastActiveDate: _parseDate(map['lastActiveDate']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'currentLevel': currentLevel,
      'currentXP': currentXP,
      'totalCoins': totalCoins,
      'streak': streak,
      'unlockedModes': unlockedModes,
      'weeklyStreak': weeklyStreak,
      'longestStreak': longestStreak,
      'missedDays': missedDays,
      'totalActiveDays': totalActiveDays,
      'lastActiveDate': lastActiveDate.toIso8601String(), // Use ISO string for Hive
    };
  }
  
  /// Convert to Firestore map (with Timestamp)
  Map<String, dynamic> toFirestoreMap() {
    return {
      'currentLevel': currentLevel,
      'currentXP': currentXP,
      'totalCoins': totalCoins,
      'streak': streak,
      'unlockedModes': unlockedModes,
      'weeklyStreak': weeklyStreak,
      'longestStreak': longestStreak,
      'missedDays': missedDays,
      'totalActiveDays': totalActiveDays,
      'lastActiveDate': Timestamp.fromDate(lastActiveDate), // Firestore Timestamp
    };
  }

  GameProgressModel copyWith({
    String? userId,
    int? currentLevel,
    int? currentXP,
    int? totalCoins,
    int? streak,
    List<String>? unlockedModes,
    int? weeklyStreak,
    int? longestStreak,
    int? missedDays,
    int? totalActiveDays,
    DateTime? lastActiveDate,
  }) {
    return GameProgressModel(
      userId: userId ?? this.userId,
      currentLevel: currentLevel ?? this.currentLevel,
      currentXP: currentXP ?? this.currentXP,
      totalCoins: totalCoins ?? this.totalCoins,
      streak: streak ?? this.streak,
      unlockedModes: unlockedModes ?? this.unlockedModes,
      weeklyStreak: weeklyStreak ?? this.weeklyStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      missedDays: missedDays ?? this.missedDays,
      totalActiveDays: totalActiveDays ?? this.totalActiveDays,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
    );
  }

  @override
  String toString() {
    return 'GameProgressModel(userId: $userId, level: $currentLevel, xp: $currentXP, coins: $totalCoins, streak: $streak, weekly: $weeklyStreak, longest: $longestStreak, missed: $missedDays)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameProgressModel && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;
}
