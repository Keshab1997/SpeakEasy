import 'package:flutter/material.dart';
import '../models/daily_quiz_model.dart';
import '../../../core/constants/app_colors.dart';

/// A Fill-in-the-Blanks question widget.
///
/// Shows the sentence with a highlighted blank and clickable word options.
/// Behaves like MCQ but visually emphasises the blank in the sentence.
class FillBlanksWidget extends StatelessWidget {
  final DailyQuizQuestion question;
  final int? selectedAnswer;
  final bool isAnswered;
  final ValueChanged<int> onAnswer;

  const FillBlanksWidget({
    super.key,
    required this.question,
    required this.selectedAnswer,
    required this.isAnswered,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Split the question text on "___" or "____" or "—"—" markers.
    final parts = question.question.split(RegExp(r'_+|—|---'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sentence with highlighted blank
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.primaryGradient),
            borderRadius: BorderRadius.circular(20),
          ),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: Colors.white,
              ),
              children: _buildSpans(parts),
            ),
          ),
        ),
        const SizedBox(height: 28),
        // Option pills
        ...List.generate(question.options.length, (i) {
          final isSelected = selectedAnswer == i;
          final isCorrectOption = isAnswered && i == question.correctAnswer;
          final isWrongOption = isAnswered && isSelected && !isCorrectOption;

          Color bgColor = isDark ? Colors.grey.shade800 : Colors.white;
          Color borderColor =
              isDark ? Colors.grey.shade600 : Colors.grey.shade300;
          Color textColor =
              isDark ? Colors.white : Colors.grey.shade800;
          IconData? suffixIcon;

          if (isAnswered) {
            if (isCorrectOption) {
              bgColor = isDark ? Colors.green.withOpacity(0.2) : Colors.green.shade50;
              borderColor = Colors.green;
              textColor = Colors.green.shade700;
              suffixIcon = Icons.check_circle;
            } else if (isWrongOption) {
              bgColor = isDark ? Colors.red.withOpacity(0.2) : Colors.red.shade50;
              borderColor = Colors.red;
              textColor = Colors.red.shade700;
              suffixIcon = Icons.cancel;
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: isAnswered ? null : () => onAnswer(i),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: borderColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        question.options[i],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (suffixIcon != null)
                      Icon(suffixIcon, color: textColor, size: 24),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  List<TextSpan> _buildSpans(List<String> parts) {
    if (parts.length <= 1) {
      // No blank marker found — show question as-is.
      return [TextSpan(text: question.question)];
    }
    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(text: parts[i].trim()));
      }
      if (i < parts.length - 1) {
        spans.add(const TextSpan(
          text: ' ______ ',
          style: TextStyle(
            decoration: TextDecoration.underline,
            decorationThickness: 2,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFD700), // gold
            fontSize: 20,
          ),
        ));
      }
    }
    return spans;
  }
}
