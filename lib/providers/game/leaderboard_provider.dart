import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repositories/leaderboard_repository.dart';

// ── Leaderboard State ──

class LeaderboardState {
  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? currentUser;
  final bool isLoading;
  final String? error;
  final LeaderboardType type;

  const LeaderboardState({
    this.entries = const [],
    this.currentUser,
    this.isLoading = false,
    this.error,
    this.type = LeaderboardType.global,
  });

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    LeaderboardEntry? currentUser,
    bool? isLoading,
    String? error,
    LeaderboardType? type,
    bool clearError = false,
  }) {
    return LeaderboardState(
      entries: entries ?? this.entries,
      currentUser: currentUser ?? this.currentUser,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      type: type ?? this.type,
    );
  }
}

enum LeaderboardType { global, weekly, daily }

class LeaderboardNotifier extends AsyncNotifier<LeaderboardState> {
  late final LeaderboardRepository _leaderboardRepository;

  @override
  Future<LeaderboardState> build() async {
    _leaderboardRepository = LeaderboardRepository();

    final entries = await _leaderboardRepository.fetchGlobalLeaderboard();

    return LeaderboardState(
      entries: entries,
      type: LeaderboardType.global,
    );
  }

  Future<void> loadGlobalLeaderboard({int limit = 100}) async {
    state = const AsyncValue.loading();

    try {
      final entries =
          await _leaderboardRepository.fetchGlobalLeaderboard(limit: limit);
      state = AsyncValue.data(LeaderboardState(
        entries: entries,
        type: LeaderboardType.global,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadWeeklyLeaderboard({int limit = 100}) async {
    state = const AsyncValue.loading();

    try {
      final entries =
          await _leaderboardRepository.fetchWeeklyLeaderboard(limit: limit);
      state = AsyncValue.data(LeaderboardState(
        entries: entries,
        type: LeaderboardType.weekly,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadDailyLeaderboard({int limit = 100}) async {
    state = const AsyncValue.loading();

    try {
      final entries =
          await _leaderboardRepository.fetchDailyLeaderboard(limit: limit);
      state = AsyncValue.data(LeaderboardState(
        entries: entries,
        type: LeaderboardType.daily,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<LeaderboardEntry?> fetchUserRank(String userId) async {
    try {
      return await _leaderboardRepository.fetchUserRank(userId);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateUserStats({
    required String userId,
    required String userName,
    required int xp,
    required int score,
    required int level,
  }) async {
    try {
      await _leaderboardRepository.updateUserStats(
        userId: userId,
        userName: userName,
        xp: xp,
        score: score,
        level: level,
      );

      // Refresh current leaderboard
      switch (state.value?.type) {
        case LeaderboardType.weekly:
          await loadWeeklyLeaderboard();
          break;
        case LeaderboardType.daily:
          await loadDailyLeaderboard();
          break;
        default:
          await loadGlobalLeaderboard();
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> syncFromFirestore({int limit = 100}) async {
    try {
      await _leaderboardRepository.syncFromFirestoreToHive(limit: limit);
      final cached = _leaderboardRepository.getCachedLeaderboard();
      state = AsyncValue.data(LeaderboardState(
        entries: cached,
        type: state.value?.type ?? LeaderboardType.global,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refresh() async {
    switch (state.value?.type) {
      case LeaderboardType.weekly:
        await loadWeeklyLeaderboard();
        break;
      case LeaderboardType.daily:
        await loadDailyLeaderboard();
        break;
      default:
        await loadGlobalLeaderboard();
    }
  }
}

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepository();
});

final leaderboardProvider =
    AsyncNotifierProvider<LeaderboardNotifier, LeaderboardState>(() {
  return LeaderboardNotifier();
});
