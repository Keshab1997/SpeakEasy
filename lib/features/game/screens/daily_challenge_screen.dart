import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/game/game_provider.dart';
import '../../../providers/game/timer_provider.dart';
import '../../../providers/game/score_provider.dart';
import '../../../providers/game/xp_provider.dart';
import '../../../providers/game/coin_provider.dart';
import '../../../providers/game/streak_provider.dart';
import '../../../providers/game/sound_provider.dart';
import 'result_screen.dart';

class DailyChallengeScreen extends ConsumerWidget {
  const DailyChallengeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final timerState = ref.watch(timerProvider);
    final scoreState = ref.watch(scoreProvider);
    final streakState = ref.watch(streakProvider);
    final theme = Theme.of(context);

    // Start daily challenge on first build
    ref.listen<GameState>(gameProvider, (previous, next) {
      if (previous?.questions.isEmpty ?? true && next.questions.isNotEmpty) {
        ref.read(timerProvider.notifier).startStandardGame();
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
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: AppColors.primaryGradient),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.today, color: Colors.white, size: 60),
              ),
              const SizedBox(height: 24),
              Text('Daily Challenge', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text('Complete today\'s challenge to earn bonus rewards!', 
                  style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(streakState.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text('${streakState.currentStreak} day streak', 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  ref.read(gameProvider.notifier).loadQuestions(
                    difficulty: 'intermediate',
                    limit: 15,
                    gameType: 'daily_challenge',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Start Daily Challenge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Maybe Later'),
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
        title: const Text('Daily Challenge', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  timerState.formattedTime,
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Section
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primary,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Question ${gameState.currentQuestionIndex + 1}/${gameState.totalQuestions}', 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('Score: ${scoreState.currentScore}', style: const TextStyle(color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white30,
                    color: Colors.white,
                    minHeight: 6,
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
                  // Daily Bonus Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.amber, Colors.orange]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Daily Bonus Active!', 
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              Text('+50% XP & Coins', 
                                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Question Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(question.tenseType, 
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          question.question,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Options
                  ...question.options.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final option = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DailyAnswerOption(
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

class _DailyAnswerOption extends StatelessWidget {
  final String option;
  final int index;
  final VoidCallback onTap;

  const _DailyAnswerOption({required this.option, required this.index, required this.onTap});

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
          gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  letters[index],
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(option, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}