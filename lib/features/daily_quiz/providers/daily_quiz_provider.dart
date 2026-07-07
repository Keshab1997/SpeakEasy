import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/game/xp_provider.dart';
import '../../../providers/game/coin_provider.dart';
import '../models/daily_quiz_model.dart';
import '../services/daily_quiz_service.dart';

// ---------------------------------------------------------------------------
// DailyQuizLeaderboardEntry
// ---------------------------------------------------------------------------

class DailyQuizLeaderboardEntry {
  final String userId;
  final String userName;
  final int score;
  final int totalTime;
  final int correctCount;

  const DailyQuizLeaderboardEntry({
    required this.userId,
    required this.userName,
    required this.score,
    required this.totalTime,
    required this.correctCount,
  });
}

// ---------------------------------------------------------------------------
// DailyQuizState
// ---------------------------------------------------------------------------

class DailyQuizState {
  final DailyQuiz? quiz;
  final int currentQuestionIndex;
  final bool isPlaying;
  final bool isLoading;
  final String? error;
  final int? leaderboardRank;
  final List<DailyQuizLeaderboardEntry> topEntries;

  const DailyQuizState({
    this.quiz,
    this.currentQuestionIndex = 0,
    this.isPlaying = false,
    this.isLoading = false,
    this.error,
    this.leaderboardRank,
    this.topEntries = const [],
  });

  DailyQuizState copyWith({
    DailyQuiz? quiz,
    int? currentQuestionIndex,
    bool? isPlaying,
    bool? isLoading,
    String? error,
    int? leaderboardRank,
    List<DailyQuizLeaderboardEntry>? topEntries,
    bool clearError = false,
    bool clearLeaderboardRank = false,
  }) {
    return DailyQuizState(
      quiz: quiz ?? this.quiz,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      leaderboardRank:
          clearLeaderboardRank ? null : leaderboardRank ?? this.leaderboardRank,
      topEntries: topEntries ?? this.topEntries,
    );
  }
}

// ---------------------------------------------------------------------------
// DailyQuizNotifier
// ---------------------------------------------------------------------------

class DailyQuizNotifier extends StateNotifier<DailyQuizState> {
  final DailyQuizService _service;
  final Ref _ref;

  DailyQuizNotifier(this._service, this._ref)
      : super(const DailyQuizState()) {
    _init();
  }

  // -----------------------------------------------------------------------
  // Init
  // -----------------------------------------------------------------------

  /// Called once from the constructor.
  ///
  /// Tries to load a saved quiz (only kept if it's still today's quiz).
  /// If nothing is saved the async generation helper is kicked off so the
  /// quiz is ready when the UI first reads the provider.
  void _init() {
    final saved = _service.loadSavedQuiz();
    if (saved != null) {
      state = DailyQuizState(
        quiz: saved,
        isPlaying: saved.startedAt != null && !saved.isCompleted,
        currentQuestionIndex: saved.answers.length,
      );
    } else {
      // No saved quiz for today → generate one asynchronously.
      // We intentionally avoid setting [isLoading] here so the initial
      // synchronous read returns a clean default state.
      _generateQuizAsync();
    }
  }

  /// Private async helper that generates a fresh quiz in the background.
  Future<void> _generateQuizAsync() async {
    try {
      final quiz = await _service.generateTodayQuiz();
      _service.saveQuiz(quiz);
      state = DailyQuizState(quiz: quiz);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // -----------------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------------

  /// Force-load (or reload) today's quiz.
  ///
  /// Unlike [_init] this sets [isLoading] so the UI can show a spinner.
  Future<void> loadTodayQuiz() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final quiz = await _service.generateTodayQuiz();
      _service.saveQuiz(quiz);
      state = DailyQuizState(quiz: quiz);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Mark the quiz as started so the timer / progress tracking begins.
  ///
  /// If the quiz was already started (e.g. resumed from a saved state) the
  /// original [startedAt] is preserved.
  void startQuiz() {
    final quiz = state.quiz;
    if (quiz == null) return;

    final started = quiz.copyWith(startedAt: quiz.startedAt ?? DateTime.now());
    _service.saveQuiz(started);
    state = DailyQuizState(
      quiz: started,
      isPlaying: true,
      currentQuestionIndex: started.answers.length,
    );
  }

  /// Record the user's selected answer for the current question.
  ///
  /// If this was the last question, [completeQuiz] is called automatically.
  void answerQuestion(int selectedIndex, int timeTaken) {
    final quiz = state.quiz;
    if (quiz == null || !state.isPlaying) return;

    final question = quiz.questions[state.currentQuestionIndex];
    final isCorrect = selectedIndex == question.correctAnswer;
    final points = _service.calculatePoints(isCorrect, timeTaken);

    final answer = DailyQuizAnswer(
      questionId: question.id,
      selectedAnswer: selectedIndex,
      isCorrect: isCorrect,
      timeTaken: timeTaken,
      pointsEarned: points,
    );

    _commitAnswer(quiz, answer);
  }

  /// Record that the current question timed out (no answer selected).
  ///
  /// Behaves the same as [answerQuestion] but marks the answer as incorrect
  /// with [selectedAnswer] set to `null`.
  void timeoutQuestion(int timeTaken) {
    final quiz = state.quiz;
    if (quiz == null || !state.isPlaying) return;

    final question = quiz.questions[state.currentQuestionIndex];
    final points = _service.calculatePoints(false, timeTaken);

    final answer = DailyQuizAnswer(
      questionId: question.id,
      selectedAnswer: null,
      isCorrect: false,
      timeTaken: timeTaken,
      pointsEarned: points,
    );

    _commitAnswer(quiz, answer);
  }

  /// Internal helper that appends [answer] to the quiz, persists it, and
  /// either advances to the next question or finalises the quiz.
  void _commitAnswer(DailyQuiz quiz, DailyQuizAnswer answer) {
    final updatedAnswers = [...quiz.answers, answer];
    final updatedQuiz = quiz.copyWith(answers: updatedAnswers);
    _service.saveQuiz(updatedQuiz);

    final isLastQuestion =
        state.currentQuestionIndex >= quiz.totalQuestions - 1;

    if (isLastQuestion) {
      // Persist the answer in state first, then finalise.
      state = state.copyWith(quiz: updatedQuiz);
      completeQuiz();
    } else {
      state = DailyQuizState(
        quiz: updatedQuiz,
        currentQuestionIndex: state.currentQuestionIndex + 1,
        isPlaying: true,
      );
    }
  }

  /// Finalise the quiz: calculate the score, award XP/coins, and persist.
  ///
  /// This is called internally when the last question is answered, but can
  /// also be invoked manually (e.g. if the user prematurely ends the quiz).
  Future<void> completeQuiz() async {
    final quiz = state.quiz;
    if (quiz == null || quiz.isCompleted) return;

    final completed = _service.completeQuiz(quiz);
    _service.saveQuiz(completed);

    // Award XP and coins via their providers.
    await _ref.read(xpProvider.notifier).addXP(completed.earnedXP);
    await _ref.read(coinProvider.notifier).addCoins(completed.earnedCoins);

    state = DailyQuizState(
      quiz: completed,
      isPlaying: false,
    );
  }

  /// Reset the provider back to the default (empty) state.
  void reset() {
    state = const DailyQuizState();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final dailyQuizProvider =
    StateNotifierProvider<DailyQuizNotifier, DailyQuizState>((ref) {
  return DailyQuizNotifier(DailyQuizService(), ref);
});
