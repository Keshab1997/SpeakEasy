import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_spoken_english_app/features/daily_quiz/models/daily_quiz_model.dart';
import 'package:flutter_spoken_english_app/features/daily_quiz/services/daily_quiz_service.dart';

void main() {
  late DailyQuizService service;

  setUp(() {
    service = DailyQuizService();
  });

  group('calculatePoints', () {
    test('returns 150 for correct answer under 10s', () {
      expect(service.calculatePoints(true, 8), 150);
    });

    test('returns 130 for correct answer 10-20s', () {
      expect(service.calculatePoints(true, 15), 130);
    });

    test('returns 110 for correct answer 20-30s', () {
      expect(service.calculatePoints(true, 25), 110);
    });

    test('returns 0 for wrong answer regardless of time', () {
      expect(service.calculatePoints(false, 5), 0);
      expect(service.calculatePoints(false, 15), 0);
      expect(service.calculatePoints(false, 30), 0);
    });
  });

  group('completeQuiz', () {
    test('calculates points correctly for all correct answers', () {
      final questions = List.generate(10, (i) => DailyQuizQuestion(
        id: 'q$i', type: i.isEven ? 'vocabulary' : 'grammar',
        question: 'Q$i', options: ['A','B','C','D'],
        correctAnswer: 0, explanation: 'E',
      ));
      final answers = questions.map((q) => DailyQuizAnswer(
        questionId: q.id, selectedAnswer: 0, isCorrect: true, timeTaken: 5, pointsEarned: 0,
      )).toList();
      final quiz = DailyQuiz(id: 'quiz_test', date: '2026-07-08', questions: questions, answers: answers, seed: 123);

      final completed = service.completeQuiz(quiz);
      expect(completed.isCompleted, true);
      expect(completed.score, 10 * 150); // 1500
      expect(completed.earnedXP, 10 * 10 + 20); // 120
      expect(completed.earnedCoins, 10 * 5 + 10); // 60
    });

    test('calculates points correctly for partial correct answers', () {
      final questions = List.generate(4, (i) => DailyQuizQuestion(
        id: 'q$i', type: 'vocabulary',
        question: 'Q$i', options: ['A','B','C','D'],
        correctAnswer: 0, explanation: 'E',
      ));
      final answers = [
        DailyQuizAnswer(questionId: 'q0', selectedAnswer: 0, isCorrect: true, timeTaken: 8, pointsEarned: 0),
        DailyQuizAnswer(questionId: 'q1', selectedAnswer: 1, isCorrect: false, timeTaken: 15, pointsEarned: 0),
        DailyQuizAnswer(questionId: 'q2', selectedAnswer: 0, isCorrect: true, timeTaken: 25, pointsEarned: 0),
        DailyQuizAnswer(questionId: 'q3', selectedAnswer: 0, isCorrect: true, timeTaken: 30, pointsEarned: 0),
      ];
      final quiz = DailyQuiz(id: 'quiz_test', date: '2026-07-08', questions: questions, answers: answers, seed: 123);

      final completed = service.completeQuiz(quiz);
      expect(completed.isCompleted, true);
      expect(completed.score, 150 + 0 + 110 + 110); // 370
      expect(completed.earnedXP, 3 * 10 + 20); // 50 (3 correct + completion bonus)
      expect(completed.earnedCoins, 3 * 5 + 10); // 25
    });

    test('handles timeout answers (null selectedAnswer)', () {
      final questions = [DailyQuizQuestion(
        id: 'q0', type: 'vocabulary',
        question: 'Q', options: ['A','B','C','D'],
        correctAnswer: 0, explanation: 'E',
      )];
      final answers = [DailyQuizAnswer(
        questionId: 'q0', selectedAnswer: null, isCorrect: false, timeTaken: 30, pointsEarned: 0,
      )];
      final quiz = DailyQuiz(id: 'quiz_test', date: '2026-07-08', questions: questions, answers: answers, seed: 123);

      final completed = service.completeQuiz(quiz);
      expect(completed.score, 0);
      // Completion bonus awarded for answering all questions (even if wrong)
      expect(completed.earnedXP, 20); // 0 correct * 10 + 20 completion bonus
      expect(completed.earnedCoins, 10); // 0 correct * 5 + 10 completion bonus
    });
  });
}
