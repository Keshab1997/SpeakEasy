import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../models/mock_test_model.dart';
import '../repositories/mock_test_repository.dart';
import '../repositories/progress_repository.dart';
import '../services/coin_service.dart';

// ── Repository Provider ──

final mockTestRepositoryProvider = Provider<MockTestRepository>((ref) {
  return MockTestRepository();
});

// ── Progress Model ──

class MockTestProgress {
  final Map<int, int> bestScores; // testNumber -> bestScore (0-20)
  final Map<int, bool> unlockedTests; // testNumber -> permanently unlocked via coins
  final int highestUnlockedTest; // highest test number that is unlocked
  final Map<int, List<int>> wrongQuestions; // testNumber -> list of wrong question indices
  final Map<int, DateTime> adUnlockedTests; // testNumber -> expiry DateTime (ad unlock)

  const MockTestProgress({
    this.bestScores = const {},
    this.unlockedTests = const {},
    this.highestUnlockedTest = 1,
    this.wrongQuestions = const {},
    this.adUnlockedTests = const {},
  });

  MockTestProgress copyWith({
    Map<int, int>? bestScores,
    Map<int, bool>? unlockedTests,
    int? highestUnlockedTest,
    Map<int, List<int>>? wrongQuestions,
    Map<int, DateTime>? adUnlockedTests,
  }) {
    return MockTestProgress(
      bestScores: bestScores ?? this.bestScores,
      unlockedTests: unlockedTests ?? this.unlockedTests,
      highestUnlockedTest: highestUnlockedTest ?? this.highestUnlockedTest,
      wrongQuestions: wrongQuestions ?? this.wrongQuestions,
      adUnlockedTests: adUnlockedTests ?? this.adUnlockedTests,
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
      Map<int, List<int>> wrongQuestions = {};
      Map<int, DateTime> adUnlockedTests = {};

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
        wrongQuestions = Map<int, List<int>>.from(
          (savedProgress['wrongQuestions'] as Map? ?? {})
              .map((k, v) => MapEntry(int.parse(k), List<int>.from(v as List? ?? []))),
        );
        // Parse ad-unlocked tests with expiry
        final rawAdUnlocks = savedProgress['adUnlockedTests'] as Map? ?? {};
        adUnlockedTests = Map<int, DateTime>.from(
          rawAdUnlocks.map((k, v) {
            final expiry = DateTime.tryParse(v as String? ?? '');
            return MapEntry(int.parse(k), expiry ?? DateTime.now().subtract(const Duration(days: 1)));
          }),
        );
      }

      // Test 1 is always unlocked
      unlockedTests[1] = true;

      // Remove expired ad unlocks
      final now = DateTime.now();
      adUnlockedTests.removeWhere((_, expiry) => now.isAfter(expiry));

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
          wrongQuestions: wrongQuestions,
          adUnlockedTests: adUnlockedTests,
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
    // Check permanent coin unlock
    if (state.progress.unlockedTests[testNumber] == true) return true;
    // Check temporary ad unlock (with expiry)
    final adExpiry = state.progress.adUnlockedTests[testNumber];
    if (adExpiry != null && DateTime.now().isBefore(adExpiry)) return true;
    return false;
  }

  bool isAdUnlocked(int testNumber) {
    final adExpiry = state.progress.adUnlockedTests[testNumber];
    return adExpiry != null && DateTime.now().isBefore(adExpiry);
  }

  Duration? getAdUnlockTimeRemaining(int testNumber) {
    final adExpiry = state.progress.adUnlockedTests[testNumber];
    if (adExpiry == null || DateTime.now().isAfter(adExpiry)) return null;
    return adExpiry.difference(DateTime.now());
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

  List<int>? getWrongQuestions(int testNumber) {
    final wrong = state.progress.wrongQuestions[testNumber];
    return (wrong != null && wrong.isNotEmpty) ? wrong : null;
  }

  Future<void> saveResult(int testNumber, int score,
      {List<int>? wrongIndices}) async {
    // Calculate effective score for wrong-only retry
    int effectiveScore = score;
    if (wrongIndices != null) {
      final previousWrong = state.progress.wrongQuestions[testNumber] ?? [];
      if (previousWrong.isNotEmpty) {
        // Wrong-only retry: effectiveScore = (20 - previousWrongCount) + newlyCorrected
        final previousWrongCount = previousWrong.length;
        final newlyCorrected = previousWrongCount - wrongIndices.length;
        effectiveScore = (20 - previousWrongCount) + newlyCorrected;
      }
    }

    final currentBest = getBestScore(testNumber);
    final newBestScore =
        effectiveScore > currentBest ? effectiveScore : currentBest;

    final newBestScores = Map<int, int>.from(state.progress.bestScores);
    newBestScores[testNumber] = newBestScore;

    // Update wrongQuestions
    final newWrongQuestions =
        Map<int, List<int>>.from(state.progress.wrongQuestions);
    if (wrongIndices != null && wrongIndices.isNotEmpty) {
      newWrongQuestions[testNumber] = wrongIndices;
    } else {
      newWrongQuestions.remove(testNumber); // all cleared
    }

    // Keep existing unlocks unchanged — no auto-unlock on perfect score
    final newUnlockedTests = Map<int, bool>.from(state.progress.unlockedTests);
    newUnlockedTests[1] = true; // Test 1 always unlocked

    final newProgress = MockTestProgress(
      bestScores: newBestScores,
      unlockedTests: newUnlockedTests,
      highestUnlockedTest: state.progress.highestUnlockedTest,
      wrongQuestions: newWrongQuestions,
      adUnlockedTests: state.progress.adUnlockedTests,
    );

    state = state.copyWith(progress: newProgress);

    // Persist to Hive and Firestore (best-effort; in-memory state already updated)
    await _persistProgress();
  }

  /// Unlock a mock test permanently by spending coins.
  /// Returns `true` if the unlock succeeded, `false` if insufficient coins.
  Future<bool> unlockWithCoins(int testNumber, int coinPrice) async {
    if (isTestUnlocked(testNumber)) return true; // already unlocked
    if (testNumber == 1) return true; // test 1 always free

    // Try to spend coins using CoinNotifier
    // We use the global coinProvider via ref — but in a StateNotifier we don't have ref.
    // Instead, we import and use the service directly.
    final progressRepo = ProgressRepository();
    final coinService = CoinService(progressRepository: progressRepo);
    final success = await coinService.spendCoins(coinPrice);
    if (!success) return false;

    final newUnlockedTests = Map<int, bool>.from(state.progress.unlockedTests);
    newUnlockedTests[testNumber] = true;

    int newHighestUnlocked = state.progress.highestUnlockedTest;
    if (testNumber > newHighestUnlocked) newHighestUnlocked = testNumber;

    final newProgress = state.progress.copyWith(
      unlockedTests: newUnlockedTests,
      highestUnlockedTest: newHighestUnlocked,
    );

    state = state.copyWith(progress: newProgress);
    await _persistProgress();
    return true;
  }

  /// Unlock a mock test temporarily by watching a rewarded ad.
  /// [duration] controls how long the unlock lasts (default 24 hours).
  Future<void> unlockWithAd(int testNumber, {Duration duration = const Duration(hours: 24)}) async {
    if (isTestUnlocked(testNumber)) return;
    final expiry = DateTime.now().add(duration);

    final newAdUnlocks =
        Map<int, DateTime>.from(state.progress.adUnlockedTests);
    newAdUnlocks[testNumber] = expiry;

    final newProgress =
        state.progress.copyWith(adUnlockedTests: newAdUnlocks);
    state = state.copyWith(progress: newProgress);
    await _persistProgress();
  }

  /// Persist current progress to Hive and Firestore.
  Future<void> _persistProgress() async {
    try {
      final p = state.progress;
      await _repository.saveToHive({
        'bestScores': p.bestScores.map((k, v) => MapEntry(k.toString(), v)),
        'unlockedTests': p.unlockedTests.map((k, v) => MapEntry(k.toString(), v)),
        'highestUnlockedTest': p.highestUnlockedTest,
        'wrongQuestions':
            p.wrongQuestions.map((k, v) => MapEntry(k.toString(), v)),
        'adUnlockedTests':
            p.adUnlockedTests.map((k, v) => MapEntry(k.toString(), v.toIso8601String())),
      });

      // Also save to Firestore if user is logged in
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await _repository.uploadToFirestore(userId, {
          'bestScores': p.bestScores.map((k, v) => MapEntry(k.toString(), v)),
          'unlockedTests': p.unlockedTests.map((k, v) => MapEntry(k.toString(), v)),
          'highestUnlockedTest': p.highestUnlockedTest,
          'wrongQuestions':
              p.wrongQuestions.map((k, v) => MapEntry(k.toString(), v)),
          'adUnlockedTests':
              p.adUnlockedTests.map((k, v) => MapEntry(k.toString(), v.toIso8601String())),
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to persist mock test progress: $e');
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
