import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/haptic_service.dart';
import '../../../../repositories/wrong_question_repository.dart';
import '../../../../models/game/wrong_question_model.dart';
import '../result_screen.dart';
import '../../../../services/haptic_service.dart';

class GrammarDetectiveModeScreen extends ConsumerStatefulWidget {
  const GrammarDetectiveModeScreen({super.key});

  @override
  ConsumerState<GrammarDetectiveModeScreen> createState() => _GrammarDetectiveModeScreenState();
}

class _QuestionData {
  final String id;
  final String incorrect;
  final String highlighted;
  final String correct;
  final List<String> options;
  final String rule;
  final String errorType;
  final String difficulty;

  _QuestionData({
    required this.id,
    required this.incorrect,
    required this.highlighted,
    required this.correct,
    required this.options,
    required this.rule,
    required this.errorType,
    required this.difficulty,
  });
}

class _GrammarDetectiveModeScreenState extends ConsumerState<GrammarDetectiveModeScreen>
    with TickerProviderStateMixin {
  // All loaded questions (30 total)
  List<_QuestionData> _allQuestions = [];
  
  // Queue of upcoming new questions (never seen before in this session)
  List<_QuestionData> _newQuestionQueue = [];
  
  // Questions that were answered wrong – these will be re-shown
  final List<_QuestionData> _wrongQuestions = [];

  int _currentIndex = 0;
  int _score = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  int _streak = 0;
  int _bestStreak = 0;
  bool _isLoading = true;
  bool _isAnswered = false;
  String? _selectedAnswer;
  bool? _isAnswerCorrect;
  int _nextQuestionCountdown = 0;

  // Currently displayed question & its shuffled options
  _QuestionData? _currentQuestion;
  late List<String> _shuffledOptions;

  // Timer
  Timer? _questionTimer;
  int _timeLeft = 15;

  // Animations
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _scoreAnimCtrl;

  final Random _random = Random();
  final int _totalQuestions = 10;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _scoreAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadQuestions();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _shakeController.dispose();
    _scoreAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/json/game/grammar_detective_data.json');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      _allQuestions = (data['questions'] as List)
          .map((q) => _QuestionData(
                id: q['id'] as String,
                incorrect: q['incorrect'] as String,
                highlighted: q['highlighted'] as String,
                correct: q['correct'] as String,
                options: (q['options'] as List).map((o) => o as String).toList(),
                rule: q['rule'] as String,
                errorType: q['error_type'] as String,
                difficulty: q['difficulty'] as String,
              ))
          .toList();

      // Shuffle all questions and take the first 10 for new question queue
      _allQuestions.shuffle(_random);
      _newQuestionQueue = _allQuestions.take(_totalQuestions).toList();
      
      // Start with the first question
      _pickNextQuestion();

      setState(() => _isLoading = false);
      _startTimer();
    } catch (e) {
      debugPrint('Error loading questions: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Pick the next question.
  /// Priority goes to wrong questions first (if any), then new questions.
  void _pickNextQuestion() {
    if (_wrongQuestions.isNotEmpty) {
      // Show a previously wrong question again (randomly pick one)
      final idx = _random.nextInt(_wrongQuestions.length);
      _currentQuestion = _wrongQuestions.removeAt(idx);
    } else if (_newQuestionQueue.isNotEmpty) {
      // Take the next new question
      _currentQuestion = _newQuestionQueue.removeAt(0);
    } else {
      // No more questions – end the game
      _currentQuestion = null;
      _endGame();
      return;
    }

    // Shuffle the options for this question
    _shuffledOptions = _currentQuestion!.options.toList()..shuffle(_random);
  }

  void _startTimer() {
    _questionTimer?.cancel();
    _timeLeft = 15;

    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeLeft--;
      });
      if (_timeLeft <= 0) {
        timer.cancel();
        if (!_isAnswered) {
          _handleTimeUp();
        }
      }
    });
  }

  void _handleTimeUp() {
    setState(() {
      _isAnswered = true;
      _isAnswerCorrect = false;
      _selectedAnswer = null;
    });
    _wrongCount++;
    _streak = 0;
    HapticService.heavy();

    // Wrong answer – send to wrong queue for retry
    if (_currentQuestion != null) {
      _wrongQuestions.add(_currentQuestion!);
      _saveWrongAnswer(null);
    }

    _startCountdown();
  }

  void _selectAnswer(String answer) {
    if (_isAnswered) return;
    _questionTimer?.cancel();

    final isCorrect = answer == _currentQuestion!.correct;

    setState(() {
      _isAnswered = true;
      _selectedAnswer = answer;
      _isAnswerCorrect = isCorrect;
    });

    if (isCorrect) {
      _correctCount++;
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;

      // Score: base 20 + time bonus (up to +10) + streak bonus (up to +20)
      final timeBonus = min(_timeLeft, 10);
      final streakBonus = min(_streak * 4, 20).toInt();
      _score += 20 + timeBonus + streakBonus;

      HapticService.correct();
      _scoreAnimCtrl.forward().then((_) => _scoreAnimCtrl.reverse());
      
      // Correct – consume this question (do NOT requeue)
    } else {
      _wrongCount++;
      _streak = 0;
      HapticService.heavy();
      _shakeController.forward().then((_) => _shakeController.reverse());

      // Wrong answer – requeue for retry later
      _wrongQuestions.add(_currentQuestion!);
      _saveWrongAnswer(answer);
    }

    _startCountdown();
  }

  void _startCountdown() {
    final delaySeconds = _isAnswerCorrect == true ? 5 : 8;
    setState(() {
      _nextQuestionCountdown = delaySeconds;
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _nextQuestionCountdown--;
      });
      if (_nextQuestionCountdown <= 0) {
        timer.cancel();
        _nextQuestion();
      }
    });
  }

  void _saveWrongAnswer(String? userAnswer) {
    if (_currentQuestion == null) return;
    final q = _currentQuestion!;
    try {
      WrongQuestionRepository().saveWrongQuestions([
        WrongQuestionModel.fromGameQuestion(
          questionId: q.id,
          tenseType: q.errorType,
          question: q.incorrect,
          options: q.options,
          correctAnswer: q.correct,
          explanation: q.rule,
          userAnswer: userAnswer ?? '(timeout)',
          difficulty: q.difficulty,
          mode: 'grammar_detective',
        ),
      ]);
    } catch (_) {}
  }

  void _nextQuestion() {
    // Check if game should end:
    // End when all new questions are used AND wrong questions are cleared
    if (_newQuestionQueue.isEmpty && _wrongQuestions.isEmpty) {
      _endGame();
      return;
    }

    setState(() {
      _isAnswered = false;
      _selectedAnswer = null;
      _isAnswerCorrect = null;
      _nextQuestionCountdown = 0;
      _currentIndex++;
    });

    _pickNextQuestion();
    if (_currentQuestion != null) {
      _startTimer();
    }
  }

  Future<void> _endGame() async {
    _questionTimer?.cancel();
    final earnedXP = _score * 2;
    final earnedCoins = _score + min(_bestStreak * 5, 50).toInt();

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
            gameMode: 'grammarDetective',
          ),
        ),
      );
    }
  }

  /// Total questions that have been or will be shown (new + wrong + current displayed count)
  int get _displayedCount => _currentIndex + 1;
  /// Approximate total for progress bar: base 10 + wrong questions counts toward it
  int get _estimatedTotal => _totalQuestions + _wrongQuestions.length;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Grammar Detective'),
          backgroundColor: const Color(0xFF8B0000),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentQuestion == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Grammar Detective'),
          backgroundColor: const Color(0xFF8B0000),
        ),
        body: const Center(child: Text('No questions available')),
      );
    }

    final q = _currentQuestion!;
    final progress = _estimatedTotal > 0 ? _displayedCount / _estimatedTotal : 0.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8B0000), Color(0xFFCC0000), Color(0xFFFF4444)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Compact Header
              _buildHeader(progress),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Question Card
                      _buildQuestionCard(q),
                      
                      const SizedBox(height: 24),
                      
                      // Answer Options (using shuffled options)
                      if (!_isAnswered) ...[
                        _buildAnswerOptions(),
                      ] else ...[
                        // Feedback & Explanation
                        _buildFeedback(q),
                        
                        const SizedBox(height: 16),
                        
                        // Countdown
                        if (_nextQuestionCountdown > 0)
                          _buildCountdown(),
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

  Widget _buildHeader(double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          _buildTimerCircle(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Q${_displayedCount}/$_estimatedTotal',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    _buildCompactStatChip(Icons.stars, '$_score', Colors.amber),
                    const SizedBox(width: 6),
                    _buildCompactStatChip(Icons.local_fire_department, '$_streak', Colors.orange),
                    const SizedBox(width: 6),
                    _buildCompactStatChip(Icons.check_circle, '$_correctCount', Colors.greenAccent),
                    if (_wrongQuestions.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _buildCompactStatChip(Icons.refresh, '${_wrongQuestions.length}', Colors.orangeAccent),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white30,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCircle() {
    final color = _timeLeft > 5 ? Colors.green : Colors.red;
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$_timeLeft',
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStatChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 3),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(_QuestionData q) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with detective badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B0000), Color(0xFFCC0000)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B0000).withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      '🔍 FIND THE ERROR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getDifficultyColor(q.difficulty).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getDifficultyColor(q.difficulty)),
                ),
                child: Text(
                  q.difficulty.toUpperCase(),
                  style: TextStyle(
                    color: _getDifficultyColor(q.difficulty),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Instruction
          const Text(
            'Which word/phrase is incorrect? Tap the correct replacement:',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Incorrect Sentence with highlighted error
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: _buildIncorrectSentence(q),
              );
            },
          ),
          
          // Error type tag
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Error Type: ${_getErrorTypeLabel(q.errorType)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncorrectSentence(_QuestionData q) {
    final highlighted = q.highlighted;
    final sentence = q.incorrect;
    
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 18, height: 1.5, color: Colors.black87, fontWeight: FontWeight.w500),
        children: _buildHighlightedSpans(sentence, highlighted),
      ),
    );
  }

  List<TextSpan> _buildHighlightedSpans(String sentence, String highlighted) {
    final spans = <TextSpan>[];
    int start = 0;
    
    while (true) {
      final index = sentence.indexOf(highlighted, start);
      if (index == -1) {
        spans.add(TextSpan(text: sentence.substring(start)));
        break;
      }
      
      if (index > start) {
        spans.add(TextSpan(text: sentence.substring(start, index)));
      }
      
      spans.add(TextSpan(
        text: highlighted,
        style: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
          decorationColor: Colors.red,
          decorationStyle: TextDecorationStyle.wavy,
        ),
      ));
      
      start = index + highlighted.length;
    }
    
    return spans;
  }

  /// Build answer options using the shuffled order
  Widget _buildAnswerOptions() {
    return Column(
      children: _shuffledOptions.map((option) {
        final isSelected = _selectedAnswer == option;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _selectAnswer(option),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isSelected ? 0.1 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        String.fromCharCode(65 + _shuffledOptions.indexOf(option)),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.blue : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeedback(_QuestionData q) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                  color: _isAnswerCorrect == true
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isAnswerCorrect == true ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isAnswerCorrect == true ? Icons.check_circle : Icons.cancel,
                      color: _isAnswerCorrect == true ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isAnswerCorrect == true ? '✅ Correct!' : '❌ Wrong!',
                      style: TextStyle(
                        color: _isAnswerCorrect == true ? Colors.green.shade700 : Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isAnswerCorrect == true && _wrongQuestions.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 14, color: Colors.orange),
                      SizedBox(width: 4),
                      Text(
                        'Retrying wrong answers',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 16),
          
          // If wrong, show correct answer
          if (_isAnswerCorrect == false) ...[
            const Text(
              'Correct Answer:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              q.correct,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Grammar Rule Explanation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8B0000).withOpacity(0.05),
                  const Color(0xFFFF4444).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF8B0000).withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Color(0xFF8B0000), size: 18),
                    SizedBox(width: 8),
                    Text(
                      '📖 Grammar Rule:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF8B0000),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  q.rule,
                  style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _isAnswerCorrect == true ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isAnswerCorrect == true ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timer_outlined,
            color: _isAnswerCorrect == true ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Next question in ${_nextQuestionCountdown} second${_nextQuestionCountdown > 1 ? "s" : ""}',
              style: TextStyle(
                color: _isAnswerCorrect == true ? Colors.green.shade700 : Colors.orange.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getErrorTypeLabel(String errorType) {
    switch (errorType) {
      case 'subject_verb_agreement':
        return 'Subject-Verb Agreement';
      case 'verb_form':
        return 'Verb Form';
      case 'article':
        return 'Article';
      case 'modal_verb':
        return 'Modal Verb';
      case 'demonstrative':
        return 'Demonstrative';
      case 'state_verb':
        return 'State Verb';
      case 'quantifier':
        return 'Quantifier';
      case 'confusing_words':
        return 'Confusing Words';
      case 'gerund_infinitive':
        return 'Gerund vs Infinitive';
      case 'tense':
        return 'Tense';
      case 'comparative':
        return 'Comparative';
      case 'reported_speech':
        return 'Reported Speech';
      case 'preposition':
        return 'Preposition';
      case 'conditional':
        return 'Conditional';
      case 'pronoun_agreement':
        return 'Pronoun Agreement';
      case 'relative_pronoun':
        return 'Relative Pronoun';
      case 'subjunctive':
        return 'Subjunctive Mood';
      case 'verb_usage':
        return 'Verb Usage';
      default:
        return errorType.replaceAll('_', ' ');
    }
  }
}