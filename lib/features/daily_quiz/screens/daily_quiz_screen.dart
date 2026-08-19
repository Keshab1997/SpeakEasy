import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/banner_ad_widget.dart';
import '../../../core/widgets/skeleton_widget.dart';
import '../../../providers/game/streak_provider.dart';
import '../../../services/ad_service.dart';
import '../providers/daily_quiz_provider.dart';
import '../services/daily_quiz_leaderboard_service.dart';
import '../models/daily_quiz_model.dart';
import 'daily_quiz_play_screen.dart';
import 'daily_quiz_result_screen.dart';
import 'daily_quiz_leaderboard_screen.dart';
import 'daily_quiz_review_screen.dart';
import 'daily_quiz_history_screen.dart';

/// Daily Quiz landing screen — a playful Duolingo-style hub showing today's
/// quiz status, daily streak, quick stats, leaderboard preview, and actions.
class DailyQuizScreen extends ConsumerWidget {
  const DailyQuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizState = ref.watch(dailyQuizProvider);
    final streak = ref.watch(streakProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final quiz = quizState.quiz;

    return Scaffold(
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
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(context, theme, streak),
              Expanded(
                child: _buildBody(
                  context,
                  ref,
                  theme,
                  isDark,
                  quiz,
                  quizState,
                  streak,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Custom top bar: back button, playful title and a 🔥 streak pill.
  Widget _buildTopBar(
    BuildContext context,
    ThemeData theme,
    StreakState streak,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final hasStreak = streak.currentStreak > 0;
    const streakColor = Color(0xFFFF7043);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              foregroundColor: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Daily Quiz',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: isDark
                    ? AppColors.onBackgroundDark
                    : AppColors.onBackgroundLight,
              ),
            ),
          ),
          // History entry point.
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DailyQuizHistoryScreen()),
            ),
            icon: const Icon(Icons.history_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              foregroundColor: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          // Streak pill — only lights up when the user has an active streak.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: hasStreak
                  ? streakColor.withValues(alpha: 0.12)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🔥',
                  style: TextStyle(
                    fontSize: 16,
                    color: hasStreak ? streakColor : Colors.grey,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${streak.currentStreak}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: hasStreak ? streakColor : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    StreakState streak,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeBanner(theme, quiz),
          const SizedBox(height: 16),
          const _YesterdayChampionBanner(),
          const SizedBox(height: 20),
          _buildQuizCard(context, ref, quiz, quizState, theme),
          const SizedBox(height: 20),
          _buildStatStrip(context, quiz, quizState, streak, theme),
          if (quiz != null && !quiz.isCompleted && quizState.isPlaying) ...[
            const SizedBox(height: 20),
            _buildProgressSection(quiz, theme),
          ],
          if (quiz != null && quiz.isCompleted) ...[
            const SizedBox(height: 20),
            _buildReviewCard(context, quiz, theme),
          ],
          const SizedBox(height: 20),
          _buildLeaderboardPreview(context, quizState, theme, isDark),
          const SizedBox(height: 20),
          if (quiz == null || !quiz.isCompleted) _buildTipSection(theme),
          const SizedBox(height: 20),
          const BannerAdWidget(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Big colorful banner with the date and a motivating line —
  /// the first thing the user sees on the landing page.
  Widget _buildWelcomeBanner(ThemeData theme, DailyQuiz? quiz) {
    final now = DateTime.now();
    final dateLabel =
        '${_weekdayName(now.weekday)} · ${now.day} ${_monthName(now.month)}';

    String subtitle;
    if (quiz == null) {
      subtitle = "Answer today's questions and grow your English every day.";
    } else if (quiz.isCompleted) {
      subtitle =
          'Amazing! ${quiz.score} points today — see you tomorrow for a new quiz 🎉';
    } else {
      subtitle =
          'Question ${quiz.answeredCount} of ${quiz.totalQuestions} — you got this!';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.purpleGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -30,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          const Positioned(
            right: 14,
            bottom: 6,
            child: Text('📝', style: TextStyle(fontSize: 40)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLabel.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Today's Challenge",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The hero action card — changes state depending on the quiz lifecycle.
  Widget _buildQuizCard(
    BuildContext context,
    WidgetRef ref,
    DailyQuiz? quiz,
    DailyQuizState quizState,
    ThemeData theme,
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
      title = 'Ready for today?';
      subtitle = "We've prepared a set of fun questions for you.";
      icon = Icons.quiz_outlined;
      buttonLabel = 'Generate Quiz';
      onPressed = () => ref.read(dailyQuizProvider.notifier).loadTodayQuiz();
    } else if (isComplete) {
      title = 'Quiz Complete!';
      subtitle =
          'You scored ${quiz.score} points · ${quiz.correctCount}/${quiz.totalQuestions} correct';
      icon = Icons.celebration;
      buttonLabel = 'View Results';
      onPressed = () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DailyQuizResultScreen()),
          );
    } else if (canResume) {
      title = 'Keep going!';
      subtitle = 'Question ${quiz.answeredCount + 1} of ${quiz.totalQuestions}';
      icon = Icons.play_circle_filled;
      buttonLabel = 'Resume Quiz';
      onPressed = () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DailyQuizPlayScreen()),
          );
    } else {
      title = 'Let\'s play!';
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

    final gradientColors =
        isComplete ? AppColors.secondaryGradient : AppColors.primaryGradient;
    final shadowColor = isComplete ? AppColors.success : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            bottom: -20,
            child: Icon(icon, size: 110, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
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
              ],
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
          ),
        ],
      ),
    );
  }

  /// Three quick stat tiles: day streak, quiz points and leaderboard rank.
  Widget _buildStatStrip(
    BuildContext context,
    DailyQuiz? quiz,
    DailyQuizState quizState,
    StreakState streak,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            emoji: '🔥',
            value: '${streak.currentStreak}',
            label: 'Day Streak',
            accent: const Color(0xFFFF7043),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            emoji: '🏆',
            value: '${quiz?.score ?? 0}',
            label: 'Quiz Points',
            accent: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            emoji: '⭐',
            value: quizState.leaderboardRank != null
                ? '#${quizState.leaderboardRank}'
                : '—',
            label: 'Rank',
            accent: const Color(0xFFEC4899),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection(DailyQuiz quiz, ThemeData theme) {
    final progress = quiz.totalQuestions > 0
        ? quiz.answeredCount / quiz.totalQuestions
        : 0.0;
    final pct = ((progress.isNaN ? 0 : progress).clamp(0.0, 1.0) * 100).toInt();
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress.isNaN ? 0 : progress,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                  color: AppColors.success,
                ),
                Center(
                  child: Text(
                    '$pct%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You\'re on a roll!',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Question ${quiz.answeredCount} of ${quiz.totalQuestions} answered. Keep the momentum going!',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
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
                color: AppColors.info.withValues(alpha: 0.15),
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
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
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
                      color: AppColors.primary.withValues(alpha: 0.1),
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
                              ? Text(medal,
                                  style: const TextStyle(fontSize: 20))
                              : Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
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
                      _Avatar(
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
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
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

  String _weekdayName(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday - 1];
  }

  String _monthName(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return names[month - 1];
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
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
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

/// Round stat tile used in the three-tile stats strip (streak / points / rank).
class _StatTile extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color accent;

  const _StatTile({
    required this.emoji,
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular avatar for leaderboard rows: shows the user's profile photo when
/// available, otherwise falls back to the first initial of their name.
class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;

  const _Avatar({
    required this.photoUrl,
    required this.name,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
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

/// Prominent gold banner showing yesterday's daily-quiz winner, so learners
/// see who they need to beat today (friendly competition).
class _YesterdayChampionBanner extends StatefulWidget {
  const _YesterdayChampionBanner();

  @override
  State<_YesterdayChampionBanner> createState() =>
      _YesterdayChampionBannerState();
}

class _YesterdayChampionBannerState extends State<_YesterdayChampionBanner> {
  final _service = DailyQuizLeaderboardService();
  late Future<DailyQuizLeaderboardEntry?> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadYesterdayChampion();
  }

  Future<DailyQuizLeaderboardEntry?> _loadYesterdayChampion() async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final dateStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final entries = await _service.fetchTopEntries(dateStr, limit: 1);
      return entries.isEmpty ? null : entries.first;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DailyQuizLeaderboardEntry?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final champion = snapshot.data!;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 2.5,
                  ),
                ),
                child: const Center(
                  child: Text('🏆', style: TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "YESTERDAY'S CHAMPION",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      champion.userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${champion.score} pts — can you beat them today?',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
