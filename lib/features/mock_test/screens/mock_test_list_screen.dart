import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeleton_widget.dart';
import '../../../providers/mock_test_provider.dart';
import 'mock_test_quiz_screen.dart';
import '../widgets/mock_test_unlock_overlay.dart';

class MockTestListScreen extends ConsumerStatefulWidget {
  const MockTestListScreen({super.key});

  @override
  ConsumerState<MockTestListScreen> createState() => _MockTestListScreenState();
}

class _MockTestListScreenState extends ConsumerState<MockTestListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(mockTestProvider.notifier).loadTests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mockTestProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.assignment_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 10),
            Text('Mock Tests', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
      body: state.isLoading
          ? ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              itemBuilder: (_, __) => const SkeletonListTile(),
            )
          : state.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text('Error loading tests', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(state.error!, textAlign: TextAlign.center,
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => ref.read(mockTestProvider.notifier).loadTests(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(context, isDark, state),
    );
  }

  void _showUnlockOverlay(BuildContext context, int testNumber, String testTitle) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MockTestUnlockOverlay(
        testNumber: testNumber,
        testTitle: testTitle,
        onUnlocked: () {
          Navigator.of(ctx).pop(); // close overlay
          // Navigate to the quiz now that it's unlocked
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MockTestQuizScreen(
                testNumber: testNumber,
                testTitle: testTitle,
              ),
            ),
          );
        },
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, MockTestState state) {
    final tests = state.allTests;
    final progress = state.progress;
    final completed = ref.read(mockTestProvider.notifier).getTotalCompleted();
    final perfect = ref.read(mockTestProvider.notifier).getTotalPerfectScores();

    return Column(
      children: [
        // ── Stats Header ──
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.primaryGradient),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStat(Icons.check_circle_rounded, '$completed/70', 'Completed', Colors.greenAccent),
                  Container(width: 1, height: 40, color: Colors.white24),
                  _buildStat(Icons.emoji_events_rounded, '$perfect', 'Perfect', Colors.amber),
                  Container(width: 1, height: 40, color: Colors.white24),
                  _buildStat(Icons.lock_open_rounded, '${progress.highestUnlockedTest}/70', 'Unlocked', Colors.white),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: completed / 70,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(completed / 70 * 100).round()}% Complete',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),

        // ── Test List ──
        Expanded(
          child: tests.isEmpty
              ? const Center(child: Text('No mock tests available.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: tests.length,
                  itemBuilder: (context, index) {
                    final test = tests[index];
                    final unlocked = ref.read(mockTestProvider.notifier).isTestUnlocked(test.testNumber);
                    final completed = ref.read(mockTestProvider.notifier).isTestCompleted(test.testNumber);
                    final bestScore = ref.read(mockTestProvider.notifier).getBestScore(test.testNumber);
                    final perfect = bestScore == 20;

                    return _buildTestCard(context, isDark, test, unlocked, completed, bestScore, perfect);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
      ],
    );
  }

  Widget _buildTestCard(
    BuildContext context,
    bool isDark,
    dynamic test,
    bool unlocked,
    bool completed,
    int bestScore,
    bool perfect,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (unlocked) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MockTestQuizScreen(
                    testNumber: test.testNumber,
                    testTitle: test.title,
                  ),
                ),
              );
            } else {
              _showUnlockOverlay(context, test.testNumber, test.title);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: perfect
                    ? AppColors.secondary
                    : (unlocked
                        ? (isDark ? AppColors.borderDark : AppColors.borderLight)
                        : Colors.grey.withOpacity(0.2)),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Test number indicator
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: unlocked
                        ? (perfect
                            ? const LinearGradient(colors: [AppColors.secondary, Color(0xFF00BFA5)])
                            : const LinearGradient(colors: AppColors.primaryGradient))
                        : LinearGradient(
                            colors: [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.1)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: unlocked
                        ? (perfect
                            ? const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 22)
                            : Text(
                                '${test.testNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ))
                        : const Icon(Icons.lock_rounded, color: Colors.grey, size: 20),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        test.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: unlocked ? null : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        unlocked
                            ? (completed
                                ? 'Best: $bestScore/20 ${perfect ? '🎉' : ''}'
                                : '${test.questions.length} questions • Ready')
                            : (test.testNumber == 1
                                ? 'Always unlocked'
                                : 'Tap to unlock 🪙'),
                        style: TextStyle(
                          fontSize: 12,
                          color: perfect
                              ? AppColors.secondary
                              : (unlocked ? (isDark ? Colors.white60 : Colors.black54) : Colors.grey),
                          fontWeight: perfect ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: perfect
                          ? AppColors.secondary.withOpacity(0.15)
                          : AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          perfect ? Icons.replay_rounded : Icons.play_arrow_rounded,
                          color: perfect ? AppColors.secondary : AppColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          perfect ? 'Retry' : 'Start',
                          style: TextStyle(
                            color: perfect ? AppColors.secondary : AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
