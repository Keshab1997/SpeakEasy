import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../models/friend_models.dart';
import '../services/friend_service.dart';

final friendServiceProvider = Provider<FriendService>((ref) {
  return FriendService();
});

/// Friend requests waiting for my decision.
final incomingFriendRequestsProvider =
    StreamProvider.autoDispose<List<FriendRequest>>((ref) {
  final currentUser = ref.watch(authProvider).asData?.value;
  if (currentUser == null) return const Stream.empty();
  return ref
      .watch(friendServiceProvider)
      .streamIncomingRequests(currentUser.id);
});

/// Requests I've sent that are still pending.
final outgoingFriendRequestsProvider =
    StreamProvider.autoDispose<List<FriendRequest>>((ref) {
  final currentUser = ref.watch(authProvider).asData?.value;
  if (currentUser == null) return const Stream.empty();
  return ref
      .watch(friendServiceProvider)
      .streamOutgoingRequests(currentUser.id);
});

/// My accepted friends list.
final myFriendsProvider = StreamProvider.autoDispose<List<Friend>>((ref) {
  final currentUser = ref.watch(authProvider).asData?.value;
  if (currentUser == null) return const Stream.empty();
  return ref.watch(friendServiceProvider).streamMyFriends(currentUser.id);
});
