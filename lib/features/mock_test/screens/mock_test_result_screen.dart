import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/mock_test_model.dart';
import '../../../providers/mock_test_provider.dart';
import '../widgets/mock_test_unlock_overlay.dart';
import 'mock_test_quiz_screen.dart';
import 'mock_test_list_screen.dart';

// ignore_for_file: prefer_const_constructors

class MockTestResultScreen extends ConsumerStatefulWidget {
  final int testNumber;
  final String testTitle;
  final int score;
  final int total;
  final List<MockTestQuestion> questions;

  /// questionIndex → user-এর selected shuffledOptionIndex
  final Map<int, int> answers;

  /// questionIndex → shuffled option text list (review তে দেখানোর জন্য)
  final Map<int, List<String>>? shuffledOptionsMap;

  /// questionIndex → shuffle-এর পর correct option এর index
  final Map<int, int>? shuffledCorrectIndexMap;

  const MockTestResultScreen({
    super.key,
    required this.testNumber,
    required this.testTitle,
    required this.score,
    required this.total,
    required this.questions,
    required this.answers,
    this.shuffledOptionsMap,
    this.shuffledCorrectIndexMap,
  });

  @override
  ConsumerState<MockTestResultScreen> createState() => _MockTestResultScreenState();
}

class _MockTestResultScreenState extends ConsumerState<MockTestResultScreen> {
  bool _showCelebration = false;

  @override
  void initState() {
    super.initState();
    if (widget.score == widget.total) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _showCelebration = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final percentage = (widget.score / widget.total * 100).round();
    final isPerfect = widget.score == widget.total;
    final nextTestNumber = widget.testNumber + 1;
    final nextTestUnlocked = nextTestNumber <= 70 &&
        ref.read(mockTestProvider.notifier).isTestUnlocked(nextTestNumber);
    final totalCompleted =
        ref.read(mockTestProvider.notifier).getTotalCompleted();

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Test Result', style: TextStyle(fontWeight: FontWeight.bold)),
            leading: IconButton(
              icon: const Icon(Icons.home_rounded),
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MockTestListScreen()),
                (route) => false,
              ),
              tooltip: 'Back to Test List',
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // ── Score Circle ──
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isPerfect
                        ? const LinearGradient(colors: [AppColors.secondary, Color(0xFF00BFA5)])
                        : const LinearGradient(colors: [Colors.orange, Colors.redAccent]),
                    boxShadow: [
                      BoxShadow(
                        color: (isPerfect ? AppColors.secondary : Colors.orange).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.score}',
                          style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '/ ${widget.total}',
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Title ──
                Text(
                  widget.testTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // ── Percentage ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isPerfect ? AppColors.secondary : Colors.orange).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$percentage%',
                    style: TextStyle(
                      color: isPerfect ? AppColors.secondary : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Shuffle Badge ──
                if (widget.shuffledOptionsMap != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shuffle_rounded, size: 14, color: Colors.grey),
                        SizedBox(width: 6),
                        Text(
                          'Options were shuffled in this attempt',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                if (widget.shuffledOptionsMap != null) const SizedBox(height: 12),

                // ── Message ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isPerfect
                        ? AppColors.secondary.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isPerfect ? AppColors.secondary.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPerfect ? Icons.emoji_events_rounded : Icons.tips_and_updates_rounded,
                        color: isPerfect ? AppColors.secondary : Colors.orange,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isPerfect
                              ? '🎉 Perfect score! You have mastered this test. ${nextTestNumber <= 70 ? "Next test is now unlocked!" : "You have completed all tests!"}'
                              : 'You need ${widget.total}/${widget.total} to unlock the next test. Review your answers and try again!',
                          style: TextStyle(
                            color: isPerfect ? AppColors.secondary : Colors.orange,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Action Buttons ──
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isPerfect) ...[
                      // Retry Wrong button (only if there are wrong questions)
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MockTestQuizScreen(
                              testNumber: widget.testNumber,
                              testTitle: widget.testTitle,
                              wrongQuestionIndices: ref
                                  .read(mockTestProvider.notifier)
                                  .getWrongQuestions(widget.testNumber),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.replay_rounded),
                        label: Text(
                          'Retry Wrong (${20 - widget.score})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MockTestQuizScreen(
                                  testNumber: widget.testNumber,
                                  testTitle: widget.testTitle,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.replay_rounded),
                            label: Text(!isPerfect ? 'Retry All' : 'Retry'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        if (isPerfect && nextTestUnlocked && nextTestNumber <= 70) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MockTestQuizScreen(
                                    testNumber: nextTestNumber,
                                    testTitle: 'Mock Test $nextTestNumber',
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: const Text('Next Test'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!isPerfect) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const MockTestListScreen()),
                          (route) => false,
                        ),
                        icon: const Icon(Icons.list_rounded),
                        label: const Text('Back to Test List'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                // ── Answer Review ──
                Row(
                  children: [
                    Text('Review Answers', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(
                      '${widget.answers.length} of ${widget.total} answered',
                      style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...widget.questions.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final q = entry.value;

                  // Shuffle info থাকলে সেটা ব্যবহার করি, না হলে original use করি
                  final displayOptions = widget.shuffledOptionsMap != null
                      ? widget.shuffledOptionsMap![idx]!
                      : q.options;
                  final correctIdx = widget.shuffledCorrectIndexMap != null
                      ? widget.shuffledCorrectIndexMap![idx]!
                      : q.correctIndex;

                  final userAnswer = widget.answers[idx];
                  final isCorrect = userAnswer == correctIdx;

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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: (isCorrect ? AppColors.secondary : Colors.redAccent).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                color: isCorrect ? AppColors.secondary : Colors.redAccent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Q${idx + 1}: ${q.question}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_rounded, size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  const Text('Your answer: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  Expanded(
                                    child: Text(
                                      userAnswer != null ? displayOptions[userAnswer] : 'Not answered',
                                      style: TextStyle(
                                        color: isCorrect ? AppColors.secondary : Colors.redAccent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (!isCorrect) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.secondary),
                                    const SizedBox(width: 6),
                                    const Text('Correct: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    Expanded(
                                      child: Text(
                                        displayOptions[correctIdx],
                                        style: const TextStyle(
                                          color: AppColors.secondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (q.explanation != null && q.explanation!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.lightbulb_rounded, size: 14, color: Colors.amber),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        q.explanation!,
                                        style: TextStyle(
                                          color: isDark ? Colors.white70 : Colors.black54,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),

                // ── Bottom Action ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const MockTestListScreen()),
                      (route) => false,
                    ),
                    icon: const Icon(Icons.list_rounded),
                    label: const Text('Back to Test List'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // ── Celebration Overlay ──
        if (_showCelebration)
          MockTestUnlockOverlay(
            completedTestNumber: widget.testNumber,
            completedTestTitle: widget.testTitle,
            score: widget.score,
            total: widget.total,
            nextTestNumber: nextTestNumber,
            totalCompleted: totalCompleted,
            totalTests: 70,
            xpReward: widget.testNumber * 10,
            coinReward: widget.testNumber * 5,
            onTakeNextTest: () {
              setState(() => _showCelebration = false);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => MockTestQuizScreen(
                    testNumber: nextTestNumber,
                    testTitle: 'Mock Test $nextTestNumber',
                  ),
                ),
              );
            },
            onDismiss: () => setState(() => _showCelebration = false),
          ),
      ],
    );
  }
}
