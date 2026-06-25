import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/ai_service.dart';
import '../../../services/hive_service.dart';
import '../models/sentence_analysis_model.dart';
import 'sentence_analysis_history_screen.dart';

class SentenceAnalyzerScreen extends ConsumerStatefulWidget {
  const SentenceAnalyzerScreen({super.key});

  @override
  ConsumerState<SentenceAnalyzerScreen> createState() => _SentenceAnalyzerScreenState();
}

class _SentenceAnalyzerScreenState extends ConsumerState<SentenceAnalyzerScreen> {
  AnalyzerStep _currentStep = AnalyzerStep.topic;
  final _answerController = TextEditingController();
  bool _isLoading = false;
  bool _isSaved = false;
  String _error = '';

  SentenceAnalysis? _analysis;
  PracticeTask? _task;
  AnswerReview? _review;

  final _tenses = [
    {'name': 'Present Simple', 'icon': Icons.repeat_rounded, 'color': const Color(0xFF10B981), 'desc': 'সাধারণ বর্তমান (I eat, He goes)'},
    {'name': 'Present Continuous', 'icon': Icons.timer_rounded, 'color': const Color(0xFF06B6D4), 'desc': 'ঘটমান বর্তমান (I am eating)'},
    {'name': 'Present Perfect', 'icon': Icons.check_circle_rounded, 'color': const Color(0xFF8B5CF6), 'desc': 'পুরাঘটিত বর্তমান (I have eaten)'},
    {'name': 'Past Simple', 'icon': Icons.skip_previous_rounded, 'color': const Color(0xFFF59E0B), 'desc': 'সাধারণ অতীত (I ate, He went)'},
    {'name': 'Past Continuous', 'icon': Icons.timer_off_rounded, 'color': const Color(0xFFEF4444), 'desc': 'ঘটমান অতীত (I was eating)'},
    {'name': 'Past Perfect', 'icon': Icons.done_all_rounded, 'color': const Color(0xFFEC4899), 'desc': 'পুরাঘটিত অতীত (I had eaten)'},
    {'name': 'Future Simple', 'icon': Icons.skip_next_rounded, 'color': const Color(0xFF6366F1), 'desc': 'সাধারণ ভবিষ্যৎ (I will eat)'},
    {'name': 'Future Continuous', 'icon': Icons.hourglass_top_rounded, 'color': const Color(0xFF14B8A6), 'desc': 'ঘটমান ভবিষ্যৎ (I will be eating)'},
    {'name': 'Future Perfect', 'icon': Icons.rocket_rounded, 'color': const Color(0xFFF97316), 'desc': 'পুরাঘটিত ভবিষ্যৎ (I will have eaten)'},
  ];

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _currentStep = AnalyzerStep.topic;
      _answerController.clear();
      _analysis = null;
      _task = null;
      _review = null;
      _isSaved = false;
      _error = '';
    });
  }

  Future<void> _analyzeSentence(String tense) async {
    setState(() {
      _currentStep = AnalyzerStep.analyzing;
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await AIService().sendMessageWithSystem(
        'Create one natural Bangla sentence in "$tense" tense and analyze it.\n\n'
        'Example format (for "$tense"):\n'
        '{\n'
        '  "banglaSentence": "আমি প্রতিদিন ভাত খাই।",\n'
        '  "tense": "Present Simple — নিয়মিত কাজ বা অভ্যাস বোঝাতে ব্যবহার হয়।",\n'
        '  "subject": "আমি (I)",\n'
        '  "object": "ভাত (rice)",\n'
        '  "wordBreakdown": "আমি = Subject\\nপ্রতিদিন = Time expression\\nভাত = Object\\nখাই = Present simple verb",\n'
        '  "englishTranslation": "I eat rice every day.",\n'
        '  "explanation": "এই বাক্যে কাজটি নিয়মিত হয়। English-এ Subject + base verb + object + time ব্যবহার করা হয়েছে।"\n'
        '}\n\n'
        'Now create a similar Bangla sentence for "$tense" tense following this EXACT structure.\n'
        'IMPORTANT:\n'
        '- Return ONLY valid JSON (no markdown, no code blocks, no extra text)\n'
        '- Use \\n for line breaks in wordBreakdown\n'
        '- Keep tense explanation in Bangla\n'
        '- If no object exists, use empty string "" for object field\n'
        '- Make the sentence natural and easy to understand',
        systemPrompt: 'You are a Bengali grammar expert. Return ONLY valid JSON. '
            'Never use markdown code blocks or extra formatting. '
            'Explain grammar in simple Bangla that beginners can understand easily.',
        maxTokens: 2048,
      );

      final data = _decodeJsonObject(response);
      final analysis = SentenceAnalysis.fromJson(data);
      if (!analysis.isValid) throw Exception('Invalid analysis response');

      setState(() {
        _analysis = analysis;
        _isSaved = false;
        _currentStep = AnalyzerStep.explanation;
        _isLoading = false;
        _error = '';
      });
    } catch (_) {
      setState(() {
        _analysis = _buildLocalAnalysis(tense);
        _isSaved = false;
        _error = 'AI এখন unavailable, তাই offline example দেখানো হচ্ছে।';
        _isLoading = false;
        _currentStep = AnalyzerStep.explanation;
      });
    }
  }

  Future<void> _generateTask() async {
    if (_analysis == null) return;

    setState(() {
      _currentStep = AnalyzerStep.generatingTask;
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await AIService().sendMessageWithSystem(
        'Based on this Bangla sentence: "${_analysis!.banglaSentence}"\n'
        'English: "${_analysis!.englishTranslation}"\n\n'
        'Create a translation practice task.\n\n'
        'Example format:\n'
        '{\n'
        '  "instruction": "এখন তুমি চেষ্টা করো: \\"${_analysis!.banglaSentence}\\" বাক্যটি ইংরেজিতে অনুবাদ করো।",\n'
        '  "correctAnswer": "${_analysis!.englishTranslation}"\n'
        '}\n\n'
        'Return ONLY this JSON structure with the task.\n'
        'IMPORTANT:\n'
        '- Use the EXACT Bangla sentence in instruction\n'
        '- Use the EXACT English translation as correctAnswer\n'
        '- No markdown, no code blocks, just pure JSON',
        systemPrompt: 'You are a Bengali grammar teacher. Return ONLY valid JSON. '
            'Never add extra formatting or markdown blocks.',
        maxTokens: 1024,
      );

      final data = _decodeJsonObject(response);
      final task = PracticeTask.fromJson(data);
      if (!task.isValid) throw Exception('Invalid task response');

      setState(() {
        _task = task;
        _answerController.clear();
        _currentStep = AnalyzerStep.practicing;
        _isLoading = false;
        _error = '';
      });
    } catch (_) {
      setState(() {
        _task = _buildLocalTask(_analysis!);
        _answerController.clear();
        _error = 'AI task তৈরি করতে পারেনি, তাই offline practice দেওয়া হলো।';
        _isLoading = false;
        _currentStep = AnalyzerStep.practicing;
      });
    }
  }

  Future<void> _submitAnswer() async {
    if (_task == null) return;

    final userAnswer = _answerController.text.trim();
    if (userAnswer.isEmpty) {
      setState(() => _error = 'দয়া করে আগে তোমার উত্তর লিখো।');
      return;
    }

    setState(() {
      _currentStep = AnalyzerStep.reviewing;
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await AIService().sendMessageWithSystem(
        'Task: ${_task!.instruction}\n'
        'Expected correct answer: ${_task!.correctAnswer}\n'
        'User\'s answer: $userAnswer\n\n'
        'Review the user\'s answer. Is it correct? '
        'Return ONLY valid JSON with keys:\n'
        '- isCorrect: true/false (be generous - accept variations)\n'
        '- feedback: feedback in Bangla. If correct, say ধন্যবাদ! and praise. '
        'If wrong, gently explain the mistake and show the right answer.\n'
        'IMPORTANT: Do NOT wrap the JSON in markdown. Return ONLY the raw JSON object.',
        systemPrompt: 'You are a kind Bengali grammar teacher. Always encourage the student. '
            'Be generous in marking - accept reasonable variations. '
            'Respond in valid JSON only. Never use markdown code blocks.',
        maxTokens: 1024,
      );

      final data = _decodeJsonObject(response);
      final review = AnswerReview.fromJson(data);

      setState(() {
        _review = review.feedback.isEmpty
            ? _buildLocalReview(userAnswer, _task!.correctAnswer)
            : review;
        _currentStep = AnalyzerStep.completed;
        _isLoading = false;
      });

      HapticFeedback.mediumImpact();
    } catch (_) {
      setState(() {
        _review = _buildLocalReview(userAnswer, _task!.correctAnswer);
        _error = 'AI review unavailable, offline feedback দেখানো হচ্ছে।';
        _isLoading = false;
        _currentStep = AnalyzerStep.completed;
      });
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SentenceAnalysisHistoryScreen()),
    );
  }

  Future<void> _saveCurrentAnalysis() async {
    final analysis = _analysis;
    if (analysis == null || _isSaved) return;

    await HiveService.saveSentenceAnalysis({
      'date': DateTime.now().toIso8601String(),
      'banglaSentence': analysis.banglaSentence,
      'tense': analysis.tense,
      'subject': analysis.subject,
      'object': analysis.object,
      'wordBreakdown': analysis.wordBreakdown,
      'englishTranslation': analysis.englishTranslation,
      'explanation': analysis.explanation,
      if (_task != null)
        'practiceTask': {
          'instruction': _task!.instruction,
          'correctAnswer': _task!.correctAnswer,
        },
      if (_answerController.text.trim().isNotEmpty) 'userAnswer': _answerController.text.trim(),
      if (_review != null)
        'answerReview': {
          'isCorrect': _review!.isCorrect,
          'feedback': _review!.feedback,
        },
    });

    if (!mounted) return;
    setState(() => _isSaved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Saved to list!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: _openHistory,
        ),
      ),
    );
  }

  Map<String, dynamic> _decodeJsonObject(String response) {
    final cleaned = _extractJson(response);
    final decoded = jsonDecode(cleaned);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('Expected a JSON object');
  }

  String _extractJson(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'```json', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();

    final objectJson = _extractBalancedJson(cleaned, '{', '}');
    if (objectJson != null) return objectJson;

    final arrayJson = _extractBalancedJson(cleaned, '[', ']');
    if (arrayJson != null) return arrayJson;

    return cleaned;
  }

  String? _extractBalancedJson(String text, String open, String close) {
    final start = text.indexOf(open);
    if (start == -1) return null;

    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final char = text[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == '\\') {
        escaped = true;
        continue;
      }
      if (char == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (char == open) depth++;
      if (char == close) depth--;
      if (depth == 0) return text.substring(start, i + 1);
    }
    return null;
  }

  SentenceAnalysis _buildLocalAnalysis(String tense) {
    final data = _localAnalysisData[tense] ?? _localAnalysisData['Present Simple']!;
    return SentenceAnalysis.fromJson(data);
  }

  PracticeTask _buildLocalTask(SentenceAnalysis analysis) {
    final expected = analysis.englishTranslation.trim().isNotEmpty
        ? analysis.englishTranslation.trim()
        : 'I eat rice every day.';
    return PracticeTask(
      instruction: 'এখন তুমি চেষ্টা করো: "${analysis.banglaSentence}" বাক্যটি ইংরেজিতে অনুবাদ করো।',
      correctAnswer: expected,
    );
  }

  AnswerReview _buildLocalReview(String userAnswer, String correctAnswer) {
    final normalizedUser = _normalizeAnswer(userAnswer);
    final normalizedCorrect = _normalizeAnswer(correctAnswer);
    final isCorrect = normalizedUser == normalizedCorrect ||
        normalizedCorrect.contains(normalizedUser) ||
        normalizedUser.contains(normalizedCorrect);

    return AnswerReview(
      isCorrect: isCorrect,
      feedback: isCorrect
          ? 'ধন্যবাদ! তোমার উত্তরটি সঠিক। এভাবেই tense pattern মনে রেখে practice চালিয়ে যাও।'
          : 'ভালো চেষ্টা! সঠিক উত্তর হবে: $correctAnswer। Subject + Verb + Object order এবং tense marker ভালোভাবে মিলিয়ে দেখো।',
    );
  }

  String _normalizeAnswer(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static final Map<String, Map<String, dynamic>> _localAnalysisData = {
    'Present Simple': {
      'banglaSentence': 'আমি প্রতিদিন ভাত খাই।',
      'tense': 'Present Simple — নিয়মিত কাজ বা অভ্যাস বোঝাতে ব্যবহার হয়।',
      'subject': 'আমি (I)',
      'object': 'ভাত (rice)',
      'wordBreakdown': 'আমি = Subject\nপ্রতিদিন = Time expression\nভাত = Object\nখাই = Present simple verb idea',
      'englishTranslation': 'I eat rice every day.',
      'explanation': 'এই বাক্যে কাজটি নিয়মিত হয়। English-এ Subject + base verb + object + time ব্যবহার করা হয়েছে।',
    },
    'Present Continuous': {
      'banglaSentence': 'সে এখন বই পড়ছে।',
      'tense': 'Present Continuous — এখন ঘটছে এমন কাজ বোঝায়।',
      'subject': 'সে (He/She)',
      'object': 'বই (book)',
      'wordBreakdown': 'সে = Subject\nএখন = এখন/now\nবই = Object\nপড়ছে = is reading',
      'englishTranslation': 'She is reading a book now.',
      'explanation': 'বাংলায় “ছে” থাকলে অনেক সময় English-এ am/is/are + verb-ing ব্যবহার হয়।',
    },
    'Present Perfect': {
      'banglaSentence': 'আমি কাজটি শেষ করেছি।',
      'tense': 'Present Perfect — অতীতে শেষ হয়েছে কিন্তু বর্তমানের সাথে সম্পর্ক আছে।',
      'subject': 'আমি (I)',
      'object': 'কাজটি (the work)',
      'wordBreakdown': 'আমি = Subject\nকাজটি = Object\nশেষ করেছি = have finished',
      'englishTranslation': 'I have finished the work.',
      'explanation': 'এই tense-এ have/has + past participle ব্যবহার হয়। কাজ শেষ হওয়ার ফল এখন গুরুত্বপূর্ণ।',
    },
    'Past Simple': {
      'banglaSentence': 'রাহিম গতকাল স্কুলে গেল।',
      'tense': 'Past Simple — অতীতে শেষ হওয়া কাজ বোঝায়।',
      'subject': 'রাহিম (Rahim)',
      'object': '',
      'wordBreakdown': 'রাহিম = Subject\nগতকাল = Past time\nস্কুলে = Place\nগেল = went',
      'englishTranslation': 'Rahim went to school yesterday.',
      'explanation': 'Past Simple-এ verb-এর past form ব্যবহার হয়। এখানে went হলো go-এর past form।',
    },
    'Past Continuous': {
      'banglaSentence': 'আমি তখন গান শুনছিলাম।',
      'tense': 'Past Continuous — অতীতের কোনো সময়ে কাজ চলছিল বোঝায়।',
      'subject': 'আমি (I)',
      'object': 'গান (music/song)',
      'wordBreakdown': 'আমি = Subject\nতখন = at that time\nগান = Object\nশুনছিলাম = was listening',
      'englishTranslation': 'I was listening to music then.',
      'explanation': 'Past Continuous-এ was/were + verb-ing ব্যবহার হয়।',
    },
    'Past Perfect': {
      'banglaSentence': 'সে আসার আগে আমি খেয়ে নিয়েছিলাম।',
      'tense': 'Past Perfect — অতীতের আরেকটি ঘটনার আগেই শেষ হওয়া কাজ।',
      'subject': 'আমি (I)',
      'object': '',
      'wordBreakdown': 'সে আসার আগে = before he came\nআমি = Subject\nখেয়ে নিয়েছিলাম = had eaten',
      'englishTranslation': 'I had eaten before he came.',
      'explanation': 'Past Perfect-এ had + past participle ব্যবহার হয়। আগে শেষ হওয়া কাজটি had eaten।',
    },
    'Future Simple': {
      'banglaSentence': 'আমি কাল বাজারে যাব।',
      'tense': 'Future Simple — ভবিষ্যতের কাজ বোঝায়।',
      'subject': 'আমি (I)',
      'object': '',
      'wordBreakdown': 'আমি = Subject\nকাল = Tomorrow\nবাজারে = Place\nযাব = will go',
      'englishTranslation': 'I will go to the market tomorrow.',
      'explanation': 'Future Simple-এ সাধারণত will + base verb ব্যবহার হয়।',
    },
    'Future Continuous': {
      'banglaSentence': 'সে সন্ধ্যায় পড়তে থাকবে।',
      'tense': 'Future Continuous — ভবিষ্যতের কোনো সময়ে কাজ চলতে থাকবে।',
      'subject': 'সে (He/She)',
      'object': '',
      'wordBreakdown': 'সে = Subject\nসন্ধ্যায় = in the evening\nপড়তে থাকবে = will be studying',
      'englishTranslation': 'She will be studying in the evening.',
      'explanation': 'Future Continuous-এ will be + verb-ing ব্যবহার হয়।',
    },
    'Future Perfect': {
      'banglaSentence': 'আমি রাতের আগে কাজটি শেষ করে ফেলব।',
      'tense': 'Future Perfect — ভবিষ্যতের নির্দিষ্ট সময়ের আগে কাজ শেষ হবে।',
      'subject': 'আমি (I)',
      'object': 'কাজটি (the work)',
      'wordBreakdown': 'আমি = Subject\nরাতের আগে = before night\nকাজটি = Object\nশেষ করে ফেলব = will have finished',
      'englishTranslation': 'I will have finished the work before night.',
      'explanation': 'Future Perfect-এ will have + past participle ব্যবহার হয়।',
    },
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_stories_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text('Sentence Analyzer',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Theme.of(context).textTheme.titleLarge?.color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openHistory,
            icon: const Icon(Icons.bookmarks_rounded),
            tooltip: 'Saved Analyses',
          ),
          if (_analysis != null)
            IconButton(
              onPressed: _isSaved ? null : _saveCurrentAnalysis,
              icon: Icon(_isSaved ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined),
              tooltip: _isSaved ? 'Already Saved' : 'Save Analysis',
            ),
          if (_currentStep != AnalyzerStep.topic)
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('New'),
            ),
        ],
      ),
      body: _buildBody(theme, isDark),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    switch (_currentStep) {
      case AnalyzerStep.topic:
        return _buildTopicStep(theme, isDark);
      case AnalyzerStep.analyzing:
        return _buildLoadingStep(theme, isDark, 'বাক্য বিশ্লেষণ করা হচ্ছে...');
      case AnalyzerStep.explanation:
        return _buildExplanationStep(theme, isDark);
      case AnalyzerStep.generatingTask:
        return _buildLoadingStep(theme, isDark, 'প্র্যাকটিস টাস্ক তৈরি করা হচ্ছে...');
      case AnalyzerStep.practicing:
        return _buildPracticeStep(theme, isDark);
      case AnalyzerStep.reviewing:
        return _buildLoadingStep(theme, isDark, 'উত্তর পরীক্ষা করা হচ্ছে...');
      case AnalyzerStep.completed:
        return _buildResultStep(theme, isDark);
    }
  }

  Widget _buildTopicStep(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 44),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sentence Analyzer',
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a tense. AI will show a Bangla sentence,\nexplain its grammar, then give you a practice task.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 13))),
                  ],
                ),
              ),
            ),
          ...List.generate((_tenses.length / 2).ceil(), (rowIndex) {
            final start = rowIndex * 2;
            final end = (start + 2).clamp(0, _tenses.length);
            final rowTenses = _tenses.sublist(start, end);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: rowTenses.map((t) {
                  final name = t['name'] as String;
                  final icon = t['icon'] as IconData;
                  final color = t['color'] as Color;
                  final desc = t['desc'] as String;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _analyzeSentence(name),
                      child: Container(
                        margin: rowTenses.length == 1 ? EdgeInsets.zero : EdgeInsets.only(right: rowTenses.indexOf(t) == 0 ? 12 : 0),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color, color.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 12),
                            Text(name,
                              style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(desc,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85), fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLoadingStep(ThemeData theme, bool isDark, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 64, height: 64,
            child: CircularProgressIndicator(strokeWidth: 4, color: Color(0xFF8B5CF6)),
          ),
          const SizedBox(height: 24),
          Text(message,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text('Please wait a moment...',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildExplanationStep(ThemeData theme, bool isDark) {
    if (_analysis == null) return const SizedBox();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('BANGLA SENTENCE',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _analysis!.banglaSentence,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _analysis!.englishTranslation,
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.psychology_rounded, color: Color(0xFF8B5CF6), size: 22),
              ),
              const SizedBox(width: 10),
              Text('Grammar Analysis',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(theme, isDark, 'Tense (কাল)', _analysis!.tense, Icons.schedule_rounded, const Color(0xFF06B6D4)),
          const SizedBox(height: 10),
          _buildInfoCard(theme, isDark, 'Subject (কর্তা)', _analysis!.subject, Icons.person_rounded, const Color(0xFF10B981)),
          const SizedBox(height: 10),
          if (_analysis!.object.isNotEmpty)
            _buildInfoCard(theme, isDark, 'Object (কর্ম)', _analysis!.object, Icons.ads_click_rounded, const Color(0xFFF59E0B)),
          if (_analysis!.object.isEmpty)
            _buildInfoCard(theme, isDark, 'Object (কর্ম)', 'No object (অকর্মক বাক্য)', Icons.ads_click_rounded, Colors.grey),
          const SizedBox(height: 10),
          if (_analysis!.wordBreakdown.isNotEmpty) ...[
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
                  Row(
                    children: [
                      Icon(Icons.abc_rounded, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text('Word Breakdown',
                        style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_analysis!.wordBreakdown,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_rounded, color: Color(0xFF8B5CF6), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_analysis!.explanation,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error,
                style: TextStyle(
                  color: _error.contains('offline') || _error.contains('unavailable')
                      ? const Color(0xFFF59E0B)
                      : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _isSaved ? null : _saveCurrentAnalysis,
              icon: Icon(_isSaved ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined),
              label: Text(_isSaved ? 'Saved to List' : 'Save This Analysis',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
                side: const BorderSide(color: Color(0xFF8B5CF6), width: 1.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 52,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _generateTask,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('আমি বুঝতে পেরেছি! চেষ্টা করব',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, bool isDark, String label, String value, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeStep(ThemeData theme, bool isDark) {
    if (_task == null) return const SizedBox();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('PRACTICE TASK',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _task!.instruction,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _answerController,
            decoration: InputDecoration(
              labelText: 'তোমার উত্তর',
              hintText: 'Type your answer here...',
              prefixIcon: const Icon(Icons.edit_rounded, color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            ),
            style: theme.textTheme.bodyLarge,
            textInputAction: TextInputAction.done,
            maxLines: 3,
            minLines: 1,
            onSubmitted: (_) => _submitAnswer(),
          ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error,
                style: TextStyle(
                  color: _error.contains('offline') || _error.contains('unavailable')
                      ? const Color(0xFFF59E0B)
                      : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 52,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _submitAnswer,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Submit Answer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildResultStep(ThemeData theme, bool isDark) {
    if (_review == null || _analysis == null) return const SizedBox();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: _review!.isCorrect
                    ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                    : const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: (_review!.isCorrect ? Colors.green : Colors.red).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(_review!.isCorrect ? '🎉' : '💪',
                    style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    _review!.isCorrect ? 'সঠিক উত্তর! ধন্যবাদ!' : 'ভুল হয়েছে, কিন্তু শিখে ফেলো!',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _analysis!.banglaSentence,
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _review!.isCorrect
                  ? Colors.green.withOpacity(0.05)
                  : const Color(0xFFF59E0B).withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _review!.isCorrect
                    ? Colors.green.withOpacity(0.2)
                    : const Color(0xFFF59E0B).withOpacity(0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _review!.isCorrect ? Icons.check_circle_rounded : Icons.lightbulb_rounded,
                  color: _review!.isCorrect ? Colors.green : const Color(0xFFF59E0B),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _review!.feedback,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          if (!_review!.isCorrect && _task != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('সঠিক উত্তর:', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_task!.correctAnswer,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _isSaved ? null : _saveCurrentAnalysis,
              icon: Icon(_isSaved ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined),
              label: Text(_isSaved ? 'Saved to List' : 'Save Full Result',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 52,
            child: FilledButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('New Sentence',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
