import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game/game_question_model.dart';

class GameRepository {
  static const String _boxName = 'game_cache';
  static const String _questionsKey = 'cached_questions';
  static const String _jsonPath = 'assets/json/game/game_questions.json';
  static const String _firestoreCollection = 'game_questions';

  // ── JSON (Asset) ──

  Future<List<GameQuestionModel>> loadFromJson() async {
    final jsonString = await rootBundle.loadString(_jsonPath);
    final data = json.decode(jsonString) as Map<String, dynamic>;
    final questionsList = data['questions'] as List<dynamic>? ?? [];
    return questionsList
        .map((q) => GameQuestionModel.fromMap(q as Map<String, dynamic>, ''))
        .toList();
  }

  // ── Hive (Local Cache) ──

  Future<Box> _ensureBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  Future<void> cacheQuestions(List<GameQuestionModel> questions) async {
    final box = await _ensureBox();
    final maps = questions.map((q) => q.toMap()).toList();
    await box.put(_questionsKey, maps);
  }

  List<GameQuestionModel> getCachedQuestions() {
    if (!Hive.isBoxOpen(_boxName)) return [];
    final box = Hive.box(_boxName);
    final raw = box.get(_questionsKey, defaultValue: <Map<String, dynamic>>[]) as List;
    return raw
        .map((e) => GameQuestionModel.fromMap(Map<String, dynamic>.from(e as Map), ''))
        .toList();
  }

  Future<void> clearCache() async {
    final box = await _ensureBox();
    await box.delete(_questionsKey);
  }

  // ── Firestore (Remote) ──

  Future<List<GameQuestionModel>> fetchFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .get();
    return snapshot.docs
        .map((doc) => GameQuestionModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> uploadToFirestore(GameQuestionModel question) async {
    await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .doc(question.id)
        .set(question.toMap());
  }

  Future<void> batchUploadToFirestore(List<GameQuestionModel> questions) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final question in questions) {
      final ref = FirebaseFirestore.instance
          .collection(_firestoreCollection)
          .doc(question.id);
      batch.set(ref, question.toMap());
    }
    await batch.commit();
  }

  Future<void> deleteFromFirestore(String questionId) async {
    await FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .doc(questionId)
        .delete();
  }

  // ── Sync (JSON → Hive → Firestore) ──

  Future<void> syncFromJsonToHive() async {
    final questions = await loadFromJson();
    await cacheQuestions(questions);
  }

  Future<void> syncFromFirestoreToHive() async {
    final questions = await fetchFromFirestore();
    await cacheQuestions(questions);
  }
}