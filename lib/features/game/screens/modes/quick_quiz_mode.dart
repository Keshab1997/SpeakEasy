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
import '../../../../services/tts_service.dart';
import '../../../../repositories/statistics_repository.dart';
import '../../../../models/game/game_result_model.dart';
import '../../../../providers/game/game_provider.dart';
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
  String _selectedAnswer = '';
  bool _isAnswered = false;
  bool _isGameOver = false;
  int _timeLeft = 10;
  Timer? _questionTimer;
  Timer? _autoAdvanceTimer;
  int _totalQuestions = 10;
  final Set<int> _usedIndices = {};
  Map<int, String> _userAnswers = {};

  // Animations
  late AnimationController _timerAnimCtrl;
  late Animation<double> _timerAnim;
  late AnimationController _scoreAnimCtrl;
  late Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _timerAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _timerAnim = Tween(begin: 0.0, end: 1.0).animate(_timerAnimCtrl);
    _scoreAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scoreAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _scoreAnimCtrl, curve: Curves.easeInOut),
    );
    _loadQuestions();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    _timerAnimCtrl.dispose();
    _scoreAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/json/vocabulary/english_to_bangla.json');
      final List<dynamic> data = json.decode(jsonString) as List<dynamic>;
      final allEntries = data
          .map((e) => _WordEntry(
                bn: e['bn'] as String? ?? '',
                en: e['en'] as String? ?? '',
              ))
          .where((e) => e.bn.isNotEmpty && e.en.isNotEmpty)
          .toList();

      if (allEntries.length < _totalQuestions) {
        _totalQuestions = allEntries.length;
      }

      allEntries.shuffle(Random());
      final selectedEntries = allEntries.take(_totalQuestions).toList();

      _questions = selectedEntries.map((entry) {
        // Generate distractors
        final distractors = (allEntries
                .where((e) => e.en != entry.en)
                .toList()
              ..shuffle(Random()))
            .take(3)
            .map((e) => e.en)
            .toList();

        final options = [entry.en, ...distractors]..shuffle(Random());
        return _Question(
          banglaWord: entry.bn,
          correctEnglish: entry.en,
          options: options,
        );
      }).toList();

      if (mounted) setState(() {});
      _startTimer();
    } catch (e) {
      debugPrint('Error loading questions: $e');
    }
  }

  void _startTimer() {
    _questionTimer?.cancel();
    _timeLeft = 10;
    _timerAnimCtrl.reset();
    _timerAnimCtrl.forward();
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
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    if (_isAnswered || _isGameOver) return;
    setState(() {
      _isAnswered = true;
      _wrongCount++;
      _userAnswers[_currentIndex] = '';
    });
    _autoAdvance();
  }

  void _selectAnswer(String answer) {
    if (_isAnswered || _isGameOver) return;
    _questionTimer?.cancel();

    setState(() {
      _isAnswered = true;
      _selectedAnswer = answer;
      _userAnswers[_currentIndex] = answer;

      if (answer == _questions[_currentIndex].correctEnglish) {
        _correctCount++;
        _score += _calculateScore();
        _streak++;
        if (_streak > _bestStreak) _bestStreak = _streak;
      } else {
        _wrongCount++;
        _streak = 0;
      }
    });

    _autoAdvance();
  }

  int _calculateScore() {
    return 100 + (_streak > 1 ? (_streak - 1) * 10 : 0) + (_timeLeft * 5);
  }

  void _autoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      if (_currentIndex + 1 < _totalQuestions) {
        setState(() {
          _currentIndex++;
          _isAnswered = false;
          _selectedAnswer = '';
        });
        _startTimer();
      } else {
        _endGame();
      }
    });
  }

  void _endGame() {
    _questionTimer?.cancel();
    _autoAdvanceTimer?.cancel();

    final accuracy = _totalQuestions > 0 ? _correctCount / _totalQuestions : 0.0;

    // Calculate XP and coins
    final xpEarned = (_correctCount * 20) + (_streak * 5);
    final coinsEarned = (_correctCount * 5) + (_streak * 2);

    _saveProgress(xpEarned, coinsEarned, accuracy);

    if (!mounted) return;
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
        score: _score,
      ));
    } catch (_) {}

    // 🔥 Upload updated streak/progress to Firestore
    try {
      final progressRepo = ref.read(progressRepositoryProvider);
      final gameProgress = progressRepo.getProgress();
      if (gameProgress != null) {
        await progressRepo.uploadProgressToFirestore(gameProgress);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.orange.shade50,
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
                      position: Tween<Offset>(
                        begin: const Offset(0.5, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _timerAnimCtrl,
                        curve: Curves.easeOutCubic,
                      )),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepOrange.withOpacity(0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Translate this word',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                question.banglaWord,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            IconButton(
                              icon: Icon(Icons.volume_up,
                                  color: Colors.deepOrange.shade300, size: 28),
                              onPressed: () => _tts.speak(question.banglaWord),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Option buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: question.options.map((option) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildOptionButton(option, question.correctEnglish),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 24),
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
        left: 8,
        right: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepOrange, Colors.orange.shade400],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
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