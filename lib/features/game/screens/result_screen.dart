import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/game/game_provider.dart';
import '../../../providers/game/timer_provider.dart';
import '../../../providers/game/score_provider.dart';
import '../../../services/game_service.dart';
import '../../../services/achievement_service.dart';
import '../../../services/ad_service.dart';
import '../../../providers/game/xp_provider.dart';
import '../../../providers/game/coin_provider.dart';
import '../../../providers/game/streak_provider.dart';
import '../../../providers/game/sound_provider.dart';
import '../../../providers/game/leaderboard_provider.dart';
import '../../../providers/game/achievement_provider.dart';
import '../../../repositories/progress_repository.dart';
import '../../../repositories/statistics_repository.dart';
import '../../../repositories/achievement_repository.dart';
import '../../../models/game/game_result_model.dart';
import '../../../models/game/achievement_model.dart';
import '../../daily_quest/providers/daily_quest_provider.dart';
import 'game_home_screen.dart';
import 'answer_review_screen.dart';
import 'question_screen.dart';
import 'modes/word_match_mode.dart';
import 'modes/quick_quiz_mode.dart';
import 'modes/fill_in_blanks_mode.dart';
import 'modes/sentence_builder_mode.dart';
import 'modes/grammar_detective_mode.dart';
import 'modes/verb_learning_mode.dart';
import 'modes/flashcard_mode.dart';
import '../widgets/achievement_unlock_overlay.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final int score;
  final int correctAnswers;
  final int wrongAnswers;
  final int earnedXP;
  final int earnedCoins;
  final String gameMode;

  /// Optional: when this game was started from a Daily Quest task,
  /// this task ID will be marked as complete.
  final String? dailyQuestTaskId;

  const ResultScreen({
    super.key,
    required this.score,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.earnedXP,
    required this.earnedCoins,
    this.gameMode = 'normal',
    this.dailyQuestTaskId,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _adWatched = false;
  bool _isLoadingAd = false;

  @override
  void initState() {
    super.initState();
    // Run all async init in order inside a single microtask.
    // We save the result FIRST so achievement checks can read the current game's data.
    Future.microtask(() async {
      await _saveLocalResult();

      // Complete any pending Daily Quest task
      _completeDailyQuestTask();

      await _addRewards();
      _updateLeaderboard();
      await _checkAchievements();
      _updateLeaderboard(); // Refresh XP/coin providers after achievement rewards are added
      await _syncGameDataToFirebase();
    });
  }

  /// Marks a Daily Quest task as complete if this game was started
  /// from the Daily Quest flow.
  void _completeDailyQuestTask() {
    // First try the explicit constructor parameter
    final taskId = widget.dailyQuestTaskId
        // Fall back to the static tracker (set by DailyQuestScreen before navigation)
        ?? DailyQuestTaskTracker.consumePendingTask();
    if (taskId != null) {
      try {
        ref.read(dailyQuestProvider.notifier).completeTask(taskId);
      } catch (e) {
        debugPrint('❌ Error completing daily quest task: $e');
      }
    }
  }

  /// Saves the current game result to Hive (StatisticsRepository) before
  /// checking achievements, so the check sees the current game's stats.
  Future<void> _saveLocalResult() async {
    try {
      final repo = StatisticsRepository();
      await repo.saveResult(GameResultModel(
        score: widget.score,
        correctAnswers: widget.correctAnswers,
        wrongAnswers: widget.wrongAnswers,
        earnedXP: widget.earnedXP,
        earnedCoins: widget.earnedCoins,
        gameType: widget.gameMode,
        completedTime: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('❌ Error saving game result: $e');
    }
  }

  /// Adds XP, coins, and updates streak for the completed game.
  /// This runs AFTER saving the result but BEFORE checking achievements,
  /// so that the cumulative stats include this game's rewards.
  Future<void> _addRewards() async {
    try {
      await ref.read(xpProvider.notifier).addXP(widget.earnedXP);
    } catch (e) {
      debugPrint('❌ Error adding XP: $e');
    }
    try {
      await ref.read(coinProvider.notifier).addCoins(widget.earnedCoins);
    } catch (e) {
      debugPrint('❌ Error adding coins: $e');
    }
    try {
      await ref.read(streakProvider.notifier).checkAndUpdateStreak();
    } catch (e) {
      debugPrint('❌ Error updating streak: $e');
    }
    try {
      await ref.read(streakProvider.notifier).recordActiveDay();
    } catch (e) {
      debugPrint('❌ Error recording active day: $e');
    }
  }

  Future<void> _checkAchievements() async {
    final total = widget.correctAnswers + widget.wrongAnswers;
    final accuracy = total > 0 ? widget.correctAnswers / total : 0.0;
    final isBossBattle = widget.gameMode == 'boss';

    int durationSeconds = 0;
    try {
      final results = await StatisticsRepository().getResults();
      if (results.isNotEmpty) {
        durationSeconds = results.first.durationSeconds;
      }
    } catch (e) {
      debugPrint('❌ Error reading duration: $e');
    }
    
    try {
      final newlyUnlocked = await ref.read(achievementProvider.notifier).checkGameAchievements(
        score: widget.score,
        correctAnswers: widget.correctAnswers,
        accuracy: accuracy,
        isBossBattle: isBossBattle,
        gameMode: widget.gameMode,
        durationSeconds: durationSeconds,
      );
      if (newlyUnlocked.isNotEmpty && mounted) {
        _showAchievementUnlock(newlyUnlocked);
      }
    } catch (e) {
      debugPrint('❌ Error checking achievements: $e');
    }
  }

  void _showAchievementUnlock(List<AchievementModel> achievements) {
    final rarest = AchievementService.getRarestAchievement(achievements);
    if (rarest == null) return;

    // Play achievement sound
    try {
      final soundService = ref.read(soundServiceProvider);
      soundService.playAchievement();
    } catch (_) {
      // Sound service not available — overlay still shows
    }

    // Show full-screen celebration overlay
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      pageBuilder: (context, anim, secondaryAnim) => AchievementUnlockOverlay(
        achievement: rarest,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  /// Syncs all locally-saved game data to Firestore so everything
  /// (progress, statistics, achievements, leaderboard) is consistent
  /// across devices and the Firestore real-time listeners show the
  /// correct values.
  ///
  /// Uses the LAST saved GameResultModel from Hive (which contains ALL
  /// fields: durationSeconds, isBossWin, isDailyChallengeWin, gameType, etc.)
  /// instead of creating a new incomplete model from widget parameters.
  Future<void> _syncGameDataToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;
    final userName = user.displayName ?? user.email?.split('@').first ?? 'User';

    try {
      final statisticsRepo = StatisticsRepository();

      // ── 1. Read the FULL result from Hive (saved by GameService or mode screens) ──
      // This preserves ALL fields: durationSeconds, isBossWin, isDailyChallengeWin,
      // gameType, difficulty, etc. — unlike the old approach that created a new
      // incomplete GameResultModel from widget params.
      final results = await statisticsRepo.getResults();
      var result = results.isNotEmpty ? results.first : null;

      // Fallback for mode screens that did not save to StatisticsRepository locally.
      // E.g., Grammar Detective, Story Completion without repo call, etc.
      if (result == null || DateTime.now().difference(result.completedTime).inSeconds > 10) {
        result = GameResultModel(
          score: widget.score,
          correctAnswers: widget.correctAnswers,
          wrongAnswers: widget.wrongAnswers,
          earnedXP: widget.earnedXP,
          earnedCoins: widget.earnedCoins,
          gameType: widget.gameMode,
          completedTime: DateTime.now(),
        );
        await statisticsRepo.saveResult(result);
      }

      if (result != null) {
        // Upload complete result with ALL 11 fields preserved
        final data = result.toFirestoreMap();
        data['userId'] = userId;
        await FirebaseFirestore.instance
            .collection('game_statistics')
            .add(data);

	        debugPrint('✅ Game result uploaded to Firebase (score: ${result.score}, '
            'correct: ${result.correctAnswers}, wrong: ${result.wrongAnswers}, '
            'xp: ${result.earnedXP}, coins: ${result.earnedCoins}, '
            'gameType: ${result.gameType}, duration: ${result.durationSeconds}s, '
            'isBossWin: ${result.isBossWin}, isDailyChallengeWin: ${result.isDailyChallengeWin})');
      }

      // ── 2. Upload meta statistics (boss wins, daily wins, time played) ──
      await statisticsRepo.uploadMetaToFirestore(userId);

      // ── 3. Save game_progress (XP, coins, level, streak) ──
      final progressRepo = ProgressRepository();
      final localProgress = progressRepo.getProgress();
      if (localProgress != null) {
        final updatedProgress = localProgress.copyWith(userId: userId);
        await progressRepo.uploadProgressToFirestore(updatedProgress);
      }

      // ── 4. Save achievements to Firestore ──
      final achievementRepo = AchievementRepository();
      final localAchievements = achievementRepo.getCachedAchievements();
      if (localAchievements.isNotEmpty) {
        await achievementRepo.batchUploadToFirestore(userId, localAchievements);
      }

      // ── 5. Update leaderboard ──
      await ref.read(leaderboardProvider.notifier).updateUserStats(
            userId: userId,
            userName: userName,
            xp: localProgress?.currentXP ?? widget.earnedXP,
            score: widget.score,
            level: localProgress?.currentLevel ?? 1,
            photoUrl: user.photoURL ?? '',
          );

      debugPrint('✅ Game data synced to Firebase after game completion');
    } catch (e) {
      debugPrint('❌ Error syncing game data to Firebase: $e');
    }
  }

  void _updateLeaderboard() async {
    // Refresh XP & coin providers so stats are up-to-date
    if (mounted) {
      ref.read(xpProvider.notifier).refresh();
      ref.read(coinProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.score;
    final correctAnswers = widget.correctAnswers;
    final wrongAnswers = widget.wrongAnswers;
    final total = correctAnswers + wrongAnswers;
    final accuracy = total > 0 ? correctAnswers / total : 0.0;
    final rating = _getRating(accuracy);
    final isPerfect = accuracy >= 1.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: AppColors.primaryGradient, begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  isPerfect ? 'Perfect!' : 'Game Over',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(rating, style: const TextStyle(color: Colors.white70, fontSize: 18)),
                const SizedBox(height: 40),

                // Score Circle
                Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5)],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$score', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const Text('Score', style: TextStyle(fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Stats Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ResultStat(label: 'Correct', value: '$correctAnswers', icon: Icons.check_circle, color: AppColors.success),
                    _ResultStat(label: 'Wrong', value: '$wrongAnswers', icon: Icons.cancel, color: AppColors.error),
                    _ResultStat(label: 'Accuracy', value: '${(accuracy * 100).toStringAsFixed(1)}%', icon: Icons.pie_chart, color: AppColors.primary),
                  ],
                ),

                const SizedBox(height: 30),

                // Rewards
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _RewardItem(icon: Icons.star, label: 'XP', value: '+${widget.earnedXP}', color: Colors.amber),
                      _RewardItem(icon: Icons.monetization_on, label: 'Coins', value: '+${widget.earnedCoins}', color: Colors.amberAccent),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Watch Ad → Double Coins Button
                if (!_adWatched && widget.earnedCoins > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoadingAd
                            ? null
                            : () async {
                                setState(() => _isLoadingAd = true);
                                final shown = await AdService().showRewardedAd(
                                  onRewardEarned: () {
                                    // Double the coins
                                    ref.read(coinProvider.notifier).addCoins(widget.earnedCoins);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(Icons.monetization_on, color: Colors.amber),
                                              SizedBox(width: 8),
                                              Text('🎉 Coins Doubled!', style: TextStyle(fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          duration: Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  },
                                );
                                if (mounted) {
                                  setState(() {
                                    _adWatched = shown;
                                    _isLoadingAd = false;
                                  });
                                }
                              },
                        icon: Icon(_isLoadingAd ? Icons.hourglass_empty : Icons.play_circle_filled),
                        label: Text(
                          _isLoadingAd
                              ? 'Loading Ad...'
                              : '🎬 Watch Ad → Double Coins!',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amberAccent,
                          side: const BorderSide(color: Colors.amberAccent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // Review Answers Button (only if there are wrong answers)
                if (wrongAnswers > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AnswerReviewScreen()),
                          );
                        },
                        icon: const Icon(Icons.rate_review),
                        label: const Text(
                          'Review Wrong Answers',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ),

                // Retry Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _retryGame(context, ref),
                      icon: const Icon(Icons.replay),
                      label: const Text(
                        'Retry',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(xpProvider.notifier).refresh();
                      ref.read(coinProvider.notifier).refresh();
                      ref.read(soundServiceProvider).playLevelUp();
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GameHomeScreen()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _retryGame(BuildContext context, WidgetRef ref) {
    // If coming from a special game mode, go back to it
    if (widget.gameMode == 'wordMatch') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WordMatchModeScreen()),
      );
      return;
    }
    if (widget.gameMode == 'quickQuiz') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const QuickQuizModeScreen()),
      );
      return;
    }
    if (widget.gameMode == 'fillInBlank') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FillInBlanksModeScreen()),
      );
      return;
    }
    if (widget.gameMode == 'sentenceBuilder') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SentenceBuilderModeScreen()),
      );
      return;
    }
    if (widget.gameMode == 'grammarDetective') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GrammarDetectiveModeScreen()),
      );
      return;
    }
    if (widget.gameMode == 'flashcard') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FlashcardsModeScreen()),
      );
      return;
    }
    if (widget.gameMode == 'verbLearning') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VerbLearningModeScreen()),
      );
      return;
    }

    // Otherwise retry the regular quiz game
    final gameState = ref.read(gameProvider);
    final mode = gameState.gameMode;
    ref.read(gameProvider.notifier).reset();
    ref.read(timerProvider.notifier).resetTimer();
    ref.read(scoreProvider.notifier).resetScore();
    ref.read(gameProvider.notifier).loadQuestions(
      mode: mode,
      limit: mode == GameMode.practice ? 10 : 20,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const QuestionScreen()),
    );
  }

  String _getRating(double accuracy) {
    if (accuracy >= 1.0) return 'Perfect! 🌟';
    if (accuracy >= 0.9) return 'Excellent! 🏆';
    if (accuracy >= 0.8) return 'Great Job! 👏';
    if (accuracy >= 0.7) return 'Good! 👍';
    if (accuracy >= 0.5) return 'Not Bad! 💪';
    return 'Keep Practicing! 📚';
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ResultStat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _RewardItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _RewardItem({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}