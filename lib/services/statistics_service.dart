import '../models/game/game_result_model.dart';
import '../repositories/statistics_repository.dart';
import '../repositories/progress_repository.dart';
import 'streak_service.dart';

class StatisticsService {
  final StatisticsRepository _statisticsRepository;
  final ProgressRepository _progressRepository;
  final StreakService _streakService;

  StatisticsService({
    required StatisticsRepository statisticsRepository,
    required ProgressRepository progressRepository,
    StreakService? streakService,
  })  : _statisticsRepository = statisticsRepository,
        _progressRepository = progressRepository,
        _streakService = streakService ??
            StreakService(progressRepository: progressRepository);

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
    final results = _statisticsRepository.getResults();
    final completed = results
        .where((r) => r.durationSeconds > 0)
        .toList(growable: false);
    if (completed.isEmpty) return Duration.zero;
    final totalSeconds =
        completed.fold<int>(0, (sum, r) => sum + r.durationSeconds);
    final avg = totalSeconds ~/ completed.length;
    return Duration(seconds: avg);
  }

  // ── Phase 18 meta counters ──

  int getBossWins() => _statisticsRepository.getBossWins();

  Future<void> recordBossWin() async {
    await _statisticsRepository.incrementBossWins();
  }

  int getDailyChallengeWins() =>
      _statisticsRepository.getDailyChallengeWins();

  Future<void> recordDailyChallengeWin() async {
    await _statisticsRepository.incrementDailyChallengeWins();
  }

  int getTimePlayedSeconds() =>
      _statisticsRepository.getTimePlayedSeconds();

  Duration getTimePlayed() {
    return Duration(seconds: getTimePlayedSeconds());
  }

  Future<void> addTimePlayed(Duration duration) async {
    await _statisticsRepository.addTimePlayed(duration.inSeconds);
  }

  /// Best streak ever achieved. Sourced from the persistent
  /// `longestStreak` recorded by the streak service so it survives
  /// streak resets.
  int getBestStreak() {
    return _streakService.getLongestStreak();
  }

  // ── Time formatting helpers ──

  /// Pretty-print a duration as `Hh Mm` (e.g. `2h 15m`) or `Mm Ss`
  /// when under an hour.
  String formatDuration(Duration d) {
    if (d.inSeconds <= 0) return '0m';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  // ── Streak Statistics ──

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
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final tomorrow = today.add(const Duration(days: 1));
    return getResultsByDateRange(start: today, end: tomorrow);
  }

  List<GameResultModel> getThisWeekResults() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDay =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    return getResultsByDateRange(start: weekStartDay, end: now);
  }

  List<GameResultModel> getThisMonthResults() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return getResultsByDateRange(start: monthStart, end: now);
  }

  // ── Daily Stats ──

  int getTodayGamesPlayed() => getTodayResults().length;

  int getTodayCorrectAnswers() =>
      getTodayResults().fold(0, (sum, r) => sum + r.correctAnswers);

  int getTodayWrongAnswers() =>
      getTodayResults().fold(0, (sum, r) => sum + r.wrongAnswers);

  double getTodayAccuracy() {
    final results = getTodayResults();
    if (results.isEmpty) return 0.0;
    final correct = results.fold(0, (sum, r) => sum + r.correctAnswers);
    final total =
        results.fold(0, (sum, r) => sum + r.correctAnswers + r.wrongAnswers);
    if (total == 0) return 0.0;
    return correct / total;
  }

  int getTodayEarnedXP() =>
      getTodayResults().fold(0, (sum, r) => sum + r.earnedXP);

  int getTodayEarnedCoins() =>
      getTodayResults().fold(0, (sum, r) => sum + r.earnedCoins);

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
      'bestStreak': getBestStreak(),
      'bossWins': getBossWins(),
      'dailyChallengeWins': getDailyChallengeWins(),
      'timePlayedSeconds': getTimePlayedSeconds(),
      'timePlayedFormatted': formatDuration(getTimePlayed()),
      'bestAccuracy': getBestResult()?.accuracy ?? 0.0,
      'highestScore': getHighestScore(),
      'averageScore': getAverageScore(),
      'averageGameDuration': formatDuration(getAverageGameDuration()),
      'performanceRating': getCurrentPerformanceRating(),
      'todayGamesPlayed': getTodayGamesPlayed(),
      'todayAccuracy': getTodayAccuracy(),
      'todayEarnedXP': getTodayEarnedXP(),
      'todayEarnedCoins': getTodayEarnedCoins(),
    };
  }
}
