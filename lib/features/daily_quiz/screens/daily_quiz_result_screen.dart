import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/daily_quiz_provider.dart';
import 'daily_quiz_leaderboard_screen.dart';
import 'daily_quiz_review_screen.dart';

class DailyQuizResultScreen extends ConsumerWidget {
  const DailyQuizResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyQuizProvider);
    final quiz = state.quiz;
    final leaderboardRank = state.leaderboardRank;
    final topEntries = state.topEntries;

    // Guard against null quiz -- should never happen when this screen is shown.
    if (quiz == null) {
      return const Scaffold(
        body: Center(child: Text('No quiz data available')),
      );
    }

    final totalQuestions = quiz.totalQuestions;
    final correctCount = quiz.correctCount;
    final wrongCount = quiz.wrongCount;
    final accuracy = totalQuestions > 0 ? correctCount / totalQuestions : 0.0;
    final rating = _getRating(accuracy);
    final isPerfect = accuracy >= 1.0;

    // Format total time as "Xm Ys"
    final totalMinutes = quiz.totalTime ~/ 60;
    final totalSeconds = quiz.totalTime % 60;
    final timeFormatted = totalMinutes > 0
        ? '${totalMinutes}m ${totalSeconds}s'
        : '${totalSeconds}s';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.primaryGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Title
                Text(
                  isPerfect ? 'Perfect!' : 'Quiz Complete',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  rating,
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const SizedBox(height: 40),

                // Score Circle (accuracy progress ring)
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0,
                          end: accuracy.clamp(0.0, 1.0),
                        ),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOut,
                        builder: (context, value, _) => CircularProgressIndicator(
                          value: value,
                          strokeWidth: 12,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          valueColor: AlwaysStoppedAnimation(
                            accuracy >= 0.8
                                ? AppColors.success
                                : accuracy >= 0.5
                                    ? AppColors.accent
                                    : AppColors.error,
                          ),
                        ),
                      ),
                      Container(
                        width: 130,
                        height: 130,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${quiz.score}',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const Text(
                                'Score',
                                style:
                                    TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ResultStat(
                      label: 'Correct',
                      value: '$correctCount',
                      icon: Icons.check_circle,
                      color: AppColors.success,
                    ),
                    _ResultStat(
                      label: 'Wrong',
                      value: '$wrongCount',
                      icon: Icons.cancel,
                      color: AppColors.error,
                    ),
                    _ResultStat(
                      label: 'Accuracy',
                      value: '${(accuracy * 100).toStringAsFixed(1)}%',
                      icon: Icons.pie_chart,
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Total Time
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined,
                          color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Time: $timeFormatted',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

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
                      _RewardItem(
                        icon: Icons.star,
                        label: 'XP',
                        value: '+${quiz.earnedXP}',
                        color: Colors.amber,
                      ),
                      _RewardItem(
                        icon: Icons.monetization_on,
                        label: 'Coins',
                        value: '+${quiz.earnedCoins}',
                        color: Colors.amberAccent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Review & Learn button
                if (quiz.isCompleted && quiz.answers.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DailyQuizReviewScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.menu_book_rounded),
                      label: const Text(
                        'Review & Learn',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 32),

                // Leaderboard Section
                if (leaderboardRank != null || topEntries.isNotEmpty)
                  _LeaderboardSection(
                    leaderboardRank: leaderboardRank,
                    topEntries: topEntries,
                  ),
                const SizedBox(height: 32),

                // Full Leaderboard Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const DailyQuizLeaderboardScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.leaderboard),
                    label: const Text(
                      'Full Leaderboard',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Home Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context)
                          .popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Home',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
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

  const _ResultStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _RewardItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _RewardItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _LeaderboardSection extends StatelessWidget {
  final int? leaderboardRank;
  final List<DailyQuizLeaderboardEntry> topEntries;

  const _LeaderboardSection({
    required this.leaderboardRank,
    required this.topEntries,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leaderboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (leaderboardRank != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Your Rank: #$leaderboardRank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (topEntries.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
            const Row(
              children: [
                SizedBox(width: 36),
                Expanded(
                    child: Text('Name',
                        style: TextStyle(color: Colors.white70, fontSize: 12))),
                SizedBox(
                    width: 50,
                    child: Text('Score',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 12))),
                SizedBox(
                    width: 50,
                    child: Text('Time',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 12))),
              ],
            ),
            const SizedBox(height: 8),
            ...topEntries.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final e = entry.value;
              final minutes = e.totalTime ~/ 60;
              final seconds = e.totalTime % 60;
              final timeStr =
                  minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        '#$rank',
                        style: TextStyle(
                          color: rank <= 3 ? Colors.amber : Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${e.score}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(
                        timeStr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
