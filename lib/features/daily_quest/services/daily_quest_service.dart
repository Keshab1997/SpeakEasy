import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/daily_quest_model.dart';
import '../models/daily_quest_task_model.dart';

// ── Hive Keys ──
const _questKey = 'current_quest';

/// Generates and persists daily quest tasks so that every user gets a
/// unique but deterministic set per day based on their weak areas and
/// the day of the year.
class DailyQuestService {
  DailyQuestService();

  // ── Task Templates ──
  //
  // We define 12 task types that the daily quest generator can pick from.
  // On a given day the user sees 4–5 tasks, each linked to an existing
  // game mode / learning screen in the app.

  static const _taskPool = [
    _TaskTemplate('grammar', 'Tense Quiz', 'Complete a tense-based quiz',
        'mode_game', '/game/mode', 25, 12, 8),
    _TaskTemplate('grammar', 'Grammar Detective',
        'Find & fix the grammar error', 'error_detection', null, 30, 15, 6),
    _TaskTemplate('vocabulary', 'Word Match',
        'Match English words with their Bangla meanings', 'word_match', null,
        20, 10, 10),
    _TaskTemplate('vocabulary', 'Flashcard Review',
        'Review your saved vocabulary flashcards', 'flashcard_review', null, 15,
        8, 5),
    _TaskTemplate('speaking', 'Pronunciation Drill',
        'Practice pronunciation of tricky words', 'pronunciation', null, 35, 18,
        5),
    _TaskTemplate('listening', 'Listening Exercise',
        'Listen and answer comprehension questions', 'listening', null, 30, 15,
        6),
    _TaskTemplate('translation', 'Banglish Translate',
        'Translate 5 Banglish sentences to English', 'translator', null, 25,
        12, 5),
    _TaskTemplate('grammar', 'Fill in the Blanks',
        'Fill in the correct word to complete the sentence', 'fill_blank', null,
        20, 10, 8),
    _TaskTemplate('vocabulary', 'Quick Quiz',
        'Test your vocabulary with a speed round', 'quick_quiz', null, 25, 12,
        8),
    _TaskTemplate('mixed', 'Sentence Builder',
        'Arrange words into correct English sentences', 'sentence_builder',
        null, 30, 15, 6),
    _TaskTemplate('mixed', 'Mixed Challenge',
        'A mix of everything — grammar, vocab, listening', 'mixed_challenge',
        null, 40, 20, 5),
    _TaskTemplate('conversation', 'Daily Chat',
        'Practice a real-life conversation scenario', 'conversation', null, 35,
        18, 5),
  ];

  /// Generate today's quest. Deterministic per date string so the
  /// same user sees the same tasks all day — no regenerating on hot reload.
  DailyQuest generateTodayQuest({int? seedOverride}) {
    final dateStr = _todayDateString();
    final rng = Random(seedOverride ?? _daySeed(dateStr));

    // Pick 5 tasks — seed-based but nudge toward weak areas.
    final weakArea = _guessWeakArea();
    final pool = List<_TaskTemplate>.from(_taskPool);
    pool.shuffle(rng);

    // Ensure at least 1 task from the weak area (if available)
    final prioritized = <_TaskTemplate>[];
    final rest = <_TaskTemplate>[];
    for (final t in pool) {
      if (weakArea != null && t.type == weakArea && prioritized.length < 2) {
        prioritized.add(t);
      } else {
        rest.add(t);
      }
    }
    final selected = [...prioritized, ...rest].take(5).toList();

    final tasks = selected.asMap().entries.map((e) {
      final idx = e.key;
      final tpl = e.value;
      return DailyQuestTaskModel(
        id: '${dateStr}_task_$idx',
        taskType: tpl.type,
        title: tpl.title,
        description: tpl.description,
        xpReward: tpl.xpReward,
        coinReward: tpl.coinReward,
        linkedScreen: tpl.screen,
        navigationData: tpl.type == 'grammar'
            ? {'mode': tpl.modeParam}
            : {'type': tpl.type},
      );
    }).toList();

    return DailyQuest(
      id: 'quest_$dateStr',
      date: dateStr,
      tasks: tasks,
      startedAt: DateTime.now(),
    );
  }

  /// Save quest locally using the daily_quest_cache Hive box.
  void saveQuest(DailyQuest quest) {
    final box = dailyQuestBox;
    box.put(_questKey, quest.toJson());
  }

  /// Load today's quest from local storage.
  /// Returns null if no saved quest or if it's from a previous day.
  DailyQuest? loadSavedQuest() {
    try {
      final box = dailyQuestBox;
      final data = box.get(_questKey);
      if (data == null) return null;
      final saved = DailyQuest.fromJson(data as Map<String, dynamic>);
      // Only return if it's today's quest
      if (saved.date != _todayDateString()) return null;
      return saved;
    } catch (_) {
      return null;
    }
  }

  /// Mark a single task as completed and return updated quest
  DailyQuest completeTask(DailyQuest quest, String taskId) {
    final updatedTasks = quest.tasks.map((t) {
      if (t.id == taskId && !t.isCompleted) {
        return t.copyWith(isCompleted: true);
      }
      return t;
    }).toList();

    final newlyCompleted =
        quest.tasks.where((t) => t.id == taskId && !t.isCompleted).isNotEmpty;

    int earnedXP = quest.earnedXP;
    int earnedCoins = quest.earnedCoins;
    if (newlyCompleted) {
      final task = quest.tasks.firstWhere((t) => t.id == taskId);
      earnedXP += task.xpReward;
      earnedCoins += task.coinReward;
    }

    final allDone = updatedTasks.every((t) => t.isCompleted);
    final now = DateTime.now();

    return quest.copyWith(
      tasks: updatedTasks,
      earnedXP: earnedXP,
      earnedCoins: earnedCoins,
      isCompleted: allDone,
      completedAt: allDone ? now : null,
    );
  }

  /// Claim the completion bonus (called once when all tasks done & bonus not claimed)
  DailyQuest claimBonus(DailyQuest quest) {
    if (!quest.isCompleted || quest.bonusClaimed) return quest;
    return quest.copyWith(
      bonusClaimed: true,
      earnedXP: quest.earnedXP + quest.completionBonusXP,
      earnedCoins: quest.earnedCoins + quest.completionBonusCoins,
    );
  }

  /// Create a summary string suitable for notifications
  String questSummary(DailyQuest quest) {
    final done = quest.completedTasks;
    final total = quest.totalTasks;
    return 'Daily Quest: $done/$total tasks done! '
        'Earned ${quest.earnedXP} XP & ${quest.earnedCoins} coins.';
  }

  // ─── Helpers ───

  static int _daySeed(String dateStr) {
    return dateStr.replaceAll('-', '').hashCode;
  }

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Returns the daily_quest_cache Hive box.
  /// This box is opened during HiveService.initialize().
  static Box get dailyQuestBox {
    return Hive.box('daily_quest_cache');
  }

  /// Try to detect the user's weakest area from statistics (sync version).
  /// Returns null if not enough data.
  String? _guessWeakArea() {
    try {
      final box = _statsBox;
      final results = box.get('game_results', defaultValue: <Map<String, dynamic>>[]) as List;
      if (results.isEmpty) return null;

      // Simple heuristic: if overall accuracy < 60%, target grammar
      int correct = 0;
      int total = 0;
      for (final r in results) {
        final c = (r as Map)['correctAnswers'] as int? ?? 0;
        final w = r['wrongAnswers'] as int? ?? 0;
        correct += c;
        total += c + w;
      }
      if (total == 0) return null;
      final accuracy = correct / total;
      if (accuracy < 0.6) return 'grammar';
      return null;
    } catch (_) {
      return null;
    }
  }

  static Box get _statsBox {
    return Hive.box('game_statistics');
  }
}

/// A reusable template for a quest task.
class _TaskTemplate {
  final String type;
  final String title;
  final String description;
  final String screen;
  final String? modeParam;
  final int xpReward;
  final int coinReward;
  final int weight;

  const _TaskTemplate(
    this.type,
    this.title,
    this.description,
    this.screen,
    this.modeParam,
    this.xpReward,
    this.coinReward,
    this.weight,
  );
}
