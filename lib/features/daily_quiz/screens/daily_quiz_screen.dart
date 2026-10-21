import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/banner_ad_widget.dart';
import '../../../core/widgets/skeleton_widget.dart';
import '../../../providers/auth_provider.dart';
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

/// Results-first Daily Quiz hub.
///
/// Immediately fetches and displays live Daily Quiz results, podium, and
/// player rankings the moment a learner enters the section — sparking healthy
/// competition right away — with a one-tap sticky action bar to play or resume.
class DailyQuizScreen extends ConsumerStatefulWidget {
  const DailyQuizScreen({super.key});

  @override
  ConsumerState<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends ConsumerState<DailyQuizScreen> {
  bool _startingQuiz = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(dailyQuizProvider);
      final notifier = ref.read(dailyQuizProvider.notifier);
      if (state.quiz == null) {
        notifier.loadTodayQuiz();
      } else {
        notifier.refreshLeaderboard();
      }
    });
  }

  String? _safeCurrentUserId() {
    try {
      return ref.watch(authProvider).asData?.value?.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _onStartOrResumeQuiz() async {
    if (_startingQuiz) return;
    setState(() => _startingQuiz = true);
    try {
      final notifier = ref.read(dailyQuizProvider.notifier);
      if (ref.read(dailyQuizProvider).quiz == null) {
        await notifier.loadTodayQuiz();
      }
      if (!mounted) return;
      final quiz = ref.read(dailyQuizProvider).quiz;
      if (quiz == null) return;

      if (quiz.isCompleted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DailyQuizResultScreen()),
        );
        return;
      }

      notifier.startQuiz();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DailyQuizPlayScreen()),
      );
    } finally {
      if (mounted) {
        setState(() => _startingQuiz = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    final notifier = ref.read(dailyQuizProvider.notifier);
    if (ref.read(dailyQuizProvider).quiz == null) {
      await notifier.loadTodayQuiz();
    } else {
      await notifier.refreshLeaderboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(dailyQuizProvider);
    final streak = ref.watch(streakProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final quiz = quizState.quiz;
    final currentUserId = _safeCurrentUserId();

    return Scaffold(
      bottomNavigationBar: _buildStickyActionBar(
        context,
        theme,
        isDark,
        quiz,
        quizState,
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
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(context, theme, streak),
              Expanded(
                child: _buildBody(
                  context,
                  theme,
                  isDark,
                  quiz,
                  quizState,
                  streak,
                  currentUserId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Custom top bar: back button, title, full leaderboard icon, history, streak.
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
              'Daily Quiz Results',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: isDark
                    ? AppColors.onBackgroundDark
                    : AppColors.onBackgroundLight,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Full Standings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DailyQuizLeaderboardScreen(),
              ),
            ),
            icon: const Icon(Icons.emoji_events_rounded),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.14),
              foregroundColor: const Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'My Quiz History',
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
          const SizedBox(width: 6),
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
    ThemeData theme,
    bool isDark,
    DailyQuiz? quiz,
    DailyQuizState quizState,
    StreakState streak,
    String? currentUserId,
  ) {
    if (quizState.isLoading && quizState.topEntries.isEmpty && quiz == null) {
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

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HERO #1 ON VISIT: Live Daily Quiz Results, Podium & Rankings
            _buildLiveResultsShowcase(
              context,
              quiz,
              quizState,
              theme,
              isDark,
              currentUserId,
            ),
            const SizedBox(height: 16),

            // 2. If user already finished today's quiz, show their detailed
            //    score & review card right underneath live standings.
            if (quiz != null && quiz.isCompleted) ...[
              _buildMyCompletedResultCard(context, quiz, quizState, theme),
              const SizedBox(height: 16),
              _buildReviewCard(context, quiz, theme),
              const SizedBox(height: 16),
            ],

            // 3. If user started today's quiz and paused midway, show progress.
            if (quiz != null && !quiz.isCompleted && quiz.answeredCount > 0) ...[
              _buildProgressSection(quiz, theme),
              const SizedBox(height: 16),
            ],

            // 4. Quick stats strip (Streak / Score / Rank)
            _buildStatStrip(context, quiz, quizState, streak, theme),
            const SizedBox(height: 16),

            // 5. Yesterday's champion banner (when viewing today's live board)
            if (!quizState.isShowingYesterdayResults) ...[
              const _YesterdayChampionBanner(),
              const SizedBox(height: 16),
            ],

            // 6. Motivation / scoring tip card when quiz is still open
            if (quiz == null || !quiz.isCompleted) ...[
              _buildTipSection(theme, isDark),
              const SizedBox(height: 16),
            ],

            const BannerAdWidget(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Primary results-first showcase displayed immediately on entering Daily Quiz.
  Widget _buildLiveResultsShowcase(
    BuildContext context,
    DailyQuiz? quiz,
    DailyQuizState quizState,
    ThemeData theme,
    bool isDark,
    String? currentUserId,
  ) {
    final now = DateTime.now();
    final dateLabel =
        '${_weekdayName(now.weekday)} · ${now.day} ${_monthName(now.month)}';
    final entries = quizState.topEntries;
    final isComplete = quiz?.isCompleted ?? false;
    final canResume =
        quiz != null && !quiz.isCompleted && quiz.answeredCount > 0;

    final boardTitle = quizState.isShowingYesterdayResults
        ? "Yesterday's Final Results"
        : "Today's Live Results";

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient header banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.purpleGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('🏆', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateLabel.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        boardTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DailyQuizLeaderboardScreen(),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.leaderboard_rounded, size: 16),
                  label: const Text(
                    'See All',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          // Body: Podium + Ranked Player Rows (or open crown invite)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (quizState.isLeaderboardLoading && entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (entries.isEmpty)
                  _buildOpenCrownInvite(isDark, theme)
                else ...[
                  // Top #1 spotlight + #2/#3 mini podium cards
                  _buildLeaderHighlight(entries.first),
                  if (entries.length >= 2) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRunnerUpTile(
                            entry: entries[1],
                            rank: 2,
                            medal: '🥈',
                            accent: const Color(0xFF64748B),
                            isDark: isDark,
                          ),
                        ),
                        if (entries.length >= 3) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildRunnerUpTile(
                              entry: entries[2],
                              rank: 3,
                              medal: '🥉',
                              accent: const Color(0xFFB45309),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (entries.length > 3) ...[
                    const SizedBox(height: 14),
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.shade200,
                    ),
                    const SizedBox(height: 10),
                    ...entries.skip(3).take(5).toList().asMap().entries.map(
                      (item) {
                        final rank = item.key + 4;
                        final entry = item.value;
                        final isYou = currentUserId != null &&
                            entry.userId == currentUserId;
                        return _buildStandingRow(
                          entry: entry,
                          rank: rank,
                          isYou: isYou,
                          theme: theme,
                          isDark: isDark,
                        );
                      },
                    ),
                  ],
                ],

                const SizedBox(height: 14),

                // Motivating personal status bar directly under standings
                _buildChallengeCallout(
                  entries: entries,
                  isComplete: isComplete,
                  canResume: canResume,
                  quiz: quiz,
                  rank: quizState.leaderboardRank,
                  isYesterdayBoard: quizState.isShowingYesterdayResults,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenCrownInvite(bool isDark, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFBBF24).withValues(alpha: 0.18),
            const Color(0xFFF59E0B).withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Text('👑', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's #1 Crown is Open!",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Play 10 Spoken English questions right now and set the score everyone else has to beat today!',
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderHighlight(DailyQuizLeaderboardEntry leader) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _Avatar(
                photoUrl: leader.photoUrl,
                name: leader.userName,
                radius: 22,
                lightFallback: true,
              ),
              const Positioned(
                top: -10,
                right: -6,
                child: Text('👑', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '#1 LEADER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  leader.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${leader.correctCount}/10 correct · ${leader.totalTime}s',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${leader.score} pts',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunnerUpTile({
    required DailyQuizLeaderboardEntry entry,
    required int rank,
    required String medal,
    required Color accent,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Text(medal, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '#$rank · ${entry.score} pts',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandingRow({
    required DailyQuizLeaderboardEntry entry,
    required int rank,
    required bool isYou,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isYou
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
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
          const SizedBox(width: 10),
          _Avatar(
            photoUrl: entry.photoUrl,
            name: entry.userName,
            radius: 14,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.userName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isYou ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isYou) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${entry.correctCount}/10 correct · ${entry.totalTime}s',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry.score} pts',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCallout({
    required List<DailyQuizLeaderboardEntry> entries,
    required bool isComplete,
    required bool canResume,
    required DailyQuiz? quiz,
    required int? rank,
    required bool isYesterdayBoard,
    required bool isDark,
  }) {
    final String message;
    final Color color;
    final IconData icon;

    if (isComplete && quiz != null) {
      color = AppColors.success;
      icon = Icons.verified_rounded;
      final rankPart = rank != null ? 'Rank #$rank · ' : '';
      message =
          '${rankPart}You scored ${quiz.score} pts (${quiz.correctCount}/${quiz.totalQuestions} correct) today!';
    } else if (canResume && quiz != null) {
      color = const Color(0xFFF59E0B);
      icon = Icons.bolt_rounded;
      message =
          'Quiz in progress (${quiz.answeredCount}/${quiz.totalQuestions}) — finish now to publish your rank!';
    } else if (entries.isNotEmpty) {
      color = AppColors.primary;
      icon = Icons.local_fire_department_rounded;
      final target = entries.first;
      message = isYesterdayBoard
          ? "Yesterday's #1 scored ${target.score} pts (${target.userName}). Play now to top today's board!"
          : 'Can you beat ${target.userName} (${target.score} pts)? Play 10 quick questions to claim your rank!';
    } else {
      color = AppColors.primary;
      icon = Icons.emoji_events_rounded;
      message = 'Take the quiz now to put your name right at #1!';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dedicated summary card when the user has already finished today's quiz.
  Widget _buildMyCompletedResultCard(
    BuildContext context,
    DailyQuiz quiz,
    DailyQuizState quizState,
    ThemeData theme,
  ) {
    final accuracyPct = quiz.totalQuestions > 0
        ? ((quiz.correctCount / quiz.totalQuestions) * 100).round()
        : 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.secondaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR RESULT TODAY',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${quiz.score} pts · ${quiz.correctCount}/${quiz.totalQuestions} ($accuracyPct%)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (quizState.leaderboardRank != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Current Rank: #${quizState.leaderboardRank}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sticky bottom action bar so starting/resuming the quiz is always one tap
  /// away right below the live results.
  Widget _buildStickyActionBar(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    DailyQuiz? quiz,
    DailyQuizState quizState,
  ) {
    final isComplete = quiz?.isCompleted ?? false;
    final canResume =
        quiz != null && !quiz.isCompleted && quiz.answeredCount > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: isComplete
            ? Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
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
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.menu_book_rounded, size: 20),
                      label: const Text(
                        'Review Answers',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DailyQuizResultScreen(),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.emoji_events_rounded, size: 20),
                      label: const Text(
                        'Full Result',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              )
            : SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startingQuiz ? null : _onStartOrResumeQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: _startingQuiz
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          canResume
                              ? Icons.play_arrow_rounded
                              : Icons.rocket_launch_rounded,
                          size: 22,
                        ),
                  label: Text(
                    canResume
                        ? 'Resume Quiz (${quiz.answeredCount + 1}/${quiz.totalQuestions})'
                        : 'Start Quiz Now · Claim Your Rank!',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
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
    final scoreLabel = quiz == null
        ? '0'
        : quiz.isCompleted || quiz.answeredCount > 0
            ? '${quiz.score}'
            : '0';
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
            value: scoreLabel,
            label: 'My Points',
            accent: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            emoji: '⭐',
            value: quizState.leaderboardRank != null
                ? '#${quizState.leaderboardRank}'
                : 'Unranked',
            label: 'My Rank',
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
                  "You're halfway to a rank!",
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Question ${quiz.answeredCount} of ${quiz.totalQuestions} answered · ${quiz.score} pts so far.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Compact "Review" card shown when today's quiz is completed.
  Widget _buildReviewCard(
    BuildContext context,
    DailyQuiz quiz,
    ThemeData theme,
  ) {
    final correct = quiz.correctCount;
    final total = quiz.totalQuestions;
    final isDark = theme.brightness == Brightness.dark;
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
                    'Review & Learn Spoken Answers',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'You got $correct/$total — tap to review every spoken explanation',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
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

  Widget _buildTipSection(ThemeData theme, bool isDark) {
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
                  'How Leaderboard Points Work',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Up to 150 pts per question (≤10s = 150 pts, ≤20s = 130 pts, ≤30s = 110 pts). Answer accurately & quickly to top the board!',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.amber.shade200 : Colors.amber.shade700,
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
              fontSize: 17,
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
  final bool lightFallback;

  const _Avatar({
    required this.photoUrl,
    required this.name,
    required this.radius,
    this.lightFallback = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: lightFallback
          ? Colors.white.withValues(alpha: 0.28)
          : AppColors.primary.withValues(alpha: 0.12),
      backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
      child: hasPhoto
          ? null
          : Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: lightFallback ? Colors.white : AppColors.primary,
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

  static DailyQuizLeaderboardEntry? _cachedChampion;
  static String? _cachedDateStr;
  static DateTime? _cachedAt;
  static const _bannerCacheTtl = Duration(hours: 12);

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
      if (_cachedDateStr == dateStr &&
          _cachedAt != null &&
          _cachedChampion != null &&
          DateTime.now().difference(_cachedAt!) < _bannerCacheTtl) {
        return _cachedChampion;
      }
      final entries = await _service.fetchTopEntries(dateStr, limit: 1);
      final champ = entries.isEmpty ? null : entries.first;
      _cachedChampion = champ;
      _cachedDateStr = dateStr;
      _cachedAt = DateTime.now();
      return champ;
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
