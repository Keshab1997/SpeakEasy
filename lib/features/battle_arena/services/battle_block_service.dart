import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple block/report: stores blocked user IDs under blocked_users/{myId}/blocked/{blockedId}
/// Lobby presence streams filter these IDs client-side. Firestore rules allow owner-only read/write.
class BattleBlockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _blockedCollection(String myId) => 'blocked_users';
  // Actually structure: blocked_users/{myId}/blocked/{blockedId}

  Future<Set<String>> getBlockedIds(String myId) async {
    if (myId.isEmpty || myId.startsWith('guest_')) return <String>{};
    try {
      final snap = await _firestore.collection('blocked_users').doc(myId).collection('blocked').get();
      return snap.docs.map((d) => d.id).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Stream<Set<String>> streamBlockedIds(String myId) {
    if (myId.isEmpty || myId.startsWith('guest_')) return Stream.value(<String>{});
    return _firestore.collection('blocked_users').doc(myId).collection('blocked').snapshots().map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  Future<void> blockUser({required String myId, required String blockedId, required String blockedName}) async {
    if (myId.isEmpty || blockedId.isEmpty || myId == blockedId) return;
    await _firestore.collection('blocked_users').doc(myId).collection('blocked').doc(blockedId).set({
      'blockedId': blockedId,
      'blockedName': blockedName,
      'blockedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser({required String myId, required String blockedId}) async {
    await _firestore.collection('blocked_users').doc(myId).collection('blocked').doc(blockedId).delete();
  }

  Future<void> reportUser({required String myId, required String reportedId, required String reason}) async {
    await _firestore.collection('battle_reports').add({
      'reporterId': myId,
      'reportedId': reportedId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }
}
