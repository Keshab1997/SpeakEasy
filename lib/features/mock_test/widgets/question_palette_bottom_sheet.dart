import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class QuestionPaletteBottomSheet extends StatelessWidget {
  final int totalQuestions;
  final int currentQuestion;
  final Map<int, int> answers;
  final ValueChanged<int> onQuestionSelected;

  const QuestionPaletteBottomSheet({
    super.key,
    required this.totalQuestions,
    required this.currentQuestion,
    required this.answers,
    required this.onQuestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final answeredCount = answers.length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Questions ($answeredCount/$totalQuestions answered)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: totalQuestions,
              itemBuilder: (context, index) {
                final isAnswered = answers.containsKey(index);
                final isCurrent = index == currentQuestion;

                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    onQuestionSelected(index);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedScale(
                    scale: isCurrent ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isAnswered
                            ? AppColors.primary
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight),
                          width: isCurrent ? 2.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isAnswered
                                ? Colors.white
                                : (isCurrent
                                    ? AppColors.primary
                                    : (isDark
                                        ? Colors.white70
                                        : Colors.black54)),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
