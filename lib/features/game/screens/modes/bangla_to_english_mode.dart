import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/haptic_service.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../../../models/game/wrong_question_model.dart';
import '../../../../repositories/wrong_question_repository.dart';
import '../../../../providers/game/tts_provider.dart';
import '../result_screen.dart';
import '../../../../services/haptic_service.dart';

class BanglaToEnglishModeScreen extends ConsumerStatefulWidget {
  const BanglaToEnglishModeScreen({super.key});

  @override
  ConsumerState<BanglaToEnglishModeScreen> createState() => _BanglaToEnglishModeScreenState();
}

class _QuestionData {
  final String id;
  final String bangla;
  final String correct;
  final List<String> options;
  final String explanation;
  final String? rule;
  final String? errorType;
  final String difficulty;

  _QuestionData({
    required this.id,
    required this.bangla,
    required this.correct,
    required this.options,
    required this.explanation,
    this.rule,
    this.errorType,
    required this.difficulty,
  });
}

class _TopicData {
  final String id;
  final String name;
  final String nameBn;
  final String icon;
  final List<_QuestionData> questions;

  _TopicData({
    required this.id,
    required this.name,
    required this.nameBn,
    required this.icon,
    required this.questions,
  });
}

class _BanglaToEnglishModeScreenState extends ConsumerState<BanglaToEnglishModeScreen>
    with TickerProviderStateMixin {
  List<_TopicData> _topics = [];
  final List<_QuestionData> _allQuestions = [];
  bool _isLoading = true;
  bool _showTopicSelection = true;

  // Game state
  _TopicData? _selectedTopic;
  List<_QuestionData> _activeQuestions = [];
  int _currentIndex = 0;
  late List<String> _shuffledOptions;
  int _score = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  bool _isAnswered = false;
  bool? _isAnswerCorrect;
  int _nextCountdown = 0;
  Timer? _countdownTimer;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/json/game/bangla_to_english_data.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      _topics = (data['topics'] as List).map((t) {
        return _TopicData(
          id: t['id'] as String,
          name: t['name'] as String,
          nameBn: t['name_bn'] as String,
          icon: t['icon'] as String,
          questions: (t['questions'] as List).map((q) => _QuestionData(
            id: q['id'] as String,
            bangla: q['bangla'] as String,
            correct: q['correct'] as String,
            options: (q['options'] as List).map((o) => o as String).toList(),
            explanation: q['explanation'] as String? ?? q['rule'] as String? ?? '',
            rule: q['rule'] as String?,
            errorType: q['error_type'] as String?,
            difficulty: q['difficulty'] as String,
          )).toList(),
        );
      }).toList();

      for (var t in _topics) {
        _allQuestions.addAll(t.questions);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _selectTopic(_TopicData topic) {
    setState(() {
      _selectedTopic = topic;
      _showTopicSelection = false;
      _activeQuestions = topic.questions.toList()..shuffle(_random);
      _currentIndex = 0;
      _isAnswered = false;
      _score = 0;
      _correctCount = 0;
      _wrongCount = 0;
    });
    _prepareOptions();
  }

  void _selectAllTopics() {
    setState(() {
      _selectedTopic = _TopicData(
        id: 'all',
        name: 'All Topics',
        nameBn: 'সব বিষয়',
        icon: 'all',
        questions: [],
      );
      _showTopicSelection = false;
      _activeQuestions = _allQuestions.toList()..shuffle(_random);
      _currentIndex = 0;
      _isAnswered = false;
      _score = 0;
      _correctCount = 0;
      _wrongCount = 0;
    });
    _prepareOptions();
  }

  _QuestionData get _currentQuestion => _activeQuestions[_currentIndex];

  void _prepareOptions() {
    _shuffledOptions = _currentQuestion.options.toList()..shuffle(_random);
    _speakCurrentQuestion();
  }

  Future<void> _speakCurrentQuestion() async {
    try {
      // Using speakBangla for proper Bengali TTS
      await ref.read(ttsServiceProvider.notifier).speakBangla(_currentQuestion.bangla);
    } catch (_) {}
  }

  Future<void> _speakCorrectAnswer() async {
    try {
      // Speak the correct English translation
      await ref.read(ttsServiceProvider.notifier).speak(_currentQuestion.correct);
    } catch (_) {}
  }

  void _selectAnswer(String answer) {
    if (_isAnswered) return;

    final isCorrect = answer == _currentQuestion.correct;
    setState(() {
      _isAnswered = true;
      _isAnswerCorrect = isCorrect;
    });

    if (isCorrect) {
      _correctCount++;
      _score += 10;
      HapticService.correct();
    } else {
      _wrongCount++;
      HapticService.heavy();
      _saveWrongAnswer(answer);
    }

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _nextCountdown = 10);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _nextCountdown--);
      if (_nextCountdown <= 0) {
        timer.cancel();
        _nextQuestion();
      }
    });
  }

  void _saveWrongAnswer(String userAnswer) {
    final q = _currentQuestion;
    try {
      WrongQuestionRepository().saveWrongQuestions([
        WrongQuestionModel.fromGameQuestion(
          questionId: '${_selectedTopic?.id ?? 'all'}_${q.id}',
          tenseType: q.errorType ?? 'translation',
          question: q.bangla,
          options: q.options,
          correctAnswer: q.correct,
          explanation: q.explanation,
          userAnswer: userAnswer,
          difficulty: q.difficulty,
          mode: 'bangla_to_english',
        ),
      ]);
    } catch (_) {}
  }

  void _nextQuestion() {
    _countdownTimer?.cancel();
    if (_currentIndex + 1 >= _activeQuestions.length) {
      _endGame();
      return;
    }
    setState(() {
      _currentIndex++;
      _isAnswered = false;
      _isAnswerCorrect = null;
      _nextCountdown = 0;
    });
    _prepareOptions();
  }

  Future<void> _endGame() async {
    _countdownTimer?.cancel();
    final earnedXP = _score * 2;
    final earnedCoins = _score;
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            score: _score,
            correctAnswers: _correctCount,
            wrongAnswers: _wrongCount,
            earnedXP: earnedXP,
            earnedCoins: earnedCoins,
            gameMode: 'banglaToEnglish',
          ),
        ),
      );
    }
  }

  void _goBackToTopics() {
    _countdownTimer?.cancel();
    setState(() {
      _showTopicSelection = true;
      _selectedTopic = null;
      _isAnswered = false;
      _isAnswerCorrect = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bangla → English')),
        body: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          itemBuilder: (_, __) => const SkeletonListTile(),
        ),
      );
    }

    if (_showTopicSelection) {
      return _buildTopicSelection();
    }

    return _buildGameScreen();
  }

  Widget _buildTopicSelection() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bangla → English'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.translate, size: 50, color: Colors.white70),
                    SizedBox(height: 12),
                    Text(
                      'Choose a Topic',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'একটি বিষয় নির্বাচন করুন',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              // All Topics card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: InkWell(
                  onTap: _selectAllTopics,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade300, width: 2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.all_inclusive, color: Colors.amber, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('All Topics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 2),
                              Text('${_allQuestions.length} questions • সব বিষয় মিশিয়ে',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Topic grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _topics.length,
                  itemBuilder: (context, index) {
                    final topic = _topics[index];
                    return _buildTopicCard(topic);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicCard(_TopicData topic) {
    final iconMap = {
      'handshake': Icons.handshake,
      'food': Icons.restaurant,
      'family': Icons.people,
      'shopping': Icons.shopping_bag,
      'travel': Icons.flight,
      'daily': Icons.alarm,
      'weather': Icons.wb_sunny,
      'health': Icons.favorite,
      'education': Icons.school,
      'time': Icons.access_time,
    };
    final icon = iconMap[topic.icon] ?? Icons.menu_book;
    final colorMap = {
      'greetings': const Color(0xFF1565C0),
      'food': const Color(0xFFE65100),
      'family': const Color(0xFF6A1B9A),
      'market': const Color(0xFF2E7D32),
      'travel': const Color(0xFF00838F),
      'daily': const Color(0xFFF57F17),
      'weather': const Color(0xFF4DB6AC),
      'health': const Color(0xFFD32F2F),
      'education': const Color(0xFF4527A0),
      'time': const Color(0xFF37474F),
    };
    final color = colorMap[topic.id] ?? Colors.teal;

    return InkWell(
      onTap: () => _selectTopic(topic),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                topic.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              topic.nameBn,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${topic.questions.length} Q',
              style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    final q = _currentQuestion;
    final total = _activeQuestions.length;
    final progress = (total > 0) ? (_currentIndex + 1) / total : 0.0;
    final topicName = _selectedTopic?.name ?? '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1)),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _goBackToTopics,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(topicName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.stars, color: Colors.amber, size: 12),
                                    const SizedBox(width: 4),
                                    Text('$_score', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text('Q ${_currentIndex + 1}/$total', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                              const Spacer(),
                              Text('✅ $_correctCount  ❌ $_wrongCount', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white30,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                              minHeight: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Game body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Bangla sentence card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.translate, color: Color(0xFF2E7D32), size: 16),
                                  SizedBox(width: 6),
                                  Text('বাংলা → English', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.format_quote, color: Colors.grey, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    q.bangla,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getDifficultyColor(q.difficulty).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _getDifficultyColor(q.difficulty)),
                                  ),
                                  child: Text(
                                    q.difficulty.toUpperCase(),
                                    style: TextStyle(color: _getDifficultyColor(q.difficulty), fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                // Speaker button to replay question audio
                                InkWell(
                                  onTap: _speakCurrentQuestion,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(Icons.volume_up, color: Color(0xFF2E7D32), size: 22),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Instruction
                      if (!_isAnswered)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app, color: Colors.white70, size: 16),
                              SizedBox(width: 8),
                              Text('সঠিক English translation বেছে নিন', style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),

                      const SizedBox(height: 14),

                      // Options
                      if (!_isAnswered)
                        ..._shuffledOptions.map((option) => _buildOptionButton(option)),

                      // Feedback
                      if (_isAnswered) ...[
                        _buildFeedback(q),
                        const SizedBox(height: 12),
                        _buildCountdownWithNext(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton(String option) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _selectAnswer(option),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Text(option, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
        ),
      ),
    );
  }

  Widget _buildFeedback(_QuestionData q) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Result header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _isAnswerCorrect == true ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _isAnswerCorrect == true ? Colors.green : Colors.red),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_isAnswerCorrect == true ? Icons.check_circle : Icons.cancel,
                        color: _isAnswerCorrect == true ? Colors.green : Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(_isAnswerCorrect == true ? '✅ Correct!' : '❌ Wrong!',
                      style: TextStyle(
                          color: _isAnswerCorrect == true ? Colors.green.shade700 : Colors.red.shade700,
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Correct answer
          if (_isAnswerCorrect == false) ...[
            const Text('Correct translation:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(q.correct, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            ),
            const SizedBox(height: 16),
          ],

          // Explanation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF2E7D32).withOpacity(0.05), const Color(0xFF4CAF50).withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Color(0xFF2E7D32), size: 18),
                    SizedBox(width: 8),
                    Text('📖 ব্যাখ্যা:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2E7D32))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(q.explanation, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownWithNext() {
    final isLast = _currentIndex + 1 >= _activeQuestions.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Countdown text
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'Auto next in $_nextCountdown sec',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Manual Next button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _nextQuestion,
              icon: Icon(isLast ? Icons.done_all : Icons.arrow_forward, size: 18),
              label: Text(
                isLast ? 'See Results' : 'Next Question',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy': return Colors.green;
      case 'medium': return Colors.orange;
      case 'hard': return Colors.red;
      default: return Colors.grey;
    }
  }
}