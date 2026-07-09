import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/game/xp_provider.dart';
import '../../../providers/game/coin_provider.dart';
import '../models/daily_quiz_model.dart';
import '../services/daily_quiz_service.dart';
import '../services/daily_quiz_leaderboard_service.dart';

// ---------------------------------------------------------------------------
// DailyQuizLeaderboardEntry
// ---------------------------------------------------------------------------

class DailyQuizLeaderboardEntry {
  final String userId;
  final String userName;
  final int score;
  final int totalTime;
  final int correctCount;
  final String? photoUrl;

  const DailyQuizLeaderboardEntry({
    required this.userId,
    required this.userName,
    required this.score,
    required this.totalTime,
    required this.correctCount,
    this.photoUrl,
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
  final DailyQuizLeaderboardService _leaderboardService;
  final Ref _ref;

  DailyQuizNotifier(this._service, this._leaderboardService, this._ref)
      : super(const DailyQuizState()) {
    _init();
  }

  // -----------------------------------------------------------------------
  // Init
  // -----------------------------------------------------------------------

  /// Called once from the constructor.
  ///
  /// Tries to load a saved quiz from Hive (only kept if still today's quiz).
  /// Does NOT generate a new quiz here — that's handled by [loadTodayQuiz].
  /// This avoids the race condition where a freshly generated in-memory quiz
  /// would shadow a persisted completed quiz in Hive.
  void _init() {
    final userId = _currentUserId;
    if (userId == null) {
      // No user yet — nothing account-scoped to restore. loadTodayQuiz()
      // (called from the home screen after auth resolves) will populate it.
      debugPrint('📅 [DailyQuiz] _init: no user — waiting for auth');
      return;
    }
    final saved = _service.loadSavedQuiz(userId);
    if (saved != null) {
      debugPrint('📅 [DailyQuiz] _init: loaded from Hive '
          '(completed=${saved.isCompleted}, answers=${saved.answers.length})');
      state = DailyQuizState(
        quiz: saved,
        isPlaying: saved.startedAt != null && !saved.isCompleted,
        currentQuestionIndex: saved.answers.length,
      );
      // If already completed, fetch leaderboard data in the background.
      if (saved.isCompleted) {
        _fetchLeaderboard(saved).then((data) {
          state = state.copyWith(
            topEntries: data.$1,
            leaderboardRank: data.$2,
          );
        });
      }
    } else {
      debugPrint('📅 [DailyQuiz] _init: Hive empty — waiting for loadTodayQuiz()');
    }
    // No fallback generation here — loadTodayQuiz() (called from home screen)
    // will handle that with proper isLoading state.
  }

  /// Current authenticated user id, or null if signed out.
  String? get _currentUserId =>
      _ref.read(authProvider).asData?.value?.id;

  /// Private async helper that generates a fresh quiz in the background.
  Future<void> _generateQuizAsync() async {
    try {
      final quiz = await _service.generateTodayQuiz();
      final userId = _currentUserId;
      if (userId != null) _service.saveQuiz(quiz, userId);
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
  /// Always tries Hive FIRST (source of truth for persistence), then falls
  /// back to the in-memory quiz, and only generates fresh if both are empty.
  Future<void> loadTodayQuiz() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // 0. Ensure question bank is loaded so [loadSavedQuiz] can validate
      //    the cached quiz hasn't gone stale due to question-bank edits.
      await _service.ensureQuestionBankLoaded();

      // 1. Always try Hive cache first — this is the persisted source of truth.
      final userId = _currentUserId;
      if (userId == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Please sign in to access the daily quiz.',
        );
        return;
      }
      final cached = _service.loadSavedQuiz(userId);
      if (cached != null) {
        debugPrint('📅 [DailyQuiz] loadTodayQuiz: restored from Hive '
            '(completed=${cached.isCompleted}, answers=${cached.answers.length})');
        _service.saveQuiz(cached, userId);
        final isPlaying = cached.startedAt != null && !cached.isCompleted;
        state = DailyQuizState(
          quiz: cached,
          isPlaying: isPlaying,
          currentQuestionIndex: cached.answers.length,
        );
        if (cached.isCompleted) {
          _fetchLeaderboard(cached).then((data) {
            state = state.copyWith(
              topEntries: data.$1,
              leaderboardRank: data.$2,
            );
          });
        }
        return;
      }

      // 2. Hive empty — use in-memory quiz if it's for today
      //    (e.g. generated earlier in this session by [_generateQuizAsync]).
      final current = state.quiz;
      if (current != null && current.date == _todayDateString()) {
        debugPrint('📅 [DailyQuiz] loadTodayQuiz: using in-memory quiz '
            '(completed=${current.isCompleted})');
        state = state.copyWith(isLoading: false);
        if (current.isCompleted) {
          _fetchLeaderboard(current).then((data) {
            state = state.copyWith(
              topEntries: data.$1,
              leaderboardRank: data.$2,
            );
          });
        }
        return;
      }

      // 3. Nothing cached or in memory → generate a fresh quiz for today.
      debugPrint('📅 [DailyQuiz] loadTodayQuiz: generating fresh quiz');
      final quiz = await _service.generateTodayQuiz();
      _service.saveQuiz(quiz, userId);
      state = DailyQuizState(quiz: quiz, isPlaying: false);
    } catch (e) {
      debugPrint('📅 [DailyQuiz] loadTodayQuiz: ERROR $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Returns today's date string in the same format used by the service.
  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Mark the quiz as started so the timer / progress tracking begins.
  ///
  /// If the quiz was already started (e.g. resumed from a saved state) the
  /// original [startedAt] is preserved. A quiz that has already been
  /// completed today can never be restarted.
  void startQuiz() {
    final quiz = state.quiz;
    if (quiz == null || quiz.isCompleted) return;

    final started = quiz.copyWith(startedAt: quiz.startedAt ?? DateTime.now());
    final userId = _currentUserId;
    if (userId != null) _service.saveQuiz(started, userId);
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
    if (quiz == null || !state.isPlaying || quiz.isCompleted) return;

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

  /// Record an answer for complex question types (match_pairs, rearrange).
  ///
  /// [isCorrect] is determined by the widget based on the specific logic.
  void answerComplexQuestion(Map<String, dynamic> responseData, bool isCorrect,
      int timeTaken) {
    final quiz = state.quiz;
    if (quiz == null || !state.isPlaying || quiz.isCompleted) return;

    final question = quiz.questions[state.currentQuestionIndex];
    final points = _service.calculatePoints(isCorrect, timeTaken);

    final answer = DailyQuizAnswer(
      questionId: question.id,
      isCorrect: isCorrect,
      timeTaken: timeTaken,
      pointsEarned: points,
      responseData: responseData,
    );

    _commitAnswer(quiz, answer);
  }

  /// Record that the current question timed out (no answer selected).
  ///
  /// Behaves the same as [answerQuestion] but marks the answer as incorrect
  /// with [selectedAnswer] set to `null`.
  void timeoutQuestion(int timeTaken) {
    final quiz = state.quiz;
    if (quiz == null || !state.isPlaying || quiz.isCompleted) return;

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
    final userId = _currentUserId;
    if (userId != null) _service.saveQuiz(updatedQuiz, userId);

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

  /// Finalise the quiz: calculate the score, award XP/coins, persist,
  /// upload to leaderboard, and fetch top entries.
  ///
  /// This is called internally when the last question is answered, but can
  /// also be invoked manually (e.g. if the user prematurely ends the quiz).
  Future<void> completeQuiz() async {
    final quiz = state.quiz;
    if (quiz == null || quiz.isCompleted) return;

    final completed = _service.completeQuiz(quiz);

    // Persist completion IMMEDIATELY and update state before any network /
    // reward calls. This guarantees that, even if the XP/coin/leaderboard
    // requests below fail (offline, permissions, etc.), today's quiz stays
    // marked as completed and is restored as "already done" on the next app
    // launch — so the user is never offered the quiz again.
    final userId = _currentUserId;
    if (userId != null) _service.saveQuiz(completed, userId);
    state = DailyQuizState(
      quiz: completed,
      isPlaying: false,
    );

    // Award XP and coins (best-effort — must not undo completion).
    try {
      await _ref.read(xpProvider.notifier).addXP(completed.earnedXP);
      await _ref.read(coinProvider.notifier).addCoins(completed.earnedCoins);
    } catch (_) {
      // Rewards are non-critical; completion is already persisted.
    }

    // Upload to leaderboard and fetch updated rankings.
    try {
      final leaderboardData = await _fetchLeaderboard(completed);
      state = state.copyWith(
        topEntries: leaderboardData.$1,
        leaderboardRank: leaderboardData.$2,
      );
    } catch (_) {
      // Leaderboard is non-critical; completion is already persisted.
    }
  }

  /// Upload today's result to the daily leaderboard, then fetch top entries
  /// and the current user's rank.
  ///
  /// Returns a record of (topEntries, leaderboardRank).
	  Future<(List<DailyQuizLeaderboardEntry>, int?)> _fetchLeaderboard(
	      DailyQuiz quiz) async {
	    try {
	      final authUser = _ref.read(authProvider).asData?.value;
	      if (authUser == null) {
        return (<DailyQuizLeaderboardEntry>[], null);
      }

      await _leaderboardService.uploadResult(
        userId: authUser.id,
        userName: authUser.name.isNotEmpty ? authUser.name : 'User',
        photoUrl: authUser.photoUrl,
        date: quiz.date,
        score: quiz.score,
        totalTime: quiz.totalTime,
        correctCount: quiz.correctCount,
      );

      final top =
          await _leaderboardService.fetchTopEntries(quiz.date, limit: 10);
      final rank =
          await _leaderboardService.getUserRank(authUser.id, quiz.date);

      return (top, rank);
	    } catch (_) {
      return (<DailyQuizLeaderboardEntry>[], null);
    }
  }

  /// Restore quiz state from the Hive cache (if available).
  ///
  /// Useful when the provider state was cleared but the quiz is still cached.
  void restoreFromCache() {
    final userId = _currentUserId;
    if (userId == null) return;
    final saved = _service.loadSavedQuiz(userId);
    if (saved != null) {
      state = DailyQuizState(
        quiz: saved,
        isPlaying: saved.startedAt != null && !saved.isCompleted,
        currentQuestionIndex: saved.answers.length,
      );
      if (saved.isCompleted) {
        _fetchLeaderboard(saved).then((data) {
          state = state.copyWith(
            topEntries: data.$1,
            leaderboardRank: data.$2,
          );
        });
      }
    }
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
  return DailyQuizNotifier(
    DailyQuizService(),
    DailyQuizLeaderboardService(),
    ref,
  );
});
