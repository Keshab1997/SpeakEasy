# Mock Test Smart Retry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to retry only wrong questions in mock tests instead of all 20 questions, with persistent tracking across app restarts.

**Architecture:** Add `wrongQuestions` field to `MockTestProgress` (persisted via Hive/Firestore). Quiz screen accepts optional `wrongQuestionIndices` to filter questions. Result screen shows two buttons: "Retry Wrong (X)" and "Retry All".

**Tech Stack:** Flutter, Riverpod, Hive, Firestore

---

### Task 1: Add `wrongQuestions` to MockTestProgress

**Files:**
- Modify: `lib/providers/mock_test_provider.dart`

- [ ] **Step 1: Add `wrongQuestions` field to `MockTestProgress`**

Replace the `MockTestProgress` class (lines 16-38):

```dart
class MockTestProgress {
  final Map<int, int> bestScores; // testNumber -> bestScore (0-20)
  final Map<int, bool> unlockedTests; // testNumber -> isUnlocked
  final int highestUnlockedTest; // highest test number that is unlocked
  final Map<int, List<int>> wrongQuestions; // testNumber -> [wrong question indices]

  const MockTestProgress({
    this.bestScores = const {},
    this.unlockedTests = const {},
    this.highestUnlockedTest = 1,
    this.wrongQuestions = const {},
  });

  MockTestProgress copyWith({
    Map<int, int>? bestScores,
    Map<int, bool>? unlockedTests,
    int? highestUnlockedTest,
    Map<int, List<int>>? wrongQuestions,
  }) {
    return MockTestProgress(
      bestScores: bestScores ?? this.bestScores,
      unlockedTests: unlockedTests ?? this.unlockedTests,
      highestUnlockedTest: highestUnlockedTest ?? this.highestUnlockedTest,
      wrongQuestions: wrongQuestions ?? this.wrongQuestions,
    );
  }
}
```

- [ ] **Step 2: Update `loadTests()` to restore `wrongQuestions` from Hive**

In `loadTests()` method, add wrongQuestions loading after line 96 (`highestUnlocked = savedProgress['highestUnlockedTest'] as int? ?? 1;`):

```dart
final wrongQuestions = Map<int, List<int>>.from(
  (savedProgress['wrongQuestions'] as Map? ?? {})
      .map((k, v) => MapEntry(int.parse(k), List<int>.from(v as List))),
);
```

Then update the state assignment (line 125-131) to include `wrongQuestions`:

```dart
state = state.copyWith(
  allTests: allTests,
  progress: MockTestProgress(
    bestScores: bestScores,
    unlockedTests: unlockedTests,
    highestUnlockedTest: highestUnlocked,
    wrongQuestions: wrongQuestions,
  ),
  isLoading: false,
);
```

- [ ] **Step 3: Update `clearProgress()` to also clear wrongQuestions**

In the `clearProgress()` method, change `state = state.copyWith(progress: const MockTestProgress())` — this already resets all fields to defaults, so `wrongQuestions` will be empty `const {}`.

- [ ] **Step 4: Commit**

```bash
git add lib/providers/mock_test_provider.dart
git commit -m "feat(mock_test): add wrongQuestions field to MockTestProgress"
```

---

### Task 2: Update `saveResult` to Track Wrong Questions

**Files:**
- Modify: `lib/providers/mock_test_provider.dart`

- [ ] **Step 1: Update `saveResult` signature and logic**

Replace the existing `saveResult` method (lines 159-212) with:

```dart
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
    // If no previous wrong questions, wrongIndices comes from a full-attempt
    // and score is already out of 20
  }

  final currentBest = getBestScore(testNumber);
  final newBestScore = effectiveScore > currentBest ? effectiveScore : currentBest;

  final newBestScores = Map<int, int>.from(state.progress.bestScores);
  newBestScores[testNumber] = newBestScore;

  // Update wrongQuestions
  final newWrongQuestions = Map<int, List<int>>.from(state.progress.wrongQuestions);
  if (wrongIndices != null && wrongIndices.isNotEmpty) {
    newWrongQuestions[testNumber] = wrongIndices;
  } else {
    newWrongQuestions.remove(testNumber); // all cleared
  }

  // Check if we should unlock the next test
  int newHighestUnlocked = state.progress.highestUnlockedTest;
  final newUnlockedTests = Map<int, bool>.from(state.progress.unlockedTests);

  newUnlockedTests[1] = true; // Test 1 always unlocked

  // A test is considered "passed" if bestScore == 20 OR if wrongQuestions are empty
  final bool testPassed = newBestScore == 20 ||
      (!newWrongQuestions.containsKey(testNumber));

  if (testPassed && testNumber < 70) {
    final nextTest = testNumber + 1;
    newUnlockedTests[nextTest] = true;
    if (nextTest > newHighestUnlocked) {
      newHighestUnlocked = nextTest;
    }
  }

  // Ensure sequential unlock: a test is unlocked only if previous has 20/20
  for (int i = 2; i <= 70; i++) {
    final prevPassed = newBestScores[i - 1] == 20 &&
        (!newWrongQuestions.containsKey(i - 1) || newWrongQuestions[i - 1]!.isEmpty);
    if (prevPassed) {
      newUnlockedTests[i] = true;
      if (i > newHighestUnlocked) newHighestUnlocked = i;
    }
  }

  final newProgress = MockTestProgress(
    bestScores: newBestScores,
    unlockedTests: newUnlockedTests,
    highestUnlockedTest: newHighestUnlocked,
    wrongQuestions: newWrongQuestions,
  );

  state = state.copyWith(progress: newProgress);

  // Save to Hive (local cache)
  await _repository.saveToHive({
    'bestScores': newBestScores.map((k, v) => MapEntry(k.toString(), v)),
    'unlockedTests': newUnlockedTests.map((k, v) => MapEntry(k.toString(), v)),
    'highestUnlockedTest': newHighestUnlocked,
    'wrongQuestions': newWrongQuestions.map(
      (k, v) => MapEntry(k.toString(), v),
    ),
  });

  // Also save to Firestore if user is logged in
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId != null) {
    await _repository.uploadToFirestore(userId, {
      'bestScores': newBestScores.map((k, v) => MapEntry(k.toString(), v)),
      'unlockedTests': newUnlockedTests.map((k, v) => MapEntry(k.toString(), v)),
      'highestUnlockedTest': newHighestUnlocked,
      'wrongQuestions': newWrongQuestions.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
    });
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/providers/mock_test_provider.dart
git commit -m "feat(mock_test): update saveResult to track wrong questions with smart scoring"
```

---

### Task 3: Add `getWrongQuestions` Getter Method

**Files:**
- Modify: `lib/providers/mock_test_provider.dart`

- [ ] **Step 1: Add getter after `isPerfectScore` method (line 157)**

```dart
List<int>? getWrongQuestions(int testNumber) {
  final wrong = state.progress.wrongQuestions[testNumber];
  return (wrong != null && wrong.isNotEmpty) ? wrong : null;
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/providers/mock_test_provider.dart
git commit -m "feat(mock_test): add getWrongQuestions getter"
```

---

### Task 4: Update Quiz Screen to Support Wrong-Questions-Only Mode

**Files:**
- Modify: `lib/features/mock_test/screens/mock_test_quiz_screen.dart`

- [ ] **Step 1: Add `wrongQuestionIndices` parameter and filter questions**

Add the new parameter to `MockTestQuizScreen`:

```dart
class MockTestQuizScreen extends ConsumerStatefulWidget {
  final int testNumber;
  final String testTitle;
  final List<int>? wrongQuestionIndices; // NEW

  const MockTestQuizScreen({
    super.key,
    required this.testNumber,
    required this.testTitle,
    this.wrongQuestionIndices, // NEW
  });
```

- [ ] **Step 2: Update `MockTestModel? get _test` getter to filter questions**

Replace the existing getter (lines 45-52) and add a new getter:

```dart
/// Full test data from provider
MockTestModel? get _test {
  final tests = ref.read(mockTestListProvider);
  try {
    return tests.firstWhere((t) => t.testNumber == widget.testNumber);
  } catch (_) {
    return null;
  }
}

/// Questions to display — either all or only wrong ones
List<MockTestQuestion> get _activeQuestions {
  final test = _test;
  if (test == null || test.questions.isEmpty) return [];
  if (widget.wrongQuestionIndices == null) return test.questions;
  return widget.wrongQuestionIndices!
      .map((i) => test.questions[i])
      .toList();
}
```

- [ ] **Step 3: Update `_shuffleAllQuestions` to use `_activeQuestions`**

Replace line 65 (`final test = _test;`) with:

```dart
void _shuffleAllQuestions() {
  final questions = _activeQuestions;
  if (questions.isEmpty) return;

  final random = Random();
  _shuffledQuestions = questions.map((q) {
    // ... rest stays the same ...
  }).toList();
}
```

- [ ] **Step 4: Update build method references from `test.questions` to `_activeQuestions`**

In the build method, replace the following:

Line 108: `final questions = test.questions;` → `final questions = _activeQuestions;`

Line 146: `totalQuestions: test.questions.length,` → `totalQuestions: _activeQuestions.length,`

- [ ] **Step 5: Add retry-mode badge in AppBar**

After the shuffle badge (around line 186, after `'${_answers.length} answered'` text), add:

```dart
if (widget.wrongQuestionIndices != null) ...[
  const SizedBox(width: 8),
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.orange.withOpacity(0.2),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      'Retrying ${widget.wrongQuestionIndices!.length}',
      style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  ),
],
```

- [ ] **Step 6: Update `_submitQuiz` to pass correct score and wrongIndices**

Replace the `_submitQuiz` method (lines 415-461) with:

```dart
Future<void> _submitQuiz() async {
  setState(() => _isSubmitting = true);

  final questions = _activeQuestions;
  int correct = 0;
  final List<int> currentWrongIndices = [];
  for (final entry in _answers.entries) {
    final questionIndex = entry.key;
    final selectedShuffledIndex = entry.value;
    if (selectedShuffledIndex == _shuffledQuestions[questionIndex].shuffledCorrectIndex) {
      correct++;
    } else {
      // Track which question index (in original test) was wrong
      if (widget.wrongQuestionIndices != null) {
        currentWrongIndices.add(widget.wrongQuestionIndices![questionIndex]);
      } else {
        currentWrongIndices.add(questionIndex);
      }
    }
  }

  // Calculate score out of 20 for saveResult
  int scoreOutOf20;
  List<int>? wrongIndicesToSave;
  if (widget.wrongQuestionIndices != null) {
    // Wrong-only retry: track remaining wrong original indices
    final previousWrong = ref.read(mockTestProvider.notifier).getWrongQuestions(widget.testNumber) ?? [];
    final previousCorrect = 20 - previousWrong.length;
    scoreOutOf20 = previousCorrect + correct;
    wrongIndicesToSave = currentWrongIndices.isNotEmpty ? currentWrongIndices : [];
  } else {
    // Full attempt: score is directly out of 20
    scoreOutOf20 = correct;
    wrongIndicesToSave = currentWrongIndices.isNotEmpty ? currentWrongIndices : [];
  }

  // Save result
  try {
    await ref.read(mockTestProvider.notifier).saveResult(
      widget.testNumber,
      scoreOutOf20,
      wrongIndices: wrongIndicesToSave,
    );
  } catch (e) {
    debugPrint('❌ saveResult failed: $e');
  }

  // Build shuffled info maps for result screen
  final Map<int, List<String>> shuffledOptionsMap = {};
  final Map<int, int> shuffledCorrectIndexMap = {};

  if (widget.wrongQuestionIndices != null) {
    // Map back to original question indices for result display
    for (int i = 0; i < _shuffledQuestions.length; i++) {
      final originalIndex = widget.wrongQuestionIndices![i];
      shuffledOptionsMap[originalIndex] = _shuffledQuestions[i].shuffledOptions;
      shuffledCorrectIndexMap[originalIndex] = _shuffledQuestions[i].shuffledCorrectIndex;
    }
  } else {
    for (int i = 0; i < _shuffledQuestions.length; i++) {
      shuffledOptionsMap[i] = _shuffledQuestions[i].shuffledOptions;
      shuffledCorrectIndexMap[i] = _shuffledQuestions[i].shuffledCorrectIndex;
    }
  }

  if (!mounted) return;
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => MockTestResultScreen(
        testNumber: widget.testNumber,
        testTitle: widget.testTitle,
        score: scoreOutOf20,
        total: 20,
        questions: _test!.questions,
        answers: _answers,
        shuffledOptionsMap: shuffledOptionsMap,
        shuffledCorrectIndexMap: shuffledCorrectIndexMap,
      ),
    ),
  );
}
```

- [ ] **Step 7: Commit**

```bash
git add lib/features/mock_test/screens/mock_test_quiz_screen.dart
git commit -m "feat(mock_test): add wrong-questions-only mode to quiz screen"
```

---

### Task 5: Update Result Screen with "Retry Wrong" Button

**Files:**
- Modify: `lib/features/mock_test/screens/mock_test_result_screen.dart`

- [ ] **Step 1: Add wrong question count info and "Retry Wrong" button**

Find the action buttons section (lines 211-259 in the original). Replace the entire `Row` of buttons with:

```dart
// ── Action Buttons ──
Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    if (!isPerfect) ...[
      // Retry Wrong button (only if there are wrong questions)
      ElevatedButton.icon(
        onPressed: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MockTestQuizScreen(
              testNumber: widget.testNumber,
              testTitle: widget.testTitle,
              wrongQuestionIndices: ref
                  .read(mockTestProvider.notifier)
                  .getWrongQuestions(widget.testNumber),
            ),
          ),
        ),
        icon: const Icon(Icons.replay_rounded),
        label: Text(
          'Retry Wrong (${20 - widget.score})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 10),
    ],
    Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => MockTestQuizScreen(
                  testNumber: widget.testNumber,
                  testTitle: widget.testTitle,
                ),
              ),
            ),
            icon: const Icon(Icons.replay_rounded),
            label: Text(!isPerfect ? 'Retry All' : 'Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        if (isPerfect && nextTestUnlocked && nextTestNumber <= 70) ...[
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => MockTestQuizScreen(
                    testNumber: nextTestNumber,
                    testTitle: 'Mock Test $nextTestNumber',
                  ),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Next Test'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ],
    ),
    if (!isPerfect) ...[
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: () => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MockTestListScreen()),
          (route) => false,
        ),
        icon: const Icon(Icons.list_rounded),
        label: const Text('Back to Test List'),
      ),
    ],
  ],
),
```

- [ ] **Step 2: Add import for MockTestQuizScreen**

Verify that `mock_test_quiz_screen.dart` is already imported at the top of the file (line 7): `import 'mock_test_quiz_screen.dart';` — this should already exist.

- [ ] **Step 3: Commit**

```bash
git add lib/features/mock_test/screens/mock_test_result_screen.dart
git commit -m "feat(mock_test): add Retry Wrong button with wrong question count"
```

---

### Task 6: Update `getTotalPerfectScores` to Account for Cleared Wrong Questions

**Files:**
- Modify: `lib/providers/mock_test_provider.dart`

- [ ] **Step 1: Update `getTotalPerfectScores`**

Replace the existing method (line 233-235):

```dart
int getTotalPerfectScores() {
  return state.progress.bestScores.values.where((s) => s == 20).length;
}
```

This already works correctly — `bestScore == 20` is only achieved when a test is fully passed (either by 20/20 or by clearing all wrong questions). No change needed.

- [ ] **Step 2: Verify no additional changes needed for list screen stats**

The `MockTestListScreen` uses `bestScore` to display "Best: X/20" and the green trophy icon. Since `saveResult` now correctly calculates `bestScore` even for wrong-only retries, these stats will automatically reflect the user's progress. No changes needed.

- [ ] **Step 3: Commit**

```bash
git add lib/providers/mock_test_provider.dart
git commit -m "chore(mock_test): verify perfect score and stats compatibility with smart retry"
```

---

## Summary of Changes

| File | Change |
|------|--------|
| `lib/providers/mock_test_provider.dart` | Add `wrongQuestions` field, update `saveResult`, add `getWrongQuestions` getter |
| `lib/features/mock_test/screens/mock_test_quiz_screen.dart` | Add `wrongQuestionIndices` param, filter questions, add badge, update `_submitQuiz` |
| `lib/features/mock_test/screens/mock_test_result_screen.dart` | Add "Retry Wrong" button, update layout |
