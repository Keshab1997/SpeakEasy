import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_spoken_english_app/features/daily_quiz/models/daily_quiz_model.dart';
import 'package:flutter_spoken_english_app/features/daily_quiz/services/daily_quiz_service.dart';

/// Reproduces the reported bug:
/// "complete the daily quiz → revisit the app → shows 'Start Quiz' instead of
/// 'View Results'".
///
/// Simulates two app sessions sharing the same Hive storage:
///  session 1: generate quiz, answer all questions, complete, save
///  session 2 (fresh service instance = app restart): loadSavedQuiz
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_dq_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('completed quiz is restored as isCompleted=true after restart', () async {
    // Session 1 — user completes today's quiz
    final service = DailyQuizService();
    final box = await Hive.openBox('daily_quiz_cache');

    final quiz = await service.generateTodayQuiz();
    expect(quiz.totalQuestions, greaterThan(0),
        reason: 'question bank must load in test');

    // Answer every question (same flow as the play screen → provider).
    var current = quiz.copyWith(startedAt: DateTime.now());
    for (var i = 0; i < quiz.totalQuestions; i++) {
      final answer = DailyQuizAnswer(
        questionId: current.questions[i].id,
        selectedAnswer: 0,
        isCorrect: true,
        timeTaken: 5,
        pointsEarned: 150,
      );
      current = current.copyWith(answers: [...current.answers, answer]);
    }

    final completed = service.completeQuiz(current);
    expect(completed.isCompleted, isTrue);

    // Persist exactly like DailyQuizNotifier.completeQuiz does.
    service.saveQuiz(completed, 'user1');
    service.saveQuizHistory(completed, 'user1');

    // Sanity: raw Hive payload carries isCompleted=true
    final raw = box.get('user1|current_quiz') as Map;
    expect(raw['isCompleted'], isTrue,
        reason: 'completion must be written to Hive');

    // Session 2 — app restart, brand-new service instance
    final service2 = DailyQuizService();
    await service2.ensureQuestionBankLoaded();
    final restored = service2.loadSavedQuiz('user1');

    debugPrint('RESTORED quiz=${restored == null ? "NULL" : "found"} '
        'isCompleted=${restored?.isCompleted}');

    expect(restored, isNotNull, reason: 'saved quiz must be restored');
    expect(restored!.isCompleted, isTrue,
        reason: 'restored quiz must still be marked completed');
  });

  test('completed quiz survives question-bank change (stale stored hash)',
      () async {
    // Session 1 — user completes today's quiz (hash for the current question
    // bank is stored alongside the quiz).
    final service = DailyQuizService();
    await Hive.openBox('daily_quiz_cache');

    final quiz = await service.generateTodayQuiz();
    var current = quiz.copyWith(startedAt: DateTime.now());
    for (var i = 0; i < quiz.totalQuestions; i++) {
      current = current.copyWith(
        answers: [
          ...current.answers,
          DailyQuizAnswer(
            questionId: current.questions[i].id,
            selectedAnswer: 0,
            isCorrect: true,
            timeTaken: 5,
            pointsEarned: 150,
          ),
        ],
      );
    }
    final completed = service.completeQuiz(current);
    service.saveQuiz(completed, 'user1');
    service.saveQuizHistory(completed, 'user1');

    // Session 2 — app updated / question bank changed: the stored hash no
    // longer matches the current asset. The completed quiz must STILL be
    // restored (its questions are already answered; rewards already granted).
    final box = Hive.box('daily_quiz_cache');
    box.put('question_bank_hash', '0:different_question_bank');

    final service2 = DailyQuizService();
    await service2.ensureQuestionBankLoaded();
    final restored = service2.loadSavedQuiz('user1');

    debugPrint('RESTORED-after-bank-change quiz='
        '${restored == null ? "NULL" : "found"} '
        'isCompleted=${restored?.isCompleted}');

    expect(restored, isNotNull,
        reason: 'completed quiz must not be discarded on hash mismatch');
    expect(restored!.isCompleted, isTrue,
        reason: 'restored quiz must still be marked completed');
  });

  test('QuestionType round-trips through toJson/fromJson', () {
    // Match/rearrange/fill-blank types must survive a Hive save+restore.
    for (final type in QuestionType.values) {
      if (type == QuestionType.multipleChoice) continue;
      final q = DailyQuizQuestion(
        id: 'q1',
        type: 'vocabulary',
        questionType: type,
        question: 'Q',
        options: const [],
        correctAnswer: 0,
        explanation: 'E',
        pairs: type == QuestionType.matchPairs
            ? const [MatchPair(left: 'a', right: 'b')]
            : null,
        jumbledWords: type == QuestionType.sentenceRearrange
            ? const ['I', 'am', 'ok']
            : null,
      );
      final restored = DailyQuizQuestion.fromJson(q.toJson());
      debugPrint('QUESTION TYPE round-trip: ${type.name} -> '
          '${restored.questionType.name}');
      expect(restored.questionType, type,
          reason: '${type.name} must not degrade to multipleChoice');
    }
  });

  test('fresh daily quiz includes new-type questions', () async {
    final service = DailyQuizService();
    final quiz = await service.generateTodayQuiz();
    final special = quiz.questions
        .where((q) => q.questionType != QuestionType.multipleChoice)
        .toList();
    debugPrint('GENERATED ${quiz.totalQuestions} questions, '
        'special=${special.map((q) => q.questionType.name).join(',')}');
    expect(special.length, greaterThanOrEqualTo(2),
        reason: 'every daily quiz must include match/rearrange/fill-blank '
            'questions, not just MCQ');
  });
}
