import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/game/game_provider.dart';
import '../../../../providers/game/sound_provider.dart';
import '../../../../services/sound_service.dart';
import '../../../../models/game/game_question_model.dart';
import '../mode_game_screen.dart';
import '../result_screen.dart';

class ChooseTenseMode extends ConsumerWidget {
  const ChooseTenseMode({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gameState = ref.watch(gameProvider);

    if (gameState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (gameState.error != null) {
      return Scaffold(
        body: Center(child: Text('Error: ${gameState.error}')),
      );
    }

    if (gameState.questions.isEmpty || gameState.currentQuestion == null) {
      return const Scaffold(body: Center(child: Text('No questions available')));
    }

    final question = gameState.currentQuestion!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Correct Tense', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          // Question
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.green, Colors.lightGreen]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select the correct tense:',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Text(
                  question.question,
                  style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.5),
                ),
              ],
            ),
          ),

          // Answer options or explanation
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: gameState.showExplanation && question.explanation != null
                  ? _buildExplanation(context, ref, question)
                  : _buildAnswerOptions(context, ref, question),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerOptions(BuildContext context, WidgetRef ref, GameQuestionModel question) {
    return ListView.builder(
      itemCount: question.options.length,
      itemBuilder: (context, index) {
        final option = question.options[index];
        final isSelected = ref.watch(gameProvider).selectedAnswer == option;
        final isCorrect = question.correctAnswer == option;
        final isWrong = isSelected && !isCorrect;
        final showResult = ref.watch(gameProvider).showExplanation;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: showResult ? null : () => _selectAnswer(context, ref, option),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: showResult && isCorrect
                      ? Colors.green
                      : showResult && isWrong
                          ? Colors.red
                          : isSelected
                              ? Colors.green
                              : Colors.green.withOpacity(0.3),
                  width: showResult && (isCorrect || isWrong) ? 3 : 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: showResult && isCorrect
                          ? Colors.green
                          : showResult && isWrong
                              ? Colors.red
                              : isSelected
                                  ? Colors.green
                                  : Colors.green.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: showResult && isCorrect
                          ? const Icon(Icons.check, color: Colors.white)
                          : showResult && isWrong
                              ? const Icon(Icons.close, color: Colors.white)
                              : Text(
                                  String.fromCharCode(65 + index),
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      option,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  if (showResult && isCorrect)
                    const Icon(Icons.check_circle, color: Colors.green, size: 24)
                  else if (showResult && isWrong)
                    const Icon(Icons.cancel, color: Colors.red, size: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExplanation(BuildContext context, WidgetRef ref, GameQuestionModel question) {
    final gameState = ref.watch(gameProvider);
    final isCorrect = gameState.isCurrentAnswerCorrect ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCorrect ? [Colors.green, Colors.green.withOpacity(0.8)] : [Colors.red, Colors.red.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                isCorrect ? 'Correct!' : 'Incorrect',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Explanation:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            question.explanation ?? 'No explanation available.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ref.read(gameProvider.notifier).continueToNext();
                ref.read(soundServiceProvider).playButtonTap();
                
                if (ref.read(gameProvider).isGameOver) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ResultScreen(
                        score: 0,
                        correctAnswers: 0,
                        wrongAnswers: 0,
                        earnedXP: 0,
                        earnedCoins: 0,
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: isCorrect ? Colors.green : Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectAnswer(BuildContext context, WidgetRef ref, String answer) {
    ref.read(gameProvider.notifier).selectAnswer(answer);
    ref.read(soundServiceProvider).playButtonTap();
  }
}