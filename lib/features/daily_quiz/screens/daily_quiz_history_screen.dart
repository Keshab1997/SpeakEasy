import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../models/daily_quiz_model.dart';
import '../services/daily_quiz_service.dart';

/// Daily Quiz history screen — a playful list of the learner's past results,
/// stored locally in Hive per user.
class DailyQuizHistoryScreen extends ConsumerStatefulWidget {
  const DailyQuizHistoryScreen({super.key});

  @override
  ConsumerState<DailyQuizHistoryScreen> createState() =>
      _DailyQuizHistoryScreenState();
}

class _DailyQuizHistoryScreenState
    extends ConsumerState<DailyQuizHistoryScreen> {
  final _service = DailyQuizService();
  List<DailyQuizHistoryEntry> _entries = [];

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    final userId = ref.read(authProvider).asData?.value?.id;
    if (userId == null) return;
    setState(() => _entries = _service.loadQuizHistory(userId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
              _buildTopBar(context, theme),
              Expanded(child: _buildBody(theme, isDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              foregroundColor: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Quiz History',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: isDark
                    ? AppColors.onBackgroundDark
                    : AppColors.onBackgroundLight,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '📜 Results',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: AppColors.infoGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Text('📜', style: TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No results yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete the Daily Quiz to start building your history!',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bestScore =
        _entries.map((e) => e.score).reduce((a, b) => a > b ? a : b);
    final totalScore = _entries.fold<int>(0, (sum, e) => sum + e.score);
    final avgScore = totalScore ~/ _entries.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        // Stats strip
        Row(
          children: [
            Expanded(
              child: _HistoryStat(
                emoji: '📚',
                value: '${_entries.length}',
                label: 'Quizzes',
                accent: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HistoryStat(
                emoji: '🏆',
                value: '$bestScore',
                label: 'Best Score',
                accent: const Color(0xFFD97706),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HistoryStat(
                emoji: '🎯',
                value: '$avgScore',
                label: 'Avg Score',
                accent: const Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Results
        ..._entries.map((e) => _HistoryCard(entry: e, isDark: isDark)),
      ],
    );
  }
}

/// One past quiz result row with a calendar-style date tile.
class _HistoryCard extends StatelessWidget {
  final DailyQuizHistoryEntry entry;
  final bool isDark;

  const _HistoryCard({required this.entry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = DateTime.tryParse(entry.date);
    const weekdays = _DailyQuizHistoryScreenState._weekdays;
    const months = _DailyQuizHistoryScreenState._months;

    final day = parsed?.day ?? 0;
    final month = parsed != null && parsed.month >= 1 && parsed.month <= 12
        ? months[parsed.month - 1]
        : '?';
    final weekday = parsed != null ? weekdays[parsed.weekday - 1] : '';
    final fullDate = parsed == null
        ? entry.date
        : '$weekday, ${months[parsed.month - 1]} ${parsed.day}';
    final minutes = entry.totalTime ~/ 60;
    final seconds = entry.totalTime % 60;
    final timeStr = minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';

    // Playful emoji based on how well the quiz went.
    final acc = entry.accuracy;
    final emoji = acc >= 85 ? '🎉' : acc >= 60 ? '💪' : acc >= 40 ? '📘' : '🌱';
    final accent = acc >= 85
        ? AppColors.success
        : acc >= 60
            ? AppColors.primary
            : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar-style date tile
          Container(
            width: 54,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withOpacity(0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  month,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullDate,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$weekday' ' · $timeStr',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MiniChip(
                      text: '${entry.correctCount}/${entry.totalQuestions}',
                      accent: accent,
                    ),
                    _MiniChip(
                      text: '+${entry.earnedXP} XP',
                      accent: AppColors.warning,
                    ),
                    if (entry.earnedCoins > 0)
                      _MiniChip(
                        text: '+${entry.earnedCoins} 🪙',
                        accent: AppColors.info,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              Text(
                '${entry.score}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
              const Text(
                'pts',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small rounded pill used inside a history card (e.g. "8/10", "+50 XP").
class _MiniChip extends StatelessWidget {
  final String text;
  final Color accent;

  const _MiniChip({required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}

/// Round stat tile used in the history stats strip.
class _HistoryStat extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color accent;

  const _HistoryStat({
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
        border: Border.all(color: accent.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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