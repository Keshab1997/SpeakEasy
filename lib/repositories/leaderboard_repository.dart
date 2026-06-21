import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardEntry {
  final String userId;
  final String userName;
  final int score;
  final int xp;
  final int level;
  final int rank;

  LeaderboardEntry({
    required this.userId,
    required this.userName,
    this.score = 0,
    this.xp = 0,
    this.level = 1,
    this.rank = 0,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map, {int? rank}) {
    return LeaderboardEntry(
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      score: map['score'] as int? ?? 0,
      xp: map['xp'] as int? ?? 0,
      level: map['level'] as int? ?? 1,
      rank: rank ?? map['rank'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'score': score,
      'xp': xp,
      'level': level,
    };
  }
}

class LeaderboardRepository {
  static const String _boxName = 'game_leaderboard';
  static const String _cacheKey = 'leaderboard_cache';
  static const String _firestoreCollection = 'leaderboard';

  // ── Hive (Local Cache) ──

  Future<Box> _ensureBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  Future<void> cacheLeaderboard(List<LeaderboardEntry> entries) async {
    final box = await _ensureBox();
    final maps = entries.map((e) => e.toMap()).toList();
    await box.put(_cacheKey, maps);
  }

  List<LeaderboardEntry> getCachedLeaderboard() {
    if (!Hive.isBoxOpen(_boxName)) return [];
    final box = Hive.box(_boxName);
    final raw = box.get(_cacheKey, defaultValue: <Map<String, dynamic>>[]) as List;
    final entries = raw
        .map((e) => LeaderboardEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    for (int i = 0; i < entries.length; i++) {
      entries[i] = LeaderboardEntry.fromMap(entries[i].toMap(), rank: i + 1);
    }
    return entries;
  }

  Future<void> clearCache() async {
    final box = await _ensureBox();
    await box.delete(_cacheKey);
  }

  // ── Firestore (Remote) ──

  Future<List<LeaderboardEntry>> fetchGlobalLeaderboard({int limit = 100}) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .orderBy('xp', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.asMap().entries.map((entry) {
      return LeaderboardEntry.fromMap(
        entry.value.data(),
        rank: entry.key + 1,
      );
    }).toList();
  }

  Future<List<LeaderboardEntry>> fetchWeeklyLeaderboard({int limit = 100}) async {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final snapshot = await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .where('lastActive', isGreaterThan: weekAgo)
        .orderBy('lastActive', descending: false)
        .orderBy('xp', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.asMap().entries.map((entry) {
      return LeaderboardEntry.fromMap(
        entry.value.data(),
        rank: entry.key + 1,
      );
    }).toList();
  }

  Future<List<LeaderboardEntry>> fetchDailyLeaderboard({int limit = 100}) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final snapshot = await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .where('lastActive', isGreaterThan: today)
        .orderBy('lastActive', descending: false)
        .orderBy('xp', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.asMap().entries.map((entry) {
      return LeaderboardEntry.fromMap(
        entry.value.data(),
        rank: entry.key + 1,
      );
    }).toList();
  }

  Future<LeaderboardEntry?> fetchUserRank(String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .doc(userId)
        .get();
    if (!doc.exists) return null;

    final userXp = doc.data()!['xp'] as int? ?? 0;

    final rankSnapshot = await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .where('xp', isGreaterThan: userXp)
        .count()
        .get();

    final rank = rankSnapshot.count! + 1;

    return LeaderboardEntry.fromMap(doc.data()!, rank: rank);
  }

  Future<void> updateUserStats({
    required String userId,
    required String userName,
    required int xp,
    required int score,
    required int level,
  }) async {
    await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .doc(userId)
        .set({
      'userId': userId,
      'userName': userName,
      'xp': xp,
      'score': score,
      'level': level,
      'lastActive': DateTime.now(),
    });
  }

  // ── Sync ──

  Future<void> syncFromFirestoreToHive({int limit = 100}) async {
    final entries = await fetchGlobalLeaderboard(limit: limit);
    await cacheLeaderboard(entries);
  }
}