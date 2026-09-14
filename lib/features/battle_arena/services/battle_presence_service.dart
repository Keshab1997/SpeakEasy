import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import '../models/battle_models.dart';

/// Heartbeat interval. Kept short (20s) so a killed app is detected quickly:
/// the online-list filter drops a heartbeat stale after 3 minutes, and the
/// server auto-forfeit treats >90s of silence in battle as a disconnect.
const Duration kPresenceHeartbeatInterval = Duration(seconds: 20);

class BattlePresenceService with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _heartbeatTimer;
  bool _isInBattle = false;

  /// Identity of the user whose heartbeat we're running — needed by the
  /// lifecycle observer to flip presence instantly on pause/resume.
  String? _activeUserId;
  String _activeName = '';
  String _activePhoto = '';
  int _activeTrophies = 100;
  bool _observing = false;

  static const String _presenceCollection = 'battle_presence';
  static const String _challengesCollection = 'battle_challenges';

  /// Sets user online status in Firestore and starts heartbeat.
  /// The initial write includes trophies (needed for the presence create
  /// rule); the periodic heartbeat refreshes liveness only — trophies are
  /// owned server-side by the Cloud Function.
  void startPresenceHeartbeat({
    required String userId,
    required String name,
    required String photoUrl,
    required int trophies,
  }) {
    _activeUserId = userId;
    _activeName = name;
    _activePhoto = photoUrl;
    _activeTrophies = trophies;

    // Go offline instantly when the app is backgrounded/killed — no more
    // ~3-minute ghost-online window waiting for the heartbeat to go stale.
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }

    _updatePresence(
      userId: userId,
      name: name,
      photoUrl: photoUrl,
      trophies: trophies,
      isOnline: true,
      isInBattle: false,
    );

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(kPresenceHeartbeatInterval, (_) async {
      // Periodic heartbeat refreshes liveness only. Trophies are NOT written
      // here — the Cloud Function is the source of truth for presence
      // trophies, and writing Hive trophies here could stack on top of the
      // server's award (double count). The initial create above sets trophies.
      try {
        await _firestore.collection(_presenceCollection).doc(userId).set({
          'name': name.isEmpty ? 'Student' : name,
          'photoUrl': photoUrl,
          'isOnline': true,
          'isInBattle': _isInBattle,
          'lastActive': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    });
  }

  /// App backgrounded/killed → offline immediately; resumed → back online.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final userId = _activeUserId;
    if (userId == null || userId.isEmpty || userId.startsWith('guest_')) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _firestore.collection(_presenceCollection).doc(userId).set({
        'isOnline': false,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((_) {});
    } else if (state == AppLifecycleState.resumed) {
      _updatePresence(
        userId: userId,
        name: _activeName,
        photoUrl: _activePhoto,
        trophies: _activeTrophies,
        isOnline: true,
        isInBattle: _isInBattle,
      );
    }
  }

  /// Sets user offline when leaving battle arena
  Future<void> stopPresenceHeartbeat(String userId) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    _activeUserId = null;
    try {
      await _firestore.collection(_presenceCollection).doc(userId).set({
        'isOnline': false,
        'isInBattle': false,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Marks whether the user is currently inside a duel, so others don't
  /// challenge someone who is busy fighting.
  Future<void> setInBattle(String userId, bool inBattle) async {
    _isInBattle = inBattle;
    if (userId.isEmpty || userId.startsWith('guest_')) return;
    try {
      await _firestore.collection(_presenceCollection).doc(userId).set({
        'isInBattle': inBattle,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Stream of active online users (filtered for active in last 2 minutes)
  Stream<List<BattlePresenceUser>> streamOnlineUsers(String currentUserId) {
    return _firestore
        .collection(_presenceCollection)
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final users = <BattlePresenceUser>[];

      for (var doc in snapshot.docs) {
        if (doc.id == currentUserId) continue; // Don't show self in online list
        try {
          final user = BattlePresenceUser.fromMap(doc.data(), doc.id);
          // Only show users active within the last 3 minutes
          if (now.difference(user.lastActive).inMinutes <= 3) {
            users.add(user);
          }
        } catch (_) {}
      }

      // Sort by trophies descending
      users.sort((a, b) => b.trophies.compareTo(a.trophies));
      return users;
    });
  }

  /// Stream of RECENTLY ACTIVE players — warriors who are offline right now
  /// but opened the app within the last [activeWithinDays] days. These are
  /// the players who "don't come daily but play occasionally" and can still
  /// receive async challenges (delivered when they return online).
  ///
  /// Cost-optimized: the recency window is filtered SERVER-SIDE with
  /// `where lastActive > cutoff` (single-field range on the same field we
  /// order by — no composite index needed), so each client only reads the
  /// small recent slice instead of 80 docs on every presence write.
  /// Remaining client-side filtering: drop self and drop genuinely online
  /// players (they're already shown in the ONLINE LEARNERS list; stale
  /// "online" flags from killed apps count as offline after 3 minutes).
  Stream<List<BattlePresenceUser>> streamRecentlyActiveUsers(
    String currentUserId, {
    int limit = 15,
    int activeWithinDays = 7,
  }) {
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(Duration(days: activeWithinDays)),
    );
    return _firestore
        .collection(_presenceCollection)
        .where('lastActive', isGreaterThan: cutoff)
        .orderBy('lastActive', descending: true)
        .limit(limit * 2) // headroom for self/online filtering below
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final users = <BattlePresenceUser>[];

      for (var doc in snapshot.docs) {
        if (doc.id == currentUserId) continue; // Don't show self
        try {
          final user = BattlePresenceUser.fromMap(doc.data(), doc.id);

          // Skip genuinely online players (they're in the online list).
          // Stale "online" flags (app killed without a clean offline write)
          // are treated as offline once the heartbeat goes stale (> 3 min).
          final genuinelyOnline =
              user.isOnline && now.difference(user.lastActive).inMinutes <= 3;
          if (genuinelyOnline) continue;

          users.add(user);
        } catch (_) {}
      }

      users.sort((a, b) => b.trophies.compareTo(a.trophies));
      return users.take(limit).toList();
    });
  }

  /// Send direct 1v1 challenge to another player.
  ///
  /// [type]:
  ///   • 'live'  → target is online now; expires after ~90s (server cleanup)
  ///   • 'async' → target is offline; stays pending up to 48h and is
  ///     delivered (popup + push) the next time they open the app.
  /// [isRematch]: true when sent from the post-match REMATCH button — the
  /// receiver's popup says "wants a rematch" instead of a fresh duel.
  Future<String> sendChallenge({
    required String fromUserId,
    required String fromUserName,
    required String fromUserPhoto,
    required int fromUserTrophies,
    required String toUserId,
    String type = 'live',
    bool isRematch = false,
  }) async {
    // DEDUP + RATE-LIMIT: deterministic doc id `ch_{from}_{to}` — at most
    // ONE pending challenge per pair can exist. A repeat send targets the
    // existing doc; security rules reject that write (only the receiver may
    // update), so mashing the challenge button can't stack duplicates or
    // spam OneSignal pushes. The id frees up when cleanup deletes the
    // expired/accepted doc (live: 90s, async: 48h).
    final challengeId = 'ch_${fromUserId}_$toUserId';
    final docRef = _firestore.collection(_challengesCollection).doc(challengeId);

    // SELF-HEALING RESEND: the deterministic id means a leftover doc from a
    // previous round (declined = 'rejected', or an old 'accepted' that never
    // led to a duel) would make our `.set()` an UPDATE — and security rules
    // only let the RECEIVER update. So: pending → friendly block; resolved →
    // delete the stale doc and create a fresh challenge.
    final existing = await docRef.get();
    if (existing.exists) {
      final status = (existing.data() ?? const {})['status'];
      if (status == 'pending') {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'A challenge is already pending for this pair',
        );
      }
      await docRef.delete();
    }

    await docRef.set({
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'fromUserPhoto': fromUserPhoto,
      'fromUserTrophies': fromUserTrophies,
      'toUserId': toUserId,
      'status': 'pending',
      'type': type,
      'isRematch': isRematch,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return challengeId;
  }

  /// Listen for challenges SENT by the current user (so the sender knows
  /// when the receiver accepts/rejects and can join the room).
  Stream<List<BattleChallenge>> listenToOutgoingChallenges(String currentUserId) {
    return _firestore
        .collection(_challengesCollection)
        .where('fromUserId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BattleChallenge.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Listen for incoming challenges for current user
  Stream<List<BattleChallenge>> listenToIncomingChallenges(String currentUserId) {
    return _firestore
        .collection(_challengesCollection)
        .where('toUserId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return BattleChallenge.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Respond to challenge (Accept / Reject)
  Future<void> respondToChallenge(String challengeId, bool accept, {String? roomId}) async {
    await _firestore.collection(_challengesCollection).doc(challengeId).update({
      'status': accept ? 'accepted' : 'rejected',
      if (roomId != null) 'roomId': roomId,
    });
  }

  Future<void> _updatePresence({
    required String userId,
    required String name,
    required String photoUrl,
    required int trophies,
    required bool isOnline,
    required bool isInBattle,
  }) async {
    try {
      await _firestore.collection(_presenceCollection).doc(userId).set({
        'id': userId,
        'name': name.isEmpty ? 'Student' : name,
        'photoUrl': photoUrl,
        'trophies': trophies,
        'isOnline': isOnline,
        'isInBattle': isInBattle,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
