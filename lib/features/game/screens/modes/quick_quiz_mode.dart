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

class _WordEntry {
  final String bn;
  final String en;
  _WordEntry({required this.bn, required this.en});
}

class _Question {
  final String banglaWord;
  final String correctEnglish;
  final List<String> options;
  _Question({
    required this.banglaWord,
    required this.correctEnglish,
    required this.options,
  });
}

class QuickQuizModeScreen extends ConsumerStatefulWidget {
  const QuickQuizModeScreen({super.key});

  @override
  ConsumerState<QuickQuizModeScreen> createState() => _QuickQuizModeScreenState();
}

class _QuickQuizModeScreenState extends ConsumerState<QuickQuizModeScreen>
    with TickerProviderStateMixin {
  final TtsService _tts = TtsService();

  List<_Question> _questions = [];
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
  int _timeLeft = 5;
  late AnimationController _timerAnimCtrl;

  // Animations
  late AnimationController _scoreAnimCtrl;
  late Animation<double> _scoreAnim;
  late AnimationController _slideAnimCtrl;
  late Animation<Offset> _slideAnim;

  final Random _random = Random();
  final int _totalQuestions = 10;

  @override
  void initState() {
    super.initState();
    _timerAnimCtrl = AnimationController(
      duration: const Duration(seconds: 5),
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
    _loadWords();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _timerAnimCtrl.dispose();
    _scoreAnimCtrl.dispose();
    _slideAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    final jsonStr =
        await rootBundle.loadString('assets/json/game/verb_quiz_data.json');
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final allWords = (data['pairs'] as List)
        .map((p) => _WordEntry(bn: p['bn'] as String, en: p['en'] as String))
        .toList();

    allWords.shuffle(_random);
    final selected = allWords.take(_totalQuestions).toList();

    final questions = <_Question>[];
    for (final word in selected) {
      // Get 3 random wrong options
      final wrongOptions = allWords
          .where((w) => w.en != word.en)
          .toList()
        ..shuffle(_random);
      final options = [
        word.en,
        ...wrongOptions.take(3).map((w) => w.en),
      ]..shuffle(_random);

      questions.add(_Question(
        banglaWord: word.bn,
        correctEnglish: word.en,
        options: options,
      ));
    }

    setState(() {
      _questions = questions;
      _isLoading = false;
    });
    _startTimer();
    // Play Bangla voice when question appears
    _tts.speakBangla(questions[0].banglaWord);
  }

  void _startTimer() {
    _questionTimer?.cancel();
    // Play Bangla voice for the current question
    if (_currentIndex < _questions.length) {
      _tts.speakBangla(_questions[_currentIndex].banglaWord);
    }
    _timeLeft = 5;
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
        // Time's up — mark as wrong
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
    _saveWrongAnswer(null); // no answer selected

    setState(() {});

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _nextQuestion();
    });
  }

  void _selectAnswer(String answer) {
    if (_isAnswered) return;
    _questionTimer?.cancel();
    _timerAnimCtrl.stop();

    _isAnswered = true;
    _selectedAnswer = answer;
    _isAnswerCorrect = answer == _questions[_currentIndex].correctEnglish;

    if (_isAnswerCorrect!) {
      _correctCount++;
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;

      // Score: base 10 + streak bonus (up to +8)
      final streakBonus = min((_streak - 1) * 2, 8);
      _score += 10 + streakBonus;

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

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _nextQuestion();
    });
  }

  void _saveWrongAnswer(String? userAnswer) {
    final q = _questions[_currentIndex];
    try {
      WrongQuestionRepository().saveWrongQuestions([
        WrongQuestionModel.fromGameQuestion(
          questionId: 'quick_quiz_${DateTime.now().millisecondsSinceEpoch}',
          tenseType: 'verb_v1',
          question: 'Meaning of: ${q.banglaWord}',
          options: q.options,
          correctAnswer: q.correctEnglish,
          explanation: '${q.banglaWord} → ${q.correctEnglish}',
          userAnswer: userAnswer ?? '(timeout)',
          difficulty: 'easy',
          mode: 'quick_quiz',
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
    _startTimer();
  }

  Future<void> _endGame() async {
    _questionTimer?.cancel();

    final total = _correctCount + _wrongCount;
    final accuracy = total > 0 ? _correctCount / total : 0.0;
    final int xpEarned = _score * 2 + (_bestStreak >= 5 ? 30 : _bestStreak >= 3 ? 15 : 0);
    final int coinsEarned = _score + (_bestStreak >= 5 ? 20 : _bestStreak >= 3 ? 10 : 0);

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
            gameMode: 'quick_quiz',
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
        gameType: 'quick_quiz',
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
              CircularProgressIndicator(color: Colors.deepOrange),
              SizedBox(height: 12),
              Text('Loading quiz...', style: TextStyle(color: Colors.grey)),
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
          // ── Header ──
          _buildHeader(progress),

          // ── Timer + Question ──
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.shade50,
                    Colors.deepOrange.shade50.withOpacity(0.3),
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
                          _timeLeft <= 2 ? Colors.red : Colors.deepOrange,
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
                      color: _timeLeft <= 2 ? Colors.red : Colors.deepOrange,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Question card with slide animation
                  Expanded(
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepOrange.withOpacity(0.15),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Choose the correct English word',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                question.banglaWord,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'বাংলা শব্দ',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
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
                          child: _buildOptionButton(option, question.correctEnglish),
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
          colors: [Color(0xFFFF6B35), Color(0xFFF7C948)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.3),
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
              Expanded(
                child: Text(
                  'Quick Quiz',
                  style: const TextStyle(
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
              // Streak fire
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
                        : Colors.orange.withOpacity(0.3)),
                width: borderColor != null ? 2.5 : 1.5,
              ),
              boxShadow: [
                if (!_isAnswered)
                  BoxShadow(
                    color: Colors.deepOrange.withOpacity(0.08),
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
}