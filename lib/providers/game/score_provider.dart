import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game/game_result_model.dart';
import '../../repositories/statistics_repository.dart';
import 'game_provider.dart';

// ── Score State ──

class ScoreState {
  final int currentScore;
  final int correctCount;
  final int wrongCount;
  final int streak;
  final int bestScore;
  final List<int> recentScores;

  const ScoreState({
    this.currentScore = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.streak = 0,
    this.bestScore = 0,
    this.recentScores = const [],
  });

  ScoreState copyWith({
    int? currentScore,
    int? correctCount,
    int? wrongCount,
    int? streak,
    int? bestScore,
    List<int>? recentScores,
  }) {
    return ScoreState(
      currentScore: currentScore ?? this.currentScore,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      streak: streak ?? this.streak,
      bestScore: bestScore ?? this.bestScore,
      recentScores: recentScores ?? this.recentScores,
    );
  }

  double get accuracy {
    final total = correctCount + wrongCount;
    if (total == 0) return 0.0;
    return correctCount / total;
  }
}

class ScoreNotifier extends StateNotifier<ScoreState> {
  final StatisticsRepository _statisticsRepository;

  ScoreNotifier(this._statisticsRepository) : super(const ScoreState()) {
    _init();
  }

  Future<void> _init() async {
    await _loadBestScore();
  }

  Future<void> _loadBestScore() async {
    final best = await _statisticsRepository.getBestResult();
    if (best != null) {
      state = state.copyWith(bestScore: best.score);
    }
  }

  void addCorrect() {
    state = state.copyWith(
      currentScore: state.currentScore + 10,
      correctCount: state.correctCount + 1,
      streak: state.streak + 1,
    );
  }

  void addWrong() {
    state = state.copyWith(
      wrongCount: state.wrongCount + 1,
      streak: 0,
    );
  }

  void addBonusPoints(int points) {
    state = state.copyWith(
      currentScore: state.currentScore + points,
    );
  }

  void resetScore() {
    final scores = List<int>.from(state.recentScores);
    if (state.currentScore > 0) {
      scores.insert(0, state.currentScore);
      if (scores.length > 20) scores.removeLast();
    }

    state = state.copyWith(
      currentScore: 0,
      correctCount: 0,
      wrongCount: 0,
      streak: 0,
      recentScores: scores,
      bestScore: state.currentScore > state.bestScore
          ? state.currentScore
          : state.bestScore,
    );
  }

  void loadFromResult(GameResultModel result) {
    state = state.copyWith(
      currentScore: result.score,
      correctCount: result.correctAnswers,
      wrongCount: result.wrongAnswers,
    );
  }
}

final scoreProvider = StateNotifierProvider<ScoreNotifier, ScoreState>((ref) {
  final statisticsRepository = ref.watch(statisticsRepositoryProvider);
  return ScoreNotifier(statisticsRepository);
});