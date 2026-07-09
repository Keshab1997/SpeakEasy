import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/daily_quiz_provider.dart';

class DailyQuizLeaderboardService {
  FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ??= FirebaseFirestore.instance;

  String get _collectionPath => 'daily_quiz_leaderboard';

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
  }

  Future<List<DailyQuizLeaderboardEntry>> fetchTopEntries(String date, {int limit = 10}) async {
    final snapshot = await _db
        .collection(_collectionPath)
        .doc(date)
        .collection('entries')
        .orderBy('score', descending: true)
        .orderBy('totalTime', descending: false)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
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
  }

  Future<int?> getUserRank(String userId, String date) async {
    final snapshot = await _db
        .collection(_collectionPath)
        .doc(date)
        .collection('entries')
        .orderBy('score', descending: true)
        .orderBy('totalTime', descending: false)
        .get();

    final entries = snapshot.docs;
    final index = entries.indexWhere((doc) => doc.id == userId);
    return index >= 0 ? index + 1 : null;
  }
}
