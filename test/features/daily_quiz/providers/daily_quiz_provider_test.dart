import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spoken_english_app/features/daily_quiz/providers/daily_quiz_provider.dart';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DailyQuizLeaderboardEntry', () {
    test('creates entry with correct values', () {
      const entry = DailyQuizLeaderboardEntry(
        userId: 'u1',
        userName: 'Alice',
        score: 1200,
        totalTime: 240,
        correctCount: 8,
      );
      expect(entry.userId, 'u1');
      expect(entry.userName, 'Alice');
      expect(entry.score, 1200);
      expect(entry.totalTime, 240);
      expect(entry.correctCount, 8);
    });
  });

  group('DailyQuizState', () {
    test('default constructor creates correct default state', () {
      const state = DailyQuizState();
      expect(state.quiz, isNull);
      expect(state.currentQuestionIndex, 0);
      expect(state.isPlaying, false);
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.leaderboardRank, isNull);
      expect(state.topEntries, isEmpty);
    });

    test('copyWith updates only specified fields', () {
      const state = DailyQuizState();
      final modified = state.copyWith(
        isLoading: true,
        error: 'test error',
        leaderboardRank: 3,
      );
      expect(modified.isLoading, true);
      expect(modified.error, 'test error');
      expect(modified.leaderboardRank, 3);
      // Unchanged fields keep defaults
      expect(modified.quiz, isNull);
      expect(modified.currentQuestionIndex, 0);
      expect(modified.isPlaying, false);
    });

    test('copyWith clearError works', () {
      final state = DailyQuizState(error: 'some error');
      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('copyWith clearLeaderboardRank works', () {
      final state = DailyQuizState(leaderboardRank: 1);
      final cleared = state.copyWith(clearLeaderboardRank: true);
      expect(cleared.leaderboardRank, isNull);
    });
  });

  group('DailyQuizProvider', () {
    test('provider initializes with default state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(dailyQuizProvider);
      expect(state.isLoading, false);
      expect(state.quiz, isNull);
      expect(state.currentQuestionIndex, 0);
      expect(state.isPlaying, false);
    });
  });
}
