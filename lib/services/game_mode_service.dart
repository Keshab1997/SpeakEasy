import 'package:flutter/material.dart';
import '../models/game/game_question_model.dart';

enum GameModeType {
  fillInBlank,
  chooseCorrectTense,
  sentenceBuilder,
  errorDetection,
  translationChallenge,
  speedQuiz,
}

class GameModeConfig {
  final GameModeType type;
  final String name;
  final String description;
  final IconData icon;
  final int timeLimit;
  final int initialLives;
  final int hintCount;
  final bool hasTimer;
  final bool hasLives;
  final bool hasHints;
  final bool hasPause;

  const GameModeConfig({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    this.timeLimit = 60,
    this.initialLives = 3,
    this.hintCount = 3,
    this.hasTimer = true,
    this.hasLives = true,
    this.hasHints = true,
    this.hasPause = true,
  });

  static const Map<GameModeType, GameModeConfig> configs = {
    GameModeType.fillInBlank: GameModeConfig(
      type: GameModeType.fillInBlank,
      name: 'Fill in the Blank',
      description: 'Complete the sentence with the correct word',
      icon: Icons.edit,
      timeLimit: 90,
      initialLives: 3,
      hintCount: 3,
    ),
    GameModeType.chooseCorrectTense: GameModeConfig(
      type: GameModeType.chooseCorrectTense,
      name: 'Choose Correct Tense',
      description: 'Select the correct tense for each sentence',
      icon: Icons.check_circle,
      timeLimit: 60,
      initialLives: 3,
      hintCount: 2,
    ),
    GameModeType.sentenceBuilder: GameModeConfig(
      type: GameModeType.sentenceBuilder,
      name: 'Sentence Builder',
      description: 'Arrange words to form correct sentences',
      icon: Icons.build,
      timeLimit: 120,
      initialLives: 5,
      hintCount: 4,
    ),
    GameModeType.errorDetection: GameModeConfig(
      type: GameModeType.errorDetection,
      name: 'Error Detection',
      description: 'Find and correct the error in the sentence',
      icon: Icons.error_outline,
      timeLimit: 90,
      initialLives: 3,
      hintCount: 3,
    ),
    GameModeType.translationChallenge: GameModeConfig(
      type: GameModeType.translationChallenge,
      name: 'Translation Challenge',
      description: 'Translate sentences between English and Bengali',
      icon: Icons.translate,
      timeLimit: 120,
      initialLives: 3,
      hintCount: 2,
    ),
    GameModeType.speedQuiz: GameModeConfig(
      type: GameModeType.speedQuiz,
      name: 'Speed Quiz',
      description: 'Answer as many questions as you can in 60 seconds',
      icon: Icons.speed,
      timeLimit: 60,
      initialLives: 1,
      hintCount: 1,
      hasLives: false,
    ),
  };

  factory GameModeConfig.fromType(GameModeType type) {
    return configs[type]!;
  }
}

class GameModeState {
  final GameModeType type;
  final int score;
  final int lives;
  final int hintsRemaining;
  final int timeRemaining;
  final int questionsAnswered;
  final int correctAnswers;
  final bool isPaused;
  final bool isGameOver;
  final bool isTimerRunning;

  const GameModeState({
    required this.type,
    this.score = 0,
    this.lives = 3,
    this.hintsRemaining = 3,
    this.timeRemaining = 60,
    this.questionsAnswered = 0,
    this.correctAnswers = 0,
    this.isPaused = false,
    this.isGameOver = false,
    this.isTimerRunning = false,
  });

  GameModeState copyWith({
    GameModeType? type,
    int? score,
    int? lives,
    int? hintsRemaining,
    int? timeRemaining,
    int? questionsAnswered,
    int? correctAnswers,
    bool? isPaused,
    bool? isGameOver,
    bool? isTimerRunning,
  }) {
    return GameModeState(
      type: type ?? this.type,
      score: score ?? this.score,
      lives: lives ?? this.lives,
      hintsRemaining: hintsRemaining ?? this.hintsRemaining,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      questionsAnswered: questionsAnswered ?? this.questionsAnswered,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      isPaused: isPaused ?? this.isPaused,
      isGameOver: isGameOver ?? this.isGameOver,
      isTimerRunning: isTimerRunning ?? this.isTimerRunning,
    );
  }

  double get accuracy {
    if (questionsAnswered == 0) return 0.0;
    return correctAnswers / questionsAnswered;
  }
}

class GameModeNotifier extends GameModeState {
  GameModeNotifier({required GameModeType type}) : super(type: type);
}