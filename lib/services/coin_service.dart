import '../repositories/progress_repository.dart';
import '../repositories/statistics_repository.dart';

class CoinService {
  final ProgressRepository _progressRepository;
  final StatisticsRepository _statisticsRepository;

  CoinService({
    required ProgressRepository progressRepository,
    StatisticsRepository? statisticsRepository,
  })  : _progressRepository = progressRepository,
        _statisticsRepository = statisticsRepository ?? StatisticsRepository();

  // ── Coin Calculation ──

  int calculateCorrectAnswerCoins({int streak = 0}) {
    const baseCoins = 5;
    final streakBonus = (streak ~/ 5) * 2; // +2 coins every 5 streak
    return baseCoins + streakBonus;
  }

  int calculateSpeedBonusCoins({required int timeRemaining, required int totalTime}) {
    if (totalTime <= 0) return 0;
    final ratio = timeRemaining / totalTime;
    if (ratio >= 0.75) return 10;
    if (ratio >= 0.50) return 5;
    if (ratio >= 0.25) return 2;
    return 0;
  }

  int calculateAccuracyBonusCoins({required double accuracy}) {
    if (accuracy >= 0.95) return 25;
    if (accuracy >= 0.85) return 15;
    if (accuracy >= 0.70) return 8;
    return 0;
  }

  int calculatePerfectGameCoins({required int totalQuestions}) {
    return totalQuestions * 3;
  }

  int calculateTotalGameCoins({
    required int correctCount,
    required int totalQuestions,
    required double accuracy,
    required int streak,
    required int timeRemaining,
    required int totalTime,
    bool isPerfectGame = false,
  }) {
    int coins = 0;

    // Base coins per correct answer
    coins += correctCount * 5;

    // Streak bonus
    final streakBonus = (streak ~/ 5) * 2;
    coins += streakBonus;

    // Speed bonus
    coins += calculateSpeedBonusCoins(timeRemaining: timeRemaining, totalTime: totalTime);

    // Accuracy bonus
    coins += calculateAccuracyBonusCoins(accuracy: accuracy);

    // Perfect game bonus
    if (isPerfectGame) {
      coins += calculatePerfectGameCoins(totalQuestions: totalQuestions);
    }

    return coins;
  }

  // ── Coin Management ──

  Future<int> getCurrentCoins() async {
    // Prefer cumulative total from statistics (game_statistics box)
    final totalEarned = await _statisticsRepository.getTotalEarnedCoins();
    if (totalEarned > 0) return totalEarned;
    // Fall back to progress box
    final progress = _progressRepository.getProgress();
    return progress?.totalCoins ?? 0;
  }

  Future<int> addCoins(int coins) async {
    await _progressRepository.addCoins(coins);
    return await getCurrentCoins();
  }

  Future<bool> spendCoins(int amount) async {
    final current = await getCurrentCoins();
    if (current < amount) return false;

    final newBalance = current - amount;
    final progress = _progressRepository.getProgress();
    if (progress == null) return false;

    final updated = progress.copyWith(totalCoins: newBalance);
    await _progressRepository.saveProgress(updated);
    return true;
  }

  // ── Shop Items ──

  Future<bool> canAfford(int cost) async {
    return (await getCurrentCoins()) >= cost;
  }

  int getHintCost() => 20;
  int getSkipCost() => 15;
  int getTimeBoostCost() => 30;
  int getFiftyFiftyCost() => 25;

  Future<bool> buyHint() => spendCoins(getHintCost());
  Future<bool> buySkip() => spendCoins(getSkipCost());
  Future<bool> buyTimeBoost() => spendCoins(getTimeBoostCost());
  Future<bool> buyFiftyFifty() => spendCoins(getFiftyFiftyCost());

  // ── Daily Coin Bonus ──

  int getDailyLoginBonus({required int streak}) {
    if (streak >= 30) return 200;
    if (streak >= 14) return 100;
    if (streak >= 7) return 50;
    if (streak >= 3) return 25;
    return 10;
  }

  int getAchievementBonus() => 50;
  int getLevelUpBonus({required int level}) => level * 10;

  // ── Special Bonuses ──

  int calculateLevelCompleteCoins() {
    return 50; // Level complete bonus
  }

  int calculateBossBattleCoins() {
    return 100; // Boss battle bonus
  }

  int calculateDailyRewardCoins() {
    return 25; // Daily reward bonus
  }

  int calculateTotalBonusCoins({
    bool isLevelComplete = false,
    bool isBossBattle = false,
    bool isDailyReward = false,
  }) {
    int bonusCoins = 0;

    if (isLevelComplete) {
      bonusCoins += calculateLevelCompleteCoins();
    }

    if (isBossBattle) {
      bonusCoins += calculateBossBattleCoins();
    }

    if (isDailyReward) {
      bonusCoins += calculateDailyRewardCoins();
    }

    return bonusCoins;
  }
}
