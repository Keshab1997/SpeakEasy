import 'package:hive_flutter/hive_flutter.dart';
import '../models/game/wrong_question_model.dart';

class WrongQuestionRepository {
  static const String _boxName = 'wrong_questions';
  static const String _listKey = 'wrong_questions_list';

  // ── Box access ──

  Future<Box> _ensureBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  // ── Save wrong questions after a game round ──

  Future<void> saveWrongQuestions(List<WrongQuestionModel> wrongs) async {
    if (wrongs.isEmpty) return;

    final box = await _ensureBox();
    final existing = getAllWrongQuestions();

    // Merge: update existing entries by id, add new ones
    final Map<String, WrongQuestionModel> merged = {
      for (final w in existing) w.id: w,
    };
    for (final w in wrongs) {
      if (merged.containsKey(w.id)) {
        // Already exists — update userAnswer and savedAt (latest mistake)
        merged[w.id] = merged[w.id]!.copyWith(
          userAnswer: w.userAnswer,
          savedAt: w.savedAt,
        );
      } else {
        merged[w.id] = w;
      }
    }

    final maps = merged.values.map((w) => w.toMap()).toList();
    await box.put(_listKey, maps);
  }

  // ── Read ──

  List<WrongQuestionModel> getAllWrongQuestions() {
    if (!Hive.isBoxOpen(_boxName)) return [];
    final box = Hive.box(_boxName);
    final raw = box.get(_listKey, defaultValue: <Map<String, dynamic>>[]) as List;
    return raw
        .map((e) => WrongQuestionModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Questions saved on a specific date (YYYY-MM-DD).
  List<WrongQuestionModel> getWrongQuestionsByDate(String date) {
    return getAllWrongQuestions()
        .where((w) => w.savedAt.startsWith(date))
        .toList();
  }

  /// Questions of a specific tense type.
  List<WrongQuestionModel> getWrongQuestionsByTense(String tenseType) {
    return getAllWrongQuestions()
        .where((w) => w.tenseType == tenseType)
        .toList();
  }

  /// Get most recent wrong questions (sorted by savedAt timestamp)
  List<WrongQuestionModel> getRecentWrongQuestions({int limit = 50}) {
    final all = getAllWrongQuestions();
    // Sort by savedAt descending (newest first)
    all.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return all.take(limit).toList();
  }

  // ── Review tracking ──

  Future<void> markAsReviewed(String questionId) async {
    final box = await _ensureBox();
    final all = getAllWrongQuestions();
    final updated = all.map((w) {
      if (w.id == questionId) return w.incrementReview();
      return w;
    }).toList();
    final maps = updated.map((w) => w.toMap()).toList();
    await box.put(_listKey, maps);
  }

  // ── Remove ──

  Future<void> removeWrongQuestion(String questionId) async {
    final box = await _ensureBox();
    final all = getAllWrongQuestions();
    final filtered = all.where((w) => w.id != questionId).toList();
    final maps = filtered.map((w) => w.toMap()).toList();
    await box.put(_listKey, maps);
  }

  Future<void> clearAll() async {
    final box = await _ensureBox();
    await box.delete(_listKey);
  }

  // ── Stats ──

  int get totalCount => getAllWrongQuestions().length;

  int get uniqueTenseCount =>
      getAllWrongQuestions().map((w) => w.tenseType).toSet().length;
}
