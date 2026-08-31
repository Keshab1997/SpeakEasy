import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/battle_models.dart';
import '../providers/battle_arena_provider.dart';
import '../widgets/battle_emote_overlay.dart';
import '../widgets/battle_timer_bar.dart';
import 'battle_result_screen.dart';

class BattleArenaScreen extends ConsumerStatefulWidget {
  const BattleArenaScreen({super.key});

  @override
  ConsumerState<BattleArenaScreen> createState() => _BattleArenaScreenState();
}

class _BattleArenaScreenState extends ConsumerState<BattleArenaScreen> {
  bool _showEmoteTray = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final battleState = ref.watch(battleArenaProvider);

    // Auto transition to result screen when match completes
    ref.listen<BattleArenaState>(battleArenaProvider, (prev, next) {
      if (next.status == BattleArenaStatus.completed && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const BattleResultScreen()),
        );
      }
    });

    final question = battleState.currentQuestion;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _confirmForfeitExit(context);
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.grey),
            tooltip: 'Surrender & Exit',
            onPressed: () => _confirmForfeitExit(context),
          ),
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'ROUND ${battleState.currentRoundIndex + 1} / 5',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B82F6),
                letterSpacing: 1.0,
              ),
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFFF59E0B)),
              onPressed: () {
                setState(() => _showEmoteTray = !_showEmoteTray);
              },
            ),
          ],
        ),
        body: question == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        // 1. Split Score Bar (Player VS Opponent)
                        _buildVersusScoreHeader(battleState, isDark),
                        const SizedBox(height: 12),

                        // 2. Round Timer Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: BattleTimerBar(
                            remainingSeconds: battleState.remainingSeconds,
                            totalSeconds: 15,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. Question Card & Options
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                _buildQuestionCard(question, isDark, theme),
                                const SizedBox(height: 18),
                                ...List.generate(question.options.length, (index) {
                                  return _buildOptionTile(
                                    index: index,
                                    optionText: question.options[index],
                                    question: question,
                                    battleState: battleState,
                                    isDark: isDark,
                                  );
                                }),
                                const SizedBox(height: 80),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Quick Emote Tray Popup
                    if (_showEmoteTray)
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: BattleEmoteOverlay(
                            onSelectEmote: (emote) {
                              ref.read(battleArenaProvider.notifier).sendEmote(emote);
                              setState(() => _showEmoteTray = false);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildVersusScoreHeader(BattleArenaState state, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Local Player
          _buildPlayerColumn(
            player: state.localPlayer,
            isLocal: true,
            hasAnswered: state.isAnswerSubmitted,
            emote: state.activeEmote,
          ),

          // Center: VS Badge
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Speed Duel',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),

          // Right: Opponent
          _buildPlayerColumn(
            player: state.opponent,
            isLocal: false,
            hasAnswered: state.isOpponentAnswered,
            emote: state.opponentEmote,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerColumn({
    required BattlePlayer player,
    required bool isLocal,
    required bool hasAnswered,
    String? emote,
  }) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: isLocal ? const Color(0xFF3B82F6) : const Color(0xFFEF4444),
              backgroundImage: player.photoUrl.isNotEmpty ? NetworkImage(player.photoUrl) : null,
              child: player.photoUrl.isEmpty
                  ? Text(
                      player.name.isNotEmpty ? player.name[0].toUpperCase() : 'P',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            if (hasAnswered)
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),
            if (emote != null)
              Positioned(
                top: -15,
                child: FloatingEmoteBubble(emote: emote),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              player.name.length > 9 ? '${player.name.substring(0, 8)}…' : player.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (player.isBot) ...[
              const SizedBox(width: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('AI', style: TextStyle(fontSize: 8, color: Colors.purple, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${player.currentScore} pts',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: isLocal ? const Color(0xFF2563EB) : const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(BattleQuestion question, bool isDark, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  question.category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF59E0B),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.bolt, size: 14, color: Color(0xFFF59E0B)),
                  Text(
                    'Speed Bonus Active',
                    style: TextStyle(fontSize: 10, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            question.question,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              height: 1.3,
            ),
          ),
          if (question.bangla.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              question.bangla,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontFamily: 'NotoSansBengali',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required int index,
    required String optionText,
    required BattleQuestion question,
    required BattleArenaState battleState,
    required bool isDark,
  }) {
    final isSelected = battleState.selectedAnswerIndex == index;
    final isAnswerSubmitted = battleState.isAnswerSubmitted;
    final isCorrectOption = index == question.correctAnswer;

    Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    Color bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    Color textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    Widget? trailingIcon;

    if (isAnswerSubmitted) {
      if (isCorrectOption) {
        borderColor = const Color(0xFF10B981);
        bgColor = const Color(0xFF10B981).withOpacity(0.15);
        textColor = const Color(0xFF10B981);
        trailingIcon = const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981));
      } else if (isSelected && !isCorrectOption) {
        borderColor = const Color(0xFFEF4444);
        bgColor = const Color(0xFFEF4444).withOpacity(0.15);
        textColor = const Color(0xFFEF4444);
        trailingIcon = const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444));
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAnswerSubmitted
              ? null
              : () {
                  ref.read(battleArenaProvider.notifier).submitLocalAnswer(index);
                },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: isSelected || (isAnswerSubmitted && isCorrectOption) ? 2 : 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + index), // A, B, C, D
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    optionText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      fontFamily: 'NotoSansBengali',
                    ),
                  ),
                ),
                if (trailingIcon != null) trailingIcon,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmForfeitExit(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text('Surrender Match?'),
            ],
          ),
          content: const Text(
            'Leaving the battle now will result in an immediate forfeit. Your opponent will be declared the WINNER and you will lose 10 Trophies (-10 🏆)!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Fighting ⚔️'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(battleArenaProvider.notifier).forfeitCurrentMatch();
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: const Text('Forfeit & Exit'),
            ),
          ],
        );
      },
    );
  }
}
