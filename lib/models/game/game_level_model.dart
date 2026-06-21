import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'game_level_model.g.dart';

@HiveType(typeId: 1)
class GameLevelModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String levelName;

  @HiveField(2)
  final bool unlocked;

  @HiveField(3)
  final bool completed;

  @HiveField(4)
  final double progress;

  @HiveField(5)
  final int totalStars;

  GameLevelModel({
    required this.id,
    required this.levelName,
    this.unlocked = false,
    this.completed = false,
    this.progress = 0.0,
    this.totalStars = 0,
  });

  factory GameLevelModel.fromMap(Map<String, dynamic> map, String docId) {
    return GameLevelModel(
      id: docId,
      levelName: map['levelName'] as String? ?? '',
      unlocked: map['unlocked'] as bool? ?? false,
      completed: map['completed'] as bool? ?? false,
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      totalStars: map['totalStars'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'levelName': levelName,
      'unlocked': unlocked,
      'completed': completed,
      'progress': progress,
      'totalStars': totalStars,
    };
  }

  GameLevelModel copyWith({
    String? id,
    String? levelName,
    bool? unlocked,
    bool? completed,
    double? progress,
    int? totalStars,
  }) {
    return GameLevelModel(
      id: id ?? this.id,
      levelName: levelName ?? this.levelName,
      unlocked: unlocked ?? this.unlocked,
      completed: completed ?? this.completed,
      progress: progress ?? this.progress,
      totalStars: totalStars ?? this.totalStars,
    );
  }

  @override
  String toString() {
    return 'GameLevelModel(id: $id, levelName: $levelName, unlocked: $unlocked, completed: $completed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameLevelModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}