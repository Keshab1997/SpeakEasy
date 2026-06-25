import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/game/leaderboard_provider.dart';
import '../../../repositories/leaderboard_repository.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<LeaderboardType>(
            icon: const Icon(Icons.filter_list),
            onSelected: (type) {
              switch (type) {
                case LeaderboardType.global:
                  ref
                      .read(leaderboardProvider.notifier)
                      .loadGlobalLeaderboard();
                case LeaderboardType.weekly:
                  ref
                      .read(leaderboardProvider.notifier)
                      .loadWeeklyLeaderboard();
                case LeaderboardType.daily:
                  ref
                      .read(leaderboardProvider.notifier)
                      .loadDailyLeaderboard();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: LeaderboardType.global, child: Text('Global')),
              const PopupMenuItem(
                  value: LeaderboardType.weekly, child: Text('Weekly')),
              const PopupMenuItem(
                  value: LeaderboardType.daily, child: Text('Daily')),
            ],
          ),
        ],
      ),
      body: ref.watch(leaderboardProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (leaderboardState) => leaderboardState.entries.isEmpty
            ? const Center(
                child: Text('No leaderboard data available'))
            : Column(
                children: [
                  // Top 3 Podium
                  if (leaderboardState.entries.length >= 3)
                    _Podium(
                        entries: leaderboardState.entries
                            .take(3)
                            .toList()),

                  if (leaderboardState.entries.length >= 3)
                    const SizedBox(height: 20),

                  // Rest of the list
                  if (leaderboardState.entries.length > 3)
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: leaderboardState.entries.length - 3,
                        itemBuilder: (context, index) {
                          final entry =
                              leaderboardState.entries[index + 3];
                          return _LeaderboardTile(
                            rank: entry.rank,
                            userName: entry.userName,
                            score: entry.score,
                            xp: entry.xp,
                            level: entry.level,
                          );
                        },
                      ),
                    ),
                  
                  // If less than 3 entries, show them in a list
                  if (leaderboardState.entries.length > 0 && leaderboardState.entries.length < 3)
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: leaderboardState.entries.length,
                        itemBuilder: (context, index) {
                          final entry = leaderboardState.entries[index];
                          return _LeaderboardTile(
                            rank: entry.rank,
                            userName: entry.userName,
                            score: entry.score,
                            xp: entry.xp,
                            level: entry.level,
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> entries;

  const _Podium({required this.entries});

  @override
  Widget build(BuildContext context) {
    // 2nd, 1st, 3rd order for visual podium
    final ordered = [entries[1], entries[0], entries[2]];

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _PodiumCard(entry: ordered[0], rank: 2, height: 120),
          const SizedBox(width: 12),
          _PodiumCard(entry: ordered[1], rank: 1, height: 150, isFirst: true),
          const SizedBox(width: 12),
          _PodiumCard(entry: ordered[2], rank: 3, height: 100),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final double height;
  final bool isFirst;

  const _PodiumCard({
    required this.entry,
    required this.rank,
    required this.height,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    Color medalColor;
    String medalEmoji;

    switch (rank) {
      case 1:
        medalColor = Colors.amber;
        medalEmoji = '🥇';
        break;
      case 2:
        medalColor = Colors.grey[300]!;
        medalEmoji = '🥈';
        break;
      case 3:
        medalColor = Colors.brown[300]!;
        medalEmoji = '🥉';
        break;
      default:
        medalColor = Colors.grey;
        medalEmoji = '';
    }

    return Column(
      children: [
        Text(medalEmoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [medalColor, medalColor.withOpacity(0.7)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('#$rank',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              CircleAvatar(
                radius: isFirst ? 24 : 20,
                backgroundColor: Colors.white,
                child: Text(entry.userName.isNotEmpty ? entry.userName[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: medalColor, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  entry.userName.isNotEmpty ? entry.userName : 'Anonymous',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Text('Lv.${entry.level}',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 10)),
              Text('${entry.xp} XP',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final String userName;
  final int score;
  final int xp;
  final int level;

  const _LeaderboardTile({
    required this.rank,
    required this.userName,
    required this.score,
    required this.xp,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$rank',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary,
            child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName.isNotEmpty ? userName : 'Anonymous',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text('Level $level', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$xp XP',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.primary)),
              Text('Score: $score', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
