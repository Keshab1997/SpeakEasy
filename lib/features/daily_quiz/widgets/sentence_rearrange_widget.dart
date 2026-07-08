import 'dart:math';
import 'package:flutter/material.dart';
import '../models/daily_quiz_model.dart';
import '../../../core/constants/app_colors.dart';

/// A Sentence Rearrangement question widget.
///
/// Shows jumbled words as tappable chips. User taps in correct order to
/// build the sentence. Back button removes the last placed word.
class SentenceRearrangeWidget extends StatefulWidget {
  final DailyQuizQuestion question;
  final bool isAnswered;
  final ValueChanged<Map<String, dynamic>> onAnswer;

  const SentenceRearrangeWidget({
    super.key,
    required this.question,
    required this.isAnswered,
    required this.onAnswer,
  });

  @override
  State<SentenceRearrangeWidget> createState() =>
      _SentenceRearrangeWidgetState();
}

class _SentenceRearrangeWidgetState extends State<SentenceRearrangeWidget> {
  final List<int> _shuffledIndices = [];
  final List<int> _userOrder = [];
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _shuffle();
  }

  void _shuffle() {
    final words = widget.question.jumbledWords ?? widget.question.options;
    _shuffledIndices.addAll(List.generate(words.length, (i) => i)..shuffle(Random()));
  }

  List<String> get _words =>
      widget.question.jumbledWords ?? widget.question.options;

  bool get _allPlaced => _userOrder.length == _words.length;

  void _tapWord(int index) {
    if (widget.isAnswered || _submitted) return;
    if (_userOrder.contains(index)) return; // already placed
    setState(() => _userOrder.add(index));
    if (_allPlaced) _submit();
  }

  void _removeLast() {
    if (widget.isAnswered || _submitted || _userOrder.isEmpty) return;
    setState(() => _userOrder.removeLast());
  }

  void _submit() {
    final correctOrder = List.generate(_words.length, (i) => i);
    final isCorrect = _listEquals(_userOrder, correctOrder);

    setState(() => _submitted = true);
    widget.onAnswer({
      'userOrder': _userOrder,
      'correctOrder': correctOrder,
      'isCorrect': isCorrect,
    });
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final words = _words;

    return Column(
      children: [
        // Built sentence area
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
            ),
          ),
          child: _userOrder.isEmpty
              ? Center(
                  child: Text(
                    'Tap the words below in correct order',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _userOrder.map((idx) {
                    return Chip(
                      label: Text(
                        words[idx],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _submitted
                              ? (idx == _userOrder.indexOf(idx)
                                  ? Colors.green.shade700
                                  : Colors.red.shade700)
                              : null,
                        ),
                      ),
                      backgroundColor: _submitted
                          ? (idx == _userOrder.indexOf(idx)
                              ? Colors.green.shade50
                              : Colors.red.shade50)
                          : AppColors.primary.withOpacity(0.1),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  }).toList(),
                ),
        ),
        if (_userOrder.isNotEmpty && !_submitted && !widget.isAnswered)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: _removeLast,
              icon: const Icon(Icons.undo, size: 18),
              label: const Text('Undo last word'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
          ),
        const SizedBox(height: 24),
        // Available word chips
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: List.generate(words.length, (i) {
            final shuffledIdx = _shuffledIndices[i];
            final isUsed = _userOrder.contains(shuffledIdx);

            return GestureDetector(
              onTap: isUsed ? null : () => _tapWord(shuffledIdx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: isUsed
                      ? Colors.grey.shade300
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isUsed
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                ),
                child: Text(
                  words[shuffledIdx],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isUsed ? Colors.grey.shade500 : Colors.white,
                    decoration:
                        isUsed ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        if (_submitted) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _listEquals(
                      _userOrder, List.generate(words.length, (i) => i))
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _listEquals(
                          _userOrder, List.generate(words.length, (i) => i))
                      ? Icons.check_circle
                      : Icons.error_outline,
                  color: _listEquals(
                          _userOrder, List.generate(words.length, (i) => i))
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _listEquals(
                          _userOrder, List.generate(words.length, (i) => i))
                      ? 'Correct order! 🎉'
                      : 'Wrong order — try again next time!',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _listEquals(
                            _userOrder, List.generate(words.length, (i) => i))
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
          // Show correct answer
          if (!_listEquals(
              _userOrder, List.generate(words.length, (i) => i)))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Correct: ${words.join(' ')}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ],
    );
  }
}
