import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../models/battle_models.dart';
import '../services/battle_presence_service.dart';

final battlePresenceServiceProvider = Provider<BattlePresenceService>((ref) {
  return BattlePresenceService();
});

/// Stream of online users in the battle lobby
final onlineBattleUsersProvider = StreamProvider.autoDispose<List<BattlePresenceUser>>((ref) {
  final authState = ref.watch(authProvider);
  final currentUser = authState.asData?.value;
  if (currentUser == null) return const Stream.empty();

  final service = ref.watch(battlePresenceServiceProvider);
  return service.streamOnlineUsers(currentUser.id);
});

/// Stream of RECENTLY ACTIVE players — offline warriors who played within
/// the last 7 days. They can receive async challenges that are delivered
/// the next time they open the app.
final recentlyActiveBattleUsersProvider =
    StreamProvider.autoDispose<List<BattlePresenceUser>>((ref) {
  final authState = ref.watch(authProvider);
  final currentUser = authState.asData?.value;
  if (currentUser == null) return const Stream.empty();

  final service = ref.watch(battlePresenceServiceProvider);
  return service.streamRecentlyActiveUsers(currentUser.id);
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
