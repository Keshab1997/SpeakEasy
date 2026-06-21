import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game/achievement_model.dart';
import '../../services/achievement_service.dart';
import '../../repositories/achievement_repository.dart';
import '../../repositories/progress_repository.dart';
import '../../repositories/statistics_repository.dart';

// ── Achievement State ──

class AchievementState {
  final List<AchievementModel> allAchievements;
  final List<AchievementModel> unlockedAchievements;
  final List<AchievementModel> lockedAchievements;
  final bool isLoading;
  final String? error;

  const AchievementState({
    this.allAchievements = const [],
    this.unlockedAchievements = const [],
    this.lockedAchievements = const [],
    this.isLoading = false,
    this.error,
  });

  AchievementState copyWith({
    List<AchievementModel>? allAchievements,
    List<AchievementModel>? unlockedAchievements,
    List<AchievementModel>? lockedAchievements,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AchievementState(
      allAchievements: allAchievements ?? this.allAchievements,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      lockedAchievements: lockedAchievements ?? this.lockedAchievements,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }

  int get unlockedCount => unlockedAchievements.length;
  int get totalCount => allAchievements.length;
  double get progress => totalCount > 0 ? unlockedCount / totalCount : 0.0;
}

class AchievementNotifier extends AsyncNotifier<AchievementState> {
  late final AchievementService _achievementService;

  @override
  Future<AchievementState> build() async {
    _achievementService = AchievementService(
      achievementRepository: AchievementRepository(),
      progressRepository: ProgressRepository(),
      statisticsRepository: StatisticsRepository(),
    );

    final achievements = await _achievementService.loadAchievements();
    final unlocked = _achievementService.getUnlockedAchievements();
    final locked = _achievementService.getLockedAchievements();

    return AchievementState(
      allAchievements: achievements,
      unlockedAchievements: unlocked,
      lockedAchievements: locked,
    );
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
    }

    return newlyUnlocked;
  }

  Future<List<AchievementModel>> checkStreakAchievements(int streak) async {
    final newlyUnlocked =
        await _achievementService.checkStreakAchievements(streak);

    if (newlyUnlocked.isNotEmpty) {
      _refreshState();
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
    }

    return newlyUnlocked;
  }

  Future<AchievementModel?> unlockAchievement(String achievementId) async {
    final achievement = await _achievementService.checkAndUnlock(achievementId);

    if (achievement != null) {
      _refreshState();
    }

    return achievement;
  }

  void _refreshState() {
    final unlocked = _achievementService.getUnlockedAchievements();
    final locked = _achievementService.getLockedAchievements();

    state = AsyncValue.data(AchievementState(
      allAchievements: _achievementService.getAllAchievements(),
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
