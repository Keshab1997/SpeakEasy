import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/game/game_question_model.dart';
import '../../../providers/game/game_provider.dart';
import '../../../repositories/wrong_question_repository.dart';
import '../../../models/game/wrong_question_model.dart';
import 'game_home_screen.dart';

class AnswerReviewScreen extends ConsumerStatefulWidget {
  const AnswerReviewScreen({super.key});

  @override
  ConsumerState<AnswerReviewScreen> createState() => _AnswerReviewScreenState();
}

class _AnswerReviewScreenState extends ConsumerState<AnswerReviewScreen> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final theme = Theme.of(context);

    // Collect only the WRONG questions from gameProvider
    final wrongEntriesFromGame = <_WrongEntry>[];
    for (int i = 0; i < gameState.questions.length; i++) {
      if (i >= gameState.userAnswers.length) break;
      final question = gameState.questions[i];
      final userAnswer = gameState.userAnswers[i];
      final isCorrect = question.correctAnswer.trim().toLowerCase() ==
          userAnswer.trim().toLowerCase();
      if (!isCorrect) {
        wrongEntriesFromGame.add(_WrongEntry(
          index: i,
          question: question,
          userAnswer: userAnswer,
        ));
      }
    }

    // Also check WrongQuestionRepository for special game modes
    final repo = WrongQuestionRepository();
    final recentWrongs = repo.getRecentWrongQuestions(limit: 50);
    
    // If gameProvider is empty but we have recent wrongs, use those
    final wrongEntries = wrongEntriesFromGame.isEmpty && recentWrongs.isNotEmpty
        ? recentWrongs.map((wq) => _WrongEntry(
              index: 0,
              question: GameQuestionModel(
                id: wq.id,
                question: wq.question,
                options: wq.decodedOptions,
                correctAnswer: wq.correctAnswer,
                explanation: wq.explanation,
                tenseType: wq.tenseType,
                difficulty: wq.difficulty,
                mode: wq.mode,
              ),
              userAnswer: wq.userAnswer,
            ))
            .toList()
        : wrongEntriesFromGame;

    final totalQuestions = gameState.questions.isNotEmpty 
        ? gameState.questions.length 
        : wrongEntries.length;
    final totalWrong = wrongEntries.length;
    final totalCorrect = totalQuestions - totalWrong;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Answer Review', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.error, height: 3),
        ),
      ),
      body: Column(
        children: [
          // ── Summary Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: totalWrong == 0
                    ? [AppColors.success, Colors.green.shade400]
                    : [Colors.orange.shade600, Colors.red.shade400],
              ),
            ),
            child: Column(
              children: [
                Text(
                  totalWrong == 0
                      ? '🎉 All Correct! No mistakes to review.'
                      : 'You got $totalWrong out of $totalQuestions wrong',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryItem(label: 'Correct', value: '$totalCorrect', color: Colors.white),
                    _SummaryItem(label: 'Wrong', value: '$totalWrong', color: Colors.yellow.shade200),
                    _SummaryItem(label: 'Accuracy', value: '${totalQuestions > 0 ? ((totalCorrect / totalQuestions) * 100).toStringAsFixed(0) : 0}%', color: Colors.white),
                  ],
                ),
              ],
            ),
          ),

          // ── Wrong Questions List ──
          Expanded(
            child: totalWrong == 0
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events, size: 80, color: AppColors.success),
                        SizedBox(height: 16),
                        Text('Perfect Score!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('No wrong answers to review.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: wrongEntries.length,
                    itemBuilder: (context, index) {
                      return _WrongQuestionCard(
                        entry: wrongEntries[index],
                        questionNumber: index + 1,
                      );
                    },
                  ),
          ),

          // ── Bottom Buttons ──
          if (totalWrong > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveAndGoHome,
                      icon: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.bookmark_add),
                      label: const Text('Save & Go Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Save these mistakes to review later from the Wrong Questions Bank.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Save wrong questions to Hive, then go home.
  Future<void> _saveAndGoHome() async {
    setState(() => _isSaving = true);

    final gameState = ref.read(gameProvider);
    final repo = WrongQuestionRepository();

    final wrongs = <WrongQuestionModel>[];
    for (int i = 0; i < gameState.questions.length; i++) {
      if (i >= gameState.userAnswers.length) break;
      final q = gameState.questions[i];
      final userAnswer = gameState.userAnswers[i];
      final isCorrect = q.correctAnswer.trim().toLowerCase() == userAnswer.trim().toLowerCase();
      if (!isCorrect) {
        wrongs.add(WrongQuestionModel.fromGameQuestion(
          questionId: q.id,
          tenseType: q.tenseType,
          question: q.question,
          options: q.options,
          correctAnswer: q.correctAnswer,
          explanation: q.explanation,
          userAnswer: userAnswer,
          difficulty: q.difficulty,
          mode: q.mode,
        ));
      }
    }

    await repo.saveWrongQuestions(wrongs);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Wrong answers saved for review!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const GameHomeScreen()), (route) => false);
    }
  }
}

// ── Data holder ──

class _WrongEntry {
  final int index;
  final GameQuestionModel question;
  final String userAnswer;
  const _WrongEntry({required this.index, required this.question, required this.userAnswer});
}

// ── Widgets ──

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

class _WrongQuestionCard extends StatelessWidget {
  final _WrongEntry entry;
  final int questionNumber;

  const _WrongQuestionCard({required this.entry, required this.questionNumber});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = entry.question;
    final userAnswer = entry.userAnswer;
    final correctAnswer = q.correctAnswer;

    // Generate a "why wrong" message
    final whyWrong = _generateWhyWrong(q, userAnswer, correctAnswer);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.red.withAlpha(25), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(20),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('✗ Wrong', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Text(
                  'Question $questionNumber',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Text(
                    q.tenseType,
                    style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // ── Question ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              q.question,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Your Wrong Answer ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withAlpha(80)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cancel, color: AppColors.error, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: [
                        const TextSpan(text: 'Your Answer: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                        TextSpan(
                          text: userAnswer,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Correct Answer ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withAlpha(80)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: [
                        const TextSpan(text: 'Correct Answer: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                        TextSpan(
                          text: correctAnswer,
                          style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Why Wrong ──
          if (whyWrong.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.help_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium,
                        children: [
                          const TextSpan(text: 'Why this is wrong: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                          TextSpan(text: whyWrong, style: const TextStyle(color: Color(0xFFE65100))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Explanation ──
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withAlpha(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text('Explanation', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  q.explanation,
                  style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Generate a contextual "why wrong" message based on the question data.
  String _generateWhyWrong(GameQuestionModel q, String userAnswer, String correctAnswer) {
    final user = userAnswer.trim().toLowerCase();

    if (user.isEmpty) {
      return 'You did not answer this question. The correct answer is "$correctAnswer".';
    }

    // Check if the user's answer is one of the other options (they picked the wrong one)
    if (q.options.any((o) => o.trim().toLowerCase() == user)) {
      // They selected a distractor — point out the difference
      return '"$userAnswer" is incorrect here. The right answer is "$correctAnswer". See the explanation below to understand the rule.';
    }

    // They typed something not in the options
    return '"$userAnswer" is not the correct answer. The right answer is "$correctAnswer".';
  }
}
