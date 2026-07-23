import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeleton_widget.dart';
import '../../../providers/game/leaderboard_provider.dart';
import '../../../repositories/leaderboard_repository.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        loading: () => ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 8,
          itemBuilder: (_, __) => const SkeletonListTile(),
        ),
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
                            photoUrl: entry.photoUrl,
                          );
                        },
                      ),
                    ),
                  
                  // If less than 3 entries, show them in a list
                  if (leaderboardState.entries.isNotEmpty && leaderboardState.entries.length < 3)
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
                            photoUrl: entry.photoUrl,
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
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _PodiumCard(entry: ordered[0], rank: 2, standHeight: 100),
          const SizedBox(width: 8),
          _PodiumCard(entry: ordered[1], rank: 1, standHeight: 140, isFirst: true),
          const SizedBox(width: 8),
          _PodiumCard(entry: ordered[2], rank: 3, standHeight: 80),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final double standHeight;
  final bool isFirst;

  const _PodiumCard({
    required this.entry,
    required this.rank,
    required this.standHeight,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color medalColor;
    String medalEmoji;
    String crown = '';

    switch (rank) {
      case 1:
        medalColor = Colors.amber;
        medalEmoji = '🥇';
        crown = '👑';
        break;
      case 2:
        medalColor = const Color(0xFFA0A0A0);
        medalEmoji = '🥈';
        break;
      case 3:
        medalColor = const Color(0xFFCD7F32);
        medalEmoji = '🥉';
        break;
      default:
        medalColor = Colors.grey;
        medalEmoji = '';
    }

    return SizedBox(
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crown for rank 1
          if (isFirst)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, -8 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: Text(crown, style: const TextStyle(fontSize: 28)),
                    ),
                  );
                },
              ),
            ),

          // Medal
          Text(medalEmoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 6),

          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: medalColor, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: medalColor.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              backgroundImage: entry.photoUrl.trim().isNotEmpty
                  ? CachedNetworkImageProvider(entry.photoUrl)
                  : null,
              child: entry.photoUrl.trim().isEmpty
                  ? Text(
                      entry.userName.isNotEmpty
                          ? entry.userName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: medalColor, fontWeight: FontWeight.bold, fontSize: 18),
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 6),

          // Name
          SizedBox(
            width: 76,
            child: Text(
              entry.userName.isNotEmpty ? entry.userName : 'Anonymous',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 2),

          // Level & XP
          Text(
            'Lv.${entry.level} • ${entry.xp} XP',
            style: TextStyle(
              color: medalColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Podium Stand
          Container(
            width: 72,
            height: standHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  medalColor,
                  medalColor.withOpacity(0.6),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  color: medalColor.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 4),
                    // Trophy icon
                    Icon(
                      rank == 1 ? Icons.emoji_events : Icons.star,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      rank == 1 ? 'ST' : rank == 2 ? 'ND' : 'RD',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Podium base
          Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  medalColor.withOpacity(0.4),
                  medalColor.withOpacity(0.6),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final String userName;
  final int score;
  final int xp;
  final int level;
  final String photoUrl;

  const _LeaderboardTile({
    required this.rank,
    required this.userName,
    required this.score,
    required this.xp,
    required this.level,
    this.photoUrl = '',
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
          // Rank circle
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
          // Profile picture with fallback to initial letter
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary,
            backgroundImage: photoUrl.trim().isNotEmpty
                ? CachedNetworkImageProvider(photoUrl)
                : null,
            child: photoUrl.trim().isEmpty
                ? Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  )
                : null,
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
