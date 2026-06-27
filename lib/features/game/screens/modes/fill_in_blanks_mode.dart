import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/game/xp_provider.dart';
import '../../../../providers/game/coin_provider.dart';
import '../../../../providers/game/streak_provider.dart';
import '../../../../providers/game/achievement_provider.dart';
import '../../../../providers/game/sound_provider.dart';
import '../../../../services/tts_service.dart';
import '../../../../repositories/statistics_repository.dart';
import '../../../../repositories/wrong_question_repository.dart';
import '../../../../models/game/game_result_model.dart';
import '../../../../models/game/wrong_question_model.dart';
import '../result_screen.dart';

class _QuestionData {
  final String id;
  final String sentence;
  final String blank;
  final List<String> options;
  final String type;
  final String tense;
  final String explanation;
  final String difficulty;

  _QuestionData({
    required this.id,
    required this.sentence,
    required this.blank,
    required this.options,
    required this.type,
    required this.tense,
    required this.explanation,
    required this.difficulty,
  });
}

class FillInBlanksModeScreen extends ConsumerStatefulWidget {
  const FillInBlanksModeScreen({super.key});

  @override
  ConsumerState<FillInBlanksModeScreen> createState() => _FillInBlanksModeScreenState();
}

class _FillInBlanksModeScreenState extends ConsumerState<FillInBlanksModeScreen>
    with TickerProviderStateMixin {
  final TtsService _tts = TtsService();

  List<_QuestionData> _questions = [];
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

  // Timer
  Timer? _questionTimer;
  int _timeLeft = 10;
  late AnimationController _timerAnimCtrl;

  // Animations
  late AnimationController _scoreAnimCtrl;
  late Animation<double> _scoreAnim;
  late AnimationController _slideAnimCtrl;
  late Animation<Offset> _slideAnim;
  late AnimationController _blankPulseCtrl;
  late Animation<double> _blankPulse;

  final Random _random = Random();
  final int _totalQuestions = 10;

  @override
  void initState() {
    super.initState();
    _timerAnimCtrl = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    _scoreAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scoreAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _scoreAnimCtrl, curve: Curves.easeInOut),
    );
    _slideAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideAnimCtrl, curve: Curves.easeOutCubic));
    _blankPulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _blankPulse = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _blankPulseCtrl, curve: Curves.easeInOut),
    );
    _loadQuestions();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _timerAnimCtrl.dispose();
    _scoreAnimCtrl.dispose();
    _slideAnimCtrl.dispose();
    _blankPulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final jsonStr =
        await rootBundle.loadString('assets/json/game/fill_blanks_data.json');
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final allQuestions = (data['questions'] as List)
        .map((q) => _QuestionData(
              id: q['id'] as String,
              sentence: q['sentence'] as String,
              blank: q['blank'] as String,
              options: (q['options'] as List).map((o) => o as String).toList(),
              type: q['type'] as String,
              tense: q['tense'] as String,
              explanation: q['explanation'] as String,
              difficulty: q['difficulty'] as String,
            ))
        .toList();

    allQuestions.shuffle(_random);
    final selected = allQuestions.take(_totalQuestions).toList();

    setState(() {
      _questions = selected;
      _isLoading = false;
    });
    _startTimer();
  }

  void _startTimer() {
    _questionTimer?.cancel();
    _timeLeft = 10;
    _timerAnimCtrl.reset();
    _timerAnimCtrl.forward();
    _slideAnimCtrl.forward(from: 0.0);

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
    _isAnswered = true;
    _isAnswerCorrect = false;
    _selectedAnswer = null;
    _wrongCount++;
    _streak = 0;

    ref.read(soundServiceProvider).playWrong();
    _saveWrongAnswer(null);

    setState(() {});

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      _nextQuestion();
    });
  }

  void _selectAnswer(String answer) {
    if (_isAnswered) return;
    _questionTimer?.cancel();
    _timerAnimCtrl.stop();
    _blankPulseCtrl.stop();

    _isAnswered = true;
    _selectedAnswer = answer;
    _isAnswerCorrect = answer == _questions[_currentIndex].blank;

    if (_isAnswerCorrect!) {
      _correctCount++;
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;

      // Score: base 15 + time bonus (up to +5) + streak bonus (up to +10)
      final timeBonus = min(_timeLeft, 5);
      final streakBonus = min((_streak - 1) * 2, 10);
      _score += 15 + timeBonus + streakBonus;

      ref.read(soundServiceProvider).playCorrect();
      _scoreAnimCtrl.forward().then((_) => _scoreAnimCtrl.reverse());
      _tts.speak(answer);
    } else {
      _wrongCount++;
      _streak = 0;
      ref.read(soundServiceProvider).playWrong();
      _saveWrongAnswer(answer);
    }

    setState(() {});

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      _nextQuestion();
    });
  }

  void _saveWrongAnswer(String? userAnswer) {
    final q = _questions[_currentIndex];
    try {
      WrongQuestionRepository().saveWrongQuestions([
        WrongQuestionModel.fromGameQuestion(
          questionId: q.id,
          tenseType: q.tense,
          question: q.sentence.replaceAll('___', '_____'),
          options: q.options,
          correctAnswer: q.blank,
          explanation: q.explanation,
          userAnswer: userAnswer ?? '(timeout)',
          difficulty: q.difficulty,
          mode: 'fill_in_blanks',
        ),
      ]);
    } catch (_) {}
  }

  void _nextQuestion() {
    if (_currentIndex + 1 >= _totalQuestions) {
      _endGame();
      return;
    }

    setState(() {
      _currentIndex++;
      _isAnswered = false;
      _selectedAnswer = null;
      _isAnswerCorrect = null;
    });
    _blankPulseCtrl.repeat(reverse: true);
    _startTimer();
  }

  Future<void> _endGame() async {
    _questionTimer?.cancel();
    _blankPulseCtrl.stop();

    final total = _correctCount + _wrongCount;
    final accuracy = total > 0 ? _correctCount / total : 0.0;
    final int xpEarned = _score * 2 + (_bestStreak >= 5 ? 40 : _bestStreak >= 3 ? 20 : 0);
    final int coinsEarned = _score + (_bestStreak >= 5 ? 25 : _bestStreak >= 3 ? 15 : 0);

    _saveProgress(xpEarned, coinsEarned, accuracy);

    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            score: _score,
            correctAnswers: _correctCount,
            wrongAnswers: _wrongCount,
            earnedXP: xpEarned,
            earnedCoins: coinsEarned,
            gameMode: 'fill_in_blanks',
          ),
        ),
      );
    }
  }

  Future<void> _saveProgress(int xp, int coins, double accuracy) async {
    try {
      await ref.read(xpProvider.notifier).addXP(xp);
    } catch (_) {}
    try {
      await ref.read(coinProvider.notifier).addCoins(coins);
    } catch (_) {}
    try {
      await ref.read(streakProvider.notifier).checkAndUpdateStreak();
    } catch (_) {}
    try {
      await ref.read(streakProvider.notifier).recordActiveDay();
    } catch (_) {}
    try {
      await ref.read(achievementProvider.notifier).checkGameAchievements(
        score: _score,
        correctAnswers: _correctCount,
        accuracy: accuracy,
      );
    } catch (_) {}
    try {
      final repo = StatisticsRepository();
      await repo.saveResult(GameResultModel(
        earnedXP: xp,
        earnedCoins: coins,
        correctAnswers: _correctCount,
        wrongAnswers: _wrongCount,
        accuracy: accuracy,
        score: _score,
        gameType: 'fill_in_blanks',
        completedTime: DateTime.now(),
      ));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.purple),
              SizedBox(height: 12),
              Text('Loading questions...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final question = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _totalQuestions;

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(progress),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.shade50,
                    Colors.deepPurple.shade50.withOpacity(0.3),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // Timer ring
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: AnimatedBuilder(
                      animation: _timerAnimCtrl,
                      builder: (_, child) => CircularProgressIndicator(
                        value: _timerAnimCtrl.value,
                        strokeWidth: 5,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _timeLeft <= 3 ? Colors.red : Colors.purple,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_timeLeft',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _timeLeft <= 3 ? Colors.red : Colors.purple,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Question card with blank
                  Expanded(
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.15),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Fill in the blank',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildSentenceWithBlank(question.sentence),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  question.type.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.purple.shade700,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Options
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Column(
                      children: List.generate(question.options.length, (i) {
                        final option = question.options[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildOptionButton(option, question.blank),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentenceWithBlank(String sentence) {
    final parts = sentence.split('___');
    
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 20,
          color: Colors.black87,
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
        children: [
          TextSpan(text: parts[0]),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: AnimatedBuilder(
              animation: _blankPulse,
              builder: (context, child) => Transform.scale(
                scale: _isAnswered ? 1.0 : _blankPulse.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: _isAnswered
                        ? (_isAnswerCorrect! ? Colors.green.shade50 : Colors.red.shade50)
                        : Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isAnswered
                          ? (_isAnswerCorrect! ? Colors.green : Colors.red)
                          : Colors.purple.shade300,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    _isAnswered && _selectedAnswer != null
                        ? _selectedAnswer!
                        : '______',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isAnswered
                          ? (_isAnswerCorrect! ? Colors.green.shade700 : Colors.red.shade700)
                          : Colors.purple.shade700,
                      letterSpacing: _isAnswered && _selectedAnswer != null ? 0 : 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (parts.length > 1) TextSpan(text: parts[1]),
        ],
      ),
    );
  }

  Widget _buildOptionButton(String option, String correctAnswer) {
    final bool isCorrectOption = option == correctAnswer;
    final bool isSelectedOption = option == _selectedAnswer;

    Color? bgColor;
    Color? borderColor;
    IconData? trailingIcon;

    if (_isAnswered) {
      if (isCorrectOption) {
        bgColor = Colors.green.shade50;
        borderColor = Colors.green;
        trailingIcon = Icons.check_circle_rounded;
      } else if (isSelectedOption && !isCorrectOption) {
        bgColor = Colors.red.shade50;
        borderColor = Colors.red;
        trailingIcon = Icons.cancel_rounded;
      }
    }

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isAnswered ? null : () => _selectAnswer(option),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: bgColor ?? Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor ??
                    (_isAnswered && !isSelectedOption && !isCorrectOption
                        ? Colors.grey.shade200
                        : Colors.purple.withOpacity(0.3)),
                width: borderColor != null ? 2.5 : 1.5,
              ),
              boxShadow: [
                if (!_isAnswered)
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          _isAnswered && isCorrectOption
                              ? FontWeight.bold
                              : FontWeight.w500,
                      color: _isAnswered && isCorrectOption
                          ? Colors.green.shade700
                          : _isAnswered && isSelectedOption && !isCorrectOption
                              ? Colors.red.shade700
                              : Colors.black87,
                    ),
                  ),
                ),
                if (trailingIcon != null)
                  Icon(trailingIcon,
                      color: isCorrectOption ? Colors.green : Colors.red,
                      size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double progress) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Fill in the Blanks',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Score
              AnimatedBuilder(
                animation: _scoreAnim,
                builder: (_, child) => Transform.scale(
                  scale: _scoreAnim.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amberAccent, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '$_score',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Streak
              if (_streak > 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: Colors.deepOrange, size: 16),
                      const SizedBox(width: 3),
                      Text(
                        '$_streak',
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_currentIndex + 1} / $_totalQuestions',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}