import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/game/achievement_model.dart';
import '../../../providers/game/achievement_provider.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(achievementProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (state) => _AchievementsBody(state: state),
      ),
    );
  }
}

class _AchievementsBody extends StatelessWidget {
  final AchievementState state;

  const _AchievementsBody({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Progress Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: AppColors.primaryGradient,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${state.unlockedCount}/${state.totalCount}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold)),
                      const Text('Badges Unlocked',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${(state.progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: state.progress,
                  backgroundColor: Colors.white30,
                  color: Colors.white,
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tabs
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Unlocked'),
                    Tab(text: 'Locked'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _AchievementList(
                          achievements: state.unlockedAchievements,
                          isUnlocked: true),
                      _AchievementList(
                          achievements: state.lockedAchievements,
                          isUnlocked: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AchievementList extends StatelessWidget {
  final List<AchievementModel> achievements;
  final bool isUnlocked;

  const _AchievementList(
      {required this.achievements, required this.isUnlocked});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (achievements.isEmpty) {
      return Center(
        child: Text(
          isUnlocked ? 'No badges unlocked yet' : 'All badges unlocked!',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        return _AchievementCard(
            achievement: achievements[index], isUnlocked: isUnlocked);
      },
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final AchievementModel achievement;
  final bool isUnlocked;

  const _AchievementCard(
      {required this.achievement, required this.isUnlocked});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked ? AppColors.success.withOpacity(0.1) : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked ? AppColors.success : AppColors.borderLight,
          width: isUnlocked ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: isUnlocked
                  ? const LinearGradient(colors: [Colors.amber, Colors.orange])
                  : null,
              color: isUnlocked ? null : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                isUnlocked ? achievement.icon : '🔒',
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isUnlocked ? null : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isUnlocked ? null : Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (achievement.xpReward > 0)
                      _RewardChip(
                          icon: '⚡',
                          label: '${achievement.xpReward} XP',
                          unlocked: isUnlocked),
                    if (achievement.coinReward > 0) ...[
                      const SizedBox(width: 6),
                      _RewardChip(
                          icon: '🪙',
                          label: '${achievement.coinReward}',
                          unlocked: isUnlocked),
                    ],
                  ],
                ),
                if (isUnlocked && achievement.unlockDate != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Unlocked: ${_formatDate(achievement.unlockDate)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          if (isUnlocked)
            const Icon(Icons.check_circle, color: AppColors.success, size: 28),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _RewardChip extends StatelessWidget {
  final String icon;
  final String label;
  final bool unlocked;

  const _RewardChip(
      {required this.icon,
      required this.label,
      required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: unlocked
            ? AppColors.primary.withOpacity(0.12)
            : Colors.grey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$icon $label',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: unlocked ? AppColors.primary : Colors.grey,
        ),
      ),
    );
  }
}
