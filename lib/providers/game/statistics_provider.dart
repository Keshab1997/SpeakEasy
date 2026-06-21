import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/statistics_service.dart';
import '../../repositories/statistics_repository.dart';
import '../../repositories/progress_repository.dart';
import 'game_provider.dart';

// ── Statistics State ──

class StatisticsState {
  final int totalGamesPlayed;
  final int totalCorrectAnswers;
  final int totalWrongAnswers;
  final double overallAccuracy;
  final int totalEarnedXP;
  final int totalEarnedCoins;
  final int currentXP;
  final int currentLevel;
  final int currentCoins;
  final int currentStreak;
  final int highestScore;
  final String performanceRating;
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
    this.highestScore = 0,
    this.performanceRating = 'Needs Practice',
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
    int? highestScore,
    String? performanceRating,
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
      highestScore: highestScore ?? this.highestScore,
      performanceRating: performanceRating ?? this.performanceRating,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  int get totalQuestionsAnswered => totalCorrectAnswers + totalWrongAnswers;
}

class StatisticsNotifier extends StateNotifier<StatisticsState> {
  final StatisticsService _statisticsService;

  StatisticsNotifier(this._statisticsService) : super(const StatisticsState()) {
    _refresh();
  }

  void _refresh() {
    final summary = _statisticsService.getFullSummary();
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
      highestScore: summary['highestScore'] as int? ?? 0,
      performanceRating: summary['performanceRating'] as String,
    );
  }

  void refresh() {
    _refresh();
  }
}

final statisticsServiceProvider = Provider<StatisticsService>((ref) {
  return StatisticsService(
    statisticsRepository: StatisticsRepository(),
    progressRepository: ProgressRepository(),
  );
});

final statisticsProvider = StateNotifierProvider<StatisticsNotifier, StatisticsState>((ref) {
  final statisticsService = ref.watch(statisticsServiceProvider);
  return StatisticsNotifier(statisticsService);
});