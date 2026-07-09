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
  static const String _hiveQuestionBankHashKey = 'question_bank_hash';

  /// Cache of loaded question bank to avoid repeated asset I/O.
  List<DailyQuizQuestion>? _cachedQuestionBank;

  /// Hash of the question bank used to detect stale caches.
  String? _questionBankHash;

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
  /// At least 2 new-type questions (fill_blanks, match_pairs, rearrange)
  /// are guaranteed each day for variety.
  Future<DailyQuiz> generateTodayQuiz({int? seed}) async {
    final dateStr = _todayDateString();
    seed ??= _dateSeed(dateStr);
    final rng = Random(seed);

    final allQuestions = await _loadQuestionBank();

    // Separate into standard MCQ and new-type questions.
    final newType = allQuestions
        .where((q) => q.questionType != QuestionType.multipleChoice)
        .toList();
    final standard =
        allQuestions
            .where((q) => q.questionType == QuestionType.multipleChoice)
            .toList();

    newType.shuffle(rng);
    standard.shuffle(rng);

    final selected = <DailyQuizQuestion>[];

    // Pick 2 new-type questions (if available).
    selected.addAll(newType.take(2));

    // Fill remaining from standard, supporting vocab/grammar/conversation.
    final vocabPool = standard.where((q) => q.type == 'vocabulary').toList();
    final grammarPool = standard.where((q) => q.type == 'grammar').toList();
    final conversationPool =
        standard.where((q) => q.type == 'conversation').toList();

    // Distribute remaining slots proportionally across available types.
    final typePools = <String, List<DailyQuizQuestion>>{
      'vocabulary': vocabPool,
      'grammar': grammarPool,
      if (conversationPool.isNotEmpty) 'conversation': conversationPool,
    };

    // Shuffle each pool.
    for (final pool in typePools.values) {
      pool.shuffle(rng);
    }

    final totalAvailable =
        typePools.values.fold<int>(0, (sum, p) => sum + p.length);
    // Remaining slots to reach 10 (never cap below 10 — e.g. when there are
    // no new-type questions, the full 10 come from the standard pool).
    final slotsRemaining = (10 - selected.length).clamp(0, 10);

    var allocated = 0;
    for (final entry in typePools.entries) {
      if (allocated >= slotsRemaining) break;
      final pool = entry.value;
      final share =
          (pool.length / totalAvailable * slotsRemaining).round().clamp(
                0,
                slotsRemaining - allocated,
              );
      selected.addAll(pool.take(share));
      allocated += share;
    }

    // Safety net: if any slots remain unfilled, top up from any pool.
    if (allocated < slotsRemaining) {
      final allRemaining =
          typePools.values.expand((p) => p).toList()..shuffle(rng);
      selected.addAll(allRemaining.take(slotsRemaining - allocated));
    }

    // Final shuffle so new types aren't always first.
    selected.shuffle(rng);

    // Trim to exactly 10.
    final finalQuestions = selected.take(10).toList();

    // Assign fresh IDs with date prefix
    final indexedQuestions = finalQuestions.asMap().entries.map((e) {
      final idx = e.key;
      final q = e.value;
      return DailyQuizQuestion(
        id: '${dateStr}_q_$idx',
        type: q.type,
        questionType: q.questionType,
        question: q.question,
        options: q.options,
        correctAnswer: q.correctAnswer,
        explanation: q.explanation,
        timeLimit: q.timeLimit,
        difficulty: q.difficulty,
        category: q.category,
        pairs: q.pairs,
        jumbledWords: q.jumbledWords,
      );
    }).toList();

    return DailyQuiz(
      id: 'quiz_$dateStr',
      date: dateStr,
      questions: indexedQuestions,
      seed: seed,
    );
  }

  /// Load all questions from the JSON asset (cached after first call).
  Future<List<DailyQuizQuestion>> _loadQuestionBank() async {
    if (_cachedQuestionBank != null) return _cachedQuestionBank!;
    try {
      final jsonString = await rootBundle.loadString(_questionsAssetPath);
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final questionsList = data['questions'] as List<dynamic>;
      _cachedQuestionBank = questionsList
          .map((q) => DailyQuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList();
      _questionBankHash = _computeHash(_cachedQuestionBank!);
      return _cachedQuestionBank!;
    } catch (e) {
      debugPrint('⚠️ Failed to load daily quiz questions: $e');
      return [];
    }
  }

  /// Ensure the question bank is loaded (for hash comparison before cache reads).
  Future<void> ensureQuestionBankLoaded() => _loadQuestionBank();

  /// Compute a hash from the question bank to detect content changes.
  String _computeHash(List<DailyQuizQuestion> questions) {
    return '${questions.length}:${questions.map((q) => q.id).join(',')}';
  }

  /// Save quiz state to Hive (also stores question bank hash for staleness check).
  ///
  /// The cache is scoped per user so a completed quiz from one account is
  /// never restored for a different logged-in account.
  void saveQuiz(DailyQuiz quiz, String userId) {
    final box = _hiveBox;
    box.put('$userId|current_quiz', quiz.copyWith(userId: userId).toJson());
    if (_questionBankHash != null) {
      box.put(_hiveQuestionBankHashKey, _questionBankHash);
    }
  }

  /// Load saved quiz from Hive for [userId]. Returns null if no quiz, a quiz
  /// belonging to a different user, a different day, or the question bank has
  /// changed since the quiz was cached.
  DailyQuiz? loadSavedQuiz(String userId) {
    try {
      final box = _hiveBox;
      final data = box.get('$userId|current_quiz');
      if (data == null) {
        debugPrint('📅 [DailyQuiz] loadSavedQuiz: no data in Hive '
            '(userId=$userId)');
        return null;
      }
      final saved = DailyQuiz.fromJson(Map<String, dynamic>.from(data));
      // Defensive: ignore a cached quiz that doesn't belong to this user
      // (e.g. a stale global key from a pre-scoped version).
      if (saved.userId != null && saved.userId != userId) {
        debugPrint('📅 [DailyQuiz] loadSavedQuiz: userId mismatch '
            '(saved=${saved.userId}, requested=$userId)');
        return null;
      }
      if (saved.date != _todayDateString()) {
        debugPrint('📅 [DailyQuiz] loadSavedQuiz: stale date '
            '(saved=${saved.date}, today=${_todayDateString()})');
        return null;
      }

      // If we have a cached hash, check it against the stored one.
      if (_questionBankHash != null) {
        final storedHash =
            box.get(_hiveQuestionBankHashKey) as String?;
        if (storedHash != _questionBankHash) {
          debugPrint('📅 [DailyQuiz] loadSavedQuiz: question bank changed, '
              'forcing regeneration');
          return null;
        }
      }

      debugPrint('📅 [DailyQuiz] loadSavedQuiz: loaded '
          '(completed=${saved.isCompleted}, answers=${saved.answers.length})');
      return saved;
    } catch (e) {
      debugPrint('📅 [DailyQuiz] loadSavedQuiz: ERROR $e');
      return null;
    }
  }

  /// Get today's quiz: either load saved (if exists) or generate fresh.
  /// Ensures the question bank is loaded first for hash staleness detection.
  Future<DailyQuiz> getTodayQuiz(String userId) async {
    await ensureQuestionBankLoaded();
    return loadSavedQuiz(userId) ?? (await generateTodayQuiz());
  }

  /// Complete the quiz: calculate final results, award XP/coins.
  DailyQuiz completeQuiz(DailyQuiz quiz) {
    final scoredAnswers = quiz.answers.map((a) {
      // Score is derived purely from the stored answer, so no question lookup
      // is required here. Avoid `firstWhere` on purpose: if an answer ever
      // references a question that is no longer present (e.g. after a
      // question-bank update or a resume across a regenerate) we must NOT
      // throw — otherwise completion would silently fail to persist.
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
