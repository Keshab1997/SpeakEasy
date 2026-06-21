import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game/game_question_model.dart';
import '../../models/game/game_result_model.dart';
import '../../services/game_service.dart';
import '../../repositories/game_repository.dart';
import '../../repositories/progress_repository.dart';
import '../../repositories/statistics_repository.dart';

// ── Repositories ──

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return GameRepository();
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository();
});

final statisticsRepositoryProvider = Provider<StatisticsRepository>((ref) {
  return StatisticsRepository();
});

// ── Services ──

final gameServiceProvider = Provider<GameService>((ref) {
  return GameService(
    gameRepository: ref.watch(gameRepositoryProvider),
    progressRepository: ref.watch(progressRepositoryProvider),
    statisticsRepository: ref.watch(statisticsRepositoryProvider),
  );
});

// ── Game State ──

class GameState {
  final List<GameQuestionModel> questions;
  final int currentQuestionIndex;
  final List<String> userAnswers;
  final bool isGameOver;
  final bool isLoading;
  final String? error;
  final GameResultModel? lastResult;
  final String? selectedAnswer;
  final bool showExplanation;
  final bool isAnswerChecked;

  /// Discriminator for which flow started this round. Drives the
  /// Phase 18 boss / daily-challenge win counters.
  final String gameType;

  /// Wall-clock start of the round. Captured when the first question
  /// is loaded; used to compute [GameResultModel.durationSeconds].
  final DateTime? startedAt;

  const GameState({
    this.questions = const [],
    this.currentQuestionIndex = 0,
    this.userAnswers = const [],
    this.isGameOver = false,
    this.isLoading = false,
    this.error,
    this.lastResult,
    this.selectedAnswer,
    this.showExplanation = false,
    this.isAnswerChecked = false,
    this.gameType = 'normal',
    this.startedAt,
  });

  GameState copyWith({
    List<GameQuestionModel>? questions,
    int? currentQuestionIndex,
    List<String>? userAnswers,
    bool? isGameOver,
    bool? isLoading,
    String? error,
    GameResultModel? lastResult,
    String? selectedAnswer,
    bool? showExplanation,
    bool? isAnswerChecked,
    String? gameType,
    DateTime? startedAt,
    bool clearError = false,
  }) {
    return GameState(
      questions: questions ?? this.questions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      userAnswers: userAnswers ?? this.userAnswers,
      isGameOver: isGameOver ?? this.isGameOver,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      lastResult: lastResult ?? this.lastResult,
      selectedAnswer: selectedAnswer ?? this.selectedAnswer,
      showExplanation: showExplanation ?? this.showExplanation,
      isAnswerChecked: isAnswerChecked ?? this.isAnswerChecked,
      gameType: gameType ?? this.gameType,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  GameQuestionModel? get currentQuestion {
    if (currentQuestionIndex < 0 || currentQuestionIndex >= questions.length) {
      return null;
    }
    return questions[currentQuestionIndex];
  }

  int get totalQuestions => questions.length;
  int get answeredCount => userAnswers.length;
  int get remainingQuestions => totalQuestions - answeredCount;
  bool get hasNextQuestion => currentQuestionIndex < totalQuestions - 1;
  bool get isLastQuestion => currentQuestionIndex == totalQuestions - 1;
  
  bool? get isCurrentAnswerCorrect {
    if (selectedAnswer == null || currentQuestion == null) return null;
    final correct = currentQuestion!.correctAnswer.trim().toLowerCase();
    final selected = selectedAnswer!.trim().toLowerCase();
    return correct == selected;
  }
}

class GameNotifier extends StateNotifier<GameState> {
  final GameService _gameService;

  GameNotifier(this._gameService) : super(const GameState());

  Future<void> loadQuestions({
    String? tenseType,
    String? difficulty,
    GameMode? mode,
    int? limit,
    String gameType = 'normal',
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final questions = await _gameService.loadQuestions(
        tenseType: tenseType,
        difficulty: difficulty,
        mode: mode,
        limit: limit,
      );

      state = state.copyWith(
        questions: questions,
        currentQuestionIndex: 0,
        userAnswers: [],
        isGameOver: false,
        isLoading: false,
        lastResult: null,
        gameType: gameType,
        startedAt: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void selectAnswer(String answer) {
    if (state.isGameOver || state.isAnswerChecked) return;
    state = state.copyWith(
      selectedAnswer: answer,
      showExplanation: false,
      isAnswerChecked: false,
    );
  }

  void checkAnswer() {
    if (state.isGameOver || state.selectedAnswer == null || state.isAnswerChecked) return;
    
    final answers = List<String>.from(state.userAnswers)..add(state.selectedAnswer!);
    
    state = state.copyWith(
      userAnswers: answers,
      showExplanation: true,
      isAnswerChecked: true,
    );
  }

  void continueToNext() {
    if (state.isGameOver) return;

    final answers = List<String>.from(state.userAnswers);
    
    if (state.isLastQuestion) {
      _finishGame(answers);
    } else {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex + 1,
        selectedAnswer: null,
        showExplanation: false,
        isAnswerChecked: false,
      );
    }
  }

  void skipQuestion() {
    if (state.isGameOver) return;
    final answers = List<String>.from(state.userAnswers)..add('');
    
    if (state.isLastQuestion) {
      _finishGame(answers);
    } else {
      state = state.copyWith(
        userAnswers: answers,
        currentQuestionIndex: state.currentQuestionIndex + 1,
        selectedAnswer: null,
        showExplanation: false,
        isAnswerChecked: false,
      );
    }
  }

  Future<void> _finishGame(List<String> answers) async {
    final duration = state.startedAt == null
        ? Duration.zero
        : DateTime.now().difference(state.startedAt!);

    final baseResult = await _gameService.calculateResult(
      questions: state.questions,
      userAnswers: answers,
      earnedXP: 0, // Will be calculated by XpService
      earnedCoins: 0, // Will be calculated by CoinService
    );

    // A round only counts as a boss / daily-challenge win when the
    // player cleared it with a passing accuracy. The exact threshold is
    // intentionally lenient (>= 50%) so partial-completion boss rounds
    // still credit progress; tighten here if product policy changes.
    final bool isWin = baseResult.accuracy >= 0.5;
    final tagged = baseResult.copyWith(
      gameType: state.gameType,
      durationSeconds: duration.inSeconds,
      isBossWin: state.gameType == 'boss' && isWin,
      isDailyChallengeWin:
          state.gameType == 'daily_challenge' && isWin,
    );

    await _gameService.saveResult(tagged, duration: duration);

    state = state.copyWith(
      userAnswers: answers,
      isGameOver: true,
      lastResult: tagged,
    );
  }

  void nextQuestion() {
    if (state.hasNextQuestion) {
      state = state.copyWith(currentQuestionIndex: state.currentQuestionIndex + 1);
    }
  }

  void previousQuestion() {
    if (state.currentQuestionIndex > 0) {
      state = state.copyWith(currentQuestionIndex: state.currentQuestionIndex - 1);
    }
  }

  void reset() {
    state = const GameState();
  }

  void setError(String error) {
    state = state.copyWith(error: error);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final gameProvider = StateNotifierProvider<GameNotifier, GameState>((ref) {
  final gameService = ref.watch(gameServiceProvider);
  return GameNotifier(gameService);
});