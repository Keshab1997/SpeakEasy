import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../../providers/auth_provider.dart';
import '../models/battle_models.dart';
import '../providers/battle_arena_provider.dart';
import '../providers/battle_presence_provider.dart';
import '../screens/battle_arena_screen.dart';
import '../screens/battle_waiting_room_screen.dart';
import '../services/battle_matchmaking_service.dart';

/// Mounted ONCE near the app root. Makes 1v1 battle challenges work from
/// ANY screen (Home, lobby, etc.):
///  • shows the "challenge received" bottom sheet no matter where the user
///    is (Accept / Decline / Later — always retryable, never a dead end)
///  • ROOM-FIRST flow: the sender already created a waiting room when they
///    challenged; accepting joins that room, and the HOST starts the duel
///  • restores the waiting room / arena after app restarts (both sides)
class GlobalBattleChallengeGate extends ConsumerStatefulWidget {
  final Widget child;

  const GlobalBattleChallengeGate({super.key, required this.child});

  @override
  ConsumerState<GlobalBattleChallengeGate> createState() =>
      _GlobalBattleChallengeGateState();
}

class _GlobalBattleChallengeGateState
    extends ConsumerState<GlobalBattleChallengeGate> {
  /// Challenges we already RESPONDED to (accepted/declined) — no re-sheet.
  final Set<String> _respondedIncoming = {};

  /// Challenges the user postponed with "Later" — no auto re-sheet, but the
  /// lobby banner keeps offering a Respond button (reshowChallengeProvider).
  final Set<String> _dismissedIncoming = {};

  /// Outgoing/accepted challenges we already routed somewhere.
  final Set<String> _handledOutgoing = {};
  final Set<String> _restoredAccepted = {};

  bool _arenaOpen = false;
  bool _sheetOpen = false;
  bool _waitingRoomOpen = false;

  /// Shows a snackbar from anywhere via the root navigator.
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
          // Previous duel's arena/result route is still considered open —
          // retry after it pops (see previous behaviour for details).
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

    // 2) Incoming PENDING challenge → accept/decline sheet.
    //    No one-shot blocking: while a challenge stays pending and the user
    //    hasn't responded or pressed "Later", a fresh provider emission can
    //    surface the sheet again — a challenge can never become unclickable.
    ref.watch(incomingChallengesProvider).whenData((challenges) {
      if (challenges.isEmpty) return;
      if (_arenaOpen || _sheetOpen) return;

      BattleChallenge? challenge;
      for (final c in challenges) {
        if (_respondedIncoming.contains(c.id)) continue;
        if (_dismissedIncoming.contains(c.id)) continue;
        challenge = c;
        break;
      }
      if (challenge == null) return;

      final toShow = challenge;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _sheetOpen || _arenaOpen) return;
        _showIncomingSheet(toShow);
      });
    });

    // 2b) "Later" re-entry: the lobby banner sets this provider when the
    //     user taps Respond on a dismissed challenge.
    ref.listen(reshowChallengeProvider, (prev, next) {
      if (next == null) return;
      ref.read(reshowChallengeProvider.notifier).state = null;
      _dismissedIncoming.remove(next.id);
      if (_sheetOpen || _arenaOpen) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _sheetOpen || _arenaOpen) return;
        _showIncomingSheet(next);
      });
    });

    // 3) A challenge I SENT got accepted → enter its room as HOST.
    ref.watch(outgoingChallengesProvider).whenData((outgoing) {
      for (final challenge in outgoing) {
        if (_handledOutgoing.contains(challenge.id)) continue;

        if (challenge.status == 'accepted' && challenge.roomId != null) {
          _handledOutgoing.add(challenge.id);
          final id = challenge.id;
          final roomId = challenge.roomId!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _enterChallengeRoom(roomId, challengeId: id, isHost: true);
          });
        } else if (challenge.status == 'rejected') {
          _handledOutgoing.add(challenge.id);
          unawaited(BattleMatchmakingService().deleteChallenge(challenge.id));
          // The waiting-room screen (if open) handles its own exit+cleanup.
          if (!_waitingRoomOpen) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showGlobalSnack(
                  'The player declined your challenge. Try another warrior! 🤺');
            });
          }
        }
      }
    });

    // 4) I ACCEPTED a challenge earlier (maybe in a previous app session)
    //    → restore my seat in the waiting room / arena (guest side).
    ref.watch(acceptedIncomingChallengesProvider).whenData((challenges) {
      for (final challenge in challenges) {
        if (_restoredAccepted.contains(challenge.id)) continue;
        if (challenge.roomId == null) continue;
        _restoredAccepted.add(challenge.id);
        final id = challenge.id;
        final roomId = challenge.roomId!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _enterChallengeRoom(roomId, challengeId: id, isHost: false);
        });
      }
    });

    return widget.child;
  }

  /// Routes me into a challenge room:
  ///  • room already in_progress (legacy flow / host started) → arena;
  ///  • room still waiting → the Waiting Room screen (host presses START).
  Future<void> _enterChallengeRoom(
    String roomId, {
    required String challengeId,
    required bool isHost,
  }) async {
    if (_waitingRoomOpen || battleWaitingRoomOpen) return;
    if (ref.read(battleArenaProvider).status == BattleArenaStatus.inDuel) {
      return;
    }

    try {
      final matchmaking = BattleMatchmakingService();
      var room = await matchmaking.getRoom(roomId);
      // Room may take a beat to propagate — retry once.
      if (room == null) {
        await Future.delayed(const Duration(milliseconds: 800));
        room = await matchmaking.getRoom(roomId);
      }
      if (room == null) {
        _showGlobalSnack('This duel room is no longer available.');
        return;
      }
      if (room.questions.isEmpty) {
        _showGlobalSnack(
            'Could not load the questions for this duel. Try again.');
        return;
      }

      if (room.status == BattleRoomStatus.inProgress) {
        // Already started (host hit START elsewhere, or legacy room) → arena.
        ref.read(battleArenaProvider.notifier).startFromRoom(room);
        return;
      }
      if (room.status != BattleRoomStatus.waiting) return;

      final navCtx = appNavigatorKey.currentContext;
      if (navCtx == null) return;
      _waitingRoomOpen = true;
      await Navigator.of(navCtx).push(
        MaterialPageRoute(
          builder: (_) => BattleWaitingRoomScreen(
            roomId: roomId,
            challengeId: challengeId,
            isHost: isHost,
          ),
        ),
      );
      _waitingRoomOpen = false;
    } catch (_) {
      _showGlobalSnack('Could not join the duel. Try again.');
    }
  }

  /// Compact "time ago" for the async-challenge badge.
  String _timeAgo(Duration diff) {
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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
        // Lives in the route-builder closure (runs ONCE), so the busy flag
        // survives StatefulBuilder rebuilds.
        bool busy = false;
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      challenge.isRematch
                          ? '🔁 1v1 REMATCH REQUESTED!'
                          : '⚔️ 1v1 CHALLENGE RECEIVED!',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: challenge.isRematch
                              ? const Color(0xFF8B5CF6)
                              : const Color(0xFFEF4444))),
                    ),
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
                      challenge.isRematch
                          ? '${challenge.fromUserName} wants a rematch!'
                          : '${challenge.fromUserName} wants to duel with you!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text('${challenge.fromUserTrophies} Trophies 🏆',
                        style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      challenge.roomId != null
                          ? '🏟️ A duel room is already prepared — accept to join it.'
                          : 'Accepting starts the duel immediately.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500]),
                    ),
                    if (challenge.isAsync)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '🕐 Sent ${_timeAgo(DateTime.now().difference(challenge.createdAt))} — while you were offline',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => _onDecline(sheetCtx, challenge),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: busy
                                ? null
                                : () {
                                    setSheetState(() => busy = true);
                                    _onAccept(sheetCtx, challenge,
                                        onDone: () =>
                                            setSheetState(() => busy = false));
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                                busy
                                    ? 'Joining…'
                                    : (challenge.isRematch
                                        ? 'Accept Rematch 🔁'
                                        : 'Accept Duel ⚔️'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              // "Later" — the lobby keeps showing a Respond
                              // banner, so the challenge is never lost.
                              _dismissedIncoming.add(challenge.id);
                              Navigator.pop(sheetCtx);
                            },
                      child: const Text('Later',
                          style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => _sheetOpen = false);
  }

  Future<void> _onAccept(
    BuildContext sheetCtx,
    BattleChallenge challenge, {
    required VoidCallback onDone,
  }) async {
    try {
      final matchmaking = BattleMatchmakingService();

      if (challenge.roomId != null) {
        // ROOM-FIRST: the room already exists — just accept and join it.
        await ref
            .read(battlePresenceServiceProvider)
            .respondToChallenge(challenge.id, true);
        _respondedIncoming.add(challenge.id);
        _restoredAccepted.add(challenge.id);
        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
        await _enterChallengeRoom(
          challenge.roomId!,
          challengeId: challenge.id,
          isHost: false,
        );
      } else {
        // LEGACY sender (older build): create the room now and start.
        final myUser = ref.read(authProvider).asData?.value;
        final myStats = ref.read(battleArenaProvider).stats;
        final room = await matchmaking.createDirectChallengeRoom(
          player1: BattlePlayer(
            id: challenge.fromUserId,
            name: challenge.fromUserName,
            photoUrl: challenge.fromUserPhoto,
            trophies: challenge.fromUserTrophies,
          ),
          player2: BattlePlayer(
            id: myUser?.id ?? 'me',
            name: myUser?.name ?? 'Me',
            photoUrl: myUser?.photoUrl ?? '',
            trophies: myStats.trophies,
          ),
        );
        await ref
            .read(battlePresenceServiceProvider)
            .respondToChallenge(challenge.id, true, roomId: room.id);
        _respondedIncoming.add(challenge.id);
        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
        ref.read(battleArenaProvider.notifier).startFromRoom(room);
      }
    } catch (_) {
      onDone();
      _showGlobalSnack('Could not accept the challenge. Try again.');
    }
  }

  Future<void> _onDecline(
      BuildContext sheetCtx, BattleChallenge challenge) async {
    try {
      await ref
          .read(battlePresenceServiceProvider)
          .respondToChallenge(challenge.id, false);
      // Free the waiting room immediately — participants may delete rooms
      // that are still 'waiting' (rules), even if the host is offline.
      if (challenge.roomId != null) {
        unawaited(
            BattleMatchmakingService().deleteRoom(challenge.roomId!));
      }
      _respondedIncoming.add(challenge.id);
      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
    } catch (_) {
      _showGlobalSnack('Could not decline. Try again.');
    }
  }
}
