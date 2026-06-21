import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game/achievement_model.dart';

class AchievementRepository {
  static const String _boxName = 'game_achievements';
  static const String _achievementsKey = 'unlocked_achievements';
  static const String _jsonPath = 'assets/json/game/game_achievements.json';
  static const String _firestoreCollection = 'game_achievements';

  // ── JSON (Asset) ──

  Future<List<AchievementModel>> loadFromJson() async {
    final jsonString = await rootBundle.loadString(_jsonPath);
    final data = json.decode(jsonString) as Map<String, dynamic>;
    final achievementsList = data['achievements'] as List<dynamic>? ?? [];
    return achievementsList
        .map((a) => AchievementModel.fromMap(a as Map<String, dynamic>, ''))
        .toList();
  }

  // ── Hive (Local Cache) ──

  Future<Box> _ensureBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  Future<void> cacheAchievements(List<AchievementModel> achievements) async {
    final box = await _ensureBox();
    final maps = achievements.map((a) => a.toMap()).toList();
    await box.put(_achievementsKey, maps);
  }

  List<AchievementModel> getCachedAchievements() {
    if (!Hive.isBoxOpen(_boxName)) return [];
    final box = Hive.box(_boxName);
    final raw = box.get(_achievementsKey, defaultValue: <Map<String, dynamic>>[]) as List;
    return raw
        .map((e) => AchievementModel.fromMap(Map<String, dynamic>.from(e as Map), ''))
        .toList();
  }

  Future<AchievementModel?> unlockAchievement(String achievementId) async {
    final achievements = getCachedAchievements();
    final index = achievements.indexWhere((a) => a.id == achievementId);
    if (index >= 0 && !achievements[index].unlocked) {
      achievements[index] = achievements[index].copyWith(
        unlocked: true,
        unlockDate: DateTime.now(),
      );
      await cacheAchievements(achievements);
      return achievements[index];
    }
    return null;
  }

  bool isAchievementUnlocked(String achievementId) {
    final achievements = getCachedAchievements();
    final match = achievements.where((a) => a.id == achievementId);
    return match.isNotEmpty && match.first.unlocked;
  }

  List<AchievementModel> getUnlockedAchievements() {
    return getCachedAchievements().where((a) => a.unlocked).toList();
  }

  List<AchievementModel> getLockedAchievements() {
    return getCachedAchievements().where((a) => !a.unlocked).toList();
  }

  int getUnlockedCount() {
    return getUnlockedAchievements().length;
  }

  Future<void> clearCache() async {
    final box = await _ensureBox();
    await box.delete(_achievementsKey);
  }

  // ── Firestore (Remote) ──

  Future<List<AchievementModel>> fetchFromFirestore(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs
        .map((doc) => AchievementModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> uploadToFirestore(String userId, AchievementModel achievement) async {
    final data = achievement.toMap();
    data['userId'] = userId;
    await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .doc(achievement.id)
        .set(data);
  }

  Future<void> batchUploadToFirestore(String userId, List<AchievementModel> achievements) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final achievement in achievements) {
      final ref = FirebaseFirestore.instance
          .collection(_firestoreCollection)
          .doc(achievement.id);
      final data = achievement.toMap();
      data['userId'] = userId;
      batch.set(ref, data);
    }
    await batch.commit();
  }

  // ── Sync ──

  Future<void> syncFromJsonToHive() async {
    final achievements = await loadFromJson();
    await cacheAchievements(achievements);
  }

  Future<void> syncFromFirestoreToHive(String userId) async {
    final achievements = await fetchFromFirestore(userId);
    await cacheAchievements(achievements);
  }
}