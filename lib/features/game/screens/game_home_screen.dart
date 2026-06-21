import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/game/game_provider.dart';
import '../../../providers/game/xp_provider.dart';
import '../../../providers/game/coin_provider.dart';
import '../../../providers/game/streak_provider.dart';
import '../../../providers/game/statistics_provider.dart';
import 'mode_selection_screen.dart';
import 'leaderboard_screen.dart';
import 'statistics_screen.dart';
import 'achievements_screen.dart';
import 'settings_screen.dart';
import 'daily_challenge_screen.dart';
import 'boss_battle_screen.dart';

class GameHomeScreen extends ConsumerWidget {
  const GameHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xpState = ref.watch(xpProvider);
    final coinState = ref.watch(coinProvider);
    final streakState = ref.watch(streakProvider);
    final statsState = ref.watch(statisticsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tense Mastery', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Player Stats Card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppColors.primaryGradient),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Level ${xpState.currentLevel}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          Text(xpState.levelTitle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                      Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                              const SizedBox(width: 4),
                              Text('${coinState.currentCoins}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(streakState.emoji, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 4),
                              Text('${streakState.currentStreak}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: xpState.levelProgress,
                      backgroundColor: Colors.white30,
                      color: Colors.white,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${xpState.currentXP} / ${xpState.xpForNextLevel} XP', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Quick Stats ──
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.quiz,
                    label: 'Games Played',
                    value: '${statsState.totalGamesPlayed}',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.trending_up,
                    label: 'Accuracy',
                    value: '${(statsState.overallAccuracy * 100).toStringAsFixed(1)}%',
                    color: AppColors.success,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Game Modes ──
            Text('Game Modes', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _ModeCard(
                  title: 'Practice',
                  subtitle: 'Learn at your pace',
                  icon: Icons.school,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModeSelectionScreen())),
                ),
                _ModeCard(
                  title: 'Daily Challenge',
                  subtitle: 'New questions daily',
                  icon: Icons.today,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyChallengeScreen())),
                ),
                _ModeCard(
                  title: 'Boss Battle',
                  subtitle: 'Ultimate test',
                  icon: Icons.emoji_events,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BossBattleScreen())),
                ),
                _ModeCard(
                  title: 'Leaderboard',
                  subtitle: 'Compete globally',
                  icon: Icons.leaderboard,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── More Options ──
            Text('More', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ListTile(
                  icon: Icons.bar_chart,
                  title: 'Statistics',
                  subtitle: 'View your progress',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsScreen())),
                ),
                _ListTile(
                  icon: Icons.emoji_events,
                  title: 'Achievements',
                  subtitle: '${statsState.totalEarnedXP} XP earned',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

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
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color)),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeCard({required this.title, required this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: AppColors.primaryGradient),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ListTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}