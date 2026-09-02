import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/streak_widget.dart';
import '../../../providers/game/xp_provider.dart';
import '../../../providers/game/coin_provider.dart';
import '../../../providers/game/streak_provider.dart';
import '../../../providers/game/statistics_provider.dart';
import '../../../providers/game/achievement_provider.dart';
import '../../../services/hive_service.dart';
import '../../../services/remote_config_service.dart';
import '../../../services/share_service.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(xpProvider.notifier).refresh();
      ref.read(coinProvider.notifier).refresh();
      ref.read(streakProvider.notifier).refresh();
      ref.read(statisticsProvider.notifier).refresh();
    });

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

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
      data: (state) => '${state.unlockedCount}/${state.totalCount} unlocked',
      loading: () => 'Loading...',
      error: (_, __) => 'View Badges',
    );
  }

  bool _hasPracticedToday() {
    final lastActive = HiveService.getLastPracticeDate();
    if (lastActive == null) return false;
    final now = DateTime.now();
    return lastActive.year == now.year &&
        lastActive.month == now.month &&
        lastActive.day == now.day;
  }

  void _showStreakInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🔥 ', style: TextStyle(fontSize: 24)),
            Text('My Streak'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '• Practice daily to keep your streak alive.\n'
              '• Complete at least one lesson each day.\n'
              '• Buy a Streak Freeze (🛡️) to protect your streak if you miss a day.\n'
              '• Longer streaks unlock special badges & rewards!',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            SizedBox(height: 16),
            Text(
              '💡 Tip: Set a daily reminder in Settings to never miss a practice day!',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Future<void> _buyStreakFreeze(BuildContext context, int currentCoins) async {
    final cost = await RemoteConfigService.getStreakFreezeCost();
    if (!context.mounted) return;
    if (currentCoins < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Not enough coins! Play games to earn more.'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🛡️ Buy Streak Freeze'),
        content: Text('Spend $cost coins to buy a Streak Freeze?\n'
            'You can protect your streak if you miss a day.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(coinProvider.notifier).spendCoins(cost);
              await HiveService.addStreakFreeze();
              if (context.mounted) {
                Navigator.pop(ctx);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🛡️ Streak Freeze purchased!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Buy', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _shareStreak(BuildContext context, int streak) {
    if (streak > 0) {
      ShareService.shareStreak(streak);
    } else {
      ShareService.shareApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final xpState = ref.watch(xpProvider);
    final coinState = ref.watch(coinProvider);
    final streakState = ref.watch(streakProvider);
    final statsState = ref.watch(statisticsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final int displayXP = statsState.totalEarnedXP > 0
        ? statsState.totalEarnedXP
        : xpState.currentXP;
    final int displayCoins = statsState.totalEarnedCoins > 0
        ? statsState.totalEarnedCoins
        : coinState.currentCoins;
    final int displayLevel =
        xpState.currentLevel > 0 ? xpState.currentLevel : 1;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎮 Learning Games', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Compact Player Banner (Level, XP, Coins) ──
                _buildPlayerHeaderCard(
                  displayLevel: displayLevel,
                  levelEmoji: xpState.levelEmoji,
                  levelTitle: xpState.levelTitle,
                  displayCoins: displayCoins,
                  displayXP: displayXP,
                  levelProgress: xpState.levelProgress,
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                // ── 2. Streak & Weekly Attendance Card ──
                StreakWidget(
                  currentStreak: streakState.currentStreak,
                  weeklyStreak: streakState.weeklyStreak,
                  weeklyMilestone: streakState.weeklyMilestone,
                  weeklyMilestoneLabel: streakState.weeklyMilestoneLabel,
                  thisWeekActiveDays: streakState.thisWeekActiveDays,
                  todayXP: displayXP,
                  dailyXPTarget: 50,
                  hasPracticeToday: _hasPracticedToday(),
                  isStreakFrozen: HiveService.getStreakFreezeCount() > 0,
                  streakFreezeCount: HiveService.getStreakFreezeCount(),
                  onTap: () => _showStreakInfoDialog(context),
                  onBuyFreeze: () => _buyStreakFreeze(context, displayCoins),
                  onShare: () => _shareStreak(context, streakState.currentStreak),
                ),
                const SizedBox(height: 18),

                // ── 3. Quick Play Modes Grid (Daily Challenge, Boss Battle, Leaderboard, Practice) ──
                _buildSectionHeader('GAME MODES', Icons.sports_esports_rounded, const Color(0xFF6366F1), isDark),
                const SizedBox(height: 10),
                _buildQuickModesGrid(context, isDark),
                const SizedBox(height: 20),

                // ── 4. All Learning Games (Compact 2-Column Grid) ──
                _buildSectionHeader('ALL LEARNING GAMES', Icons.stars_rounded, const Color(0xFFF59E0B), isDark),
                const SizedBox(height: 10),
                _buildAllGamesGrid(context),
                const SizedBox(height: 20),

                // ── 5. Quick Stats & Achievements (Side-by-Side Compact) ──
                _buildStatsAndAchievementsRow(
                  context: context,
                  statsState: statsState,
                  isDark: isDark,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Compact Player Header Banner ──
  Widget _buildPlayerHeaderCard({
    required int displayLevel,
    required String levelEmoji,
    required String levelTitle,
    required int displayCoins,
    required int displayXP,
    required double levelProgress,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(levelEmoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Level $displayLevel',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            levelTitle,
                            style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$displayXP XP earned',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              // Coins Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$displayCoins',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: levelProgress.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Header ──
  Widget _buildSectionHeader(String title, IconData icon, Color color, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // ── Quick Play Modes Grid (Practice, Daily, Boss, Leaderboard) ──
  Widget _buildQuickModesGrid(BuildContext context, bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: [
        _buildQuickModeTile(
          title: 'Daily Challenge',
          subtitle: 'New Daily Qs',
          icon: Icons.today_rounded,
          gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DailyChallengeScreen()),
          ),
        ),
        _buildQuickModeTile(
          title: 'Boss Battle',
          subtitle: 'Ultimate Test',
          icon: Icons.shield_rounded,
          gradient: const [Color(0xFFEF4444), Color(0xFFB91C1C)],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BossBattleScreen()),
          ),
        ),
        _buildQuickModeTile(
          title: 'Leaderboard',
          subtitle: 'Compete Global',
          icon: Icons.leaderboard_rounded,
          gradient: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
          ),
        ),
        _buildQuickModeTile(
          title: 'Practice Hub',
          subtitle: 'Self-Paced',
          icon: Icons.school_rounded,
          gradient: const [Color(0xFF10B981), Color(0xFF047857)],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickModeTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── All Learning Games (Compact 2-Column Grid) ──
  Widget _buildAllGamesGrid(BuildContext context) {
    final games = [
      _GameItem(
        title: 'Word Match',
        description: 'বাংলা → English pairs',
        icon: Icons.compare_arrows_rounded,
        badge: 'HOT',
        gradient: const [Color(0xFF6366F1), Color(0xFF4338CA)],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WordMatchModeScreen()),
        ),
      ),
      _GameItem(
        title: 'Quick Quiz',
        description: '5s speed challenge',
        icon: Icons.bolt_rounded,
        badge: 'SPEED',
        gradient: const [Color(0xFFF43F5E), Color(0xFFBE123C)],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QuickQuizModeScreen()),
        ),
      ),
      _GameItem(
        title: 'Verb Learning',
        description: 'V1–V5 & grammar rules',
        icon: Icons.directions_run_rounded,
        badge: 'VERBS',
        gradient: const [Color(0xFF10B981), Color(0xFF047857)],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VerbLearningModeScreen()),
        ),
      ),
      _GameItem(
        title: 'Fill Blanks',
        description: 'Sentence grammar gaps',
        icon: Icons.edit_note_rounded,
        badge: 'MCQ',
        gradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FillInBlanksModeScreen()),
        ),
      ),
      _GameItem(
        title: 'Sentence Builder',
        description: 'Arrange words in order',
        icon: Icons.construction_rounded,
        badge: 'BUILD',
        gradient: const [Color(0xFF0284C7), Color(0xFF0369A1)],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SentenceBuilderModeScreen()),
        ),
      ),
      _GameItem(
        title: 'Grammar Detective',
        description: 'Spot & fix mistakes',
        icon: Icons.search_rounded,
        badge: 'ERROR',
        gradient: const [Color(0xFFD97706), Color(0xFFB45309)],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GrammarDetectiveModeScreen()),
        ),
      ),
      _GameItem(
        title: 'Translation',
        description: 'বাংলা to English mode',
        icon: Icons.translate_rounded,
        badge: 'DUAL',
        gradient: const [Color(0xFF059669), Color(0xFF065F46)],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BanglaToEnglishModeScreen()),
        ),
      ),
      _GameItem(
        title: 'Story Completion',
        description: 'Complete the short story',
        icon: Icons.auto_stories_rounded,
        badge: 'READ',
        gradient: const [Color(0xFF0D9488), Color(0xFF115E59)],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StoryCompletionModeScreen()),
        ),
      ),
      _GameItem(
        title: 'Flashcards',
        description: 'Swipe & learn vocabulary',
        icon: Icons.style_rounded,
        badge: 'VOCAB',
        gradient: const [Color(0xFFEC4899), Color(0xFFBE185D)],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FlashcardsModeScreen()),
        ),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.22,
      ),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final g = games[index];
        return _buildGameGridTile(g);
      },
    );
  }

  Widget _buildGameGridTile(_GameItem game) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: game.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: game.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: game.gradient.first.withValues(alpha: 0.32),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(game.icon, color: Colors.white, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      game.badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    game.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    game.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 10.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Quick Stats & Achievements (Side-by-Side Row) ──
  Widget _buildStatsAndAchievementsRow({
    required BuildContext context,
    required dynamic statsState,
    required bool isDark,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildBottomHubCard(
            title: 'Statistics',
            subtitle: '${statsState.totalGamesPlayed} Played · ${(statsState.overallAccuracy * 100).toStringAsFixed(0)}% Acc',
            icon: Icons.bar_chart_rounded,
            color: const Color(0xFF3B82F6),
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatisticsScreen()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildBottomHubCard(
            title: 'Achievements',
            subtitle: _buildAchievementsSubtitle(),
            icon: Icons.emoji_events_rounded,
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AchievementsScreen()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomHubCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Model for Clean Game Grid Items ──
class _GameItem {
  final String title;
  final String description;
  final IconData icon;
  final String badge;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _GameItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.badge,
    required this.gradient,
    required this.onTap,
  });
}
