import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../../providers/auth_provider.dart';
import '../models/battle_models.dart';
import '../providers/battle_arena_provider.dart';
import '../providers/battle_presence_provider.dart';
import '../screens/battle_arena_screen.dart';
import '../services/battle_matchmaking_service.dart';

/// Mounted ONCE near the app root. Makes 1v1 battle challenges work from
/// ANY screen (Home, lobby, etc.):
///  • shows the "challenge received" bottom sheet no matter where the user is
///  • accepting creates the room and drops both players into the arena
///  • accepting a challenge you SENT (other person) joins you too
class GlobalBattleChallengeGate extends ConsumerStatefulWidget {
  final Widget child;

  const GlobalBattleChallengeGate({super.key, required this.child});

  @override
  ConsumerState<GlobalBattleChallengeGate> createState() =>
      _GlobalBattleChallengeGateState();
}

class _GlobalBattleChallengeGateState
    extends ConsumerState<GlobalBattleChallengeGate> {
  // Challenges we've already reacted to (so streams don't refire).
  final Set<String> _handledIncoming = {};
  final Set<String> _handledOutgoing = {};
  bool _arenaOpen = false;
  bool _sheetOpen = false;

  /// Shows a snackbar from anywhere via the root navigator (no BuildContext
  /// is held across an await, so this is safe to call from catch blocks).
  void _showGlobalSnack(String message, {Color color = const Color(0xFFEF4444)}) {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    final messenger = ScaffoldMessenger.of(ctx);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1) Navigate into the arena whenever a duel starts (quick match OR a
    //    challenge accepted from anywhere).
    ref.listen<BattleArenaState>(battleArenaProvider, (prev, next) async {
      final wasDuel = prev?.status == BattleArenaStatus.inDuel;
      final isDuel = next.status == BattleArenaStatus.inDuel;

      if (!wasDuel && isDuel) {
        if (_arenaOpen) {
          // Previous duel's arena/result route is still considered open
          // (its push future hasn't completed yet — e.g. BattleResultScreen
          // is still on top and the user pressed "Play Again" which pops
          // the result and immediately starts a new Quick 1v1). Pushing
          // now would either be dropped by the guard or stack on top of
          // the result. Schedule a retry after the previous route is
          // popped and _arenaOpen clears.
          // ignore: use_build_context_synchronously
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (!mounted) return;
            if (ref.read(battleArenaProvider).status != BattleArenaStatus.inDuel) return;
            if (_arenaOpen) return;
            final navCtx = appNavigatorKey.currentContext;
            if (navCtx == null) return;
            _arenaOpen = true;
            // ignore: use_build_context_synchronously
            await Navigator.of(navCtx).push(
              MaterialPageRoute(builder: (_) => const BattleArenaScreen()),
            );
            _arenaOpen = false;
          });
          return;
        }
        _arenaOpen = true;
        // ignore: use_build_context_synchronously
        await Navigator.of(appNavigatorKey.currentContext!).push(
          MaterialPageRoute(builder: (_) => const BattleArenaScreen()),
        );
        _arenaOpen = false;
      }
    });

    // 2) Incoming challenge → show the accept/decline sheet globally.
    ref.watch(incomingChallengesProvider).whenData((challenges) {
      if (challenges.isEmpty) return;
      // Don't interrupt if a battle/sheet is already up.
      if (_arenaOpen || _sheetOpen) return;

      BattleChallenge? challenge;
      for (final c in challenges) {
        if (!_handledIncoming.contains(c.id)) {
          challenge = c;
          break;
        }
      }
      if (challenge == null) return;

      _handledIncoming.add(challenge.id);
      final toShow = challenge;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showIncomingSheet(toShow);
      });
    });

    // 3) A challenge I SENT got accepted → join the room.
    ref.watch(outgoingChallengesProvider).whenData((outgoing) {
      for (final challenge in outgoing) {
        if (_handledOutgoing.contains(challenge.id)) continue;

        if (challenge.status == 'accepted' && challenge.roomId != null) {
          _handledOutgoing.add(challenge.id);
          final id = challenge.id;
          final roomId = challenge.roomId!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _joinAcceptedRoom(roomId, id);
          });
        } else if (challenge.status == 'rejected') {
          _handledOutgoing.add(challenge.id);
          unawaited(BattleMatchmakingService().deleteChallenge(challenge.id));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showGlobalSnack(
                'The player declined your challenge. Try another warrior! 🤺');
          });
        }
      }
    });

    return widget.child;
  }

  Future<void> _joinAcceptedRoom(String roomId, String challengeId) async {
    try {
      final matchmaking = BattleMatchmakingService();
      var room = await matchmaking.getRoom(roomId);
      // Room may take a beat to propagate — retry once.
      if (room == null) {
        await Future.delayed(const Duration(milliseconds: 800));
        room = await matchmaking.getRoom(roomId);
      }
      if (room == null) return;
      if (ref.read(battleArenaProvider).status == BattleArenaStatus.inDuel) {
        return;
      }
      ref.read(battleArenaProvider.notifier).startFromRoom(room);
      unawaited(matchmaking.deleteChallenge(challengeId));
    } catch (_) {
      _showGlobalSnack('Could not join the duel. Try again.');
    }
  }

  void _showIncomingSheet(BattleChallenge challenge) {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;

    _sheetOpen = true;
    showModalBottomSheet(
      context: ctx,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⚔️ 1v1 CHALLENGE RECEIVED!',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEF4444))),
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 30,
                  backgroundImage: challenge.fromUserPhoto.isNotEmpty
                      ? NetworkImage(challenge.fromUserPhoto)
                      : null,
                  child: challenge.fromUserPhoto.isEmpty
                      ? Text(challenge.fromUserName.isNotEmpty
                          ? challenge.fromUserName[0].toUpperCase()
                          : 'P')
                      : null,
                ),
                const SizedBox(height: 10),
                Text(
                  '${challenge.fromUserName} wants to duel with you!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text('${challenge.fromUserTrophies} Trophies 🏆',
                    style: const TextStyle(
                        color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ref
                              .read(battlePresenceServiceProvider)
                              .respondToChallenge(challenge.id, false);
                          Navigator.pop(sheetCtx);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Pop sheet FIRST before pushing the arena.
                          // GlobalBattleChallengeGate pushes BattleArenaScreen
                          // onto the same root navigator as the bottom sheet;
                          // if we start the duel while the sheet is still
                          // open, the arena lands under the sheet and the
                          // following pop(sheetCtx) pops the arena instead
                          // of the sheet — leaving the receiver with no
                          // visible question.
                          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          await _acceptChallenge(challenge);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Accept Duel ⚔️',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() => _sheetOpen = false);
  }

  Future<void> _acceptChallenge(BattleChallenge challenge) async {
    try {
      final myUser = ref.read(authProvider).asData?.value;
      final myStats = ref.read(battleArenaProvider).stats;

      final player1 = BattlePlayer(
        id: challenge.fromUserId,
        name: challenge.fromUserName,
        photoUrl: challenge.fromUserPhoto,
        trophies: challenge.fromUserTrophies,
      );
      final player2 = BattlePlayer(
        id: myUser?.id ?? 'me',
        name: myUser?.name ?? 'Me',
        photoUrl: myUser?.photoUrl ?? '',
        trophies: myStats.trophies,
      );

      final matchmaking = BattleMatchmakingService();
      final room = await matchmaking.createDirectChallengeRoom(
        player1: player1,
        player2: player2,
      );

      await ref
          .read(battlePresenceServiceProvider)
          .respondToChallenge(challenge.id, true, roomId: room.id);

      // Don't delete the challenge here — the sender's
      // outgoingChallengesProvider needs to see status='accepted' + roomId
      // before the doc disappears. The sender deletes it after joining
      // (_joinAcceptedRoom), and the scheduled cleanup removes stale ones.

      // Start the battle on THIS (receiver) device — the gate's listener
      // pushes the arena screen.
      ref.read(battleArenaProvider.notifier).startFromRoom(room);
    } catch (_) {
      _showGlobalSnack('Could not start the duel. Try again.');
    }
  }
}
