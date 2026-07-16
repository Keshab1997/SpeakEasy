import '../models/game/game_progress_model.dart';
import '../repositories/progress_repository.dart';

class StreakService {
  final ProgressRepository _progressRepository;

  StreakService({required ProgressRepository progressRepository})
      : _progressRepository = progressRepository;

  // ── Streak Management ──

  int getCurrentStreak() {
    final progress = _progressRepository.getProgress();
    return progress?.streak ?? 0;
  }

  Future<int> incrementStreak() async {
    await _progressRepository.incrementStreak();
    return getCurrentStreak();
  }

  Future<void> resetStreak() async {
    await _progressRepository.resetStreak();
  }

  // ── Milestones ──

  bool isMilestoneReached(int streak) {
    if (streak <= 0) return false;
    if (streak == 1) return true;
    if (streak % 3 == 0) return true;
    if (streak % 7 == 0) return true;
    if (streak % 14 == 0) return true;
    if (streak % 30 == 0) return true;
    if (streak % 100 == 0) return true;
    return false;
  }

  String getMilestoneMessage(int streak) {
    if (streak == 1) return 'First day! Let\'s start a streak! 🔥';
    if (streak == 3) return '3-day streak! Keep going! 🔥🔥🔥';
    if (streak == 7) return 'One week! You\'re on fire! 🔥🔥🔥🔥🔥🔥🔥';
    if (streak == 14) return 'Two weeks strong! Amazing dedication! 💪';
    if (streak == 30) return '30-day streak! You\'re a champion! 🏆';
    if (streak == 100) return '100-day streak! Legendary! 👑';
    if (streak % 30 == 0) return '\$streak-day streak! Unstoppable! 🚀';
    if (streak % 7 == 0) return '\$streak-day streak! Keep it up! ⭐';
    return 'Streak: \$streak days! 🔥';
  }

  // ── Daily Streak Check ──

  bool shouldResetStreak() {
    final progress = _progressRepository.getProgress();
    if (progress == null) return false;

    final now = DateTime.now();
    final lastActive = progress.lastActiveDate;
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(lastActive.year, lastActive.month, lastActive.day);
    
    return today.difference(lastDay).inDays >= 2;
  }

  Future<int> checkAndUpdateStreak() async {
    final progress = _progressRepository.getProgress();
    
    // First-time user — initialize streak to 1
    if (progress == null) {
      await _progressRepository.incrementStreak(); // 0 -> 1
      await _progressRepository.updateLastActiveDate(DateTime.now());
      await _progressRepository.incrementTotalActiveDays();
      return 1;
    }

    final now = DateTime.now();
    final lastActive = progress.lastActiveDate;
    final today = DateTime(now.year, now.month, now.day);
    final lastActiveDay = DateTime(lastActive.year, lastActive.month, lastActive.day);
    final daysDifference = today.difference(lastActiveDay).inDays;

    if (daysDifference >= 2) {
      // Streak broken — reset to 1
      await _progressRepository.resetStreak();
      await _progressRepository.incrementStreak();
      return 1;
    }

    if (daysDifference == 1) {
      // New calendar day — increment streak
      await _progressRepository.incrementStreak();
      return getCurrentStreak();
    }

    // Same day — no change
    return getCurrentStreak();
  }

  // ── Streak Rewards ──

  int getStreakBonusXP(int streak) {
    if (streak >= 30) return 200;
    if (streak >= 14) return 100;
    if (streak >= 7) return 50;
    if (streak >= 3) return 20;
    return 5;
  }

  int getStreakBonusCoins(int streak) {
    if (streak >= 30) return 100;
    if (streak >= 14) return 50;
    if (streak >= 7) return 25;
    if (streak >= 3) return 10;
    return 2;
  }

  // ── Flames / Streak Indicator ──

  String getStreakEmoji(int streak) {
    if (streak <= 0) return '⚫';
    if (streak <= 2) return '🔥';
    if (streak <= 6) return '🔥🔥';
    if (streak <= 13) return '🔥🔥🔥';
    if (streak <= 29) return '🔥🔥🔥🔥';
    return '🔥🔥🔥🔥🔥';
  }

  int getStreakFlameCount(int streak) {
    if (streak <= 0) return 0;
    if (streak <= 2) return 1;
    if (streak <= 6) return 2;
    if (streak <= 13) return 3;
    if (streak <= 29) return 4;
    return 5;
  }

  // ── Weekly Streak ──

  int getCurrentWeeklyStreak() {
    final progress = _progressRepository.getProgress();
    return progress?.weeklyStreak ?? 0;
  }

  Future<int> incrementWeeklyStreak() async {
    await _progressRepository.incrementWeeklyStreak();
    return getCurrentWeeklyStreak();
  }

  Future<void> resetWeeklyStreak() async {
    await _progressRepository.resetWeeklyStreak();
  }

  /// Check if the user is in a new ISO week compared to last active date.
  bool isNewWeek() {
    final progress = _progressRepository.getProgress();
    if (progress == null) return false;

    final now = DateTime.now();
    final lastActive = progress.lastActiveDate;

    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(lastActive.year, lastActive.month, lastActive.day);

    // Find the Monday of the current week
    final daysSinceMondayToday = today.weekday - 1;
    final mondayThisWeek = today.subtract(Duration(days: daysSinceMondayToday));

    // Also find the Monday of the week containing lastActiveDate
    final daysSinceMondayLast = lastDay.weekday - 1;
    final mondayLastWeek = lastDay.subtract(Duration(days: daysSinceMondayLast));

    // New week if lastActiveDate's Monday is before this week's Monday
    return mondayLastWeek.isBefore(mondayThisWeek);
  }

  /// Check if the user had any activity in the previous calendar week.
  /// Uses lastActiveDate rather than weeklyActivity (which gets cleared
  /// by HiveService.resetWeeklyActivityIfNewWeek before this runs).
  bool _hadActivityLastWeek(GameProgressModel progress) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastActive = progress.lastActiveDate;
    final lastActiveDay = DateTime(lastActive.year, lastActive.month, lastActive.day);

    // Find Monday of the current week
    final daysSinceMonday = today.weekday - 1;
    final mondayThisWeek = today.subtract(Duration(days: daysSinceMonday));

    // Monday of the previous week
    final mondayPrevWeek = mondayThisWeek.subtract(const Duration(days: 7));

    // Check if lastActiveDay falls within the previous calendar week
    // (Monday 00:00 ≤ lastActiveDay < Monday 00:00 of current week)
    return !lastActiveDay.isBefore(mondayPrevWeek) &&
        lastActiveDay.isBefore(mondayThisWeek);
  }

  /// Check and update weekly streak based on week transition.
  /// Called once per app open, when entering a new week.
  /// - If new week AND had activity last week → increment weeklyStreak
  /// - If new week AND no activity last week → reset weeklyStreak to 0
  /// - If same week → no change
  Future<int> checkAndUpdateWeeklyStreak() async {
    final progress = _progressRepository.getProgress();
    if (progress == null) return 0;

    // If still in the same calendar week, no streak update needed
    if (!isNewWeek()) {
      return progress.weeklyStreak;
    }

    // We've crossed into a new week
    // Check if the user had activity in the previous week
    final hadActivity = _hadActivityLastWeek(progress);
    
    if (hadActivity) {
      await _progressRepository.incrementWeeklyStreak();
    } else {
      await _progressRepository.resetWeeklyStreak();
    }

    return getCurrentWeeklyStreak();
  }

  // ── Longest Streak ──

  int getLongestStreak() {
    final progress = _progressRepository.getProgress();
    return progress?.longestStreak ?? 0;
  }

  Future<void> updateLongestStreak(int currentStreak) async {
    final longest = getLongestStreak();
    if (currentStreak > longest) {
      await _progressRepository.updateLongestStreak(currentStreak);
    }
  }

  // ── Missed Days Tracking ──

  int getMissedDays() {
    final progress = _progressRepository.getProgress();
    return progress?.missedDays ?? 0;
  }

  Future<void> incrementMissedDays() async {
    await _progressRepository.incrementMissedDays();
  }

  Future<void> resetMissedDays() async {
    await _progressRepository.resetMissedDays();
  }

  int calculateMissedDays({required DateTime lastActiveDate}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(lastActiveDate.year, lastActiveDate.month, lastActiveDate.day);
    final daysDifference = today.difference(lastDay).inDays;
    
    if (daysDifference > 1) {
      return daysDifference - 1; // E.g., if missed yesterday (diff 2), missed 1 day.
    }
    return 0;
  }

  // ── Streak Statistics ──

  StreakStats getStreakStats() {
    final progress = _progressRepository.getProgress();
    if (progress == null) {
      return const StreakStats(
        currentStreak: 0,
        weeklyStreak: 0,
        longestStreak: 0,
        missedDays: 0,
        totalActiveDays: 0,
      );
    }

    return StreakStats(
      currentStreak: progress.streak,
      weeklyStreak: progress.weeklyStreak,
      longestStreak: progress.longestStreak,
      missedDays: progress.missedDays,
      totalActiveDays: progress.totalActiveDays,
    );
  }

  Future<void> recordActiveDay() async {
    final progress = _progressRepository.getProgress();
    final now = DateTime.now();

    if (progress != null) {
      final lastActive = progress.lastActiveDate;
      final today = DateTime(now.year, now.month, now.day);
      final lastActiveDay = DateTime(lastActive.year, lastActive.month, lastActive.day);
      final daysDifference = today.difference(lastActiveDay).inDays;

      if (daysDifference > 0) {
        // Only increment totalActiveDays if it's a new calendar day
        // (Don't increment if daysDifference == 0)
        await _progressRepository.incrementTotalActiveDays();
        
        // Update weekly streak only once per day
        await checkAndUpdateWeeklyStreak();
      }
    }

    // Now update last active date (done on every launch, or at least every day)
    await _progressRepository.updateLastActiveDate(now);

    // Update longest streak if current streak is higher
    final currentStreak = getCurrentStreak();
    await updateLongestStreak(currentStreak);
  }

  // ── Streak Recovery ──

  bool canRecoverStreak() {
    final progress = _progressRepository.getProgress();
    if (progress == null) return false;

    final now = DateTime.now();
    final lastActive = progress.lastActiveDate;
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(lastActive.year, lastActive.month, lastActive.day);
    
    // Can recover if exactly 1 day was missed (daysDifference == 2)
    return today.difference(lastDay).inDays == 2;
  }

  Future<bool> recoverStreak({int coinCost = 50}) async {
    if (!canRecoverStreak()) return false;

    // Check if user has enough coins
    final currentCoins = _progressRepository.getProgress()?.totalCoins ?? 0;
    if (currentCoins < coinCost) return false;

    // Spend coins
    final canAfford = await _progressRepository.spendCoins(coinCost);
    if (!canAfford) return false;

    // Reset missed days
    await resetMissedDays();

    // Streak will be restored
    return true;
  }
}

// ── Streak Statistics Model ──

class StreakStats {
  // ... (keep the same structure)
  final int currentStreak;
  final int weeklyStreak;
  final int longestStreak;
  final int missedDays;
  final int totalActiveDays;

  const StreakStats({
    this.currentStreak = 0,
    this.weeklyStreak = 0,
    this.longestStreak = 0,
    this.missedDays = 0,
    this.totalActiveDays = 0,
  });

  StreakStats copyWith({
    int? currentStreak,
    int? weeklyStreak,
    int? longestStreak,
    int? missedDays,
    int? totalActiveDays,
  }) {
    return StreakStats(
      currentStreak: currentStreak ?? this.currentStreak,
      weeklyStreak: weeklyStreak ?? this.weeklyStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      missedDays: missedDays ?? this.missedDays,
      totalActiveDays: totalActiveDays ?? this.totalActiveDays,
    );
  }

  double get consistency {
    if (totalActiveDays == 0) return 0.0;
    final expectedDays = totalActiveDays + missedDays;
    if (expectedDays == 0) return 0.0;
    return (totalActiveDays / expectedDays).clamp(0.0, 1.0);
  }

  String get consistencyLabel {
    final c = consistency;
    if (c >= 0.9) return 'Excellent';
    if (c >= 0.7) return 'Good';
    if (c >= 0.5) return 'Fair';
    return 'Needs Improvement';
  }
}
