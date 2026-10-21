import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/game/xp_provider.dart';
import '../../../providers/game/coin_provider.dart';
import '../../../providers/game/game_provider.dart';
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
  final bool isLeaderboardLoading;
  final bool isShowingYesterdayResults;
  final String? error;
  final int? leaderboardRank;
  final List<DailyQuizLeaderboardEntry> topEntries;

  const DailyQuizState({
    this.quiz,
    this.currentQuestionIndex = 0,
    this.isPlaying = false,
    this.isLoading = false,
    this.isLeaderboardLoading = false,
    this.isShowingYesterdayResults = false,
    this.error,
    this.leaderboardRank,
    this.topEntries = const [],
  });

  DailyQuizState copyWith({
    DailyQuiz? quiz,
    int? currentQuestionIndex,
    bool? isPlaying,
    bool? isLoading,
    bool? isLeaderboardLoading,
    bool? isShowingYesterdayResults,
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
      isLeaderboardLoading: isLeaderboardLoading ?? this.isLeaderboardLoading,
      isShowingYesterdayResults:
          isShowingYesterdayResults ?? this.isShowingYesterdayResults,
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
    if (userId != null) {
      final saved = _service.loadSavedQuiz(userId);
      if (saved != null) {
        debugPrint('📅 [DailyQuiz] _init: loaded from Hive '
            '(completed=${saved.isCompleted}, answers=${saved.answers.length})');
        state = state.copyWith(
          quiz: saved,
          isPlaying: saved.startedAt != null && !saved.isCompleted,
          currentQuestionIndex: saved.answers.length,
        );
      } else {
        debugPrint(
            '📅 [DailyQuiz] _init: Hive empty — waiting for loadTodayQuiz()');
      }
    } else {
      debugPrint('📅 [DailyQuiz] _init: no user — waiting for auth');
    }
    // Always fetch live standings right away so entering Daily Quiz immediately
    // displays results before the user even starts playing.
    refreshLeaderboard();
  }

  /// Current authenticated user id, or null if signed out or Firebase isn't initialized yet.
  String? get _currentUserId {
    try {
      return _ref.read(authProvider).asData?.value?.id;
    } catch (_) {
      return null;
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
    // Kick off read-only live results fetch in parallel for ALL users (even
    // before they take today's quiz!).
    final leaderboardFuture = refreshLeaderboard();

    try {
      // 0. Ensure question bank is loaded so [loadSavedQuiz] can validate
      //    the cached quiz hasn't gone stale due to question-bank edits.
      await _service.ensureQuestionBankLoaded();

      // 1. Always try Hive cache first — this is the persisted source of truth.
      final userId = _currentUserId;
      if (userId == null) {
        await leaderboardFuture;
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
        final isPlaying = cached.startedAt != null && !cached.isCompleted;
        state = state.copyWith(
          quiz: cached,
          isPlaying: isPlaying,
          isLoading: false,
          currentQuestionIndex: cached.answers.length,
          clearError: true,
        );
        await leaderboardFuture;
        return;
      }

      // 2. Hive empty — use in-memory quiz if it's for today.
      final current = state.quiz;
      if (current != null && current.date == _todayDateString()) {
        debugPrint('📅 [DailyQuiz] loadTodayQuiz: using in-memory quiz '
            '(completed=${current.isCompleted})');
        state = state.copyWith(isLoading: false, clearError: true);
        await leaderboardFuture;
        return;
      }

      // 3. Nothing cached or in memory → generate a fresh quiz for today.
      debugPrint('📅 [DailyQuiz] loadTodayQuiz: generating fresh quiz');
      final quiz = await _service.generateTodayQuiz();
      _service.saveQuiz(quiz, userId);
      state = state.copyWith(
        quiz: quiz,
        isPlaying: false,
        isLoading: false,
        currentQuestionIndex: 0,
        clearError: true,
      );
      await leaderboardFuture;
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

  String _yesterdayDateString() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
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
    state = state.copyWith(
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
      state = state.copyWith(
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
    // reward calls.
    final userId = _currentUserId;
    if (userId != null) {
      _service.saveQuiz(completed, userId);
      _service.saveQuizHistory(completed, userId);
    }
    state = state.copyWith(
      quiz: completed,
      isPlaying: false,
    );

    // Award XP and coins (best-effort — must not undo completion).
    try {
      await _ref.read(xpProvider.notifier).addXP(completed.earnedXP);
      await _ref.read(coinProvider.notifier).addCoins(completed.earnedCoins);

      if (userId != null) {
        final progressRepo = _ref.read(progressRepositoryProvider);
        final localProgress = progressRepo.getProgress();
        if (localProgress != null) {
          final updatedProgress = localProgress.copyWith(userId: userId);
          await progressRepo.uploadProgressToFirestore(updatedProgress);
        }
      }
    } catch (_) {
      // Rewards are non-critical; completion is already persisted.
    }

    // Upload to leaderboard and fetch updated rankings.
    try {
      final leaderboardData = await _uploadAndFetchLeaderboard(completed);
      state = state.copyWith(
        topEntries: leaderboardData.$1,
        leaderboardRank: leaderboardData.$2,
        isShowingYesterdayResults: false,
      );
    } catch (_) {
      // Leaderboard is non-critical; completion is already persisted.
    }
  }

  /// Read-only fetch of today's live results so users see live standings right
  /// upon entering Daily Quiz (even before playing). Never uploads 0-point rows.
  /// If nobody has completed today's quiz yet, falls back to yesterday's final
  /// results so learners always see competitive scores to beat.
  Future<void> refreshLeaderboard() async {
    state = state.copyWith(isLeaderboardLoading: state.topEntries.isEmpty);
    try {
      final today = _todayDateString();
      final userId = _currentUserId;

      final todayEntries =
          await _leaderboardService.fetchTopEntries(today, limit: 15);
      final rank = userId != null
          ? await _leaderboardService.getUserRank(userId, today)
          : null;

      if (todayEntries.isNotEmpty) {
        state = state.copyWith(
          topEntries: todayEntries,
          leaderboardRank: rank,
          clearLeaderboardRank: rank == null,
          isShowingYesterdayResults: false,
          isLeaderboardLoading: false,
        );
        return;
      }

      // Early-morning fallback: show yesterday's final winners to inspire play.
      final yesterdayEntries = await _leaderboardService.fetchTopEntries(
        _yesterdayDateString(),
        limit: 15,
      );
      state = state.copyWith(
        topEntries: yesterdayEntries,
        clearLeaderboardRank: true,
        isShowingYesterdayResults: yesterdayEntries.isNotEmpty,
        isLeaderboardLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLeaderboardLoading: false);
    }
  }

  /// Upload today's completed result to the daily leaderboard, then fetch top
  /// entries and the current user's rank.
  Future<(List<DailyQuizLeaderboardEntry>, int?)> _uploadAndFetchLeaderboard(
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
          await _leaderboardService.fetchTopEntries(quiz.date, limit: 15);
      final rank =
          await _leaderboardService.getUserRank(authUser.id, quiz.date);

      return (top, rank);
    } catch (_) {
      return (<DailyQuizLeaderboardEntry>[], null);
    }
  }

  /// Restore quiz state from the Hive cache (if available).
  void restoreFromCache() {
    final userId = _currentUserId;
    if (userId != null) {
      final saved = _service.loadSavedQuiz(userId);
      if (saved != null) {
        state = state.copyWith(
          quiz: saved,
          isPlaying: saved.startedAt != null && !saved.isCompleted,
          currentQuestionIndex: saved.answers.length,
        );
      }
    }
    refreshLeaderboard();
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
