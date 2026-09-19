import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import '../models/battle_models.dart';

/// Thrown when challenge spam protection blocks the request.
class ChallengeBlockedException implements Exception {
  final String message;
  const ChallengeBlockedException(this.message);
  @override
  String toString() => message;
}

/// Heartbeat interval. Kept short (20s) so a killed app is detected quickly:
/// the online-list filter drops a heartbeat stale after 3 minutes, and the
/// server auto-forfeit treats >90s of silence in battle as a disconnect.
const Duration kPresenceHeartbeatInterval = Duration(seconds: 20);

class BattlePresenceService with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── SHARED heartbeat state (across all instances) ────────────────────────
  // Several instances exist (lobby via Riverpod, arena provider, waiting
  // room), but Firestore must see exactly ONE heartbeat per user. The timer,
  // identity and lifecycle observer are therefore static + refcounted:
  //   • the lobby takes a reference while it is on screen,
  //   • a duel started OUTSIDE the lobby (challenge accepted from Home)
  //     takes one via setInBattle(true) — otherwise the server auto-forfeit
  //     (>90s of silence = disconnect) would strike a player mid-fight.
  static Timer? _heartbeatTimer;
  static int _heartbeatRefs = 0;
  static bool _battleHoldsRef = false;
  static bool _observerRegistered = false;
  static bool _appPaused = false;

  /// Identity of the user whose heartbeat is running — needed by the
  /// lifecycle observer to flip presence instantly on pause/resume.
  static String? _activeUserId;
  static String _activeName = '';
  static String _activePhoto = '';
  static int _activeTrophies = 100;
  static bool _inBattle = false;

  static const String _presenceCollection = 'battle_presence';
  static const String _challengesCollection = 'battle_challenges';

  // ═══════════════════════════════════════════════════════════════════════
  // CHALLENGE SPAM PROTECTION — sothik niyom
  // ═══════════════════════════════════════════════════════════════════════
  // Per-pair cooldown tracking (in-memory + Firestore age check).
  // Same sender → same receiver cannot spam multiple challenges at once.
  static final Map<String, DateTime> _lastChallengeSentAt = {};

  /// Thrown when a challenge is blocked by spam protection.
  static const String kChallengePendingMsg =
      'Already challenged — waiting for reply ⏳';
  static const String kChallengeCooldownMsg =
      'Please wait before challenging again ⏳';
  static const String kChallengeInBattleMsg =
      'Player is busy in a duel ⚔️ — try later';

  /// Sets user online status in Firestore and starts the (shared) heartbeat.
  /// The initial write includes trophies (needed for the presence create
  /// rule); the periodic heartbeat refreshes liveness only — trophies are
  /// owned server-side by the Cloud Function.
  void startPresenceHeartbeat({
    required String userId,
    required String name,
    required String photoUrl,
    required int trophies,
  }) {
    _setIdentity(
      userId: userId,
      name: name,
      photoUrl: photoUrl,
      trophies: trophies,
    );
    _ensureObserver();

    _heartbeatRefs++;
    _ensureTimer();

    _updatePresence(
      userId: userId,
      name: name,
      photoUrl: photoUrl,
      trophies: trophies,
      isOnline: !_appPaused,
      isInBattle: _inBattle,
    );
  }

  static void _setIdentity({
    required String userId,
    required String name,
    required String photoUrl,
    required int trophies,
  }) {
    _activeUserId = userId;
    _activeName = name;
    _activePhoto = photoUrl;
    _activeTrophies = trophies;
  }

  void _ensureObserver() {
    // Go offline instantly when the app is backgrounded — no ghost-online
    // window. Registered once app-wide, no matter which instance asks.
    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }
  }

  static void _ensureTimer() {
    if (_heartbeatTimer != null) return;
    _heartbeatTimer = Timer.periodic(kPresenceHeartbeatInterval, (_) async {
      final userId = _activeUserId;
      if (userId == null || userId.isEmpty || userId.startsWith('guest_')) {
        return;
      }
      // App backgrounded: the lifecycle observer already marked us offline.
      // Do NOT flip back to online — the previous design kept re-publishing
      // isOnline:true while the process was alive (ghost presence + kept an
      // abandoned battle "alive" so auto-forfeit never fired).
      if (_appPaused) return;
      // Periodic heartbeat refreshes liveness only. Trophies are NOT written
      // here — the Cloud Function is the source of truth for presence
      // trophies, and writing Hive trophies here could stack on top of the
      // server's award (double count). The initial create sets trophies.
      try {
        await FirebaseFirestore.instance
            .collection(_presenceCollection)
            .doc(userId)
            .set({
          'name': _activeName.isEmpty ? 'Student' : _activeName,
          'photoUrl': _activePhoto,
          'isOnline': true,
          'isInBattle': _inBattle,
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
      _appPaused = true;
      _firestore.collection(_presenceCollection).doc(userId).set({
        'isOnline': false,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((_) {});
    } else if (state == AppLifecycleState.resumed) {
      _appPaused = false;
      _updatePresence(
        userId: userId,
        name: _activeName,
        photoUrl: _activePhoto,
        trophies: _activeTrophies,
        isOnline: true,
        isInBattle: _inBattle,
      );
    }
  }

  /// Releases one heartbeat reference (lobby dispose). When no reference
  /// remains the timer stops and the user is marked offline.
  Future<void> stopPresenceHeartbeat(String userId) async {
    if (_heartbeatRefs > 0) _heartbeatRefs--;
    if (_heartbeatRefs > 0 || _battleHoldsRef) return;
    await _teardown(userId);
  }

  static Future<void> _teardown(String userId) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _activeUserId = null;
    if (userId.isEmpty || userId.startsWith('guest_')) return;
    try {
      await FirebaseFirestore.instance
          .collection(_presenceCollection)
          .doc(userId)
          .set({
        'isOnline': false,
        'isInBattle': false,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Marks whether the user is currently inside a duel, so others don't
  /// challenge someone who is busy fighting. While in battle a heartbeat is
  /// GUARANTEED: duels can start outside the lobby (challenge accepted from
  /// Home), where the lobby heartbeat isn't running — without liveness
  /// writes the >90s auto-forfeit would forfeit an actively playing user.
  Future<void> setInBattle(
    String userId,
    bool inBattle, {
    String name = '',
    String photoUrl = '',
    int trophies = 100,
  }) async {
    _inBattle = inBattle;
    if (userId.isEmpty || userId.startsWith('guest_')) return;

    if (inBattle) {
      if (userId != _activeUserId || _heartbeatTimer == null) {
        if (userId != _activeUserId) {
          _setIdentity(
            userId: userId,
            name: name,
            photoUrl: photoUrl,
            trophies: trophies,
          );
        }
        _ensureObserver();
        if (_heartbeatTimer == null) {
          _battleHoldsRef = true;
          _heartbeatRefs++;
          _ensureTimer();
        }
      }
    } else if (_battleHoldsRef) {
      _battleHoldsRef = false;
      if (_heartbeatRefs > 0) _heartbeatRefs--;
      if (_heartbeatRefs == 0) {
        try {
          await _firestore.collection(_presenceCollection).doc(userId).set({
            'isInBattle': false,
            'lastActive': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
        // Only the battle held a reference → nobody else needs the heartbeat;
        // mark offline (lobby dispose already tore down otherwise).
        if (!_appPaused) {
          await _teardown(userId);
        }
        return;
      }
    }

    try {
      await _firestore.collection(_presenceCollection).doc(userId).set({
        'isInBattle': inBattle,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Whether [userId] is genuinely online RIGHT NOW (online flag + a fresh
  /// heartbeat). Guards flows that need the other side live — e.g. accepting
  /// a challenge must not launch a duel against a sender who went offline,
  /// leaving the receiver to play a ghost match alone.
  Future<bool> isUserOnline(String userId) async {
    if (userId.isEmpty || userId.startsWith('guest_')) return false;
    try {
      final doc =
          await _firestore.collection(_presenceCollection).doc(userId).get();
      if (!doc.exists) return false;
      final d = doc.data();
      if (d == null) return false;
      final online = d['isOnline'] == true;
      final last = (d['lastActive'] as Timestamp?)?.toDate();
      final fresh =
          last != null && DateTime.now().difference(last).inMinutes <= 3;
      return online && fresh;
    } catch (_) {
      return false;
    }
  }

  /// SINGLE combined presence stream for the lobby — fetches the 60 most
  /// recent presence docs once (1 Firestore listener instead of 2).
  /// Callers derive online vs recently-active client-side, cutting read cost ~50%.
  Stream<List<BattlePresenceUser>> streamLobbyPresence(String currentUserId) {
    return _firestore
        .collection(_presenceCollection)
        .orderBy('lastActive', descending: true)
        .limit(60)
        .snapshots()
        .map((snapshot) {
      final users = <BattlePresenceUser>[];
      for (var doc in snapshot.docs) {
        if (doc.id == currentUserId) continue;
        try {
          users.add(BattlePresenceUser.fromMap(doc.data(), doc.id));
        } catch (_) {}
      }
      return users;
    });
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
  ///   • 'live'  → target is online now; kept ~10 min (server cleanup)
  ///   • 'async' → target is offline; stays pending up to 48h and is
  ///     delivered (popup + push) the next time they open the app.
  /// [isRematch]: true when sent from the post-match REMATCH button — the
  /// receiver's popup says "wants a rematch" instead of a fresh duel.
  ///
  /// RESEND SEMANTICS: the deterministic doc id `ch_{from}_{to}` means at
  /// most ONE challenge doc exists per pair. Sending again REPLACES the
  /// previous challenge — a still-pending one is cancelled, a resolved one
  /// (declined/stale accepted) is deleted, and a FRESH doc is created. The
  /// fresh doc carries a new `createdAt`, which is what the receiver's
  /// GlobalBattleChallengeGate uses to resurface the popup.
  /// [onSupersededRoom] is called with the replaced challenge's roomId (if
  /// any) so the caller can delete the now-orphaned waiting room instantly.
  Future<String> sendChallenge({
    required String fromUserId,
    required String fromUserName,
    required String fromUserPhoto,
    required int fromUserTrophies,
    required String toUserId,
    String type = 'live',
    bool isRematch = false,
    String? roomId,
    void Function(String? oldRoomId)? onSupersededRoom,
  }) async {
    // ── GUEST/BOT BLOCK ────────────────────────────────────
    if (fromUserId.startsWith('guest_') ||
        toUserId.startsWith('guest_') ||
        fromUserId.startsWith('bot_') ||
        toUserId.startsWith('bot_')) {
      throw const ChallengeBlockedException(
          'Guest/Bot cannot duel — please sign in 🔒');
    }
    final challengeId = 'ch_${fromUserId}_$toUserId';
    final docRef = _firestore.collection(_challengesCollection).doc(challengeId);
    final pairKey = '${fromUserId}_$toUserId';

    // ── IN-MEMORY COOLDOWN (30s) ─────────────────────────────
    // Prevents rapid double-tap / spam even before Firestore check.
    final lastSent = _lastChallengeSentAt[pairKey];
    if (lastSent != null &&
        DateTime.now().difference(lastSent).inSeconds < 30) {
      final wait = 30 - DateTime.now().difference(lastSent).inSeconds;
      throw ChallengeBlockedException(
          '$kChallengeCooldownMsg (${wait}s wait) ⏳');
    }

    // ── GLOBAL OUTGOING LIMIT (anti-spam across many targets) ─
    // One sender cannot have more than 3 pending challenges at once.
    // This stops a single user from spamming the whole lobby.
    try {
      final outgoingSnap = await _firestore
          .collection(_challengesCollection)
          .where('fromUserId', isEqualTo: fromUserId)
          .where('status', isEqualTo: 'pending')
          .limit(4)
          .get();
      if (outgoingSnap.docs.length >= 3) {
        throw const ChallengeBlockedException(
            'Too many pending challenges — wait for replies ⏳ (max 3)');
      }
    } catch (e) {
      if (e is ChallengeBlockedException) rethrow;
      // Count check failure is non-fatal — continue.
    }

    // ── CHECK RECEIVER IS NOT IN BATTLE ──────────────────────
    // UI already disables the button, but a race (or old build) could still
    // send. Blocking here guarantees the rule server-side too.
    try {
      final presenceDoc =
          await _firestore.collection(_presenceCollection).doc(toUserId).get();
      if (presenceDoc.exists) {
        final pd = presenceDoc.data() ?? {};
        final inBattle = pd['isInBattle'] == true;
        // Also check lastActive freshness — stale presence is ignored
        final lastActive = (pd['lastActive'] as Timestamp?)?.toDate();
        final fresh = lastActive != null &&
            DateTime.now().difference(lastActive).inMinutes <= 3;
        if (inBattle && fresh) {
          throw const ChallengeBlockedException(kChallengeInBattleMsg);
        }
      }
    } catch (e) {
      if (e is ChallengeBlockedException) rethrow;
      // Presence check failure is non-fatal — continue to challenge.
    }

    // ── EXISTING CHALLENGE CHECK (SPAM PROTECTION) ───────────
    // Deterministic ID means at most one doc per pair. We used to
    // delete-then-create unconditionally (allowed spamming every tap).
    // Now we BLOCK if a pending/accepted challenge is still fresh.
    final existing = await docRef.get();
    if (existing.exists) {
      final data = existing.data() ?? const {};
      final status = data['status'] as String? ?? 'pending';
      final oldRoomId = data['roomId'] as String?;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final age = createdAt != null
          ? DateTime.now().difference(createdAt)
          : const Duration(days: 99);

      if (status == 'pending') {
        // Pending challenges are valid and the receiver hasn't responded yet.
        // Block resend for 60s (live) / 120s (async) — receiver needs time
        // to see and respond, and spamming would create orphan rooms.
        final blockSeconds = type == 'async' ? 120 : 60;
        if (age.inSeconds < blockSeconds) {
          final wait = blockSeconds - age.inSeconds;
          throw ChallengeBlockedException(
              '$kChallengePendingMsg — try again in ${wait}s');
        }
        // Pending but old enough (receiver ignored) → allow replace.
        // Fall through to delete + create.
      } else if (status == 'accepted') {
        // Already accepted — a duel is waiting/starting. Don't spam.
        // Check room state if possible; otherwise block for 2 minutes.
        if (oldRoomId != null) {
          try {
            final roomDoc = await _firestore
                .collection('battle_rooms')
                .doc(oldRoomId)
                .get();
            if (roomDoc.exists) {
              final roomStatus = roomDoc.data()?['status'] as String?;
              if (roomStatus == 'waiting' || roomStatus == 'in_progress') {
                throw const ChallengeBlockedException(
                    'Duel already accepted — join the waiting room ⚔️');
              }
            }
          } catch (e) {
            if (e is ChallengeBlockedException) rethrow;
          }
        }
        if (age.inMinutes < 2) {
          throw ChallengeBlockedException(
              'Already accepted ${age.inSeconds}s ago — wait for duel to start');
        }
      }
      // For rejected/expired or old pending/accepted → allow replace.
      // Delete the old doc (sender-allowed) and clean its orphan room.
      try {
        await docRef.delete();
      } catch (e) {
        debugPrint('⚠️ could not replace previous challenge doc: $e');
        rethrow;
      }
      onSupersededRoom?.call(oldRoomId);
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
      // Room-first flow: the waiting room already exists at send time.
      if (roomId != null) 'roomId': roomId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _lastChallengeSentAt[pairKey] = DateTime.now();
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

  /// Streams a single challenge doc (null once it is deleted).
  Stream<BattleChallenge?> streamChallenge(String challengeId) {
    return _firestore
        .collection(_challengesCollection)
        .doc(challengeId)
        .snapshots()
        .map((doc) => doc.exists && doc.data() != null
            ? BattleChallenge.fromMap(doc.data()!, doc.id)
            : null);
  }

  /// Challenges addressed to me that I already ACCEPTED — used to restore
  /// the waiting room after an app restart (room-first flow).
  Stream<List<BattleChallenge>> listenToAcceptedIncomingChallenges(
      String currentUserId) {
    return _firestore
        .collection(_challengesCollection)
        .where('toUserId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BattleChallenge.fromMap(doc.data(), doc.id))
            .toList());
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
