import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/daily_quiz_provider.dart';

class DailyQuizLeaderboardService {
  FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ??= FirebaseFirestore.instance;

  String get _collectionPath => 'daily_quiz_leaderboard';

  // ── Static cache shared across all instances (hub + banner + result + detail)
  // Avoids 3 separate reads for the same date within a few minutes.
  static final Map<String, List<DailyQuizLeaderboardEntry>> _topCache = {};
  static final Map<String, DateTime> _topCacheTime = {};
  static const Duration _cacheTtl = Duration(minutes: 2);

  Future<void> uploadResult({
    required String userId,
    required String userName,
    required String photoUrl,
    required String date,
    required int score,
    required int totalTime,
    required int correctCount,
  }) async {
    await _db.collection(_collectionPath).doc(date).collection('entries').doc(userId).set({
      'userId': userId,
      'userName': userName,
      'photoUrl': photoUrl,
      'score': score,
      'totalTime': totalTime,
      'correctCount': correctCount,
      'completedAt': FieldValue.serverTimestamp(),
    });
    // Invalidate cache for this date so next fetch sees fresh rank
    _topCache.remove(date);
    _topCacheTime.remove(date);
  }

  Future<List<DailyQuizLeaderboardEntry>> fetchTopEntries(String date, {int limit = 10}) async {
    // Cheap in-memory cache — hub preview + champion banner + result reuse same fetch
    final cached = _topCache[date];
    final cachedAt = _topCacheTime[date];
    if (cached != null && cachedAt != null && DateTime.now().difference(cachedAt) < _cacheTtl) {
      if (cached.length >= limit) return cached.take(limit).toList();
      // Cached smaller than requested -> fetch anyway (e.g. preview cached 3, detail wants 50)
      if (limit <= 10 && cached.length >= 3) return cached.take(limit).toList();
    }

    final snapshot = await _db
        .collection(_collectionPath)
        .doc(date)
        .collection('entries')
        .orderBy('score', descending: true)
        .orderBy('totalTime', descending: false)
        .limit(limit)
        .get();

    final entries = snapshot.docs.map((doc) {
      final data = doc.data();
      return DailyQuizLeaderboardEntry(
        userId: data['userId'] as String,
        userName: data['userName'] as String,
        score: data['score'] as int,
        totalTime: data['totalTime'] as int,
        correctCount: data['correctCount'] as int,
        photoUrl: data['photoUrl'] as String?,
      );
    }).toList();

    // Cache the largest fetch for this date
    final existing = _topCache[date];
    if (existing == null || entries.length > existing.length) {
      _topCache[date] = entries;
      _topCacheTime[date] = DateTime.now();
    }
    return entries;
  }

  /// Efficient rank: no longer fetches ALL docs (was 1000 reads).
  /// Uses count aggregation: rank = 1 + #score>myScore + #score==myScore && totalTime<myTime
  Future<int?> getUserRank(String userId, String date) async {
    try {
      final myDoc = await _db.collection(_collectionPath).doc(date).collection('entries').doc(userId).get();
      if (!myDoc.exists || myDoc.data() == null) return null;
      final myScore = myDoc.data()!['score'] as int? ?? 0;
      final myTime = myDoc.data()!['totalTime'] as int? ?? 0;

      // Count players strictly ahead: higher score
      int higher = 0;
      int sameScoreFaster = 0;
      try {
        // Prefer aggregation count (1 index read per 1000, not 1 doc read per player)
        final higherSnap = await _db
            .collection(_collectionPath)
            .doc(date)
            .collection('entries')
            .where('score', isGreaterThan: myScore)
            .count()
            .get();
        higher = higherSnap.count ?? 0;

        final tieSnap = await _db
            .collection(_collectionPath)
            .doc(date)
            .collection('entries')
            .where('score', isEqualTo: myScore)
            .where('totalTime', isLessThan: myTime)
            .count()
            .get();
        sameScoreFaster = tieSnap.count ?? 0;
      } catch (_) {
        // Fallback for older SDK / if count() not available: 2 range queries then size
        final higherDocs = await _db
            .collection(_collectionPath)
            .doc(date)
            .collection('entries')
            .where('score', isGreaterThan: myScore)
            .get();
        higher = higherDocs.size;
        final tieDocs = await _db
            .collection(_collectionPath)
            .doc(date)
            .collection('entries')
            .where('score', isEqualTo: myScore)
            .where('totalTime', isLessThan: myTime)
            .get();
        sameScoreFaster = tieDocs.size;
      }

      return higher + sameScoreFaster + 1;
    } catch (_) {
      // Ultimate fallback: old slow method
      try {
        final snapshot = await _db
            .collection(_collectionPath)
            .doc(date)
            .collection('entries')
            .orderBy('score', descending: true)
            .orderBy('totalTime', descending: false)
            .get();
        final index = snapshot.docs.indexWhere((doc) => doc.id == userId);
        return index >= 0 ? index + 1 : null;
      } catch (_) {
        return null;
      }
    }
  }

  /// For tests / debug: clear in-memory cache
  static void clearCache() {
    _topCache.clear();
    _topCacheTime.clear();
  }
}
