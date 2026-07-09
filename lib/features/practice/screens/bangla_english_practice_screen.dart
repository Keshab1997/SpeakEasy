import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/banner_ad_widget.dart';
import '../../../models/bangla_english_model.dart';


class BanglaEnglishCategoryScreen extends StatefulWidget {
  const BanglaEnglishCategoryScreen({super.key});

  @override
  State<BanglaEnglishCategoryScreen> createState() =>
      _BanglaEnglishCategoryScreenState();
}

class _BanglaEnglishCategoryScreenState
    extends State<BanglaEnglishCategoryScreen> {
  List<BanglaEnglishCategory>? _categories;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cats = await BanglaEnglishCategory.loadAll();
    setState(() {
      _categories = cats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.translate_rounded, color: AppColors.primary, size: 26),
            SizedBox(width: 8),
            Text('Bangla → English',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('Choose a Topic',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${_categories!.length} topics — total ${_categories!.fold(0, (s, c) => s + c.exercises.length)} sentences',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    const SizedBox(height: 20),
                    ..._categories!.map((cat) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildCategoryCard(context, cat),
                        )),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, BanglaEnglishCategory cat) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => BanglaEnglishExerciseScreen(
                  category: cat, exercises: cat.exercises))),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cat.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cat.color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cat.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(cat.icon, color: cat.color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cat.title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: cat.color)),
                  const SizedBox(height: 2),
                  Text(cat.subtitle,
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: cat.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${cat.exercises.length}',
                  style: TextStyle(
                      color: cat.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: cat.color, size: 22),
          ],
        ),
      ),
    );
  }
}

class BanglaEnglishExerciseScreen extends StatefulWidget {
  final BanglaEnglishCategory category;
  final List<BanglaEnglishExercise> exercises;

  const BanglaEnglishExerciseScreen({
    super.key,
    required this.category,
    required this.exercises,
  });

  @override
  State<BanglaEnglishExerciseScreen> createState() =>
      _BanglaEnglishExerciseScreenState();
}

class _BanglaEnglishExerciseScreenState
    extends State<BanglaEnglishExerciseScreen> {
  static final Map<String, int> _savedProgress = {};

  final _decoyPool = [
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'been', 'being',
    'have', 'has', 'had', 'having', 'do', 'does', 'did', 'doing',
    'will', 'would', 'can', 'could', 'should', 'may', 'might', 'shall',
    'go', 'goes', 'gone', 'going', 'went', 'make', 'made', 'take', 'took', 'taken',
    'get', 'got', 'gotten', 'see', 'saw', 'seen', 'come', 'came', 'know', 'knew', 'known',
    'very', 'too', 'also', 'even', 'just', 'only', 'still', 'already', 'yet',
    'but', 'and', 'or', 'so', 'because', 'if', 'then', 'than', 'though',
    'here', 'there', 'now', 'then', 'always', 'never', 'often', 'sometimes',
    'not', 'no', 'never', 'nothing', 'some', 'any', 'many', 'much', 'more', 'most',
    'this', 'that', 'these', 'those', 'my', 'your', 'his', 'her', 'its', 'our', 'their',
    'in', 'on', 'at', 'by', 'with', 'for', 'to', 'of', 'from', 'into', 'onto', 'upon',
    'up', 'down', 'over', 'under', 'above', 'below', 'between', 'among', 'before', 'after',
    'good', 'bad', 'big', 'small', 'new', 'old', 'first', 'last', 'next', 'same', 'different',
    'quickly', 'slowly', 'carefully', 'easily', 'well', 'badly', 'hard', 'early', 'late',
  ];

  int _index = 0;
  int _score = 0;
  bool _submitted = false;

  List<String> _selectedWords = [];
  List<String> _remainingWords = [];

  @override
  void initState() {
    super.initState();
    final saved = _savedProgress[widget.category.id] ?? 0;
    if (saved > 0 && saved < widget.exercises.length) {
      _index = saved;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResumePrompt());
    }
    _initWords();
  }

  void _showResumePrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Resume?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'You were at exercise ${_savedProgress[widget.category.id]! + 1} of ${widget.exercises.length}. Continue from there?'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _index = 0;
                _score = 0;
                _savedProgress.remove(widget.category.id);
              });
              _initWords();
              Navigator.pop(ctx);
            },
            child: const Text('Start Over',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }

  void _initWords() {
    final correct = widget.exercises[_index].english;
    final words = correct
        .replaceAll(RegExp(r'[.!?,:;"]'), '')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();

    final rng = _index.hashCode;
    _decoyPool.shuffle(Random(rng));
    final decoyCount = words.length + 5;
    final decoys = _decoyPool.take(decoyCount).toList();

    final all = [...words, ...decoys];
    all.shuffle(Random(rng));

    _selectedWords = [];
    _remainingWords = all;
  }

  @override
  void dispose() {
    if (_index > 0 && _index < widget.exercises.length) {
      _savedProgress[widget.category.id] = _index;
    } else if (_index >= widget.exercises.length) {
      _savedProgress.remove(widget.category.id);
    }
    super.dispose();
  }

  String _normalize(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[.!?]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ');

  void _selectWord(String word) {
    if (_submitted) return;
    final idx = _remainingWords.indexOf(word);
    if (idx == -1) return;
    setState(() {
      _selectedWords.add(_remainingWords.removeAt(idx));
    });
  }

  void _unselectWord(int idx) {
    if (_submitted) return;
    setState(() {
      _remainingWords.add(_selectedWords.removeAt(idx));
    });
  }

  void _submit() {
    if (_submitted || _selectedWords.isEmpty) return;
    final user = _normalize(_selectedWords.join(' '));
    final correct = _normalize(widget.exercises[_index].english);
    setState(() {
      _submitted = true;
      if (user == correct) _score++;
    });
  }

  void _next() {
    setState(() {
      if (_index + 1 >= widget.exercises.length) {
        _index = widget.exercises.length;
      } else {
        _index++;
      }
      _submitted = false;
      _initWords();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_index >= widget.exercises.length) {
      return _buildResult(isDark, theme);
    }

    final ex = widget.exercises[_index];
    final total = widget.exercises.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(widget.category.icon, color: widget.category.color, size: 26),
            const SizedBox(width: 8),
            Text(widget.category.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: (_index + 1) / total,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                color: widget.category.color,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Exercise ${_index + 1} / $total',
                      style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const Spacer(),
                  Text('Score: $_score',
                      style: TextStyle(
                          color: widget.category.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: widget.category.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: widget.category.color.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('বাংলা বাক্য:',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12)),
                    const SizedBox(height: 8),
                    Text(ex.bangla,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildBuilder(isDark),
              const SizedBox(height: 12),
              if (!_submitted) _buildWordBank(isDark),
              const SizedBox(height: 12),
              if (!_submitted)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _selectedWords.isEmpty ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.category.color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Check',
                        style:
                            TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              if (_submitted) ...[
                _buildResultCard(ex, isDark),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.info.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(ex.grammarFocus,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: widget.category.color)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...ex.rules.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• ',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600)),
                                Expanded(
                                  child: Text(r,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600)),
                                ),
                              ],
                            ),
                          )),
                      if (ex.hint.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.tips_and_updates_rounded,
                                size: 14, color: AppColors.warning),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(ex.hint,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.warning)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.category.color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                        _index + 1 >= total ? 'See Result' : 'Next',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuilder(bool isDark) {
    final accent = widget.category.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Your sentence:',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            const Spacer(),
            Text('${_selectedWords.length} words',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: _selectedWords.isEmpty
              ? Text('Tap words below to build...',
                  style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                      fontStyle: FontStyle.italic))
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selectedWords.asMap().entries.map((e) {
                    final i = e.key;
                    final w = e.value;
                    return GestureDetector(
                      onTap: () => _unselectWord(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: accent.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(w,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: accent)),
                            const SizedBox(width: 4),
                            Icon(Icons.close_rounded,
                                size: 14, color: accent.withOpacity(0.5)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildWordBank(bool isDark) {
    final accent = widget.category.color;
    if (_remainingWords.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Word bank (tap to add):',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _remainingWords.map((w) => GestureDetector(
            onTap: () => _selectWord(w),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withOpacity(0.15)),
              ),
              child: Text(w,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: accent)),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildResultCard(BanglaEnglishExercise ex, bool isDark) {
    final correct = _submitted && _normalize(_selectedWords.join(' ')) == _normalize(ex.english);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: correct
            ? AppColors.success.withOpacity(0.1)
            : AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: correct
              ? AppColors.success.withOpacity(0.3)
              : AppColors.error.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: correct ? AppColors.success : AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                correct ? 'Correct!' : 'Incorrect',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: correct ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Correct: ',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                TextSpan(text: ex.english,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(bool isDark, ThemeData theme) {
    final total = widget.exercises.length;
    final pct = total > 0 ? (_score / total * 100).round() : 0;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(widget.category.icon, color: widget.category.color, size: 26),
            const SizedBox(width: 8),
            Text(widget.category.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ],
        ),
      ),
      body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
              Icon(
                pct >= 80
                    ? Icons.emoji_events_rounded
                    : pct >= 50
                        ? Icons.thumb_up_rounded
                        : Icons.replay_rounded,
                size: 80,
                color: pct >= 80
                    ? AppColors.warning
                    : pct >= 50
                        ? widget.category.color
                        : Colors.grey,
              ),
              const SizedBox(height: 20),
              Text('Exercise Complete!',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('$_score / $total correct',
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: widget.category.color)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _statChip('$pct%', 'Accuracy', AppColors.success),
                  const SizedBox(width: 12),
                  _statChip('${total - _score}', 'Wrong', AppColors.error),
                  const SizedBox(width: 12),
                  _statChip('$total', 'Total', AppColors.info),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 200,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _savedProgress.remove(widget.category.id);
                    setState(() {
                      _index = 0;
                      _score = 0;
                      _submitted = false;
                    });
                    _initWords();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.category.color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const Spacer(),
              const BannerAdWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 18, color: color)),
          Text(label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ],
      ),
    );
  }
}
