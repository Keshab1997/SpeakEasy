# Hive ↔ Firebase Sync & UI Display Analysis

## 1. Data Flow Summary

### Flow A: Main Game (QuestionScreen → GameProvider → GameService)
```
GameProvider._finishGame()
  → GameService.saveResult()
    1. Hive: saveResult() + addXP() + addCoins()
    2. Firebase: uploadResultToFirestore() + uploadMetaToFirestore() + uploadProgressToFirestore()
  → ResultScreen._syncGameDataToFirebase() (DUPLICATE upload!)
```

### Flow B: Game Mode Screens (WordMatch, QuickQuiz, FillBlanks, StoryCompletion, etc.)
```
ModeScreen._endGame()
  → repo.saveResult()   [Hive ONLY, no Firebase]
  → Navigate to ResultScreen
    → ResultScreen._syncGameDataToFirebase()
      1. Creates NEW incomplete GameResultModel → uploadResultToFirestore()
      2. uploadMetaToFirestore()
      3. Upload progress, achievements, leaderboard
      4. GameDataSyncService.saveUserDataToFirebase() (backup)
```

### Flow C: Login / App Start
```
AuthProvider.fetchUserData() / _init()
  → GameDataSyncService.loadUserDataFromFirebase()
    1. syncProgressFromFirestoreToHive()
    2. syncLevelsFromFirestoreToHive()
    3. syncFromFirestoreToHive() (statistics)
    4. syncFromFirestoreToHive() (achievements)
```

---

## 2. Sync Working Status

### ✅ Hive Save (Local) — ✅ WORKING in all cases
| Data | Save to Hive |
|------|-------------|
| Game Results | ✅ GameService.saveResult() / repo.saveResult() |
| Game Progress (XP/Coins/Level) | ✅ GameService.saveResult() / ProgressRepository |
| Meta Counters (Boss Wins, etc.) | ✅ StatisticsRepository incrementBossWins() |
| Achievements | ✅ AchievementRepository |
| Time Played | ✅ StatisticsRepository.addTimePlayed() |

### 🔥 Firebase Upload (Remote) — ⚠️ PARTIALLY WORKING

| Data | Upload to Firebase | Status |
|------|--------------------|--------|
| Game Results (game_statistics) | GameService.saveResult() **AND** ResultScreen | ✅ Dual upload (redundant but works) |
| Game Results (game_statistics) from Mode Screens | Only via ResultScreen | ✅ Works but **incomplete data** |
| Meta Counters (game_statistics_meta) | GameService.saveResult() + ResultScreen | ✅ Working |
| Game Progress (game_progress) | GameService.saveResult() + ResultScreen | ✅ Working |
| Achievement Batch | ResultScreen + GameDataSyncService | ✅ Working |
| **Game Levels** | **NEVER uploaded to Firestore** | ❌ **MISSING** |
| **autoSyncAfterGame()** | **Defined but NEVER called** | ❌ **DEAD CODE** |

---

## 3. CRITICAL ISSUES FOUND

### Issue 1: ResultScreen Creates Incomplete GameResultModel
- **File:** `lib/features/game/screens/result_screen.dart` (line 124-135)
- **Problem:** ResultScreen creates a **new** GameResultModel from scratch instead of using the model already saved to Hive:
```dart
final result = GameResultModel(
  score: widget.score,
  correctAnswers: widget.correctAnswers,
  wrongAnswers: widget.wrongAnswers,
  // MISSING: durationSeconds, isBossWin, isDailyChallengeWin, difficulty, gameType
);
```
- **Impact:** When mode screens save to Hive with full data, then ResultScreen uploads an incomplete version to Firebase, losing duration, boss/daily win flags, and difficulty.

### Issue 2: Mode Screens Don't Upload Directly to Firebase
- **Files:** `word_match_mode.dart`, `quick_quiz_mode.dart`, `fill_in_blanks_mode.dart`, `story_completion_mode.dart`
- **Pattern:** Each mode screen creates `StatisticsRepository()` and calls only `repo.saveResult()` (Hive-only). Firebase upload is entirely dependent on ResultScreen.
- **Impact:** If ResultScreen's `_syncGameDataToFirebase()` fails or crashes, game results are permanently lost from Firebase.

### Issue 3: Real-time Firestore Listeners Don't Actually Sync from Firestore
- **File:** `lib/providers/game/statistics_provider.dart` (lines 154-192)
- **Problem:** The real-time listeners trigger `_refresh()` which reads **from Hive**, not from Firestore:
```dart
_progressSubscription = FirebaseFirestore.instance
    .collection('game_progress')
    .doc(_currentUserId!)
    .snapshots()
    .listen((snapshot) {
  _refresh();  // <-- Reads from Hive, NOT from Firestore!
});
```
- **Impact:** Cross-device sync doesn't work. Firestore updates from another device trigger a re-read of stale Hive data. The UI never updates with remote changes until next login.

### Issue 4: Game Levels Not Synced to Firebase
- **File:** `lib/services/game_data_sync_service.dart` (lines 53-78)
- **Problem:** `saveUserDataToFirebase()` uploads progress, statistics meta, and achievements, but **does NOT upload levels**:
```dart
// Missing in saveUserDataToFirebase():
// await _progressRepository.batchUploadLevelsToFirestore(userId, levels);
```
- **Impact:** Levels only exist in Hive. If user clears cache or logs in on another device, levels are lost.

### Issue 5: XP/Coin Double-Counting Risk
- **Files:** `game_service.dart` (line 211-212) AND `result_screen.dart`
- **Problem:** GameService.saveResult() calls `_progressRepository.addXP()` / `addCoins()`. Then ResultScreen uploads `localProgress` from the same repo to Firebase. This is consistent.
- But mode screens calculate XP/Coins themselves and pass to ResultScreen as `widget.earnedXP` / `widget.earnedCoins`. The ResultScreen uploads this, **but doesn't add it to the progress repository** for mode screens.
- **Impact for mode screens:** XP/coins from mode games may not be persisted in Hive's progress repository, only uploaded to Firebase.

### Issue 6: `autoSyncAfterGame()` is Dead Code
- **File:** `lib/services/game_data_sync_service.dart` (line 80-83)
- **Problem:** `autoSyncAfterGame()` is defined but **never called anywhere** in the codebase.
- **Impact:** Dead code that should either be removed or integrated into the result flow.

---

## 4. UI Display Verification

### Statistics Screen (GameHomeScreen / StatisticsScreen)
| Field | Source | Correct? |
|-------|--------|---------|
| Games Played | `statsState.totalGamesPlayed` ← Hive `getResults()` | ✅ Shows local Hive data |
| Accuracy | `statsState.overallAccuracy` ← from Hive results | ✅ Accurate for local data |
| XP / Coins | Prefers `statsState.totalEarnedXP` from Hive, falls back to `xpState.currentXP` | ✅ Correct |
| Streak | From `streakProvider` which reads from ProgressRepository | ✅ Correct |
| Best Streak | From `streakService.getLongestStreak()` ← Hive | ✅ Correct |
| Time Played | From `_statisticsRepository.getTimePlayedSeconds()` ← Hive | ✅ Correct |
| Boss Wins | From `_statisticsRepository.getBossWins()` ← Hive | ✅ Correct |

### Key Finding: UI Displays Local Hive Data, NOT Firebase Data
- UI reads from Hive via StatisticsProvider → StatisticsService → StatisticsRepository
- Firestore listeners exist but only serve to trigger Hive re-reads
- If Hive is cleared, data reloads from Firebase on next login

---

## 5. Summary Table

| Scenario | Hive Saved? | Firebase Synced? | UI Shows Correctly? |
|----------|-------------|-----------------|-------------------|
| Main Game (QuestionScreen) | ✅ | ✅ (with duplicate) | ✅ |
| Word Match Mode | ✅ | ⚠️ (incomplete in ResultScreen) | ✅ |
| Quick Quiz Mode | ✅ | ⚠️ (incomplete in ResultScreen) | ✅ |
| Fill Blanks Mode | ✅ | ⚠️ (incomplete in ResultScreen) | ✅ |
| Story Completion Mode | ✅ | ⚠️ (incomplete in ResultScreen) | ✅ |
| Boss Battle | ✅ | ⚠️ (isBossWin flag missing in ResultScreen) | ✅ |
| Daily Challenge | ✅ | ⚠️ (isDailyChallenge flag missing in ResultScreen) | ✅ |
| Game Levels | ✅ Hive | ❌ Never uploaded to Firebase | ✅ from Hive |
| Cross-device sync | ❌ Not synced | ❌ Listeners don't update Hive | ❌ Stale data |

---

## 6. Recommended Fixes

1. **Fix ResultScreen to pass through the full GameResultModel** instead of creating a new one
2. **Add level upload** to `GameDataSyncService.saveUserDataToFirebase()`
3. **Fix Firestore listeners** to actually sync data from Firestore to Hive, not just re-read stale Hive
4. **Make mode screens call GameService.saveResult()** (which handles Firebase) instead of directly calling repo.saveResult()
5. **Call autoSyncAfterGame()** in the ResultScreen instead of duplicating logic
6. **Remove duplicate Firebase uploads** to prevent redundant writes