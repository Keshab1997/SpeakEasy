import '../models/game/game_result_model.dart';
import '../repositories/statistics_repository.dart';
import '../repositories/progress_repository.dart';

class StatisticsService {
  final StatisticsRepository _statisticsRepository;
  final ProgressRepository _progressRepository;

  StatisticsService({
    required StatisticsRepository statisticsRepository,
    required ProgressRepository progressRepository,
  })  : _statisticsRepository = statisticsRepository,
        _progressRepository = progressRepository;

  // ── Core Statistics ──

  int getTotalGamesPlayed() {
    return _statisticsRepository.getTotalGamesPlayed();
  }

  int getTotalCorrectAnswers() {
    return _statisticsRepository.getTotalCorrectAnswers();
  }

  int getTotalWrongAnswers() {
    return _statisticsRepository.getTotalWrongAnswers();
  }

  int getTotalQuestionsAnswered() {
    return getTotalCorrectAnswers() + getTotalWrongAnswers();
  }

  double getOverallAccuracy() {
    return _statisticsRepository.getOverallAccuracy();
  }

  int getTotalEarnedXP() {
    return _statisticsRepository.getTotalEarnedXP();
  }

  int getTotalEarnedCoins() {
    return _statisticsRepository.getTotalEarnedCoins();
  }

  int getCurrentXP() {
    final progress = _progressRepository.getProgress();
    return progress?.currentXP ?? 0;
  }

  int getCurrentLevel() {
    final progress = _progressRepository.getProgress();
    return progress?.currentLevel ?? 1;
  }

  int getCurrentCoins() {
    final progress = _progressRepository.getProgress();
    return progress?.totalCoins ?? 0;
  }

  int getCurrentStreak() {
    final progress = _progressRepository.getProgress();
    return progress?.streak ?? 0;
  }

  // ── Game Results ──

  List<GameResultModel> getRecentResults({int count = 10}) {
    final results = _statisticsRepository.getResults();
    return results.take(count).toList();
  }

  GameResultModel? getLastGameResult() {
    final results = _statisticsRepository.getResults();
    return results.isNotEmpty ? results.first : null;
  }

  GameResultModel? getBestResult() {
    return _statisticsRepository.getBestResult();
  }

  // ── Performance Metrics ──

  double getAverageScore() {
    final results = _statisticsRepository.getResults();
    if (results.isEmpty) return 0.0;
    final totalScore = results.fold(0, (sum, r) => sum + r.score);
    return totalScore / results.length;
  }

  int getHighestScore() {
    final results = _statisticsRepository.getResults();
    if (results.isEmpty) return 0;
    return results.map((r) => r.score).reduce((a, b) => a > b ? a : b);
  }

  int getLowestScore() {
    final results = _statisticsRepository.getResults();
    if (results.isEmpty) return 0;
    return results.map((r) => r.score).reduce((a, b) => a < b ? a : b);
  }

  Duration getAverageGameDuration() {
    // Placeholder — game duration tracking can be expanded
    return const Duration(minutes: 2);
  }

  // ── Streak Statistics ──

  int getBestStreak() {
    // Best streak can be stored separately; returns current streak as fallback
    final progress = _progressRepository.getProgress();
    return progress?.streak ?? 0;
  }

  // ── Performance Ratings ──

  String getPerformanceRating(double accuracy) {
    if (accuracy >= 0.95) return 'Excellent';
    if (accuracy >= 0.85) return 'Great';
    if (accuracy >= 0.70) return 'Good';
    if (accuracy >= 0.50) return 'Average';
    return 'Needs Practice';
  }

  String getCurrentPerformanceRating() {
    return getPerformanceRating(getOverallAccuracy());
  }

  // ── Progress Over Time ──

  List<GameResultModel> getResultsByDateRange({
    required DateTime start,
    required DateTime end,
  }) {
    return _statisticsRepository.getResults().where((r) {
      return r.completedTime.isAfter(start) && r.completedTime.isBefore(end);
    }).toList();
  }

  List<GameResultModel> getTodayResults() {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final tomorrow = today.add(const Duration(days: 1));
    return getResultsByDateRange(start: today, end: tomorrow);
  }

  List<GameResultModel> getThisWeekResults() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return getResultsByDateRange(start: weekStartDay, end: now);
  }

  List<GameResultModel> getThisMonthResults() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return getResultsByDateRange(start: monthStart, end: now);
  }

  // ── Daily Stats ──

  int getTodayGamesPlayed() {
    return getTodayResults().length;
  }

  int getTodayCorrectAnswers() {
    return getTodayResults().fold(0, (sum, r) => sum + r.correctAnswers);
  }

  int getTodayWrongAnswers() {
    return getTodayResults().fold(0, (sum, r) => sum + r.wrongAnswers);
  }

  double getTodayAccuracy() {
    final results = getTodayResults();
    if (results.isEmpty) return 0.0;
    final correct = results.fold(0, (sum, r) => sum + r.correctAnswers);
    final total = results.fold(0, (sum, r) => sum + r.correctAnswers + r.wrongAnswers);
    if (total == 0) return 0.0;
    return correct / total;
  }

  int getTodayEarnedXP() {
    return getTodayResults().fold(0, (sum, r) => sum + r.earnedXP);
  }

  int getTodayEarnedCoins() {
    return getTodayResults().fold(0, (sum, r) => sum + r.earnedCoins);
  }

  // ── Summary ──

  Map<String, dynamic> getFullSummary() {
    return {
      'totalGamesPlayed': getTotalGamesPlayed(),
      'totalCorrectAnswers': getTotalCorrectAnswers(),
      'totalWrongAnswers': getTotalWrongAnswers(),
      'totalQuestionsAnswered': getTotalQuestionsAnswered(),
      'overallAccuracy': getOverallAccuracy(),
      'totalEarnedXP': getTotalEarnedXP(),
      'totalEarnedCoins': getTotalEarnedCoins(),
      'currentXP': getCurrentXP(),
      'currentLevel': getCurrentLevel(),
      'currentCoins': getCurrentCoins(),
      'currentStreak': getCurrentStreak(),
      'bestAccuracy': getBestResult()?.accuracy ?? 0.0,
      'highestScore': getHighestScore(),
      'averageScore': getAverageScore(),
      'performanceRating': getCurrentPerformanceRating(),
      'todayGamesPlayed': getTodayGamesPlayed(),
      'todayAccuracy': getTodayAccuracy(),
      'todayEarnedXP': getTodayEarnedXP(),
      'todayEarnedCoins': getTodayEarnedCoins(),
    };
  }
}