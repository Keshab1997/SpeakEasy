import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/battle_models.dart';

/// Result of applying a finished battle to local stats.
class BattleMatchOutcome {
  final BattleStats stats;
  final int trophyDelta; // actually applied (after shield/floor)
  final bool shielded; // loss-streak shield triggered (no trophies lost)
  final bool comeback; // comeback bonus applied (+30 win)

  const BattleMatchOutcome({
    required this.stats,
    required this.trophyDelta,
    this.shielded = false,
    this.comeback = false,
  });
}

class BattleGameService {
  static const String _hiveBoxName = 'battle_arena_stats';

  // Battle questions are DRAWN FROM THE LEARNING ASSETS (not the daily quiz):
  //   • Grammar     -> Mock Test question bank   (assets/json/mock_tests/*.json)
  //   • Verbs       -> Verb forms quiz            (assets/json/verb_forms/*.json)
  //   • Vocabulary  -> Vocabulary chapters        (assets/json/vocabulary/**/*.json)
  static const int _mockTestCount = 70; // mock_test_01 .. mock_test_70
  static const List<String> _verbFiles = [
    'common_verbs',
    'irregular_verbs',
    'action_verbs',
    'communication',
    'daily_routine',
    'movement',
    'mental_verbs',
    'emotion_verbs',
    'education_verbs',
    'travel_verbs',
    'work_verbs',
  ];
  static const List<String> _vocabChapterPaths = [
    'assets/json/vocabulary/Beginner',
    'assets/json/vocabulary/Intermediate',
    'assets/json/vocabulary/Advanced',
  ];

  static List<BattleQuestion>? _cachedQuestions;

  /// Loads 5 curated questions: 2 Grammar (mock tests), 2 Vocabulary, 1 Verb.
  /// Questions are generated from the app's learning content so the battle
  /// feels like a real review of lessons rather than the daily quiz bank.
  static Future<List<BattleQuestion>> loadCuratedQuestions() async {
    final pool = await _loadQuestionPool();

    final rng = Random();
    List<BattleQuestion> pick(String category, int count) {
      final list = pool.where((q) => q.category == category).toList()
        ..shuffle(rng);
      return list.take(count).toList();
    }

    final selected = <BattleQuestion>[
      ...pick('grammar', 2), // Mock tests
      ...pick('vocabulary', 2), // Vocabulary chapters
      ...pick('verb', 1), // Verb forms
    ];

    // Top up from anything available if a category ran short.
    if (selected.length < 5) {
      final remaining =
          pool.where((q) => !selected.any((s) => s.id == q.id)).toList()
            ..shuffle(rng);
      selected.addAll(remaining.take(5 - selected.length));
    }

    selected.shuffle(rng);
    return selected.take(5).toList();
  }

  /// Builds (and caches) the full battle question pool from the three sources.
  static Future<List<BattleQuestion>> _loadQuestionPool() async {
    if (_cachedQuestions != null && _cachedQuestions!.isNotEmpty) {
      return _cachedQuestions!;
    }

    final all = <BattleQuestion>[];

    // 1) Grammar — from mock tests (ready-made MCQs).
    for (var i = 1; i <= _mockTestCount; i++) {
      final path =
          'assets/json/mock_tests/mock_test_${i.toString().padLeft(2, '0')}.json';
      try {
        final raw = await rootBundle.loadString(path);
        final data = json.decode(raw) as Map<String, dynamic>;
        final questions = (data['questions'] as List<dynamic>? ?? []);
        for (var idx = 0; idx < questions.length; idx++) {
          final q = questions[idx] as Map<String, dynamic>;
          final options = (q['options'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();
          // Mock tests use 'correctIndex' (fallback 'correctAnswer').
          final correct =
              (q['correctIndex'] ?? q['correctAnswer'] ?? 0) as num;
          if (options.length < 2) continue;
          all.add(BattleQuestion(
            id: 'mock_${i}_$idx',
            question: (q['question'] ?? '').toString(),
            bangla: (q['bangla'] ?? '').toString(),
            options: options,
            correctAnswer: correct.toInt().clamp(0, options.length - 1),
            explanation: (q['explanation'] ?? '').toString(),
            category: 'grammar',
            timeLimit: 20,
          ));
        }
      } catch (_) {
        // Missing/empty mock file — skip it.
      }
    }

    // 2) Verbs — generate "choose the right form" MCQs from verb lists.
    for (final name in _verbFiles) {
      try {
        final raw =
            await rootBundle.loadString('assets/json/verb_forms/$name.json');
        final list = json.decode(raw) as List<dynamic>;
        final verbs = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((m) =>
                (m['v1'] ?? '').toString().trim().isNotEmpty &&
                (m['v2'] ?? '').toString().trim().isNotEmpty)
            .toList();
        if (verbs.length < 4) continue;

        // One stable shuffled pool of V2 forms used for distractors.
        final v2pool = verbs
            .map((m) => (m['v2'] ?? '').toString().trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..shuffle();

        for (var v = 0; v < verbs.length; v++) {
          final verb = verbs[v];
          final v1 = (verb['v1'] ?? '').toString().trim();
          final v2 = (verb['v2'] ?? '').toString().trim();
          final bangla = (verb['bangla'] ?? '').toString();

          final distractors = v2pool
              .where((c) => c.toLowerCase() != v2.toLowerCase())
              .take(3)
              .toList();
          if (distractors.length < 3) continue;

          final options = <String>[v2, ...distractors]..shuffle();
          all.add(BattleQuestion(
            id: 'verb_${name}_$v',
            question: 'Past form (V2) of "$v1" is —',
            bangla: bangla.isNotEmpty ? '"$v1" ($bangla) এর past form কোনটি?' : '',
            options: options,
            correctAnswer: options.indexWhere((o) => o == v2),
            explanation:
                '$v1 → $v2 → ${(verb['v3'] ?? '').toString().trim()}  (${(verb['meaning'] ?? '').toString()})',
            category: 'verb',
            timeLimit: 15,
          ));
        }
      } catch (_) {}
    }

    // 3) Vocabulary — "English word → Bengali meaning" MCQs (same style as the
    //    in-app Vocab Test), generated from every chapter's word list.
    final allWords = <Map<String, dynamic>>[];
    for (final dir in _vocabChapterPaths) {
      // Chapters are named chapter_XX_*.json; load via AssetManifest is heavy,
      // so we rely on a known manifest list if present, else scan common names.
      try {
        final manifest =
            await rootBundle.loadString('AssetManifest.json');
        final map = json.decode(manifest) as Map<String, dynamic>;
        for (final key in map.keys) {
          if (key.startsWith(dir) && key.endsWith('.json')) {
            try {
              final raw = await rootBundle.loadString(key);
              final data = json.decode(raw) as Map<String, dynamic>;
              final words = (data['words'] as List<dynamic>? ?? []);
              for (final w in words) {
                final m = Map<String, dynamic>.from(w as Map);
                final word = (m['word'] ?? '').toString().trim();
                final meaning = (m['banglaMeaning'] ?? '').toString().trim();
                if (word.isNotEmpty && meaning.isNotEmpty) {
                  allWords.add(m);
                }
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    // Stable shuffled meaning pool for vocab distractors.
    final meaningPool = allWords
        .map((w) => (w['banglaMeaning'] ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..shuffle();

    for (var i = 0; i < allWords.length; i++) {
      final w = allWords[i];
      final word = (w['word'] ?? '').toString().trim();
      final meaning = (w['banglaMeaning'] ?? '').toString().trim();
      if (word.isEmpty || meaning.isEmpty) continue;

      final distractors = meaningPool
          .where((c) => c != meaning)
          .take(3)
          .toList();
      if (distractors.length < 3) continue;

      final options = <String>[meaning, ...distractors]..shuffle();
      all.add(BattleQuestion(
        id: 'vocab_$i',
        question: '"$word" এর বাংলা অর্থ কী?',
        bangla: (w['pronunciation'] ?? '').toString(),
        options: options,
        correctAnswer: options.indexWhere((o) => o == meaning),
        explanation:
            '$word = $meaning${(w['exampleSentence'] ?? '').toString().isNotEmpty ? '\nExample: ${w['exampleSentence']}' : ''}',
        category: 'vocabulary',
        timeLimit: 15,
      ));
    }

    if (all.isEmpty) {
      // Absolute safety net if assets failed to load.
      _cachedQuestions = _getFallbackQuestions();
    } else {
      _cachedQuestions = all;
    }
    return _cachedQuestions!;
  }

  /// Calculates round score with speed bonus.
  /// Speed bonus scales with the question's own time limit (default 15s):
  /// answering instantly gives ~150, answering at the buzzer gives 100.
  static int calculateRoundScore({
    required bool isCorrect,
    required int timeTakenSeconds,
    int roundTimeLimit = 15,
  }) {
    if (!isCorrect) return 0;
    final limit = roundTimeLimit > 0 ? roundTimeLimit : 15;
    final clampedTime = timeTakenSeconds.clamp(0, limit);
    final speedBonus = ((limit - clampedTime) * (50 / limit)).round(); // 0 to 50
    return 100 + speedBonus; // 100 to 150 points
  }

  // ── Trophy economy (mirrors the Cloud Function rules) ──
  static const int trophyWin = 25;
  static const int trophyLoss = -10;
  static const int trophyDraw = 5;
  static const int comebackBonus = 5; // win below 100 trophies => +30
  static const int comebackThreshold = 100;
  static const int lossShieldAfter = 3; // 4th straight loss is free

  /// Simple delta kept for reference; prefer [saveMatchResult] which applies
  /// shields, comeback bonus and division floors.
  static int calculateTrophyDelta({required bool isWin, required bool isDraw}) {
    if (isDraw) return trophyDraw;
    return isWin ? trophyWin : trophyLoss;
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
  /// Also syncs trophies to Firestore presence doc for immediate Firebase visibility
  /// Applies the result to local Hive stats with the full trophy rule set
  /// (comeback bonus, loss-streak shield, division floor, rookie floor at 0).
  /// Mirrors the server Cloud Function so the instant local UI matches.
  static Future<BattleMatchOutcome> saveMatchResult({
    required bool isWin,
    required bool isDraw,
    required int score,
    String? userId,
  }) async {
    final box = await Hive.openBox(_hiveBoxName);
    final current = await getLocalStats();

    var applied = 0;
    var shielded = false;
    var comeback = false;
    var lossStreak = current.lossStreak;

    if (isWin) {
      lossStreak = 0;
      comeback = current.trophies < comebackThreshold;
      applied = trophyWin + (comeback ? comebackBonus : 0); // 25 or 30
    } else if (isDraw) {
      applied = trophyDraw; // loss streak held
    } else {
      // Loss — every 4th straight loss is free (loss-streak shield).
      if (lossStreak >= lossShieldAfter) {
        shielded = true;
        applied = 0;
        lossStreak = 0;
      } else {
        applied = trophyLoss;
        lossStreak += 1;
      }
    }

    final floor = current.divisionFloor; // rank protection
    final newTrophies = max(0, max(floor, current.trophies + applied));

    final updated = BattleStats(
      totalMatches: current.totalMatches + 1,
      wins: isWin ? current.wins + 1 : current.wins,
      losses: (!isWin && !isDraw) ? current.losses + 1 : current.losses,
      winStreak: isWin
          ? current.winStreak + 1
          : (isDraw ? current.winStreak : 0),
      lossStreak: lossStreak,
      trophies: newTrophies,
    );

    await box.put('stats', updated.toMap());

    // NOTE: The Cloud Function `onBattleRoomWrite` is the source of truth for
    // the SHARED/online trophies & leaderboard; this local Hive record only
    // drives the instant on-device UI (bot matches + immediate feedback).

    return BattleMatchOutcome(
      stats: updated,
      trophyDelta: newTrophies - current.trophies,
      shielded: shielded,
      comeback: comeback,
    );
  }

  static List<BattleQuestion> _getFallbackQuestions() {
    return const [
      BattleQuestion(
        id: 'fb_1',
        question: 'What is the meaning of \'Abundant\'?',
        bangla: '\'Abundant\' শব্দটির অর্থ কী?',
        options: ['সীমিত', 'প্রচুর (Plentiful)', 'দুর্লভ', 'ক্ষীণ'],
        correctAnswer: 1,
        explanation: '\'Abundant\' means plentiful or in large supply.',
        category: 'vocabulary',
      ),
      BattleQuestion(
        id: 'fb_2',
        question: 'She is good ____ English.',
        bangla: 'সঠিক preposition বসান:',
        options: ['in', 'at', 'with', 'on'],
        correctAnswer: 1,
        explanation: 'Good at is the correct idiom.',
        category: 'grammar',
      ),
      BattleQuestion(
        id: 'fb_3',
        question: 'If I ____ hard, I would pass.',
        bangla: 'সঠিক verb রূপ বাছুন:',
        options: ['study', 'studied', 'studying', 'had studied'],
        correctAnswer: 1,
        explanation: 'Second conditional: If + Past Simple, would + V1.',
        category: 'grammar',
      ),
      BattleQuestion(
        id: 'fb_4',
        question: 'How do you ask for the bill at a restaurant?',
        bangla: 'রেস্টুরেন্টে বিল কীভাবে চাইবেন?',
        options: ['Give bill', 'Pay now', 'Could we have the bill, please?', 'Bill quick'],
        correctAnswer: 2,
        explanation: 'Polite request using \'Could we...\'',
        category: 'conversation',
      ),
      BattleQuestion(
        id: 'fb_5',
        question: 'What is the antonym of \'Genuine\'?',
        bangla: '\'Genuine\' শব্দের বিপরীত শব্দ কোনটি?',
        options: ['Real', 'Pure', 'Fake', 'True'],
        correctAnswer: 2,
        explanation: 'Genuine means real, opposite is Fake.',
        category: 'vocabulary',
      ),
    ];
  }
}
