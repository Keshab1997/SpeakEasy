import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/game/statistics_provider.dart';
import '../../../providers/game/xp_provider.dart';
import '../../../providers/game/coin_provider.dart';
import '../../../providers/game/streak_provider.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsState = ref.watch(statisticsProvider);
    final xpState = ref.watch(xpProvider);
    final coinState = ref.watch(coinProvider);
    final streakState = ref.watch(streakProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Performance Rating
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppColors.primaryGradient),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text('Performance Rating', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(statsState.performanceRating, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Overall Stats
            Text('Overall Statistics', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _StatCard(label: 'Games Played', value: '${statsState.totalGamesPlayed}', icon: Icons.quiz, color: AppColors.primary),
                _StatCard(label: 'Total Questions', value: '${statsState.totalQuestionsAnswered}', icon: Icons.help_outline, color: AppColors.info),
                _StatCard(label: 'Correct Answers', value: '${statsState.totalCorrectAnswers}', icon: Icons.check_circle, color: AppColors.success),
                _StatCard(label: 'Wrong Answers', value: '${statsState.totalWrongAnswers}', icon: Icons.cancel, color: AppColors.error),
                _StatCard(label: 'Accuracy', value: '${(statsState.overallAccuracy * 100).toStringAsFixed(1)}%', icon: Icons.pie_chart, color: AppColors.warning),
                _StatCard(label: 'Best Score', value: '${statsState.highestScore}', icon: Icons.emoji_events, color: Colors.amber),
              ],
            ),

            const SizedBox(height: 24),

            // Rewards Stats
            Text('Rewards', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total XP',
                    value: '${statsState.totalEarnedXP}',
                    icon: Icons.star,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Total Coins',
                    value: '${statsState.totalEarnedCoins}',
                    icon: Icons.monetization_on,
                    color: Colors.amberAccent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Current Status
            Text('Current Status', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  _StatusRow(label: 'Current Level', value: '${xpState.currentLevel} - ${xpState.levelTitle}'),
                  const Divider(),
                  _StatusRow(label: 'Current XP', value: '${xpState.currentXP} / ${xpState.xpForNextLevel}'),
                  const Divider(),
                  _StatusRow(label: 'Level Progress', value: '${(xpState.levelProgress * 100).toStringAsFixed(1)}%'),
                  const Divider(),
                  _StatusRow(label: 'Current Coins', value: '${coinState.currentCoins}'),
                  const Divider(),
                  _StatusRow(label: 'Current Streak', value: '${streakState.currentStreak} days ${streakState.emoji}'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Streak Stats
            Text('Streak', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('${streakState.currentStreak}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      const Text('Current', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('${streakState.bestStreak}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      const Text('Best', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  Column(
                    children: [
                      Text(streakState.emoji, style: const TextStyle(fontSize: 32)),
                      const Text('Status', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color)),
          Text(label, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}