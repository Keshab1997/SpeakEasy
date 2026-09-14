import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../battle_arena/models/battle_models.dart';
import '../../battle_arena/providers/battle_arena_provider.dart';
import '../../battle_arena/services/battle_leaderboard_service.dart';
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

/// Friends leaderboard: me + my friends ranked by trophies (1-based rank
/// within the circle). One batched Firestore getAll per refresh.
final friendsLeaderboardProvider =
    FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) async {
  final me = ref.watch(authProvider).asData?.value;
  if (me == null) return const [];
  final friends = await ref.watch(myFriendsProvider.future);
  if (friends.isEmpty) return const [];
  final stats = ref.watch(battleArenaProvider).stats;
  return BattleLeaderboardService().getFriendsLeaderboard(
    myId: me.id,
    mySeed: LeaderboardSeed(
      userId: me.id,
      name: me.name,
      photoUrl: me.photoUrl,
      trophies: stats.trophies,
    ),
    friendSeeds: friends
        .map((f) => LeaderboardSeed(
              userId: f.id,
              name: f.name,
              photoUrl: f.photoUrl,
              trophies: f.trophies,
            ))
        .toList(),
  );
});
