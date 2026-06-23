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
    // Prefer cumulative total from statistics (game_statistics box)
    final totalEarned = await _statisticsRepository.getTotalEarnedXP();
    if (totalEarned > 0) return totalEarned;
    // Fall back to progress box
    final progress = _progressRepository.getProgress();
    return progress?.currentXP ?? 0;
  }

  Future<int> getCurrentLevel() async {
    final xp = await getCurrentXP();
    if (xp > 0) return (xp ~/ 100) + 1;
    final progress = _progressRepository.getProgress();
    return progress?.currentLevel ?? 1;
  }

  int getXPForNextLevel(int currentLevel) {
    return currentLevel * 100; // Level 1 = 100 XP, Level 2 = 200 XP, etc.
  }

  Future<double> getLevelProgress() async {
    final xp = await getCurrentXP();
    final level = await getCurrentLevel();
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

  // ── Level Titles ──

  String getLevelTitle(int level) {
    if (level <= 3) return 'Beginner';
    if (level <= 6) return 'Learner';
    if (level <= 10) return 'Intermediate';
    if (level <= 15) return 'Advanced';
    if (level <= 20) return 'Expert';
    if (level <= 30) return 'Master';
    return 'Grandmaster';
  }

  Future<String> getCurrentLevelTitle() async {
    return getLevelTitle(await getCurrentLevel());
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