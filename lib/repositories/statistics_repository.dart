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
    final results = getResults();
    results.insert(0, result);
    await box.put(_resultsKey, results.map((r) => r.toMap()).toList());
  }

  List<GameResultModel> getResults() {
    if (!Hive.isBoxOpen(_boxName)) return [];
    final box = Hive.box(_boxName);
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

  int getTotalGamesPlayed() {
    return getResults().length;
  }

  int getTotalCorrectAnswers() {
    return getResults().fold(0, (sum, r) => sum + r.correctAnswers);
  }

  int getTotalWrongAnswers() {
    return getResults().fold(0, (sum, r) => sum + r.wrongAnswers);
  }

  double getOverallAccuracy() {
    final results = getResults();
    if (results.isEmpty) return 0.0;
    final totalCorrect = results.fold(0, (sum, r) => sum + r.correctAnswers);
    final totalQuestions = results.fold(0, (sum, r) => sum + r.correctAnswers + r.wrongAnswers);
    if (totalQuestions == 0) return 0.0;
    return totalCorrect / totalQuestions;
  }

  int getTotalEarnedXP() {
    return getResults().fold(0, (sum, r) => sum + r.earnedXP);
  }

  int getTotalEarnedCoins() {
    return getResults().fold(0, (sum, r) => sum + r.earnedCoins);
  }

  GameResultModel? getBestResult() {
    final results = getResults();
    if (results.isEmpty) return null;
    return results.reduce((a, b) => a.accuracy >= b.accuracy ? a : b);
  }

  // ── Firestore (Remote) ──

  Future<List<GameResultModel>> fetchFromFirestore(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('completedTime', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => GameResultModel.fromMap(doc.data()))
        .toList();
  }

  Future<void> uploadResultToFirestore(String userId, GameResultModel result) async {
    final data = result.toMap();
    data['userId'] = userId;
    await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .add(data);
  }

  // ── Sync ──

  Future<void> syncFromFirestoreToHive(String userId) async {
    final results = await fetchFromFirestore(userId);
    final box = await _ensureBox();
    await box.put(_resultsKey, results.map((r) => r.toMap()).toList());
  }
}