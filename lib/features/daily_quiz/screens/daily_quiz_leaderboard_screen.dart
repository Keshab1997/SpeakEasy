import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeleton_widget.dart';
import '../../../providers/auth_provider.dart';
import '../providers/daily_quiz_provider.dart';
import '../services/daily_quiz_leaderboard_service.dart';

/// Full daily-quiz leaderboard screen.
///
/// Fetches and displays today's top entries from Firestore in a playful,
/// Duolingo-style podium + standings layout.
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

  /// Colors used for rank 1 / 2 / 3 (gold, silver, bronze).
  static const _gold = Color(0xFFF59E0B);
  static const _silver = Color(0xFF9CA3AF);
  static const _bronze = Color(0xFFB45309);

  static const medals = ['🥇', '🥈', '🥉'];

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
    final currentUserId = ref.watch(authProvider).asData?.value?.id;

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
              Expanded(
                child: _buildBody(context, theme, isDark, currentUserId),
              ),
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
              'Leaderboard',
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
              color: _gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '🏆 Today',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _gold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    String? currentUserId,
  ) {
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
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.cloud_off, size: 36, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Text(
                'Could not load leaderboard',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.accentGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🏆', style: TextStyle(fontSize: 44)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No entries yet today',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.onBackgroundDark
                      : AppColors.onBackgroundLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete the Daily Quiz to appear here!',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Top-3 podium
    final hasPodium = _entries.length >= 3;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (hasPodium) ...[
          _buildPodium(theme),
          const SizedBox(height: 24),
        ],
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Text(
                'All Standings',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${_entries.length} players',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ..._entries.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          return _LeaderboardRow(
            entry: entry.value,
            rank: rank,
            isYou: currentUserId != null && entry.value.userId == currentUserId,
            isDark: isDark,
          );
        }),
      ],
    );
  }

  Widget _buildPodium(ThemeData theme) {
    final first = _entries[0];
    final second = _entries[1];
    final third = _entries[2];
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;

    return Column(
      children: [
        // 1st place (center, tallest) — champion card
        _PodiumTile(
          rank: 1,
          userName: first.userName,
          photoUrl: first.photoUrl,
          score: first.score,
          isChampion: true,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _PodiumCard(
                rank: 2,
                userName: second.userName,
                photoUrl: second.photoUrl,
                score: second.score,
                gradientColors: const [Color(0xFFE2E8F0), Color(0xFF94A3B8)],
                cardColor: cardBg,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PodiumCard(
                rank: 3,
                userName: third.userName,
                photoUrl: third.photoUrl,
                score: third.score,
                gradientColors: const [Color(0xFFE2A87F), Color(0xFFB45309)],
                cardColor: cardBg,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Full-width gold podium card for the 1st-place winner.
class _PodiumTile extends StatelessWidget {
  final int rank;
  final String userName;
  final String? photoUrl;
  final int score;
  final bool isChampion;

  const _PodiumTile({
    required this.rank,
    required this.userName,
    this.photoUrl,
    required this.score,
    this.isChampion = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _DailyQuizLeaderboardScreenState._gold.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -24,
            right: -16,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.6),
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
                  child: hasPhoto
                      ? null
                      : Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('👑 CHAMPION',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#$rank · $score pts',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact silver/bronze podium card for 2nd and 3rd place.
class _PodiumCard extends StatelessWidget {
  final int rank;
  final String userName;
  final String? photoUrl;
  final int score;
  final List<Color> gradientColors;
  final Color cardColor;

  const _PodiumCard({
    required this.rank,
    required this.userName,
    this.photoUrl,
    required this.score,
    required this.gradientColors,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            _DailyQuizLeaderboardScreenState.medals[rank - 1],
            style: const TextStyle(fontSize: 26),
          ),
          const SizedBox(height: 8),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withOpacity(0.4),
            backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
            child: hasPhoto
                ? null
                : Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '$score pts',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single standings row — rank badge, avatar, name (+YOU tag) and score.
class _LeaderboardRow extends StatelessWidget {
  final DailyQuizLeaderboardEntry entry;
  final int rank;
  final bool isYou;
  final bool isDark;

  const _LeaderboardRow({
    required this.entry,
    required this.rank,
    required this.isYou,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final hasPhoto = entry.photoUrl != null && entry.photoUrl!.isNotEmpty;
    final minutes = entry.totalTime ~/ 60;
    final seconds = entry.totalTime % 60;
    final timeStr = minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';

    final accent = isTop3
        ? [
            _DailyQuizLeaderboardScreenState._gold,
            _DailyQuizLeaderboardScreenState._silver,
            _DailyQuizLeaderboardScreenState._bronze,
          ][rank - 1]
        : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isYou
            ? AppColors.primary.withOpacity(0.08)
            : (isDark ? AppColors.surfaceDark : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isYou
              ? AppColors.primary
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: isYou ? 1.5 : 1,
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
        children: [
          // Rank badge
          SizedBox(
            width: 34,
            child: isTop3
                ? Text(
                    _DailyQuizLeaderboardScreenState.medals[rank - 1],
                    style: const TextStyle(fontSize: 20),
                  )
                : Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          // Avatar
          CircleAvatar(
            radius: 15,
            backgroundColor: accent.withOpacity(0.15),
            backgroundImage: hasPhoto ? NetworkImage(entry.photoUrl!) : null,
            child: hasPhoto
                ? null
                : Text(
                    entry.userName.isNotEmpty
                        ? entry.userName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.userName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isTop3 ? FontWeight.w800 : FontWeight.w600,
                          color: isDark
                              ? (isYou ? Colors.white : Colors.white70)
                              : (isYou ? Colors.black87 : Colors.black87),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isYou) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$timeStr · ${entry.correctCount}/10 correct',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.score}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isYou ? AppColors.primary : accent,
                ),
              ),
              Text(
                'pts',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
