import 'dart:math';
import 'package:flutter/material.dart';
import '../models/daily_quiz_model.dart';
import '../../../core/constants/app_colors.dart';

/// A Match-the-Pairs question widget.
///
/// Shows two columns (left = words, right = meanings, both shuffled).
/// User taps a left item then a right item to match them.
/// Matched pairs are highlighted. When all matched, user confirms.
class MatchPairsWidget extends StatefulWidget {
  final DailyQuizQuestion question;
  final bool isAnswered;
  final ValueChanged<Map<String, dynamic>> onAnswer;

  const MatchPairsWidget({
    super.key,
    required this.question,
    required this.isAnswered,
    required this.onAnswer,
  });

  @override
  State<MatchPairsWidget> createState() => _MatchPairsWidgetState();
}

class _MatchPairsWidgetState extends State<MatchPairsWidget> {
  final List<int> _shuffledLeft = [];
  final List<int> _shuffledRight = [];
  int? _selectedLeftIndex;
  final Map<int, int> _matchedPairs = {}; // leftIndex → rightIndex
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _shuffle();
  }

  void _shuffle() {
    final pairs = widget.question.pairs ?? [];
    final rng = Random();
    _shuffledLeft.addAll(List.generate(pairs.length, (i) => i)..shuffle(rng));
    _shuffledRight.addAll(List.generate(pairs.length, (i) => i)..shuffle(rng));
  }

  void _onTapLeft(int displayIndex) {
    if (widget.isAnswered || _submitted) return;
    final realIndex = _shuffledLeft[displayIndex];
    if (_matchedPairs.containsKey(realIndex)) return; // already matched
    setState(() => _selectedLeftIndex = realIndex);
  }

  void _onTapRight(int displayIndex) {
    if (widget.isAnswered || _submitted || _selectedLeftIndex == null) return;
    final realIndex = _shuffledRight[displayIndex];

    // Check if this right item is already matched.
    if (_matchedPairs.containsValue(realIndex)) return;

    setState(() {
      _matchedPairs[_selectedLeftIndex!] = realIndex;
      _selectedLeftIndex = null;
    });

    // Auto-submit when all matched.
    if (_matchedPairs.length == (widget.question.pairs?.length ?? 0)) {
      _submit();
    }
  }

  void _submit() {
    final pairs = widget.question.pairs ?? [];
    int correct = 0;
    for (final entry in _matchedPairs.entries) {
      if (entry.value == entry.key) correct++;
    }

    // Build response data.
    final matchList = _matchedPairs.entries
        .map((e) => {'leftIndex': e.key, 'userRightIndex': e.value})
        .toList();

    setState(() => _submitted = true);
    widget.onAnswer({
      'matches': matchList,
      'correctCount': correct,
      'totalPairs': pairs.length,
    });

    // After a brief delay we could auto-advance — the parent controls that via
    // the isAnswered / onAnswer flow.
  }

  @override
  Widget build(BuildContext context) {
    final pairs = widget.question.pairs ?? [];
    if (pairs.isEmpty) {
      return const Center(child: Text('No pairs available'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Tap a word on the left, then match it with its meaning on the right.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Row(
            children: [
              // Left column — words
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: pairs.length,
                  itemBuilder: (_, li) {
                    final realLeft = _shuffledLeft[li];
                    final isMatched = _matchedPairs.containsKey(realLeft);
                    final isSelected = _selectedLeftIndex == realLeft;

                    return _buildPairCard(
                      text: pairs[realLeft].left,
                      color: isMatched
                          ? Colors.green
                          : isSelected
                              ? AppColors.primary
                              : Colors.grey,
                      isMatched: isMatched,
                      onTap: () => _onTapLeft(li),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Right column — meanings
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: pairs.length,
                  itemBuilder: (_, ri) {
                    final realRight = _shuffledRight[ri];
                    final isMatched =
                        _matchedPairs.containsValue(realRight);
                    final pairedWithLeft = _matchedPairs.entries
                        .firstWhere(
                          (e) => e.value == realRight,
                          orElse: () => MapEntry(-1, -1),
                        )
                        .key;
                    final isCorrectMatch =
                        _submitted && pairedWithLeft == realRight;
                    final isWrongMatch =
                        _submitted &&
                        isMatched &&
                        pairedWithLeft != realRight;

                    Color borderColor;
                    if (isWrongMatch) {
                      borderColor = Colors.red;
                    } else if (isCorrectMatch) {
                      borderColor = Colors.green;
                    } else if (isMatched) {
                      borderColor = Colors.green;
                    } else {
                      borderColor = Colors.grey;
                    }

                    return _buildPairCard(
                      text: pairs[realRight].right,
                      color: borderColor,
                      isMatched: isMatched,
                      isWrong: isWrongMatch,
                      onTap: () => _onTapRight(ri),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (_submitted) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _allCorrect()
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _allCorrect()
                      ? Icons.check_circle
                      : Icons.info_outline,
                  color: _allCorrect() ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  _allCorrect()
                      ? 'All matched correctly! 🎉'
                      : '${_correctCount()} / ${pairs.length} correct',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _allCorrect()
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  bool _allCorrect() => _correctCount() == (widget.question.pairs?.length ?? 0);
  int _correctCount() {
    int c = 0;
    for (final e in _matchedPairs.entries) {
      if (e.value == e.key) c++;
    }
    return c;
  }

  Widget _buildPairCard({
    required String text,
    required Color color,
    bool isMatched = false,
    bool isWrong = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: isWrong
                ? Colors.red.shade50
                : isMatched
                    ? Colors.green.shade50
                    : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isWrong
                  ? Colors.red
                  : isMatched
                      ? Colors.green
                      : color.withOpacity(0.4),
              width: isMatched ? 2 : 1,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isMatched ? FontWeight.w600 : FontWeight.w500,
              color: isWrong
                  ? Colors.red.shade700
                  : isMatched
                      ? Colors.green.shade700
                      : Colors.grey.shade800,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
