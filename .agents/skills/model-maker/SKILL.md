---
name: model-maker
description: "Specialized for creating Dart model classes in this project — with manual fromMap/toMap (Firestore), Hive @HiveType annotations, copyWith, ==/hashCode, and toString."
tools: [Read, Write, Edit]
---

# Model Maker

Your purpose: Create Dart data model files that match this project's exact patterns. Pure data classes only — no logic, no providers, no widgets.

## File Location
- Plain models: `lib/models/<model_name>_model.dart`
- Feature-specific models: `lib/models/<feature>/<model_name>_model.dart`
- Hive models: same locations, with `.g.dart` part file

## Pattern A: Plain Firestore Model (No Hive)

Most common pattern. Used for data that only lives in Firestore.

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final DateTime joinedAt;
  final String? photoUrl;     // nullable optional fields use String?
  final int streak;            // numeric fields with defaults
  final String currentLevel;   // enum-like strings

  // Constructor: required for essential, named with defaults for optional
  // Use positional 'id' param, named optional params with defaults
  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.joinedAt,
    this.streak = 0,
    this.currentLevel = 'Beginner',
  });

  // Factory: fromMap takes Map<String, dynamic> + docId
  // Use map['field'] ?? defaultValue pattern
  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      id: docId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] as String?,
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      streak: map['streak'] ?? 0,
      currentLevel: map['currentLevel'] ?? 'Beginner',
    );
  }

  // toMap: NO 'id' in the map (Firestore doc ID is separate)
  // For Timestamp fields: use Timestamp.fromDate()
  // Null-safe: wrap nullable fields with if (value != null)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'streak': streak,
      'currentLevel': currentLevel,
    };
  }

  // copyWith: every field as optional named param
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? photoUrl,
    DateTime? joinedAt,
    int? streak,
    String? currentLevel,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      joinedAt: joinedAt ?? this.joinedAt,
      streak: streak ?? this.streak,
      currentLevel: currentLevel ?? this.currentLevel,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UserModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'UserModel(id: $id, name: $name, email: $email, level: $currentLevel)';
}
```

## Pattern B: Firestore Model with Separate toFirestoreMap

Use when Timestamps need different handling for Hive vs Firestore.

```dart
// toMap() → uses ISO string dates (for Hive storage)
Map<String, dynamic> toMap() {
  return {
    'lastActiveDate': lastActiveDate.toIso8601String(),
    'currentLevel': currentLevel,
  };
}

// toFirestoreMap() → uses Timestamp (for Firestore)
Map<String, dynamic> toFirestoreMap() {
  return {
    'lastActiveDate': Timestamp.fromDate(lastActiveDate),
    'currentLevel': currentLevel,
  };
}
```

## Pattern C: Hive Model (+ Firestore)

For models that are stored both locally (Hive) and in Firestore. Run `build_runner` AFTER creating the file.

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'game_progress_model.g.dart';  // ← MUST match filename

@HiveType(typeId: 3)  // ← UNIQUE integer per Hive model
class GameProgressModel {
  @HiveField(0)       // ← sequential from 0
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

  @HiveField(11)
  final Map<String, bool> weeklyActivity;

  @HiveField(12)
  final String? weeklyActivityWeekStart;

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
    this.weeklyActivity = const {},
    this.weeklyActivityWeekStart,
  }) : lastActiveDate = lastActiveDate ?? DateTime.now();

  // fromMap: explicit casts like as int? ?? 0, List<String>.from(...)
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
      weeklyActivity: map['weeklyActivity'] != null
          ? Map<String, bool>.from(
              (map['weeklyActivity'] as Map).map((k, v) => MapEntry(k.toString(), v == true)))
          : {},
      weeklyActivityWeekStart: map['weeklyActivityWeekStart'] as String?,
    );
  }

  // Helper for flexible date parsing
  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  // Same copyWith, ==, hashCode, toString as Pattern A
  // + toMap() with ISO dates, toFirestoreMap() with Timestamps
}

// After creating this file, run:
// flutter pub run build_runner build --delete-conflicting-outputs
```

## Pattern Summary

| Element | Convention |
|---------|-----------|
| Constructor | `required this.field` for essentials, `this.field = default` for optionals |
| fromMap | `factory Model.fromMap(Map<String, dynamic> map, String docId)` — `map['field'] ?? default` |
| toMap | Returns `Map<String, dynamic>` — NO `id` field (it's the doc ID) |
| toFirestoreMap | Same as toMap but with `Timestamp.fromDate()` instead of ISO strings |
| Nullable fields | `as String?` in fromMap, `if (val != null)` guard in toMap |
| copyWith | All fields optional, `field ?? this.field` pattern |
| == | `identical(this, other) || other is ClassName && other.id == id` |
| hashCode | `id.hashCode` only (single identity field) |
| toString | Class summary with key identifying fields |

## Rules
- DO use `const` constructor whenever all fields are final
- DO put `id` as the first field (it's the document ID from Firestore)
- DO use `@HiveField(N)` sequentially from 0
- DO use `as int? ?? default` pattern for explicit type casting in fromMap
- DON'T include `id` in `toMap()` output (Firestore doc ID is separate from data)
- DON'T add business logic or validation — models are pure data containers
- DON'T use freezed or json_serializable (this project uses manual serialization)
