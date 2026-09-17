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
    // Keep the bot within ±15 trophies of the player so the matchup is fair
    // (was ±30 — low-trophy players kept meeting scary 130-trophy bots).
    final trophyDelta = _rng.nextInt(31) - 15; // -15..+15
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

  /// Bot accuracy rises LINEARLY with the player's trophies, so low-trophy
  /// learners get a forgiving bot and veterans get a real challenge — no
  /// more cliff-jumps at division boundaries (was a step function).
  /// 100🏆 → ~0.58 · 300🏆 → ~0.65 · 800🏆 → ~0.82 · 1100🏆+ → 0.92 cap.
  static double accuracyForTrophies(int userTrophies) {
    final t = userTrophies < 0 ? 0 : userTrophies;
    return (0.55 + t / 3000).clamp(0.55, 0.92);
  }

  /// Reaction speed (seconds) — higher-trophy players meet a faster bot.
  /// Scales with the question's own [timeLimit] so the bot never eats an
  /// unfair share of short rounds (grammar questions give 20s, others 15s).
  static int reactionSecondsForTrophies(int userTrophies, {int timeLimit = 15}) {
    final base = userTrophies >= 800
        ? 2 + _rng.nextInt(4) // 2–5s (fast)
        : 3 + _rng.nextInt(5); // 3–7s
    final scaled = (base * (timeLimit / 15.0)).round();
    // Always leave the player at least 2s of theoretical headroom.
    return scaled.clamp(2, max(2, timeLimit - 2));
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
      // Pick one of the incorrect options — built from the ACTUAL option
      // count (some grammar questions have 2-3 options; a hardcoded
      // [0,1,2,3] could select a non-existent index).
      final wrongOptions = [
        for (var i = 0; i < question.options.length; i++)
          if (i != question.correctAnswer) i,
      ];
      chosenAnswer = wrongOptions.isEmpty
          ? question.correctAnswer
          : wrongOptions[_rng.nextInt(wrongOptions.length)];
    }

    final int reactionSeconds = reactionSecondsForTrophies(
      userTrophies,
      timeLimit: question.timeLimit > 0 ? question.timeLimit : 15,
    );

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
