import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants/tense_constants.dart';
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

    // Map the game "mode" to a difficulty so it selects the right questions:
    //   challenge → hard
    // Other modes (practice/quiz/timed/endless) impose no difficulty filter.
    // GameMode must NOT be compared against q.mode — q.mode stores the question
    // content type (fill_blank, choose_tense, ...), not the play mode.
    final effectiveDifficulty = difficulty ??
        (mode == GameMode.challenge ? 'hard' : null);

    // Apply filters
    if (tenseType != null && tenseType.isNotEmpty) {
      if (_isSpecialCategory(tenseType)) {
        // "comparison" / "special_usage" are cross-tense categories — they
        // deliberately mix questions from every tense rather than filtering
        // to one. No tenseType filter is applied here.
      } else {
        // Normalise so a snake_case id (e.g. "present_indefinite") still
        // matches questions whose tenseType is the readable label
        // ("Present Indefinite").
        final canonical = TenseConstants.nameFromId(tenseType);
        final id = TenseConstants.idFromName(tenseType);
        questions = questions.where((q) {
          final qt = q.tenseType;
          return qt == tenseType || qt == canonical || qt == id;
        }).toList();
      }
    }
    if (effectiveDifficulty != null && effectiveDifficulty.isNotEmpty) {
      questions = questions.where((q) => q.difficulty == effectiveDifficulty).toList();
    }

    // Shuffle questions themselves
    questions.shuffle();

    // Shuffle options within each question so the correct answer
    // appears at a different position every time.
    final rng = Random();
    questions = questions.map((q) => _shuffleOptions(q, rng)).toList();

    if (limit != null && limit > 0 && limit < questions.length) {
      questions = questions.take(limit).toList();
    }

    return questions;
  }

  /// Returns a copy of [question] whose [options] (and [optionBangla])
  /// have been shuffled together, with [correctAnswer] updated to match
  /// the new position of the original correct option.
  GameQuestionModel _shuffleOptions(GameQuestionModel question, Random rng) {
    final opts = question.options;
    if (opts.length <= 1) return question;

    // Build index list [0, 1, 2, …] and shuffle it.
    final indices = List<int>.generate(opts.length, (i) => i)..shuffle(rng);

    final shuffledOptions = indices.map((i) => opts[i]).toList();
    final shuffledBangla = question.optionBangla.isNotEmpty
        ? indices.map((i) => i < question.optionBangla.length ? question.optionBangla[i] : '').toList()
        : <String>[];

    // Find where the original correct answer landed.
    final newCorrect = question.correctAnswer.trim().toLowerCase();
    int newCorrectIdx = 0;
    for (int i = 0; i < shuffledOptions.length; i++) {
      if (shuffledOptions[i].trim().toLowerCase() == newCorrect) {
        newCorrectIdx = i;
        break;
      }
    }

    return question.copyWith(
      options: shuffledOptions,
      optionBangla: shuffledBangla,
      correctAnswer: shuffledOptions[newCorrectIdx],
    );
  }

  /// Special categories that mix questions across tenses instead of filtering
  /// to a single tense. These have no dedicated question file.
  bool _isSpecialCategory(String tenseType) {
    const special = {'comparison', 'special_usage', 'mixed', 'all'};
    return special.contains(tenseType.toLowerCase());
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

    // Upload to Firestore (user-specific)
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        await _statisticsRepository.uploadResultToFirestore(userId, resultWithDuration);
        await _statisticsRepository.uploadMetaToFirestore(userId);
        final progress = _progressRepository.getProgress();
        if (progress != null) {
          await _progressRepository.uploadProgressToFirestore(progress);
        }
      } catch (e) {
        print('Failed to upload result to Firestore: $e');
      }
    }
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