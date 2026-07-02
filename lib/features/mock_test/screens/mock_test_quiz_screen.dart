import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/mock_test_model.dart';
import '../../../providers/mock_test_provider.dart';
import '../widgets/question_palette_bottom_sheet.dart';
import 'mock_test_result_screen.dart';

/// একটি প্রশ্নের জন্য shuffled options ট্র্যাক রাখে
class _ShuffledQuestion {
  final List<String> shuffledOptions;
  final int shuffledCorrectIndex; // shuffle-এর পর correct option এর নতুন index

  _ShuffledQuestion({
    required this.shuffledOptions,
    required this.shuffledCorrectIndex,
  });
}

class MockTestQuizScreen extends ConsumerStatefulWidget {
  final int testNumber;
  final String testTitle;
  final List<int>? wrongQuestionIndices;

  const MockTestQuizScreen({
    super.key,
    required this.testNumber,
    required this.testTitle,
    this.wrongQuestionIndices,
  });

  @override
  ConsumerState<MockTestQuizScreen> createState() => _MockTestQuizScreenState();
}

class _MockTestQuizScreenState extends ConsumerState<MockTestQuizScreen> {
  int _currentQuestion = 0;
  int? _selectedAnswer;
  final Map<int, int> _answers = {}; // questionIndex -> selected shuffledOptionIndex
  bool _isSubmitting = false;

  // shuffle-এর পর প্রতিটি প্রশ্নের options ও correct index সংরক্ষণ
  late List<_ShuffledQuestion> _shuffledQuestions;
  late final PageController _pageController;

	MockTestModel? get _test {
    final tests = ref.read(mockTestListProvider);
    try {
      return tests.firstWhere((t) => t.testNumber == widget.testNumber);
    } catch (_) {
      return null;
    }
  }

  /// Questions to display — either all or only wrong ones
  List<MockTestQuestion> get _activeQuestions {
    final test = _test;
    if (test == null || test.questions.isEmpty) return [];
    if (widget.wrongQuestionIndices == null) return test.questions;
    return widget.wrongQuestionIndices!
        .map((i) => test.questions[i])
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _shuffledQuestions = [];
    _pageController = PageController();
    _shuffleAllQuestions();
  }

  /// প্রতিটি প্রশ্নের options shuffle করে এবং নতুন correctIndex ট্র্যাক করে
	void _shuffleAllQuestions() {
    final questions = _activeQuestions;
    if (questions.isEmpty) return;

    final random = Random();
    _shuffledQuestions = questions.map((q) {
      // options ও correctIndex নিয়ে একটি তালিকা তৈরি করি
      final List<_IndexedOption> indexedOptions = [];
      for (int i = 0; i < q.options.length; i++) {
        indexedOptions.add(_IndexedOption(text: q.options[i], originalIndex: i));
      }

      // তালিকাটি shuffle করি
      indexedOptions.shuffle(random);

      // shuffle-এর পর নতুন correctIndex খুঁজে বের করি
      int newCorrectIndex = 0;
      final List<String> shuffledTexts = [];
      for (int i = 0; i < indexedOptions.length; i++) {
        shuffledTexts.add(indexedOptions[i].text);
        if (indexedOptions[i].originalIndex == q.correctIndex) {
          newCorrectIndex = i;
        }
      }

      return _ShuffledQuestion(
        shuffledOptions: shuffledTexts,
        shuffledCorrectIndex: newCorrectIndex,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final test = _test;
    if (test == null || test.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.testTitle)),
        body: const Center(child: Text('Test questions not available.')),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
	    final questions = _activeQuestions;
	    if (questions.isEmpty) {
	      return Scaffold(
	        appBar: AppBar(title: Text(widget.testTitle)),
	        body: const Center(child: Text('No questions to retry.')),
	      );
	    }
	    final progress = (_currentQuestion + 1) / questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.testTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _isSubmitting
              ? null
              : () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Leave Test?'),
                      content: const Text('Your progress in this attempt will be lost.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Continue Test')),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                          },
                          child: const Text('Leave', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_view_rounded),
            onPressed: _isSubmitting
                ? null
                : () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => QuestionPaletteBottomSheet(
	                      totalQuestions: _activeQuestions.length,
                        currentQuestion: _currentQuestion,
                        answers: _answers,
                        onQuestionSelected: (index) {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Progress Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? AppColors.surfaceDark : Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question ${_currentQuestion + 1}/${questions.length}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shuffle_rounded, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Options shuffled',
                          style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_answers.length} answered',
                          style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                if (widget.wrongQuestionIndices != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Retrying ${widget.wrongQuestionIndices!.length} wrong questions',
                            style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    color: AppColors.primary,
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),

          // ── Question ──
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: questions.length,
              onPageChanged: (index) {
                setState(() {
                  _currentQuestion = index;
                  _selectedAnswer = _answers[index];
                });
              },
              itemBuilder: (context, index) {
                final question = questions[index];
                final shuffled = _shuffledQuestions[index];

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question number badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Q${index + 1}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Question text
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: AppColors.primaryGradient),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          question.question,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Shuffled Options
                      ...shuffled.shuffledOptions.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final option = entry.value;
                        final isSelected = _selectedAnswer == idx;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: _isSubmitting ? null : () => setState(() => _selectedAnswer = idx),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.1)
                                    : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                                  width: isSelected ? 2.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? AppColors.primary : Colors.grey,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        String.fromCharCode(65 + idx),
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.grey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Bottom Navigation ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              border: Border(
                top: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // Skip / Previous
                if (_currentQuestion > 0)
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            if (_selectedAnswer != null) {
                              _answers[_currentQuestion] = _selectedAnswer!;
                            }
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                    child: const Text('Previous'),
                  )
                else
                  const SizedBox.shrink(),

                const Spacer(),

                // Next / Submit
                SizedBox(
                  width: 160,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _selectedAnswer != null && !_isSubmitting
                        ? () async {
                            _answers[_currentQuestion] = _selectedAnswer!;
                            if (_currentQuestion < questions.length - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              await _submitQuiz();
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _currentQuestion < questions.length - 1 ? 'Next' : 'Submit',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

			  Future<void> _submitQuiz() async {
			    final test = _test;
			    if (test == null) {
			      if (!mounted) return;
			      Navigator.pop(context);
			      return;
			    }
			    setState(() => _isSubmitting = true);
		
		    final questions = _activeQuestions;
		    int correct = 0;
		    final List<int> currentWrongIndices = [];
		    for (final entry in _answers.entries) {
		      final questionIndex = entry.key;
		      final selectedShuffledIndex = entry.value;
		      if (selectedShuffledIndex == _shuffledQuestions[questionIndex].shuffledCorrectIndex) {
		        correct++;
		      } else {
		        // Track which question index (in original test) was wrong
		        if (widget.wrongQuestionIndices != null) {
		          currentWrongIndices.add(widget.wrongQuestionIndices![questionIndex]);
		        } else {
		          currentWrongIndices.add(questionIndex);
		        }
		      }
		    }
		
		    // Calculate score out of 20 and wrong indices to save
		    int scoreOutOf20;
		    List<int>? wrongIndicesToSave;
		    if (widget.wrongQuestionIndices != null) {
		      // Wrong-only retry: calculate effective total
		      final previousWrong = ref.read(mockTestProvider.notifier).getWrongQuestions(widget.testNumber) ?? [];
		      final previousCorrect = 20 - previousWrong.length;
		      scoreOutOf20 = previousCorrect + correct;
		      wrongIndicesToSave = currentWrongIndices.isNotEmpty ? currentWrongIndices : [];
		    } else {
		      // Full attempt: score is directly out of 20
		      scoreOutOf20 = correct;
		      wrongIndicesToSave = currentWrongIndices.isNotEmpty ? currentWrongIndices : [];
		    }
		
		    // Save result
		    try {
		      await ref.read(mockTestProvider.notifier).saveResult(
		        widget.testNumber,
		        scoreOutOf20,
		        wrongIndices: wrongIndicesToSave,
		      );
		    } catch (e) {
		      debugPrint('❌ saveResult failed: $e');
		    }
		
		    // Build shuffled info maps for result screen
		    final Map<int, List<String>> shuffledOptionsMap = {};
		    final Map<int, int> shuffledCorrectIndexMap = {};

		    // Transform _answers to use original question indices for result screen
		    final Map<int, int> answersForResult = {};
		    if (widget.wrongQuestionIndices != null) {
		      // Map back to original question indices for result display
		      for (int i = 0; i < _shuffledQuestions.length; i++) {
		        final originalIndex = widget.wrongQuestionIndices![i];
		        shuffledOptionsMap[originalIndex] = _shuffledQuestions[i].shuffledOptions;
		        shuffledCorrectIndexMap[originalIndex] = _shuffledQuestions[i].shuffledCorrectIndex;
		      }
		      // Convert relative indices in _answers to original indices
		      for (final entry in _answers.entries) {
		        answersForResult[widget.wrongQuestionIndices![entry.key]] = entry.value;
		      }
		    } else {
		      for (int i = 0; i < _shuffledQuestions.length; i++) {
		        shuffledOptionsMap[i] = _shuffledQuestions[i].shuffledOptions;
		        shuffledCorrectIndexMap[i] = _shuffledQuestions[i].shuffledCorrectIndex;
		      }
		      answersForResult.addAll(_answers);
		    }
		
		    if (!mounted) return;
		    Navigator.pushReplacement(
		      context,
		      MaterialPageRoute(
		        builder: (_) => MockTestResultScreen(
		          testNumber: widget.testNumber,
		          testTitle: widget.testTitle,
		          score: scoreOutOf20,
		          total: 20,
		          questions: test.questions,
		          answers: answersForResult,
		          shuffledOptionsMap: shuffledOptionsMap,
		          shuffledCorrectIndexMap: shuffledCorrectIndexMap,
		        ),
		      ),
		    );
		  }
}

/// shuffle-এর সময় originalIndex ট্র্যাক রাখার জন্য ক্ষণস্থায়ী হেলপার
class _IndexedOption {
  final String text;
  final int originalIndex;

  _IndexedOption({required this.text, required this.originalIndex});
}
