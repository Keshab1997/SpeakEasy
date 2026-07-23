import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/game/game_provider.dart';
import '../../../providers/game/timer_provider.dart';
import '../../../providers/game/score_provider.dart';
import '../../../providers/game/statistics_provider.dart';
import 'result_screen.dart';

class BossBattleScreen extends ConsumerWidget {
  const BossBattleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final timerState = ref.watch(timerProvider);
    final scoreState = ref.watch(scoreProvider);
    final theme = Theme.of(context);
    const themeColor = Colors.deepPurple;
    const themeGradient = [Color(0xFF7C3AED), Color(0xFF6D28D9)];

    // Start boss battle on first build
    ref.listen<GameState>(gameProvider, (previous, next) {
      if (previous?.questions.isEmpty ?? true && next.questions.isNotEmpty) {
        ref.read(timerProvider.notifier).startChallengeGame();
      }
    });

    if (gameState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (gameState.error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(gameState.error!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.read(gameProvider.notifier).reset(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (gameState.questions.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
              const SizedBox(height: 16),
              Text('Boss Battle', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Defeat the boss by answering 20 hard questions!', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  ref.read(gameProvider.notifier).loadQuestions(
                    difficulty: 'hard',
                    limit: 20,
                    gameType: 'boss',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Start Boss Battle'),
              ),
            ],
          ),
        ),
      );
    }

    final question = gameState.currentQuestion!;
    final progress = gameState.answeredCount / gameState.totalQuestions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boss Battle', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: themeColor,
        actions: [
          if (timerState.isRunning || timerState.isPaused)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                timerState.formattedTime,
                style: TextStyle(
                  color: timerState.remainingSeconds < 10 ? Colors.red : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Boss Health Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: themeColor,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Boss Health', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('${gameState.totalQuestions - gameState.answeredCount}/${gameState.totalQuestions}', 
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 1 - progress,
                    backgroundColor: Colors.white30,
                    color: Colors.white,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),

          // Boss Battle Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: themeGradient),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Boss Battle',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Question ${gameState.currentQuestionIndex + 1} of ${gameState.totalQuestions}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${scoreState.currentScore}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: themeGradient),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.white, size: 24),
                            const SizedBox(width: 8),
                            Text('Question ${gameState.currentQuestionIndex + 1}', 
                                style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          question.question,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600, height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Difficulty Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: themeColor),
                    ),
                    child: Text(
                      'HARD - ${question.tenseType}',
                      style: const TextStyle(color: themeColor, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Options
                  ...question.options.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final option = entry.value;

                    final isAnswerChecked = gameState.isAnswerChecked;
                    final isCorrect = option.trim().toLowerCase() == question.correctAnswer.trim().toLowerCase();
                    final isSelected = gameState.selectedAnswer?.trim().toLowerCase() == option.trim().toLowerCase();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BossAnswerOption(
                        option: option,
                        index: idx,
                        isAnswerChecked: isAnswerChecked,
                        isCorrect: isCorrect,
                        isSelected: isSelected,
                        themeColor: themeColor,
                        onTap: isAnswerChecked ? () {} : () => _selectAnswer(context, ref, option),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Show explanation panel
          if (gameState.isAnswerChecked)
            _ExplanationPanel(
              isCorrect: gameState.isCurrentAnswerCorrect ?? false,
              explanation: question.explanation,
              isLast: gameState.isLastQuestion,
              onContinue: () => _handleContinue(context, ref),
            ),
        ],
      ),
    );
  }

  void _selectAnswer(BuildContext context, WidgetRef ref, String answer) {
    ref.read(gameProvider.notifier).selectAnswer(answer);
    ref.read(gameProvider.notifier).checkAnswer();
    final isCorrect = ref.read(gameProvider).isCurrentAnswerCorrect ?? false;
    if (isCorrect) {
      ref.read(scoreProvider.notifier).addCorrect();
      HapticFeedback.lightImpact();
    } else {
      ref.read(scoreProvider.notifier).addWrong();
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _handleContinue(BuildContext context, WidgetRef ref) async {
    await ref.read(gameProvider.notifier).continueToNext();
    final gameState = ref.read(gameProvider);
    if (gameState.isGameOver) {
      ref.read(timerProvider.notifier).resetTimer();
      ref.read(statisticsProvider.notifier).refresh();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ResultScreen(
        score: gameState.lastResult?.score ?? 0,
        correctAnswers: gameState.lastResult?.correctAnswers ?? 0,
        wrongAnswers: gameState.lastResult?.wrongAnswers ?? 0,
        earnedXP: gameState.lastResult?.earnedXP ?? 0,
        earnedCoins: gameState.lastResult?.earnedCoins ?? 0,
      )));
    }
  }
}

class _BossAnswerOption extends StatelessWidget {
  final String option;
  final int index;
  final bool isAnswerChecked;
  final bool isCorrect;
  final bool isSelected;
  final Color themeColor;
  final VoidCallback onTap;

  const _BossAnswerOption({
    required this.option,
    required this.index,
    required this.isAnswerChecked,
    required this.isCorrect,
    required this.isSelected,
    required this.themeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final letters = ['A', 'B', 'C', 'D'];

    Color cardBgColor = theme.cardColor;
    Color borderColor = themeColor;
    double borderWidth = 2.0;
    Widget? suffixIcon;
    Color letterBgColor = themeColor;
    Color letterTextColor = Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    if (isAnswerChecked) {
      if (isCorrect) {
        cardBgColor = isDark ? Colors.green.withOpacity(0.15) : Colors.green.shade50;
        borderColor = Colors.green;
        letterBgColor = Colors.green;
        textColor = isDark ? Colors.white : Colors.green.shade900;
        suffixIcon = const Icon(Icons.check_circle, color: Colors.green, size: 24);
      } else if (isSelected) {
        cardBgColor = isDark ? Colors.red.withOpacity(0.15) : Colors.red.shade50;
        borderColor = Colors.red;
        letterBgColor = Colors.red;
        textColor = isDark ? Colors.white : Colors.red.shade900;
        suffixIcon = const Icon(Icons.cancel, color: Colors.red, size: 24);
      } else {
        cardBgColor = (isDark ? theme.cardColor : Colors.grey.shade100).withOpacity(0.6);
        borderColor = AppColors.borderLight.withOpacity(0.4);
        letterBgColor = isDark ? Colors.white12 : Colors.grey.shade300;
        letterTextColor = Colors.grey;
        textColor = Colors.grey;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: isAnswerChecked && (isCorrect || isSelected)
            ? [
                BoxShadow(
                  color: (isCorrect ? Colors.green : Colors.red).withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAnswerChecked ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: letterBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      letters[index],
                      style: TextStyle(
                        color: letterTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    option,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: isAnswerChecked && (isCorrect || isSelected) ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
                if (suffixIcon != null) ...[
                  const SizedBox(width: 12),
                  suffixIcon,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExplanationPanel extends StatelessWidget {
  final bool isCorrect;
  final String explanation;
  final VoidCallback onContinue;
  final bool isLast;

  const _ExplanationPanel({
    required this.isCorrect,
    required this.explanation,
    required this.onContinue,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isCorrect
        ? (isDark ? const Color(0xFF1E3A1E) : const Color(0xFFE8F5E9))
        : (isDark ? const Color(0xFF3A1E1E) : const Color(0xFFFFEBEE));

    final textColor = isCorrect
        ? (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32))
        : (isDark ? const Color(0xFFE57373) : const Color(0xFFC62828));

    final icon = isCorrect ? Icons.check_circle_outline : Icons.error_outline;
    final title = isCorrect ? 'অসাধারণ! সঠিক উত্তর' : 'ভুল উত্তর হয়েছে';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isCorrect
                ? (isDark ? Colors.green.withOpacity(0.3) : Colors.green.shade200)
                : (isDark ? Colors.red.withOpacity(0.3) : Colors.red.shade200),
            width: 1.5,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: textColor, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'বিস্তারিত ব্যাখ্যা:',
                      style: TextStyle(
                        color: textColor.withOpacity(0.85),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      explanation,
                      style: TextStyle(
                        color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCorrect ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onContinue,
                child: Text(
                  isLast ? 'ফলাফল দেখুন' : 'পরবর্তী প্রশ্ন',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}