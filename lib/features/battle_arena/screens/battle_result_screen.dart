import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/battle_arena_provider.dart';

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
    Color outcomeColor = isDraw ? const Color(0xFFF59E0B) : (isWinner ? const Color(0xFF10B981) : const Color(0xFFEF4444));

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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const Spacer(),

                  // Outcome Trophy Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: outcomeColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: outcomeColor, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        isDraw ? '🤝' : (isWinner ? '🏆' : '💔'),
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Headline
                  Text(
                    headline,
                    style: TextStyle(
                      fontSize: 28,
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
                    const SizedBox(height: 12),
                  ],

                  // Trophies Delta Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                        const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 24),
                        const SizedBox(width: 8),
                        Text(
                          state.trophyDelta >= 0 ? '+${state.trophyDelta} Trophies' : '${state.trophyDelta} Trophies',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: state.trophyDelta >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Shield / comeback encouragement
                  if (!isWinner && !isDraw && state.trophyDelta == 0) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        "🛡️ Loss Shield activated — you didn't lose any trophies! Keep going!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                  if (isWinner && state.trophyDelta >= 30) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        '📈 Comeback Bonus! Extra trophies for climbing back 💪',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),

                  // Score Comparison Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
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
                          child: const Text('VS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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

                  const Spacer(),

                  // Play Again & Lobby Buttons
                  ElevatedButton(
                    onPressed: () {
                      ref.read(battleArenaProvider.notifier).resetLobby();
                      Navigator.of(context).pop();
                      ref.read(battleArenaProvider.notifier).startQuickMatch();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.replay_rounded),
                        SizedBox(width: 8),
                        Text(
                          'PLAY AGAIN ⚔️',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton(
                    onPressed: () {
                      ref.read(battleArenaProvider.notifier).resetLobby();
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Back to Lobby 🏠'),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
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
              radius: 28,
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
                  child: const Text('👑', style: TextStyle(fontSize: 12)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          name.length > 10 ? '${name.substring(0, 9)}…' : name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          '$score pts',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isWinner ? const Color(0xFF10B981) : Colors.grey,
          ),
        ),
      ],
    );
  }
}
