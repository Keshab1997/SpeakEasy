import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              'ROUND ${battleState.currentRoundIndex + 1} / 5',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? const [Color(0xFF0A1020), Color(0xFF0F172A), Color(0xFF101B33)]
                        : const [Color(0xFFF8FAFC), Color(0xFFF1F5F9), Color(0xFFE7EDF5)],
                  ),
                ),
                child: SafeArea(
                  child: Stack(
                    children: [
                      // Decorative arena glows
                      Positioned(
                        top: -70,
                        right: -50,
                        child: _buildGlow(const Color(0xFF3B82F6), isDark),
                      ),
                      Positioned(
                        bottom: 60,
                        left: -60,
                        child: _buildGlow(const Color(0xFFEF4444), isDark),
                      ),

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
                              totalSeconds: question.timeLimit,
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

                      // Quick Emote Tray Popup (slides up with fade)
                      Positioned(
                        bottom: 24,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          ignoring: !_showEmoteTray,
                          child: AnimatedSlide(
                            offset: _showEmoteTray ? Offset.zero : const Offset(0, 0.6),
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            child: AnimatedOpacity(
                              opacity: _showEmoteTray ? 1 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Center(
                                child: BattleEmoteOverlay(
                                  onSelectEmote: (emote) {
                                    ref.read(battleArenaProvider.notifier).sendEmote(emote);
                                    setState(() => _showEmoteTray = false);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// Soft radial glow used as background decoration.
  Widget _buildGlow(Color color, bool isDark) {
    return Container(
      width: 190,
      height: 190,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: isDark ? 0.14 : 0.08),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }

  Widget _buildVersusScoreHeader(BattleArenaState state, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1E293B), Color(0xFF16233B)]
              : [Colors.white, const Color(0xFFF1F5F9)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
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
            isDark: isDark,
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
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
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
                '⚔️ Speed Duel',
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
            isDark: isDark,
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
    required bool isDark,
    String? emote,
  }) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Avatar with gradient ring + glow when answered
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isLocal
                      ? const [Color(0xFF3B82F6), Color(0xFF06B6D4)]
                      : const [Color(0xFFEF4444), Color(0xFFF97316)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isLocal ? const Color(0xFF3B82F6) : const Color(0xFFEF4444))
                        .withValues(alpha: hasAnswered ? 0.55 : 0.25),
                    blurRadius: hasAnswered ? 14 : 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: isLocal ? const Color(0xFF3B82F6) : const Color(0xFFEF4444),
                backgroundImage: player.photoUrl.isNotEmpty ? NetworkImage(player.photoUrl) : null,
                child: player.photoUrl.isEmpty
                    ? Text(
                        player.name.isNotEmpty ? player.name[0].toUpperCase() : 'P',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
            ),
            if (hasAnswered)
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(Icons.check, size: 11, color: Colors.white),
                ),
              ),
            if (emote != null)
              Positioned(
                top: -24,
                left: isLocal ? -12 : null,
                right: isLocal ? null : -12,
                child: FloatingEmoteBubble(
                  emote: emote,
                  accentColor: isLocal
                      ? const Color(0xFF3B82F6)
                      : (player.isBot ? const Color(0xFF8B5CF6) : const Color(0xFFEF4444)),
                ),
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
                  color: Colors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('AI', style: TextStyle(fontSize: 8, color: Colors.purple, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        // Animated score counter
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
                  .animate(animation),
              child: child,
            ),
          ),
          child: Text(
            '${player.currentScore} pts',
            key: ValueKey<int>(player.currentScore),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: isLocal ? const Color(0xFF2563EB) : const Color(0xFFEF4444),
            ),
          ),
        ),
      ],
    );
  }

  /// Emoji per question category (used in the question card badge).
  String _categoryEmoji(String category) {
    final c = category.toLowerCase();
    if (c.contains('vocab')) return '📚';
    if (c.contains('gram')) return '✍️';
    if (c.contains('conv')) return '💬';
    return '🎯';
  }

  Widget _buildQuestionCard(BattleQuestion question, bool isDark, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1E293B), Color(0xFF18243A)]
              : [Colors.white, const Color(0xFFFAFBFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.10 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${_categoryEmoji(question.category)} ${question.category.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
              fontWeight: FontWeight.w800,
              fontSize: 18,
              height: 1.35,
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
    // The opponent's chosen option (revealed with a small rival marker once
    // the round settles — only meaningful against a live player).
    final isOpponentChoice = battleState.opponentAnswerIndex == index;

    Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    Color bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    Color textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    List<Color> badgeColors = const [Color(0xFF3B82F6), Color(0xFF6366F1)];
    Color? tileGlow;
    Widget? trailingIcon;

    if (isAnswerSubmitted) {
      if (isCorrectOption) {
        borderColor = const Color(0xFF10B981);
        bgColor = const Color(0xFF10B981).withValues(alpha: 0.15);
        textColor = const Color(0xFF10B981);
        badgeColors = const [Color(0xFF10B981), Color(0xFF34D399)];
        tileGlow = const Color(0xFF10B981);
        trailingIcon = const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981));
      } else if (isSelected && !isCorrectOption) {
        borderColor = const Color(0xFFEF4444);
        bgColor = const Color(0xFFEF4444).withValues(alpha: 0.15);
        textColor = const Color(0xFFEF4444);
        badgeColors = const [Color(0xFFEF4444), Color(0xFFF87171)];
        tileGlow = const Color(0xFFEF4444);
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
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: borderColor,
                width: isSelected || (isAnswerSubmitted && isCorrectOption) ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: tileGlow != null
                      ? tileGlow.withValues(alpha: 0.30)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: tileGlow != null ? 12 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: badgeColors),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: badgeColors.first.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + index), // A, B, C, D
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
                // Show which option the opponent picked (after the round is
                // revealed) — a small rival marker that never hides the
                // correct/wrong answer colours.
                if (trailingIcon == null && isOpponentChoice && battleState.isOpponentAnswered)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Tooltip(
                      message: "Opponent's choice",
                      child: Icon(Icons.person_rounded, size: 20, color: Color(0xFFEF4444)),
                    ),
                  )
                else if (trailingIcon != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isOpponentChoice && battleState.isOpponentAnswered)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.person_rounded, size: 18, color: Color(0xFFEF4444)),
                        ),
                      trailingIcon,
                    ],
                  ),
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
                if (!context.mounted) return;
                Navigator.of(context).pop();
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
