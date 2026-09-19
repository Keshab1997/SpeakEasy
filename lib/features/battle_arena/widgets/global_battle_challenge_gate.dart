import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../../providers/auth_provider.dart';
import '../models/battle_models.dart';
import '../providers/battle_arena_provider.dart';
import '../providers/battle_presence_provider.dart';
import '../screens/battle_arena_screen.dart';
import '../screens/battle_result_screen.dart';
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
        // arenaIsLive (not just the flag) so a missed dispose can never
        // disable the arena for the rest of the session.
        if (BattleArenaScreen.arenaIsLive || _arenaOpen) return;
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
          // ⚠️ A LATE backlog emission (decline delivered while we were
          // offline/backgrounded) can arrive AFTER I already re-challenged:
          // the doc id is deterministic, so a blind deleteChallenge here
          // would kill the NEW challenge — the receiver's accept then hit a
          // missing doc and the whole resend broke. Re-verify first: only
          // delete when the doc is STILL this exact rejected instance.
          // (Deleting the rejected instance's ROOM is always safe — every
          // challenge gets its own room id.)
          try {
            unawaited(() async {
              try {
                final freshDoc = await ref
                    .read(battlePresenceServiceProvider)
                    .getChallenge(challenge.id);
                final sameInstance = freshDoc != null &&
                    freshDoc.status == 'rejected' &&
                    freshDoc.createdAt == challenge.createdAt;
                if (sameInstance) {
                  unawaited(matchmaking.deleteChallenge(challenge.id));
                }
              } catch (_) {
                // Read failed — leave the doc alone; a retry/replace flow
                // will clean it up later.
              }
            }());
          } catch (_) {}
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

  /// Drops a leftover result screen (+ its finished-duel state) before
  /// entering another duel. `removeRoute` targets the exact route, so a
  /// waiting room already pushed above it is never popped by mistake.
  void _clearStaleResultScreen(BattleArenaStatus status) {
    if (status != BattleArenaStatus.completed) return;
    final ctx = BattleResultScreen.activeContext;
    if (ctx != null && ctx.mounted) {
      final route = ModalRoute.of(ctx);
      if (route != null && route.isActive) {
        Navigator.of(ctx).removeRoute(route);
      }
    }
    // Reset only after the route is gone: the result screen watches the
    // provider, and rebuilding it on state meant for the NEXT duel is how a
    // stale scoreboard flash happens.
    ref.read(battleArenaProvider.notifier).resetLobby();
  }

  /// Owns the arena push for callers that have no waiting room of their own.
  /// Dedups against the live route (and the listener's own in-flight push),
  /// and says so out loud when navigation is impossible.
  Future<void> _pushArena() async {
    if (BattleArenaScreen.arenaIsLive || _arenaOpen) return;
    final navCtx = appNavigatorKey.currentContext;
    if (navCtx == null) {
      _showGlobalSnack('Could not open the duel — please try again.');
      return;
    }
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

  /// Routes me into a challenge room:
  ///  • room already in_progress (legacy flow / host started) → arena;
  ///  • room still waiting → the Waiting Room screen (host presses START).
  Future<void> _enterChallengeRoom(
    String roomId, {
    required String challengeId,
    required bool isHost,
  }) async {
    if (_waitingRoomOpen || battleWaitingRoomOpen) return;
    final duel = ref.read(battleArenaProvider);
    if (duel.status == BattleArenaStatus.inDuel) {
      // Only a duel for THIS room means "already inside". A stale `inDuel`
      // (previous duel whose state never got reset) used to swallow every
      // later accept with no message — a rematch then looked like a dead
      // button while the old duel's result screen stayed on screen.
      if (duel.room?.id == roomId) return;
    }
    // A finished duel's result screen must not sit underneath the new one:
    // it is where the player lands when the rematch pops, and its stale
    // scores are what they see while the real match runs above it.
    _clearStaleResultScreen(duel.status);

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
        // Navigating must happen HERE, not by hoping the global listener
        // reacts: _onAccept popped its sheet in this same frame, and a push
        // issued that early can die — leaving the duel running with no screen
        // at all, which is exactly what an accepted rematch used to feel like.
        ref.read(battleArenaProvider.notifier).startFromRoom(room);
        await _pushArena();
        return;
      }
      if (room.status != BattleRoomStatus.waiting) {
        _showGlobalSnack('This duel is already over — send a new challenge.');
        return;
      }

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

  /// After accepting one challenge, auto-decline other pending ones
  /// so the user doesn't get spammed with sequential popups.
  /// Also cancels any *outgoing* pending to the same challenger (cross-challenge A→B + B→A).
  Future<void> _declineOtherPendingChallenges(
      {required BattleChallenge accepted}) async {
    final keepId = accepted.id;
    final challengerId = accepted.fromUserId;
    // 1) Decline other incoming pending (to me, from others)
    try {
      final incoming = ref.read(incomingChallengesProvider).asData?.value ?? [];
      final toDecline = incoming.where((c) => c.id != keepId).toList();
      for (final c in toDecline) {
        try {
          await ref
              .read(battlePresenceServiceProvider)
              .respondToChallenge(c.id, false);
          if (c.roomId != null) {
            unawaited(BattleMatchmakingService().deleteRoom(c.roomId!));
          }
          _respondedIncoming[c.id] = c.createdAt;
        } catch (_) {}
      }
    } catch (_) {}
    // 2) Cancel outgoing pending to the same challenger (cross-challenge)
    try {
      final outgoing = ref.read(outgoingChallengesProvider).asData?.value ?? [];
      final outgoingToCancel = outgoing
          .where(
              (c) => c.toUserId == challengerId && c.status == 'pending')
          .toList();
      for (final c in outgoingToCancel) {
        try {
          // Sender can delete own pending challenge + waiting room
          await BattleMatchmakingService().deleteChallenge(c.id);
          if (c.roomId != null) {
            unawaited(BattleMatchmakingService().deleteRoom(c.roomId!));
          }
          _handledOutgoing[c.id] = c.createdAt;
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _onAccept(
    BuildContext sheetCtx,
    BattleChallenge challenge, {
    required VoidCallback onDone,
  }) async {
    try {
      final matchmaking = BattleMatchmakingService();
      final presence = ref.read(battlePresenceServiceProvider);

      // ── FRESH CHALLENGE RE-VERIFICATION ─────────────────────
      // The sheet may be holding a STALE object: the per-pair doc id is
      // deterministic, so a challenge that was declined once and sent again
      // REUSES the same id with a NEW createdAt and a NEW room. Accepting a
      // stale instance used to join the DEAD room (or nothing), and the
      // sender then saw "left the room". Re-read the doc and act on ITS
      // state: pending/accepted + the CURRENT roomId.
      final fresh = await presence.getChallenge(challenge.id);
      if (fresh != null) {
        if (fresh.status == 'rejected') {
          onDone();
          _respondedIncoming[fresh.id] = fresh.createdAt;
          _showGlobalSnack(
              'This challenge was declined already — ask for a new one 🤺',
              color: const Color(0xFF64748B));
          return;
        }
        if (fresh.status == 'pending' || fresh.status == 'accepted') {
          challenge = fresh;
        }
      }

      // ── SENDER LIVENESS CHECK (with room fallback) ──────────
      // Strictly blocking on presence alone caused false negatives
      // (heartbeat 20s + network jitter = stale lastActive). If the
      // sender appears offline but their waiting room still exists and
      // is in 'waiting', we allow the join — the room is the source of
      // truth, presence is just a hint.
      bool senderOnline = await presence.isUserOnline(challenge.fromUserId);
      if (!senderOnline && challenge.roomId != null) {
        try {
          final fallbackRoom = await matchmaking.getRoom(challenge.roomId!);
          if (fallbackRoom != null &&
              fallbackRoom.status == BattleRoomStatus.waiting) {
            senderOnline = true;
            debugPrint('⚠️ sender presence offline but room is waiting — allowing accept (fallback)');
          }
        } catch (_) {}
      }
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
        // Auto-decline other pending challenges to stop the
        // "por por request astey thake" spam loop.
        unawaited(_declineOtherPendingChallenges(accepted: challenge));
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
        unawaited(_declineOtherPendingChallenges(accepted: challenge));
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
