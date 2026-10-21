import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_spoken_english_app/features/daily_quiz/models/daily_quiz_model.dart';
import 'package:flutter_spoken_english_app/features/daily_quiz/providers/daily_quiz_provider.dart';
import 'package:flutter_spoken_english_app/features/daily_quiz/screens/daily_quiz_screen.dart';
import 'package:flutter_spoken_english_app/features/daily_quiz/services/daily_quiz_leaderboard_service.dart';
import 'package:flutter_spoken_english_app/features/daily_quiz/services/daily_quiz_service.dart';

class _FakeLeaderboardService extends DailyQuizLeaderboardService {
  final Map<String, List<DailyQuizLeaderboardEntry>> entriesByDate;
  int uploadCalls = 0;

  _FakeLeaderboardService(this.entriesByDate);

  @override
  Future<void> uploadResult({
    required String userId,
    required String userName,
    required String photoUrl,
    required String date,
    required int score,
    required int totalTime,
    required int correctCount,
  }) async {
    uploadCalls++;
  }

  @override
  Future<List<DailyQuizLeaderboardEntry>> fetchTopEntries(
    String date, {
    int limit = 10,
  }) async {
    return (entriesByDate[date] ?? const []).take(limit).toList();
  }

  @override
  Future<int?> getUserRank(String userId, String date) async => null;
}

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dq_results_first_test');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>('daily_quiz_cache');
    await Hive.openBox<dynamic>('streak_box');
    await Hive.openBox<dynamic>('settings');
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets(
      'visiting DailyQuizScreen immediately displays live results before taking quiz',
      (tester) async {
    final today = _fmtDate(DateTime.now());
    final fakeLeaderboard = _FakeLeaderboardService({
      today: const [
        DailyQuizLeaderboardEntry(
          userId: 'u1',
          userName: 'Ananya Sen',
          score: 1420,
          totalTime: 44,
          correctCount: 10,
        ),
        DailyQuizLeaderboardEntry(
          userId: 'u2',
          userName: 'Rohan Das',
          score: 1290,
          totalTime: 58,
          correctCount: 9,
        ),
        DailyQuizLeaderboardEntry(
          userId: 'u3',
          userName: 'Sohini Roy',
          score: 1180,
          totalTime: 65,
          correctCount: 9,
        ),
      ],
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyQuizProvider.overrideWith(
            (ref) => DailyQuizNotifier(
              DailyQuizService(),
              fakeLeaderboard,
              ref,
            ),
          ),
        ],
        child: const MaterialApp(
          home: DailyQuizScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Results are immediately visible right upon opening Daily Quiz — NOT gated!
    expect(find.text("Today's Live Results"), findsOneWidget);
    expect(find.text('Ananya Sen'), findsOneWidget);
    expect(find.text('1420 pts'), findsOneWidget);
    expect(find.text('Rohan Das'), findsOneWidget);
    expect(find.text('Sohini Roy'), findsOneWidget);
    expect(find.text('Complete the quiz to see the leaderboard'), findsNothing);
    expect(
      find.textContaining('Can you beat Ananya Sen (1420 pts)?'),
      findsOneWidget,
    );
    expect(find.text('Start Quiz Now · Claim Your Rank!'), findsOneWidget);

    // Must NEVER upload a 0-score result merely by viewing Daily Quiz.
    expect(fakeLeaderboard.uploadCalls, 0);
  });

  testWidgets(
      'falls back to yesterday final results early morning when today board is empty',
      (tester) async {
    final yesterday = _fmtDate(DateTime.now().subtract(const Duration(days: 1)));
    final fakeLeaderboard = _FakeLeaderboardService({
      yesterday: const [
        DailyQuizLeaderboardEntry(
          userId: 'u9',
          userName: 'Pritam Ghosh',
          score: 1360,
          totalTime: 51,
          correctCount: 10,
        ),
      ],
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyQuizProvider.overrideWith(
            (ref) => DailyQuizNotifier(
              DailyQuizService(),
              fakeLeaderboard,
              ref,
            ),
          ),
        ],
        child: const MaterialApp(
          home: DailyQuizScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Yesterday's Final Results"), findsOneWidget);
    expect(find.text('Pritam Ghosh'), findsOneWidget);
    expect(find.text('1360 pts'), findsOneWidget);
    expect(fakeLeaderboard.uploadCalls, 0);
  });

  test('weak sentences bank persists missed questions and removes mastered ones',
      () {
    final service = DailyQuizService();
    const quiz = DailyQuiz(
      id: 'quiz_2026-10-21',
      date: '2026-10-21',
      seed: 101,
      questions: [
        DailyQuizQuestion(
          id: 'q1',
          type: 'conversation',
          question: 'Phone network weak situation?',
          options: ['Cut phone', 'Your voice is breaking up.', 'Shout', 'Bye'],
          correctAnswer: 1,
          explanation: 'Natural spoken English phrase.',
        ),
        DailyQuizQuestion(
          id: 'q2',
          type: 'vocabulary',
          question: 'Running late situation?',
          options: ['I am on my way.', 'Walking street', 'Leg coming', 'Wait'],
          correctAnswer: 0,
          explanation: 'Everyday phrase.',
        ),
        DailyQuizQuestion(
          id: 'q3',
          type: 'grammar',
          question: 'Past negative situation?',
          options: ['I did not went.', 'I didn\'t go.', 'Not went.', 'Went no.'],
          correctAnswer: 1,
          explanation: 'Use base verb after didn\'t.',
        ),
      ],
    );

    // Q1 wrong, Q2 correct, Q3 unanswered (missed/timeout) -> 2 weak items saved.
    final completed = service.completeQuiz(
      quiz.copyWith(
        answers: const [
          DailyQuizAnswer(
            questionId: 'q1',
            selectedAnswer: 0,
            isCorrect: false,
            timeTaken: 12,
            pointsEarned: 0,
          ),
          DailyQuizAnswer(
            questionId: 'q2',
            selectedAnswer: 0,
            isCorrect: true,
            timeTaken: 8,
            pointsEarned: 150,
          ),
        ],
      ),
    );

    service.saveWeakQuestionsFromQuiz(completed, 'learner_1');
    final savedWeak = service.loadWeakQuestions('learner_1');
    expect(savedWeak.length, 2);
    expect(savedWeak.any((q) => q.id == 'q2'), isFalse);

    final afterMastered = service.removeWeakQuestion(
      'learner_1',
      'Phone network weak situation?',
    );
    expect(afterMastered.length, 1);
    expect(afterMastered.single.id, 'q3');
  });
}
