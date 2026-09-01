import 'package:hive_flutter/hive_flutter.dart';

/// One finished battle (stored locally on the device via Hive — zero
/// Firestore cost, works offline).
class BattleHistoryRecord {
  final String opponentName;
  final bool isBot;
  final int myScore;
  final int opponentScore;
  final String result; // 'win' | 'loss' | 'draw'
  final int trophyDelta;
  final DateTime playedAt;
  final int perfectRounds; // rounds answered correctly (for badges)

  const BattleHistoryRecord({
    required this.opponentName,
    required this.isBot,
    required this.myScore,
    required this.opponentScore,
    required this.result,
    required this.trophyDelta,
    required this.playedAt,
    this.perfectRounds = 0,
  });

  Map<String, dynamic> toMap() => {
        'opponentName': opponentName,
        'isBot': isBot,
        'myScore': myScore,
        'opponentScore': opponentScore,
        'result': result,
        'trophyDelta': trophyDelta,
        'playedAt': playedAt.toIso8601String(),
        'perfectRounds': perfectRounds,
      };

  factory BattleHistoryRecord.fromMap(Map<dynamic, dynamic> map) {
    return BattleHistoryRecord(
      opponentName: map['opponentName'] ?? 'Opponent',
      isBot: map['isBot'] ?? false,
      myScore: (map['myScore'] as num?)?.toInt() ?? 0,
      opponentScore: (map['opponentScore'] as num?)?.toInt() ?? 0,
      result: map['result'] ?? 'draw',
      trophyDelta: (map['trophyDelta'] as num?)?.toInt() ?? 0,
      playedAt: DateTime.tryParse(map['playedAt'] ?? '') ?? DateTime.now(),
      perfectRounds: (map['perfectRounds'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Local-only battle history + derived achievements.
class BattleHistoryService {
  static const String _boxName = 'battle_history';
  static const String _recordsKey = 'records';
  static const int _maxRecords = 100;

  Future<Box> _openBox() => Hive.openBox(_boxName);

  Future<void> addRecord(BattleHistoryRecord record) async {
    final box = await _openBox();
    final raw = (box.get(_recordsKey) as List?) ?? [];
    final list = raw.map((e) => BattleHistoryRecord.fromMap(e)).toList()
      ..insert(0, record); // newest first
    // Trim to most recent N.
    final trimmed = list.take(_maxRecords).map((e) => e.toMap()).toList();
    await box.put(_recordsKey, trimmed);
  }

  Future<List<BattleHistoryRecord>> getRecords() async {
    final box = await _openBox();
    final raw = (box.get(_recordsKey) as List?) ?? [];
    return raw.map((e) => BattleHistoryRecord.fromMap(e)).toList();
  }

  Future<void> clear() async {
    final box = await _openBox();
    await box.delete(_recordsKey);
  }

  // ── Achievements (computed from local stats + history) ──────────────

  /// Returns the list of badge ids the player has earned given their stats.
  static List<String> earnedBadges({
    required int totalMatches,
    required int wins,
    required int winStreak,
    required int bestStreak,
    required List<BattleHistoryRecord> recent,
  }) {
    final badges = <String>[];
    if (wins >= 1) badges.add('first_blood');
    if (wins >= 10) badges.add('warrior_10');
    if (wins >= 50) badges.add('champion_50');
    if (wins >= 100) badges.add('legend_100');
    if (bestStreak >= 3) badges.add('streak_3');
    if (bestStreak >= 5) badges.add('on_fire_5');
    if (bestStreak >= 10) badges.add('unstoppable_10');
    if (totalMatches >= 25) badges.add('veteran_25');
    if (totalMatches >= 100) badges.add('centurion');
    // Flawless: won a match without a single wrong round (perfectRounds counts
    // rounds answered correctly; tracked by the provider when available).
    if (recent.any((r) => r.result == 'win' && r.myScore >= 700)) {
      badges.add('flawless');
    }
    // Comeback-ish: beat a bot/human by a wide margin.
    if (recent.any((r) => r.result == 'win' && r.myScore - r.opponentScore >= 300)) {
      badges.add('dominator');
    }
    return badges;
  }

  /// Static badge catalogue for UI (id → emoji, title, description).
  static const Map<String, Map<String, String>> badgeCatalog = {
    'first_blood': {'emoji': '🗡️', 'title': 'First Blood', 'desc': 'আপনার প্রথম battle জিতুন'},
    'warrior_10': {'emoji': '⚔️', 'title': 'Warrior', 'desc': '১০টি battle জিতুন'},
    'champion_50': {'emoji': '🏅', 'title': 'Champion', 'desc': '৫০টি battle জিতুন'},
    'legend_100': {'emoji': '👑', 'title': 'Legend', 'desc': '১০০টি battle জিতুন'},
    'streak_3': {'emoji': '🔥', 'title': 'Hot Streak', 'desc': 'পরপর ৩টি জয়'},
    'on_fire_5': {'emoji': '🌋', 'title': 'On Fire', 'desc': 'পরপর ৫টি জয়'},
    'unstoppable_10': {'emoji': '💎', 'title': 'Unstoppable', 'desc': 'পরপর ১০টি জয়'},
    'veteran_25': {'emoji': '🎖️', 'title': 'Veteran', 'desc': '২৫টি battle খেলুন'},
    'centurion': {'emoji': '🏛️', 'title': 'Centurion', 'desc': '১০০টি battle খেলুন'},
    'flawless': {'emoji': '✨', 'title': 'Flawless', 'desc': 'কোনো পয়েন্ট না হারিয়ে ম্যাচ জিতুন'},
    'dominator': {'emoji': '😤', 'title': 'Dominator', 'desc': '৩০০+ পয়েন্ট ব্যবধানে জিতুন'},
  };
}
