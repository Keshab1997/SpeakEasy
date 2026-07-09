import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/daily_quiz_provider.dart';
import '../models/daily_quiz_model.dart';

/// Post-completion review screen.
///
/// Shows every question the student attempted today along with what they
/// answered, the correct answer, and the explanation — so they can learn from
/// both mistakes and correct picks. Accessible only for today's completed quiz
/// via the "Review & Learn" button on the result screen.
class DailyQuizReviewScreen extends ConsumerWidget {
  const DailyQuizReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quiz = ref.watch(dailyQuizProvider).quiz;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (quiz == null || quiz.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('📖 Quiz Review'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text('No quiz data available to review.'),
        ),
      );
    }

    // Build a lookup of answers by questionId for O(1) matching.
    final answerById = <String, DailyQuizAnswer>{
      for (final a in quiz.answers) a.questionId: a,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('📖 Quiz Review'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppColors.backgroundDark, AppColors.surfaceDark]
                : [AppColors.backgroundLight, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review your answers and learn from each question.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 16),
              ...quiz.questions.asMap().entries.map((entry) {
                final index = entry.key;
                final question = entry.value;
                final answer = answerById[question.id];
                return _ReviewQuestionCard(
                  index: index,
                  question: question,
                  answer: answer,
                  isDark: isDark,
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single question's review card.
class _ReviewQuestionCard extends StatelessWidget {
  final int index;
  final DailyQuizQuestion question;
  final DailyQuizAnswer? answer;
  final bool isDark;

  const _ReviewQuestionCard({
    required this.index,
    required this.question,
    required this.answer,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = answer?.isCorrect ?? false;
    final answered = answer != null;

    final correctText = _optionText(question, question.correctAnswer);
    final selectedText = answer?.selectedAnswer != null
        ? _optionText(question, answer!.selectedAnswer!)
        : 'Not answered';

    // Header colors
    final statusColor = isCorrect ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect
              ? AppColors.success.withOpacity(0.35)
              : AppColors.error.withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: number + status
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                isCorrect ? 'Correct' : (answered ? 'Wrong' : 'Skipped'),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (answer != null)
                Text(
                  '${answer!.timeTaken}s',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Question text
          Text(
            question.question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // Your answer row
          _AnswerRow(
            label: 'Your answer',
            text: selectedText,
            color: isCorrect ? AppColors.success : AppColors.error,
            icon: isCorrect ? Icons.check : Icons.close,
          ),
          const SizedBox(height: 8),

          // Correct answer row (only if wrong or skipped)
          if (!isCorrect)
            _AnswerRow(
              label: 'Correct answer',
              text: correctText,
              color: AppColors.success,
              icon: Icons.check,
            ),
          const SizedBox(height: 12),

          // Explanation
          if (question.explanation.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withOpacity(0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: AppColors.info,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question.explanation,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: isDark
                            ? Colors.white.withOpacity(0.9)
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Resolve the displayed text for an option index, handling complex types
  /// where `selectedAnswer` is an index into [options] when available, or
  /// falls back to a readable description.
  String _optionText(DailyQuizQuestion q, int index) {
    if (q.options.isNotEmpty && index >= 0 && index < q.options.length) {
      return q.options[index];
    }
    return 'Option ${index + 1}';
  }
}

/// A labelled answer row (e.g. "Your answer: ...").
class _AnswerRow extends StatelessWidget {
  final String label;
  final String text;
  final Color color;
  final IconData icon;

  const _AnswerRow({
    required this.label,
    required this.text,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label:  ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  TextSpan(
                    text: text,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
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
