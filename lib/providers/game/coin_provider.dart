import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/coin_service.dart';
import '../../repositories/statistics_repository.dart';
import 'game_provider.dart';

// ── Coin State ──

class CoinState {
  final int currentCoins;
  final int earnedThisGame;
  final int spentThisGame;
  final int totalEarned;
  final int totalSpent;

  const CoinState({
    this.currentCoins = 0,
    this.earnedThisGame = 0,
    this.spentThisGame = 0,
    this.totalEarned = 0,
    this.totalSpent = 0,
  });

  CoinState copyWith({
    int? currentCoins,
    int? earnedThisGame,
    int? spentThisGame,
    int? totalEarned,
    int? totalSpent,
  }) {
    return CoinState(
      currentCoins: currentCoins ?? this.currentCoins,
      earnedThisGame: earnedThisGame ?? this.earnedThisGame,
      spentThisGame: spentThisGame ?? this.spentThisGame,
      totalEarned: totalEarned ?? this.totalEarned,
      totalSpent: totalSpent ?? this.totalSpent,
    );
  }

  int get netThisGame => earnedThisGame - spentThisGame;
}

class CoinNotifier extends StateNotifier<CoinState> {
  final CoinService _coinService;

  CoinNotifier(this._coinService) : super(const CoinState()) {
    _init();
  }

  Future<void> _init() async {
    await _refresh();
  }

  Future<void> _refresh() async {
    state = CoinState(
      currentCoins: await _coinService.getCurrentCoins(),
    );
  }

  Future<int> addCoins(int coins) async {
    final newBalance = await _coinService.addCoins(coins);
    state = state.copyWith(
      currentCoins: newBalance,
      earnedThisGame: state.earnedThisGame + coins,
      totalEarned: state.totalEarned + coins,
    );
    return newBalance;
  }

  Future<bool> spendCoins(int amount) async {
    final success = await _coinService.spendCoins(amount);
    if (success) {
      final currentCoins = await _coinService.getCurrentCoins();
      state = state.copyWith(
        currentCoins: currentCoins,
        spentThisGame: state.spentThisGame + amount,
        totalSpent: state.totalSpent + amount,
      );
    }
    return success;
  }

  Future<bool> canAfford(int cost) {
    return _coinService.canAfford(cost);
  }

  Future<bool> buyHint() => spendCoins(_coinService.getHintCost());
  Future<bool> buySkip() => spendCoins(_coinService.getSkipCost());
  Future<bool> buyTimeBoost() => spendCoins(_coinService.getTimeBoostCost());
  Future<bool> buyFiftyFifty() => spendCoins(_coinService.getFiftyFiftyCost());

  int calculateCorrectAnswerCoins({int streak = 0}) {
    return _coinService.calculateCorrectAnswerCoins(streak: streak);
  }

  int calculateTotalGameCoins({
    required int correctCount,
    required int totalQuestions,
    required double accuracy,
    required int streak,
    required int timeRemaining,
    required int totalTime,
    bool isPerfectGame = false,
  }) {
    return _coinService.calculateTotalGameCoins(
      correctCount: correctCount,
      totalQuestions: totalQuestions,
      accuracy: accuracy,
      streak: streak,
      timeRemaining: timeRemaining,
      totalTime: totalTime,
      isPerfectGame: isPerfectGame,
    );
  }

  int calculateLevelCompleteCoins() {
    return _coinService.calculateLevelCompleteCoins();
  }

  int calculateBossBattleCoins() {
    return _coinService.calculateBossBattleCoins();
  }

  int calculateDailyRewardCoins() {
    return _coinService.calculateDailyRewardCoins();
  }

  int calculateTotalBonusCoins({
    bool isLevelComplete = false,
    bool isBossBattle = false,
    bool isDailyReward = false,
  }) {
    return _coinService.calculateTotalBonusCoins(
      isLevelComplete: isLevelComplete,
      isBossBattle: isBossBattle,
      isDailyReward: isDailyReward,
    );
  }

  Future<void> resetGameCoins() async {
    state = CoinState(
      currentCoins: await _coinService.getCurrentCoins(),
    );
  }

  void refresh() {
    _refresh();
  }
}

final coinServiceProvider = Provider<CoinService>((ref) {
  return CoinService(
    progressRepository: ref.watch(progressRepositoryProvider),
    statisticsRepository: StatisticsRepository(),
  );
});

final coinProvider = StateNotifierProvider<CoinNotifier, CoinState>((ref) {
  final coinService = ref.watch(coinServiceProvider);
  return CoinNotifier(coinService);
});