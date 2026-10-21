import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_spoken_english_app/features/daily_quiz/models/daily_quiz_model.dart';
import 'package:flutter_spoken_english_app/features/daily_quiz/services/daily_quiz_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Spoken English Daily Quiz Question Bank', () {
    late List<DailyQuizQuestion> questions;

    setUpAll(() {
      final raw = File('assets/json/daily_quiz/questions.json').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final list = decoded['questions'] as List<dynamic>;
      questions = list
          .map((e) => DailyQuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList();
    });

    test('replaces legacy dq_* bank completely with spoken_* practical questions', () {
      expect(questions.length, greaterThanOrEqualTo(200));
      for (final q in questions) {
        expect(q.id.startsWith('spoken_'), isTrue,
            reason: 'Found non-spoken or legacy question ID: ${q.id}');
        expect(q.id.startsWith('dq_'), isFalse);
      }
    });

    test('every question has unique prompt, 4 distinct options, valid answer & explanation', () {
      final ids = <String>{};
      final prompts = <String>{};
      final correctCounts = <int, int>{0: 0, 1: 0, 2: 0, 3: 0};

      for (final q in questions) {
        expect(ids.add(q.id), isTrue, reason: 'Duplicate id: ${q.id}');
        expect(q.question.trim(), isNotEmpty, reason: '${q.id} empty question');
        expect(prompts.add(q.question.trim()), isTrue,
            reason: 'Duplicate question prompt at ${q.id}');
        expect(['conversation', 'vocabulary', 'grammar'], contains(q.type),
            reason: '${q.id} invalid type ${q.type}');
        expect(['easy', 'medium', 'hard'], contains(q.difficulty),
            reason: '${q.id} invalid difficulty ${q.difficulty}');
        expect(q.timeLimit, inInclusiveRange(20, 60));
        expect(q.options.length, 4, reason: '${q.id} must have 4 MCQ options');
        expect(q.options.map((o) => o.trim()).toSet().length, 4,
            reason: '${q.id} has duplicate options');
        expect(q.correctAnswer, inInclusiveRange(0, 3),
            reason: '${q.id} invalid correctAnswer ${q.correctAnswer}');
        expect(q.explanation.trim(), isNotEmpty,
            reason: '${q.id} missing explanation');

        correctCounts[q.correctAnswer] = (correctCounts[q.correctAnswer] ?? 0) + 1;
      }

      // Ensure A/B/C/D answer slots are balanced (~25% each, never skewed)
      for (final slot in [0, 1, 2, 3]) {
        final share = (correctCounts[slot] ?? 0) / questions.length;
        expect(share, inInclusiveRange(0.20, 0.30),
            reason: 'Option index $slot share ($share) is skewed');
      }
    });

    test('invalidates unfinished legacy dq_* cached quiz automatically on upgrade', () async {
      final tempDir = await Directory.systemTemp.createTemp('spoken_dq_upgrade');
      Hive.init(tempDir.path);
      final box = await Hive.openBox<dynamic>('daily_quiz_cache');

      final service = DailyQuizService();
      await service.ensureQuestionBankLoaded();
      final generated = await service.generateTodayQuiz();
      expect(generated.totalQuestions, 10);
      final bankPrompts = questions.map((q) => q.question).toSet();
      expect(
        generated.questions.every((q) => bankPrompts.contains(q.question)),
        isTrue,
      );

      // Simulate an unfinished quiz left behind from the deleted dq_* bank.
      final staleLegacyQuiz = DailyQuiz(
        id: 'dq_${generated.date}',
        date: generated.date,
        seed: 42,
        questions: const [
          DailyQuizQuestion(
            id: 'dq_001',
            type: 'vocabulary',
            question: "What is the meaning of 'Abundant'?",
            options: ['Rare', 'Plentiful', 'Empty', 'Small'],
            correctAnswer: 1,
            explanation: 'Old textbook question',
          ),
        ],
        answers: const [],
        isCompleted: false,
      );
      service.saveQuiz(staleLegacyQuiz, 'test_user_1');
      // Overwrite stored bank hash with old legacy hash to simulate app update.
      await box.put('question_bank_hash', '370:dq_001,dq_002');

      expect(service.loadSavedQuiz('test_user_1'), isNull);

      await Hive.close();
      await tempDir.delete(recursive: true);
    });
  });
}
