import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/game/game_provider.dart';
import '../../../providers/game/timer_provider.dart';
import '../../../providers/game/score_provider.dart';
import '../../../services/game_service.dart';
import '../../../providers/game/xp_provider.dart';
import '../../../providers/game/coin_provider.dart';
import '../../../providers/game/sound_provider.dart';
import '../../../providers/game/leaderboard_provider.dart';
import 'game_home_screen.dart';
import 'answer_review_screen.dart';
import 'question_screen.dart';
import 'modes/word_match_mode.dart';
import 'modes/quick_quiz_mode.dart';
import 'modes/fill_in_blanks_mode.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final int score;
  final int correctAnswers;
  final int wrongAnswers;
  final int earnedXP;
  final int earnedCoins;
  final String gameMode;

  const ResultScreen({
    super.key,
    required this.score,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.earnedXP,
    required this.earnedCoins,
    this.gameMode = 'normal',
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  @override
  void initState() {
    super.initState();
    _updateLeaderboard();
  }

  Future<void> _updateLeaderboard() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userName = user.displayName ?? user.email?.split('@').first ?? 'User';
    final xpState = ref.read(xpProvider);

    await ref.read(leaderboardProvider.notifier).updateUserStats(
      userId: user.uid,
      userName: userName,
      xp: xpState.currentXP,
      score: widget.score,
      level: xpState.currentLevel,
    );

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

                const SizedBox(height: 32),

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
    if (widget.gameMode == 'word_match') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WordMatchModeScreen()),
      );
      return;
    }
    if (widget.gameMode == 'quick_quiz') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const QuickQuizModeScreen()),
      );
      return;
    }
    if (widget.gameMode == 'fill_in_blanks') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FillInBlanksModeScreen()),
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