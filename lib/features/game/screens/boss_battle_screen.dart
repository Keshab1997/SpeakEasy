import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/game/game_provider.dart';
import '../../../providers/game/timer_provider.dart';
import '../../../providers/game/score_provider.dart';
import '../../../providers/game/xp_provider.dart';
import '../../../providers/game/coin_provider.dart';
import '../../../providers/game/sound_provider.dart';
import 'result_screen.dart';

class BossBattleScreen extends ConsumerWidget {
  const BossBattleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final timerState = ref.watch(timerProvider);
    final scoreState = ref.watch(scoreProvider);
    final theme = Theme.of(context);

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
                  backgroundColor: AppColors.error,
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
        backgroundColor: AppColors.error,
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
            color: AppColors.error,
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

          // Score Display
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.error.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BossStat(label: 'Score', value: '${scoreState.currentScore}', icon: Icons.star),
                _BossStat(label: 'Correct', value: '${scoreState.correctCount}', icon: Icons.check_circle, color: AppColors.success),
                _BossStat(label: 'Wrong', value: '${scoreState.wrongCount}', icon: Icons.cancel, color: AppColors.error),
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
                      gradient: LinearGradient(colors: [AppColors.error, AppColors.error.withOpacity(0.8)]),
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
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Text(
                      'HARD - ${question.tenseType}',
                      style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Options
                  ...question.options.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final option = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BossAnswerOption(
                        option: option,
                        index: idx,
                        onTap: () => _selectAnswer(context, ref, option),
                      ),
                    );
                  }),
                ],
              ),
            ),
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
      ref.read(soundProvider.notifier).playCorrect();
    } else {
      ref.read(scoreProvider.notifier).addWrong();
      ref.read(soundProvider.notifier).playWrong();
    }

    if (ref.read(gameProvider).isAnswerChecked && !ref.read(gameProvider).isGameOver) {
      ref.read(gameProvider.notifier).continueToNext();
    }

    if (ref.read(gameProvider).isGameOver) {
      ref.read(timerProvider.notifier).resetTimer();
      final gs = ref.read(gameProvider);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ResultScreen(
        score: gs.lastResult?.score ?? 0,
        correctAnswers: gs.lastResult?.correctAnswers ?? 0,
        wrongAnswers: gs.lastResult?.wrongAnswers ?? 0,
        earnedXP: gs.lastResult?.earnedXP ?? 0,
        earnedCoins: gs.lastResult?.earnedCoins ?? 0,
      )));
    }
  }
}

class _BossStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _BossStat({required this.label, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _BossAnswerOption extends StatelessWidget {
  final String option;
  final int index;
  final VoidCallback onTap;

  const _BossAnswerOption({required this.option, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final letters = ['A', 'B', 'C', 'D'];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  letters[index],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(option, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}