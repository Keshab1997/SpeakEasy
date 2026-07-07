import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/game/streak_provider.dart';
import '../../../providers/game/xp_provider.dart';
import '../../../providers/game/coin_provider.dart';
import '../../daily_quest/services/daily_quest_service.dart';
import '../models/daily_quest_model.dart';

/// Simple tracker that connects Daily Quest navigation to game completion.
/// Set when navigating from a Daily Quest task; consumed by ResultScreen
/// when the game finishes so the task gets marked complete.
class DailyQuestTaskTracker {
  static String? _pendingTaskId;

  static String? get pendingTaskId => _pendingTaskId;

  /// Call before navigating from a daily quest task.
  static void startTask(String taskId) {
    _pendingTaskId = taskId;
  }

  /// Call after a game completes. Returns the tracked task id and clears it.
  static String? consumePendingTask() {
    final id = _pendingTaskId;
    _pendingTaskId = null;
    return id;
  }

  /// Clear without consuming (e.g. user cancelled).
  static void clear() {
    _pendingTaskId = null;
  }
}

// ── Providers ──

final dailyQuestServiceProvider = Provider<DailyQuestService>((ref) {
  return DailyQuestService();
});

/// Holds the current DailyQuest state in memory + persists via Hive.
class DailyQuestState {
  final DailyQuest? quest;
  final bool isLoading;
  final String? error;
  final bool justCompleted; // true for a few seconds after full completion

  const DailyQuestState({
    this.quest,
    this.isLoading = false,
    this.error,
    this.justCompleted = false,
  });

  DailyQuestState copyWith({
    DailyQuest? quest,
    bool? isLoading,
    String? error,
    bool? justCompleted,
    bool clearError = false,
  }) {
    return DailyQuestState(
      quest: quest ?? this.quest,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      justCompleted: justCompleted ?? this.justCompleted,
    );
  }
}

class DailyQuestNotifier extends StateNotifier<DailyQuestState> {
  final DailyQuestService _service;
  final StreakNotifier _streakNotifier;
  final XpNotifier _xpNotifier;
  final CoinNotifier _coinNotifier;

  DailyQuestNotifier(
    this._service,
    this._streakNotifier,
    this._xpNotifier,
    this._coinNotifier,
  ) : super(const DailyQuestState()) {
    _init();
  }

  void _init() {
    // Try loading saved quest first
    final saved = _service.loadSavedQuest();
    if (saved != null) {
      state = DailyQuestState(quest: saved);
    } else {
      _generateNewQuest();
    }
  }

  void _generateNewQuest() {
    final quest = _service.generateTodayQuest();
    _service.saveQuest(quest);
    state = DailyQuestState(quest: quest);
  }

  /// Called when a task is completed from the game screen
  Future<void> completeTask(String taskId) async {
    final current = state.quest;
    if (current == null) return;

    // Find the task in the current quest
    final taskIndex = current.tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return; // Task not found

    final task = current.tasks[taskIndex];
    final wasAlreadyCompleted = task.isCompleted;

    final updated = _service.completeTask(current, taskId);
    _service.saveQuest(updated);

    // Award XP & coins only if not already completed
    if (!wasAlreadyCompleted) {
      await _xpNotifier.addXP(task.xpReward);
      await _coinNotifier.addCoins(task.coinReward);
    }

    final wasJustCompleted = !current.isCompleted && updated.isCompleted;

    state = DailyQuestState(
      quest: updated,
      justCompleted: wasJustCompleted,
    );

    // If ALL tasks done, auto-claim bonus & update streak
    if (wasJustCompleted) {
      await _claimBonus(updated);
    }
  }

  Future<void> _claimBonus(DailyQuest quest) async {
    final withBonus = _service.claimBonus(quest);
    _service.saveQuest(withBonus);

    // Bonus XP & coins
    await _xpNotifier.addXP(quest.completionBonusXP);
    await _coinNotifier.addCoins(quest.completionBonusCoins);

    state = DailyQuestState(quest: withBonus, justCompleted: true);

    // Refresh streak after quest completion
    _streakNotifier.refresh();
  }

  void resetJustCompleted() {
    if (state.justCompleted) {
      state = state.copyWith(justCompleted: false);
    }
  }

  /// Force a refresh — regenerate if it's a new day
  void refresh() {
    final saved = _service.loadSavedQuest();
    if (saved == null) {
      _generateNewQuest();
    } else {
      state = DailyQuestState(quest: saved);
    }
  }
}

final dailyQuestProvider =
    StateNotifierProvider<DailyQuestNotifier, DailyQuestState>((ref) {
  final service = ref.watch(dailyQuestServiceProvider);
  final streakNotifier = ref.watch(streakProvider.notifier);
  final xpNotifier = ref.watch(xpProvider.notifier);
  final coinNotifier = ref.watch(coinProvider.notifier);
  return DailyQuestNotifier(
    service,
    streakNotifier,
    xpNotifier,
    coinNotifier,
  );
});
