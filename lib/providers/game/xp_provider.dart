import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/xp_service.dart';
import '../../repositories/statistics_repository.dart';
import 'game_provider.dart';

// ── XP State ──

class XpState {
  final int currentXP;
  final int currentLevel;
  final int xpForNextLevel;
  final double levelProgress;
  final String levelTitle;
  final String levelEmoji;

  const XpState({
    this.currentXP = 0,
    this.currentLevel = 1,
    this.xpForNextLevel = XpService.xpPerLevel,
    this.levelProgress = 0.0,
    this.levelTitle = 'Rookie',
    this.levelEmoji = '🎯',
  });

  XpState copyWith({
    int? currentXP,
    int? currentLevel,
    int? xpForNextLevel,
    double? levelProgress,
    String? levelTitle,
    String? levelEmoji,
  }) {
    return XpState(
      currentXP: currentXP ?? this.currentXP,
      currentLevel: currentLevel ?? this.currentLevel,
      xpForNextLevel: xpForNextLevel ?? this.xpForNextLevel,
      levelProgress: levelProgress ?? this.levelProgress,
      levelTitle: levelTitle ?? this.levelTitle,
      levelEmoji: levelEmoji ?? this.levelEmoji,
    );
  }
}

class XpNotifier extends StateNotifier<XpState> {
  final XpService _xpService;
  StreamSubscription<DocumentSnapshot>? _progressSubscription;

  XpNotifier(this._xpService) : super(const XpState()) {
    _init();
    _startFirestoreListener();
  }

  Future<void> _init() async {
    // Initial load from Hive (fast, for immediate display)
    await _refresh();
  }

  /// Listens to Firestore [game_progress] document for real-time updates.
  /// When data changes (e.g. from another device or after a game syncs),
  /// the state is updated directly from Firebase — bypassing Hive.
  void _startFirestoreListener() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) return;

    _progressSubscription = FirebaseFirestore.instance
        .collection('game_progress')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      _updateFromFirestore(snapshot);
    }, onError: (_) {
      // Firestore unavailable — stay with current Hive-backed state
    });
  }

  /// Reads XP/level directly from the Firestore snapshot and computes
  /// derived values (progress, title, emoji) on the fly.
  void _updateFromFirestore(DocumentSnapshot snapshot) {
    if (!snapshot.exists) return;

    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) return;

    final int currentXP = data['currentXP'] as int? ?? 0;
    final int currentLevel = data['currentLevel'] as int? ?? 1;

    // Recompute level from XP (matches XpService logic)
    final int computedLevel = currentXP > 0 ? (currentXP ~/ 100) + 1 : currentLevel;
    final int xpForNextLevel = _xpService.getXPForNextLevel(computedLevel);
    final double levelProgress = _xpService.getLevelProgressFor(computedLevel, currentXP);
    final String levelTitle = _xpService.getLevelTitle(computedLevel);
    final String levelEmoji = _xpService.getLevelEmoji(computedLevel);

    state = XpState(
      currentXP: currentXP,
      currentLevel: computedLevel,
      xpForNextLevel: xpForNextLevel,
      levelProgress: levelProgress,
      levelTitle: levelTitle,
      levelEmoji: levelEmoji,
    );
  }

  Future<void> _refresh() async {
    final currentXP = await _xpService.getCurrentXP();
    final currentLevel = await _xpService.getCurrentLevel();
    final levelProgress = await _xpService.getLevelProgress();
    final levelTitle = await _xpService.getCurrentLevelTitle();
    final levelEmoji = await _xpService.getCurrentLevelEmoji();
    state = XpState(
      currentXP: currentXP,
      currentLevel: currentLevel,
      xpForNextLevel: _xpService.getXPForNextLevel(currentLevel),
      levelProgress: levelProgress,
      levelTitle: levelTitle,
      levelEmoji: levelEmoji,
    );
  }

  Future<void> addXP(int xp) async {
    await _xpService.addXP(xp);
    await _refresh();
  }

  int calculateCorrectAnswerXP({int streak = 0}) {
    return _xpService.calculateCorrectAnswerXP(streak: streak);
  }

  int calculatePerfectRoundXP() {
    return _xpService.calculatePerfectRoundXP();
  }

  int calculateDailyChallengeXP() {
    return _xpService.calculateDailyChallengeXP();
  }

  int calculateBossBattleXP() {
    return _xpService.calculateBossBattleXP();
  }

  int calculateTotalGameXP({
    required int correctCount,
    required int totalQuestions,
    required double accuracy,
    required int streak,
    required int timeRemaining,
    required int totalTime,
    bool isPerfectGame = false,
  }) {
    return _xpService.calculateTotalGameXP(
      correctCount: correctCount,
      totalQuestions: totalQuestions,
      accuracy: accuracy,
      streak: streak,
      timeRemaining: timeRemaining,
      totalTime: totalTime,
      isPerfectGame: isPerfectGame,
    );
  }

  int getDailyStreakBonus(int streak) {
    return _xpService.getDailyStreakBonus(streak);
  }

  void refresh() {
    _refresh();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }
}

final xpServiceProvider = Provider<XpService>((ref) {
  return XpService(
    progressRepository: ref.watch(progressRepositoryProvider),
    statisticsRepository: StatisticsRepository(),
  );
});

final xpProvider = StateNotifierProvider<XpNotifier, XpState>((ref) {
  final xpService = ref.watch(xpServiceProvider);
  return XpNotifier(xpService);
});
