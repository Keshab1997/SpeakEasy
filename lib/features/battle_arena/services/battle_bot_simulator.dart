import 'dart:math';
import '../models/battle_models.dart';

class BattleBotSimulator {
  static final Random _rng = Random();
  static int? _lastEmoteRound;

  static const List<Map<String, String>> _botProfiles = [
    {'name': 'Arif Hasan', 'avatar': 'https://api.dicebear.com/7.x/bottts/png?seed=Arif'},
    {'name': 'Priya Das', 'avatar': 'https://api.dicebear.com/7.x/bottts/png?seed=Priya'},
    {'name': 'Tanvir Ahmed', 'avatar': 'https://api.dicebear.com/7.x/bottts/png?seed=Tanvir'},
    {'name': 'Sneha Roy', 'avatar': 'https://api.dicebear.com/7.x/bottts/png?seed=Sneha'},
    {'name': 'Rahul Sharma', 'avatar': 'https://api.dicebear.com/7.x/bottts/png?seed=Rahul'},
    {'name': 'Ananya Sen', 'avatar': 'https://api.dicebear.com/7.x/bottts/png?seed=Ananya'},
    {'name': 'Joy Chakraborty', 'avatar': 'https://api.dicebear.com/7.x/bottts/png?seed=Joy'},
    {'name': 'Riya Mukherjee', 'avatar': 'https://api.dicebear.com/7.x/bottts/png?seed=Riya'},
    {'name': 'Suman Dey', 'avatar': 'https://api.dicebear.com/7.x/bottts/png?seed=Suman'},
    {'name': 'Nusrat Jahan', 'avatar': 'https://api.dicebear.com/7.x/bottts/png?seed=Nusrat'},
  ];

  /// Creates a realistic bot player matching the user's trophy level
  static BattlePlayer createBotPlayer({required int userTrophies}) {
    // New match → reset the emote cooldown tracker
    _lastEmoteRound = null;

    final profile = _botProfiles[_rng.nextInt(_botProfiles.length)];
    // Keep the bot within ~30 trophies of the player so the matchup is fair.
    final trophyDelta = _rng.nextInt(61) - 30; // -30..+30
    final botTrophies = max(50, userTrophies + trophyDelta);

    return BattlePlayer(
      id: 'bot_${DateTime.now().millisecondsSinceEpoch}_${_rng.nextInt(1000)}',
      name: profile['name']!,
      photoUrl: profile['avatar']!,
      trophies: botTrophies,
      currentScore: 0,
      currentRound: 0,
      isReady: true,
      isBot: true,
    );
  }

  /// Bot accuracy rises with the player's trophy band, so low-trophy
  /// learners get a forgiving bot and veterans get a real challenge.
  static double accuracyForTrophies(int userTrophies) {
    if (userTrophies >= 1500) return 0.92; // Grandmaster
    if (userTrophies >= 800) return 0.85;  // Master
    if (userTrophies >= 300) return 0.75;  // Challenger
    return 0.60;                           // Novice
  }

  /// Reaction speed (seconds) — higher-trophy players meet a faster bot.
  static int reactionSecondsForTrophies(int userTrophies) {
    if (userTrophies >= 800) {
      return 2 + _rng.nextInt(4); // 2–5s (fast)
    }
    return 3 + _rng.nextInt(5);   // 3–7s
  }

  /// Calculates a bot answer choice and response time, scaled to the
  /// player's trophy level.
  static BotAnswerDecision decideAnswer({
    required BattleQuestion question,
    required int roundNumber,
    int userTrophies = 100,
  }) {
    final accuracy = accuracyForTrophies(userTrophies);
    final isCorrect = _rng.nextDouble() < accuracy;
    final int chosenAnswer;

    if (isCorrect) {
      chosenAnswer = question.correctAnswer;
    } else {
      // Pick one of the incorrect options
      final wrongOptions = [0, 1, 2, 3]..remove(question.correctAnswer);
      chosenAnswer = wrongOptions[_rng.nextInt(wrongOptions.length)];
    }

    final int reactionSeconds = reactionSecondsForTrophies(userTrophies);

    return BotAnswerDecision(
      selectedAnswer: chosenAnswer,
      isCorrect: isCorrect,
      reactionSeconds: reactionSeconds,
    );
  }

  /// Occasional friendly emote from the bot.
  /// Rules to avoid spam after every question:
  /// - never in round 1 (let the player settle in)
  /// - never two rounds in a row (cooldown)
  /// - only ~15% chance
  static String? maybeGenerateEmote({int roundNumber = 0}) {
    if (roundNumber <= 1) return null;
    if (_lastEmoteRound != null && roundNumber - _lastEmoteRound! < 2) return null;

    if (_rng.nextDouble() < 0.15) {
      _lastEmoteRound = roundNumber;
      const emotes = ['🔥', '😎', '👏', '⚡', '🤯'];
      return emotes[_rng.nextInt(emotes.length)];
    }
    return null;
  }
}

class BotAnswerDecision {
  final int selectedAnswer;
  final bool isCorrect;
  final int reactionSeconds;

  const BotAnswerDecision({
    required this.selectedAnswer,
    required this.isCorrect,
    required this.reactionSeconds,
  });
}
