import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/daily_quiz_model.dart';

class DailyQuizService {
  static const String _questionsAssetPath =
      'assets/json/daily_quiz/questions.json';
  static const String _hiveBoxName = 'daily_quiz_cache';

  /// Calculate points for a single question.
  int calculatePoints(bool isCorrect, int timeTaken) {
    if (!isCorrect) return 0;
    if (timeTaken <= 10) return 150;
    if (timeTaken <= 20) return 130;
    if (timeTaken <= 30) return 110;
    return 100;
  }

  /// Generate today's quiz deterministically from seed.
  /// Loads the full question bank, splits into vocab/grammar, shuffles each
  /// with seed-based RNG, picks first 5 of each, interleaves.
  Future<DailyQuiz> generateTodayQuiz({int? seed}) async {
    final dateStr = _todayDateString();
    seed ??= _dateSeed(dateStr);
    final rng = Random(seed);

    final allQuestions = await _loadQuestionBank();
    final vocabPool =
        allQuestions.where((q) => q.type == 'vocabulary').toList();
    final grammarPool =
        allQuestions.where((q) => q.type == 'grammar').toList();

    vocabPool.shuffle(rng);
    grammarPool.shuffle(rng);

    final selectedVocab = vocabPool.take(5).toList();
    final selectedGrammar = grammarPool.take(5).toList();

    // Interleave: V, G, V, G, V, G, V, G, V, G
    final questions = <DailyQuizQuestion>[];
    for (int i = 0; i < 5; i++) {
      questions.add(selectedVocab[i]);
      questions.add(selectedGrammar[i]);
    }

    // Assign fresh IDs with date prefix
    final indexedQuestions = questions.asMap().entries.map((e) {
      final idx = e.key;
      final q = e.value;
      return DailyQuizQuestion(
        id: '${dateStr}_q_$idx',
        type: q.type,
        question: q.question,
        options: q.options,
        correctAnswer: q.correctAnswer,
        explanation: q.explanation,
        timeLimit: q.timeLimit,
        difficulty: q.difficulty,
        category: q.category,
      );
    }).toList();

    return DailyQuiz(
      id: 'quiz_$dateStr',
      date: dateStr,
      questions: indexedQuestions,
      seed: seed,
    );
  }

  /// Load all questions from the JSON asset.
  Future<List<DailyQuizQuestion>> _loadQuestionBank() async {
    try {
      final jsonString = await rootBundle.loadString(_questionsAssetPath);
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final questionsList = data['questions'] as List<dynamic>;
      return questionsList
          .map((q) => DailyQuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Failed to load daily quiz questions: $e');
      return [];
    }
  }

  /// Save quiz state to Hive.
  void saveQuiz(DailyQuiz quiz) {
    final box = _hiveBox;
    box.put('current_quiz', quiz.toJson());
  }

  /// Load saved quiz from Hive. Returns null if no quiz or it's from a different day.
  DailyQuiz? loadSavedQuiz() {
    try {
      final box = _hiveBox;
      final data = box.get('current_quiz');
      if (data == null) return null;
      final saved = DailyQuiz.fromJson(data as Map<String, dynamic>);
      if (saved.date != _todayDateString()) return null;
      return saved;
    } catch (_) {
      return null;
    }
  }

  /// Get today's quiz: either load saved (if exists) or generate fresh.
  Future<DailyQuiz> getTodayQuiz() async {
    return loadSavedQuiz() ?? (await generateTodayQuiz());
  }

  /// Complete the quiz: calculate final results, award XP/coins.
  DailyQuiz completeQuiz(DailyQuiz quiz) {
    final scoredAnswers = quiz.answers.map((a) {
      final question = quiz.questions.firstWhere((q) => q.id == a.questionId);
      return DailyQuizAnswer(
        questionId: a.questionId,
        selectedAnswer: a.selectedAnswer,
        isCorrect: a.isCorrect,
        timeTaken: a.timeTaken,
        pointsEarned: calculatePoints(a.isCorrect, a.timeTaken),
      );
    }).toList();

    final correctCount = scoredAnswers.where((a) => a.isCorrect).length;
    final earnedXP = correctCount * 10 +
        (scoredAnswers.length == quiz.totalQuestions ? 20 : 0);
    final earnedCoins = correctCount * 5 +
        (scoredAnswers.length == quiz.totalQuestions ? 10 : 0);

    return quiz.copyWith(
      answers: scoredAnswers,
      isCompleted: true,
      earnedXP: earnedXP,
      earnedCoins: earnedCoins,
      completedAt: DateTime.now(),
    );
  }

  // -- Helpers --

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  int _dateSeed(String dateStr) => dateStr.replaceAll('-', '').hashCode;

  static Box get _hiveBox {
    return Hive.box(_hiveBoxName);
  }
}
