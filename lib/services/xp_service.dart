import '../repositories/progress_repository.dart';
import '../repositories/statistics_repository.dart';

class XpService {
  final ProgressRepository _progressRepository;
  final StatisticsRepository _statisticsRepository;

  XpService({
    required ProgressRepository progressRepository,
    StatisticsRepository? statisticsRepository,
  })  : _progressRepository = progressRepository,
        _statisticsRepository = statisticsRepository ?? StatisticsRepository();

  // ── XP Calculation ──

  int calculateCorrectAnswerXP({int streak = 0}) {
    const baseXP = 10;
    final streakBonus = (streak ~/ 5) * 5; // +5 XP every 5 streak
    return baseXP + streakBonus;
  }

  int calculateSpeedBonusXP({required int timeRemaining, required int totalTime}) {
    if (totalTime <= 0) return 0;
    final ratio = timeRemaining / totalTime;
    if (ratio >= 0.75) return 15;
    if (ratio >= 0.50) return 10;
    if (ratio >= 0.25) return 5;
    return 0;
  }

  int calculateAccuracyBonusXP({required double accuracy}) {
    if (accuracy >= 0.95) return 50;
    if (accuracy >= 0.85) return 30;
    if (accuracy >= 0.70) return 15;
    return 0;
  }

  int calculatePerfectGameXP({required int totalQuestions}) {
    return totalQuestions * 5;
  }

  int calculatePerfectRoundXP() {
    return 50; // Perfect round bonus
  }

  int calculateDailyChallengeXP() {
    return 100; // Daily challenge bonus
  }

  int calculateBossBattleXP() {
    return 200; // Boss battle bonus
  }

  int calculateLevelCompletionXP({required int levelNumber}) {
    return levelNumber * 20;
  }

  int calculateTotalGameXP({
    required int correctCount,
    required int totalQuestions,
    required double accuracy,
    required int streak,
    required int timeRemaining,
    required int totalTime,
    bool isPerfectGame = false,
  }) {
    int xp = 0;

    // Base XP per correct answer
    xp += correctCount * 10;

    // Streak bonus
    final streakBonus = (streak ~/ 5) * 5;
    xp += streakBonus;

    // Speed bonus
    xp += calculateSpeedBonusXP(timeRemaining: timeRemaining, totalTime: totalTime);

    // Accuracy bonus
    xp += calculateAccuracyBonusXP(accuracy: accuracy);

    // Perfect game bonus
    if (isPerfectGame) {
      xp += calculatePerfectGameXP(totalQuestions: totalQuestions);
    }

    return xp;
  }

  // ── XP Management ──

  Future<int> getCurrentXP() async {
    // ProgressRepository is the source of truth for current balance —
    // it tracks ALL XP (game earnings + achievement rewards + bonuses).
    final progress = _progressRepository.getProgress();
    if (progress != null && progress.currentXP > 0) return progress.currentXP;
    // Fall back to statistics box (game-only XP) if progress isn't set yet
    final totalEarned = await _statisticsRepository.getTotalEarnedXP();
    return totalEarned;
  }

  /// XP needed to finish one level. 300 (was 100) so gamer rank
  /// levels up more slowly and feels earned.
  static const int xpPerLevel = 300;

  /// Level from total XP. Shared so Hive / Firestore / leaderboard stay in sync.
  static int levelFromTotalXP(int xp, {int fallback = 1}) {
    if (xp <= 0) return fallback;
    return (xp ~/ xpPerLevel) + 1;
  }

  int levelFromXP(int xp, {int fallback = 1}) {
    return levelFromTotalXP(xp, fallback: fallback);
  }

  Future<int> getCurrentLevel() async {
    final xp = await getCurrentXP();
    final progress = _progressRepository.getProgress();
    return levelFromXP(xp, fallback: progress?.currentLevel ?? 1);
  }

  /// Cumulative XP required to *finish* [currentLevel] and reach the next.
  /// Level 0 (before L1) is 0 so progress-in-level math stays correct.
  int getXPForNextLevel(int currentLevel) {
    if (currentLevel <= 0) return 0;
    return currentLevel * xpPerLevel; // L1→2 = 300, L2→3 = 600, …
  }

  Future<double> getLevelProgress() async {
    final xp = await getCurrentXP();
    final level = await getCurrentLevel();
    return getLevelProgressFor(level, xp);
  }

  /// Synchronous version — computes progress from given level & XP values
  /// without hitting any async storage. Used by Firestore listener callbacks.
  double getLevelProgressFor(int level, int xp) {
    final xpForNext = getXPForNextLevel(level);
    final xpForCurrent = getXPForNextLevel(level - 1);
    final xpInCurrentLevel = xp - xpForCurrent;
    final xpNeeded = xpForNext - xpForCurrent;

    if (xpNeeded <= 0) return 1.0;
    return (xpInCurrentLevel / xpNeeded).clamp(0.0, 1.0);
  }

  Future<bool> checkLevelUp() async {
    final xp = await getCurrentXP();
    final level = await getCurrentLevel();
    final xpNeeded = getXPForNextLevel(level);

    if (xp >= xpNeeded) {
      await _progressRepository.advanceLevel();
      return true;
    }
    return false;
  }

  Future<int> addXP(int xp) async {
    await _progressRepository.addXP(xp);
    final leveledUp = await checkLevelUp();
    if (leveledUp) {
      return await getCurrentLevel();
    }
    return await getCurrentLevel();
  }

  // ── Level Titles (Gamer Ranks) ──

  /// Returns a gaming-style rank title based on the player's level.
  /// Wider ranges = each rank feels more meaningful to achieve.
  String getLevelTitle(int level) {
    if (level <= 5) return 'Rookie';
    if (level <= 12) return 'Bronze';
    if (level <= 21) return 'Silver';
    if (level <= 32) return 'Gold';
    if (level <= 45) return 'Platinum';
    if (level <= 60) return 'Diamond';
    if (level <= 77) return 'Elite';
    if (level <= 95) return 'Master';
    return 'Legend';
  }

  /// Returns an emoji matching the player's rank.
  String getLevelEmoji(int level) {
    if (level <= 5) return '🎯';
    if (level <= 12) return '🥉';
    if (level <= 21) return '🥈';
    if (level <= 32) return '🥇';
    if (level <= 45) return '💎';
    if (level <= 60) return '💠';
    if (level <= 77) return '⚡';
    if (level <= 95) return '🏅';
    return '👑';
  }

  Future<String> getCurrentLevelTitle() async {
    return getLevelTitle(await getCurrentLevel());
  }

  Future<String> getCurrentLevelEmoji() async {
    return getLevelEmoji(await getCurrentLevel());
  }

  // ── Streak XP ──

  int getDailyStreakBonus(int streak) {
    if (streak >= 30) return 100;
    if (streak >= 14) return 50;
    if (streak >= 7) return 25;
    if (streak >= 3) return 10;
    return 0;
  }
}