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
    extends ConsumerState<GlobalBattleChallengeGate>
    with WidgetsBindingObserver {
  /// Challenges we already RESPONDED to (accepted/declined) — no re-sheet.
  /// Keyed by challenge id, but stores the `createdAt` we answered: challenge
  /// ids are deterministic (`ch_{from}_{to}`), so a RESENT challenge reuses
  /// the SAME id with a NEWER createdAt and must surface again. We only
  /// suppress when the timestamp matches the instance we already handled.
  final Map<String, DateTime> _respondedIncoming = {};

  /// Challenges the user postponed with "Later" — no auto re-sheet, but the
  /// lobby banner keeps offering a Respond button (reshowChallengeProvider).
  /// Same createdAt logic as above so a resent challenge resurfaces.
  final Map<String, DateTime> _dismissedIncoming = {};

  bool _isStaleHandled(Map<String, DateTime> handled, BattleChallenge c) {
    final handledAt = handled[c.id];
    if (handledAt == null) return false;
    // Suppress only the SAME instance; a newer createdAt = a resend.
    return !c.createdAt.isAfter(handledAt);
  }

  /// Outgoing/accepted challenges we already routed somewhere. Same
  /// createdAt logic as the incoming maps: the deterministic id is reused by
  /// a resend, so only suppress the exact instance we already routed.
  final Map<String, DateTime> _handledOutgoing = {};
  final Map<String, DateTime> _restoredAccepted = {};

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Receiver comes back to the app → re-evaluate pending challenges NOW.
  /// Stream emissions only fire on Firestore changes; if the challenge doc
  /// arrived while the app was backgrounded (no snapshot since), the sheet
  /// would otherwise wait for the next unrelated write. A rebuild re-runs
  /// the incoming-challenge block and surfaces the popup.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1) Navigate into the arena whenever a duel starts (quick match OR a
    //    challenge accepted from anywhere).
    ref.listen<BattleArenaState>(battleArenaProvider, (prev, next) async {
      final wasDuel = prev?.status == BattleArenaStatus.inDuel;
      final isDuel = next.status == BattleArenaStatus.inDuel;

      if (!wasDuel && isDuel) {
        // One frame of slack. The widget that starts the duel flips the
        // provider state and pops itself in the SAME frame, and a pop queued
        // that early leaves the root navigator's context stale for this push
        // — the await then dies, and (before the try/finally below) left
        // _arenaOpen pinned true for the rest of the app's life: every later
        // duel in the session silently never opened. Sound kept playing
        // because the round timers live in the provider, not the screen.
        await Future<void>.delayed(Duration.zero);
        if (!mounted) return;
        if (ref.read(battleArenaProvider).status != BattleArenaStatus.inDuel) return;
        // Whoever opened the duel navigates into it; this listener only covers
        // quick match and mid-session restores. BattleArenaScreen.routeActive
        // is the ground truth, so this can neither double-push nor fight the
        // waiting room for the same duel.
        if (BattleArenaScreen.routeActive || _arenaOpen) return;
        final navCtx = appNavigatorKey.currentContext;
        if (navCtx == null) return;
        _arenaOpen = true;
        try {
          // ignore: use_build_context_synchronously
          await Navigator.of(navCtx, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => const BattleArenaScreen()),
          );
        } finally {
          _arenaOpen = false;
        }
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
        if (_isStaleHandled(_respondedIncoming, c)) continue;
        if (_isStaleHandled(_dismissedIncoming, c)) continue;
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
        if (_isStaleHandled(_handledOutgoing, challenge)) continue;

        if (challenge.status == 'accepted' && challenge.roomId != null) {
          _handledOutgoing[challenge.id] = challenge.createdAt;
          final id = challenge.id;
          final roomId = challenge.roomId!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _enterChallengeRoom(roomId, challengeId: id, isHost: true);
          });
        } else if (challenge.status == 'rejected') {
          _handledOutgoing[challenge.id] = challenge.createdAt;
          final matchmaking = BattleMatchmakingService();
          unawaited(matchmaking.deleteChallenge(challenge.id));
          // Declined → free the waiting room instantly, even when the host
          // is NOT on the waiting-room screen (app restart / lobby). Rules
          // allow participants to delete rooms still in 'waiting'.
          final deadRoomId = challenge.roomId;
          if (deadRoomId != null) {
            unawaited(matchmaking.deleteRoom(deadRoomId));
          }
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
        if (_isStaleHandled(_restoredAccepted, challenge)) continue;
        if (challenge.roomId == null) continue;
        _restoredAccepted[challenge.id] = challenge.createdAt;
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
      // ignore: use_build_context_synchronously
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
                              _dismissedIncoming[challenge.id] = challenge.createdAt;
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
      final presence = ref.read(battlePresenceServiceProvider);

      // The duel needs the SENDER live: room-first they must press START in
      // the waiting room, legacy the match begins instantly on accept.
      // Accepting while they're offline launches a GHOST MATCH — the
      // receiver plays alone, scores climb, the absent sender sits at 0.
      // Block the accept (challenge stays pending, sheet stays retryable)
      // and tell the user to accept when the challenger is back online.
      final senderOnline = await presence.isUserOnline(challenge.fromUserId);
      if (!senderOnline) {
        onDone();
        _showGlobalSnack(
            '${challenge.fromUserName} is offline right now 📴 — accept again when they are back online!',
            color: const Color(0xFF64748B));
        return;
      }

      if (challenge.roomId != null) {
        // ROOM-FIRST: the room already exists — just accept and join it.
        await presence.respondToChallenge(challenge.id, true);
        _respondedIncoming[challenge.id] = challenge.createdAt;
        _restoredAccepted[challenge.id] = challenge.createdAt;
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
        await presence.respondToChallenge(challenge.id, true, roomId: room.id);
        _respondedIncoming[challenge.id] = challenge.createdAt;
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
      _respondedIncoming[challenge.id] = challenge.createdAt;
      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
    } catch (_) {
      _showGlobalSnack('Could not decline. Try again.');
    }
  }
}
