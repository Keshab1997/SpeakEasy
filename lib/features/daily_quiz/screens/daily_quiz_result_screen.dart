import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/game/coin_provider.dart';
import '../../../services/ad_service.dart';
import '../models/daily_quiz_model.dart';
import '../providers/daily_quiz_provider.dart';
import 'daily_quiz_leaderboard_screen.dart';
import 'daily_quiz_review_screen.dart';

/// Daily Quiz result screen — a playful, celebratory summary showing the
/// learner's score, stats, rewards and leaderboard position.
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

    // Big celebratory emoji based on performance.
    final emoji = isPerfect
        ? '👑'
        : accuracy >= 0.8
            ? '🎉'
            : accuracy >= 0.5
                ? '💪'
                : '📚';

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF6C63FF), Color(0xFF4F46E5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Playful decorative circles.
              Positioned(
                top: -70,
                right: -70,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                bottom: -60,
                left: -60,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Positioned(
                top: 120,
                left: -40,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Celebratory emoji
                    Text(emoji, style: const TextStyle(fontSize: 52)),
                    const SizedBox(height: 8),
                    Text(
                      isPerfect ? 'Perfect!' : 'Quiz Complete!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rating,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 17),
                    ),
                    const SizedBox(height: 28),

                    // Score ring
                    _ScoreRing(score: quiz.score, accuracy: accuracy),
                    const SizedBox(height: 32),

                    // Stats tiles
                    Row(
                      children: [
                        Expanded(
                          child: _ResultTile(
                            label: 'Correct',
                            value: '$correctCount',
                            icon: Icons.check_circle,
                            color: const Color(0xFF4ADE80),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ResultTile(
                            label: 'Wrong',
                            value: '$wrongCount',
                            icon: Icons.cancel,
                            color: const Color(0xFFF87171),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ResultTile(
                            label: 'Accuracy',
                            value: '${(accuracy * 100).toStringAsFixed(0)}%',
                            icon: Icons.pie_chart,
                            color: const Color(0xFF93C5FD),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Time + Rewards
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _RewardPill(
                              emoji: '⏱️',
                              label: 'Time',
                              value: timeFormatted,
                            ),
                          ),
                          _RewardPill(
                            emoji: '⭐',
                            label: 'XP',
                            value: '+${quiz.earnedXP}',
                            color: const Color(0xFFFFE082),
                          ),
                          _RewardPill(
                            emoji: '🪙',
                            label: 'Coins',
                            value: '+${quiz.earnedCoins}',
                            color: const Color(0xFFFFC400),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 🎥 Bonus Points button (Rewarded Ad)
                    _BonusAdButton(quiz: quiz, ref: ref),
                    const SizedBox(height: 12),

                    // Review & Learn button (with interstitial ad)
                    if (quiz.isCompleted && quiz.answers.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await AdService().showInterstitialAd();
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DailyQuizReviewScreen(),
                                ),
                              );
                            }
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
                    const SizedBox(height: 24),

                    // Leaderboard Section
                    if (leaderboardRank != null || topEntries.isNotEmpty)
                      _LeaderboardSection(
                        leaderboardRank: leaderboardRank,
                        topEntries: topEntries,
                      ),
                    const SizedBox(height: 24),

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
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
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
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
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

/// Animated accuracy ring with the score in the center.
class _ScoreRing extends StatelessWidget {
  final int score;
  final double accuracy;

  const _ScoreRing({required this.score, required this.accuracy});

  @override
  Widget build(BuildContext context) {
    final ringColor = accuracy >= 0.8
        ? AppColors.success
        : accuracy >= 0.5
            ? const Color(0xFFFBBF24)
            : AppColors.error;
    return SizedBox(
      width: 168,
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: accuracy.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            builder: (context, value, _) => CircularProgressIndicator(
              value: value,
              strokeWidth: 14,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation(ringColor),
            ),
          ),
          Container(
            width: 134,
            height: 134,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$score',
                  style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    height: 1.1,
                  ),
                ),
                const Text(
                  'points',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small stat tile (Correct / Wrong / Accuracy).
class _ResultTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ResultTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Compact pill used for Time / XP / Coins highlights.
class _RewardPill extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color? color;

  const _RewardPill({
    required this.emoji,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

/// Bonus Points button that shows a Rewarded Ad.
///
/// Uses local state to track whether the bonus has been claimed so the button
/// can be disabled after the user watches the ad.
class _BonusAdButton extends ConsumerStatefulWidget {
  final DailyQuiz quiz;
  final WidgetRef ref;

  const _BonusAdButton({required this.quiz, required this.ref});

  @override
  ConsumerState<_BonusAdButton> createState() => _BonusAdButtonState();
}

class _BonusAdButtonState extends ConsumerState<_BonusAdButton> {
  bool _bonusClaimed = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    if (_bonusClaimed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent, size: 22),
            SizedBox(width: 8),
            Text(
              '✅ Bonus Claimed!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isLoading
            ? null
            : () async {
                final messenger = ScaffoldMessenger.of(context);
                setState(() => _isLoading = true);
                final shown = await AdService().showRewardedAd(
                  onRewardEarned: () {
                    widget.ref.read(coinProvider.notifier).addCoins(5);
                    setState(() => _bonusClaimed = true);
                  },
                );
                if (mounted) setState(() => _isLoading = false);
                if (!shown && mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content:
                          Text('No ad available right now. Try again later.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
        icon: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.play_circle_fill, color: Colors.amber, size: 22),
        label: Text(
          _isLoading ? 'Loading ad...' : '🎥 +5 Bonus Coins',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.amber.withValues(alpha: 0.7)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Compact leaderboard preview shown on the result screen.
class _LeaderboardSection extends StatelessWidget {
  final int? leaderboardRank;
  final List<DailyQuizLeaderboardEntry> topEntries;

  const _LeaderboardSection({
    required this.leaderboardRank,
    required this.topEntries,
  });

  @override
  Widget build(BuildContext context) {
    final medals = ['🥇', '🥈', '🥉'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 22),
              SizedBox(width: 8),
              Text(
                'Leaderboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (leaderboardRank != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('👑', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Text(
                    'Your Rank: #$leaderboardRank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (topEntries.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 10),
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
                      width: 34,
                      child: rank <= 3
                          ? Text(medals[rank - 1],
                              style: const TextStyle(fontSize: 18))
                          : Text(
                              '#$rank',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${e.score} pts',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
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
