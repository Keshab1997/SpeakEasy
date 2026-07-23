import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/banner_ad_widget.dart';
import '../../../core/widgets/skeleton_widget.dart';
import '../../../services/ad_service.dart';
import '../providers/daily_quiz_provider.dart';
import '../models/daily_quiz_model.dart';
import 'daily_quiz_play_screen.dart';
import 'daily_quiz_result_screen.dart';
import 'daily_quiz_leaderboard_screen.dart';
import 'daily_quiz_review_screen.dart';

/// Daily Quiz landing screen - shows today's quiz status,
/// leaderboard preview, and action buttons.
class DailyQuizScreen extends ConsumerWidget {
  const DailyQuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizState = ref.watch(dailyQuizProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final quiz = quizState.quiz;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📝 Daily Quiz',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppColors.backgroundDark, AppColors.surfaceDark]
                : [AppColors.backgroundLight, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _buildBody(context, ref, theme, isDark, quiz, quizState),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    bool isDark,
    DailyQuiz? quiz,
    DailyQuizState quizState,
  ) {
    if (quizState.isLoading) {
      return const SingleChildScrollView(
        child: Column(
          children: [
            SkeletonProgressHeader(),
            SkeletonCourseCard(),
            SkeletonCourseCard(),
          ],
        ),
      );
    }

    if (quizState.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                quizState.error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(dailyQuizProvider.notifier).loadTodayQuiz(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(quiz, theme),
          const SizedBox(height: 20),
          _buildQuizCard(context, ref, quiz, quizState, theme, isDark),
          const SizedBox(height: 24),
          if (quiz != null && quiz.isCompleted)
            _buildReviewCard(context, quiz, theme),
          if (quiz != null && !quiz.isCompleted && quizState.isPlaying)
            _buildProgressSection(quiz, theme),
          if (quiz != null && !quiz.isCompleted && quizState.isPlaying)
            const SizedBox(height: 24),
          _buildLeaderboardPreview(context, quizState, theme, isDark),
          const SizedBox(height: 24),
          if (quiz == null || !quiz.isCompleted) _buildTipSection(theme),
          const SizedBox(height: 16),
          const BannerAdWidget(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader(DailyQuiz? quiz, ThemeData theme) {
    final now = DateTime.now();
    final dateStr = '${now.day} ${_monthName(now.month)} ${now.year}';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.calendar_today_rounded,
              color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateStr,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              quiz != null
                  ? '${quiz.answeredCount}/${quiz.totalQuestions} questions answered'
                  : 'New quiz available',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  /// Compact "Review" card shown under the completed quiz card, linking to the
  /// per-question learning review screen.
  Widget _buildReviewCard(
    BuildContext context,
    DailyQuiz quiz,
    ThemeData theme,
  ) {
    final correct = quiz.correctCount;
    final total = quiz.totalQuestions;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: AppColors.info, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review & Learn',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'You got $correct/$total — tap to review each answer',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.info, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizCard(
    BuildContext context,
    WidgetRef ref,
    DailyQuiz? quiz,
    DailyQuizState quizState,
    ThemeData theme,
    bool isDark,
  ) {
    final bool canResume =
        quiz != null && !quiz.isCompleted && quizState.isPlaying;
    final bool isComplete = quiz != null && quiz.isCompleted;

    String title;
    String subtitle;
    IconData icon;
    String buttonLabel;
    VoidCallback? onPressed;

    if (quiz == null) {
      title = 'No Quiz Yet';
      subtitle = "Load today's quiz to get started";
      icon = Icons.quiz_outlined;
      buttonLabel = 'Generate Quiz';
      onPressed = () => ref.read(dailyQuizProvider.notifier).loadTodayQuiz();
    } else if (isComplete) {
      title = 'Quiz Complete! 🎉';
      subtitle =
          'You scored ${quiz.score} pts · ${quiz.correctCount}/${quiz.totalQuestions} correct';
      icon = Icons.celebration;
      buttonLabel = 'View Results';
      onPressed = () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DailyQuizResultScreen()),
          );
    } else if (canResume) {
      title = 'Quiz in Progress';
      subtitle =
          'Question ${quiz.answeredCount + 1} of ${quiz.totalQuestions}';
      icon = Icons.play_circle_filled;
      buttonLabel = 'Resume Quiz';
      onPressed = () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DailyQuizPlayScreen()),
          );
    } else {
      title = "Today's Quiz";
      subtitle = '${quiz.totalQuestions} questions · Speed scoring';
      icon = Icons.quiz_outlined;
      buttonLabel = 'Start Quiz';
      onPressed = () {
        ref.read(dailyQuizProvider.notifier).startQuiz();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DailyQuizPlayScreen()),
        );
      };
    }

    final gradientColors = isComplete
        ? [Colors.green.shade400, Colors.green.shade600]
        : AppColors.primaryGradient;

    final shadowColor = isComplete ? Colors.green : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          if (quiz != null && !isComplete) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _QuizChip(
                  icon: Icons.help_outline_rounded,
                  label: '${quiz.totalQuestions} Qs',
                ),
                const _QuizChip(
                  icon: Icons.timer_outlined,
                  label: '30s each',
                ),
                const _QuizChip(
                  icon: Icons.flash_on_rounded,
                  label: 'Speed bonus',
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressSection(DailyQuiz quiz, ThemeData theme) {
    final progress = quiz.totalQuestions > 0
        ? quiz.answeredCount / quiz.totalQuestions
        : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            height: 10,
            child: LinearProgressIndicator(
              value: progress.isNaN ? 0 : progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardPreview(
    BuildContext context,
    DailyQuizState quizState,
    ThemeData theme,
    bool isDark,
  ) {
    final medals = ['🥇', '🥈', '🥉'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const DailyQuizLeaderboardScreen(),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.leaderboard, color: Colors.amber, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Leaderboard',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              if (quizState.leaderboardRank != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Your Rank: #${quizState.leaderboardRank}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (quizState.topEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Complete the quiz to see the leaderboard',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            ...quizState.topEntries.take(3).map((entry) {
              final rank = quizState.topEntries.indexOf(entry) + 1;
              final medal = rank <= medals.length ? medals[rank - 1] : null;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Center(
                        child: medal != null
                            ? Text(medal, style: const TextStyle(fontSize: 20))
                            : Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '$rank',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _LeaderboardAvatar(
                      photoUrl: entry.photoUrl,
                      name: entry.userName,
                      radius: 14,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.userName,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${entry.score} pts',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
      ),
    );
  }

  Widget _buildTipSection(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Speed Scoring',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.amber.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Answer fast for bonus points! '
                  'Correct answers are worth more the quicker you respond.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.amber.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[month - 1];
  }
}

/// Circular avatar for leaderboard rows: shows the user's profile photo when
/// available, otherwise falls back to the first initial of their name.
class _LeaderboardAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;

  const _LeaderboardAvatar({
    required this.photoUrl,
    required this.name,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.12),
      backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
      child: hasPhoto
          ? null
          : Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.85,
              ),
            ),
    );
  }
}

/// Small translucent chip shown on the quiz hero card.
class _QuizChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _QuizChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}