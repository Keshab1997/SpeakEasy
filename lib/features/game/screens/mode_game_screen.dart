import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../services/haptic_service.dart';
import '../../../../services/game_mode_service.dart';
import '../../../../providers/game/timer_provider.dart';
import '../../../../providers/game/score_provider.dart';
import '../../../../providers/game/xp_provider.dart';
import '../../../../providers/game/coin_provider.dart';
import '../../../../providers/game/achievement_provider.dart';
import '../../../../providers/game/game_provider.dart';
import '../../../../providers/game/sound_provider.dart';
import '../../../../providers/game/streak_provider.dart';
import '../../../../repositories/statistics_repository.dart';
import '../../../../models/game/game_result_model.dart';
import '../../../../services/ad_service.dart';
import '../../../../core/widgets/explanation_widget.dart';
import '../../../../core/widgets/game_widgets.dart';
import '../../../../models/game/game_question_model.dart';
import 'result_screen.dart';

// Remove unused import

class ModeGameScreen extends ConsumerStatefulWidget {
  final GameModeType modeType;

  const ModeGameScreen({super.key, required this.modeType});

  @override
  ConsumerState<ModeGameScreen> createState() => _ModeGameScreenState();
}

class _ModeGameScreenState extends ConsumerState<ModeGameScreen> with TickerProviderStateMixin {
  late GameModeConfig _config;
  late GameModeState _gameState;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _config = GameModeConfig.fromType(widget.modeType);
    _gameState = GameModeState(
      type: widget.modeType,
      lives: _config.initialLives,
      hintsRemaining: _config.hintCount,
      timeRemaining: _config.timeLimit,
    );

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.forward();

    // Load questions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadQuestions();
    });

    // Start timer
    if (_config.hasTimer) {
      _startTimer();
    }
  }

  Future<void> _loadQuestions() async {
    final gameNotifier = ref.read(gameProvider.notifier);
    await gameNotifier.loadQuestions(limit: _config.initialLives + 5);
  }

  @override
  void dispose() {
    _animationController.dispose();
    ref.read(timerProvider.notifier).resetTimer();
    super.dispose();
  }

  void _startTimer() {
    ref.read(timerProvider.notifier).startTimer(seconds: _config.timeLimit);
  }

  void _pauseGame() {
    setState(() => _gameState = _gameState.copyWith(isPaused: true));
    ref.read(timerProvider.notifier).pauseTimer();
    ref.read(soundServiceProvider).playButtonTap();
  }

  void _resumeGame() {
    setState(() => _gameState = _gameState.copyWith(isPaused: false));
    ref.read(timerProvider.notifier).resumeTimer();
    ref.read(soundServiceProvider).playButtonTap();
  }

  void _useHint() {
    if (_gameState.hintsRemaining > 0 && !_gameState.isPaused && !_gameState.isGameOver) {
      setState(() => _gameState = _gameState.copyWith(hintsRemaining: _gameState.hintsRemaining - 1));
      ref.read(soundServiceProvider).playButtonTap();
      // TODO: Show hint
    }
  }

  void _loseLife() {
    if (_config.hasLives) {
      final newLives = _gameState.lives - 1;
      setState(() => _gameState = _gameState.copyWith(lives: newLives));
      HapticService.wrong();

      if (newLives <= 0) {
        _endGame();
      }
    }
  }

  void _addScore(int points) {
    setState(() => _gameState = _gameState.copyWith(score: _gameState.score + points));
    ref.read(scoreProvider.notifier).addCorrect();
  }

  void _handleAnswerSelected(String answer) {
    ref.read(gameProvider.notifier).selectAnswer(answer);
    ref.read(soundServiceProvider).playButtonTap();
  }

  void _checkAnswer() {
    final gameState = ref.read(gameProvider);
    if (gameState.selectedAnswer == null) return;

    ref.read(gameProvider.notifier).checkAnswer();
    
    final isCorrect = gameState.isCurrentAnswerCorrect ?? false;
    if (isCorrect) {
      _addScore(10);
      // Award XP for correct answer
      final streak = _gameState.correctAnswers;
      final xp = ref.read(xpProvider.notifier).calculateCorrectAnswerXP(streak: streak);
      ref.read(xpProvider.notifier).addXP(xp);
      // Award coins for correct answer
      final coins = ref.read(coinProvider.notifier).calculateCorrectAnswerCoins(streak: streak);
      ref.read(coinProvider.notifier).addCoins(coins);
      HapticService.correct();
    } else {
      _loseLife();
      HapticService.wrong();
    }
  }

  Future<void> _continueToNext() async {
    await ref.read(gameProvider.notifier).continueToNext();
    ref.read(soundServiceProvider).playButtonTap();

    final gameState = ref.read(gameProvider);
    if (gameState.isGameOver) {
      _endGame();
    }
  }

  Future<void> _endGame() async {
    setState(() => _gameState = _gameState.copyWith(isGameOver: true, isTimerRunning: false));
    ref.read(timerProvider.notifier).resetTimer();

    final scoreState = ref.read(scoreProvider);
    final correctCount = scoreState.correctCount;
    final wrongCount = scoreState.wrongCount;
    final answeredCount = correctCount + wrongCount;
    final accuracy = answeredCount > 0 ? correctCount / answeredCount : 0.0;
    final gameMode = widget.modeType.name;

    // Calculate base rewards
    int xpEarned = (_gameState.score * 2) + (accuracy * 50).round();
    int coinsEarned = (_gameState.score * 1) + (accuracy * 25).round();

    // Perfect round bonus (all answers correct)
    if (accuracy >= 1.0 && answeredCount > 0) {
      final perfectBonus = ref.read(xpProvider.notifier).calculatePerfectRoundXP();
      xpEarned += perfectBonus;
    }

    // Mode-specific XP bonuses
    switch (widget.modeType) {
      case GameModeType.speedQuiz:
        // Speed quiz bonus
        final speedBonus = ref.read(xpProvider.notifier).calculateDailyChallengeXP();
        xpEarned += speedBonus;
        break;
      case GameModeType.sentenceBuilder:
        // Boss battle bonus for sentence builder
        final bossBonus = ref.read(xpProvider.notifier).calculateBossBattleXP();
        xpEarned += bossBonus;
        break;
      default:
        // Daily challenge bonus for other modes
        final dailyBonus = ref.read(xpProvider.notifier).calculateDailyChallengeXP();
        xpEarned += dailyBonus ~/ 2; // Half bonus for regular modes
        break;
    }

    // Mode-specific coin bonuses
    switch (widget.modeType) {
      case GameModeType.speedQuiz:
        // Level complete bonus for speed quiz
        final levelBonus = ref.read(coinProvider.notifier).calculateLevelCompleteCoins();
        coinsEarned += levelBonus;
        break;
      case GameModeType.sentenceBuilder:
        // Boss battle bonus for sentence builder
        final bossBonus = ref.read(coinProvider.notifier).calculateBossBattleCoins();
        coinsEarned += bossBonus;
        break;
      default:
        // Daily reward bonus for other modes
        final dailyBonus = ref.read(coinProvider.notifier).calculateDailyRewardCoins();
        coinsEarned += dailyBonus;
        break;
    }

    // Add rewards
    ref.read(xpProvider.notifier).addXP(xpEarned);
    ref.read(coinProvider.notifier).addCoins(coinsEarned);

    // Update streak
    ref.read(streakProvider.notifier).recordActiveDay();
    ref.read(streakProvider.notifier).checkAndUpdateStreak();

    // Save stats before checking achievements
    try {
      final repo = StatisticsRepository();
      await repo.saveResult(GameResultModel(
        score: _gameState.score,
        correctAnswers: correctCount,
        wrongAnswers: wrongCount,
        earnedXP: xpEarned,
        earnedCoins: coinsEarned,
        gameType: gameMode,
        completedTime: DateTime.now(),
      ));
    } catch (_) {}

    // Check achievements
    await ref.read(achievementProvider.notifier).checkGameAchievements(
      score: _gameState.score,
      correctAnswers: correctCount,
      accuracy: accuracy,
      gameMode: gameMode,
    );

    // Show interstitial ad before navigating to result
    try {
      await AdService().showInterstitialAd();
    } catch (_) {
      // Silently fail if ad fails to load/show
    }

    // Navigate to result screen
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            score: _gameState.score,
            correctAnswers: correctCount,
            wrongAnswers: wrongCount,
            earnedXP: xpEarned,
            earnedCoins: coinsEarned,
            gameMode: gameMode,
                      ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(timerProvider);
    final theme = Theme.of(context);

    // Check if timer finished
    if (timerState.isFinished && !_gameState.isGameOver && !_gameState.isPaused) {
      _endGame();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_config.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _getModeColor(),
        actions: [
          // Timer
          if (_config.hasTimer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  timerState.formattedTime,
                  style: TextStyle(
                    color: timerState.remainingSeconds < 10 ? Colors.red : _getModeColor(),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          // Pause button
          if (_config.hasPause)
            IconButton(
              icon: Icon(_gameState.isPaused ? Icons.play_arrow : Icons.pause),
              onPressed: _gameState.isPaused ? _resumeGame : _pauseGame,
            ),
        ],
      ),
      body: _gameState.isPaused
          ? _buildPauseOverlay()
          : _buildGameContent(theme),
    );
  }

  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Paused', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _resumeGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Resume', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Quit', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameContent(ThemeData theme) {
    final gameState = ref.watch(gameProvider);

    if (gameState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (gameState.error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${gameState.error}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadQuestions,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (gameState.questions.isEmpty || gameState.currentQuestion == null) {
      return const Scaffold(
        body: Center(child: Text('No questions available')),
      );
    }

    final question = gameState.currentQuestion!;

    return Column(
      children: [
        // Game Stats Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: _getModeColor(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _GameStat(label: 'Score', value: '${_gameState.score}', icon: Icons.star),
              _GameStat(
                label: 'Question',
                value: '${gameState.answeredCount + 1}/${gameState.totalQuestions}',
                icon: Icons.quiz,
              ),
              if (_config.hasLives)
                _GameStat(
                  label: 'Lives',
                  value: '${_gameState.lives}',
                  icon: Icons.favorite,
                  valueColor: Colors.red,
                ),
              if (_config.hasHints)
                _GameStat(
                  label: 'Hints',
                  value: '${_gameState.hintsRemaining}',
                  icon: Icons.lightbulb,
                  valueColor: Colors.amber,
                ),
            ],
          ),
        ),

        // Progress Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ProgressBar(
            progress: gameState.answeredCount / gameState.totalQuestions,
            color: _getModeColor(),
          ),
        ),

        // Question Area
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question Card
                  QuestionCard(
                    question: question.question,
                    tenseType: question.tenseType,
                    difficulty: question.difficulty,
                    gradientStart: _getModeColor(),
                    gradientEnd: _getModeColor().withOpacity(0.8),
                  ),

                  const SizedBox(height: 24),

                  // Answer Options or Explanation
                  if (!gameState.showExplanation) ...[
                    Text(
                      'Select your answer:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAnswerOptions(theme, question),
                    const SizedBox(height: 16),
                    if (gameState.selectedAnswer != null && !gameState.isAnswerChecked)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _checkAnswer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getModeColor(),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Check Answer',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ] else if (gameState.showExplanation) ...[
                    ExplanationWidget(
                      explanation: question.explanation,
                      isCorrect: gameState.isCurrentAnswerCorrect ?? false,
                      onContinue: _continueToNext,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerOptions(ThemeData theme, GameQuestionModel question) {
    return Column(
      children: List.generate(question.options.length, (index) {
        final option = question.options[index];
        final isSelected = ref.watch(gameProvider).selectedAnswer == option;
        final isCorrect = question.correctAnswer == option;
        final isWrong = isSelected && !isCorrect;
        final showResult = ref.watch(gameProvider).showExplanation;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: OptionButton(
            option: option,
            index: index,
            isSelected: isSelected,
            isCorrect: showResult && isCorrect,
            isWrong: showResult && isWrong,
                    onTap: showResult ? () {} : () { _handleAnswerSelected(option); },
            color: _getModeColor(),
          ),
        );
      }),
    );
  }

  String _getModeQuestionText() {
    // Placeholder - each mode will provide its own question format
    return 'Sample question for ${_config.name} mode';
  }

  Color _getModeColor() {
    switch (widget.modeType) {
      case GameModeType.fillInBlank:
        return Colors.blue;
      case GameModeType.chooseCorrectTense:
        return Colors.green;
      case GameModeType.sentenceBuilder:
        return Colors.orange;
      case GameModeType.errorDetection:
        return Colors.red;
      case GameModeType.translationChallenge:
        return Colors.purple;
      case GameModeType.speedQuiz:
        return Colors.teal;
    }
  }
}

class _GameStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _GameStat({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}