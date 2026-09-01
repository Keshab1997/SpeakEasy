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
