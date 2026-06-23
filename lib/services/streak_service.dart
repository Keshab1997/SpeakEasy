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
    if (streak % 30 == 0) return '$streak-day streak! Unstoppable! 🚀';
    if (streak % 7 == 0) return '$streak-day streak! Keep it up! ⭐';
    return 'Streak: $streak days! 🔥';
  }

  // ── Daily Streak Check ──

  bool shouldResetStreak() {
    final progress = _progressRepository.getProgress();
    if (progress == null) return false;

    final now = DateTime.now();
    final lastActive = progress.lastActiveDate;
    final difference = now.difference(lastActive);

    // Reset if more than 48 hours have passed
    return difference.inHours > 48;
  }

  Future<int> checkAndUpdateStreak() async {
    final progress = _progressRepository.getProgress();
    if (progress == null) return 0;

    final now = DateTime.now();
    final lastActive = progress.lastActiveDate;
    final difference = now.difference(lastActive);

    if (difference.inHours > 48) {
      // Streak broken — reset to 1
      await _progressRepository.resetStreak();
      await _progressRepository.incrementStreak();
      return 1;
    }

    if (difference.inHours >= 24) {
      // New day — increment streak
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

  bool isNewWeek() {
    final progress = _progressRepository.getProgress();
    if (progress == null) return false;

    final now = DateTime.now();
    final lastActive = progress.lastActiveDate;
    
    // Check if it's a new week (more than 7 days since last active)
    final difference = now.difference(lastActive);
    return difference.inDays >= 7;
  }

  Future<int> checkAndUpdateWeeklyStreak() async {
    final progress = _progressRepository.getProgress();
    if (progress == null) return 0;

    if (isNewWeek()) {
      // New week - reset weekly streak and start fresh
      await resetWeeklyStreak();
      await incrementWeeklyStreak();
      return 1;
    }

    // Same week - increment if active today
    final now = DateTime.now();
    final lastActive = progress.lastActiveDate;
    final difference = now.difference(lastActive);

    if (difference.inHours < 24) {
      // Active today - increment weekly streak
      await incrementWeeklyStreak();
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
    final difference = now.difference(lastActiveDate);
    
    // If more than 24 hours but less than 48 hours, count as 1 missed day
    // If more than 48 hours, count as 2+ missed days
    if (difference.inHours > 48) {
      return (difference.inDays ~/ 2).clamp(1, difference.inDays);
    } else if (difference.inHours > 24) {
      return 1;
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
    final now = DateTime.now();

    // Update last active date first so subsequent streak checks use fresh data
    await _progressRepository.updateLastActiveDate(now);

    // Update total active days
    await _progressRepository.incrementTotalActiveDays();

    // Update longest streak if current streak is higher
    final currentStreak = getCurrentStreak();
    await updateLongestStreak(currentStreak);

    // Update weekly streak
    await checkAndUpdateWeeklyStreak();
  }

  // ── Streak Recovery ──

  bool canRecoverStreak() {
    final progress = _progressRepository.getProgress();
    if (progress == null) return false;

    final now = DateTime.now();
    final lastActive = progress.lastActiveDate;
    final difference = now.difference(lastActive);

    // Can recover if streak was lost within last 24 hours
    return difference.inHours > 24 && difference.inHours <= 48;
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

    // Streak will be reset to 1 on next check
    return true;
  }
}

// ── Streak Statistics Model ──

class StreakStats {
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
