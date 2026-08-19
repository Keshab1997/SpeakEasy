import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/xp_service.dart';

class LeaderboardEntry {
  final String userId;
  final String userName;
  final int score;
  final int xp;
  final int level;
  final int rank;
  final String photoUrl;

  LeaderboardEntry({
    required this.userId,
    required this.userName,
    this.score = 0,
    this.xp = 0,
    this.level = 1,
    this.rank = 0,
    this.photoUrl = '',
  });

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map, {int? rank}) {
    final xp = _asInt(map['xp'] ?? map['currentXP']);
    final storedLevel = _asInt(
      map['level'] ?? map['currentLevel'],
      fallback: 0,
    );
    // Prefer XP-derived level so stale / missing Firestore `level: 1` is not shown.
    final level = XpService.levelFromTotalXP(xp, fallback: storedLevel > 0 ? storedLevel : 1);

    return LeaderboardEntry(
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? map['name'] as String? ?? '',
      score: _asInt(map['score']),
      xp: xp,
      level: level,
      rank: rank ?? _asInt(map['rank']),
      photoUrl: map['photoUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'score': score,
      'xp': xp,
      'level': level,
      'photoUrl': photoUrl,
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
    return _docsToEntries(snapshot.docs);
  }

  /// Real-time stream equivalent of [fetchGlobalLeaderboard].
  /// Emits a new list every time any document in the collection changes.
  Stream<List<LeaderboardEntry>> watchGlobalLeaderboard({int limit = 100}) {
    return FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .orderBy('xp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => _docsToEntries(snapshot.docs));
  }

  /// Converts Firestore QueryDocumentSnapshots to ranked LeaderboardEntries.
  List<LeaderboardEntry> _docsToEntries(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return docs.asMap().entries.map((entry) {
      return LeaderboardEntry.fromMap(
        entry.value.data(),
        rank: entry.key + 1,
      );
    }).toList();
  }

  Future<List<LeaderboardEntry>> fetchWeeklyLeaderboard({int limit = 100}) async {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    // Fetch top users by XP (global), then filter by lastActive on client side.
    // This avoids Firestore's range-filter + orderBy limitation which would sort
    // by lastActive first instead of by XP.
    final snapshot = await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .orderBy('xp', descending: true)
        .limit(limit)
        .get();

    final filteredDocs = snapshot.docs.where((doc) {
      final lastActive = (doc.data()['lastActive'] as Timestamp?)?.toDate();
      return lastActive != null && lastActive.isAfter(weekAgo);
    }).toList();

    return filteredDocs.asMap().entries.map((entry) {
      return LeaderboardEntry.fromMap(
        entry.value.data(),
        rank: entry.key + 1,
      );
    }).toList();
  }

  Future<List<LeaderboardEntry>> fetchDailyLeaderboard({int limit = 100}) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    // Fetch top users by XP (global), then filter by lastActive on client side.
    final snapshot = await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .orderBy('xp', descending: true)
        .limit(limit)
        .get();

    final filteredDocs = snapshot.docs.where((doc) {
      final lastActive = (doc.data()['lastActive'] as Timestamp?)?.toDate();
      return lastActive != null && lastActive.isAfter(today);
    }).toList();

    return filteredDocs.asMap().entries.map((entry) {
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
    String photoUrl = '',
  }) async {
    final resolvedLevel = XpService.levelFromTotalXP(xp, fallback: level);
    await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .doc(userId)
        .set({
      'userId': userId,
      'userName': userName,
      'xp': xp,
      'score': score,
      'level': resolvedLevel,
      'currentLevel': resolvedLevel,
      'photoUrl': photoUrl,
      'lastActive': DateTime.now(),
    }, SetOptions(merge: true));
  }

  // ── Sync ──

  Future<void> syncFromFirestoreToHive({int limit = 100}) async {
    final entries = await fetchGlobalLeaderboard(limit: limit);
    await cacheLeaderboard(entries);
  }
}