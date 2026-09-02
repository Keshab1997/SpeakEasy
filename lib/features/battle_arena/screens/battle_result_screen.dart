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

class _BattleResultScreenState extends ConsumerState<BattleResultScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(battleArenaProvider);
      if (state.isWinner) {
        _confettiController.play();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(battleArenaProvider);

    final isWinner = state.isWinner;
    final isDraw = state.isDraw;
    final isOpponentForfeited = state.isOpponentForfeited;

    String headline = isDraw ? 'MATCH TIED 🤝' : (isWinner ? 'VICTORY! 🏆' : 'DEFEAT 💔');
    Color outcomeColor = isDraw
        ? const Color(0xFFF59E0B)
        : (isWinner ? const Color(0xFF10B981) : const Color(0xFFEF4444));

    final questions = state.room?.questions ?? [];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Confetti Animation for Winner
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Color(0xFF10B981),
                Color(0xFF3B82F6),
                Color(0xFFF59E0B),
                Color(0xFFEC4899),
              ],
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const SizedBox(height: 12),

                          // Outcome Trophy Icon
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: outcomeColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: outcomeColor, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: outcomeColor.withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                isDraw ? '🤝' : (isWinner ? '🏆' : '💔'),
                                style: const TextStyle(fontSize: 44),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Headline
                          Text(
                            headline,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: outcomeColor,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (isOpponentForfeited) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Opponent surrendered / left the battle! 🏃💨',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Trophies Delta Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: outcomeColor.withValues(alpha: 0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  state.trophyDelta >= 0
                                      ? '+${state.trophyDelta} Trophies'
                                      : '${state.trophyDelta} Trophies',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: state.trophyDelta >= 0
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Shield / comeback encouragement
                          if (!isWinner && !isDraw && state.trophyDelta == 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text(
                                "🛡️ Loss Shield activated — you didn't lose any trophies! Keep going!",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                            ),
                          ],
                          if (isWinner && state.trophyDelta >= 30) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text(
                                '📈 Comeback Bonus! Extra trophies for climbing back 💪',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),

                          // Score Comparison Card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildPlayerResultSummary(
                                  name: state.localPlayer.name,
                                  photoUrl: state.localPlayer.photoUrl,
                                  score: state.localPlayer.currentScore,
                                  isWinner: isWinner,
                                  isDark: isDark,
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Text(
                                    'VS',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                                _buildPlayerResultSummary(
                                  name: state.opponent.name,
                                  photoUrl: state.opponent.photoUrl,
                                  score: state.opponent.currentScore,
                                  isWinner: !isWinner && !isDraw,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── NEW: Review Answers & Explanations Button ──
                          if (questions.isNotEmpty)
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? [
                                          const Color(0xFF1E293B),
                                          const Color(0xFF0F2B48),
                                        ]
                                      : [
                                          const Color(0xFFEFF6FF),
                                          const Color(0xFFDBEAFE),
                                        ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
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
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.menu_book_rounded,
                                          color: Color(0xFF2563EB),
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Review Questions & Explanations 📝',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : const Color(0xFF1D4ED8),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          const Spacer(),
                          const SizedBox(height: 16),

                          // Play Again Button
                          ElevatedButton(
                            onPressed: () async {
                              final notifier = ref.read(battleArenaProvider.notifier);
                              notifier.resetLobby();
                              if (context.mounted) Navigator.of(context).pop();
                              await Future.delayed(const Duration(milliseconds: 400));
                              notifier.startQuickMatch();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 3,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.replay_rounded),
                                SizedBox(width: 8),
                                Text(
                                  'PLAY AGAIN ⚔️',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Back to Lobby Button
                          OutlinedButton(
                            onPressed: () {
                              ref.read(battleArenaProvider.notifier).resetLobby();
                              Navigator.of(context).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Back to Lobby 🏠'),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerResultSummary({
    required String name,
    required String photoUrl,
    required int score,
    required bool isWinner,
    required bool isDark,
  }) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'P') : null,
            ),
            if (isWinner)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('👑', style: TextStyle(fontSize: 11)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          name.length > 10 ? '${name.substring(0, 9)}…' : name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(
          '$score pts',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: isWinner ? const Color(0xFF10B981) : Colors.grey,
          ),
        ),
      ],
    );
  }
}
