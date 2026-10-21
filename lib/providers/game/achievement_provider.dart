import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../models/game/achievement_model.dart';
import '../../models/game/game_progress_model.dart';
import '../../models/game/game_result_model.dart';
import '../../services/achievement_service.dart';
import '../../repositories/achievement_repository.dart';
import '../../repositories/progress_repository.dart';
import '../../repositories/statistics_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Achievement State ──

class AchievementState {
  final List<AchievementModel> allAchievements;
  final List<AchievementModel> unlockedAchievements;
  final List<AchievementModel> lockedAchievements;
  final bool isLoading;
  final String? error;

  // Real-time stats
  final int totalGamesPlayed;
  final int totalCorrectAnswers;
  final int totalWrongAnswers;
  final double overallAccuracy;
  final int totalEarnedXP;
  final int totalEarnedCoins;
  final int currentStreak;
  final int longestStreak;
  final int currentLevel;
  final int currentXP;
  final int totalCoins;
  final int weeklyStreak;
  final int bossWins;
  final int dailyChallengeWins;
  final int timePlayedSeconds;

  const AchievementState({
    this.allAchievements = const [],
    this.unlockedAchievements = const [],
    this.lockedAchievements = const [],
    this.isLoading = false,
    this.error,
    this.totalGamesPlayed = 0,
    this.totalCorrectAnswers = 0,
    this.totalWrongAnswers = 0,
    this.overallAccuracy = 0.0,
    this.totalEarnedXP = 0,
    this.totalEarnedCoins = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.currentLevel = 1,
    this.currentXP = 0,
    this.totalCoins = 0,
    this.weeklyStreak = 0,
    this.bossWins = 0,
    this.dailyChallengeWins = 0,
    this.timePlayedSeconds = 0,
  });

  AchievementState copyWith({
    List<AchievementModel>? allAchievements,
    List<AchievementModel>? unlockedAchievements,
    List<AchievementModel>? lockedAchievements,
    bool? isLoading,
    String? error,
    bool clearError = false,
    int? totalGamesPlayed,
    int? totalCorrectAnswers,
    int? totalWrongAnswers,
    double? overallAccuracy,
    int? totalEarnedXP,
    int? totalEarnedCoins,
    int? currentStreak,
    int? longestStreak,
    int? currentLevel,
    int? currentXP,
    int? totalCoins,
    int? weeklyStreak,
    int? bossWins,
    int? dailyChallengeWins,
    int? timePlayedSeconds,
  }) {
    return AchievementState(
      allAchievements: allAchievements ?? this.allAchievements,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      lockedAchievements: lockedAchievements ?? this.lockedAchievements,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      totalGamesPlayed: totalGamesPlayed ?? this.totalGamesPlayed,
      totalCorrectAnswers: totalCorrectAnswers ?? this.totalCorrectAnswers,
      totalWrongAnswers: totalWrongAnswers ?? this.totalWrongAnswers,
      overallAccuracy: overallAccuracy ?? this.overallAccuracy,
      totalEarnedXP: totalEarnedXP ?? this.totalEarnedXP,
      totalEarnedCoins: totalEarnedCoins ?? this.totalEarnedCoins,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      currentLevel: currentLevel ?? this.currentLevel,
      currentXP: currentXP ?? this.currentXP,
      totalCoins: totalCoins ?? this.totalCoins,
      weeklyStreak: weeklyStreak ?? this.weeklyStreak,
      bossWins: bossWins ?? this.bossWins,
      dailyChallengeWins: dailyChallengeWins ?? this.dailyChallengeWins,
      timePlayedSeconds: timePlayedSeconds ?? this.timePlayedSeconds,
    );
  }

  int get unlockedCount => unlockedAchievements.length;
  int get totalCount => allAchievements.length;
  double get progress => totalCount > 0 ? unlockedCount / totalCount : 0.0;
  int get lockedCount => lockedAchievements.length;
}

class AchievementNotifier extends AsyncNotifier<AchievementState> {
  AchievementService? _achievementService;
  AchievementRepository? _achievementRepository;

  // Real-time stream subscriptions
  StreamSubscription<DocumentSnapshot>? _progressSubscription;
  StreamSubscription<QuerySnapshot>? _statsSubscription;
  StreamSubscription<DocumentSnapshot>? _metaSubscription;
	  String? _currentUserId;
	  bool _buildComplete = false;

  /// Ensures the service and repository are initialized.
  /// This can be called before [build()] completes (e.g. when
  /// [checkGameAchievements] is triggered from a game result screen
  /// before the provider's build() finishes).
  Future<void> _ensureInitialized() async {
    if (_achievementService != null) return;

    _achievementRepository = AchievementRepository();
    _achievementService = AchievementService(
      achievementRepository: _achievementRepository!,
      progressRepository: ProgressRepository(),
      statisticsRepository: StatisticsRepository(),
    );

    // Load default achievements from JSON so we have data to unlock
    final cached = await _achievementRepository!.getAchievementsFromCache();
    if (cached.isEmpty) {
      final jsonAchievements = await _achievementRepository!.loadFromJson();
      await _achievementRepository!.cacheAchievements(jsonAchievements);
    }
  }

  @override
  Future<AchievementState> build() async {
    // Cancel old subscriptions before re-initializing (important for refresh())
    _progressSubscription?.cancel();
    _statsSubscription?.cancel();
    _metaSubscription?.cancel();

    await _ensureInitialized();
    final repo = _achievementRepository!;
    final service = _achievementService!;

    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // ── 1. Load achievements from Hive (fast, for immediate display) ──
    final achievements = await service.loadAchievements();
    final unlocked = service.getUnlockedAchievements();
    final locked = service.getLockedAchievements();

    var currentState = AchievementState(
      allAchievements: achievements,
      unlockedAchievements: unlocked,
      lockedAchievements: locked,
    );

    // ── 2. Try to load cached stats from Hive (so we never show all 0s) ──
    try {
      final box = await Hive.openBox('game_progress');
      final cachedProgress = box.get('user_progress');
      if (cachedProgress != null) {
        final progress = GameProgressModel.fromMap(
          Map<String, dynamic>.from(cachedProgress as Map),
          '',
        );
        currentState = currentState.copyWith(
          currentLevel: progress.currentLevel,
          currentXP: progress.currentXP,
          totalCoins: progress.totalCoins,
          currentStreak: progress.streak,
          longestStreak: progress.longestStreak,
          weeklyStreak: progress.weeklyStreak,
        );
      }

      final statsBox = await Hive.openBox('game_statistics');
      final cachedStats = statsBox.get('game_results');
      if (cachedStats != null && cachedStats is List && cachedStats.isNotEmpty) {
        final results = cachedStats
            .map((e) => GameResultModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        final totalGames = results.length;
        final totalCorrect = results.fold<int>(0, (s, r) => s + r.correctAnswers);
        final totalWrong = results.fold<int>(0, (s, r) => s + r.wrongAnswers);
        final totalQuestions = totalCorrect + totalWrong;
        final accuracy = totalQuestions > 0 ? totalCorrect / totalQuestions : 0.0;
        final totalXP = results.fold<int>(0, (s, r) => s + r.earnedXP);
        final totalCoins = results.fold<int>(0, (s, r) => s + r.earnedCoins);

        currentState = currentState.copyWith(
          totalGamesPlayed: totalGames,
          totalCorrectAnswers: totalCorrect,
          totalWrongAnswers: totalWrong,
          overallAccuracy: accuracy,
          totalEarnedXP: totalXP,
          totalEarnedCoins: totalCoins,
        );
      }

      final bossWins = statsBox.get('boss_wins', defaultValue: 0) as int;
      final dailyWins = statsBox.get('daily_challenge_wins', defaultValue: 0) as int;
      final timePlayed = statsBox.get('time_played_seconds', defaultValue: 0) as int;
      if (bossWins > 0 || dailyWins > 0 || timePlayed > 0) {
        currentState = currentState.copyWith(
          bossWins: bossWins,
          dailyChallengeWins: dailyWins,
          timePlayedSeconds: timePlayed,
        );
      }
    } catch (_) {
      // Hive read failed — stay with defaults
    }

    // Emit Hive-cached state immediately so the UI never shows all-zero
    state = AsyncValue.data(currentState);

    // ── 2b. Retroactively unlock achievements based on saved stats ──
    try {
      final missed = await service.checkGameAchievements(
        score: 0,
        correctAnswers: 0,
        accuracy: 0,
      );
	      if (missed.isNotEmpty) {
	        final refreshed = await service.loadAchievements();
	        currentState = currentState.copyWith(
	          allAchievements: refreshed,
	          unlockedAchievements: service.getUnlockedAchievements(),
	          lockedAchievements: service.getLockedAchievements(),
	        );
	        state = AsyncValue.data(currentState);
	        await _syncAchievementsToFirestore();
	        await _syncProgressToFirestore(); // also push XP/coin rewards to Firestore
	      }
    } catch (_) {}

    // ── 3. Sync achievements from Firestore (overrides Hive) ──
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      try {
        await repo.syncFromFirestoreToHive(_currentUserId!);
        final firestoreAchievements = await service.loadAchievements();
        final firestoreUnlocked = service.getUnlockedAchievements();
        final firestoreLocked = service.getLockedAchievements();

        // Use current state (which has Hive stats) — DON'T reset to initialState!
        currentState = state.value ?? currentState;
        currentState = currentState.copyWith(
          allAchievements: firestoreAchievements,
          unlockedAchievements: firestoreUnlocked,
          lockedAchievements: firestoreLocked,
        );
        state = AsyncValue.data(currentState);
      } catch (_) {}
    }

    // ── 4. Start real-time Firestore listeners ──
    _startRealtimeListeners();

    // Cancel streams when provider is disposed
    ref.onDispose(() {
      _progressSubscription?.cancel();
      _statsSubscription?.cancel();
      _metaSubscription?.cancel();
    });

    // ── 5. One-shot Firestore fetch for the remaining data ──
    // This runs after listeners are set up, so subsequent updates are real-time.
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      await _fetchProgressFromFirestore();
      await _fetchStatsFromFirestore();
      await _fetchMetaFromFirestore();
    }

    _buildComplete = true;
    return state.value ?? currentState;
  }

  /// Fetches [game_progress] (Level, XP, Coins, Streaks) from Firestore.
  Future<void> _fetchProgressFromFirestore() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    try {
      final progressDoc = await FirebaseFirestore.instance
          .collection('game_progress')
          .doc(_currentUserId!)
          .get();
      if (progressDoc.exists && progressDoc.data() != null) {
        final data = progressDoc.data()!;
        final current = state.value;
        if (current != null) {
          state = AsyncValue.data(current.copyWith(
            currentLevel: data['currentLevel'] as int? ?? current.currentLevel,
            currentXP: data['currentXP'] as int? ?? current.currentXP,
            totalCoins: data['totalCoins'] as int? ?? current.totalCoins,
            currentStreak: data['streak'] as int? ?? current.currentStreak,
            longestStreak: data['longestStreak'] as int? ?? current.longestStreak,
            weeklyStreak: data['weeklyStreak'] as int? ?? current.weeklyStreak,
          ));
        }
        // Background sync to Hive
        await _achievementService!.syncProgressFromFirestore(_currentUserId!);
      }
    } catch (_) {
      // Fallback: try Hive cache
      final cached = _achievementService!.getCachedProgress();
      if (cached != null) {
        final current = state.value;
        if (current != null) {
          state = AsyncValue.data(current.copyWith(
            currentLevel: cached.currentLevel,
            currentXP: cached.currentXP,
            totalCoins: cached.totalCoins,
            currentStreak: cached.streak,
            longestStreak: cached.longestStreak,
            weeklyStreak: cached.weeklyStreak,
          ));
        }
      }
    }
  }

  /// Fetches [game_statistics] (games played, correct/wrong, XP, coins) from Firestore.
  Future<void> _fetchStatsFromFirestore() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    try {
      final statsSnapshot = await FirebaseFirestore.instance
          .collection('game_statistics')
          .where('userId', isEqualTo: _currentUserId!)
          .get();

      int totalGames = 0;
      int totalCorrect = 0;
      int totalWrong = 0;
      int totalXP = 0;
      int totalCoins = 0;
      for (final doc in statsSnapshot.docs) {
        final d = doc.data();
        totalGames++;
        totalCorrect += d['correctAnswers'] as int? ?? 0;
        totalWrong += d['wrongAnswers'] as int? ?? 0;
        totalXP += d['earnedXP'] as int? ?? 0;
        totalCoins += d['earnedCoins'] as int? ?? 0;
      }
      final totalQuestions = totalCorrect + totalWrong;
      final accuracy = totalQuestions > 0 ? totalCorrect / totalQuestions : 0.0;

      final current = state.value;
      if (current != null) {
        state = AsyncValue.data(current.copyWith(
          totalGamesPlayed: totalGames,
          totalCorrectAnswers: totalCorrect,
          totalWrongAnswers: totalWrong,
          overallAccuracy: accuracy,
          totalEarnedXP: totalXP,
          totalEarnedCoins: totalCoins,
        ));
      }
      // Background sync to Hive
      await _achievementService!.syncStatisticsFromFirestore(_currentUserId!);
    } catch (_) {}
  }

  /// Fetches [game_statistics_meta] (Boss Wins, Daily Wins, Time Played) from Firestore.
  Future<void> _fetchMetaFromFirestore() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    try {
      final metaDoc = await FirebaseFirestore.instance
          .collection('game_statistics_meta')
          .doc(_currentUserId!)
          .get();
      if (metaDoc.exists && metaDoc.data() != null) {
        final d = metaDoc.data()!;
        final current = state.value;
        if (current != null) {
          state = AsyncValue.data(current.copyWith(
            bossWins: d['bossWins'] as int? ?? current.bossWins,
            dailyChallengeWins: d['dailyChallengeWins'] as int? ?? current.dailyChallengeWins,
            timePlayedSeconds: d['timePlayedSeconds'] as int? ?? current.timePlayedSeconds,
          ));
        }
      }
    } catch (_) {}
  }

  void _startRealtimeListeners() {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;

    // Listen to progress updates from Firestore
    _progressSubscription = FirebaseFirestore.instance
        .collection('game_progress')
        .doc(_currentUserId!)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _updateProgressStats(snapshot.data()!);
      }
    });

    // Listen to statistics updates from Firestore
    _statsSubscription = FirebaseFirestore.instance
        .collection('game_statistics')
        .where('userId', isEqualTo: _currentUserId!)
        .snapshots()
        .listen((snapshot) {
      _updateStatisticsFromFirestore(snapshot.docs);
    });

    // Listen to meta statistics updates from Firestore
    _metaSubscription = FirebaseFirestore.instance
        .collection('game_statistics_meta')
        .doc(_currentUserId!)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _updateMetaStats(snapshot.data()!);
      }
    });
  }

  /// Reads progress (Level, XP, Coins, Streaks) directly from Firestore snapshot data.
  void _updateProgressStats(Map<String, dynamic> data) {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(
      currentLevel: data['currentLevel'] as int? ?? currentState.currentLevel,
      currentXP: data['currentXP'] as int? ?? currentState.currentXP,
      totalCoins: data['totalCoins'] as int? ?? currentState.totalCoins,
      currentStreak: data['streak'] as int? ?? currentState.currentStreak,
      longestStreak: data['longestStreak'] as int? ?? currentState.longestStreak,
      weeklyStreak: data['weeklyStreak'] as int? ?? currentState.weeklyStreak,
    ));

    // Background sync to Hive for offline
    _syncProgressToHive();
  }

  Future<void> _syncProgressToHive() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    try {
      await _achievementService!.syncProgressFromFirestore(_currentUserId!);
    } catch (_) {}
  }

  /// Aggregates game result stats directly from Firestore QuerySnapshot docs.
  void _updateStatisticsFromFirestore(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final currentState = state.value;
    if (currentState == null) return;

    int totalGames = 0;
    int totalCorrect = 0;
    int totalWrong = 0;
    int totalXP = 0;
    int totalCoins = 0;

    for (final doc in docs) {
      final data = doc.data();
      totalGames++;
      totalCorrect += data['correctAnswers'] as int? ?? 0;
      totalWrong += data['wrongAnswers'] as int? ?? 0;
      totalXP += data['earnedXP'] as int? ?? 0;
      totalCoins += data['earnedCoins'] as int? ?? 0;
    }

    final totalQuestions = totalCorrect + totalWrong;
    final accuracy = totalQuestions > 0 ? totalCorrect / totalQuestions : 0.0;

    state = AsyncValue.data(currentState.copyWith(
      totalGamesPlayed: totalGames,
      totalCorrectAnswers: totalCorrect,
      totalWrongAnswers: totalWrong,
      overallAccuracy: accuracy,
      totalEarnedXP: totalXP,
      totalEarnedCoins: totalCoins,
    ));

    // Background sync to Hive
    _syncToHive();
  }

  Future<void> _syncToHive() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    try {
      await _achievementService!.syncStatisticsFromFirestore(_currentUserId!);
    } catch (_) {}
  }

  /// Reads meta stats directly from Firestore snapshot data.
  void _updateMetaStats(Map<String, dynamic> data) {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(
      bossWins: data['bossWins'] as int? ?? currentState.bossWins,
      dailyChallengeWins: data['dailyChallengeWins'] as int? ?? currentState.dailyChallengeWins,
      timePlayedSeconds: data['timePlayedSeconds'] as int? ?? currentState.timePlayedSeconds,
    ));
  }

  Future<List<AchievementModel>> checkGameAchievements({
    required int score,
    required int correctAnswers,
    required double accuracy,
    int speedBonusCount = 0,
    String gameMode = '',
    int durationSeconds = 0,
  }) async {
    // Wait for build() to complete before checking achievements,
    // so that Hive boxes & cached stats are available and real-time
    // listeners are active. This prevents race conditions where
    // achievement checks run on stale or empty data.
    while (!_buildComplete) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Ensure service is initialized even if build() hasn't run yet
    await _ensureInitialized();

    final newlyUnlocked = await _achievementService!.checkGameAchievements(
      score: score,
      correctAnswers: correctAnswers,
      accuracy: accuracy,
      speedBonusCount: speedBonusCount,
      gameMode: gameMode,
      durationSeconds: durationSeconds,
    );

	    if (newlyUnlocked.isNotEmpty) {
	      _refreshState();
	      await _syncAchievementsToFirestore();
	      await _syncProgressToFirestore();
	    }

	    return newlyUnlocked;
	  }

	  Future<List<AchievementModel>> checkStreakAchievements(int streak) async {
	    final newlyUnlocked =
	        await _achievementService!.checkStreakAchievements(streak);

	    if (newlyUnlocked.isNotEmpty) {
	      _refreshState();
	      await _syncAchievementsToFirestore();
	      await _syncProgressToFirestore();
	    }

	    return newlyUnlocked;
	  }

	  Future<List<AchievementModel>> checkTenseMastery({
	    required bool presentComplete,
	    required bool pastComplete,
	    required bool futureComplete,
	  }) async {
	    final newlyUnlocked = await _achievementService!.checkTenseMastery(
	      presentComplete: presentComplete,
	      pastComplete: pastComplete,
	      futureComplete: futureComplete,
	    );

	    if (newlyUnlocked.isNotEmpty) {
	      _refreshState();
	      await _syncAchievementsToFirestore();
	      await _syncProgressToFirestore();
	    }

	    return newlyUnlocked;
	  }

	  Future<AchievementModel?> unlockAchievement(String achievementId) async {
	    final achievement = await _achievementService!.checkAndUnlock(achievementId);

	    if (achievement != null) {
	      _refreshState();
	      await _syncAchievementsToFirestore();
	      await _syncProgressToFirestore();
	    }

    return achievement;
  }

  /// Uploads current XP/coin progress to Firestore so that
  /// [xpProvider] and [coinProvider] (which listen to the
  /// `game_progress` document) reflect achievement rewards in real time.
  Future<void> _syncProgressToFirestore() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    try {
      final progress = _achievementService!.getCachedProgress();
      if (progress != null) {
        await FirebaseFirestore.instance
            .collection('game_progress')
            .doc(_currentUserId!)
            .set(progress.toFirestoreMap());
      }
    } catch (_) {}
  }

  Future<void> _syncAchievementsToFirestore() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    try {
      final achievements = _achievementService!.getAllAchievements();
      if (achievements.isNotEmpty) {
        await _achievementRepository!.batchUploadToFirestore(_currentUserId!, achievements);
      }
    } catch (_) {}
  }

  void _refreshState() {
    final unlocked = _achievementService!.getUnlockedAchievements();
    final locked = _achievementService!.getLockedAchievements();

    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(
      allAchievements: _achievementService!.getAllAchievements(),
      unlockedAchievements: unlocked,
      lockedAchievements: locked,
    ));
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

final achievementServiceProvider = Provider<AchievementService>((ref) {
  return AchievementService(
    achievementRepository: AchievementRepository(),
    progressRepository: ProgressRepository(),
    statisticsRepository: StatisticsRepository(),
  );
});

final achievementProvider =
    AsyncNotifierProvider<AchievementNotifier, AchievementState>(() {
  return AchievementNotifier();
});

// Real-time stats provider for live updates
final realtimeStatsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final userId = FirebaseAuth.instance.currentUser?.uid;

  if (userId == null || userId.isEmpty) return Stream.value({});

  return FirebaseFirestore.instance
      .collection('game_progress')
      .doc(userId)
      .snapshots()
      .map((snapshot) {
    if (!snapshot.exists || snapshot.data() == null) return {};
    return snapshot.data()!;
  });
});

// Real-time game results provider
final realtimeGameResultsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId = FirebaseAuth.instance.currentUser?.uid;

  if (userId == null || userId.isEmpty) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('game_statistics')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .where((doc) => doc.id != '${userId}_meta')
        .map((doc) => doc.data())
        .toList();
  });
});
