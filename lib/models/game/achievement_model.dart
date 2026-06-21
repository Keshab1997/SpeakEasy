import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'achievement_model.g.dart';

@HiveType(typeId: 4)
class AchievementModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final bool unlocked;

  @HiveField(4)
  final DateTime? unlockDate;

  @HiveField(5)
  final String icon; // emoji badge

  @HiveField(6)
  final String category;

  @HiveField(7)
  final int xpReward;

  @HiveField(8)
  final int coinReward;

  AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    this.unlocked = false,
    this.unlockDate,
    this.icon = '🏅',
    this.category = 'General',
    this.xpReward = 0,
    this.coinReward = 0,
  });

  factory AchievementModel.fromMap(Map<String, dynamic> map, String docId) {
    return AchievementModel(
      id: docId.isEmpty ? (map['id'] as String? ?? '') : docId,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      unlocked: map['unlocked'] as bool? ?? false,
      unlockDate: _parseDate(map['unlockDate']),
      icon: map['icon'] as String? ?? '🏅',
      category: map['category'] as String? ?? 'General',
      xpReward: map['xpReward'] as int? ?? 0,
      coinReward: map['coinReward'] as int? ?? 0,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'unlocked': unlocked,
      'unlockDate': unlockDate != null ? Timestamp.fromDate(unlockDate!) : null,
      'icon': icon,
      'category': category,
      'xpReward': xpReward,
      'coinReward': coinReward,
    };
  }

  AchievementModel copyWith({
    String? id,
    String? title,
    String? description,
    bool? unlocked,
    DateTime? unlockDate,
    String? icon,
    String? category,
    int? xpReward,
    int? coinReward,
  }) {
    return AchievementModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      unlocked: unlocked ?? this.unlocked,
      unlockDate: unlockDate ?? this.unlockDate,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      xpReward: xpReward ?? this.xpReward,
      coinReward: coinReward ?? this.coinReward,
    );
  }

  @override
  String toString() {
    return 'AchievementModel(id: $id, title: $title, unlocked: $unlocked)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AchievementModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
