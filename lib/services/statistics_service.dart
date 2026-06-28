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

  Future<int> getTotalGamesPlayed() {
    return _statisticsRepository.getTotalGamesPlayed();
  }

  Future<int> getTotalCorrectAnswers() {
    return _statisticsRepository.getTotalCorrectAnswers();
  }

  Future<int> getTotalWrongAnswers() {
    return _statisticsRepository.getTotalWrongAnswers();
  }

  Future<int> getTotalQuestionsAnswered() async {
    return (await getTotalCorrectAnswers()) + (await getTotalWrongAnswers());
  }

  Future<double> getOverallAccuracy() {
    return _statisticsRepository.getOverallAccuracy();
  }

  Future<int> getTotalEarnedXP() {
    return _statisticsRepository.getTotalEarnedXP();
  }

  Future<int> getTotalEarnedCoins() {
    return _statisticsRepository.getTotalEarnedCoins();
  }

  Future<int> getCurrentXP() async {
    // Prefer the cumulative total from statistics; fall back to progress box
    final totalEarned = await _statisticsRepository.getTotalEarnedXP();
    if (totalEarned > 0) return totalEarned;
    final progress = _progressRepository.getProgress();
    return progress?.currentXP ?? 0;
  }

  Future<int> getCurrentLevel() async {
    // Derive level from total earned XP (100 XP per level)
    final totalXP = await getCurrentXP();
    if (totalXP > 0) return (totalXP ~/ 100) + 1;
    final progress = _progressRepository.getProgress();
    return progress?.currentLevel ?? 1;
  }

  Future<int> getCurrentCoins() async {
    // Prefer the cumulative total from statistics; fall back to progress box
    final totalEarned = await _statisticsRepository.getTotalEarnedCoins();
    if (totalEarned > 0) return totalEarned;
    final progress = _progressRepository.getProgress();
    return progress?.totalCoins ?? 0;
  }

  int getCurrentStreak() {
    final progress = _progressRepository.getProgress();
    return progress?.streak ?? 0;
  }

  // ── Game Results ──

  Future<List<GameResultModel>> getRecentResults({int count = 10}) async {
    final results = await _statisticsRepository.getResults();
    return results.take(count).toList();
  }

  Future<GameResultModel?> getLastGameResult() async {
    final results = await _statisticsRepository.getResults();
    return results.isNotEmpty ? results.first : null;
  }

  Future<GameResultModel?> getBestResult() {
    return _statisticsRepository.getBestResult();
  }

  // ── Performance Metrics ──

  Future<double> getAverageScore() async {
    final results = await _statisticsRepository.getResults();
    if (results.isEmpty) return 0.0;
    final totalScore = results.fold<int>(0, (sum, r) => sum + r.score);
    return totalScore / results.length;
  }

  Future<int> getHighestScore() async {
    final results = await _statisticsRepository.getResults();
    if (results.isEmpty) return 0;
    return results.map((r) => r.score).reduce((a, b) => a > b ? a : b);
  }

  Future<int> getLowestScore() async {
    final results = await _statisticsRepository.getResults();
    if (results.isEmpty) return 0;
    return results.map((r) => r.score).reduce((a, b) => a < b ? a : b);
  }

  Future<Duration> getAverageGameDuration() async {
    final results = await _statisticsRepository.getResults();
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

  Future<String> getCurrentPerformanceRating() async {
    return getPerformanceRating(await getOverallAccuracy());
  }

  // ── Progress Over Time ──

  Future<List<GameResultModel>> getResultsByDateRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final results = await _statisticsRepository.getResults();
    return results.where((r) {
      return r.completedTime.isAfter(start) && r.completedTime.isBefore(end);
    }).toList();
  }

  Future<List<GameResultModel>> getTodayResults() async {
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final tomorrow = today.add(const Duration(days: 1));
    return getResultsByDateRange(start: today, end: tomorrow);
  }

  Future<List<GameResultModel>> getThisWeekResults() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDay =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    return getResultsByDateRange(start: weekStartDay, end: now);
  }

  Future<List<GameResultModel>> getThisMonthResults() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return getResultsByDateRange(start: monthStart, end: now);
  }

  // ── Daily Stats ──

  Future<int> getTodayGamesPlayed() async => (await getTodayResults()).length;

  Future<int> getTodayCorrectAnswers() async =>
      (await getTodayResults()).fold<int>(0, (sum, r) => sum + r.correctAnswers);

  Future<int> getTodayWrongAnswers() async =>
      (await getTodayResults()).fold<int>(0, (sum, r) => sum + r.wrongAnswers);

  Future<double> getTodayAccuracy() async {
    final results = await getTodayResults();
    if (results.isEmpty) return 0.0;
    final correct = results.fold<int>(0, (sum, r) => sum + r.correctAnswers);
    final total =
        results.fold<int>(0, (sum, r) => sum + r.correctAnswers + r.wrongAnswers);
    if (total == 0) return 0.0;
    return correct / total;
  }

  Future<int> getTodayEarnedXP() async =>
      (await getTodayResults()).fold<int>(0, (sum, r) => sum + r.earnedXP);

  Future<int> getTodayEarnedCoins() async =>
      (await getTodayResults()).fold<int>(0, (sum, r) => sum + r.earnedCoins);

  // ── Cross-device Sync ──

  /// Sync game progress (XP, coins, level, streak) from Firestore → Hive
  Future<void> syncProgressFromFirestoreToHive(String userId) async {
    await _progressRepository.syncProgressFromFirestoreToHive(userId);
  }

  /// Sync statistics meta (boss wins, daily wins, time played) from Firestore → Hive
  Future<void> syncMetaFromFirestoreToHive(String userId) async {
    await _statisticsRepository.syncMetaFromFirestoreToHive(userId);
  }

  /// Sync game results from Firestore → Hive
  Future<void> syncResultsFromFirestoreToHive(String userId) async {
    await _statisticsRepository.syncFromFirestoreToHive(userId);
  }

  // ── Summary ──

  Future<Map<String, dynamic>> getFullSummary() async {
    // Kick off all async calls in parallel for performance
    final results = await _statisticsRepository.getResults();
    final totalGames = results.length;
    final totalCorrect = results.fold<int>(0, (sum, r) => sum + r.correctAnswers);
    final totalWrong = results.fold<int>(0, (sum, r) => sum + r.wrongAnswers);
    final totalQ = totalCorrect + totalWrong;
    final accuracy = totalQ == 0 ? 0.0 : totalCorrect / totalQ;
    final totalXP = results.fold<int>(0, (sum, r) => sum + r.earnedXP);
    final totalCoins = results.fold<int>(0, (sum, r) => sum + r.earnedCoins);
    final bestAccuracy = results.isEmpty
        ? 0.0
        : results.map((r) => r.accuracy).reduce((a, b) => a > b ? a : b);
    final highestScore = results.isEmpty
        ? 0
        : results.map((r) => r.score).reduce((a, b) => a > b ? a : b);
    final avgScore = results.isEmpty
        ? 0.0
        : results.fold<int>(0, (sum, r) => sum + r.score) / results.length;
    final bestStreak = _streakService.getLongestStreak();
    final currentStreak = _streakService.getCurrentStreak();

    // Coalesce current XP / level / coins from stats, fall back to progress box
    final currentXP = totalXP > 0 ? totalXP : (_progressRepository.getProgress()?.currentXP ?? 0);
    final currentLevel = currentXP > 0 ? (currentXP ~/ 100) + 1 : (_progressRepository.getProgress()?.currentLevel ?? 1);
    final currentCoins = totalCoins > 0 ? totalCoins : (_progressRepository.getProgress()?.totalCoins ?? 0);

    // Time played
    final timePlayedSec = _statisticsRepository.getTimePlayedSeconds();
    final timePlayed = Duration(seconds: timePlayedSec);

    // Performance rating
    String perfRating = 'Needs Practice';
    if (accuracy >= 0.95) perfRating = 'Excellent';
    else if (accuracy >= 0.85) perfRating = 'Great';
    else if (accuracy >= 0.70) perfRating = 'Good';
    else if (accuracy >= 0.50) perfRating = 'Average';

    // Average game duration
    final completed = results.where((r) => r.durationSeconds > 0).toList();
    final avgDuration = completed.isEmpty
        ? Duration.zero
        : Duration(seconds: completed.fold<int>(0, (sum, r) => sum + r.durationSeconds) ~/ completed.length);

    return {
      'totalGamesPlayed': totalGames,
      'totalCorrectAnswers': totalCorrect,
      'totalWrongAnswers': totalWrong,
      'totalQuestionsAnswered': totalQ,
      'overallAccuracy': accuracy,
      'totalEarnedXP': totalXP,
      'totalEarnedCoins': totalCoins,
      'currentXP': currentXP,
      'currentLevel': currentLevel,
      'currentCoins': currentCoins,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'bossWins': _statisticsRepository.getBossWins(),
      'dailyChallengeWins': _statisticsRepository.getDailyChallengeWins(),
      'timePlayedSeconds': timePlayedSec,
      'timePlayedFormatted': formatDuration(timePlayed),
      'bestAccuracy': bestAccuracy,
      'highestScore': highestScore,
      'averageScore': avgScore,
      'averageGameDuration': formatDuration(avgDuration),
      'performanceRating': perfRating,
      'todayGamesPlayed': 0,  // simplified — can be computed if needed
      'todayAccuracy': 0.0,
      'todayEarnedXP': 0,
      'todayEarnedCoins': 0,
    };
  }
}
