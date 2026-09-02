import 'package:flutter/material.dart';
import '../models/battle_models.dart';

class BattleAnswerReviewScreen extends StatelessWidget {
  final List<BattleQuestion> questions;
  final Map<String, int> userAnswers;
  final Map<String, int> opponentAnswers;
  final String opponentName;
  final bool opponentIsBot;

  const BattleAnswerReviewScreen({
    super.key,
    required this.questions,
    required this.userAnswers,
    required this.opponentAnswers,
    required this.opponentName,
    this.opponentIsBot = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    int correctCount = 0;
    for (int i = 0; i < questions.length; i++) {
      final ans = userAnswers[i.toString()];
      if (ans != null && ans == questions[i].correctAnswer) {
        correctCount++;
      }
    }
    final wrongCount = questions.length - correctCount;
    final accuracy = questions.isNotEmpty
        ? ((correctCount / questions.length) * 100).toStringAsFixed(0)
        : '0';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          '📝 Question Review',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
      ),
      body: questions.isEmpty
          ? Center(
              child: Text(
                'No questions available to review.',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 16,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              physics: const BouncingScrollPhysics(),
              children: [
                // ── Top Summary Header Card ──
                _buildSummaryCard(
                  isDark: isDark,
                  total: questions.length,
                  correct: correctCount,
                  wrong: wrongCount,
                  accuracy: accuracy,
                ),
                const SizedBox(height: 20),

                // ── Section Title ──
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.quiz_rounded, size: 18, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 8),
                      Text(
                        'ROUND BY ROUND BREAKDOWN',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Questions List ──
                ...List.generate(questions.length, (index) {
                  final q = questions[index];
                  final userChoice = userAnswers[index.toString()];
                  final opponentChoice = opponentAnswers[index.toString()];
                  return _buildQuestionReviewCard(
                    roundIndex: index,
                    question: q,
                    userChoice: userChoice,
                    opponentChoice: opponentChoice,
                    isDark: isDark,
                    theme: theme,
                  );
                }),

                const SizedBox(height: 12),

                // ── Back Button ──
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Back to Results 🏆'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildSummaryCard({
    required bool isDark,
    required int total,
    required int correct,
    required int wrong,
    required String accuracy,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: correct >= 3
              ? [const Color(0xFF065F46), const Color(0xFF047857), const Color(0xFF059669)]
              : [const Color(0xFF1E1B4B), const Color(0xFF312E81), const Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (correct >= 3 ? const Color(0xFF059669) : const Color(0xFF4338CA))
                .withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  correct >= 3 ? '🎯' : '💡',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      correct >= 4
                          ? 'Outstanding Performance!'
                          : (correct >= 3 ? 'Good Effort!' : 'Keep Practicing!'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Review the correct answers and detailed explanations below.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric('Total', '$total', Colors.white),
              _buildMetric('Correct', '$correct', const Color(0xFF34D399)),
              _buildMetric('Mistakes', '$wrong', const Color(0xFFF87171)),
              _buildMetric('Accuracy', '$accuracy%', const Color(0xFFFBBF24)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildQuestionReviewCard({
    required int roundIndex,
    required BattleQuestion question,
    required int? userChoice,
    required int? opponentChoice,
    required bool isDark,
    required ThemeData theme,
  }) {
    final isCorrect = userChoice != null && userChoice == question.correctAnswer;
    final isUnanswered = userChoice == null;
    final statusColor = isCorrect
        ? const Color(0xFF10B981)
        : (isUnanswered ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Round & Status ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(19),
                topRight: Radius.circular(19),
              ),
              border: Border(
                bottom: BorderSide(
                  color: statusColor.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ROUND ${roundIndex + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    question.category.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      isCorrect
                          ? Icons.check_circle_rounded
                          : (isUnanswered ? Icons.timer_off_outlined : Icons.cancel_rounded),
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isCorrect
                          ? 'Correct'
                          : (isUnanswered ? 'Time Out' : 'Incorrect'),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Question Body ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.question,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
                if (question.bangla.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    question.bangla,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontFamily: 'NotoSansBengali',
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Options List ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: List.generate(question.options.length, (optIndex) {
                return _buildOptionRow(
                  optIndex: optIndex,
                  optionText: question.options[optIndex],
                  correctIndex: question.correctAnswer,
                  userChoice: userChoice,
                  opponentChoice: opponentChoice,
                  isDark: isDark,
                );
              }),
            ),
          ),

          const SizedBox(height: 12),

          // ── Explanation Box ──
          if (question.explanation.trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_rounded, color: Color(0xFFF59E0B), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Explanation / ব্যাখ্যা:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    question.explanation,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      fontFamily: 'NotoSansBengali',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionRow({
    required int optIndex,
    required String optionText,
    required int correctIndex,
    required int? userChoice,
    required int? opponentChoice,
    required bool isDark,
  }) {
    final isCorrect = optIndex == correctIndex;
    final isUserPick = userChoice == optIndex;
    final isOpponentPick = opponentChoice == optIndex;

    Color bgColor = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC);
    Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    Color textColor = isDark ? Colors.white70 : const Color(0xFF334155);
    Color badgeColor = Colors.grey;

    if (isCorrect) {
      bgColor = const Color(0xFF10B981).withValues(alpha: isDark ? 0.20 : 0.12);
      borderColor = const Color(0xFF10B981);
      textColor = const Color(0xFF10B981);
      badgeColor = const Color(0xFF10B981);
    } else if (isUserPick && !isCorrect) {
      bgColor = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.20 : 0.12);
      borderColor = const Color(0xFFEF4444);
      textColor = const Color(0xFFEF4444);
      badgeColor = const Color(0xFFEF4444);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: (isCorrect || isUserPick) ? 1.8 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Letter Badge (A, B, C, D)
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: badgeColor, width: 1.2),
            ),
            child: Center(
              child: Text(
                String.fromCharCode(65 + optIndex),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: badgeColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Option Text
          Expanded(
            child: Text(
              optionText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: (isCorrect || isUserPick) ? FontWeight.bold : FontWeight.w500,
                color: textColor,
                fontFamily: 'NotoSansBengali',
              ),
            ),
          ),

          // Indicators
          if (isCorrect)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 12, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    'Correct',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          if (isUserPick && !isCorrect) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close, size: 12, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    'Your Choice',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isOpponentPick) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: "$opponentName's choice",
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.purple, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, size: 11, color: Colors.purple),
                    const SizedBox(width: 2),
                    Text(
                      opponentName.length > 7
                          ? '${opponentName.substring(0, 6)}…'
                          : opponentName,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
