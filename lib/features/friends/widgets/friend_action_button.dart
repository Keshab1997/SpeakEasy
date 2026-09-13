import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../battle_arena/providers/battle_arena_provider.dart';
import '../providers/friend_providers.dart';

/// Compact "+" / friend-state button for player cards, profile sheets and
/// the post-match result screen.
///
/// States:
///   • already friends      → green person-check (disabled)
///   • outgoing request     → hourglass "Requested" (tap cancels)
///   • incoming request     → "Accept" button (accepts instantly)
///   • nothing yet          → person-add → sends a request (+ push via CF)
class FriendActionButton extends ConsumerStatefulWidget {
  final String targetUserId;
  final String targetName;
  final String targetPhotoUrl;
  final int targetTrophies;

  /// true = circular icon-only (player cards); false = full labelled button.
  final bool compact;

  const FriendActionButton({
    super.key,
    required this.targetUserId,
    required this.targetName,
    this.targetPhotoUrl = '',
    this.targetTrophies = 100,
    this.compact = true,
  });

  @override
  ConsumerState<FriendActionButton> createState() => _FriendActionButtonState();
}

class _FriendActionButtonState extends ConsumerState<FriendActionButton> {
  bool _busy = false;

  void _snack(String message, {Color color = const Color(0xFF10B981)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _sendRequest() async {
    final me = ref.read(authProvider).asData?.value;
    if (me == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(friendServiceProvider).sendFriendRequest(
            fromUserId: me.id,
            fromUserName: me.name,
            fromUserPhoto: me.photoUrl,
            fromUserTrophies: ref.read(battleArenaProvider).stats.trophies,
            toUserId: widget.targetUserId,
          );
      _snack('Friend request sent to ${widget.targetName}! 🤝');
    } catch (_) {
      _snack('Could not send friend request.', color: const Color(0xFFEF4444));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(String requestId) async {
    final requests =
        ref.read(incomingFriendRequestsProvider).asData?.value ?? [];
    final req = requests.where((r) => r.id == requestId).firstOrNull;
    if (req == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(friendServiceProvider).acceptFriendRequest(req);
      _snack('You are now friends with ${widget.targetName}! 🎉');
    } catch (_) {
      _snack('Could not accept request.', color: const Color(0xFFEF4444));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(String requestId) async {
    try {
      await ref.read(friendServiceProvider).cancelOutgoingRequest(requestId);
      _snack('Friend request cancelled.');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).asData?.value;
    if (me == null || me.id == widget.targetUserId) {
      return const SizedBox.shrink();
    }

    final friends = ref.watch(myFriendsProvider).asData?.value ?? [];
    final outgoing = ref.watch(outgoingFriendRequestsProvider).asData?.value ?? [];
    final incoming = ref.watch(incomingFriendRequestsProvider).asData?.value ?? [];

    final isFriend = friends.any((f) => f.id == widget.targetUserId);
    final outReq = outgoing
        .where((r) => r.toUserId == widget.targetUserId)
        .firstOrNull;
    final inReq = incoming
        .where((r) => r.fromUserId == widget.targetUserId)
        .firstOrNull;

    // ── Already friends ────────────────────────────────────────────────
    if (isFriend) {
      return widget.compact
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.check_circle_rounded,
                  size: 22, color: Color(0xFF10B981)),
            )
          : OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('Friends ✓'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF10B981),
              ),
            );
    }

    // ── Incoming request from them → accept ───────────────────────────
    if (inReq != null) {
      final label = widget.compact ? null : 'Accept';
      return widget.compact
          ? IconButton(
              tooltip: 'Accept friend request',
              onPressed: _busy ? null : () => _accept(inReq.id),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.person_add_alt_1_rounded,
                      color: Color(0xFF10B981)),
            )
          : ElevatedButton.icon(
              onPressed: _busy ? null : () => _accept(inReq.id),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(label ?? 'Accept'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
            );
    }

    // ── Outgoing request pending → tap to cancel ──────────────────────
    if (outReq != null) {
      return widget.compact
          ? IconButton(
              tooltip: 'Friend request sent — tap to cancel',
              onPressed: () => _cancel(outReq.id),
              icon: const Icon(Icons.hourglass_top_rounded,
                  color: Color(0xFFF59E0B)),
            )
          : OutlinedButton.icon(
              onPressed: () => _cancel(outReq.id),
              icon: const Icon(Icons.hourglass_top_rounded, size: 18),
              label: const Text('Requested'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF59E0B),
              ),
            );
    }

    // ── Nothing yet → send request ────────────────────────────────────
    return widget.compact
        ? IconButton(
            tooltip: 'Send friend request',
            onPressed: _busy ? null : _sendRequest,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.person_add_alt_rounded,
                    color: Color(0xFF8B5CF6)),
          )
        : ElevatedButton.icon(
            onPressed: _busy ? null : _sendRequest,
            icon: const Icon(Icons.person_add_alt_rounded, size: 18),
            label: const Text('Add Friend'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
            ),
          );
  }
}
