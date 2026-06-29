import 'package:flutter/foundation.dart';
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
  
  final GameMode? gameMode;

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
    this.gameMode,
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
    GameMode? gameMode,
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
      gameMode: gameMode ?? this.gameMode,
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
        gameMode: mode,
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

  Future<void> continueToNext() async {
    if (state.isGameOver) return;

    final answers = List<String>.from(state.userAnswers);
    
    if (state.isLastQuestion) {
      await _finishGame(answers);
    } else {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex + 1,
        selectedAnswer: null,
        showExplanation: false,
        isAnswerChecked: false,
      );
    }
  }

  Future<void> skipQuestion() async {
    if (state.isGameOver) return;
    final answers = List<String>.from(state.userAnswers)..add('');
    
    if (state.isLastQuestion) {
      await _finishGame(answers);
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
      earnedXP: 0,
      earnedCoins: 0,
    );

    final correctCount = baseResult.correctAnswers;
    final total = baseResult.correctAnswers + baseResult.wrongAnswers;
    final accuracy = total > 0 ? correctCount / total : 0.0;
    final isPerfect = accuracy >= 1.0;

    final earnedXP = correctCount * 10 +
        (accuracy >= 0.85 ? 30 : accuracy >= 0.7 ? 15 : 0) +
        (isPerfect ? correctCount * 5 : 0);
    final earnedCoins = correctCount * 5 +
        (accuracy >= 0.85 ? 15 : accuracy >= 0.7 ? 8 : 0) +
        (isPerfect ? correctCount * 3 : 0);

    final bool isWin = baseResult.accuracy >= 0.5;
    final tagged = baseResult.copyWith(
      gameType: state.gameType,
      durationSeconds: duration.inSeconds,
      earnedXP: earnedXP,
      earnedCoins: earnedCoins,
      isBossWin: state.gameType == 'boss' && isWin,
      isDailyChallengeWin:
          state.gameType == 'daily_challenge' && isWin,
    );

    try {
      await _gameService.saveResult(tagged, duration: duration);
    } catch (e) {
      debugPrint('Failed to save game result: $e');
    }

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