import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game/game_progress_model.dart';
import '../models/game/game_level_model.dart';

class ProgressRepository {
  static const String _boxName = 'game_progress';
  static const String _progressKey = 'user_progress';
  static const String _levelsKey = 'game_levels';
  static const String _jsonPath = 'assets/json/game/game_progress.json';
  static const String _levelsJsonPath = 'assets/json/game/game_levels.json';
  static const String _firestoreCollection = 'game_progress';
  static const String _levelsFirestoreCollection = 'game_levels';

  // ── JSON (Asset) ──

  Future<List<GameProgressModel>> loadProgressFromJson() async {
    final jsonString = await rootBundle.loadString(_jsonPath);
    final data = json.decode(jsonString) as Map<String, dynamic>;
    final progressList = data['progress'] as List<dynamic>? ?? [];
    return progressList
        .map((p) => GameProgressModel.fromMap(p as Map<String, dynamic>, ''))
        .toList();
  }

  Future<List<GameLevelModel>> loadLevelsFromJson() async {
    final jsonString = await rootBundle.loadString(_levelsJsonPath);
    final data = json.decode(jsonString) as Map<String, dynamic>;
    final levelsList = data['levels'] as List<dynamic>? ?? [];
    return levelsList
        .map((l) => GameLevelModel.fromMap(l as Map<String, dynamic>, ''))
        .toList();
  }

  // ── Hive (Local Cache) ──

  Future<Box> _ensureBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  // --- GameProgressModel ---

  Future<void> saveProgress(GameProgressModel progress) async {
    final box = await _ensureBox();
    await box.put(_progressKey, progress.toMap());
  }

  GameProgressModel? getProgress() {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final box = Hive.box(_boxName);
    final raw = box.get(_progressKey);
    if (raw == null) return null;
    return GameProgressModel.fromMap(Map<String, dynamic>.from(raw as Map), '');
  }

  Future<void> addXP(int xp) async {
    var progress = getProgress();
    progress ??= GameProgressModel(userId: '');
    final updated = progress.copyWith(currentXP: progress.currentXP + xp);
    await saveProgress(updated);
  }

  Future<void> addCoins(int coins) async {
    var progress = getProgress();
    progress ??= GameProgressModel(userId: '');
    final updated = progress.copyWith(totalCoins: progress.totalCoins + coins);
    await saveProgress(updated);
  }

  Future<void> incrementStreak() async {
    var progress = getProgress();
    progress ??= GameProgressModel(userId: '');
    final updated = progress.copyWith(streak: progress.streak + 1);
    await saveProgress(updated);
  }

  Future<void> resetStreak() async {
    var progress = getProgress();
    progress ??= GameProgressModel(userId: '');
    final updated = progress.copyWith(streak: 0);
    await saveProgress(updated);
  }

  // ── Weekly Streak ──

  Future<void> incrementWeeklyStreak() async {
    var progress = getProgress();
    progress ??= GameProgressModel(userId: '');
    final updated =
        progress.copyWith(weeklyStreak: progress.weeklyStreak + 1);
    await saveProgress(updated);
  }

  Future<void> resetWeeklyStreak() async {
    var progress = getProgress();
    progress ??= GameProgressModel(userId: '');
    final updated = progress.copyWith(weeklyStreak: 0);
    await saveProgress(updated);
  }

  // ── Longest Streak ──

  Future<void> updateLongestStreak(int currentStreak) async {
    var progress = getProgress();
    progress ??= GameProgressModel(userId: '');
    if (currentStreak > progress.longestStreak) {
      final updated = progress.copyWith(longestStreak: currentStreak);
      await saveProgress(updated);
    }
  }

  // ── Missed Days ──

  Future<void> incrementMissedDays() async {
    var progress = getProgress();
    progress ??= GameProgressModel(userId: '');
    final updated = progress.copyWith(missedDays: progress.missedDays + 1);
    await saveProgress(updated);
  }

  Future<void> resetMissedDays() async {
    var progress = getProgress();
    progress ??= GameProgressModel(userId: '');
    final updated = progress.copyWith(missedDays: 0);
    await saveProgress(updated);
  }

  // ── Total Active Days ──

  Future<void> incrementTotalActiveDays() async {
    var progress = getProgress();
    progress ??= GameProgressModel(userId: '');
    final updated =
        progress.copyWith(totalActiveDays: progress.totalActiveDays + 1);
    await saveProgress(updated);
  }

  // ── Last Active Date ──

  Future<void> updateLastActiveDate(DateTime date) async {
    var progress = getProgress();
    progress ??= GameProgressModel(userId: '');
    final updated = progress.copyWith(lastActiveDate: date);
    await saveProgress(updated);
  }

  // ── Coins ──

  Future<bool> spendCoins(int amount) async {
    var progress = getProgress();
    progress ??= GameProgressModel(userId: '');
    if (progress.totalCoins < amount) return false;
    final updated = progress.copyWith(totalCoins: progress.totalCoins - amount);
    await saveProgress(updated);
    return true;
  }

  Future<void> advanceLevel() async {
    var progress = getProgress();
    progress ??= GameProgressModel(userId: '');
    final updated = progress.copyWith(currentLevel: progress.currentLevel + 1);
    await saveProgress(updated);
  }

  Future<void> unlockMode(String mode) async {
    var progress = getProgress();
    progress ??= GameProgressModel(userId: '');
    if (progress.unlockedModes.contains(mode)) return;
    final updatedModes = List<String>.from(progress.unlockedModes)..add(mode);
    final updated = progress.copyWith(unlockedModes: updatedModes);
    await saveProgress(updated);
  }

  Future<void> clearProgress() async {
    final box = await _ensureBox();
    await box.delete(_progressKey);
  }

  // --- GameLevelModel ---

  Future<void> saveLevels(List<GameLevelModel> levels) async {
    final box = await _ensureBox();
    final maps = levels.map((l) => l.toMap()).toList();
    await box.put(_levelsKey, maps);
  }

  List<GameLevelModel> getLevels() {
    if (!Hive.isBoxOpen(_boxName)) return [];
    final box = Hive.box(_boxName);
    final raw = box.get(_levelsKey, defaultValue: <Map<String, dynamic>>[]) as List;
    return raw
        .map((e) => GameLevelModel.fromMap(Map<String, dynamic>.from(e as Map), ''))
        .toList();
  }

  Future<void> unlockLevel(String levelId) async {
    final levels = getLevels();
    final index = levels.indexWhere((l) => l.id == levelId);
    if (index >= 0) {
      levels[index] = levels[index].copyWith(unlocked: true);
      await saveLevels(levels);
    }
  }

  Future<void> completeLevel(String levelId, int stars) async {
    final levels = getLevels();
    final index = levels.indexWhere((l) => l.id == levelId);
    if (index >= 0) {
      levels[index] = levels[index].copyWith(
        completed: true,
        progress: 1.0,
        totalStars: stars,
      );
      await saveLevels(levels);
    }
  }

  Future<void> updateLevelProgress(String levelId, double progress) async {
    final levels = getLevels();
    final index = levels.indexWhere((l) => l.id == levelId);
    if (index >= 0) {
      levels[index] = levels[index].copyWith(progress: progress);
      await saveLevels(levels);
    }
  }

  Future<void> clearLevels() async {
    final box = await _ensureBox();
    await box.delete(_levelsKey);
  }

  // ── Firestore (Remote) ──

  Future<GameProgressModel?> fetchProgressFromFirestore(String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .doc(userId)
        .get();
    if (!doc.exists) return null;
    return GameProgressModel.fromMap(doc.data()!, doc.id);
  }

  Future<void> uploadProgressToFirestore(GameProgressModel progress) async {
    await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .doc(progress.userId)
        .set(progress.toFirestoreMap()); // Use toFirestoreMap for Firestore
  }

  Future<List<GameLevelModel>> fetchLevelsFromFirestore(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(_levelsFirestoreCollection)
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs
        .map((doc) => GameLevelModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> uploadLevelToFirestore(String userId, GameLevelModel level) async {
    final data = level.toMap();
    data['userId'] = userId;
    await FirebaseFirestore.instance
        .collection(_levelsFirestoreCollection)
        .doc(level.id)
        .set(data);
  }

  Future<void> batchUploadLevelsToFirestore(String userId, List<GameLevelModel> levels) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final level in levels) {
      final ref = FirebaseFirestore.instance
          .collection(_levelsFirestoreCollection)
          .doc(level.id);
      final data = level.toMap();
      data['userId'] = userId;
      batch.set(ref, data);
    }
    await batch.commit();
  }

  // ── Sync ──

  Future<void> syncLevelsFromJsonToHive() async {
    final levels = await loadLevelsFromJson();
    await saveLevels(levels);
  }

  Future<void> syncProgressFromFirestoreToHive(String userId) async {
    final progress = await fetchProgressFromFirestore(userId);
    if (progress != null) {
      await saveProgress(progress);
    }
  }

  Future<void> syncLevelsFromFirestoreToHive(String userId) async {
    final levels = await fetchLevelsFromFirestore(userId);
    await saveLevels(levels);
  }
}