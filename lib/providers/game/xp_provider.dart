import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/xp_service.dart';
import 'game_provider.dart';

// ── XP State ──

class XpState {
  final int currentXP;
  final int currentLevel;
  final int xpForNextLevel;
  final double levelProgress;
  final String levelTitle;

  const XpState({
    this.currentXP = 0,
    this.currentLevel = 1,
    this.xpForNextLevel = 100,
    this.levelProgress = 0.0,
    this.levelTitle = 'Beginner',
  });

  XpState copyWith({
    int? currentXP,
    int? currentLevel,
    int? xpForNextLevel,
    double? levelProgress,
    String? levelTitle,
  }) {
    return XpState(
      currentXP: currentXP ?? this.currentXP,
      currentLevel: currentLevel ?? this.currentLevel,
      xpForNextLevel: xpForNextLevel ?? this.xpForNextLevel,
      levelProgress: levelProgress ?? this.levelProgress,
      levelTitle: levelTitle ?? this.levelTitle,
    );
  }
}

class XpNotifier extends StateNotifier<XpState> {
  final XpService _xpService;

  XpNotifier(this._xpService) : super(const XpState()) {
    _refresh();
  }

  void _refresh() {
    state = XpState(
      currentXP: _xpService.getCurrentXP(),
      currentLevel: _xpService.getCurrentLevel(),
      xpForNextLevel: _xpService.getXPForNextLevel(_xpService.getCurrentLevel()),
      levelProgress: _xpService.getLevelProgress(),
      levelTitle: _xpService.getCurrentLevelTitle(),
    );
  }

  Future<void> addXP(int xp) async {
    await _xpService.addXP(xp);
    _refresh();
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
}

final xpServiceProvider = Provider<XpService>((ref) {
  return XpService(
    progressRepository: ref.watch(progressRepositoryProvider),
  );
});

final xpProvider = StateNotifierProvider<XpNotifier, XpState>((ref) {
  final xpService = ref.watch(xpServiceProvider);
  return XpNotifier(xpService);
});