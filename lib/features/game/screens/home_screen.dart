import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/game/xp_provider.dart';
import '../../../providers/game/coin_provider.dart';
import '../../../providers/game/streak_provider.dart';
import '../../../providers/game/achievement_provider.dart';
import '../../../providers/game/statistics_provider.dart';
import '../../../providers/game/sound_provider.dart';
import '../../../providers/game/game_provider.dart';
import '../../../providers/theme_provider.dart';
import 'mode_selection_screen.dart';
import 'daily_challenge_screen.dart';
import 'leaderboard_screen.dart';
import 'statistics_screen.dart';
import 'achievements_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final xpState = ref.watch(xpProvider);
    final coinState = ref.watch(coinProvider);
    final streakState = ref.watch(streakProvider);
    final achievementState = ref.watch(achievementProvider);
    final statsState = ref.watch(statisticsProvider);
    final themeState = ref.watch(themeProvider);
    final theme = Theme.of(context);

    // Set system UI overlay style based on theme
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: themeState.isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: themeState.isDark
                ? [AppColors.backgroundDark, AppColors.surfaceDark]
                : [AppColors.primary.withOpacity(0.05), Colors.white],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    expandedHeight: 120,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    flexibleSpace: FlexibleSpaceBar(
                      title: const Text(
                        'Tense Mastery',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                      ),
                      centerTitle: false,
                      titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                    ),
                    actions: [
                      IconButton(
                        icon: Icon(themeState.isDark ? Icons.light_mode : Icons.dark_mode),
                        onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () {
                          ref.read(soundProvider.notifier).playButtonTap();
                          // Navigate to settings
                        },
                      ),
                    ],
                  ),

                  // Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Player Stats Card
                          _PlayerStatsCard(
                            level: xpState.currentLevel,
                            levelTitle: xpState.levelTitle,
                            xp: xpState.currentXP,
                            xpForNextLevel: xpState.xpForNextLevel,
                            levelProgress: xpState.levelProgress,
                            coins: coinState.currentCoins,
                            streak: streakState.currentStreak,
                            streakEmoji: streakState.emoji,
                          ),

                          const SizedBox(height: 32),

                          // Continue Playing Section
                          if (statsState.totalGamesPlayed > 0) ...[
                            _SectionHeader(
                              title: 'Continue Playing',
                              action: TextButton(
                                onPressed: () {
                                  ref.read(soundProvider.notifier).playButtonTap();
                                  // Continue last game
                                },
                                child: const Text('Resume'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ContinuePlayingCard(
                              lastPlayed: 'Today',
                              progress: 0.6,
                              onTap: () {
                                ref.read(soundProvider.notifier).playButtonTap();
                                ref.read(gameProvider.notifier).loadQuestions(limit: 10);
                                // Navigate to question screen
                              },
                            ),
                            const SizedBox(height: 32),
                          ],

                          // Daily Challenge Section
                          _SectionHeader(
                            title: 'Daily Challenge',
                            action: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [Colors.amber, Colors.orange]),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(streakState.emoji, style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 4),
                                  const Text(
                                    '+50% Bonus',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _DailyChallengeCard(
                            questions: 15,
                            difficulty: 'Intermediate',
                            onTap: () {
                              ref.read(soundProvider.notifier).playButtonTap();
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DailyChallengeScreen()),
                              );
                            },
                          ),

                          const SizedBox(height: 32),

                          // Current Level & XP Progress
                          _SectionHeader(title: 'Current Level'),
                          const SizedBox(height: 12),
                          _LevelProgressCard(
                            level: xpState.currentLevel,
                            title: xpState.levelTitle,
                            progress: xpState.levelProgress,
                            currentXP: xpState.currentXP,
                            nextLevelXP: xpState.xpForNextLevel,
                          ),

                          const SizedBox(height: 32),

                          // Streak Section
                          _SectionHeader(title: 'Streak'),
                          const SizedBox(height: 12),
                          _StreakCard(
                            streak: streakState.currentStreak,
                            emoji: streakState.emoji,
                            flameCount: streakState.flameCount,
                          ),

                          const SizedBox(height: 32),

                          // Achievements Preview
                          _SectionHeader(
                            title: 'Achievements',
                            action: TextButton(
                              onPressed: () {
                                ref.read(soundProvider.notifier).playButtonTap();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                                );
                              },
                              child: const Text('View All'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (achievementState.value != null)
                            _AchievementsPreview(
                              unlocked: achievementState.value!.unlockedCount,
                              total: achievementState.value!.totalCount,
                              progress: achievementState.value!.progress,
                            ),

                          const SizedBox(height: 32),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: _ActionButton(
                                  label: 'Play Now',
                                  icon: Icons.play_arrow,
                                  gradient: AppColors.primaryGradient,
                                  onTap: () {
                                    ref.read(soundProvider.notifier).playButtonTap();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ActionButton(
                                  label: 'Leaderboard',
                                  icon: Icons.leaderboard,
                                  gradient: [Colors.purple, Colors.deepPurple],
                                  onTap: () {
                                    ref.read(soundProvider.notifier).playButtonTap();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: _ActionButton(
                              label: 'Statistics',
                              icon: Icons.bar_chart,
                              gradient: [Colors.teal, Colors.cyan],
                              onTap: () {
                                ref.read(soundProvider.notifier).playButtonTap();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerStatsCard extends StatelessWidget {
  final int level;
  final String levelTitle;
  final int xp;
  final int xpForNextLevel;
  final double levelProgress;
  final int coins;
  final int streak;
  final String streakEmoji;

  const _PlayerStatsCard({
    required this.level,
    required this.levelTitle,
    required this.xp,
    required this.xpForNextLevel,
    required this.levelProgress,
    required this.coins,
    required this.streak,
    required this.streakEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.primaryGradient),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level $level',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      levelTitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
                      const SizedBox(width: 4),
                      Text(
                        '$coins',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(streakEmoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 4),
                      Text(
                        '$streak',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: levelProgress,
              backgroundColor: Colors.white30,
              color: Colors.white,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$xp / $xpForNextLevel XP',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _ContinuePlayingCard extends StatelessWidget {
  final String lastPlayed;
  final double progress;
  final VoidCallback onTap;

  const _ContinuePlayingCard({
    required this.lastPlayed,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.blue, Colors.lightBlue]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Practice Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last played: $lastPlayed',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white30,
                      color: Colors.white,
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}

class _DailyChallengeCard extends StatelessWidget {
  final int questions;
  final String difficulty;
  final VoidCallback onTap;

  const _DailyChallengeCard({
    required this.questions,
    required this.difficulty,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.amber, Colors.orange]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.today, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today\'s Challenge',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$questions questions • $difficulty',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '+50% XP',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelProgressCard extends StatelessWidget {
  final int level;
  final String title;
  final double progress;
  final int currentXP;
  final int nextLevelXP;

  const _LevelProgressCard({
    required this.level,
    required this.title,
    required this.progress,
    required this.currentXP,
    required this.nextLevelXP,
  });

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level $level',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: AppColors.primaryGradient),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              color: AppColors.primary,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$currentXP / $nextLevelXP XP to next level',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;
  final String emoji;
  final int flameCount;

  const _StreakCard({
    required this.streak,
    required this.emoji,
    required this.flameCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
              Text(
                emoji * flameCount,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text(
                '$streak days',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Current Streak',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 60,
            color: Colors.white30,
          ),
          Column(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              Text(
                '$flameCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Flame Level',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementsPreview extends StatelessWidget {
  final int unlocked;
  final int total;
  final double progress;

  const _AchievementsPreview({
    required this.unlocked,
    required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        // Navigate to achievements
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.amber, Colors.orange]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.emoji_events, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$unlocked / $total',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Achievements Unlocked',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      color: AppColors.primary,
                      minHeight: 4,
                    ),
                  ),
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

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}