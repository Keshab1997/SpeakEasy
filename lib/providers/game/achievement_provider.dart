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
  late final AchievementService _achievementService;
  late final AchievementRepository _achievementRepository;
  
  // Real-time stream subscriptions
  StreamSubscription<DocumentSnapshot>? _progressSubscription;
  StreamSubscription<QuerySnapshot>? _statsSubscription;
  StreamSubscription<DocumentSnapshot>? _metaSubscription;
  String? _currentUserId;

  @override
  Future<AchievementState> build() async {
    final progressRepo = ProgressRepository();
    _achievementRepository = AchievementRepository();
    _achievementService = AchievementService(
      achievementRepository: _achievementRepository,
      progressRepository: progressRepo,
      statisticsRepository: StatisticsRepository(),
    );

    final achievements = await _achievementService.loadAchievements();
    final unlocked = _achievementService.getUnlockedAchievements();
    final locked = _achievementService.getLockedAchievements();

    // Get current user ID from Firebase Auth
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // Build initial state with achievements
    final initialState = AchievementState(
      allAchievements: achievements,
      unlockedAchievements: unlocked,
      lockedAchievements: locked,
    );

    // ── First, load cached progress from Hive (so we never show all 0s) ──
    try {
      // Ensure the Hive box is opened before trying to read from it
      final box = await Hive.openBox('game_progress');
      final cachedProgress = box.get('user_progress');
      if (cachedProgress != null) {
        final progress = GameProgressModel.fromMap(
          Map<String, dynamic>.from(cachedProgress as Map),
          '',
        );
        state = AsyncValue.data(initialState.copyWith(
          currentLevel: progress.currentLevel,
          currentXP: progress.currentXP,
          totalCoins: progress.totalCoins,
          currentStreak: progress.streak,
          longestStreak: progress.longestStreak,
          weeklyStreak: progress.weeklyStreak,
        ));
      }

      // Also load cached statistics from Hive
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

        final current = state.value ?? initialState;
        state = AsyncValue.data(current.copyWith(
          totalGamesPlayed: totalGames,
          totalCorrectAnswers: totalCorrect,
          totalWrongAnswers: totalWrong,
          overallAccuracy: accuracy,
          totalEarnedXP: totalXP,
          totalEarnedCoins: totalCoins,
        ));
      }

      // Load cached meta (boss wins, daily wins, time played)
      final bossWins = statsBox.get('boss_wins', defaultValue: 0) as int;
      final dailyWins = statsBox.get('daily_challenge_wins', defaultValue: 0) as int;
      final timePlayed = statsBox.get('time_played_seconds', defaultValue: 0) as int;
      if (bossWins > 0 || dailyWins > 0 || timePlayed > 0) {
        final current = state.value ?? initialState;
        state = AsyncValue.data(current.copyWith(
          bossWins: bossWins,
          dailyChallengeWins: dailyWins,
          timePlayedSeconds: timePlayed,
        ));
      }
    } catch (_) {
      // Hive read failed silently
    }

    // ── Fetch initial data from Firestore to override Hive cache ──
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      try {
        // 0. Fetch achievements from Firestore and sync to Hive
        await _achievementRepository.syncFromFirestoreToHive(_currentUserId!);
        // Reload from Hive (now updated with Firestore data)
        final firestoreAchievements = await _achievementService.loadAchievements();
        final firestoreUnlocked = _achievementService.getUnlockedAchievements();
        final firestoreLocked = _achievementService.getLockedAchievements();
        // Update initialState with Firestore-synced achievement data
        final syncedInitialState = initialState.copyWith(
          allAchievements: firestoreAchievements,
          unlockedAchievements: firestoreUnlocked,
          lockedAchievements: firestoreLocked,
        );

        // 1. Fetch progress (Level, XP, Coins, Streaks)
        final progressDoc = await FirebaseFirestore.instance
            .collection('game_progress')
            .doc(_currentUserId!)
            .get();
        if (progressDoc.exists && progressDoc.data() != null) {
          final data = progressDoc.data()!;
          // Sync to Hive so AchievementService reads correct values
          await _achievementService.syncProgressFromFirestore(_currentUserId!);
          // Build updated state
          state = AsyncValue.data(syncedInitialState.copyWith(
            currentLevel: data['currentLevel'] as int? ?? 1,
            currentXP: data['currentXP'] as int? ?? 0,
            totalCoins: data['totalCoins'] as int? ?? 0,
            currentStreak: data['streak'] as int? ?? 0,
            longestStreak: data['longestStreak'] as int? ?? 0,
            weeklyStreak: data['weeklyStreak'] as int? ?? 0,
          ));
        }

        // 2. Fetch statistics (Games, Correct, Wrong, XP, Coins)
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
        await _achievementService.syncStatisticsFromFirestore(_currentUserId!);

        // Merge with current state
        final currentState = state.value ?? initialState;
        state = AsyncValue.data(currentState.copyWith(
          totalGamesPlayed: totalGames,
          totalCorrectAnswers: totalCorrect,
          totalWrongAnswers: totalWrong,
          overallAccuracy: accuracy,
          totalEarnedXP: totalXP,
          totalEarnedCoins: totalCoins,
        ));

        // 3. Fetch meta (Boss Wins, Daily Wins, Time Played)
        final metaDoc = await FirebaseFirestore.instance
            .collection('game_statistics_meta')
            .doc(_currentUserId!)
            .get();
        if (metaDoc.exists && metaDoc.data() != null) {
          final d = metaDoc.data()!;
          final currentState2 = state.value ?? initialState;
          state = AsyncValue.data(currentState2.copyWith(
            bossWins: d['bossWins'] as int? ?? 0,
            dailyChallengeWins: d['dailyChallengeWins'] as int? ?? 0,
            timePlayedSeconds: d['timePlayedSeconds'] as int? ?? 0,
          ));
        }
      } catch (_) {
        // If Firestore fails, try loading from Hive cache directly
        final cached = _achievementService.getCachedProgress();
        if (cached != null) {
          state = AsyncValue.data((state.value ?? initialState).copyWith(
            currentLevel: cached.currentLevel,
            currentXP: cached.currentXP,
            totalCoins: cached.totalCoins,
            currentStreak: cached.streak,
            longestStreak: cached.longestStreak,
            weeklyStreak: cached.weeklyStreak,
          ));
        }
      }
    } else {
      // No user ID — try Hive cache
      try {
        final cached = _achievementService.getCachedProgress();
        if (cached != null) {
          state = AsyncValue.data(initialState.copyWith(
            currentLevel: cached.currentLevel,
            currentXP: cached.currentXP,
            totalCoins: cached.totalCoins,
            currentStreak: cached.streak,
            longestStreak: cached.longestStreak,
            weeklyStreak: cached.weeklyStreak,
          ));
        }
      } catch (_) {}
    }

    // Start listening to real-time updates
    _startRealtimeListeners();

    return state.value ?? initialState;
  }

  void _startRealtimeListeners() {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;

    // Listen to progress updates
    _progressSubscription = FirebaseFirestore.instance
        .collection('game_progress')
        .doc(_currentUserId!)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final progress = GameProgressModel.fromMap(snapshot.data()!, _currentUserId!);
        _updateProgressStats(progress);
      }
    });

    // Listen to statistics updates
    _statsSubscription = FirebaseFirestore.instance
        .collection('game_statistics')
        .where('userId', isEqualTo: _currentUserId!)
        .snapshots()
        .listen((snapshot) {
      // Even if snapshot.docs is empty (e.g. after a clear), 
      // we should update the state to reflect 0s.
      _updateStatisticsFromFirestore(snapshot.docs);
    });

    // Listen to meta statistics updates
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

  void _updateProgressStats(GameProgressModel progress) {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(
      currentLevel: progress.currentLevel,
      currentXP: progress.currentXP,
      totalCoins: progress.totalCoins,
      currentStreak: progress.streak,
      longestStreak: progress.longestStreak,
      weeklyStreak: progress.weeklyStreak,
    ));

    // Sync progress to Hive so AchievementService reads correct XP/coins
    _syncProgressToHive();
  }

  Future<void> _syncProgressToHive() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    try {
      await _achievementService.syncProgressFromFirestore(_currentUserId!);
    } catch (_) {
      // Silently fail - Hive sync is best-effort
    }
  }

  void _updateStatisticsFromFirestore(List<QueryDocumentSnapshot> docs) {
    final currentState = state.value;
    if (currentState == null) return;

    int totalGames = 0;
    int totalCorrect = 0;
    int totalWrong = 0;
    int totalXP = 0;
    int totalCoins = 0;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
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

    // Sync Firestore data to Hive so AchievementService reads correct stats
    _syncToHive();
  }

  Future<void> _syncToHive() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    try {
      await _achievementService.syncStatisticsFromFirestore(_currentUserId!);
    } catch (_) {
      // Silently fail - Hive sync is best-effort
    }
  }

  void _updateMetaStats(Map<String, dynamic> data) {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(
      bossWins: data['bossWins'] as int? ?? 0,
      dailyChallengeWins: data['dailyChallengeWins'] as int? ?? 0,
      timePlayedSeconds: data['timePlayedSeconds'] as int? ?? 0,
    ));
  }

  Future<List<AchievementModel>> checkGameAchievements({
    required int score,
    required int correctAnswers,
    required double accuracy,
    bool isBossBattle = false,
    int speedBonusCount = 0,
  }) async {
    final newlyUnlocked = await _achievementService.checkGameAchievements(
      score: score,
      correctAnswers: correctAnswers,
      accuracy: accuracy,
      isBossBattle: isBossBattle,
      speedBonusCount: speedBonusCount,
    );

    if (newlyUnlocked.isNotEmpty) {
      _refreshState();
      // Upload updated achievements to Firestore
      await _syncAchievementsToFirestore();
    }

    return newlyUnlocked;
  }

  Future<List<AchievementModel>> checkStreakAchievements(int streak) async {
    final newlyUnlocked =
        await _achievementService.checkStreakAchievements(streak);

    if (newlyUnlocked.isNotEmpty) {
      _refreshState();
      // Upload updated achievements to Firestore
      await _syncAchievementsToFirestore();
    }

    return newlyUnlocked;
  }

  Future<List<AchievementModel>> checkTenseMastery({
    required bool presentComplete,
    required bool pastComplete,
    required bool futureComplete,
  }) async {
    final newlyUnlocked = await _achievementService.checkTenseMastery(
      presentComplete: presentComplete,
      pastComplete: pastComplete,
      futureComplete: futureComplete,
    );

    if (newlyUnlocked.isNotEmpty) {
      _refreshState();
      // Upload updated achievements to Firestore
      await _syncAchievementsToFirestore();
    }

    return newlyUnlocked;
  }

  Future<AchievementModel?> unlockAchievement(String achievementId) async {
    final achievement = await _achievementService.checkAndUnlock(achievementId);

    if (achievement != null) {
      _refreshState();
      // Upload updated achievements to Firestore
      await _syncAchievementsToFirestore();
    }

    return achievement;
  }

  /// Upload all cached achievements to Firestore so they persist across devices
  Future<void> _syncAchievementsToFirestore() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    try {
      final achievements = _achievementService.getAllAchievements();
      if (achievements.isNotEmpty) {
        await _achievementRepository.batchUploadToFirestore(_currentUserId!, achievements);
      }
    } catch (_) {
      // Silently fail - Firestore upload is best-effort
    }
  }

  void _refreshState() {
    final unlocked = _achievementService.getUnlockedAchievements();
    final locked = _achievementService.getLockedAchievements();

    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(
      allAchievements: _achievementService.getAllAchievements(),
      unlockedAchievements: unlocked,
      lockedAchievements: locked,
    ));
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  void dispose() {
    _progressSubscription?.cancel();
    _statsSubscription?.cancel();
    _metaSubscription?.cancel();
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