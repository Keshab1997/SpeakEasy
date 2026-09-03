import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/battle_arena_provider.dart';
import 'battle_answer_review_screen.dart';

class BattleResultScreen extends ConsumerStatefulWidget {
  const BattleResultScreen({super.key});

  @override
  ConsumerState<BattleResultScreen> createState() => _BattleResultScreenState();
}

class _BattleResultScreenState extends ConsumerState<BattleResultScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _heroController;
  late Animation<double> _heroScale;
  late Animation<double> _heroFade;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heroScale = CurvedAnimation(
      parent: _heroController,
      curve: const ElasticOutCurve(0.72),
    );
    _heroFade = CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(battleArenaProvider);
      if (state.isWinner) {
        _confettiController.play();
      }
      _heroController.forward();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(battleArenaProvider);

    final isWinner = state.isWinner;
    final isDraw = state.isDraw;
    final isOpponentForfeited = state.isOpponentForfeited;

    final outcome = isDraw
        ? _Outcome.draw
        : isWinner
            ? _Outcome.win
            : _Outcome.loss;

    final questions = state.room?.questions ?? [];

    // Hero gradients per outcome
    final heroGradient = switch (outcome) {
      _Outcome.win => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
        ),
      _Outcome.loss => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7F1D1D), Color(0xFFDC2626), Color(0xFFF87171)],
        ),
      _Outcome.draw => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF92400E), Color(0xFFF59E0B), Color(0xFFFCD34D)],
        ),
    };

    final bgGradient = isDark
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: switch (outcome) {
              _Outcome.win => [const Color(0xFF042F1A), const Color(0xFF0F172A), const Color(0xFF0B1220)],
              _Outcome.loss => [const Color(0xFF2A0A0A), const Color(0xFF0F172A), const Color(0xFF0B1220)],
              _Outcome.draw => [const Color(0xFF2A1A05), const Color(0xFF0F172A), const Color(0xFF0B1220)],
            },
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: switch (outcome) {
              _Outcome.win => [const Color(0xFFECFDF5), const Color(0xFFF8FAFC), const Color(0xFFE0F2FE)],
              _Outcome.loss => [const Color(0xFFFEF2F2), const Color(0xFFF8FAFC), const Color(0xFFFFF1F2)],
              _Outcome.draw => [const Color(0xFFFFFBEB), const Color(0xFFF8FAFC), const Color(0xFFFEF3C7)],
            },
          );

    final headline = switch (outcome) {
      _Outcome.win => isOpponentForfeited ? 'VICTORY! 🏆' : 'VICTORY!',
      _Outcome.loss => 'DEFEAT',
      _Outcome.draw => 'DRAW!',
    };

    final subtitle = switch (outcome) {
      _Outcome.win => isOpponentForfeited
          ? 'Opponent fled the arena'
          : 'You dominated the duel!',
      _Outcome.loss => 'Close battle — come back stronger!',
      _Outcome.draw => 'A hard-fought tie!',
    };

    final delta = state.trophyDelta;
    final deltaPositive = delta >= 0;
    final deltaColor = deltaPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: Stack(
          children: [
            // Subtle grid pattern glows
            Positioned(
              top: -80,
              right: -60,
              child: _glow(outcome.color.withValues(alpha: isDark ? 0.18 : 0.10), 220),
            ),
            Positioned(
              bottom: 120,
              left: -80,
              child: _glow(outcome.color.withValues(alpha: isDark ? 0.12 : 0.08), 260),
            ),

            // Confetti
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: 28,
                gravity: 0.18,
                colors: const [
                  Color(0xFF10B981),
                  Color(0xFF3B82F6),
                  Color(0xFFF59E0B),
                  Color(0xFFEC4899),
                  Color(0xFF8B5CF6),
                ],
              ),
            ),

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        children: [
                          // ── HERO HEADER ─────────────────────────────────
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: heroGradient,
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
                              boxShadow: [
                                BoxShadow(
                                  color: outcome.color.withValues(alpha: 0.35),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // soft highlight overlay
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Colors.white.withValues(alpha: 0.18), Colors.transparent],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                                  child: Column(
                                    children: [
                                      // top bar
                                      Row(
                                        children: [
                                          _heroTopChip(
                                            icon: Icons.bolt_rounded,
                                            label: 'BATTLE RESULT',
                                          ),
                                          const Spacer(),
                                          if (isOpponentForfeited)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text('🏃', style: TextStyle(fontSize: 12)),
                                                  SizedBox(width: 4),
                                                  Text('Forfeit',
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.w800,
                                                          fontSize: 11,
                                                          letterSpacing: 0.5)),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 18),

                                      // Animated trophy / outcome icon
                                      ScaleTransition(
                                        scale: _heroScale,
                                        child: FadeTransition(
                                          opacity: _heroFade,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              // outer glow ring
                                              Container(
                                                width: 122,
                                                height: 122,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.white.withValues(alpha: 0.14),
                                                  border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.5),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.white.withValues(alpha: 0.18),
                                                      blurRadius: 24,
                                                      spreadRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                width: 96,
                                                height: 96,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.white,
                                                  border: Border.all(color: Colors.white, width: 2),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.18),
                                                      blurRadius: 16,
                                                      offset: const Offset(0, 6),
                                                    ),
                                                  ],
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    switch (outcome) {
                                                      _Outcome.win => '🏆',
                                                      _Outcome.loss => '💔',
                                                      _Outcome.draw => '🤝',
                                                    },
                                                    style: const TextStyle(fontSize: 48),
                                                  ),
                                                ),
                                              ),
                                              if (isWinner)
                                                Positioned(
                                                  top: 0,
                                                  right: 6,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF59E0B),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: Colors.white, width: 2),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                                                          blurRadius: 10,
                                                        ),
                                                      ],
                                                    ),
                                                    child: const Text('👑', style: TextStyle(fontSize: 14)),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      // Headline with shadow
                                      Text(
                                        headline,
                                        style: TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2.0,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black.withValues(alpha: 0.25),
                                              blurRadius: 12,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        subtitle,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withValues(alpha: 0.94),
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      if (isOpponentForfeited) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.16),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                                          ),
                                          child: const Text(
                                            'Opponent surrendered — you are the winner! 🏃💨',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── FLOATING TROPHY PILL (overlaps hero) ───────
                          Transform.translate(
                            offset: const Offset(0, -22),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: deltaColor.withValues(alpha: 0.22),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: deltaColor.withValues(alpha: 0.14),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: deltaPositive
                                            ? [const Color(0xFFF59E0B), const Color(0xFFF97316)]
                                            : [const Color(0xFF64748B), const Color(0xFF475569)],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  TweenAnimationBuilder<int>(
                                    tween: IntTween(begin: 0, end: delta),
                                    duration: const Duration(milliseconds: 900),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, _) => Text(
                                      '${value >= 0 ? '+' : ''}$value',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: deltaColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Trophies',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // ── SHIELD / COMEBACK BANNERS ─────────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                if (!isWinner && !isDraw && delta == 0)
                                  _banner(
                                    icon: '🛡️',
                                    title: 'Loss Shield Active',
                                    subtitle: 'No trophies lost — keep pushing!',
                                    colors: const [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                                    isDark: isDark,
                                  ),
                                if (isWinner && delta >= 30)
                                  _banner(
                                    icon: '📈',
                                    title: 'Comeback Bonus!',
                                    subtitle: 'Extra trophies for climbing back 💪',
                                    colors: const [Color(0xFFB45309), Color(0xFFF59E0B)],
                                    isDark: isDark,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),

                          // ── DUEL SCORE ARENA ──────────────────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // duel header
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: outcome.color,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: outcome.color.withValues(alpha: 0.5),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'DUEL SCOREBOARD',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(width: 8, height: 8, decoration: BoxDecoration(color: outcome.color, shape: BoxShape.circle)),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _playerDuelColumn(
                                          name: state.localPlayer.name,
                                          photoUrl: state.localPlayer.photoUrl,
                                          score: state.localPlayer.currentScore,
                                          isWinner: isWinner,
                                          isLocal: true,
                                          isDark: isDark,
                                          trophies: state.localPlayer.trophies,
                                        ),
                                      ),
                                      // VS pillar
                                      Column(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: isDraw
                                                    ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                                                    : isWinner
                                                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                                        : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                                              ),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: outcome.color.withValues(alpha: 0.35),
                                                  blurRadius: 12,
                                                ),
                                              ],
                                            ),
                                            child: const Center(
                                              child: Text(
                                                'VS',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 12,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                              ),
                                            ),
                                            child: Text(
                                              '${(state.localPlayer.currentScore - state.opponent.currentScore).abs()} pts gap',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Expanded(
                                        child: _playerDuelColumn(
                                          name: state.opponent.name,
                                          photoUrl: state.opponent.photoUrl,
                                          score: state.opponent.currentScore,
                                          isWinner: !isWinner && !isDraw,
                                          isLocal: false,
                                          isDark: isDark,
                                          isBot: state.opponent.isBot,
                                          trophies: state.opponent.trophies,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // divider + quick stats
                                  Container(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _miniStat(
                                        label: 'Rounds',
                                        value: '5/5',
                                        icon: Icons.layers_rounded,
                                        isDark: isDark,
                                      ),
                                      _dotDivider(isDark),
                                      _miniStat(
                                        label: outcome == _Outcome.win ? 'Margin' : outcome == _Outcome.draw ? 'Tie' : 'Deficit',
                                        value: isDraw ? '—' : '+${(state.localPlayer.currentScore - state.opponent.currentScore).abs()}',
                                        icon: isWinner ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                        isDark: isDark,
                                        color: outcome.color,
                                      ),
                                      _dotDivider(isDark),
                                      _miniStat(
                                        label: 'Division',
                                        value: _divisionShort(state.stats.trophies),
                                        icon: Icons.military_tech_rounded,
                                        isDark: isDark,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ── REVIEW BUTTON ─────────────────────────────
                          if (questions.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: isDark ? [const Color(0xFF1E293B), const Color(0xFF1E3A5F)] : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                                  ),
                                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.55)),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => BattleAnswerReviewScreen(
                                            questions: questions,
                                            userAnswers: state.localPlayer.roundAnswers,
                                            opponentAnswers: state.opponent.roundAnswers,
                                            opponentName: state.opponent.name,
                                            opponentIsBot: state.opponent.isBot,
                                          ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2563EB),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 18),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Review Answers',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? Colors.white : const Color(0xFF1E40AF),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(Icons.arrow_forward_rounded, size: 16, color: isDark ? Colors.white70 : const Color(0xFF3B82F6)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 18),

                          // ── ACTIONS ────────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                // Play again — premium gradient
                                Container(
                                  width: double.infinity,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () async {
                                        final notifier = ref.read(battleArenaProvider.notifier);
                                        notifier.resetLobby();
                                        if (context.mounted) Navigator.of(context).pop();
                                        await Future.delayed(const Duration(milliseconds: 350));
                                        notifier.startQuickMatch();
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'PLAY AGAIN',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.1,
                                              fontSize: 15,
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          Text('⚔️', style: TextStyle(fontSize: 16)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      ref.read(battleArenaProvider.notifier).resetLobby();
                                      Navigator.of(context).pop();
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.home_rounded, size: 18),
                                        SizedBox(width: 6),
                                        Text('Back to Lobby', style: TextStyle(fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────

  Widget _glow(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      );

  Widget _heroTopChip({required IconData icon, required String label}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      );

  Widget _banner({
    required String icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required bool isDark,
  }) =>
      Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              ),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                  const SizedBox(height: 1),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _playerDuelColumn({
    required String name,
    required String photoUrl,
    required int score,
    required bool isWinner,
    required bool isLocal,
    required bool isDark,
    bool isBot = false,
    int trophies = 100,
  }) {
    final ringColors = isWinner
        ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
        : isLocal
            ? [const Color(0xFF3B82F6), const Color(0xFF06B6D4)]
            : [const Color(0xFF64748B), const Color(0xFF475569)];

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: ringColors),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isWinner ? const Color(0xFFF59E0B) : ringColors.first).withValues(alpha: 0.35),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'P',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: isDark ? Colors.white : const Color(0xFF334155),
                        ))
                    : null,
              ),
            ),
            if (isWinner)
              Positioned(
                top: -6,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.45), blurRadius: 10)],
                  ),
                  child: const Text('👑', style: TextStyle(fontSize: 12)),
                ),
              ),
            if (isWinner)
              Positioned(
                bottom: -8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: const Text(
                      'WINNER',
                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          name.length > 11 ? '${name.substring(0, 10)}…' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        if (isBot)
          Container(
            margin: const EdgeInsets.only(top: 3),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
            child: const Text('BOT 🤖', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED))),
          ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isWinner
                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                : isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isWinner ? const Color(0xFF10B981).withValues(alpha: 0.35) : isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            '$score pts',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isWinner ? const Color(0xFF059669) : isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniStat({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    Color? color,
  }) =>
      Column(
        children: [
          Icon(icon, size: 14, color: color ?? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: color ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ],
      );

  Widget _dotDivider(bool isDark) => Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          shape: BoxShape.circle,
        ),
      );

  String _divisionShort(int trophies) {
    if (trophies >= 1500) return 'Grandmaster';
    if (trophies >= 800) return 'Master';
    if (trophies >= 300) return 'Challenger';
    return 'Novice';
  }
}

enum _Outcome { win, loss, draw }

extension on _Outcome {
  Color get color => switch (this) {
        _Outcome.win => const Color(0xFF10B981),
        _Outcome.loss => const Color(0xFFEF4444),
        _Outcome.draw => const Color(0xFFF59E0B),
      };
}
