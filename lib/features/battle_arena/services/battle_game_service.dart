import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Pool bucketed by category so `pick()` is O(1) instead of filtering the
  /// whole pool on every match. Built once alongside [_cachedQuestions].
  static Map<String, List<BattleQuestion>>? _cachedByCategory;

  /// The parsed pool is static asset content, but we still re-parse after a
  /// TTL so hot-reloaded / OTA asset changes are picked up and we don't pin
  /// a huge list forever if the process lives a long time.
  static DateTime? _cachedAt;
  static const Duration _cacheTtl = Duration(minutes: 5);

  static bool get _cacheValid =>
      _cachedQuestions != null &&
      _cachedQuestions!.isNotEmpty &&
      _cachedAt != null &&
      DateTime.now().difference(_cachedAt!) < _cacheTtl;

  /// Question-set version stored on seed rooms. Bump it whenever the pool
  /// construction changes so old rooms keep generating their original set.
  static const int questionSetVersion = 1;

  /// Loads 5 curated questions: 2 Grammar (mock tests), 2 Vocabulary, 1 Verb.
  /// Questions are generated from the app's learning content so the battle
  /// feels like a real review of lessons rather than the daily quiz bank.
  static Future<List<BattleQuestion>> loadCuratedQuestions() async {
    return generateSeededQuestions(Random().nextInt(0x7FFFFFFF));
  }

  /// Warms the question-pool cache without selecting anything.
  static Future<void> ensurePoolLoaded() => _loadQuestionPool().then((_) {});

  /// DETERMINISTIC question selection for SEED rooms. Both players (and the
  /// anti-cheat Cloud Function's data) derive the same 5 questions from the
  /// shared seed, so the room doc itself carries only the seed — never the
  /// correct answers. Determinism requires:
  ///   • the pool built in a fixed order (asset iteration is stable) with
  ///     seeded distractor shuffles (see _loadQuestionPool), and
  ///   • Dart's `Random(seed)`, which is reproducible across platforms.
  static Future<List<BattleQuestion>> generateSeededQuestions(
    int seed, {
    int count = 5,
  }) async {
    await _loadQuestionPool();
    final byCategory = _cachedByCategory ?? const <String, List<BattleQuestion>>{};
    final pool = _cachedQuestions ?? const <BattleQuestion>[];

    final rng = Random(seed);
    List<BattleQuestion> pick(String category, int n) {
      final list = List<BattleQuestion>.from(byCategory[category] ?? const [])
        ..shuffle(rng);
      return list.take(n).toList();
    }

    final selected = <BattleQuestion>[
      ...pick('grammar', 2), // Mock tests
      ...pick('vocabulary', 2), // Vocabulary chapters
      ...pick('verb', 1), // Verb forms
    ];

    // Top up from anything available if a category ran short.
    if (selected.length < count) {
      final selectedIds = selected.map((s) => s.id).toSet();
      final remaining =
          pool.where((q) => !selectedIds.contains(q.id)).toList()..shuffle(rng);
      selected.addAll(remaining.take(count - selected.length));
    }

    selected.shuffle(rng);
    return selected.take(count).toList();
  }

  /// Builds (and caches) the full battle question pool from the three sources.
  /// Bucketed by category and reused until the TTL expires.
  static Future<List<BattleQuestion>> _loadQuestionPool() async {
    if (_cacheValid) {
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
        // FIXED-SEED shuffle: seed rooms regenerate questions on two
        // devices — every device must build byte-identical options.
        final v2pool = verbs
            .map((m) => (m['v2'] ?? '').toString().trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..shuffle(Random(987654321));

        // Deterministic option order across devices (seed rooms).
        final verbOptionRng = Random(555555);
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

          final options = <String>[v2, ...distractors]..shuffle(verbOptionRng);
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
    //    AssetManifest is parsed ONCE (previously once per chapter dir = 3×).
    final allWords = <Map<String, dynamic>>[];
    Map<String, dynamic>? assetManifest;
    try {
      final manifest = await rootBundle.loadString('AssetManifest.json');
      assetManifest = json.decode(manifest) as Map<String, dynamic>;
    } catch (_) {}

    if (assetManifest != null) {
      for (final dir in _vocabChapterPaths) {
        for (final key in assetManifest.keys) {
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
      }
    }

    // Stable shuffled meaning pool for vocab distractors.
    // FIXED-SEED shuffle — required for cross-device seed-room determinism.
    final meaningPool = allWords
        .map((w) => (w['banglaMeaning'] ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..shuffle(Random(123456789));

    // Deterministic option order across devices (seed rooms).
    final vocabOptionRng = Random(444444);
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

      final options = <String>[meaning, ...distractors]..shuffle(vocabOptionRng);
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

    // Bucket by category once so per-match selection is O(1) per category.
    _cachedByCategory = {};
    for (final q in _cachedQuestions!) {
      _cachedByCategory!.putIfAbsent(q.category, () => []).add(q);
    }
    _cachedAt = DateTime.now();

    return _cachedQuestions!;
  }

  /// Pulls the authoritative battle stats (trophies + win/loss record) from
  /// the server `battle_presence` doc and overwrites the local Hive copy.
  ///
  /// The Cloud Function `onBattleRoomWrite` → `recordMatchResult` is the
  /// source of truth for shared trophies. The local Hive record is only an
  /// instant on-device preview; without re-syncing it drifts (e.g. server
  /// applies a forfeit/comeback the client never saw). Calling this when
  /// entering the arena and after an online match keeps them converged and
  /// prevents the lobby heartbeat from re-publishing a stale local trophy
  /// count over the server's value.
  static Future<BattleStats> syncStatsFromServer(String userId) async {
    if (userId.isEmpty || userId.startsWith('guest_') || userId.startsWith('bot_')) {
      return getLocalStats();
    }
    try {
      final doc =
          await FirebaseFirestore.instance.collection('battle_presence').doc(userId).get();
      if (!doc.exists) return getLocalStats();
      final d = doc.data();
      if (d == null) return getLocalStats();

      final local = await getLocalStats();
      final serverTrophies = (d['trophies'] as num?)?.toInt();
      if (serverTrophies == null) return local;

      final synced = BattleStats(
        totalMatches: (d['totalMatches'] as num?)?.toInt() ?? local.totalMatches,
        wins: (d['wins'] as num?)?.toInt() ?? local.wins,
        losses: (d['losses'] as num?)?.toInt() ?? local.losses,
        winStreak: (d['winStreak'] as num?)?.toInt() ?? local.winStreak,
        lossStreak: (d['lossStreak'] as num?)?.toInt() ?? local.lossStreak,
        trophies: serverTrophies,
      );

      final box = await Hive.openBox(_hiveBoxName);
      await box.put('stats', synced.toMap());
      return synced;
    } catch (_) {
      return getLocalStats();
    }
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
  /// [isOnline] true → server (Cloud Function) owns trophies/leaderboard, so
  /// we DON'T write presence here (avoids double-count). false (bot/offline)
  /// → we write presence immediately so the online list & profile card show
  /// the new trophies/wins without waiting for a server.
  static Future<BattleMatchOutcome> saveMatchResult({
    required bool isWin,
    required bool isDraw,
    required int score,
    String? userId,
    bool isOnline = false,
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

    // Sync to presence for bot/offline matches so the online roster & profile
    // cards (which read battle_presence) see the new trophies/wins instantly.
    // Online ranked matches are owned by the Cloud Function — don't write
    // here or the server's next transaction would double-count the delta.
    if (!isOnline && userId != null && userId.isNotEmpty && !userId.startsWith('guest_') && !userId.startsWith('bot_')) {
      try {
        await FirebaseFirestore.instance.collection('battle_presence').doc(userId).set({
          'id': userId,
          'trophies': newTrophies,
          'wins': updated.wins,
          'losses': updated.losses,
          // NOTE: deliberately NOT touching 'draws' / 'bestStreak' here —
          // Hive doesn't track them and writing 0/current-streak would wipe
          // the server-owned values earned in ranked online matches.
          'totalMatches': updated.totalMatches,
          'winStreak': updated.winStreak,
          'isOnline': true,
          'lastActive': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    // NOTE: For online matches the Cloud Function `onBattleRoomWrite` is the
    // source of truth for the SHARED trophies & leaderboard; this Hive record
    // only drives the instant on-device UI (bot matches + immediate feedback).

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
