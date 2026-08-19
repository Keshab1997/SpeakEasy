import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/quiz_model.dart';

class ResultScreen extends StatelessWidget {
  final int score;
  final int total;
  final QuizModel quiz;
  final Map<int, int> answers;

  const ResultScreen({
    super.key,
    required this.score,
    required this.total,
    required this.quiz,
    required this.answers,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final percentage = (score / total * 100).round();
    final isPassed = percentage >= 60;

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Result', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPassed ? AppColors.secondary.withValues(alpha: 0.1) : Colors.redAccent.withValues(alpha: 0.1),
              ),
              child: Center(
                child: Icon(
                  isPassed ? Icons.emoji_events_rounded : Icons.replay_rounded,
                  color: isPassed ? AppColors.secondary : Colors.redAccent,
                  size: 56,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isPassed ? 'Congratulations!' : 'Keep Trying!',
              style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isPassed ? 'You passed the quiz!' : 'You need 60% to pass.',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPassed ? AppColors.secondaryGradient : [Colors.redAccent, Colors.orange],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Text(
                    '$score / $total',
                    style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$percentage% Score',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Review Answers', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...quiz.questions.asMap().entries.map((entry) {
              final idx = entry.key;
              final q = entry.value;
              final userAnswer = answers[idx];
              final isCorrect = userAnswer == q.correctIndex;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCorrect ? AppColors.secondary : Colors.redAccent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: isCorrect ? AppColors.secondary : Colors.redAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Q${idx + 1}: ${q.question}',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Your answer: ${userAnswer != null ? q.options[userAnswer] : 'Not answered'}',
                      style: TextStyle(color: isCorrect ? AppColors.secondary : Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 13)),
                    if (!isCorrect) ...[
                      const SizedBox(height: 4),
                      Text('Correct: ${q.options[q.correctIndex]}',
                        style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Back to Quizzes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
