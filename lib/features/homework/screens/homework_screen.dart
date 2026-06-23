import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/ai_service.dart';
import '../../../services/hive_service.dart';
import '../models/homework_model.dart';
import 'homework_history_screen.dart';

class HomeworkScreen extends ConsumerStatefulWidget {
  const HomeworkScreen({super.key});

  @override
  ConsumerState<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends ConsumerState<HomeworkScreen> {
  HomeworkStep _currentStep = HomeworkStep.topic;
  final _questions = <HomeworkQuestion>[];
  final _topicController = TextEditingController();
  final _controllers = <TextEditingController>[];
  bool _isLoading = false;
  bool _isSaved = false;
  int _score = 0;
  String _error = '';

  final _topicSuggestions = [
    'Daily Routine',
    'My Family',
    'Food & Eating',
    'Travel & Journey',
    'School & Education',
    'Weather & Seasons',
    'Shopping & Market',
    'Health & Fitness',
    'Friends & Social Life',
    'Hobbies & Free Time',
    'My Home',
    'Festivals in Bangladesh',
  ];

  @override
  void dispose() {
    _topicController.dispose();
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _currentStep = HomeworkStep.topic;
      _questions.clear();
      _topicController.clear();
      for (final c in _controllers) c.dispose();
      _controllers.clear();
      _score = 0;
      _isSaved = false;
      _error = '';
    });
  }

  Future<void> _generateQuestions() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      setState(() => _error = 'দয়া করে একটি বিষয় লিখুন');
      return;
    }

    setState(() {
      _currentStep = HomeworkStep.generating;
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await AIService().sendMessageWithSystem(
        'Generate exactly 10 simple Bengali sentences on the topic "$topic" for English translation practice. '
        'Return ONLY a valid JSON array of strings. Example: ["বাক্য ১", "বাক্য ২"]',
        systemPrompt: 'You are a helpful English teacher. Always respond in valid JSON format only. '
            'Generate natural, everyday Bengali sentences that are useful for real-life conversation.',
      );

      final cleaned = _extractJson(response);
      final List<dynamic> sentences = jsonDecode(cleaned);

      if (sentences.length < 10) {
        throw Exception('Only ${sentences.length} sentences generated');
      }

      setState(() {
        _questions.clear();
        for (final s in sentences.take(10)) {
          _questions.add(HomeworkQuestion(banglaSentence: s.toString()));
        }
        _controllers.clear();
        for (var i = 0; i < _questions.length; i++) {
          _controllers.add(TextEditingController());
        }
        _currentStep = HomeworkStep.translating;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'বাক্য তৈরি করতে সমস্যা হয়েছে। আবার চেষ্টা করুন।';
        _isLoading = false;
        _currentStep = HomeworkStep.topic;
      });
    }
  }

  Future<void> _submitTranslations() async {
    for (int i = 0; i < _controllers.length; i++) {
      _questions[i].userTranslation = _controllers[i].text.trim();
    }

    setState(() {
      _currentStep = HomeworkStep.reviewing;
      _isLoading = true;
    });

    try {
      final inputJson = jsonEncode(_questions.map((q) => {
        'bangla': q.banglaSentence,
        'userTranslation': q.userTranslation ?? '',
      }).toList());

      final response = await AIService().sendMessageWithSystem(
        'Review these 10 Bangla to English translations. For each, provide the correct English translation, '
        'whether the user was correct, and feedback in Bangla explaining the mistake if any.\n\n'
        'Input: $inputJson\n\n'
        'Return ONLY a valid JSON array of objects with keys: correctTranslation (string), isCorrect (bool), feedback (string in Bangla).\n'
        'Example: [{"correctTranslation":"...","isCorrect":true,"feedback":""}]',
        systemPrompt: 'You are an English teacher. Review translations carefully considering grammar, meaning, and natural expression. '
            'Be encouraging but honest. Respond in valid JSON only.',
      );

      final cleaned = _extractJson(response);
      final List<dynamic> results = jsonDecode(cleaned);

      int correctCount = 0;
      for (int i = 0; i < results.length && i < _questions.length; i++) {
        final r = results[i] as Map<String, dynamic>;
        _questions[i].correctTranslation = r['correctTranslation'] as String?;
        _questions[i].isCorrect = r['isCorrect'] as bool?;
        _questions[i].feedback = r['feedback'] as String?;
        if (_questions[i].isCorrect == true) correctCount++;
      }

      setState(() {
        _score = correctCount;
        _currentStep = HomeworkStep.completed;
        _isLoading = false;
      });

      HapticFeedback.mediumImpact();
    } catch (e) {
      setState(() {
        _error = 'পর্যালোচনা করতে সমস্যা হয়েছে। আবার চেষ্টা করুন।';
        _isLoading = false;
        _currentStep = HomeworkStep.translating;
      });
    }
  }

  Future<void> _saveToHistory() async {
    final session = {
      'topic': _topicController.text.trim(),
      'date': DateTime.now().toIso8601String(),
      'score': _score,
      'total': _questions.length,
      'questions': _questions.map((q) => {
        'bangla': q.banglaSentence,
        'userTranslation': q.userTranslation ?? '',
        'correctTranslation': q.correctTranslation ?? '',
        'isCorrect': q.isCorrect ?? false,
        'feedback': q.feedback ?? '',
      }).toList(),
    };
    await HiveService.saveHomeworkSession(session);
    setState(() => _isSaved = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Saved to history!'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _extractJson(String text) {
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    return text;
  }

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
            const Icon(Icons.home_work_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text('Homework',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Theme.of(context).textTheme.titleLarge?.color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeworkHistoryScreen()),
            ),
          ),
          if (_currentStep != HomeworkStep.topic)
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
      case HomeworkStep.topic:
        return _buildTopicStep(theme, isDark);
      case HomeworkStep.generating:
        return _buildLoadingStep(theme, isDark, 'তোমার জন্য বাক্য তৈরি করা হচ্ছে...');
      case HomeworkStep.translating:
        return _buildTranslatingStep(theme, isDark);
      case HomeworkStep.reviewing:
        return _buildLoadingStep(theme, isDark, 'তোমার উত্তর পর্যালোচনা করা হচ্ছে...');
      case HomeworkStep.completed:
        return _buildResultsStep(theme, isDark);
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
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.primaryGradient),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 44),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'AI Homework',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a topic. The AI teacher will create 10 Bangla sentences\nfor you to translate into English.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _topicController,
            decoration: InputDecoration(
              labelText: 'Enter a topic',
              hintText: 'e.g. Daily Routine, My Family...',
              prefixIcon: const Icon(Icons.topic_rounded, color: AppColors.primary),
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
            onSubmitted: (_) => _generateQuestions(),
          ),
          const SizedBox(height: 12),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
            ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _generateQuestions,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Generate Homework', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Suggested Topics',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _topicSuggestions.map((t) {
              return ActionChip(
                label: Text(t, style: const TextStyle(fontSize: 13)),
                avatar: const Icon(Icons.topic_rounded, size: 16, color: AppColors.primary),
                onPressed: () {
                  _topicController.text = t;
                  _generateQuestions();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingStep(ThemeData theme, bool isDark, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 64, height: 64,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait a moment...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslatingStep(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.primaryGradient),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('HOMEWORK',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                  const Spacer(),
                  Text('${_questions.length} questions',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Translate these sentences to English',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_topicController.text.trim(),
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: _questions.length + 1,
            itemBuilder: (_, i) {
              if (i == _questions.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _submitTranslations,
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Submit All Answers',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                );
              }
              return _buildQuestionCard(theme, isDark, i);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(ThemeData theme, bool isDark, int index) {
    final q = _questions[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: AppColors.primaryGradient),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('${index + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    q.banglaSentence,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: isDark ? Colors.grey[200] : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controllers[index],
              decoration: InputDecoration(
                hintText: 'English translation...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[900]! : Colors.grey[50],
              ),
              style: theme.textTheme.bodyLarge,
              textInputAction: TextInputAction.next,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsStep(ThemeData theme, bool isDark) {
    final total = _questions.length;
    final percentage = (total > 0) ? (_score / total) : 0.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: percentage >= 0.7
                    ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                    : percentage >= 0.4
                        ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
                        : const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    percentage >= 0.7 ? '🎉' : percentage >= 0.4 ? '💪' : '📚',
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    percentage >= 0.7 ? 'Excellent!' : percentage >= 0.4 ? 'Good Effort!' : 'Keep Practicing!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_score / $total Correct',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(percentage * 100).toInt()}% Accuracy',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      color: Colors.white,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.reviews_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text('Detailed Review',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(_questions.length, (i) => _buildResultCard(theme, isDark, i)),
          const SizedBox(height: 24),
          if (!_isSaved)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _saveToHistory,
                icon: const Icon(Icons.bookmark_add_rounded),
                label: const Text('Save to History',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          if (_isSaved)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                  SizedBox(width: 8),
                  Text('Saved to History',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('New Homework',
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

  Widget _buildResultCard(ThemeData theme, bool isDark, int index) {
    final q = _questions[index];
    final isCorrect = q.isCorrect ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCorrect
                ? Colors.green.withOpacity(0.4)
                : Colors.red.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: isCorrect ? Colors.green : Colors.red,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isCorrect ? 'CORRECT' : 'WRONG',
                    style: TextStyle(
                      color: isCorrect ? Colors.green : Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Spacer(),
                Text('#${index + 1}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('বাংলা:', style: TextStyle(
                    color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(q.banglaSentence,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey[200] : Colors.black87,
                    )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? Colors.green.withOpacity(0.05)
                          : Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCorrect
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Answer:',
                          style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          q.userTranslation?.isNotEmpty == true
                              ? q.userTranslation!
                              : '(empty)',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isCorrect ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Correct:',
                          style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          q.correctTranslation ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (q.feedback != null && q.feedback!.isNotEmpty && !isCorrect) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_rounded, color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        q.feedback!,
                        style: TextStyle(
                          color: isDark ? Colors.grey[200] : Colors.black87,
                          fontSize: 13,
                          height: 1.4,
                        ),
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
}
