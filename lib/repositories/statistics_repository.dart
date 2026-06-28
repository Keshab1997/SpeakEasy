import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game/game_result_model.dart';

class StatisticsRepository {
  static const String _boxName = 'game_statistics';
  static const String _resultsKey = 'game_results';
  static const String _jsonPath = 'assets/json/game/game_progress.json';
  static const String _firestoreCollection = 'game_statistics';

  // ── Phase 18 meta-counter keys ──
  static const String _bossWinsKey = 'boss_wins';
  static const String _dailyWinsKey = 'daily_challenge_wins';
  static const String _timePlayedKey = 'time_played_seconds';

  // ── JSON (Asset) ──

  Future<List<GameResultModel>> loadFromJson() async {
    final jsonString = await rootBundle.loadString(_jsonPath);
    final data = json.decode(jsonString) as Map<String, dynamic>;
    final resultsList = data['progress'] as List<dynamic>? ?? [];
    return resultsList
        .map((r) => GameResultModel.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  // ── Hive (Local Cache) ──

  Future<Box> _ensureBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  Future<void> saveResult(GameResultModel result) async {
    final box = await _ensureBox();
    final results = await getResults();
    results.insert(0, result);
    await box.put(_resultsKey, results.map((r) => r.toMap()).toList());
  }

  Future<List<GameResultModel>> getResults() async {
    final box = await _ensureBox();
    final raw = box.get(_resultsKey, defaultValue: <Map<String, dynamic>>[]) as List;
    return raw
        .map((e) => GameResultModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> clearResults() async {
    final box = await _ensureBox();
    await box.put(_resultsKey, <Map<String, dynamic>>[]);
  }

  // Computed statistics from Hive

  Future<int> getTotalGamesPlayed() async {
    final results = await getResults();
    return results.length;
  }

  Future<int> getTotalCorrectAnswers() async {
    final results = await getResults();
    return results.fold<int>(0, (sum, r) => sum + r.correctAnswers);
  }

  Future<int> getTotalWrongAnswers() async {
    final results = await getResults();
    return results.fold<int>(0, (sum, r) => sum + r.wrongAnswers);
  }

  Future<double> getOverallAccuracy() async {
    final results = await getResults();
    if (results.isEmpty) return 0.0;
    final totalCorrect = results.fold<int>(0, (sum, r) => sum + r.correctAnswers);
    final totalQuestions =
        results.fold<int>(0, (sum, r) => sum + r.correctAnswers + r.wrongAnswers);
    if (totalQuestions == 0) return 0.0;
    return totalCorrect / totalQuestions;
  }

  Future<int> getTotalEarnedXP() async {
    final results = await getResults();
    return results.fold<int>(0, (sum, r) => sum + r.earnedXP);
  }

  Future<int> getTotalEarnedCoins() async {
    final results = await getResults();
    return results.fold<int>(0, (sum, r) => sum + r.earnedCoins);
  }

  Future<GameResultModel?> getBestResult() async {
    final results = await getResults();
    if (results.isEmpty) return null;
    return results.reduce((a, b) => a.accuracy >= b.accuracy ? a : b);
  }

  // ── Phase 18 counters (persistent meta) ──

  int getBossWins() {
    if (!Hive.isBoxOpen(_boxName)) return 0;
    return Hive.box(_boxName).get(_bossWinsKey, defaultValue: 0) as int;
  }

  Future<void> incrementBossWins() async {
    final box = await _ensureBox();
    final current = getBossWins();
    await box.put(_bossWinsKey, current + 1);
  }

  int getDailyChallengeWins() {
    if (!Hive.isBoxOpen(_boxName)) return 0;
    return Hive.box(_boxName).get(_dailyWinsKey, defaultValue: 0) as int;
  }

  Future<void> incrementDailyChallengeWins() async {
    final box = await _ensureBox();
    final current = getDailyChallengeWins();
    await box.put(_dailyWinsKey, current + 1);
  }

  int getTimePlayedSeconds() {
    if (!Hive.isBoxOpen(_boxName)) return 0;
    return Hive.box(_boxName).get(_timePlayedKey, defaultValue: 0) as int;
  }

  Future<void> addTimePlayed(int seconds) async {
    if (seconds <= 0) return;
    final box = await _ensureBox();
    final current = getTimePlayedSeconds();
    await box.put(_timePlayedKey, current + seconds);
  }

  // ── Firestore (Remote) ──

  Future<List<GameResultModel>> fetchFromFirestore(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .where('userId', isEqualTo: userId)
        .get(); // Remove orderBy to avoid index requirement
    
    // Sort in memory after fetching
    final results = snapshot.docs
        .map((doc) => GameResultModel.fromMap(doc.data()))
        .toList();
    
    results.sort((a, b) => b.completedTime.compareTo(a.completedTime));
    return results;
  }

  Future<void> uploadResultToFirestore(String userId, GameResultModel result) async {
    final data = result.toFirestoreMap();
    data['userId'] = userId;
    await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .add(data);
  }

  Future<void> uploadMetaToFirestore(String userId) async {
    final data = <String, dynamic>{
      'userId': userId,
      'bossWins': getBossWins(),
      'dailyChallengeWins': getDailyChallengeWins(),
      'timePlayedSeconds': getTimePlayedSeconds(),
    };
    await FirebaseFirestore.instance
        .collection('${_firestoreCollection}_meta')
        .doc(userId)
        .set(data, SetOptions(merge: true));
  }

  // ── Sync ──

  Future<void> syncFromFirestoreToHive(String userId) async {
    final results = await fetchFromFirestore(userId);
    final box = await _ensureBox();
    await box.put(_resultsKey, results.map((r) => r.toMap()).toList());
  }

  /// Sync meta counters (boss wins, daily wins, time played) from Firestore → Hive.
  /// This is needed for cross-device sync — when another device writes to Firestore,
  /// this method updates the local Hive values.
  Future<void> syncMetaFromFirestoreToHive(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('${_firestoreCollection}_meta')
          .doc(userId)
          .get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final box = await _ensureBox();
      if (data.containsKey('bossWins')) {
        await box.put(_bossWinsKey, data['bossWins'] as int);
      }
      if (data.containsKey('dailyChallengeWins')) {
        await box.put(_dailyWinsKey, data['dailyChallengeWins'] as int);
      }
      if (data.containsKey('timePlayedSeconds')) {
        await box.put(_timePlayedKey, data['timePlayedSeconds'] as int);
      }
    } catch (e) {
      print('❌ syncMetaFromFirestoreToHive error: $e');
    }
  }
}
