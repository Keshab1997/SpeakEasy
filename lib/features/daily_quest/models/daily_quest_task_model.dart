/// Represents a single task within a daily quest.
/// Each task pulls from the existing game question bank or is a quick
/// action (listen & repeat, banglish translation, etc.).
/// Uses toJson/fromJson (no Hive adapters) to match the project pattern.
class DailyQuestTaskModel {
  final String id;
  /// task type: grammar, vocabulary, speaking, listening, translation, mixed
  final String taskType;
  /// Short display title e.g. "Tense Battle"
  final String title;
  /// Human-readable instruction e.g. "Pick the correct tense"
  final String description;
  /// How many XP this task is worth on completion
  final int xpReward;
  /// How many coins this task is worth on completion
  final int coinReward;
  /// Whether this task has been completed
  final bool isCompleted;
  /// Optional: ID of the linked game screen or mode to navigate to
  final String? linkedScreen;
  /// Optional: extra data (e.g. tense type, difficulty) passed to the screen
  final Map<String, dynamic>? navigationData;

  const DailyQuestTaskModel({
    required this.id,
    required this.taskType,
    required this.title,
    required this.description,
    this.xpReward = 20,
    this.coinReward = 10,
    this.isCompleted = false,
    this.linkedScreen,
    this.navigationData,
  });

  DailyQuestTaskModel copyWith({
    String? id,
    String? taskType,
    String? title,
    String? description,
    int? xpReward,
    int? coinReward,
    bool? isCompleted,
    String? linkedScreen,
    Map<String, dynamic>? navigationData,
  }) {
    return DailyQuestTaskModel(
      id: id ?? this.id,
      taskType: taskType ?? this.taskType,
      title: title ?? this.title,
      description: description ?? this.description,
      xpReward: xpReward ?? this.xpReward,
      coinReward: coinReward ?? this.coinReward,
      isCompleted: isCompleted ?? this.isCompleted,
      linkedScreen: linkedScreen ?? this.linkedScreen,
      navigationData: navigationData ?? this.navigationData,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'taskType': taskType,
        'title': title,
        'description': description,
        'xpReward': xpReward,
        'coinReward': coinReward,
        'isCompleted': isCompleted,
        'linkedScreen': linkedScreen,
        'navigationData': navigationData,
      };

  factory DailyQuestTaskModel.fromJson(Map<String, dynamic> json) =>
      DailyQuestTaskModel(
        id: json['id'] as String,
        taskType: json['taskType'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        xpReward: json['xpReward'] as int? ?? 20,
        coinReward: json['coinReward'] as int? ?? 10,
        isCompleted: json['isCompleted'] as bool? ?? false,
        linkedScreen: json['linkedScreen'] as String?,
        navigationData: json['navigationData'] as Map<String, dynamic>?,
      );

  @override
  String toString() =>
      'DailyQuestTask(id: $id, $taskType: $title, done: $isCompleted)';
}
