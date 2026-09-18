import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/battle_models.dart';
import '../providers/battle_arena_provider.dart';
import '../screens/battle_arena_screen.dart';
import '../services/battle_matchmaking_service.dart';
import '../services/battle_presence_service.dart';

/// True while ANY waiting-room route is on screen. The challenge gate
/// checks this before pushing its own copy (the host can arrive here via
/// the lobby OR via the gate — never both).
bool battleWaitingRoomOpen = false;

/// ROOM-FIRST challenge flow:
///   • the sender creates the room at CHALLENGE TIME (status: 'waiting')
///     and waits here — Cancel until the receiver accepts, then START;
///   • the receiver joins this room when they ACCEPT and waits for the
///     host to press START;
///   • START flips the room to in_progress → both devices enter the arena.
class BattleWaitingRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String challengeId;
  final bool isHost;

  const BattleWaitingRoomScreen({
    super.key,
    required this.roomId,
    required this.challengeId,
    required this.isHost,
  });

  @override
  ConsumerState<BattleWaitingRoomScreen> createState() =>
      _BattleWaitingRoomScreenState();
}

class _BattleWaitingRoomScreenState
    extends ConsumerState<BattleWaitingRoomScreen>
    with SingleTickerProviderStateMixin {
  final BattleMatchmakingService _matchmaking = BattleMatchmakingService();

  /// Hydrated room (questions regenerated from the seed) — this exact
  /// object is handed to the arena on start.
  BattleRoom? _room;
  bool _loading = true;
  bool _enteringArena = false;
  bool _arenaPushed = false;
  bool _leaving = false;
  bool _joinMarked = false;
  bool _busy = false;

  StreamSubscription<BattleRoom?>? _roomSub;
  StreamSubscription<BattleChallenge?>? _challengeSub;

  /// Guests waiting for the host to press START auto-leave after 2 minutes —
  /// covers the host's app dying / walking away after the guest joined, so
  /// the guest is never soft-locked staring at "waiting for host" forever.
  Timer? _guestStartTimeout;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    battleWaitingRoomOpen = true;
    _init();
  }

  Future<void> _init() async {
    // Fetch + hydrate once (snapshots below don't carry questions for
    // seed rooms).
    final room = await _matchmaking.getRoom(widget.roomId);
    if (!mounted) return;
    if (room == null || room.questions.isEmpty) {
      _toast('This duel room is no longer available.');
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _room = room;
      _loading = false;
    });

    // Guest announces the join so the host's START button unlocks.
    if (!widget.isHost && !_joinMarked) {
      _joinMarked = true;
      unawaited(_matchmaking.markPlayer2Joined(widget.roomId));
      _guestStartTimeout?.cancel();
      _guestStartTimeout = Timer(const Duration(minutes: 2), () {
        if (!mounted || _leaving || _enteringArena) return;
        if (_room?.status != BattleRoomStatus.waiting) return;
        _leaving = true;
        unawaited(_matchmaking.markPlayer2Left(widget.roomId));
        _toast('The host seems away — you left the room. Try again! 🤺');
        Navigator.of(context).pop();
      });
    }

    _listenToRoom();
    if (widget.isHost) _listenToChallenge();
  }

  void _listenToRoom() {
    _roomSub?.cancel();
    _roomSub = _matchmaking.streamRoom(widget.roomId).listen((snapshot) {
      if (!mounted || _leaving) return;

      // Room deleted (host cancelled / cleanup).
      if (snapshot == null) {
        if (_enteringArena) return;
        _leaving = true;
        _toast(widget.isHost
            ? 'The duel room was closed.'
            : 'The host cancelled the challenge.');
        Navigator.of(context).pop();
        return;
      }

      // Merge live fields onto the hydrated room (questions stay local).
      _room = _room!.copyWith(
        status: snapshot.status,
        player2JoinedAt: snapshot.player2JoinedAt,
        player2LeftAt: snapshot.player2LeftAt,
        player1: snapshot.player1,
        player2: snapshot.player2,
      );

      // Host started the duel → both sides enter the arena.
      if (snapshot.status == BattleRoomStatus.inProgress) {
        unawaited(_enterArenaNow());
        return;
      }

      // Host-only reactions while waiting.
      if (widget.isHost) {
        if (snapshot.player2LeftAt != null) {
          _leaving = true;
          unawaited(_matchmaking.deleteRoom(widget.roomId));
          _toast('${snapshot.player2.name} left the room.');
          Navigator.of(context).pop();
          return;
        }
      }

      setState(() {});
    });
  }

  /// Host watches the challenge doc: declined/deleted → close everything.
  void _listenToChallenge() {
    _challengeSub?.cancel();
    _challengeSub = BattlePresenceService()
        .streamChallenge(widget.challengeId)
        .listen((challenge) {
      if (!mounted || _leaving || _enteringArena) return;
      final declined = challenge == null || challenge.status == 'rejected';
      if (!declined) return;

      _leaving = true;
      unawaited(_matchmaking.deleteRoom(widget.roomId));
      unawaited(_matchmaking.deleteChallenge(widget.challengeId));
      _toast('The player declined your challenge. 🤺');
      Navigator.of(context).pop();
    });
  }

  void _enterArena() {
    if (_enteringArena) return;
    _enteringArena = true;
    if (mounted) Navigator.of(context).pop();
  }

  /// The screen that STARTED the duel is the one that navigates into it —
  /// no global listener may be the only path in. That indirection is exactly
  /// how both players ended up hearing the round timer while still looking
  /// at this waiting room.
  Future<void> _enterArenaNow() async {
    if (_arenaPushed || _leaving) return;
    final room = _room;
    if (room == null || room.questions.isEmpty) {
      _toast('Could not load the questions for this duel.');
      return;
    }
    _arenaPushed = true;
    ref.read(battleArenaProvider.notifier).startFromRoom(room);
    if (BattleArenaScreen.routeActive) return; // restore path already put us in
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const BattleArenaScreen()),
    );
    // Pop only AFTER the arena is on top of us. Popping first tore the root
    // navigator's context out from under any other navigation in the frame.
    _enterArena();
  }

  Future<void> _startBattle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // The Firestore write only resolves on server ack — on a flaky/offline
      // connection the await hangs forever and the button sticks on
      // STARTING… while the guest waits indefinitely. Bounding it turns the
      // hang into an actionable error; retrying is safe (idempotent flip).
      await _matchmaking.startWaitingRoom(widget.roomId).timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('start battle timed out'),
      );
      // The room snapshot flips to in_progress → _enterArena() fires.
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      _toast('Could not start the battle. Check your internet and try again.');
    }
  }

  Future<void> _cancelAsHost() async {
    if (_leaving) return;
    _leaving = true;
    unawaited(_matchmaking.deleteChallenge(widget.challengeId));
    unawaited(_matchmaking.deleteRoom(widget.roomId));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _leaveAsGuest() async {
    if (_leaving) return;
    _leaving = true;
    unawaited(_matchmaking.markPlayer2Left(widget.roomId));
    if (mounted) Navigator.of(context).pop();
  }

  void _toast(String message) {
    final ctx = mounted ? context : null;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  void dispose() {
    battleWaitingRoomOpen = false;
    _pulse.dispose();
    _roomSub?.cancel();
    _challengeSub?.cancel();
    _guestStartTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final room = _room;

    // System back = Cancel (host) / Leave (guest) — same cleanup as the
    // visible buttons, so nobody can ghost a waiting room silently.
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop || _leaving || _enteringArena) return;
        if (widget.isHost) {
          unawaited(_matchmaking.deleteChallenge(widget.challengeId));
          unawaited(_matchmaking.deleteRoom(widget.roomId));
        } else {
          unawaited(_matchmaking.markPlayer2Left(widget.roomId));
        }
      },
      child: Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF0A1020), Color(0xFF0F172A), Color(0xFF101B33)]
                : const [Color(0xFFF8FAFC), Color(0xFFF1F5F9), Color(0xFFE7EDF5)],
          ),
        ),
        child: SafeArea(
          child: _loading || room == null
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        widget.isHost ? '⚔️ DUEL LOBBY' : '🛡️ DUEL LOBBY',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Player cards + VS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _playerCard(room.player1, isDark,
                              label: room.player1.id == _myId() ? 'YOU' : 'HOST'),
                          const Text(
                            'VS',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                          _playerCard(room.player2, isDark,
                              label: room.player2.id == _myId() ? 'YOU' : 'GUEST'),
                        ],
                      ),
                      const SizedBox(height: 32),

                      Expanded(child: _buildStatusArea(room, theme)),

                      _buildActionArea(room),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
        ),
      ),
      ),
    );
  }

  String _myId() => ref.read(battleArenaProvider).localPlayer.id;

  Widget _playerCard(BattlePlayer player, bool isDark, {required String label}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
            ),
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            radius: 34,
            backgroundColor:
                isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            backgroundImage:
                player.photoUrl.isNotEmpty ? NetworkImage(player.photoUrl) : null,
            child: player.photoUrl.isEmpty
                ? Text(
                    player.name.isNotEmpty
                        ? player.name[0].toUpperCase()
                        : 'P',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          player.name.length > 12
              ? '${player.name.substring(0, 11)}…'
              : player.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 2),
        Text('${player.trophies} 🏆',
            style: const TextStyle(fontSize: 12, color: Color(0xFFF59E0B))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3B82F6))),
        ),
      ],
    );
  }

  Widget _buildStatusArea(BattleRoom room, ThemeData theme) {
    final joined = room.player2JoinedAt != null;

    String title;
    String subtitle;
    if (!widget.isHost) {
      title = 'You joined the room! ✅';
      subtitle = 'Waiting for ${room.player1.name} to start the battle…';
    } else if (joined) {
      title = '${room.player2.name} is ready! 🔥';
      subtitle = 'Press START when you are ready to fight.';
    } else {
      title = 'Waiting for ${room.player2.name}…';
      subtitle =
          'They will see your challenge now. The room is already prepared ⚔️';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => Opacity(
            opacity: 0.55 + 0.45 * _pulse.value,
            child: Text(
              widget.isHost && joined ? '🎯' : '⏳',
              style: const TextStyle(fontSize: 54),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(title,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildActionArea(BattleRoom room) {
    final joined = room.player2JoinedAt != null;

    if (widget.isHost && joined) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _busy ? null : _startBattle,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 6,
          ),
          child: Text(
            _busy ? 'STARTING…' : '⚔️ START BATTLE',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ),
      );
    }

    final cancelLabel =
        widget.isHost ? '✖ Cancel Challenge' : '🚪 Leave Room';
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: widget.isHost ? _cancelAsHost : _leaveAsGuest,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey,
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(cancelLabel,
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
