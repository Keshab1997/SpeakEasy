import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/battle_models.dart';

class BattleGameService {
  static const String _questionsPath = 'assets/json/daily_quiz/questions.json';
  static const String _hiveBoxName = 'battle_arena_stats';

  static List<BattleQuestion>? _cachedQuestions;

  /// Loads 5 curated questions (2 Vocab, 2 Grammar, 1 Conversation)
  static Future<List<BattleQuestion>> loadCuratedQuestions() async {
    if (_cachedQuestions == null || _cachedQuestions!.isEmpty) {
      try {
        final jsonStr = await rootBundle.loadString(_questionsPath);
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        final List<dynamic> qList = data['questions'] ?? [];

        _cachedQuestions = qList.map((item) {
          final map = item as Map<String, dynamic>;
          return BattleQuestion(
            id: map['id'] ?? 'dq_${Random().nextInt(1000)}',
            question: map['question'] ?? '',
            bangla: map['bangla'] ?? '',
            options: List<String>.from(map['options'] ?? []),
            correctAnswer: (map['correctAnswer'] as num?)?.toInt() ?? 0,
            explanation: map['explanation'] ?? '',
            category: map['category'] ?? map['type'] ?? 'grammar',
            timeLimit: 15, // Standard 15 seconds per round
          );
        }).toList();
      } catch (e) {
        // Fallback default questions if asset fails
        _cachedQuestions = _getFallbackQuestions();
      }
    }

    final rng = Random();
    final vocab = _cachedQuestions!
        .where((q) => q.category.toLowerCase().contains('vocab'))
        .toList()
      ..shuffle(rng);
    final grammar = _cachedQuestions!
        .where((q) => q.category.toLowerCase().contains('gram'))
        .toList()
      ..shuffle(rng);
    final conv = _cachedQuestions!
        .where((q) => q.category.toLowerCase().contains('conv'))
        .toList()
      ..shuffle(rng);

    final selected = <BattleQuestion>[];

    // Pick 2 Vocab
    selected.addAll(vocab.take(2));
    // Pick 2 Grammar
    selected.addAll(grammar.take(2));
    // Pick 1 Conversation
    selected.addAll(conv.take(1));

    // If any category didn't have enough, fill from remaining
    if (selected.length < 5) {
      final remaining = _cachedQuestions!.where((q) => !selected.contains(q)).toList()..shuffle(rng);
      selected.addAll(remaining.take(5 - selected.length));
    }

    selected.shuffle(rng);
    return selected;
  }

  /// Calculates round score with speed bonus
  static int calculateRoundScore({required bool isCorrect, required int timeTakenSeconds}) {
    if (!isCorrect) return 0;
    // Base 100 points
    final clampedTime = timeTakenSeconds.clamp(0, 15);
    final speedBonus = ((15 - clampedTime) * 3.33).round(); // 0 to 50
    return 100 + speedBonus; // 100 to 150 points
  }

  /// Calculates trophy changes: Winner +25, Loser -10 (cannot drop below 0)
  static int calculateTrophyDelta({required bool isWin, required bool isDraw}) {
    if (isDraw) return 5;
    return isWin ? 25 : -10;
  }

  /// Gets local battle stats from Hive
  static Future<BattleStats> getLocalStats() async {
    final box = await Hive.openBox(_hiveBoxName);
    final map = box.get('stats');
    if (map != null) {
      return BattleStats.fromMap(Map<String, dynamic>.from(map));
    }
    return const BattleStats(
      totalMatches: 0,
      wins: 0,
      losses: 0,
      winStreak: 0,
      trophies: 100,
    );
  }

  /// Updates battle stats after match
  static Future<BattleStats> saveMatchResult({
    required bool isWin,
    required bool isDraw,
    required int score,
  }) async {
    final box = await Hive.openBox(_hiveBoxName);
    final current = await getLocalStats();
    final trophyDelta = calculateTrophyDelta(isWin: isWin, isDraw: isDraw);
    final newTrophies = max(0, current.trophies + trophyDelta);

    final updated = BattleStats(
      totalMatches: current.totalMatches + 1,
      wins: isWin ? current.wins + 1 : current.wins,
      losses: (!isWin && !isDraw) ? current.losses + 1 : current.losses,
      winStreak: isWin ? current.winStreak + 1 : 0,
      trophies: newTrophies,
    );

    await box.put('stats', updated.toMap());
    return updated;
  }

  static List<BattleQuestion> _getFallbackQuestions() {
    return const [
      BattleQuestion(
        id: 'fb_1',
        question: "What is the meaning of 'Abundant'?",
        bangla: "'Abundant' শব্দটির অর্থ কী?",
        options: ["সীমিত", "প্রচুর (Plentiful)", "দুর্লভ", "ক্ষীণ"],
        correctAnswer: 1,
        explanation: "'Abundant' means plentiful or in large supply.",
        category: 'vocabulary',
      ),
      BattleQuestion(
        id: 'fb_2',
        question: "She is good ____ English.",
        bangla: "সঠিক preposition বসান:",
        options: ["in", "at", "with", "on"],
        correctAnswer: 1,
        explanation: "Good at is the correct idiom.",
        category: 'grammar',
      ),
      BattleQuestion(
        id: 'fb_3',
        question: "If I ____ hard, I would pass.",
        bangla: "সঠিক verb রূপ বাছুন:",
        options: ["study", "studied", "studying", "had studied"],
        correctAnswer: 1,
        explanation: "Second conditional: If + Past Simple, would + V1.",
        category: 'grammar',
      ),
      BattleQuestion(
        id: 'fb_4',
        question: "How do you ask for the bill at a restaurant?",
        bangla: "রেস্টুরেন্টে বিল কীভাবে চাইবেন?",
        options: ["Give bill", "Pay now", "Could we have the bill, please?", "Bill quick"],
        correctAnswer: 2,
        explanation: "Polite request using 'Could we...'",
        category: 'conversation',
      ),
      BattleQuestion(
        id: 'fb_5',
        question: "What is the antonym of 'Genuine'?",
        bangla: "'Genuine' শব্দের বিপরীত শব্দ কোনটি?",
        options: ["Real", "Pure", "Fake", "True"],
        correctAnswer: 2,
        explanation: "Genuine means real, opposite is Fake.",
        category: 'vocabulary',
      ),
    ];
  }
}
