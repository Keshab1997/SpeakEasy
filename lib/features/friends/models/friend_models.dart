import 'package:cloud_firestore/cloud_firestore.dart';

/// A pending (or accepted) friend request between two learners.
/// Stored in `friend_requests/{requestId}`.
///
/// Lifecycle:
///   sender creates (status 'pending') → receiver accepts (status 'accepted')
///   or rejects (doc deleted). On accept, a Cloud Function writes BOTH
///   users' friendship entries (clients may only write their own doc) and
///   pushes the sender.
class FriendRequest {
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String fromUserPhoto;
  final int fromUserTrophies;
  final String toUserId;
  final String status; // 'pending' | 'accepted'
  final DateTime createdAt;

  const FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    this.fromUserPhoto = '',
    this.fromUserTrophies = 100,
    required this.toUserId,
    this.status = 'pending',
    required this.createdAt,
  });

  factory FriendRequest.fromMap(Map<String, dynamic> map, String docId) {
    return FriendRequest(
      id: docId,
      fromUserId: map['fromUserId'] ?? '',
      fromUserName: map['fromUserName'] ?? 'A learner',
      fromUserPhoto: map['fromUserPhoto'] ?? '',
      fromUserTrophies: (map['fromUserTrophies'] as num?)?.toInt() ?? 100,
      toUserId: map['toUserId'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// One entry of my friends map (`friendships/{myUid}.friends.{friendUid}`).
/// Snapshot data captured at accept time so the friends list renders even
/// when the friend has no fresh presence doc.
class Friend {
  final String id;
  final String name;
  final String photoUrl;
  final int trophies;
  final DateTime addedAt;

  const Friend({
    required this.id,
    required this.name,
    this.photoUrl = '',
    this.trophies = 100,
    required this.addedAt,
  });

  factory Friend.fromMap(String uid, Map<String, dynamic> map) {
    return Friend(
      id: uid,
      name: map['name'] ?? 'A learner',
      photoUrl: map['photoUrl'] ?? '',
      trophies: (map['trophies'] as num?)?.toInt() ?? 100,
      addedAt: (map['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
