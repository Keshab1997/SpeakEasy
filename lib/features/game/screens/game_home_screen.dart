import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/game/xp_provider.dart';
import '../../../providers/game/coin_provider.dart';
import '../../../providers/game/streak_provider.dart';
import '../../../providers/game/statistics_provider.dart';
import '../../../providers/game/achievement_provider.dart';
import 'mode_selection_screen.dart';
import 'leaderboard_screen.dart';
import 'statistics_screen.dart';
import 'achievements_screen.dart';
import 'daily_challenge_screen.dart';
import 'boss_battle_screen.dart';
import 'modes/word_match_mode.dart';
import 'modes/quick_quiz_mode.dart';
import 'modes/fill_in_blanks_mode.dart';
import 'modes/sentence_builder_mode.dart';
import 'modes/grammar_detective_mode.dart';
import 'modes/bangla_to_english_mode.dart';
import 'modes/flashcard_mode.dart';
import 'modes/story_completion_mode.dart';
import 'modes/verb_learning_mode.dart';

class GameHomeScreen extends ConsumerStatefulWidget {
  const GameHomeScreen({super.key});

  @override
  ConsumerState<GameHomeScreen> createState() => _GameHomeScreenState();
}

class _GameHomeScreenState extends ConsumerState<GameHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // Refresh providers so the header shows the latest accumulated values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(xpProvider.notifier).refresh();
      ref.read(coinProvider.notifier).refresh();
      ref.read(streakProvider.notifier).refresh();
      ref.read(statisticsProvider.notifier).refresh();
    });

    // Animation setup
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _buildAchievementsSubtitle() {
    final achievementState = ref.watch(achievementProvider);
    return achievementState.when(
      data: (state) =>
          '${state.unlockedCount}/${state.totalCount} badges unlocked',
      loading: () => 'Loading badges...',
      error: (_, __) => 'View achievements',
    );
  }

  @override
  Widget build(BuildContext context) {
    final xpState = ref.watch(xpProvider);
    final coinState = ref.watch(coinProvider);
    final streakState = ref.watch(streakProvider);
    final statsState = ref.watch(statisticsProvider);
    final theme = Theme.of(context);

    // Use total earned XP/Coins from statistics (the persistent cumulative
    // counters) when the per-box ProgressRepository values are still 0.
    final int displayXP = statsState.totalEarnedXP > 0
        ? statsState.totalEarnedXP
        : xpState.currentXP;
    final int displayCoins = statsState.totalEarnedCoins > 0
        ? statsState.totalEarnedCoins
        : coinState.currentCoins;
    final int displayLevel =
        xpState.currentLevel > 0 ? xpState.currentLevel : 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tense Mastery',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
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
                gradient: const LinearGradient(colors: AppColors.primaryGradient),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Level $displayLevel',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold)),
                          Text(xpState.levelTitle,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                      Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.monetization_on,
                                  color: Colors.amber, size: 20),
                              const SizedBox(width: 4),
                              Text('$displayCoins',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(streakState.emoji,
                                  style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 4),
                              Text('${streakState.currentStreak}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
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
                  Text('$displayXP XP earned',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
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
                    value:
                        '${(statsState.overallAccuracy * 100).toStringAsFixed(1)}%',
                    color: AppColors.success,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Featured Game Section Title ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade400, Colors.orange.shade400],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.stars_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Featured Games',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Enhanced Featured Games Grid ──
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    _EnhancedGameCard(
                      title: 'Word Match',
                      description: 'Match বাংলা → English pairs',
                      details: '6 rounds • Score + Streak bonus',
                      icon: Icons.compare_arrows_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      badge: 'HOT',
                      badgeColor: Colors.deepOrange,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const WordMatchModeScreen()),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _EnhancedGameCard(
                      title: 'Quick Quiz',
                      description: 'বাংলা দেখে correct English বেছে নিন',
                      details: '5 sec timer • Fast-paced challenge',
                      icon: Icons.bolt_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFf093fb), Color(0xFFF5576C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      badge: 'NEW',
                      badgeColor: Colors.green,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const QuickQuizModeScreen()),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _EnhancedGameCard(
                      title: 'Verb Learning',
                      description: 'Verb forms, Bangla meaning & example sentences',
                      details: 'V1-V5 • Explanation • Quick Quiz',
                      icon: Icons.directions_run_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF58CC02), Color(0xFF3DA302)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      badge: 'NEW',
                      badgeColor: Colors.orange,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VerbLearningModeScreen()),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _CompactGameCard(
                            title: 'Fill Blanks',
                            icon: Icons.edit_note_rounded,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6A1B9A), Color(0xFFBA68C8)],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const FillInBlanksModeScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CompactGameCard(
                            title: 'Sentence Builder',
                            icon: Icons.construction_rounded,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const SentenceBuilderModeScreen()),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _CompactGameCard(
                            title: 'Grammar Detective',
                            icon: Icons.search_rounded,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFc31432), Color(0xFF240b36)],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const GrammarDetectiveModeScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CompactGameCard(
                            title: 'Translation',
                            icon: Icons.translate_rounded,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF56ab2f), Color(0xFFa8e063)],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const BanglaToEnglishModeScreen()),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _EnhancedGameCard(
                      title: 'Story Completion',
                      description: 'গল্পে ফাঁকা জায়গায় সঠিক শব্দ বসান',
                      details: '10 stories • Bengali translation + explanation',
                      icon: Icons.auto_stories_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      badge: 'NEW',
                      badgeColor: const Color(0xFF0D9488),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const StoryCompletionModeScreen()),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _EnhancedGameCard(
                      title: 'Flashcards',
                      description: 'Swipe & memorize বাংলা → English',
                      details: '8 categories • 100+ words with pronunciation',
                      icon: Icons.style_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      badge: 'NEW',
                      badgeColor: const Color(0xFF6366F1),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FlashcardsModeScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Game Modes ──
            Row(
              children: [
                const Icon(Icons.sports_esports_rounded,
                    color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Text('Game Modes',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                _ModeCard(
                  title: 'Practice',
                  subtitle: 'Learn at your pace',
                  icon: Icons.school,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ModeSelectionScreen())),
                ),
                _ModeCard(
                  title: 'Daily Challenge',
                  subtitle: 'New questions daily',
                  icon: Icons.today,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const DailyChallengeScreen())),
                ),
                _ModeCard(
                  title: 'Boss Battle',
                  subtitle: 'Ultimate test',
                  icon: Icons.emoji_events,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BossBattleScreen())),
                ),
                _ModeCard(
                  title: 'Leaderboard',
                  subtitle: 'Compete globally',
                  icon: Icons.leaderboard,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── More Options ──
            Row(
              children: [
                const Icon(Icons.more_horiz_rounded,
                    color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Text('More',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ListTile(
                  icon: Icons.bar_chart,
                  title: 'Statistics',
                  subtitle: 'View your progress',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const StatisticsScreen())),
                ),
                _ListTile(
                  icon: Icons.emoji_events,
                  title: 'Achievements',
                  subtitle: _buildAchievementsSubtitle(),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AchievementsScreen())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Enhanced Game Card Widget ──
class _EnhancedGameCard extends StatelessWidget {
  final String title;
  final String description;
  final String details;
  final IconData icon;
  final Gradient gradient;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _EnhancedGameCard({
    required this.title,
    required this.description,
    required this.details,
    required this.icon,
    required this.gradient,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
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
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: Icon(icon, color: Colors.white, size: 32),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Colors.white.withOpacity(0.8), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    details,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact Game Card Widget ──
class _CompactGameCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _CompactGameCard({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        height: 130,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 12),
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
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold, color: color)),
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

  const _ModeCard(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: AppColors.primaryGradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
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

  const _ListTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

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
                  Text(title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
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