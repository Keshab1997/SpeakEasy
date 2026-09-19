import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'battle_game_service.dart';

/// Season: 30 days, trophies reset to 1000 + 30% of above-1000 retained.
/// Grandmaster stuck fix: every 30 days season resets, rewards given.
/// Example: 1800 trophies → 1000 + (800*0.3)=1240 for next season.
class BattleSeasonService {
  static const String _hiveBoxName = 'battle_arena_stats';
  static const String _seasonStartKey = 'seasonStartMs';
  static const String _seasonNumberKey = 'seasonNumber';
  static const Duration seasonDuration = Duration(days: 30);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns days remaining in current season (0 if expired).
  Future<int> getDaysRemaining() async {
    final box = await Hive.openBox(_hiveBoxName);
    final startMs = box.get(_seasonStartKey) as int?;
    if (startMs == null) {
      // First season starts now
      await box.put(_seasonStartKey, DateTime.now().millisecondsSinceEpoch);
      await box.put(_seasonNumberKey, 1);
      return seasonDuration.inDays;
    }
    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    final elapsed = DateTime.now().difference(start);
    final remaining = seasonDuration - elapsed;
    return remaining.inDays.clamp(0, 30);
  }

  Future<int> getSeasonNumber() async {
    final box = await Hive.openBox(_hiveBoxName);
    return (box.get(_seasonNumberKey) as int?) ?? 1;
  }

  /// Checks if season expired and resets trophies if needed.
  /// Returns null if no reset, otherwise returns (oldTrophies -> newTrophies, rewardCoins).
  Future<SeasonResetResult?> checkAndResetIfNeeded(String userId) async {
    final box = await Hive.openBox(_hiveBoxName);
    final startMs = box.get(_seasonStartKey) as int?;
    if (startMs == null) {
      await box.put(_seasonStartKey, DateTime.now().millisecondsSinceEpoch);
      await box.put(_seasonNumberKey, 1);
      return null;
    }
    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    if (DateTime.now().difference(start) < seasonDuration) return null;

    // Season expired — calculate new trophies
    final stats = await BattleGameService.getLocalStats();
    final oldTrophies = stats.trophies;
    int newTrophies;
    int rewardCoins = 0;
    String rewardTitle = '';

    if (oldTrophies >= 1500) {
      newTrophies = 1000 + ((oldTrophies - 1000) * 0.3).round();
      rewardCoins = 500;
      rewardTitle = 'Grandmaster Chest 💎';
    } else if (oldTrophies >= 800) {
      newTrophies = 800 + ((oldTrophies - 800) * 0.4).round();
      rewardCoins = 300;
      rewardTitle = 'Master Chest 🥇';
    } else if (oldTrophies >= 300) {
      newTrophies = 300 + ((oldTrophies - 300) * 0.5).round();
      rewardCoins = 150;
      rewardTitle = 'Challenger Chest 🥈';
    } else {
      newTrophies = oldTrophies; // Novice no reset, just new season
      rewardCoins = 50;
      rewardTitle = 'Novice Reward 🥉';
    }
    newTrophies = newTrophies.clamp(100, 2000);

    // Update Hive
    final newSeason = ((box.get(_seasonNumberKey) as int?) ?? 1) + 1;
    await box.put(_seasonStartKey, DateTime.now().millisecondsSinceEpoch);
    await box.put(_seasonNumberKey, newSeason);

    // Update presence doc (client can update own presence)
    try {
      await _firestore.collection('battle_presence').doc(userId).set({
        'trophies': newTrophies,
        'seasonResetAt': FieldValue.serverTimestamp(),
        'lastSeasonReward': rewardTitle,
      }, SetOptions(merge: true));
    } catch (_) {}

    // Also update local stats via game service (fire-and-forget)
    // The next server sync will adopt presence trophies
    return SeasonResetResult(
      oldTrophies: oldTrophies,
      newTrophies: newTrophies,
      rewardCoins: rewardCoins,
      rewardTitle: rewardTitle,
      seasonNumber: newSeason,
    );
  }
}

class SeasonResetResult {
  final int oldTrophies;
  final int newTrophies;
  final int rewardCoins;
  final String rewardTitle;
  final int seasonNumber;
  const SeasonResetResult({
    required this.oldTrophies,
    required this.newTrophies,
    required this.rewardCoins,
    required this.rewardTitle,
    required this.seasonNumber,
  });
}
