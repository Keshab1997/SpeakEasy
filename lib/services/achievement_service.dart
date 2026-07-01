import '../models/game/achievement_model.dart';
import '../models/game/game_progress_model.dart';
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
    var achievements = await _achievementRepository.getAchievementsFromCache();
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

  // ── Comprehensive Automatic Achievement Checks ──

  /// Checks ALL achievements after every game completion.
  /// Uses cumulative stats from repositories to determine unlocks.
  Future<List<AchievementModel>> checkGameAchievements({
    required int score,
    required int correctAnswers,
    required double accuracy,
    bool isBossBattle = false,
    int speedBonusCount = 0,
    String gameMode = '',
    int durationSeconds = 0,
  }) async {
    final newlyUnlocked = <AchievementModel>[];

    // ── Gather cumulative stats once ──
    final totalGames = await _statisticsRepository.getTotalGamesPlayed();
    final totalCorrect = await _statisticsRepository.getTotalCorrectAnswers();
    final totalWrong = await _statisticsRepository.getTotalWrongAnswers();
    final totalQuestions = totalCorrect + totalWrong;
    final overallAccuracy = totalQuestions > 0 ? totalCorrect / totalQuestions : 0.0;
    final totalXP = await _statisticsRepository.getTotalEarnedXP();
    final totalCoinsEarned = await _statisticsRepository.getTotalEarnedCoins();
    final progress = _progressRepository.getProgress();
    final currentStreak = progress?.streak ?? 0;
    final bossWins = _statisticsRepository.getBossWins();
    final dailyWins = _statisticsRepository.getDailyChallengeWins();

    // Helper to check & unlock
    Future<void> check(String id) async {
      final a = await checkAndUnlock(id);
      if (a != null) newlyUnlocked.add(a);
    }

    // ════════════════════════════════════════
    // 🎯 GENERAL / MILESTONE ACHIEVEMENTS
    // ════════════════════════════════════════

    // First Win
    if (totalGames >= 1) await check('first_win');
    // 10 Correct Answers
    if (totalCorrect >= 10) await check('ten_correct');
    // 50 Games
    if (totalGames >= 50) await check('games_50');
    // 200 Games
    if (totalGames >= 200) await check('games_200');
    // 500 Games
    if (totalGames >= 500) await check('games_500');
    // 1000 Games
    if (totalGames >= 1000) await check('games_1000');

    // ════════════════════════════════════════
    // ⚡ XP ACHIEVEMENTS
    // ════════════════════════════════════════

    if (totalXP >= 100) await check('xp_100');
    if (totalXP >= 1000) await check('xp_1000');
    if (totalXP >= 5000) await check('xp_5000');
    if (totalXP >= 10000) await check('xp_10000');
    if (totalXP >= 25000) await check('xp_25000');
    if (totalXP >= 50000) await check('xp_50000');

    // ════════════════════════════════════════
    // 🔥 STREAK ACHIEVEMENTS
    // ════════════════════════════════════════

    if (currentStreak >= 7) await check('streak_7');
    if (currentStreak >= 30) await check('streak_30');

    // ════════════════════════════════════════
    // 💯 SKILL ACHIEVEMENTS
    // ════════════════════════════════════════

    // Perfect Round
    if (accuracy >= 1.0 && correctAnswers > 0) await check('perfect_round');
    // Speed Master
    if (speedBonusCount >= 5) await check('speed_master');
    // 80% Overall Accuracy
    if (overallAccuracy >= 0.8 && totalGames >= 20) await check('accuracy_80');
    // 90% Overall Accuracy
    if (overallAccuracy >= 0.9 && totalGames >= 50) await check('accuracy_90');
    // Perfect Streak 7
    // Note: This requires tracking consecutive perfect rounds — using a simplified check
    if (accuracy >= 1.0 && correctAnswers > 0 && currentStreak >= 7) {
      await check('perfect_streak_7');
    }

    // ════════════════════════════════════════
    // 🪙 COINS / WEALTH ACHIEVEMENTS
    // ════════════════════════════════════════

    if (totalCoinsEarned >= 500) await check('coins_500');
    if (totalCoinsEarned >= 2000) await check('coins_2000');
    if (totalCoinsEarned >= 10000) await check('coins_10000');

    // ════════════════════════════════════════
    // 🏆 BOSS BATTLE ACHIEVEMENTS
    // ════════════════════════════════════════

    if (isBossBattle || bossWins >= 1) await check('boss_slayer');
    if (bossWins >= 10) await check('boss_conqueror');
    // Boss Immortal — requires perfect boss battle (no lives lost)
    // Passed via accuracy && isBossBattle from caller
    if (isBossBattle && accuracy >= 1.0) await check('boss_immortal');

    // ════════════════════════════════════════
    // 📅 DAILY CHALLENGE ACHIEVEMENTS
    // ════════════════════════════════════════

    if (dailyWins >= 1) await check('daily_starter');
    if (dailyWins >= 7) await check('daily_7');
    if (dailyWins >= 30) await check('daily_30');

    // ════════════════════════════════════════
    // 🎮 GAME-MODE SPECIFIC ACHIEVEMENTS
    // ════════════════════════════════════════

    // Fill in the Blank
    final fillBlankCorrect = await _statisticsRepository.getGameModeCorrect('fillInBlank');
    if (fillBlankCorrect >= 50) await check('fill_blank_pro');
    if (fillBlankCorrect >= 200) await check('fill_blank_master');

    // Choose Correct Tense
    final tenseCorrect = await _statisticsRepository.getGameModeCorrect('chooseCorrectTense');
    if (tenseCorrect >= 50) await check('tense_picker_pro');
    if (tenseCorrect >= 200) await check('tense_picker_master');

    // Sentence Builder
    final sbCorrect = await _statisticsRepository.getGameModeCorrect('sentenceBuilder');
    if (sbCorrect >= 50) await check('builder_pro');
    if (sbCorrect >= 200) await check('builder_master');
    if (durationSeconds > 0 && correctAnswers > 0 && (durationSeconds / correctAnswers) < 10) {
      await check('builder_speedster');
    }

    // Error Detection
    final edCorrect = await _statisticsRepository.getGameModeCorrect('errorDetection');
    if (edCorrect >= 50) await check('error_hunter_pro');
    if (edCorrect >= 200) await check('error_hunter_master');
    if (accuracy >= 1.0 && edCorrect > 0) await check('error_perfect_round');

    // Translation Challenge
    final tcCorrect = await _statisticsRepository.getGameModeCorrect('translationChallenge');
    if (tcCorrect >= 50) await check('translator_pro');
    if (tcCorrect >= 200) await check('translator_master');
    if (tcCorrect >= 500) await check('translator_bilingual');

    // Speed Quiz
    final sqCorrect = await _statisticsRepository.getGameModeCorrect('speedQuiz');
    if (sqCorrect >= 20) await check('speed_demon');
    if (sqCorrect >= 50) await check('speed_lightning');
    if (accuracy >= 1.0 && correctAnswers >= 10) await check('speed_perfect');

    // Word Match
    final wmCorrect = await _statisticsRepository.getGameModeCorrect('wordMatch');
    if (wmCorrect >= 50) await check('word_match_pro');
    if (wmCorrect >= 200) await check('word_match_master');
    if (durationSeconds > 0 && correctAnswers >= 5 && durationSeconds < 30) {
      await check('word_match_lightning');
    }

    // ════════════════════════════════════════
    // 🆕 NEW GAME MODE ACHIEVEMENTS
    // ════════════════════════════════════════

    // Quick Quiz
    final qqCorrect = await _statisticsRepository.getGameModeCorrect('quickQuiz');
    if (qqCorrect >= 20) await check('quick_quiz_starter');
    if (qqCorrect >= 100) await check('quick_quiz_pro');
    if (qqCorrect >= 300) await check('quick_quiz_master');
    if (durationSeconds > 0 && correctAnswers >= 10 && durationSeconds < 30) {
      await check('quick_quiz_speedster');
    }
    if (accuracy >= 1.0 && correctAnswers >= 10) await check('quick_quiz_perfect');

    // Verb Learning
    final vlCorrect = await _statisticsRepository.getGameModeCorrect('verbLearning');
    if (vlCorrect >= 10) await check('verb_learner');
    if (vlCorrect >= 50) await check('verb_pro');
    if (vlCorrect >= 200) await check('verb_master');
    // verb_conqueror — all forms mastered. Simplified check: 500+ correct
    if (vlCorrect >= 500) await check('verb_conqueror');

    // Grammar Detective
    final gdCorrect = await _statisticsRepository.getGameModeCorrect('grammarDetective');
    if (gdCorrect >= 20) await check('grammar_detective_starter');
    if (gdCorrect >= 80) await check('grammar_detective_pro');
    if (gdCorrect >= 300) await check('grammar_detective_master');
    if (accuracy >= 1.0 && correctAnswers >= 5) await check('grammar_detective_perfect');

    // Bangla to English
    final beCorrect = await _statisticsRepository.getGameModeCorrect('banglaToEnglish');
    if (beCorrect >= 20) await check('bangla_starter');
    if (beCorrect >= 100) await check('bangla_pro');
    if (beCorrect >= 500) await check('bangla_master');
    if (beCorrect >= 1000) await check('bangla_expert');

    // Story Completion
    final scCorrect = await _statisticsRepository.getGameModeCorrect('storyCompletion');
    if (scCorrect >= 5) await check('story_starter');
    if (scCorrect >= 20) await check('story_teller');
    if (scCorrect >= 50) await check('story_master');
    if (accuracy >= 1.0 && correctAnswers >= 5) await check('story_perfect');

    // Flashcards
    final fcReviewed = await _statisticsRepository.getGameModeCorrect('flashcard');
    if (fcReviewed >= 50) await check('flashcard_learner');
    if (fcReviewed >= 200) await check('flashcard_pro');
    if (fcReviewed >= 500) await check('flashcard_master');
    if (fcReviewed >= 1000) await check('flashcard_expert');

    // Normal Quiz
    final nqCorrect = await _statisticsRepository.getGameModeCorrect('normal');
    if (nqCorrect >= 10) await check('quiz_starter');
    if (nqCorrect >= 50) await check('quiz_pro');
    if (nqCorrect >= 100) await check('quiz_champion');
    if (accuracy >= 1.0 && correctAnswers >= 10) await check('quiz_perfect');

    return newlyUnlocked;
  }

  // ── Streak-based badges ──

  Future<List<AchievementModel>> checkStreakAchievements(int streak) async {
    final newlyUnlocked = <AchievementModel>[];

    if (streak >= 7) {
      final a = await checkAndUnlock('streak_7');
      if (a != null) newlyUnlocked.add(a);
    }
    if (streak >= 30) {
      final a = await checkAndUnlock('streak_30');
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

  /// Sync statistics from Firestore to Hive so local reads are up-to-date.
  Future<void> syncStatisticsFromFirestore(String userId) async {
    await _statisticsRepository.syncFromFirestoreToHive(userId);
  }

  /// Sync progress from Firestore to Hive so local reads are up-to-date.
  Future<void> syncProgressFromFirestore(String userId) async {
    await _progressRepository.syncProgressFromFirestoreToHive(userId);
  }

  /// Get cached progress from Hive (may be null if never saved).
  GameProgressModel? getCachedProgress() {
    return _progressRepository.getProgress();
  }

  /// Rarity tier ordering (higher = more rare / higher display priority).
  static const Map<String, int> _rarityOrder = {
    'Common': 0,
    'Uncommon': 1,
    'Rare': 2,
    'Epic': 3,
    'Legendary': 4,
  };

  /// Given a list of achievements, returns the one with the highest rarity.
  /// If multiple share the same rarity, returns the one with the lowest
  /// [order] field (i.e., highest display priority within that tier).
  static AchievementModel? getRarestAchievement(List<AchievementModel> achievements) {
    if (achievements.isEmpty) return null;
    return achievements.reduce((a, b) {
      final aOrder = _rarityOrder[a.rarity] ?? 0;
      final bOrder = _rarityOrder[b.rarity] ?? 0;
      if (aOrder != bOrder) return aOrder > bOrder ? a : b;
      return a.order <= b.order ? a : b;
    });
  }
}
