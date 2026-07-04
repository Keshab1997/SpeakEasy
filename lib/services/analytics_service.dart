import 'package:cloud_firestore/cloud_firestore.dart';

/// Data point for daily chart
class AnalyticsDataPoint {
  final DateTime date;
  final int count;

  AnalyticsDataPoint({required this.date, required this.count});
}

/// Module completion stats for pie chart
class ModuleStat {
  final String name;
  final int completedCount;
  final String icon;

  ModuleStat({
    required this.name,
    required this.completedCount,
    required this.icon,
  });
}

/// Streak distribution for bar chart
class StreakDistribution {
  final int activeUsers;
  final int atRiskUsers;
  final int inactiveUsers;

  StreakDistribution({
    required this.activeUsers,
    required this.atRiskUsers,
    required this.inactiveUsers,
  });
}

/// Aggregated analytics data
class AppAnalytics {
  final int totalUsers;
  final int newUsersThisWeek;
  final int todayActiveUsers;
  final int todayLessonsCompleted;
  final List<AnalyticsDataPoint> dailySignups;
  final List<ModuleStat> moduleStats;
  final StreakDistribution streakDistribution;

  AppAnalytics({
    required this.totalUsers,
    required this.newUsersThisWeek,
    required this.todayActiveUsers,
    required this.todayLessonsCompleted,
    required this.dailySignups,
    required this.moduleStats,
    required this.streakDistribution,
  });
}

class AnalyticsService {
  AnalyticsService._();

  static final _firestore = FirebaseFirestore.instance;
  static AppAnalytics? _cached;
  static DateTime _lastFetch = DateTime(2000);

  /// Returns cached analytics if fetched within the last 60 seconds,
  /// otherwise fetches fresh data from Firestore.
  static Future<AppAnalytics> getAnalytics() async {
    if (_cached != null &&
        DateTime.now().difference(_lastFetch).inSeconds < 60) {
      return _cached!;
    }

    final results = await Future.wait([
      getTotalUsers(),
      getNewUsersThisWeek(),
      getTodayActiveUsers(),
      getTodayLessons(),
      getDailySignups(),
      getModuleStats(),
      getStreakDistribution(),
    ]);

    _cached = AppAnalytics(
      totalUsers: results[0] as int,
      newUsersThisWeek: results[1] as int,
      todayActiveUsers: results[2] as int,
      todayLessonsCompleted: results[3] as int,
      dailySignups: results[4] as List<AnalyticsDataPoint>,
      moduleStats: results[5] as List<ModuleStat>,
      streakDistribution: results[6] as StreakDistribution,
    );
    _lastFetch = DateTime.now();
    return _cached!;
  }

  /// 1. Total user count
  static Future<int> getTotalUsers() async {
    final snapshot =
        await _firestore.collection('users').count().get();
    return snapshot.count ?? 0;
  }

  /// 2. New users this week (since Monday 00:00)
  static Future<int> getNewUsersThisWeek() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monday =
        DateTime(weekStart.year, weekStart.month, weekStart.day);

    final snapshot = await _firestore
        .collection('users')
        .where('joinedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monday))
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// 3. Today's active users (lastActiveDate is today)
  static Future<int> getTodayActiveUsers() async {
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('users')
        .where('lastActiveDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('lastActiveDate',
            isLessThan: Timestamp.fromDate(todayEnd))
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// 4. Lessons completed today (from progress collection)
  static Future<int> getTodayLessons() async {
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('progress')
        .where('lastActiveDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('lastActiveDate',
            isLessThan: Timestamp.fromDate(todayEnd))
        .get();

    int total = 0;
    for (final doc in snapshot.docs) {
      final lessons = doc.data()['lessonsCompleted'] as int? ?? 0;
      total += lessons;
    }
    return total;
  }

  /// 5. Daily signups for the last 7 days
  static Future<List<AnalyticsDataPoint>> getDailySignups() async {
    final now = DateTime.now();
    final points = <AnalyticsDataPoint>[];

    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final nextDay = day.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('users')
          .where('joinedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(day))
          .where('joinedAt', isLessThan: Timestamp.fromDate(nextDay))
          .count()
          .get();

      points.add(AnalyticsDataPoint(
        date: day,
        count: snapshot.count ?? 0,
      ));
    }

    return points;
  }

  /// 6. Module completion stats
  static Future<List<ModuleStat>> getModuleStats() async {
    final snapshot = await _firestore
        .collection('progress')
        .limit(5000)
        .get();

    int grammarCount = 0;
    int vocabCount = 0;
    int speakingCount = 0;
    int quizCount = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if ((data['completedLessonIds'] as List?)?.isNotEmpty == true) {
        grammarCount++;
      }
      final totalCoins = data['totalCoins'];
      if (totalCoins is int && totalCoins > 0) {
        quizCount++;
      }
      if (data['speakingScore'] != null &&
          (data['speakingScore'] as int) > 0) {
        speakingCount++;
      }
      if (((data['lessonsCompleted'] as int?) ?? 0) > 0) {
        vocabCount++;
      }
    }

    return [
      ModuleStat(name: 'Grammar', completedCount: grammarCount, icon: '📝'),
      ModuleStat(name: 'Vocabulary', completedCount: vocabCount, icon: '📖'),
      ModuleStat(name: 'Speaking', completedCount: speakingCount, icon: '🎤'),
      ModuleStat(name: 'Quiz', completedCount: quizCount, icon: '🧠'),
    ];
  }

  /// 7. Streak distribution
  static Future<StreakDistribution> getStreakDistribution() async {
    final results = await Future.wait([
      _firestore
          .collection('users')
          .where('streak', isGreaterThanOrEqualTo: 3)
          .count()
          .get(),
      _firestore
          .collection('users')
          .where('streak', isGreaterThanOrEqualTo: 1)
          .where('streak', isLessThan: 3)
          .count()
          .get(),
      _firestore
          .collection('users')
          .where('streak', isEqualTo: 0)
          .count()
          .get(),
    ]);

    return StreakDistribution(
      activeUsers: results[0].count ?? 0,
      atRiskUsers: results[1].count ?? 0,
      inactiveUsers: results[2].count ?? 0,
    );
  }

  /// Force refresh
  static Future<void> refresh() async {
    _cached = null;
    _lastFetch = DateTime(2000);
  }
}