import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/banner_ad_widget.dart';
import '../../../models/verb_form_model.dart';

class VerbFormPracticeScreen extends StatefulWidget {
  final List<VerbFormCategory>? categories;

  const VerbFormPracticeScreen({super.key, this.categories});

  @override
  State<VerbFormPracticeScreen> createState() => _VerbFormPracticeScreenState();
}

class _VerbFormPracticeScreenState extends State<VerbFormPracticeScreen> {
  List<VerbFormCategory>? _loadedCategories;
  late List<_Question> _questions;
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _showResult = false;
  bool _finished = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.categories != null) {
      _loadedCategories = widget.categories;
      _questions = _generateQuestions();
    } else {
      _loadAndStart();
    }
  }

  Future<void> _loadAndStart() async {
    setState(() => _loading = true);
    final cats = await VerbFormCategory.loadAll();
    setState(() {
      _loadedCategories = cats;
      _loading = false;
      _questions = _generateQuestions();
    });
  }

  List<_Question> _generateQuestions() {
    final rng = Random();
    final allVerbs = <VerbForm>[];
    for (final cat in _loadedCategories!) {
      allVerbs.addAll(cat.verbs);
    }
    allVerbs.shuffle(rng);

    const templates = [
      _QTemplate('I ___ ({{v1}}) every day.', 'v1',
          'I {{answer}} ({{v1}}) every day.',
          'Present Simple — I/You/We/They-এর সাথে verb-এর base form (V1) বসে'),
      _QTemplate('She ___ ({{v1}}) yesterday.', 'v2',
          'She {{answer}} ({{v1}}) yesterday.',
          'Past Simple — "yesterday" অতীত নির্দেশ করছে, তাই V2 (past form) বসে'),
      _QTemplate('They have ___ ({{v1}}) already.', 'v3',
          'They have {{answer}} ({{v1}}) already.',
          'Present Perfect — have/has-এর পরে সবসময় V3 (past participle) বসে'),
      _QTemplate('He is ___ ({{v1}}) now.', 'v4',
          'He is {{answer}} ({{v1}}) now.',
          'Present Continuous — is/am/are-এর পরে verb-এর V4 (-ing form) বসে'),
      _QTemplate('She ___ ({{v1}}) every day.', 'v5',
          'She {{answer}} ({{v1}}) every day.',
          'Present Simple (3rd person) — He/She/It-এর সাথে V5 (V1 + s/es) বসে'),
    ];

    final questions = <_Question>[];
    for (final verb in allVerbs) {
      if (questions.length >= 30) break;

      final tmpl = templates[rng.nextInt(templates.length)];
      final formKey = tmpl.answerKey;
      final correct = _getForm(verb, formKey);
      if (correct == null || correct.isEmpty) continue;

      final allForms = [
        verb.v1,
        verb.v2,
        verb.v3,
        verb.v4,
        verb.v5,
      ].where((f) => f.isNotEmpty && f != correct).toSet().toList();
      allForms.shuffle(rng);
      final wrongs = allForms.take(3).toList();
      if (wrongs.length < 3) continue;

      final options = [correct, ...wrongs];
      options.shuffle(rng);

      questions.add(_Question(
        sentence: tmpl.sentence.replaceAll('{{v1}}', verb.v1),
        correctAnswer: correct,
        options: options,
        answerSentence: tmpl.answerSentence
            .replaceAll('{{v1}}', verb.v1)
            .replaceAll('{{answer}}', correct),
        bangla: verb.bangla,
        formLabel: formKey.toUpperCase(),
        explanation: tmpl.explanation,
      ));
    }

    questions.shuffle(rng);
    return questions.take(15).toList();
  }

  String? _getForm(VerbForm v, String key) {
    switch (key) {
      case 'v1': return v.v1;
      case 'v2': return v.v2;
      case 'v3': return v.v3;
      case 'v4': return v.v4;
      case 'v5': return v.v5;
      default: return null;
    }
  }

  void _answer(int i) {
    if (_showResult) return;
    setState(() {
      _selected = i;
      _showResult = true;
      if (_questions[_index].options[i] == _questions[_index].correctAnswer) {
        _score++;
      }
    });
  }

  void _next() {
    if (_index + 1 >= _questions.length) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _showResult = false;
    });
  }

  void _restart() {
    setState(() {
      _questions = _generateQuestions();
      _index = 0;
      _score = 0;
      _selected = null;
      _showResult = false;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Verb Forms Quiz',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_finished) {
      return _buildResult(isDark, theme);
    }

    final q = _questions[_index];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verb Forms Quiz',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: (_index + 1) / _questions.length,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                color: AppColors.primary,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Question ${_index + 1} / ${_questions.length}',
                      style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const Spacer(),
                  Text('Score: $_score',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(q.formLabel,
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        Text(q.bangla,
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                                fontStyle: FontStyle.italic)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('Fill in the blank with the correct form:',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    const SizedBox(height: 10),
                    Text(q.sentence,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ...List.generate(q.options.length, (i) {
                final opt = q.options[i];
                Color bg;
                Color txt;
                if (_showResult) {
                  if (opt == q.correctAnswer) {
                    bg = AppColors.success.withOpacity(0.15);
                    txt = AppColors.success;
                  } else if (i == _selected) {
                    bg = AppColors.error.withOpacity(0.15);
                    txt = AppColors.error;
                  } else {
                    bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
                    txt = isDark ? Colors.white : Colors.black87;
                  }
                } else {
                  bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
                  txt = isDark ? Colors.white : Colors.black87;
                }
                final borderC = _showResult && opt == q.correctAnswer
                    ? AppColors.success.withOpacity(0.4)
                    : _showResult && i == _selected
                        ? AppColors.error.withOpacity(0.4)
                        : isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _showResult ? null : () => _answer(i),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderC),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _showResult && opt == q.correctAnswer
                                    ? AppColors.success
                                    : _showResult && i == _selected
                                        ? AppColors.error
                                        : isDark
                                            ? Colors.grey[700]
                                            : Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: _showResult && opt == q.correctAnswer
                                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                                    : _showResult && i == _selected
                                        ? const Icon(Icons.close, size: 16, color: Colors.white)
                                        : Text('${i + 1}',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.grey[700])),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(opt,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16, color: txt)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              if (_showResult && _selected != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.info.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 18),
                          const SizedBox(width: 6),
                          Text(q.answerSentence,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.info)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_rounded,
                              color: AppColors.warning, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(q.explanation,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.info, height: 1.3)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _showResult ? _next : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(_index + 1 >= _questions.length ? 'See Result' : 'Next',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult(bool isDark, ThemeData theme) {
    final pct = (_score / _questions.length * 100).round();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verb Forms Quiz',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
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
                        ? AppColors.primary
                        : Colors.grey,
              ),
              const SizedBox(height: 20),
              Text('Quiz Complete!',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('$_score / ${_questions.length} correct',
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _statChip('$pct%', 'Accuracy', AppColors.success),
                  const SizedBox(width: 12),
                  _statChip('${_questions.length - _score}', 'Wrong', AppColors.error),
                  const SizedBox(width: 12),
                  _statChip('${_questions.length}', 'Total', AppColors.info),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 200,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

class _QTemplate {
  final String sentence;
  final String answerKey;
  final String answerSentence;
  final String explanation;
  const _QTemplate(
      this.sentence, this.answerKey, this.answerSentence, this.explanation);
}

class _Question {
  final String sentence;
  final String correctAnswer;
  final List<String> options;
  final String answerSentence;
  final String bangla;
  final String formLabel;
  final String explanation;

  const _Question({
    required this.sentence,
    required this.correctAnswer,
    required this.options,
    required this.answerSentence,
    required this.bangla,
    required this.formLabel,
    required this.explanation,
  });
}
