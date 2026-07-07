import 'daily_quest_task_model.dart';

/// Represents a full day's quest — a collection of tasks for the user
/// to complete, with tracking for progress and streak registration.
class DailyQuest {
  final String id;

  /// YYYY-MM-DD format date for this quest
  final String date;

  /// Tasks in this quest
  final List<DailyQuestTaskModel> tasks;

  /// Whether the user has completed ALL tasks today
  final bool isCompleted;

  /// Did the user already claim the bonus?
  final bool bonusClaimed;

  /// Total XP earned from this quest so far
  final int earnedXP;

  /// Total coins earned from this quest so far
  final int earnedCoins;

  /// Timestamp when user first opened the quest today
  final DateTime? startedAt;

  /// Timestamp when the quest was fully completed
  final DateTime? completedAt;

  const DailyQuest({
    required this.id,
    required this.date,
    this.tasks = const [],
    this.isCompleted = false,
    this.bonusClaimed = false,
    this.earnedXP = 0,
    this.earnedCoins = 0,
    this.startedAt,
    this.completedAt,
  });

  int get totalTasks => tasks.length;
  int get completedTasks => tasks.where((t) => t.isCompleted).length;
  double get progress =>
      totalTasks > 0 ? completedTasks / totalTasks : 0.0;
  int get remainingTasks => totalTasks - completedTasks;
  String get progressLabel => '$completedTasks / $totalTasks';

  /// Bonus XP for completing all tasks
  int get completionBonusXP => totalTasks * 15;

  /// Bonus coins for completing all tasks
  int get completionBonusCoins => totalTasks * 5;

  DailyQuest copyWith({
    String? id,
    String? date,
    List<DailyQuestTaskModel>? tasks,
    bool? isCompleted,
    bool? bonusClaimed,
    int? earnedXP,
    int? earnedCoins,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return DailyQuest(
      id: id ?? this.id,
      date: date ?? this.date,
      tasks: tasks ?? this.tasks,
      isCompleted: isCompleted ?? this.isCompleted,
      bonusClaimed: bonusClaimed ?? this.bonusClaimed,
      earnedXP: earnedXP ?? this.earnedXP,
      earnedCoins: earnedCoins ?? this.earnedCoins,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'isCompleted': isCompleted,
        'bonusClaimed': bonusClaimed,
        'earnedXP': earnedXP,
        'earnedCoins': earnedCoins,
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory DailyQuest.fromJson(Map<String, dynamic> json) => DailyQuest(
        id: json['id'] as String,
        date: json['date'] as String,
        tasks: (json['tasks'] as List<dynamic>?)
                ?.map((t) =>
                    DailyQuestTaskModel.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
        isCompleted: json['isCompleted'] as bool? ?? false,
        bonusClaimed: json['bonusClaimed'] as bool? ?? false,
        earnedXP: json['earnedXP'] as int? ?? 0,
        earnedCoins: json['earnedCoins'] as int? ?? 0,
        startedAt: json['startedAt'] != null
            ? DateTime.parse(json['startedAt'] as String)
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
      );

  @override
  String toString() =>
      'DailyQuest(date: $date, $progressLabel tasks, done: $isCompleted)';
}
