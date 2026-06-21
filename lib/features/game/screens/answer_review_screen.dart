import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/game/game_provider.dart';
import '../../../providers/game/score_provider.dart';

class AnswerReviewScreen extends ConsumerWidget {
  const AnswerReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final scoreState = ref.watch(scoreProvider);
    final theme = Theme.of(context);

    if (gameState.questions.isEmpty || gameState.userAnswers.isEmpty) {
      return const Scaffold(body: Center(child: Text('No answers to review')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Answer Review', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Summary Header
          Container(
            padding: const EdgeInsets.all(20),
            color: AppColors.primary,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryItem(label: 'Correct', value: '${scoreState.correctCount}', color: AppColors.success),
                _SummaryItem(label: 'Wrong', value: '${scoreState.wrongCount}', color: AppColors.error),
                _SummaryItem(label: 'Score', value: '${scoreState.currentScore}', color: Colors.white),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: gameState.questions.length,
              itemBuilder: (context, index) {
                final question = gameState.questions[index];
                final userAnswer = index < gameState.userAnswers.length ? gameState.userAnswers[index] : '';
                final isCorrect = userAnswer == question.correctAnswer;

                return _QuestionReviewCard(
                  questionNumber: index + 1,
                  question: question,
                  userAnswer: userAnswer,
                  isCorrect: isCorrect,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _QuestionReviewCard extends StatelessWidget {
  final int questionNumber;
  final dynamic question;
  final String userAnswer;
  final bool isCorrect;

  const _QuestionReviewCard({
    required this.questionNumber,
    required this.question,
    required this.userAnswer,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect ? AppColors.success : AppColors.error,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isCorrect ? AppColors.success : AppColors.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isCorrect ? 'Correct' : 'Wrong',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Text('Q$questionNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question.question,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          if (userAnswer.isNotEmpty) ...[
            _AnswerRow(label: 'Your Answer', answer: userAnswer, isCorrect: isCorrect),
          ],
          _AnswerRow(
            label: 'Correct Answer',
            answer: question.correctAnswer,
            isCorrect: true,
            isHighlighted: true,
          ),
          if (question.explanation != null && question.explanation!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question.explanation!,
                      style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  final String label;
  final String answer;
  final bool isCorrect;
  final bool isHighlighted;

  const _AnswerRow({
    required this.label,
    required this.answer,
    required this.isCorrect,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            color: isCorrect ? AppColors.success : AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  TextSpan(
                    text: answer,
                    style: TextStyle(
                      color: isHighlighted ? AppColors.success : null,
                      fontWeight: isHighlighted ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}