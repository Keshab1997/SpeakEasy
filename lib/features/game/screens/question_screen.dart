import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/game/game_provider.dart';
import '../../../providers/game/timer_provider.dart';
import '../../../providers/game/score_provider.dart';
import '../../../providers/game/xp_provider.dart';
import '../../../providers/game/coin_provider.dart';
import '../../../providers/game/streak_provider.dart';
import '../../../providers/game/achievement_provider.dart';
import '../../../providers/game/sound_provider.dart';
import 'result_screen.dart';

class QuestionScreen extends ConsumerWidget {
  const QuestionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final timerState = ref.watch(timerProvider);
    final scoreState = ref.watch(scoreProvider);
    final theme = Theme.of(context);

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
              const Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('No questions available', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
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
        title: Text('Question ${gameState.currentQuestionIndex + 1}/${gameState.totalQuestions}'),
        actions: [
          if (timerState.isRunning || timerState.isPaused)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                timerState.formattedTime,
                style: TextStyle(
                  color: timerState.remainingSeconds < 10 ? Colors.red : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.cardColor,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Score: ${scoreState.currentScore}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${gameState.answeredCount}/${gameState.totalQuestions}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[300],
                    color: AppColors.primary,
                    minHeight: 4,
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
                      gradient: LinearGradient(colors: AppColors.primaryGradient),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      question.question,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600, height: 1.4),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tense Type Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Text(
                      question.tenseType,
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Options
                  ...question.options.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final option = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AnswerOption(
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

class _AnswerOption extends StatelessWidget {
  final String option;
  final int index;
  final VoidCallback onTap;

  const _AnswerOption({required this.option, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final letters = ['A', 'B', 'C', 'D'];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
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
              child: Text(option, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}