import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/streak_service.dart';
import '../../services/hive_service.dart';
import 'game_provider.dart';

// ── Streak State ──

class StreakState {
  final int currentStreak;
  final int weeklyStreak;
  final int bestStreak;
  final int longestStreak;
  final int missedDays;
  final bool shouldReset;
  final String emoji;
  final int flameCount;
  final String weeklyMilestone;      // milestone emoji for weekly streak
  final String weeklyMilestoneLabel; // label like "Dedicated"
  final int thisWeekActiveDays;      // how many days active this week (0-7)

  const StreakState({
    this.currentStreak = 0,
    this.weeklyStreak = 0,
    this.bestStreak = 0,
    this.longestStreak = 0,
    this.missedDays = 0,
    this.shouldReset = false,
    this.emoji = '⚫',
    this.flameCount = 0,
    this.weeklyMilestone = '🌱',
    this.weeklyMilestoneLabel = 'Started',
    this.thisWeekActiveDays = 0,
  });

  StreakState copyWith({
    int? currentStreak,
    int? weeklyStreak,
    int? bestStreak,
    int? longestStreak,
    int? missedDays,
    bool? shouldReset,
    String? emoji,
    int? flameCount,
  }) {
    return StreakState(
      currentStreak: currentStreak ?? this.currentStreak,
      weeklyStreak: weeklyStreak ?? this.weeklyStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      missedDays: missedDays ?? this.missedDays,
      shouldReset: shouldReset ?? this.shouldReset,
      emoji: emoji ?? this.emoji,
      flameCount: flameCount ?? this.flameCount,
    );
  }
}

class StreakNotifier extends StateNotifier<StreakState> {
  final StreakService _streakService;

  StreakNotifier(this._streakService) : super(const StreakState()) {
    _refresh();
  }

  void _refresh() {
    final streak = _streakService.getCurrentStreak();
    final weeklyStreak = _streakService.getCurrentWeeklyStreak();
    final longestStreak = _streakService.getLongestStreak();
    final missedDays = _streakService.getMissedDays();
    final milestone = StreakNotifier.getWeeklyMilestone(weeklyStreak);
    final weekActiveDays = HiveService.getWeekActivityList().where((a) => a).length;
    
    state = StreakState(
      currentStreak: streak,
      weeklyStreak: weeklyStreak,
      bestStreak: streak,
      longestStreak: longestStreak,
      missedDays: missedDays,
      shouldReset: _streakService.shouldResetStreak(),
      emoji: _streakService.getStreakEmoji(streak),
      flameCount: _streakService.getStreakFlameCount(streak),
      weeklyMilestone: milestone.emoji,
      weeklyMilestoneLabel: milestone.label,
      thisWeekActiveDays: weekActiveDays,
    );
  }

  Future<int> incrementStreak() async {
    final newStreak = await _streakService.incrementStreak();
    _refresh();
    return newStreak;
  }

  Future<void> resetStreak() async {
    await _streakService.resetStreak();
    _refresh();
  }

  Future<int> checkAndUpdateStreak() async {
    final newStreak = await _streakService.checkAndUpdateStreak();
    _refresh();
    return newStreak;
  }

  bool isMilestoneReached() {
    return _streakService.isMilestoneReached(state.currentStreak);
  }

  String getMilestoneMessage() {
    return _streakService.getMilestoneMessage(state.currentStreak);
  }

  int getStreakBonusXP() {
    return _streakService.getStreakBonusXP(state.currentStreak);
  }

  int getStreakBonusCoins() {
    return _streakService.getStreakBonusCoins(state.currentStreak);
  }

  // ── Weekly Milestone Helpers ──

  /// Get milestone emoji and label for a given weekly streak count.
  static ({String emoji, String label}) getWeeklyMilestone(int weeklyStreak) {
    if (weeklyStreak >= 52) return (emoji: '👑', label: 'Legend');
    if (weeklyStreak >= 26) return (emoji: '💪', label: 'Committed');
    if (weeklyStreak >= 12) return (emoji: '⚡', label: 'Dedicated');
    if (weeklyStreak >= 4) return (emoji: '🔥', label: 'Consistent');
    if (weeklyStreak >= 1) return (emoji: '🌱', label: 'Started');
    return (emoji: '⚪', label: 'No streak');
  }

  // ── Weekly Streak ──

  int getCurrentWeeklyStreak() {
    return _streakService.getCurrentWeeklyStreak();
  }

  Future<int> incrementWeeklyStreak() async {
    final newStreak = await _streakService.incrementWeeklyStreak();
    _refresh();
    return newStreak;
  }

  Future<void> resetWeeklyStreak() async {
    await _streakService.resetWeeklyStreak();
    _refresh();
  }

  Future<int> checkAndUpdateWeeklyStreak() async {
    final newStreak = await _streakService.checkAndUpdateWeeklyStreak();
    _refresh();
    return newStreak;
  }

  // ── Longest Streak ──

  int getLongestStreak() {
    return _streakService.getLongestStreak();
  }

  Future<void> updateLongestStreak(int currentStreak) async {
    await _streakService.updateLongestStreak(currentStreak);
    _refresh();
  }

  // ── Missed Days ──

  int getMissedDays() {
    return _streakService.getMissedDays();
  }

  Future<void> incrementMissedDays() async {
    await _streakService.incrementMissedDays();
    _refresh();
  }

  Future<void> resetMissedDays() async {
    await _streakService.resetMissedDays();
    _refresh();
  }

  // ── Streak Statistics ──

  StreakStats getStreakStats() {
    return _streakService.getStreakStats();
  }

  Future<void> recordActiveDay() async {
    await _streakService.recordActiveDay();
    _refresh();
  }

  // ── Streak Recovery ──

  bool canRecoverStreak() {
    return _streakService.canRecoverStreak();
  }

  Future<bool> recoverStreak({int coinCost = 50}) async {
    final success = await _streakService.recoverStreak(coinCost: coinCost);
    if (success) {
      _refresh();
    }
    return success;
  }

  void refresh() {
    _refresh();
  }
}

final streakServiceProvider = Provider<StreakService>((ref) {
  return StreakService(
    progressRepository: ref.watch(progressRepositoryProvider),
  );
});

final streakProvider = StateNotifierProvider<StreakNotifier, StreakState>((ref) {
  final streakService = ref.watch(streakServiceProvider);
  return StreakNotifier(streakService);
});