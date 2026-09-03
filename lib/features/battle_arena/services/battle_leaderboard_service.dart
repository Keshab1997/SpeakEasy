import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/battle_models.dart';

/// One row on the battle leaderboard.
class LeaderboardEntry {
  final String userId;
  final String name;
  final String photoUrl;
  final int trophies;
  final int wins;
  final int losses;
  final int draws;
  final int totalMatches;
  final int winStreak;
  final int bestStreak;
  final int rank; // 1-based, filled after sorting

  const LeaderboardEntry({
    required this.userId,
    required this.name,
    this.photoUrl = '',
    this.trophies = 100,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.totalMatches = 0,
    this.winStreak = 0,
    this.bestStreak = 0,
    this.rank = 0,
  });

  double get winRate => totalMatches == 0 ? 0 : wins / totalMatches * 100;

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map, String docId,
      {int rank = 0}) {
    return LeaderboardEntry(
      userId: docId,
      name: map['name'] ?? 'Player',
      photoUrl: map['photoUrl'] ?? '',
      trophies: (map['trophies'] as num?)?.toInt() ?? 100,
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      losses: (map['losses'] as num?)?.toInt() ?? 0,
      draws: (map['draws'] as num?)?.toInt() ?? 0,
      totalMatches: (map['totalMatches'] as num?)?.toInt() ?? 0,
      winStreak: (map['winStreak'] as num?)?.toInt() ?? 0,
      bestStreak: (map['bestStreak'] as num?)?.toInt() ?? 0,
      rank: rank,
    );
  }
}

/// Reads the battle leaderboard. Uses a ONE-TIME query (no live listener) plus
/// a short in-memory cache to keep Firestore reads cheap: opening the board
/// costs ~50 reads max, and re-opens within the TTL cost nothing.
class BattleLeaderboardService {
  static const String _collection = 'battle_leaderboard';
  static const int _limit = 50;
  static const Duration _cacheTtl = Duration(minutes: 5);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<LeaderboardEntry>? _cache;
  DateTime? _cachedAt;

  Future<List<LeaderboardEntry>> getTopPlayers({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cache != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return _cache!;
    }

    try {
      final snap = await _firestore
          .collection(_collection)
          .orderBy('trophies', descending: true)
          .limit(_limit)
          .get();

      final entries = <LeaderboardEntry>[];
      for (var i = 0; i < snap.docs.length; i++) {
        entries.add(
          LeaderboardEntry.fromMap(snap.docs[i].data(), snap.docs[i].id,
              rank: i + 1),
        );
      }

      _cache = entries;
      _cachedAt = DateTime.now();
      return entries;
    } catch (e) {
      // If offline / permission error, return stale cache or empty — caller
      // will fall back to local Hive stats.
      if (_cache != null) return _cache!;
      return [];
    }
  }

  /// Returns the caller's own rank/entry, or null if they've never played a
  /// ranked (online) match. Counts how many players are above them.
  Future<LeaderboardEntry?> getMyRank(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (!doc.exists) return null;

      // Number of players with more trophies = rank offset.
      final myTrophies = (doc.data()?['trophies'] as num?)?.toInt() ?? 0;
      final above = await _firestore
          .collection(_collection)
          .where('trophies', isGreaterThan: myTrophies)
          .get();
      return LeaderboardEntry.fromMap(doc.data()!, doc.id, rank: above.size + 1);
    } catch (_) {
      return null;
    }
  }

  /// Fetches a single opponent's career stats (for the profile card).
  /// Tries `battle_leaderboard` first (server-authoritative for online ranked
  /// matches), then falls back to `battle_presence` (live presence + bot stats).
  /// Merges both so the card never shows only trophies.
  Future<BattlePresenceUser?> getPlayerProfile(String userId) async {
    try {
      // 1) Try authoritative leaderboard entry (has wins/losses/draws).
      final lbDoc = await _firestore.collection(_collection).doc(userId).get();
      BattlePresenceUser? lbUser;
      if (lbDoc.exists && lbDoc.data() != null) {
        final d = lbDoc.data()!;
        lbUser = BattlePresenceUser(
          id: userId,
          name: d['name'] ?? 'Player',
          photoUrl: d['photoUrl'] ?? '',
          trophies: (d['trophies'] as num?)?.toInt() ?? 100,
          isOnline: true,
          lastActive: DateTime.now(),
          isInBattle: false,
          wins: (d['wins'] as num?)?.toInt() ?? 0,
          losses: (d['losses'] as num?)?.toInt() ?? 0,
          draws: (d['draws'] as num?)?.toInt() ?? 0,
          totalMatches: (d['totalMatches'] as num?)?.toInt() ?? 0,
          winStreak: (d['winStreak'] as num?)?.toInt() ?? 0,
        );
      }

      // 2) Always also fetch presence (has live online/battle flag + newer trophies).
      final presenceDoc =
          await _firestore.collection('battle_presence').doc(userId).get();
      if (!presenceDoc.exists) return lbUser;
      final p = BattlePresenceUser.fromMap(presenceDoc.data()!, presenceDoc.id);

      // 3) Merge: leaderboard wins/stats take precedence, but presence
      // trophies/photo/name are fresher for the live card.
      if (lbUser == null) return p;
      return BattlePresenceUser(
        id: p.id,
        name: p.name.isNotEmpty ? p.name : lbUser.name,
        photoUrl: p.photoUrl.isNotEmpty ? p.photoUrl : lbUser.photoUrl,
        trophies: p.trophies != 100 || lbUser.trophies == 100
            ? p.trophies
            : lbUser.trophies,
        isOnline: p.isOnline,
        lastActive: p.lastActive,
        isInBattle: p.isInBattle,
        wins: lbUser.wins != 0 ? lbUser.wins : p.wins,
        losses: lbUser.losses != 0 ? lbUser.losses : p.losses,
        draws: lbUser.draws != 0 ? lbUser.draws : p.draws,
        totalMatches: lbUser.totalMatches != 0 ? lbUser.totalMatches : p.totalMatches,
        winStreak: lbUser.winStreak != 0 ? lbUser.winStreak : p.winStreak,
      );
    } catch (_) {
      return null;
    }
  }

  /// Direct fetch of a leaderboard entry as [LeaderboardEntry].
  Future<LeaderboardEntry?> getLeaderboardEntry(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      final myTrophies = (doc.data()?['trophies'] as num?)?.toInt() ?? 0;
      final above = await _firestore
          .collection(_collection)
          .where('trophies', isGreaterThan: myTrophies)
          .get();
      return LeaderboardEntry.fromMap(doc.data()!, doc.id, rank: above.size + 1);
    } catch (_) {
      return null;
    }
  }
}
