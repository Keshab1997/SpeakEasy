import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/grammar_chapter_model.dart';
import '../../../models/quiz_model.dart';
import '../../../utils/grammar_quiz_generator.dart';

class GrammarTestScreen extends StatefulWidget {
  final GrammarChapter chapter;
  const GrammarTestScreen({super.key, required this.chapter});

  @override
  State<GrammarTestScreen> createState() => _GrammarTestScreenState();
}

class _GrammarTestScreenState extends State<GrammarTestScreen> {
  late final List<QuestionModel> _questions;
  int _currentIndex = 0;
  int? _selectedIndex;
  int _score = 0;
  bool _showResult = false;
  bool _answered = false;
  final Map<int, int> _userAnswers = {};

  @override
  void initState() {
    super.initState();
    _questions = generateGrammarQuiz(widget.chapter);
  }

  void _selectOption(int index) {
    if (_answered) return;
    setState(() {
      _selectedIndex = index;
      _answered = true;
      _userAnswers[_currentIndex] = index;
      if (index == _questions[_currentIndex].correctIndex) _score++;
    });
  }

  void _next() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedIndex = null;
        _answered = false;
      });
    } else {
      setState(() => _showResult = true);
    }
  }

  void _retry() {
    setState(() {
      _currentIndex = 0;
      _selectedIndex = null;
      _score = 0;
      _showResult = false;
      _answered = false;
      _userAnswers.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showResult) return _buildResult();
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.chapter.title)),
        body: const Center(child: Text('No questions available for this chapter.')),
      );
    }
    return _buildQuiz();
  }

  Widget _buildQuiz() {
    final q = _questions[_currentIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = _questions.length;
    final progress = (_currentIndex + 1) / total;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chapter.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 4,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${_currentIndex + 1} of $total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                Text(
                  '$_score/${_currentIndex + (_answered ? 1 : 0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Text(
                q.question,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
            ...List.generate(q.options.length, (i) => _buildOption(i, q, isDark)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _answered ? _next : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  _currentIndex < _questions.length - 1 ? 'Next Question' : 'See Results',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            if (q.explanation != null && _answered) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.12)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        q.explanation!,
                        style: const TextStyle(fontSize: 13, color: Colors.blue, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOption(int index, QuestionModel q, bool isDark) {
    final selected = _selectedIndex == index;
    final correct = q.correctIndex == index;
    Color bg;
    Color border;
    Color textColor;

    if (!_answered) {
      bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
      border = isDark ? AppColors.borderDark : AppColors.borderLight;
      textColor = isDark ? Colors.white : Colors.black87;
    } else if (correct) {
      bg = Colors.green.withValues(alpha: 0.1);
      border = Colors.green;
      textColor = Colors.green.shade700;
    } else if (selected && !correct) {
      bg = Colors.red.withValues(alpha: 0.1);
      border = Colors.red;
      textColor = Colors.red.shade700;
    } else {
      bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
      border = isDark ? AppColors.borderDark : AppColors.borderLight;
      textColor = isDark ? Colors.white60 : Colors.black45;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _selectOption(index),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: selected || (_answered && correct) ? 2 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _answered && correct
                      ? Colors.green
                      : _answered && selected && !correct
                          ? Colors.red
                          : isDark
                              ? Colors.grey[700]
                              : Colors.grey[200],
                ),
                child: Center(
                  child: _answered && correct
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : _answered && selected && !correct
                          ? const Icon(Icons.close, size: 16, color: Colors.white)
                          : Text(
                              String.fromCharCode(65 + index),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.black45,
                              ),
                            ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  q.options[index],
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = _questions.length;
    final pct = total > 0 ? (_score / total * 100).round() : 0;
    final passed = pct >= 50;

    return Scaffold(
      appBar: AppBar(title: const Text('Test Complete')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(passed ? '🎉' : '💪', style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              passed ? 'Great Job!' : 'Keep Practicing!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              widget.chapter.title,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 24),
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: passed ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                border: Border.all(color: passed ? Colors.green : Colors.orange, width: 4),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_score/$total',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: passed ? Colors.green : Colors.orange,
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: passed ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _retry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : Colors.black54,
                  side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Back to Chapters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
            if (_userAnswers.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Review Answers',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 12),
                    ...List.generate(_questions.length, (i) {
                      final q = _questions[i];
                      final userAns = _userAnswers[i];
                      final correct = userAns == q.correctIndex;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              correct ? Icons.check_circle : Icons.cancel,
                              color: correct ? Colors.green : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Q${i + 1}: ${q.options[q.correctIndex]}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                  if (q.explanation != null)
                                    Text(
                                      q.explanation!,
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
