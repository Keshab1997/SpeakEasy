import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/statistics_service.dart';
import '../../services/streak_service.dart';
import '../../repositories/statistics_repository.dart';
import '../../repositories/progress_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Statistics State ──

class StatisticsState {
  // Overall counts
  final int totalGamesPlayed;
  final int totalCorrectAnswers;
  final int totalWrongAnswers;
  final double overallAccuracy;

  // Rewards
  final int totalEarnedXP;
  final int totalEarnedCoins;

  // Current live values (mirrored from progress so the screen has
  // them without needing to also watch xpProvider/coinProvider).
  final int currentXP;
  final int currentLevel;
  final int currentCoins;
  final int currentStreak;
  final int bestStreak;

  // Performance
  final int highestScore;
  final double averageScore;
  final String performanceRating;

  // Phase 18 additions
  final int bossWins;
  final int dailyChallengeWins;
  final int timePlayedSeconds;
  final String timePlayedFormatted;

  // Loading / error
  final bool isLoading;

  const StatisticsState({
    this.totalGamesPlayed = 0,
    this.totalCorrectAnswers = 0,
    this.totalWrongAnswers = 0,
    this.overallAccuracy = 0.0,
    this.totalEarnedXP = 0,
    this.totalEarnedCoins = 0,
    this.currentXP = 0,
    this.currentLevel = 1,
    this.currentCoins = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.highestScore = 0,
    this.averageScore = 0.0,
    this.performanceRating = 'Needs Practice',
    this.bossWins = 0,
    this.dailyChallengeWins = 0,
    this.timePlayedSeconds = 0,
    this.timePlayedFormatted = '0m',
    this.isLoading = false,
  });

  StatisticsState copyWith({
    int? totalGamesPlayed,
    int? totalCorrectAnswers,
    int? totalWrongAnswers,
    double? overallAccuracy,
    int? totalEarnedXP,
    int? totalEarnedCoins,
    int? currentXP,
    int? currentLevel,
    int? currentCoins,
    int? currentStreak,
    int? bestStreak,
    int? highestScore,
    double? averageScore,
    String? performanceRating,
    int? bossWins,
    int? dailyChallengeWins,
    int? timePlayedSeconds,
    String? timePlayedFormatted,
    bool? isLoading,
  }) {
    return StatisticsState(
      totalGamesPlayed: totalGamesPlayed ?? this.totalGamesPlayed,
      totalCorrectAnswers: totalCorrectAnswers ?? this.totalCorrectAnswers,
      totalWrongAnswers: totalWrongAnswers ?? this.totalWrongAnswers,
      overallAccuracy: overallAccuracy ?? this.overallAccuracy,
      totalEarnedXP: totalEarnedXP ?? this.totalEarnedXP,
      totalEarnedCoins: totalEarnedCoins ?? this.totalEarnedCoins,
      currentXP: currentXP ?? this.currentXP,
      currentLevel: currentLevel ?? this.currentLevel,
      currentCoins: currentCoins ?? this.currentCoins,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      highestScore: highestScore ?? this.highestScore,
      averageScore: averageScore ?? this.averageScore,
      performanceRating: performanceRating ?? this.performanceRating,
      bossWins: bossWins ?? this.bossWins,
      dailyChallengeWins: dailyChallengeWins ?? this.dailyChallengeWins,
      timePlayedSeconds: timePlayedSeconds ?? this.timePlayedSeconds,
      timePlayedFormatted:
          timePlayedFormatted ?? this.timePlayedFormatted,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  int get totalQuestionsAnswered => totalCorrectAnswers + totalWrongAnswers;
}

class StatisticsNotifier extends StateNotifier<StatisticsState> {
  final StatisticsService _statisticsService;
  
  // Real-time stream subscriptions
  StreamSubscription<DocumentSnapshot>? _progressSubscription;
  StreamSubscription<DocumentSnapshot>? _metaSubscription;
  StreamSubscription<QuerySnapshot>? _resultsSubscription;
  String? _currentUserId;

  StatisticsNotifier(this._statisticsService) : super(const StatisticsState()) {
    _refresh();
    _startRealtimeListeners();
  }

  Future<void> _refresh() async {
    final summary = await _statisticsService.getFullSummary();
    state = StatisticsState(
      totalGamesPlayed: summary['totalGamesPlayed'] as int,
      totalCorrectAnswers: summary['totalCorrectAnswers'] as int,
      totalWrongAnswers: summary['totalWrongAnswers'] as int,
      overallAccuracy: summary['overallAccuracy'] as double,
      totalEarnedXP: summary['totalEarnedXP'] as int,
      totalEarnedCoins: summary['totalEarnedCoins'] as int,
      currentXP: summary['currentXP'] as int,
      currentLevel: summary['currentLevel'] as int,
      currentCoins: summary['currentCoins'] as int,
      currentStreak: summary['currentStreak'] as int,
      bestStreak: summary['bestStreak'] as int,
      highestScore: summary['highestScore'] as int? ?? 0,
      averageScore: (summary['averageScore'] as num?)?.toDouble() ?? 0.0,
      performanceRating: summary['performanceRating'] as String,
      bossWins: summary['bossWins'] as int? ?? 0,
      dailyChallengeWins: summary['dailyChallengeWins'] as int? ?? 0,
      timePlayedSeconds: summary['timePlayedSeconds'] as int? ?? 0,
      timePlayedFormatted:
          summary['timePlayedFormatted'] as String? ?? '0m',
    );
  }

  void _startRealtimeListeners() {
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (_currentUserId == null || _currentUserId!.isEmpty) return;

    // Listen to progress updates — use _refresh() which reads from local Hive
    // (the source of truth). Firestore snapshots only trigger a re-read of
    // local data, they never directly overwrite state with potentially stale
    // Firestore values.
    _progressSubscription = FirebaseFirestore.instance
        .collection('game_progress')
        .doc(_currentUserId!)
        .snapshots()
        .listen((snapshot) {
      // Firestore data may be stale if local updates haven't synced yet.
      // Always prefer local Hive data via _refresh().
      _refresh();
    });

    // Listen to meta statistics updates
    _metaSubscription = FirebaseFirestore.instance
        .collection('game_statistics_meta')
        .doc(_currentUserId!)
        .snapshots()
        .listen((snapshot) {
      // Refresh from local Hive (source of truth)
      _refresh();
    });

    // Listen to new game results
    _resultsSubscription = FirebaseFirestore.instance
        .collection('game_statistics')
        .where('userId', isEqualTo: _currentUserId!)
        .snapshots()
        .listen((snapshot) {
      // When a new result is added, we refresh the whole summary to ensure
      // all aggregated stats (accuracy, total games, etc.) are correct.
      _refresh();
    });
  }

  /// Public refresh hook so providers that mutate progress (XP, coins,
  /// streak, achievements) can call this after their own refresh to
  /// keep the statistics view in sync.
  void refresh() {
    _refresh();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _metaSubscription?.cancel();
    _resultsSubscription?.cancel();
    super.dispose();
  }

  // Recording helpers — UI / other providers can call these to keep
  // counters in sync without needing to know about the repository.

  Future<void> recordBossWin() async {
    await _statisticsService.recordBossWin();
    _refresh();
  }

  Future<void> recordDailyChallengeWin() async {
    await _statisticsService.recordDailyChallengeWin();
    _refresh();
  }
}

final statisticsServiceProvider = Provider<StatisticsService>((ref) {
  return StatisticsService(
    statisticsRepository: StatisticsRepository(),
    progressRepository: ProgressRepository(),
    streakService: StreakService(
      progressRepository: ProgressRepository(),
    ),
  );
});

final statisticsProvider =
    StateNotifierProvider<StatisticsNotifier, StatisticsState>((ref) {
  final statisticsService = ref.watch(statisticsServiceProvider);
  return StatisticsNotifier(statisticsService);
});