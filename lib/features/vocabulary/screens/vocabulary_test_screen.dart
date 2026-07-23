import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/banner_ad_widget.dart';
import '../../../core/widgets/skeleton_widget.dart';
import '../../../models/vocabulary_chapter_model.dart';
import '../../../providers/chapter_vocabulary_provider.dart';
import '../../../services/hive_service.dart';

class VocabularyTestScreen extends ConsumerStatefulWidget {
  const VocabularyTestScreen({super.key});

  @override
  ConsumerState<VocabularyTestScreen> createState() =>
      _VocabularyTestScreenState();
}

class _VocabularyTestScreenState extends ConsumerState<VocabularyTestScreen> {
  List<_Question> _questions = [];
  int _current = 0;
  int? _selected;
  bool _answered = false;
  int _score = 0;
  bool _finished = false;

  static const int _totalQuestions = 10;

  final FlutterTts _tts = FlutterTts();
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
    _ensureBoxOpen().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _buildQuestions());
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(String word) async {
    if (_muted) return;
    await _tts.speak(word);
  }

  void _select(String option) {
    if (_answered) return;
    final isCorrect = option == _questions[_current].correctAnswer;
    setState(() {
      _selected = _questions[_current].options.indexOf(option);
      _answered = true;
      if (isCorrect) _score++;
    });
    if (!_muted) {
      _tts.speak(isCorrect ? 'Correct' : 'Wrong');
    }
  }

  Future<void> _ensureBoxOpen() async {
    if (!Hive.isBoxOpen('vocab_test_history')) {
      await Hive.openBox('vocab_test_history');
    }
  }

  List<ChapterWord> _getAllWords() {
    final chapters = ref.read(allChaptersProvider).asData?.value ?? [];
    return chapters
        .expand((c) => c.words)
        .where((w) => w.banglaMeaning.isNotEmpty)
        .toList();
  }

  void _buildQuestions([List<String>? fixedWords]) {
    final allWords = _getAllWords();
    if (allWords.length < 4) return;

    final rng = Random();
    List<ChapterWord> picked;

    if (fixedWords != null) {
      picked = fixedWords
          .map((w) => allWords.firstWhere((a) => a.word == w,
              orElse: () => allWords[rng.nextInt(allWords.length)]))
          .toList();
    } else {
      final shuffled = List<ChapterWord>.from(allWords)..shuffle(rng);
      picked = shuffled.take(_totalQuestions).toList();
    }

    final questions = picked.map((correct) {
      final others = allWords.where((w) => w != correct).toList()..shuffle(rng);
      final options = [
        ...others.take(3).map((w) => w.banglaMeaning),
        correct.banglaMeaning,
      ]..shuffle(rng);
      return _Question(
        word: correct.word,
        pronunciation: correct.pronunciation,
        correctAnswer: correct.banglaMeaning,
        options: options,
      );
    }).toList();

    setState(() {
      _questions = questions;
      _current = 0;
      _selected = null;
      _answered = false;
      _score = 0;
      _finished = false;
    });
    Future.delayed(const Duration(milliseconds: 300), () => _speak(questions.first.word));
  }

  void _next() {
    if (_current + 1 >= _questions.length) {
      // Save session
      HiveService.saveTestSession(
        _questions.map((q) => q.word).toList(),
        _score,
      );
      setState(() => _finished = true);
    } else {
      setState(() {
        _current++;
        _selected = null;
        _answered = false;
      });
      _speak(_questions[_current].word);
    }
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _HistorySheet(
        onRetry: (words) {
          Navigator.pop(context);
          _buildQuestions(words);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_questions.isEmpty) {
      return const SkeletonPage(
        title: 'Vocabulary Test',
        type: SkeletonType.detail,
      );
    }

    if (_finished) return _buildResult(theme);

    final q = _questions[_current];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary Test',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
            onPressed: () => setState(() => _muted = !_muted),
            tooltip: _muted ? 'Unmute' : 'Mute',
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: _showHistory,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_current + 1) / _questions.length,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Question ${_current + 1} / ${_questions.length}',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.primaryGradient),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(children: [
                Text(q.word,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900)),
                if (q.pronunciation.isNotEmpty)
                  Text(q.pronunciation,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontStyle: FontStyle.italic)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _speak(q.word),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 6),
                        Text('Pronounce', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            const Text('এই word-এর বাংলা অর্থ কী?',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 12),
            ...q.options.asMap().entries.map((e) {
              final idx = e.key;
              final opt = e.value;
              final isCorrect = opt == q.correctAnswer;
              final isSelected = _selected == idx;
              Color bg = Colors.transparent;
              Color border = Colors.grey.withOpacity(0.3);
              if (_answered) {
                if (isCorrect) { bg = Colors.green.withOpacity(0.12); border = Colors.green; }
                else if (isSelected) { bg = Colors.red.withOpacity(0.12); border = Colors.red; }
              }
              return GestureDetector(
                onTap: () => _select(opt),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                      color: bg,
                      border: Border.all(color: border, width: 1.5),
                      borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Expanded(child: Text(opt, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                    if (_answered && isCorrect) const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                    if (_answered && isSelected && !isCorrect) const Icon(Icons.cancel_rounded, color: Colors.red, size: 20),
                  ]),
                ),
              );
            }),
            const Spacer(),
            if (_answered)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _current + 1 >= _questions.length ? 'See Result' : 'Next',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(ThemeData theme) {
    final pct = _score / _questions.length;
    final emoji = pct == 1.0 ? '🏆' : pct >= 0.7 ? '🎉' : pct >= 0.4 ? '👍' : '💪';
    final msg = pct == 1.0 ? 'Perfect Score!' : pct >= 0.7 ? 'Great job!' : pct >= 0.4 ? 'Keep practicing!' : "Don't give up!";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        actions: [IconButton(icon: const Icon(Icons.history_rounded), onPressed: _showHistory)],
      ),
      body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(msg, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.primaryGradient),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_score / ${_questions.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _buildQuestions(_questions.map((q) => q.word).toList()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Retry Same Words', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _buildQuestions(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('New Random Test', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
              const Spacer(),
              const BannerAdWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Question {
  final String word;
  final String pronunciation;
  final String correctAnswer;
  final List<String> options;
  const _Question({required this.word, required this.pronunciation, required this.correctAnswer, required this.options});
}

class _HistorySheet extends StatefulWidget {
  final void Function(List<String> words) onRetry;
  const _HistorySheet({required this.onRetry});

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _history = HiveService.getTestHistory();
  }

  void _refresh() {
    setState(() {
      _history = HiveService.getTestHistory();
    });
  }

  Future<void> _delete(int index) async {
    await HiveService.deleteTestSession(index);
    _refresh();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await HiveService.clearAllTestSessions();
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(children: [
              const Icon(Icons.history_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Test History',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
              if (_history.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  label: const Text('Clear All'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
            ]),
          ),
          const Divider(height: 1),
          if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No history yet. Complete a test first!',
                  textAlign: TextAlign.center),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.all(12),
                itemCount: _history.length,
                itemBuilder: (_, i) {
                  final s = _history[i];
                  final words = List<String>.from(s['words'] as List);
                  final score = s['score'] as int;
                  final total = s['total'] as int;
                  final date = DateTime.tryParse(s['date'] as String);
                  final dateStr = date != null
                      ? '${date.day}/${date.month}  ${date.hour}:${date.minute.toString().padLeft(2, '0')}'
                      : '';
                  return Dismissible(
                    key: ValueKey('${s['date']}_$i'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.delete_rounded, color: Colors.white),
                    ),
                    onDismissed: (_) => _delete(i),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$score/$total',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text('${words.take(4).join(', ')}...',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(dateStr,
                            style: const TextStyle(fontSize: 11)),
                        trailing: TextButton(
                          onPressed: () => widget.onRetry(words),
                          child: const Text('Retry'),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
