import 'package:hive/hive.dart';

part 'level_model.g.dart';

@HiveType(typeId: 5)
class LevelModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final int order;

  @HiveField(4)
  final bool unlocked;

  @HiveField(5)
  final bool completed;

  @HiveField(6)
  final int totalStars;

  @HiveField(7)
  final int requiredXP;

  @HiveField(8)
  final List<TenseCategory> categories;

  LevelModel({
    required this.id,
    required this.name,
    required this.description,
    required this.order,
    this.unlocked = false,
    this.completed = false,
    this.totalStars = 0,
    this.requiredXP = 0,
    this.categories = const [],
  });

  factory LevelModel.fromMap(Map<String, dynamic> map, String docId) {
    return LevelModel(
      id: docId,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      order: map['order'] as int? ?? 0,
      unlocked: map['unlocked'] as bool? ?? false,
      completed: map['completed'] as bool? ?? false,
      totalStars: map['totalStars'] as int? ?? 0,
      requiredXP: map['requiredXP'] as int? ?? 0,
      categories: (map['categories'] as List<dynamic>? ?? [])
          .map((c) => TenseCategory.fromMap(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'order': order,
      'unlocked': unlocked,
      'completed': completed,
      'totalStars': totalStars,
      'requiredXP': requiredXP,
      'categories': categories.map((c) => c.toMap()).toList(),
    };
  }

  LevelModel copyWith({
    String? id,
    String? name,
    String? description,
    int? order,
    bool? unlocked,
    bool? completed,
    int? totalStars,
    int? requiredXP,
    List<TenseCategory>? categories,
  }) {
    return LevelModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      order: order ?? this.order,
      unlocked: unlocked ?? this.unlocked,
      completed: completed ?? this.completed,
      totalStars: totalStars ?? this.totalStars,
      requiredXP: requiredXP ?? this.requiredXP,
      categories: categories ?? this.categories,
    );
  }

  @override
  String toString() {
    return 'LevelModel(id: $id, name: $name, order: $order, unlocked: $unlocked)';
  }
}

@HiveType(typeId: 6)
class TenseCategory {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final int questionCount;

  @HiveField(4)
  final bool unlocked;

  @HiveField(5)
  final bool completed;

  @HiveField(6)
  final int stars;

  TenseCategory({
    required this.id,
    required this.name,
    required this.description,
    this.questionCount = 0,
    this.unlocked = false,
    this.completed = false,
    this.stars = 0,
  });

  factory TenseCategory.fromMap(Map<String, dynamic> map) {
    return TenseCategory(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      questionCount: map['questionCount'] as int? ?? 0,
      unlocked: map['unlocked'] as bool? ?? false,
      completed: map['completed'] as bool? ?? false,
      stars: map['stars'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'questionCount': questionCount,
      'unlocked': unlocked,
      'completed': completed,
      'stars': stars,
    };
  }

  TenseCategory copyWith({
    String? id,
    String? name,
    String? description,
    int? questionCount,
    bool? unlocked,
    bool? completed,
    int? stars,
  }) {
    return TenseCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      questionCount: questionCount ?? this.questionCount,
      unlocked: unlocked ?? this.unlocked,
      completed: completed ?? this.completed,
      stars: stars ?? this.stars,
    );
  }
}