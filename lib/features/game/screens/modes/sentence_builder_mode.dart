import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/haptic_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/skeleton_widget.dart';
import '../../../../repositories/wrong_question_repository.dart';
import '../../../../models/game/wrong_question_model.dart';
import '../result_screen.dart';
import '../../../../services/haptic_service.dart';

class SentenceBuilderModeScreen extends ConsumerStatefulWidget {
  const SentenceBuilderModeScreen({super.key});

  @override
  ConsumerState<SentenceBuilderModeScreen> createState() => _SentenceBuilderModeScreenState();
}

class _SentenceBuilderModeScreenState extends ConsumerState<SentenceBuilderModeScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _allQuestions = [];
  List<Map<String, dynamic>> _selectedQuestions = [];
  
  int _currentQuestionIndex = 0;
  List<String> _selectedWords = [];
  List<String> _availableWords = [];
  
  int _score = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  int _streak = 0;
  
  Timer? _timer;
  int _timeLeft = 15; // 15 seconds per question
  
  bool _isLoading = true;
  bool _showHint = false;
  bool _isAnswerSubmitted = false;
  bool _isCorrect = false;
  int _nextQuestionCountdown = 0;
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

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
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final String response = await rootBundle.loadString('assets/json/game/sentence_builder_data.json');
      final data = json.decode(response);
      _allQuestions = List<Map<String, dynamic>>.from(data['questions']);
      
      // Select 10 random questions
      _allQuestions.shuffle(Random());
      _selectedQuestions = _allQuestions.take(10).toList();
      
      setState(() {
        _isLoading = false;
      });
      _setupQuestion();
      _startTimer();
    } catch (e) {
      debugPrint('Error loading questions: $e');
      setState(() => _isLoading = false);
    }
  }

  void _setupQuestion() {
    if (_currentQuestionIndex >= _selectedQuestions.length) return;
    
    final question = _selectedQuestions[_currentQuestionIndex];
    final scrambled = List<String>.from(question['scrambled']);
    scrambled.shuffle(Random());
    
    setState(() {
      _availableWords = scrambled;
      _selectedWords = [];
      _showHint = false;
      _isAnswerSubmitted = false;
      _isCorrect = false;
      _timeLeft = 15;
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _submitAnswer(timeout: true);
      }
    });
  }

  void _onWordTapped(String word) {
    if (_isAnswerSubmitted) return;
    
    setState(() {
      _availableWords.remove(word);
      _selectedWords.add(word);
    });
  }

  void _onSelectedWordTapped(String word) {
    if (_isAnswerSubmitted) return;
    
    setState(() {
      _selectedWords.remove(word);
      _availableWords.add(word);
    });
  }

  void _submitAnswer({bool timeout = false}) {
    _timer?.cancel();
    
    final question = _selectedQuestions[_currentQuestionIndex];
    final correctAnswer = question['correct'] as String;
    final userAnswer = _selectedWords.join(' ');
    
    final isCorrect = userAnswer.trim().toLowerCase() == correctAnswer.trim().toLowerCase();
    
    setState(() {
      _isAnswerSubmitted = true;
      _isCorrect = isCorrect;
    });
    
    if (isCorrect) {
      _correctCount++;
      _streak++;
      
      // Calculate score
      int baseScore = 20;
      int timeBonus = (_timeLeft * 2).clamp(0, 10);
      int streakBonus = min(_streak * 5, 25);
      
      setState(() {
        _score += baseScore + timeBonus + streakBonus;
      });
      
      HapticService.correct();
    } else {
      _wrongCount++;
      _streak = 0;
      _shakeController.forward().then((_) => _shakeController.reverse());
      HapticService.heavy();
      
      // Save wrong answer
      _saveWrongAnswer(question, userAnswer, correctAnswer);
    }
    
    // Move to next question after delay with countdown
    // Wrong answer: 5 seconds to read explanation
    // Correct answer: 2.5 seconds
    final delaySeconds = isCorrect ? 3 : 5;
    setState(() {
      _nextQuestionCountdown = delaySeconds;
    });
    
    // Start countdown timer
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
        if (_currentQuestionIndex < _selectedQuestions.length - 1) {
          setState(() {
            _currentQuestionIndex++;
          });
          _setupQuestion();
          _startTimer();
        } else {
          _showResults();
        }
      }
    });
  }

  Future<void> _saveWrongAnswer(Map<String, dynamic> question, String userAnswer, String correctAnswer) async {
    final wrongQuestion = WrongQuestionModel.fromGameQuestion(
      questionId: question['id'],
      tenseType: question['tense'] ?? 'sentence_builder',
      question: 'Arrange: ${(question['scrambled'] as List).join(', ')}',
      options: [correctAnswer, userAnswer, '', ''],
      correctAnswer: correctAnswer,
      explanation: question['explanation'] ?? '',
      userAnswer: userAnswer,
      difficulty: question['difficulty'] ?? 'medium',
      mode: 'sentence_builder',
    );
    
    await WrongQuestionRepository().saveWrongQuestions([wrongQuestion]);
  }

  Future<void> _showResults() async {
    _timer?.cancel();
    
    final earnedXP = _score * 2;
    final earnedCoins = _score + min(_streak * 5, 50).toInt();
    
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
            gameMode: 'sentenceBuilder',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sentence Builder')),
        body: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          itemBuilder: (_, __) => const SkeletonListTile(),
        ),
      );
    }

    if (_selectedQuestions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sentence Builder')),
        body: const Center(child: Text('No questions available')),
      );
    }

    final question = _selectedQuestions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _selectedQuestions.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(progress),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Question Card
                      _buildQuestionCard(question),
                      
                      const SizedBox(height: 24),
                      
                      // Selected Words Area
                      _buildSelectedWordsArea(),
                      
                      const SizedBox(height: 24),
                      
                      // Available Words
                      _buildAvailableWords(),
                      
                      const SizedBox(height: 24),
                      
                      // Hint Button
                      if (!_isAnswerSubmitted && !_showHint)
                        _buildHintButton(),
                      
                      // Hint Display
                      if (_showHint && !_isAnswerSubmitted)
                        _buildHintDisplay(question),
                      
                      const SizedBox(height: 16),
                      
                      // Submit Button
                      if (!_isAnswerSubmitted && _selectedWords.isNotEmpty)
                        _buildSubmitButton(),
                      
                      // Feedback
                      if (_isAnswerSubmitted)
                        _buildFeedback(question),
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
                      'Q${_currentQuestionIndex + 1}/${_selectedQuestions.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    _buildCompactStatChip(Icons.stars, '$_score', Colors.amber),
                    const SizedBox(width: 6),
                    _buildCompactStatChip(Icons.local_fire_department, '$_streak', Colors.orange),
                    const SizedBox(width: 6),
                    _buildCompactStatChip(Icons.check_circle, '$_correctCount', Colors.green),
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

  Widget _buildQuestionCard(Map<String, dynamic> question) {
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
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Text(
                  question['tense'].toString().replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getDifficultyColor(question['difficulty']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  question['difficulty'].toString().toUpperCase(),
                  style: TextStyle(
                    color: _getDifficultyColor(question['difficulty']),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '🔨 Arrange the words to form a correct sentence:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedWordsArea() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isAnswerSubmitted
              ? (_isCorrect ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2))
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isAnswerSubmitted
                ? (_isCorrect ? Colors.green : Colors.red)
                : Colors.blue.shade200,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isAnswerSubmitted
                      ? (_isCorrect ? Icons.check_circle : Icons.cancel)
                      : Icons.edit,
                  color: _isAnswerSubmitted
                      ? (_isCorrect ? Colors.green : Colors.red)
                      : Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isAnswerSubmitted
                      ? (_isCorrect ? '✅ Correct!' : '❌ Wrong!')
                      : 'Your Sentence:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _isAnswerSubmitted
                        ? (_isCorrect ? Colors.green : Colors.red)
                        : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _selectedWords.isEmpty
                ? const Center(
                    child: Text(
                      'Tap words below to build your sentence',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedWords.map((word) {
                      return GestureDetector(
                        onTap: () => _onSelectedWordTapped(word),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade300),
                          ),
                          child: Text(
                            word,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableWords() {
    if (_availableWords.isEmpty) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Words:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableWords.map((word) {
              return GestureDetector(
                onTap: () => _onWordTapped(word),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    word,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHintButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() => _showHint = true),
      icon: const Icon(Icons.lightbulb_outline, color: Colors.amber),
      label: const Text('Show Hint', style: TextStyle(color: Colors.white)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.amber),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  Widget _buildHintDisplay(Map<String, dynamic> question) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, color: Colors.amber, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              question['hint'] ?? '',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _submitAnswer(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        child: const Text(
          '✓ Submit Answer',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFeedback(Map<String, dynamic> question) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
              if (!_isCorrect) ...[
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Correct Answer:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  question['correct'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Explanation:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                question['explanation'] ?? '',
                style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
              ),
            ],
          ),
        ),
        
        // Countdown indicator
        if (_nextQuestionCountdown > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _isCorrect ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isCorrect ? Colors.green.shade200 : Colors.orange.shade200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: _isCorrect ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Next question in $_nextQuestionCountdown second${_nextQuestionCountdown > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: _isCorrect ? Colors.green.shade700 : Colors.orange.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
}