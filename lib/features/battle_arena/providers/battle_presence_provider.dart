import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../models/battle_models.dart';
import '../services/battle_block_service.dart';
import '../services/battle_presence_service.dart';

final battlePresenceServiceProvider = Provider<BattlePresenceService>((ref) {
  return BattlePresenceService();
});

/// SINGLE combined lobby presence — 1 Firestore listener (60 docs, orderBy lastActive)
/// All other lobby lists derive from this, cutting presence read cost by ~50%.
final lobbyPresenceProvider =
    StreamProvider.autoDispose<List<BattlePresenceUser>>((ref) {
  final authState = ref.watch(authProvider);
  final currentUser = authState.asData?.value;
  if (currentUser == null) return const Stream.empty();
  return ref.watch(battlePresenceServiceProvider).streamLobbyPresence(currentUser.id);
});

/// Blocked user IDs — lobby filters these out so blocked players never appear.
final blockedIdsProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final user = ref.watch(authProvider).asData?.value;
  if (user == null || user.id.isEmpty || user.id.startsWith('guest_')) {
    return Stream.value(<String>{});
  }
  return BattleBlockService().streamBlockedIds(user.id);
});

/// Online users derived from the single combined stream (isOnline true + fresh <3m) + blocked filter
final onlineBattleUsersProvider = Provider<AsyncValue<List<BattlePresenceUser>>>((ref) {
  final lobbyAsync = ref.watch(lobbyPresenceProvider);
  final blocked = ref.watch(blockedIdsProvider).asData?.value ?? <String>{};
  return lobbyAsync.whenData((users) {
    final now = DateTime.now();
    final online = users
        .where((u) => !blocked.contains(u.id) && u.isOnline && now.difference(u.lastActive).inMinutes <= 3)
        .toList()
      ..sort((a, b) => b.trophies.compareTo(a.trophies));
    return online;
  });
});

/// Recently active (offline but played within 7 days) derived from single stream + blocked filter
final recentlyActiveBattleUsersProvider =
    Provider<AsyncValue<List<BattlePresenceUser>>>((ref) {
  final lobbyAsync = ref.watch(lobbyPresenceProvider);
  final blocked = ref.watch(blockedIdsProvider).asData?.value ?? <String>{};
  return lobbyAsync.whenData((users) {
    final now = DateTime.now();
    final recent = users.where((u) {
      if (blocked.contains(u.id)) return false;
      final genuinelyOnline = u.isOnline && now.difference(u.lastActive).inMinutes <= 3;
      if (genuinelyOnline) return false;
      // Within 7 days
      return now.difference(u.lastActive).inDays < 7;
    }).toList()
      ..sort((a, b) => b.trophies.compareTo(a.trophies));
    return recent.take(15).toList();
  });
});

/// Stream of outgoing (sent by me) challenges — so I know when the
/// receiver accepts and I need to join the room myself.
final outgoingChallengesProvider = StreamProvider.autoDispose<List<BattleChallenge>>((ref) {
  final authState = ref.watch(authProvider);
  final currentUser = authState.asData?.value;
  if (currentUser == null) return const Stream.empty();

  final service = ref.watch(battlePresenceServiceProvider);
  return service.listenToOutgoingChallenges(currentUser.id);
});

/// Stream of incoming 1v1 challenges
final incomingChallengesProvider = StreamProvider.autoDispose<List<BattleChallenge>>((ref) {
  final authState = ref.watch(authProvider);
  final currentUser = authState.asData?.value;
  if (currentUser == null) return const Stream.empty();

  final service = ref.watch(battlePresenceServiceProvider);
  return service.listenToIncomingChallenges(currentUser.id);
});

/// Challenges addressed to me that I already ACCEPTED — the gate uses this
/// to restore the waiting room / arena after an app restart.
final acceptedIncomingChallengesProvider =
    StreamProvider.autoDispose<List<BattleChallenge>>((ref) {
  final authState = ref.watch(authProvider);
  final currentUser = authState.asData?.value;
  if (currentUser == null) return const Stream.empty();

  final service = ref.watch(battlePresenceServiceProvider);
  return service.listenToAcceptedIncomingChallenges(currentUser.id);
});

/// Set by UI entry points (e.g. the lobby's pending-challenge banner) when
/// the user wants the accept/decline sheet for a challenge that was
/// dismissed with "Later". The gate shows it and clears this back to null.
final reshowChallengeProvider = StateProvider<BattleChallenge?>((ref) => null);

/// Reactive set of userIds that the current user has a pending outgoing
/// challenge to — used to disable Duel buttons instantly (DRY).
final outgoingPendingIdsProvider = Provider<Set<String>>((ref) {
  final outgoing = ref.watch(outgoingChallengesProvider).asData?.value ?? [];
  return outgoing
      .where((c) => c.status == 'pending')
      .map((c) => c.toUserId)
      .toSet();
});

/// Map of toUserId -> pending challenge (for countdown & cancel).
final outgoingPendingChallengeMapProvider =
    Provider<Map<String, BattleChallenge>>((ref) {
  final outgoing = ref.watch(outgoingChallengesProvider).asData?.value ?? [];
  return {
    for (final c in outgoing.where((c) => c.status == 'pending')) c.toUserId: c
  };
});
