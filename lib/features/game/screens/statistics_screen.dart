import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/game/statistics_provider.dart';
import '../../../providers/game/xp_provider.dart';
import '../../../providers/game/coin_provider.dart';
import '../../../providers/game/streak_provider.dart';

/// Phase 18 Statistics screen.
///
/// Aggregates the persistent counters maintained by
/// [StatisticsService] and renders them as a structured dashboard:
/// performance rating, headline numbers, rewards, Phase-18 win /
/// streak / time counters, today's progress, and a "current status"
/// section that mirrors the live progress providers.
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh all providers so the screen shows the latest data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(statisticsProvider.notifier).refresh();
      ref.read(xpProvider.notifier).refresh();
      ref.read(coinProvider.notifier).refresh();
      ref.read(streakProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statisticsProvider);
    final xpState = ref.watch(xpProvider);
    final streakState = ref.watch(streakProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Statistics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(statisticsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(statisticsProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PerformanceBanner(rating: stats.performanceRating),
              const SizedBox(height: 24),

              const _SectionHeader(
                title: 'Overall Statistics',
                icon: Icons.bar_chart,
              ),
              const SizedBox(height: 12),
              _StatsGrid(
                tiles: [
                  _StatTileData(
                    label: 'Games Played',
                    value: '${stats.totalGamesPlayed}',
                    icon: Icons.sports_esports,
                    color: AppColors.primary,
                  ),
                  _StatTileData(
                    label: 'Correct',
                    value: '${stats.totalCorrectAnswers}',
                    icon: Icons.check_circle,
                    color: AppColors.success,
                  ),
                  _StatTileData(
                    label: 'Wrong',
                    value: '${stats.totalWrongAnswers}',
                    icon: Icons.cancel,
                    color: AppColors.error,
                  ),
                  _StatTileData(
                    label: 'Accuracy',
                    value:
                        '${(stats.overallAccuracy * 100).toStringAsFixed(1)}%',
                    icon: Icons.pie_chart,
                    color: AppColors.warning,
                  ),
                  _StatTileData(
                    label: 'Best Score',
                    value: '${stats.highestScore}',
                    icon: Icons.emoji_events,
                    color: Colors.amber,
                  ),
                  _StatTileData(
                    label: 'Avg Score',
                    value: stats.averageScore.toStringAsFixed(1),
                    icon: Icons.analytics,
                    color: AppColors.info,
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const _SectionHeader(
                title: 'Rewards',
                icon: Icons.workspace_premium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _GradientStatCard(
                      label: 'Total XP',
                      value: '${stats.totalEarnedXP}',
                      icon: Icons.star,
                      gradient: AppColors.accentGradient,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GradientStatCard(
                      label: 'Total Coins',
                      value: '${stats.totalEarnedCoins}',
                      icon: Icons.monetization_on,
                      gradient: AppColors.secondaryGradient,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const _SectionHeader(
                title: 'Special Wins',
                icon: Icons.military_tech,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _GradientStatCard(
                      label: 'Boss Wins',
                      value: '${stats.bossWins}',
                      icon: Icons.shield,
                      gradient: const [
                        Color(0xFFEF4444),
                        Color(0xFFB91C1C),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GradientStatCard(
                      label: 'Daily Wins',
                      value: '${stats.dailyChallengeWins}',
                      icon: Icons.flash_on,
                      gradient: AppColors.purpleGradient,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const _SectionHeader(
                title: 'Streaks',
                icon: Icons.local_fire_department,
              ),
              const SizedBox(height: 12),
              _StreakCard(
                current: streakState.currentStreak,
                best: stats.bestStreak,
                emoji: streakState.emoji,
              ),

              const SizedBox(height: 24),
              const _SectionHeader(
                title: 'Time Played',
                icon: Icons.timer,
              ),
              const SizedBox(height: 12),
              _TimePlayedCard(
                totalSeconds: stats.timePlayedSeconds,
                formatted: stats.timePlayedFormatted,
              ),

              const SizedBox(height: 24),
              const _SectionHeader(
                title: 'Current Status',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              _StatusCard(
                rows: [
                  _StatusRowData(
                    label: 'Current Level',
                    value:
                        '${stats.currentLevel} - ${xpState.levelTitle}',
                  ),
                  _StatusRowData(
                    label: 'Total XP Earned',
                    value:
                        '${stats.totalEarnedXP} XP',
                  ),
                  _StatusRowData(
                    label: 'Coins Balance',
                    value: '${stats.totalEarnedCoins}',
                  ),
                  _StatusRowData(
                    label: 'Current Streak',
                    value:
                        '${stats.currentStreak} days ${streakState.emoji}',
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const _SectionHeader(
                title: 'Recent Form',
                icon: Icons.history,
              ),
              const SizedBox(height: 12),
              _RecentFormCard(
                bestScore: stats.highestScore,
                averageScore: stats.averageScore,
                accuracy:
                    (stats.overallAccuracy * 100).toStringAsFixed(1),
                rating: stats.performanceRating,
              ),

              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Keep playing to grow your stats!',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section pieces ──

class _PerformanceBanner extends StatelessWidget {
  final String rating;
  const _PerformanceBanner({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.primaryGradient),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Rating',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            rating,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Based on overall accuracy',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _StatTileData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTileData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _StatsGrid extends StatelessWidget {
  final List<_StatTileData> tiles;
  const _StatsGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    // Layout as row-pairs wrapped in IntrinsicHeight so each pair
    // sizes to its tallest tile. This avoids the fixed-aspect-ratio
    // overflow that a 2-column GridView hits on narrow phones.
    final rows = <Widget>[];
    for (int i = 0; i < tiles.length; i += 2) {
      final left = tiles[i];
      final right = (i + 1 < tiles.length) ? tiles[i + 1] : null;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _StatCard(data: left)),
              if (right != null) ...[
                const SizedBox(width: 12),
                Expanded(child: _StatCard(data: right)),
              ],
            ],
          ),
        ),
      );
      if (i + 2 < tiles.length) {
        rows.add(const SizedBox(height: 12));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

class _StatCard extends StatelessWidget {
  final _StatTileData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(data.icon, color: data.color, size: 22),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              data.value,
              maxLines: 1,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: data.color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _GradientStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;
  const _GradientStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int current;
  final int best;
  final String emoji;
  const _StreakCard({
    required this.current,
    required this.best,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.deepOrange],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StreakColumn(value: '$current', label: 'Current'),
          _StreakColumn(value: '$best', label: 'Best'),
          _StreakColumn(value: emoji, label: 'Status', isEmoji: true),
        ],
      ),
    );
  }
}

class _StreakColumn extends StatelessWidget {
  final String value;
  final String label;
  final bool isEmoji;
  const _StreakColumn({
    required this.value,
    required this.label,
    this.isEmoji = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: isEmoji ? 32 : 32,
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

class _TimePlayedCard extends StatelessWidget {
  final int totalSeconds;
  final String formatted;
  const _TimePlayedCard({
    required this.totalSeconds,
    required this.formatted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.timer,
              color: AppColors.info,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatted,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$hours h · $minutes m · $seconds s total',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRowData {
  final String label;
  final String value;
  const _StatusRowData({required this.label, required this.value});
}

class _StatusCard extends StatelessWidget {
  final List<_StatusRowData> rows;
  const _StatusCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _StatusRow(label: rows[i].label, value: rows[i].value),
            if (i < rows.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentFormCard extends StatelessWidget {
  final int bestScore;
  final double averageScore;
  final String accuracy;
  final String rating;
  const _RecentFormCard({
    required this.bestScore,
    required this.averageScore,
    required this.accuracy,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.infoGradient),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Snapshot',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            rating,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniMetric(label: 'Best', value: '$bestScore'),
              _MiniMetric(
                label: 'Avg',
                value: averageScore.toStringAsFixed(1),
              ),
              _MiniMetric(label: 'Accuracy', value: '$accuracy%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 2),
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
