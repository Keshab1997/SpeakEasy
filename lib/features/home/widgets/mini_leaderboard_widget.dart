import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeleton_widget.dart';
import '../../../providers/game/leaderboard_provider.dart';
import '../../../repositories/leaderboard_repository.dart';
import '../../game/screens/leaderboard_screen.dart';

class MiniLeaderboardWidget extends ConsumerWidget {
  const MiniLeaderboardWidget({super.key});

  String _getMedal(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#$rank';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return leaderboardAsync.when(
      loading: () => _buildSkeleton(isDark),
      error: (_, __) => const SizedBox.shrink(),
      data: (state) {
        if (state.entries.isEmpty) return const SizedBox.shrink();

        final top3 = state.entries.take(3).toList();
        final currentUser = state.currentUser;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'LEADERBOARD',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LeaderboardScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'See All',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),

              // Top 3
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: top3.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final user = entry.value;
                    final isFirst = rank == 1;

                    return Expanded(
                      child: Column(
                        children: [
                          // Avatar/Initial
                          Container(
                            width: isFirst ? 48 : 40,
                            height: isFirst ? 48 : 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: isFirst
                                  ? Border.all(color: AppColors.primary, width: 2)
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                user.userName.isNotEmpty
                                    ? user.userName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: isFirst ? 20 : 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _getMedal(rank),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.userName.length > 8
                                ? '${user.userName.substring(0, 8)}...'
                                : user.userName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${user.xp} XP',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Divider(
                  color: isDark ? Colors.white12 : Colors.grey[200],
                  height: 1,
                ),
              ),

              // Current user's rank
              if (currentUser != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '👤',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              'Rank #${currentUser.rank} • ${currentUser.xp} XP',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Level ${currentUser.level}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LeaderboardScreen(),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Icon(
                          Icons.sports_esports_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Play games to earn XP & climb!',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeleton(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonListTile(),
          SkeletonListTile(),
          SkeletonListTile(),
        ],
      ),
    );
  }
}
