import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/grammar_chapter_model.dart';
import '../../../models/quiz_model.dart';
import '../../../services/ai_service.dart';
import '../../../services/hive_service.dart';
import '../../../utils/grammar_quiz_generator.dart';

class GrammarMasterScreen extends ConsumerStatefulWidget {
  final GrammarChapter chapter;

  const GrammarMasterScreen({super.key, required this.chapter});

  @override
  ConsumerState<GrammarMasterScreen> createState() =>
      _GrammarMasterScreenState();
}

class _GrammarMasterScreenState extends ConsumerState<GrammarMasterScreen> {
  List<QuestionModel> _questions = [];
  int _currentIndex = 0;
  int? _selectedIndex;
  bool _isAnswered = false;
  bool _isLoading = true;
  int _score = 0;
  bool _showResult = false;
  bool _hasSaved = false;
  final Map<int, int> _userAnswers = {};
  final _scrollController = ScrollController();

  static const _generatorPrompt = """You are an expert English grammar teacher. Based on the chapter data provided below, create 5 multiple-choice questions to test the student's understanding.

For EACH question, provide:
1. A clear question in English with Bangla translation
2. 4 options (one correct, three plausible wrong ones)
3. The correct answer index (0-based)
4. A detailed teacher-like explanation in English + Bangla explaining why the correct answer is right and why the wrong ones are wrong

IMPORTANT: Return ONLY a valid JSON array. No other text. No markdown formatting. No code blocks.

Format:
[
  {
    "question": "Question in English? বাংলা: বাংলা প্রশ্ন",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctIndex": 0,
    "explanation": "Detailed English explanation...\\n\\nবাংলা: বাংলা ব্যাখ্যা..."
  }
]""";

  @override
  void initState() {
    super.initState();
    _generateQuestionsWithAI();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _generateQuestionsWithAI() async {
    setState(() => _isLoading = true);
    try {
      final chapterData = _buildChapterContext();
      final response = await AIService()
          .sendMessageWithSystem(chapterData, systemPrompt: _generatorPrompt);
      final parsed = _parseQuestionsFromAI(response);
      if (parsed.length >= 3) {
        if (mounted) {
          setState(() {
            _questions = parsed.take(5).toList();
            _isLoading = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _questions = generateGrammarQuiz(widget.chapter);
        if (_questions.length > 5) _questions = _questions.sublist(0, 5);
        _isLoading = false;
      });
    }
  }

  String _buildChapterContext() {
    final buf = StringBuffer();
    buf.writeln('Chapter: ${widget.chapter.title}');
    buf.writeln('Level: ${widget.chapter.level}');
    buf.writeln('Description: ${widget.chapter.description}');
    buf.writeln('');

    for (int i = 0; i < widget.chapter.topics.length; i++) {
      final t = widget.chapter.topics[i];
      buf.writeln('--- Topic ${i + 1}: ${t.name} (${t.banglaName}) ---');
      if (t.definition.isNotEmpty) buf.writeln('Definition: ${t.definition}');
      if (t.banglaDefinition.isNotEmpty) {
        buf.writeln('বাংলা: ${t.banglaDefinition}');
      }
      if (t.formula.isNotEmpty) buf.writeln('Formula: ${t.formula}');
      if (t.rules.isNotEmpty) {
        buf.writeln('Rules:');
        for (final r in t.rules) {
          buf.writeln('  - $r');
        }
      }
      if (t.examples.isNotEmpty) {
        buf.writeln('Examples:');
        for (final e in t.examples) {
          buf.writeln('  EN: ${e.en}');
          buf.writeln('  BN: ${e.bn}');
        }
      }
      if (t.tips.isNotEmpty) buf.writeln('Tips: ${t.tips}');
      buf.writeln('');
    }

    if (widget.chapter.commonMistakes.isNotEmpty) {
      buf.writeln('--- Common Mistakes ---');
      for (final m in widget.chapter.commonMistakes) {
        buf.writeln('Wrong: ${m.wrong}');
        buf.writeln('Correct: ${m.correct}');
        buf.writeln('Explanation: ${m.explanation}');
      }
    }

    return buf.toString();
  }

  List<QuestionModel> _parseQuestionsFromAI(String response) {
    try {
      String clean = response.trim();
      if (clean.startsWith('```')) {
        clean = clean.split('\n').skip(1).join('\n');
      }
      if (clean.endsWith('```')) {
        clean = clean.substring(0, clean.length - 3);
      }
      clean = clean.trim();
      if (clean.startsWith('```json')) {
        clean = clean.replaceFirst('```json', '').trim();
        if (clean.endsWith('```')) {
          clean = clean.substring(0, clean.length - 3).trim();
        }
      }

      final List<dynamic> data = jsonDecode(clean) as List<dynamic>;
      return data.map((item) {
        final map = item as Map<String, dynamic>;
        return QuestionModel(
          question: map['question'] as String? ?? '',
          options: (map['options'] as List<dynamic>?)
                  ?.cast<String>() ??
              [],
          correctIndex: map['correctIndex'] as int? ?? 0,
          explanation: map['explanation'] as String?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  void _selectOption(int index) {
    if (_isAnswered) return;
    setState(() {
      _selectedIndex = index;
      _isAnswered = true;
      _userAnswers[_currentIndex] = index;
      if (index == _questions[_currentIndex].correctIndex) {
        _score++;
      }
    });
    _scrollToBottom();
  }

  void _next() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedIndex = null;
        _isAnswered = false;
      });
      _scrollToTop();
    } else {
      _saveSession();
      setState(() => _showResult = true);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _retry() {
    setState(() {
      _currentIndex = 0;
      _selectedIndex = null;
      _isAnswered = false;
      _score = 0;
      _showResult = false;
      _hasSaved = false;
      _userAnswers.clear();
    });
    _generateQuestionsWithAI();
  }

  Future<void> _saveSession() async {
    if (_hasSaved) return;
    _hasSaved = true;
    final questionsData = _questions.asMap().entries.map((e) {
      final i = e.key;
      final q = e.value;
      return {
        'question': q.question,
        'options': q.options,
        'correctIndex': q.correctIndex,
        'userAnswer': _userAnswers[i],
        'isCorrect': _userAnswers[i] == q.correctIndex,
        'explanation': q.explanation,
      };
    }).toList();

    await HiveService.saveMasterGuideSession({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'chapterTitle': widget.chapter.title,
      'chapterNumber': widget.chapter.chapter,
      'score': _score,
      'total': _questions.length,
      'percentage': (_score / _questions.length * 100).round(),
      'date': DateTime.now().toIso8601String(),
      'questions': questionsData,
    });
  }

  void _showHistorySheet() {
    final sessions = HiveService.getMasterGuideHistory();
    if (sessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No history yet'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? AppColors.backgroundDark : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.borderDark : Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded,
                        size: 22, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text('Master Guide History',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (sessions.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_rounded,
                            size: 22, color: Colors.red),
                        tooltip: 'Delete all',
                        onPressed: () {
                          showDialog(
                            context: ctx,
                            builder: (dCtx) => AlertDialog(
                              title:
                                  const Text('Delete all history?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dCtx),
                                    child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () async {
                                    await HiveService
                                        .clearAllMasterGuideSessions();
                                    if (!dCtx.mounted) return;
                                    Navigator.pop(dCtx);
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('Delete All',
                                      style: TextStyle(
                                          color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              if (sessions.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_rounded,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('No history yet',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 15)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: sessions.length,
                    itemBuilder: (ctx, idx) {
                      final s = sessions[idx];
                      final title =
                          s['chapterTitle'] as String? ?? 'Unknown';
                      final score = s['score'] as int? ?? 0;
                      final total = s['total'] as int? ?? 0;
                      final dateStr = s['date'] as String? ?? '';
                      final percent = s['percentage'] as int? ?? 0;
                      final date = dateStr.isNotEmpty
                          ? _formatDate(DateTime.parse(dateStr))
                          : '';

                      return Dismissible(
                        key: ValueKey(s['id']),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          color: Colors.red,
                          child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                              size: 24),
                        ),
                        onDismissed: (_) async {
                          final history =
                              HiveService.getMasterGuideHistory();
                          final realIdx = history.indexWhere(
                              (h) => h['id'] == s['id']);
                          if (realIdx >= 0) {
                            await HiveService
                                .deleteMasterGuideSession(realIdx);
                          }
                          setSheetState(() {});
                        },
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: percent >= 50
                                    ? AppColors.secondaryGradient
                                    : AppColors.accentGradient,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('$percent%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  )),
                            ),
                          ),
                          title: Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Row(
                            children: [
                              Text('$score/$total',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: percent >= 50
                                        ? Colors.green
                                        : Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  )),
                              if (date.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(date,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    )),
                              ],
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.remove_red_eye_outlined,
                                size: 20, color: Colors.grey[400]),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _viewPastSession(s);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewPastSession(Map<String, dynamic> session) {
    final questions = (session['questions'] as List?) ?? [];
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No question details available'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.backgroundDark : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollCtrl,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.school,
                          color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(session['chapterTitle'] as String? ?? '',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w800)),
                          Text(
                            'Score: ${session['score']}/${session['total']} (${session['percentage']}%)',
                            style: TextStyle(
                              color: (session['percentage'] as int? ?? 0) >= 50
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...questions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final q = Map<String, dynamic>.from(entry.value as Map);
                  final isCorrect = q['isCorrect'] as bool? ?? false;
                  final options = (q['options'] as List?)?.cast<String>() ?? [];
                  final userAns = q['userAnswer'] as int?;
                  final correctIdx = q['correctIndex'] as int? ?? 0;
                  final explanation =
                      q['explanation'] as String? ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? Colors.green.withValues(alpha: 0.05)
                          : Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCorrect
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.red.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCorrect
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: isCorrect
                                  ? Colors.green
                                  : Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Q${i + 1}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                          fontWeight:
                                              FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(q['question'] as String? ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(height: 1.4)),
                        const SizedBox(height: 6),
                        Text(
                          'Your answer: ${userAns != null && userAns < options.length ? options[userAns] : 'N/A'}',
                          style: TextStyle(
                            color: isCorrect
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!isCorrect && correctIdx < options.length)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Correct: ${options[correctIdx]}',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (explanation.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary
                                  .withValues(alpha: 0.06),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Text(explanation,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(height: 1.5)),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Master Guide'),
          actions: [
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'History',
              onPressed: _showHistorySheet,
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 40),
                // Animated book icon
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.9, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (_, value, __) => Transform.scale(
                    scale: value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.2),
                            AppColors.purpleGradient[0].withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: AppColors.primaryGradient,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Main message
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.06),
                        AppColors.purpleGradient[0].withValues(alpha: 0.03),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Preparing Your Lesson',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Teacher Keshab is creating personalized questions\nbased on your chapter...',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Chapter info card
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Ch ${widget.chapter.chapter}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Flexible(
                        child: Text(
                          widget.chapter.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Animated dots
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.3, end: 1.0),
                      duration: Duration(milliseconds: 600 + i * 200),
                      builder: (_, value, __) => Opacity(
                        opacity: value,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(
                                alpha: 0.5 + i * 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Master Guide'),
          actions: [
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'History',
              onPressed: _showHistorySheet,
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.quiz_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('No questions available for this chapter.',
                  style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Chapter'),
              ),
            ],
          ),
        ),
      );
    }

    if (_showResult) {
      return _buildResultScreen(theme, isDark);
    }

    final q = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Guide'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'History',
            onPressed: _showHistorySheet,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1}/${_questions.length}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 16),

          // Question card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  isDark ? AppColors.surfaceDark : Colors.white,
                  isDark ? Colors.grey[900]! : Colors.grey[50]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.help_outline,
                          color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text('Question',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        )),
                  ],
                ),
                const SizedBox(height: 14),
                Text(q.question,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.6,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Options
          ...q.options.asMap().entries.map((entry) {
            final i = entry.key;
            final option = entry.value;
            final letter = String.fromCharCode(65 + i);
            final isSelected = _selectedIndex == i;
            final isCorrectOption = i == q.correctIndex;

            Color? bgColor;
            Color? borderColor;
            Color? letterBg;
            IconData? icon;

            if (_isAnswered) {
              if (isCorrectOption) {
                bgColor = Colors.green.withValues(alpha: 0.1);
                borderColor = Colors.green;
                letterBg = Colors.green;
                icon = Icons.check_circle;
              } else if (isSelected && !isCorrectOption) {
                bgColor = Colors.red.withValues(alpha: 0.1);
                borderColor = Colors.red;
                letterBg = Colors.red;
                icon = Icons.cancel;
              } else {
                bgColor = isDark ? AppColors.surfaceDark : Colors.grey[50];
                borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
                letterBg = Colors.grey[400];
              }
            } else {
              bgColor = isSelected
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : (isDark ? AppColors.surfaceDark : Colors.grey[50]);
              borderColor = isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.borderDark : AppColors.borderLight);
              letterBg =
                  isSelected ? AppColors.primary : Colors.grey[400];
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _selectOption(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: letterBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: icon != null
                              ? Icon(icon, color: Colors.white, size: 18)
                              : Text(letter,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  )),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(option,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                              decoration: _isAnswered && isSelected && !isCorrectOption
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: _isAnswered && isSelected && !isCorrectOption
                                  ? Colors.red.shade700
                                  : null,
                            )),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Explanation
          if (_isAnswered && q.explanation != null && q.explanation!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _TeacherExplanationCard(
              explanation: q.explanation!,
              isCorrect: _selectedIndex == q.correctIndex,
              isDark: isDark,
              theme: theme,
            ),
          ],

          if (_isAnswered) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _next,
                icon: Icon(_currentIndex < _questions.length - 1
                    ? Icons.arrow_forward
                    : Icons.send_rounded),
                label: Text(
                  _currentIndex < _questions.length - 1
                      ? 'Next Question'
                      : 'See Results',
                  style:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultScreen(ThemeData theme, bool isDark) {
    final percentage =
        _questions.isEmpty ? 0 : (_score / _questions.length * 100).round();
    final isPassed = percentage >= 50;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Guide'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'History',
            onPressed: _showHistorySheet,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPassed
                    ? [Colors.green.withValues(alpha: 0.15), Colors.green.withValues(alpha: 0.05)]
                    : [Colors.orange.withValues(alpha: 0.15), Colors.orange.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPassed
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.orange.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isPassed
                          ? AppColors.secondaryGradient
                          : AppColors.accentGradient,
                    ),
                  ),
                  child: Center(
                    child: Text('$percentage%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        )),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isPassed ? 'Great Job! 🎉' : 'Keep Practicing! 💪',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'You got $_score out of ${_questions.length} correct',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isPassed
                        ? 'Excellent work! You have a good understanding of ${widget.chapter.title}. Review any questions you got wrong to strengthen your knowledge even further.'
                        : 'Don\'t worry! Learning grammar takes time. Review the chapter and try again. Focus on the concepts you missed.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text('Answer Review',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),

          ..._questions.asMap().entries.map((entry) {
            final i = entry.key;
            final q = entry.value;
            final userAns = _userAnswers[i];
            final isCorrect = userAns == q.correctIndex;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isCorrect
                    ? Colors.green.withValues(alpha: 0.05)
                    : Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCorrect
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Q${i + 1}',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      Text(
                        isCorrect ? 'Correct' : 'Incorrect',
                        style: TextStyle(
                          color: isCorrect ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(q.question,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    'Your answer: ${userAns != null ? q.options[userAns] : 'Not answered'}',
                    style: TextStyle(
                      color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!isCorrect)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Correct: ${q.options[q.correctIndex]}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (q.explanation != null && q.explanation!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: () =>
                            _showExplanationDialog(i, q.explanation!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.school,
                                  size: 14, color: AppColors.primary),
                              SizedBox(width: 6),
                              Text('View Explanation',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showExplanationDialog(int questionIndex, String explanation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.backgroundDark
                : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollCtrl,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text("Teacher's Explanation",
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 20),
              Text(explanation,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherExplanationCard extends StatelessWidget {
  final String explanation;
  final bool isCorrect;
  final bool isDark;
  final ThemeData theme;

  const _TeacherExplanationCard({
    required this.explanation,
    required this.isCorrect,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCorrect
              ? [Colors.green.withValues(alpha: 0.08), Colors.green.withValues(alpha: 0.02)]
              : [Colors.orange.withValues(alpha: 0.08), Colors.orange.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.orange.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCorrect ? Icons.check_circle : Icons.auto_awesome,
                  color: isCorrect ? Colors.green : Colors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCorrect ? 'Correct! 🎉' : 'Not quite! 💪',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isCorrect ? Colors.green : Colors.orange,
                    ),
                  ),
                  Text(
                    'Teacher Keshab says:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            explanation,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
