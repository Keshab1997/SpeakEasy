import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_models.dart';

/// Friend system data layer.
///
/// Collections:
///   friend_requests/{id}  — pending/accepted requests between users
///   friendships/{userId}  — per-user doc: { friends: { uid: snapshot } }
///
/// Security model (see firestore.rules):
///   • A client only ever writes ITS OWN friendship doc.
///   • Accepting a request = flipping request status to 'accepted'; a Cloud
///     Function (admin) then writes BOTH friendship docs and pushes the sender.
///   • Removing a friend updates only MY doc (one-sided; acceptable MVP).
class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _requestsCollection = 'friend_requests';
  static const String _friendshipsCollection = 'friendships';

  /// Send a friend request to another player.
  Future<String> sendFriendRequest({
    required String fromUserId,
    required String fromUserName,
    required String fromUserPhoto,
    required int fromUserTrophies,
    required String toUserId,
  }) async {
    final docRef = await _firestore.collection(_requestsCollection).add({
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

  /// Requests waiting for MY decision.
  Stream<List<FriendRequest>> streamIncomingRequests(String userId) {
    return _firestore
        .collection(_requestsCollection)
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FriendRequest.fromMap(d.data(), d.id))
            .toList());
  }

  /// Requests I sent (used to show a "Requested" state on player cards).
  Stream<List<FriendRequest>> streamOutgoingRequests(String userId) {
    return _firestore
        .collection(_requestsCollection)
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FriendRequest.fromMap(d.data(), d.id))
            .toList());
  }

  /// My friends list (snapshot data written by the Cloud Function on accept).
  Stream<List<Friend>> streamMyFriends(String userId) {
    return _firestore
        .collection(_friendshipsCollection)
        .doc(userId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return <Friend>[];
      final friends = (snap.data()?['friends'] as Map<String, dynamic>?) ?? {};
      final list = friends.entries
          .map((e) =>
              Friend.fromMap(e.key, Map<String, dynamic>.from(e.value as Map)))
          .toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  /// Accept an incoming request.
  /// Only flips the status — the `onFriendRequestUpdate` Cloud Function then
  /// writes both friendship docs (clients can't write each other's doc) and
  /// pushes the requester "X accepted your friend request!".
  Future<void> acceptFriendRequest(FriendRequest request) async {
    await _firestore
        .collection(_requestsCollection)
        .doc(request.id)
        .update({'status': 'accepted'});
  }

  /// Reject an incoming request (silent — doc deleted, no push).
  Future<void> rejectFriendRequest(String requestId) async {
    await _firestore.collection(_requestsCollection).doc(requestId).delete();
  }

  /// Cancel an outgoing request I sent.
  Future<void> cancelOutgoingRequest(String requestId) =>
      rejectFriendRequest(requestId);

  /// Remove a friend from MY list (one-sided; their copy stays until they
  /// remove too — they simply stop being relevant for notifications).
  Future<void> removeFriend(String userId, String friendId) async {
    await _firestore
        .collection(_friendshipsCollection)
        .doc(userId)
        .update({'friends.$friendId': FieldValue.delete()});
  }
}
