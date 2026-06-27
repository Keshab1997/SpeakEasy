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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(achievementProvider.notifier).refresh(),
          ),
        ],
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(achievementProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
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
    return SingleChildScrollView(
      child: Column(
        children: [
          // Progress Header with Real-time Stats
          _buildProgressHeader(context, state),

          // Real-time Stats Cards
          _buildRealtimeStatsSection(context, state),

          // Achievement Tabs
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Overview'),
                      Tab(text: 'Unlocked'),
                      Tab(text: 'Locked'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildOverviewTab(context, state),
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
      ),
    );
  }

  Widget _buildProgressHeader(BuildContext context, AchievementState state) {
    return Container(
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
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
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
          const SizedBox(height: 16),
          // Level and XP Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickStat('Level', '${state.currentLevel}', Icons.star),
              _buildQuickStat('XP', '${state.currentXP}', Icons.bolt),
              _buildQuickStat('Coins', '${state.totalCoins}', Icons.monetization_on),
              _buildQuickStat('Streak', '${state.currentStreak}🔥', Icons.local_fire_department),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _buildRealtimeStatsSection(BuildContext context, AchievementState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Live Stats',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'REAL-TIME',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Games Played',
                          '${state.totalGamesPlayed}',
                          Icons.videogame_asset,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Accuracy',
                          '${(state.overallAccuracy * 100).toStringAsFixed(1)}%',
                          Icons.gps_fixed,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Correct',
                  '${state.totalCorrectAnswers}',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Wrong',
                  '${state.totalWrongAnswers}',
                  Icons.cancel,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total XP Earned',
                  '${state.totalEarnedXP}',
                  Icons.star,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Coins Earned',
                  '${state.totalEarnedCoins}',
                  Icons.monetization_on,
                  Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Longest Streak',
                  '${state.longestStreak}',
                  Icons.whatshot,
                  Colors.deepOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Weekly Streak',
                  '${state.weeklyStreak}',
                  Icons.calendar_today,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Boss Wins',
                  '${state.bossWins}',
                  Icons.bug_report,
                  Colors.redAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Daily Wins',
                  '${state.dailyChallengeWins}',
                  Icons.emoji_events,
                  Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Time Played',
            _formatTimePlayed(state.timePlayedSeconds),
            Icons.timer,
            Colors.cyan,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  String _formatTimePlayed(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isFullWidth ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, AchievementState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Player Level Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Player Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildProfileStat('Level', '${state.currentLevel}'),
                    _buildProfileStat('XP', '${state.currentXP}'),
                    _buildProfileStat('Coins', '${state.totalCoins}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Achievement Progress
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Achievement Progress',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${state.unlockedCount} Unlocked'),
                    Text('${state.lockedCount} Locked'),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: state.progress,
                    backgroundColor: Colors.grey[300],
                    color: AppColors.primary,
                    minHeight: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Performance Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Performance Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPerformanceRow('Total Games', '${state.totalGamesPlayed}'),
                _buildPerformanceRow('Correct Answers', '${state.totalCorrectAnswers}'),
                _buildPerformanceRow('Accuracy', '${(state.overallAccuracy * 100).toStringAsFixed(1)}%'),
                _buildPerformanceRow('Current Streak', '${state.currentStreak} days'),
                _buildPerformanceRow('Longest Streak', '${state.longestStreak} days'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUnlocked ? Icons.emoji_events : Icons.lock_open,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isUnlocked ? 'No badges unlocked yet' : 'All badges unlocked!',
              style: theme.textTheme.bodyLarge,
            ),
            if (isUnlocked) ...[
              const SizedBox(height: 8),
              Text(
                'Play games to earn achievements!',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ],
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