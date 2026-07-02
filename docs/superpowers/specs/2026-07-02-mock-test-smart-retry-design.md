# Mock Test Smart Retry Design

**Date:** 2026-07-02
**Feature:** শুধু wrong questions retry করার সুযোগ + Retry All option

## Problem

Currently, each mock test has 20 questions. A user must score 20/20 to unlock the next test. If they get
(e.g.) 14 correct and 6 wrong, retrying makes them answer **all 20 questions again**. This is frustrating
and wastes time on questions the user already mastered.

## Solution

Introduce **Smart Retry**: after a non-perfect attempt, the user can choose to retry only the questions
they got wrong. Wrong questions are tracked persistently (Hive + Firestore) so progress survives app restarts.

## Data Model

### MockTestProgress — new field

```dart
class MockTestProgress {
  // ... existing fields ...
  final Map<int, List<int>> wrongQuestions; // testNumber → [wrong question indices]
}
```

- Key: `testNumber` (int)
- Value: list of question indices (0-based) that were answered incorrectly in the latest attempt
- Stored alongside `bestScores` / `unlockedTests` in Hive and Firestore

### Save format (Hive / Firestore)

```json
{
  "bestScores": { "5": 14 },
  "wrongQuestions": { "5": [3, 7, 10, 12, 15, 18] },
  "unlockedTests": { "1": true, "5": true },
  "highestUnlockedTest": 5
}
```

## Quiz Screen — Wrong-Questions-Only Mode

### Parameter change

```dart
class MockTestQuizScreen extends ConsumerStatefulWidget {
  final int testNumber;
  final String testTitle;
  final List<int>? wrongQuestionIndices; // NEW: if set, only these questions shown
}
```

### Behavior

- `wrongQuestionIndices == null` → show all 20 questions (existing behavior)
- `wrongQuestionIndices` is set → **only those questions** appear in the PageView
- Questions count, progress bar, and "Question X/Y" labels reflect the reduced count
- Options are **reshuffled** every attempt (existing shuffle logic unchanged)
- AppBar shows a badge: `"Retrying ${wrongQuestions.length} wrong questions"`

## Result Screen — Two-Button Design

### When score < 20 (not perfect)

| Button | Label | Action |
|--------|-------|--------|
| 🔄 Retry Wrong | `Retry Wrong (X)` | Opens quiz with only wrong questions |
| 🔁 Retry All | `Retry All` | Opens quiz with all 20 questions |

### When score == 20 (perfect)

- Existing celebration overlay (`MockTestUnlockOverlay`)
- "Next Test" button
- No change

### Message

```
"You got 6 wrong. Retry wrong questions or try all 20 again."
```

## Save Logic (`saveResult`)

### New signature

```dart
Future<void> saveResult(int testNumber, int score, {List<int>? wrongIndices})
```

### Logic

The `score` parameter is always out of 20. In wrong-only mode, the quiz screen calculates:

```
previousWrongCount  = wrongQuestions[testNumber].length   (e.g. 6)
newlyCorrectCount   = number of wrong questions answered correctly this attempt (e.g. 4)
effectiveScore      = (20 - previousWrongCount) + newlyCorrectCount  (e.g. 14 + 4 = 18)
```

1. **Update bestScore**: `bestScore = max(oldBestScore, effectiveScore)`

2. **Update wrongQuestions**:
   - `wrongIndices` contains the indices STILL wrong after this attempt
   - If `wrongIndices` non-empty → store it for the test
   - If empty/absent → remove entry (all cleared)

3. **Unlock condition**: Test unlocks when `wrongQuestions[testNumber]` is empty (and `bestScores[prevTest] == 20` for sequential unlock logic — existing behavior unchanged)

4. **Note**: If user clicks "Retry All", the score is directly out of 20 (existing behavior), and `wrongQuestions` is overwritten with the new attempt's wrong indices.

5. **Hive + Firestore** (existing pattern unchanged)

## Progressive Retry Flow (Example)

| Attempt | What's shown | Correct | Wrong | wrongQuestions after | bestScore |
|---------|-------------|---------|-------|---------------------|-----------|
| 1st | All 20 | 14 | 6 | `[q3, q7, q10, q12, q15, q18]` | 14 |
| 2nd (Wrong) | q3, q7, q10, q12, q15, q18 | 4 | 2 | `[q3, q10]` | 18 |
| 3rd (Wrong) | q3, q10 | 2 | 0 | `[]` (empty) | 20 ✅ Unlock! |

If at any point the user clicks **Retry All**, a fresh attempt with all 20 questions is made, and
`wrongQuestions` is updated based on that attempt's results.

## Files to Modify

| File | Changes |
|------|---------|
| `lib/providers/mock_test_provider.dart` | Add `wrongQuestions` to `MockTestProgress`; update `saveResult` signature & logic; add `getWrongQuestions()` method; update Hive/Firestore serialization |
| `lib/models/mock_test_model.dart` | No change needed (quiz data is static) |
| `lib/features/mock_test/screens/mock_test_quiz_screen.dart` | Accept `wrongQuestionIndices` param; filter questions; show badge |
| `lib/features/mock_test/screens/mock_test_result_screen.dart` | Add "Retry Wrong" button; update message; pass wrong indices |
| `lib/repositories/mock_test_repository.dart` | No change needed (already generic Map storage) |

## Testing

1. **Wrong-only retry**: Attempt test, get some wrong, retry wrong, verify only wrong questions shown
2. **Progressive clearing**: Retry wrong multiple times, verify wrong count decreases
3. **Retry All**: After having wrong questions, click Retry All, verify all 20 shown
4. **Persistence**: Close and reopen app, verify wrong questions still tracked
5. **Perfect score**: Verify celebration still works correctly
6. **Unlock**: Verify next test unlocks when all wrong questions cleared
