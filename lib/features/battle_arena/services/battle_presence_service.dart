import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/battle_models.dart';

class BattlePresenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _heartbeatTimer;

  static const String _presenceCollection = 'battle_presence';
  static const String _challengesCollection = 'battle_challenges';

  /// Sets user online status in Firestore and starts heartbeat
  void startPresenceHeartbeat({
    required String userId,
    required String name,
    required String photoUrl,
    required int trophies,
  }) {
    _updatePresence(
      userId: userId,
      name: name,
      photoUrl: photoUrl,
      trophies: trophies,
      isOnline: true,
      isInBattle: false,
    );

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _updatePresence(
        userId: userId,
        name: name,
        photoUrl: photoUrl,
        trophies: trophies,
        isOnline: true,
        isInBattle: false,
      );
    });
  }

  /// Sets user offline when leaving battle arena
  Future<void> stopPresenceHeartbeat(String userId) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    try {
      await _firestore.collection(_presenceCollection).doc(userId).set({
        'isOnline': false,
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

  /// Send direct 1v1 challenge to an online player
  Future<String> sendChallenge({
    required String fromUserId,
    required String fromUserName,
    required String fromUserPhoto,
    required int fromUserTrophies,
    required String toUserId,
  }) async {
    final docRef = await _firestore.collection(_challengesCollection).add({
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'fromUserPhoto': fromUserPhoto,
      'fromUserTrophies': fromUserTrophies,
      'toUserId': toUserId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
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
