import '../models/game/game_question_model.dart';
import '../models/game/game_result_model.dart';
import '../models/game/game_level_model.dart';
import '../repositories/game_repository.dart';
import '../repositories/progress_repository.dart';
import '../repositories/statistics_repository.dart';

enum GameMode {
  practice,
  quiz,
  challenge,
  timed,
  endless,
}

class GameService {
  final GameRepository _gameRepository;
  final ProgressRepository _progressRepository;
  final StatisticsRepository _statisticsRepository;

  GameService({
    required GameRepository gameRepository,
    required ProgressRepository progressRepository,
    required StatisticsRepository statisticsRepository,
  })  : _gameRepository = gameRepository,
        _progressRepository = progressRepository,
        _statisticsRepository = statisticsRepository;

  // ── Question Loading ──

  Future<List<GameQuestionModel>> loadQuestions({
    String? tenseType,
    String? difficulty,
    GameMode? mode,
    int? limit,
  }) async {
    List<GameQuestionModel> questions;

    // Try cache first, then JSON, then Firestore
    questions = _gameRepository.getCachedQuestions();
    if (questions.isEmpty) {
      try {
        questions = await _gameRepository.loadFromJson();
      } catch (_) {
        questions = await _gameRepository.fetchFromFirestore();
      }
      await _gameRepository.cacheQuestions(questions);
    }

    // Apply filters
    if (tenseType != null && tenseType.isNotEmpty) {
      questions = questions.where((q) => q.tenseType == tenseType).toList();
    }
    if (difficulty != null && difficulty.isNotEmpty) {
      questions = questions.where((q) => q.difficulty == difficulty).toList();
    }
    if (mode != null) {
      final modeStr = mode.name;
      questions = questions.where((q) => q.mode == modeStr).toList();
    }

    // Shuffle and limit
    questions.shuffle();
    if (limit != null && limit > 0 && limit < questions.length) {
      questions = questions.take(limit).toList();
    }

    return questions;
  }

  Future<List<GameQuestionModel>> loadQuestionsByTenseType(String tenseType) {
    return loadQuestions(tenseType: tenseType);
  }

  Future<List<GameQuestionModel>> loadQuestionsByDifficulty(String difficulty) {
    return loadQuestions(difficulty: difficulty);
  }

  // ── Answer Checking ──

  bool checkAnswer(GameQuestionModel question, String selectedAnswer) {
    return question.correctAnswer.trim().toLowerCase() ==
        selectedAnswer.trim().toLowerCase();
  }

  // ── Game Result ──

  Future<GameResultModel> calculateResult({
    required List<GameQuestionModel> questions,
    required List<String> userAnswers,
    required int earnedXP,
    required int earnedCoins,
  }) async {
    int correct = 0;
    int wrong = 0;

    for (int i = 0; i < questions.length && i < userAnswers.length; i++) {
      if (checkAnswer(questions[i], userAnswers[i])) {
        correct++;
      } else {
        wrong++;
      }
    }

    final total = correct + wrong;
    final accuracy = total > 0 ? correct / total : 0.0;
    final score = (correct * 10) + (accuracy * 100).round();

    return GameResultModel(
      score: score,
      correctAnswers: correct,
      wrongAnswers: wrong,
      accuracy: accuracy,
      earnedXP: earnedXP,
      earnedCoins: earnedCoins,
    );
  }

  Future<void> saveResult(
    GameResultModel result, {
    Duration? duration,
  }) async {
    // Persist duration into the result so historical aggregates stay
    // accurate even if the caller forgets to thread it through.
    final resultWithDuration = duration != null && result.durationSeconds == 0
        ? result.copyWith(durationSeconds: duration.inSeconds)
        : result;

    await _statisticsRepository.saveResult(resultWithDuration);

    // Cumulative time-played counter (Phase 18).
    if (duration != null && duration.inSeconds > 0) {
      await _statisticsRepository.addTimePlayed(duration.inSeconds);
    }

    // Phase 18 win counters — derived from the result's own flags so
    // the same code path serves boss / daily / normal games.
    if (resultWithDuration.isBossWin) {
      await _statisticsRepository.incrementBossWins();
    }
    if (resultWithDuration.isDailyChallengeWin) {
      await _statisticsRepository.incrementDailyChallengeWins();
    }

    await _progressRepository.addXP(result.earnedXP);
    await _progressRepository.addCoins(result.earnedCoins);
  }

  // ── Level Progression ──

  Future<List<GameLevelModel>> getLevels() async {
    var levels = _progressRepository.getLevels();
    if (levels.isEmpty) {
      levels = await _progressRepository.loadLevelsFromJson();
      await _progressRepository.saveLevels(levels);
    }
    return levels;
  }

  Future<void> completeLevel(String levelId, int stars) async {
    await _progressRepository.completeLevel(levelId, stars);
    await _progressRepository.advanceLevel();
  }

  GameLevelModel? getNextUnlockedLevel() {
    final levels = _progressRepository.getLevels();
    for (final level in levels) {
      if (level.unlocked && !level.completed) {
        return level;
      }
    }
    return levels.isNotEmpty ? levels.first : null;
  }

  // ── Game Mode Management ──

  bool isModeUnlocked(GameMode mode) {
    final progress = _progressRepository.getProgress();
    if (progress == null) return mode == GameMode.practice;
    return progress.unlockedModes.contains(mode.name);
  }

  Future<void> unlockMode(GameMode mode) async {
    await _progressRepository.unlockMode(mode.name);
  }

  // ── Question Generation ──

  List<GameQuestionModel> generatePracticeSet({
    required List<GameQuestionModel> allQuestions,
    int count = 10,
  }) {
    final shuffled = List<GameQuestionModel>.from(allQuestions)..shuffle();
    return shuffled.take(count).toList();
  }

  List<GameQuestionModel> generateChallengeSet({
    required List<GameQuestionModel> allQuestions,
    int count = 20,
    String? difficulty,
  }) {
    var pool = allQuestions;
    if (difficulty != null) {
      pool = pool.where((q) => q.difficulty == difficulty).toList();
    }
    final shuffled = List<GameQuestionModel>.from(pool)..shuffle();
    return shuffled.take(count).toList();
  }
}