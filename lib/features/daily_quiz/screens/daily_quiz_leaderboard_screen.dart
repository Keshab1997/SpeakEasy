import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeleton_widget.dart';
import '../providers/daily_quiz_provider.dart';
import '../services/daily_quiz_leaderboard_service.dart';

/// Full daily-quiz leaderboard screen.
///
/// Fetches and displays today's top entries from Firestore.
class DailyQuizLeaderboardScreen extends ConsumerStatefulWidget {
  const DailyQuizLeaderboardScreen({super.key});

  @override
  ConsumerState<DailyQuizLeaderboardScreen> createState() =>
      _DailyQuizLeaderboardScreenState();
}

class _DailyQuizLeaderboardScreenState
    extends ConsumerState<DailyQuizLeaderboardScreen> {
  final _service = DailyQuizLeaderboardService();
  List<DailyQuizLeaderboardEntry> _entries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final entries = await _service.fetchTopEntries(dateStr, limit: 50);
      if (mounted) {
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Daily Quiz Leaderboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(theme, isDark),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        itemBuilder: (_, __) => const SkeletonListTile(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Could not load leaderboard',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadLeaderboard,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            Text(
              'No entries yet today',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete the Daily Quiz to appear here!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    // Top-3 podium
    final hasPodium = _entries.length >= 3;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        if (hasPodium) _buildPodium(theme),
        if (hasPodium) const SizedBox(height: 24),
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              const SizedBox(width: 36),
              const Expanded(
                child: Text('Name',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        fontSize: 12))),
              SizedBox(
                width: 50,
                child: Text('Score',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        fontSize: 12))),
              SizedBox(
                width: 50,
                child: Text('Time',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        fontSize: 12))),
              SizedBox(
                width: 50,
                child: Text('Correct',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        fontSize: 12))),
            ],
          ),
        ),
        const Divider(),
        // Entries list
        ..._entries.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final e = entry.value;
          final minutes = e.totalTime ~/ 60;
          final seconds = e.totalTime % 60;
          final timeStr =
              minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';

          final isTop3 = rank <= 3;
          final rankColor =
              rank == 1
                  ? Colors.amber
                  : rank == 2
                      ? Colors.grey.shade400
                      : rank == 3
                          ? Colors.brown.shade300
                          : Colors.grey;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                // Rank
                SizedBox(
                  width: 36,
                  child: isTop3
                      ? Icon(Icons.emoji_events, color: rankColor, size: 20)
                      : Text(
                          '#$rank',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                ),
                Expanded(
                  child: Text(
                    e.userName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isTop3 ? FontWeight.w700 : FontWeight.w500,
                      color: isTop3
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${e.score}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isTop3 ? rankColor : null,
                    ),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    timeStr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${e.correctCount}/10',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPodium(ThemeData theme) {
    final first = _entries[0];
    final second = _entries[1];
    final third = _entries[2];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // 1st place (center, tallest)
          _PodiumTile(
            rank: 1,
            userName: first.userName,
            photoUrl: first.photoUrl,
            score: first.score,
            correctCount: first.correctCount,
            color: Colors.amber,
            height: 120,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd place
              Expanded(
                child: _PodiumTile(
                  rank: 2,
                  userName: second.userName,
                  photoUrl: second.photoUrl,
                  score: second.score,
                  correctCount: second.correctCount,
                  color: Colors.grey.shade400,
                  height: 90,
                ),
              ),
              const SizedBox(width: 12),
              // 3rd place
              Expanded(
                child: _PodiumTile(
                  rank: 3,
                  userName: third.userName,
                  photoUrl: third.photoUrl,
                  score: third.score,
                  correctCount: third.correctCount,
                  color: Colors.brown.shade300,
                  height: 70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PodiumTile extends StatelessWidget {
  final int rank;
  final String userName;
  final String? photoUrl;
  final int score;
  final int correctCount;
  final Color color;
  final double height;

  const _PodiumTile({
    required this.rank,
    required this.userName,
    this.photoUrl,
    required this.score,
    required this.correctCount,
    required this.color,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final avatarRadius = rank == 1 ? 26.0 : 20.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: color.withOpacity(0.2),
            backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
            child: hasPhoto
                ? null
                : Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: avatarRadius * 0.8,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            '#$rank',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            userName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text(
            '$score pts · $correctCount/10',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
