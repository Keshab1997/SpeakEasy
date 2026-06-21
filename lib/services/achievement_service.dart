import '../models/game/achievement_model.dart';
import '../repositories/achievement_repository.dart';
import '../repositories/progress_repository.dart';
import '../repositories/statistics_repository.dart';

class AchievementService {
  final AchievementRepository _achievementRepository;
  final ProgressRepository _progressRepository;
  final StatisticsRepository _statisticsRepository;

  AchievementService({
    required AchievementRepository achievementRepository,
    required ProgressRepository progressRepository,
    required StatisticsRepository statisticsRepository,
  })  : _achievementRepository = achievementRepository,
        _progressRepository = progressRepository,
        _statisticsRepository = statisticsRepository;

  // ── Achievement Loading ──

  Future<List<AchievementModel>> loadAchievements() async {
    var achievements = _achievementRepository.getCachedAchievements();
    if (achievements.isEmpty) {
      achievements = await _achievementRepository.loadFromJson();
      await _achievementRepository.cacheAchievements(achievements);
    }
    return achievements;
  }

  // ── Achievement Unlocking ──

  Future<AchievementModel?> checkAndUnlock(String achievementId) async {
    await loadAchievements();
    if (_achievementRepository.isAchievementUnlocked(achievementId)) {
      return null;
    }
    final achievement = await _achievementRepository.unlockAchievement(achievementId);
    if (achievement == null) return null;

    // Grant rewards on unlock
    if (achievement.xpReward > 0) {
      await _progressRepository.addXP(achievement.xpReward);
    }
    if (achievement.coinReward > 0) {
      await _progressRepository.addCoins(achievement.coinReward);
    }

    return achievement;
  }

  // ── Automatic Achievement Checks ──

  /// Central check after each game. Covers the Phase 17 badges that are
  /// derived from gameplay stats (First Win, 10 Correct, 100 XP,
  /// Perfect Round, Speed Master).
  Future<List<AchievementModel>> checkGameAchievements({
    required int score,
    required int correctAnswers,
    required double accuracy,
    bool isBossBattle = false,
    int speedBonusCount = 0,
  }) async {
    final newlyUnlocked = <AchievementModel>[];

    // First Win — finished a game
    final totalGames = _statisticsRepository.getTotalGamesPlayed();
    if (totalGames >= 1) {
      final a = await checkAndUnlock('first_win');
      if (a != null) newlyUnlocked.add(a);
    }

    // 10 Correct Answers — cumulative
    final totalCorrect =
        _statisticsRepository.getTotalCorrectAnswers() + correctAnswers;
    if (totalCorrect >= 10) {
      final a = await checkAndUnlock('ten_correct');
      if (a != null) newlyUnlocked.add(a);
    }

    // 100 XP — cumulative
    final totalXP = _progressRepository.getProgress()?.currentXP ?? 0;
    if (totalXP >= 100) {
      final a = await checkAndUnlock('xp_100');
      if (a != null) newlyUnlocked.add(a);
    }

    // Perfect Round — 100% accuracy this round
    if (accuracy >= 1.0 && correctAnswers > 0) {
      final a = await checkAndUnlock('perfect_round');
      if (a != null) newlyUnlocked.add(a);
    }

    // Speed Master — 5 consecutive full-time-bonus answers
    if (speedBonusCount >= 5) {
      final a = await checkAndUnlock('speed_master');
      if (a != null) newlyUnlocked.add(a);
    }

    // Boss Slayer — won a boss battle
    if (isBossBattle) {
      final a = await checkAndUnlock('boss_slayer');
      if (a != null) newlyUnlocked.add(a);
    }

    return newlyUnlocked;
  }

  // ── Streak-based badges ──

  Future<List<AchievementModel>> checkStreakAchievements(int streak) async {
    final newlyUnlocked = <AchievementModel>[];

    if (streak >= 7) {
      final a = await checkAndUnlock('streak_7');
      if (a != null) newlyUnlocked.add(a);
    }

    return newlyUnlocked;
  }

  // ── Tense mastery badges ──

  Future<List<AchievementModel>> checkTenseMastery({
    required bool presentComplete,
    required bool pastComplete,
    required bool futureComplete,
  }) async {
    final newlyUnlocked = <AchievementModel>[];

    if (presentComplete) {
      final a = await checkAndUnlock('present_tense_master');
      if (a != null) newlyUnlocked.add(a);
    }
    if (pastComplete) {
      final a = await checkAndUnlock('past_tense_master');
      if (a != null) newlyUnlocked.add(a);
    }
    if (futureComplete) {
      final a = await checkAndUnlock('future_tense_master');
      if (a != null) newlyUnlocked.add(a);
    }

    // Tense Champion — all three tenses mastered
    if (presentComplete && pastComplete && futureComplete) {
      final a = await checkAndUnlock('tense_champion');
      if (a != null) newlyUnlocked.add(a);
    }

    return newlyUnlocked;
  }

  // ── Query Achievements ──

  List<AchievementModel> getAllAchievements() {
    return _achievementRepository.getCachedAchievements();
  }

  List<AchievementModel> getUnlockedAchievements() {
    return _achievementRepository.getUnlockedAchievements();
  }

  List<AchievementModel> getLockedAchievements() {
    return _achievementRepository.getLockedAchievements();
  }

  int getUnlockedCount() {
    return _achievementRepository.getUnlockedCount();
  }

  int getTotalCount() {
    return _achievementRepository.getCachedAchievements().length;
  }

  double getCompletionProgress() {
    final total = getTotalCount();
    if (total == 0) return 0.0;
    return getUnlockedCount() / total;
  }
}
