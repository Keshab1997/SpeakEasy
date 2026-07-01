import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../models/mock_test_model.dart';
import '../repositories/mock_test_repository.dart';

// ── Repository Provider ──

final mockTestRepositoryProvider = Provider<MockTestRepository>((ref) {
  return MockTestRepository();
});

// ── Progress Model ──

class MockTestProgress {
  final Map<int, int> bestScores; // testNumber -> bestScore (0-20)
  final Map<int, bool> unlockedTests; // testNumber -> isUnlocked
  final int highestUnlockedTest; // highest test number that is unlocked

  const MockTestProgress({
    this.bestScores = const {},
    this.unlockedTests = const {},
    this.highestUnlockedTest = 1,
  });

  MockTestProgress copyWith({
    Map<int, int>? bestScores,
    Map<int, bool>? unlockedTests,
    int? highestUnlockedTest,
  }) {
    return MockTestProgress(
      bestScores: bestScores ?? this.bestScores,
      unlockedTests: unlockedTests ?? this.unlockedTests,
      highestUnlockedTest: highestUnlockedTest ?? this.highestUnlockedTest,
    );
  }
}

// ── State ──

class MockTestState {
  final List<MockTestModel> allTests;
  final MockTestProgress progress;
  final bool isLoading;
  final String? error;

  const MockTestState({
    this.allTests = const [],
    this.progress = const MockTestProgress(),
    this.isLoading = false,
    this.error,
  });

  MockTestState copyWith({
    List<MockTestModel>? allTests,
    MockTestProgress? progress,
    bool? isLoading,
    String? error,
  }) {
    return MockTestState(
      allTests: allTests ?? this.allTests,
      progress: progress ?? this.progress,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── Notifier ──

class MockTestNotifier extends StateNotifier<MockTestState> {
  final MockTestRepository _repository;

  MockTestNotifier(this._repository) : super(const MockTestState());

  Future<void> loadTests() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load progress from Hive (synced from Firebase on startup by GameDataSyncService)
      final savedProgress = _repository.getFromHive();
      Map<int, int> bestScores = {};
      Map<int, bool> unlockedTests = {};
      int highestUnlocked = 1;

      if (savedProgress != null) {
        bestScores = Map<int, int>.from(
          (savedProgress['bestScores'] as Map? ?? {})
              .map((k, v) => MapEntry(int.parse(k), v as int)),
        );
        unlockedTests = Map<int, bool>.from(
          (savedProgress['unlockedTests'] as Map? ?? {})
              .map((k, v) => MapEntry(int.parse(k), v as bool)),
        );
        highestUnlocked = savedProgress['highestUnlockedTest'] as int? ?? 1;
      }

      // Test 1 is always unlocked
      unlockedTests[1] = true;

      // Load all 70 test files
      final List<MockTestModel> allTests = [];
      for (int i = 1; i <= 70; i++) {
        final fileName =
            'assets/json/mock_tests/mock_test_${i.toString().padLeft(2, '0')}.json';
        try {
          final raw = await rootBundle.loadString(fileName);
          final json = jsonDecode(raw) as Map<String, dynamic>;
          allTests.add(MockTestModel.fromJson(json));
        } catch (e) {
          // If a file fails to load, create a placeholder
          allTests.add(MockTestModel(
            id: 'mock_test_${i.toString().padLeft(2, '0')}',
            testNumber: i,
            title: 'Mock Test $i',
            description: 'Test content not available.',
          ));
        }
      }

      // Sort by test number
      allTests.sort((a, b) => a.testNumber.compareTo(b.testNumber));

      state = state.copyWith(
        allTests: allTests,
        progress: MockTestProgress(
          bestScores: bestScores,
          unlockedTests: unlockedTests,
          highestUnlockedTest: highestUnlocked,
        ),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load mock tests: $e',
      );
    }
  }

  bool isTestUnlocked(int testNumber) {
    if (testNumber == 1) return true;
    return state.progress.unlockedTests[testNumber] == true;
  }

  bool isTestCompleted(int testNumber) {
    return state.progress.bestScores.containsKey(testNumber);
  }

  int getBestScore(int testNumber) {
    return state.progress.bestScores[testNumber] ?? 0;
  }

  bool isPerfectScore(int testNumber) {
    return getBestScore(testNumber) == 20;
  }

  Future<void> saveResult(int testNumber, int score) async {
    final currentBest = getBestScore(testNumber);
    final newBestScore = score > currentBest ? score : currentBest;

    final newBestScores = Map<int, int>.from(state.progress.bestScores);
    newBestScores[testNumber] = newBestScore;

    // Check if we should unlock the next test
    int newHighestUnlocked = state.progress.highestUnlockedTest;
    final newUnlockedTests = Map<int, bool>.from(state.progress.unlockedTests);

    newUnlockedTests[1] = true; // Test 1 always unlocked

    if (newBestScore == 20 && testNumber < 70) {
      final nextTest = testNumber + 1;
      newUnlockedTests[nextTest] = true;
      if (nextTest > newHighestUnlocked) {
        newHighestUnlocked = nextTest;
      }
    }

    // Ensure sequential unlock: a test is unlocked only if previous has 20/20
    for (int i = 2; i <= 70; i++) {
      if (newBestScores[i - 1] == 20) {
        newUnlockedTests[i] = true;
        if (i > newHighestUnlocked) newHighestUnlocked = i;
      }
    }

    final newProgress = MockTestProgress(
      bestScores: newBestScores,
      unlockedTests: newUnlockedTests,
      highestUnlockedTest: newHighestUnlocked,
    );

    state = state.copyWith(progress: newProgress);

    // Save to Hive (local cache)
    await _repository.saveToHive({
      'bestScores': newBestScores.map((k, v) => MapEntry(k.toString(), v)),
      'unlockedTests': newUnlockedTests.map((k, v) => MapEntry(k.toString(), v)),
      'highestUnlockedTest': newHighestUnlocked,
    });

    // Also save to Firestore if user is logged in
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await _repository.uploadToFirestore(userId, {
        'bestScores': newBestScores.map((k, v) => MapEntry(k.toString(), v)),
        'unlockedTests': newUnlockedTests.map((k, v) => MapEntry(k.toString(), v)),
        'highestUnlockedTest': newHighestUnlocked,
      });
    }
  }

  /// Clear all progress (both Hive and Firestore).
  Future<void> clearProgress() async {
    await _repository.clearHive();

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await _repository.deleteFromFirestore(userId);
    }

    // Reset state to default
    state = state.copyWith(
      progress: const MockTestProgress(),
    );
  }

  int getTotalCompleted() {
    return state.progress.bestScores.length;
  }

  int getTotalPerfectScores() {
    return state.progress.bestScores.values.where((s) => s == 20).length;
  }
}

// ── Providers ──

final mockTestProvider =
    StateNotifierProvider<MockTestNotifier, MockTestState>((ref) {
  final repository = ref.watch(mockTestRepositoryProvider);
  return MockTestNotifier(repository);
});

final mockTestListProvider = Provider<List<MockTestModel>>((ref) {
  return ref.watch(mockTestProvider).allTests;
});

final mockTestProgressProvider = Provider<MockTestProgress>((ref) {
  return ref.watch(mockTestProvider).progress;
});

final isLoadingMockTestsProvider = Provider<bool>((ref) {
  return ref.watch(mockTestProvider).isLoading;
});
