import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_spoken_english_app/features/daily_quiz/models/daily_quiz_model.dart';

void main() {
  group('DailyQuizQuestion', () {
    test('toJson / fromJson round-trips correctly', () {
      final question = DailyQuizQuestion(
        id: 'dq_v_001',
        type: 'vocabulary',
        question: 'What meaning Eloquent?',
        options: ['A', 'B', 'C', 'D'],
        correctAnswer: 0,
        explanation: 'Eloquent means fluent.',
        timeLimit: 30,
        difficulty: 'medium',
        category: 'general',
      );
      final json = question.toJson();
      final restored = DailyQuizQuestion.fromJson(json);
      expect(restored.id, question.id);
      expect(restored.type, question.type);
      expect(restored.question, question.question);
      expect(restored.options, question.options);
      expect(restored.correctAnswer, question.correctAnswer);
      expect(restored.explanation, question.explanation);
      expect(restored.timeLimit, question.timeLimit);
      expect(restored.difficulty, question.difficulty);
      expect(restored.category, question.category);
    });

    test('uses default values when JSON fields missing', () {
      final json = {'id': 'dq_v_002', 'type': 'grammar', 'question': 'Q?', 'options': ['A','B','C','D'], 'correctAnswer': 2, 'explanation': 'E'};
      final restored = DailyQuizQuestion.fromJson(json);
      expect(restored.timeLimit, 30);
      expect(restored.difficulty, 'medium');
      expect(restored.category, 'general');
    });
  });

  group('DailyQuizAnswer', () {
    test('toJson / fromJson round-trips correctly', () {
      final answer = DailyQuizAnswer(
        questionId: 'dq_v_001',
        selectedAnswer: 2,
        isCorrect: true,
        timeTaken: 8,
        pointsEarned: 150,
      );
      final json = answer.toJson();
      final restored = DailyQuizAnswer.fromJson(json);
      expect(restored.questionId, answer.questionId);
      expect(restored.selectedAnswer, answer.selectedAnswer);
      expect(restored.isCorrect, answer.isCorrect);
      expect(restored.timeTaken, answer.timeTaken);
      expect(restored.pointsEarned, answer.pointsEarned);
    });

    test('supports null selectedAnswer (timeout)', () {
      final answer = DailyQuizAnswer(
        questionId: 'dq_v_001',
        selectedAnswer: null,
        isCorrect: false,
        timeTaken: 30,
        pointsEarned: 0,
      );
      final json = answer.toJson();
      final restored = DailyQuizAnswer.fromJson(json);
      expect(restored.selectedAnswer, isNull);
      expect(restored.isCorrect, false);
      expect(restored.timeTaken, 30);
      expect(restored.pointsEarned, 0);
    });
  });

  group('DailyQuiz', () {
    test('toJson / fromJson round-trips with all fields', () {
      final questions = [
        DailyQuizQuestion(
          id: 'dq_v_001', type: 'vocabulary',
          question: 'Q1', options: ['A','B','C','D'],
          correctAnswer: 0, explanation: 'E1',
          timeLimit: 30, difficulty: 'easy', category: 'general',
        ),
        DailyQuizQuestion(
          id: 'dq_g_001', type: 'grammar',
          question: 'Q2', options: ['A','B','C','D'],
          correctAnswer: 1, explanation: 'E2',
          timeLimit: 30, difficulty: 'easy', category: 'present',
        ),
      ];
      final answers = [
        DailyQuizAnswer(questionId: 'dq_v_001', selectedAnswer: 0, isCorrect: true, timeTaken: 5, pointsEarned: 150),
        DailyQuizAnswer(questionId: 'dq_g_001', selectedAnswer: null, isCorrect: false, timeTaken: 30, pointsEarned: 0),
      ];
      final quiz = DailyQuiz(
        id: 'quiz_2026-07-08',
        date: '2026-07-08',
        questions: questions,
        answers: answers,
        seed: 20260708,
        startedAt: DateTime(2026, 7, 8, 6, 0, 0),
        completedAt: DateTime(2026, 7, 8, 6, 5, 30),
      );
      final json = quiz.toJson();
      final restored = DailyQuiz.fromJson(json);
      expect(restored.id, quiz.id);
      expect(restored.date, quiz.date);
      expect(restored.seed, quiz.seed);
      expect(restored.questions.length, 2);
      expect(restored.answers.length, 2);
      expect(restored.correctCount, 1);
      expect(restored.wrongCount, 1);
      expect(restored.score, 150);
      expect(restored.totalTime, 35);
      expect(restored.totalQuestions, 2);
      expect(restored.answeredCount, 2);
      expect(restored.isCompleted, false);
      expect(restored.earnedXP, 0);
      expect(restored.earnedCoins, 0);
      expect(restored.startedAt, isNotNull);
      expect(restored.completedAt, isNotNull);
    });

    test('computed properties work on empty quiz', () {
      final quiz = DailyQuiz(id: 'quiz_2026-07-08', date: '2026-07-08', seed: 20260708);
      expect(quiz.correctCount, 0);
      expect(quiz.wrongCount, 0);
      expect(quiz.score, 0);
      expect(quiz.totalTime, 0);
      expect(quiz.totalQuestions, 0);
      expect(quiz.answeredCount, 0);
      expect(quiz.isCompleted, false);
    });

    test('isCompleted true when all questions answered', () {
      final questions = [
        DailyQuizQuestion(id: 'q1', type: 'vocabulary', question: 'Q1', options: ['A','B','C','D'], correctAnswer: 0, explanation: 'E'),
        DailyQuizQuestion(id: 'q2', type: 'grammar', question: 'Q2', options: ['A','B','C','D'], correctAnswer: 1, explanation: 'E'),
      ];
      final answers = [
        DailyQuizAnswer(questionId: 'q1', selectedAnswer: 0, isCorrect: true, timeTaken: 5, pointsEarned: 150),
        DailyQuizAnswer(questionId: 'q2', selectedAnswer: 1, isCorrect: true, timeTaken: 8, pointsEarned: 150),
      ];
      final quiz = DailyQuiz(
        id: 'quiz_test', date: '2026-07-08',
        questions: questions, answers: answers,
        isCompleted: true, earnedXP: 20, earnedCoins: 10,
        seed: 123,
      );
      expect(quiz.isCompleted, true);
      expect(quiz.earnedXP, 20);
      expect(quiz.earnedCoins, 10);
      expect(quiz.score, 300);
    });
  });
}
