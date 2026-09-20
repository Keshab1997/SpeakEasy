import 'package:flutter/material.dart';
import '../models/friend_models.dart';
import '../../battle_arena/models/battle_models.dart';

class FriendListCard extends StatelessWidget {
  final Friend friend;
  final bool isOnline;
  final bool isInBattle;
  final bool isChallenging;
  final BattleChallenge? pendingChallenge;
  final VoidCallback onChallenge;
  final VoidCallback? onCancel;
  final VoidCallback onRemove;

  const FriendListCard({
    super.key,
    required this.friend,
    required this.isOnline,
    this.isInBattle = false,
    this.isChallenging = false,
    this.pendingChallenge,
    required this.onChallenge,
    this.onCancel,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onLongPress: () => _confirmRemove(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                  backgroundImage: friend.photoUrl.isNotEmpty ? NetworkImage(friend.photoUrl) : null,
                  child: friend.photoUrl.isEmpty ? Text(friend.name.isNotEmpty ? friend.name[0].toUpperCase() : 'P', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))) : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isOnline ? (isInBattle ? const Color(0xFFF59E0B) : const Color(0xFF10B981)) : const Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(friend.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 14),
                      const SizedBox(width: 4),
                      Text('${friend.trophies} 🏆', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: (isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8)).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text(isOnline ? (isInBattle ? '⚔️ IN BATTLE' : 'ONLINE') : 'OFFLINE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8), letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (isOnline && isInBattle) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.sports_kabaddi_rounded, size: 16),
        label: const Text('Busy'),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), elevation: 2),
      );
    }
    if (pendingChallenge != null) {
      // ⏳ ASYNC invites live 48 HOURS — no fake countdown ("Expiring..."
      // মিথ্যা ছিল); শান্ত, cancelable "Sent 🔔 ✕"। LIVE pendings আসল 90s
      // TTL-এ কাউন্ট ডাউন করবে (আগের 60s ভুল ছিল)।
      if (pendingChallenge!.isAsync) {
        return ElevatedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.notifications_active_rounded, size: 14),
          label: const Text('Sent 🔔 ✕',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF64748B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            elevation: 2,
          ),
        );
      }
      return ElevatedButton.icon(
        onPressed: onCancel,
        icon: const Icon(Icons.close_rounded, size: 14),
        label: _CountdownText(challenge: pendingChallenge!, totalSeconds: BattleChallenge.liveTtl.inSeconds),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), elevation: 2),
      );
    }
    if (isChallenging) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        label: const Text('Sending...'),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), elevation: 2),
      );
    }
    // Offline friend = async INVITE (delivered on their next login),
    // not an instant duel — the label must say so.
    final onlineTarget = isOnline;
    return ElevatedButton.icon(
      onPressed: onChallenge,
      icon: Icon(onlineTarget ? Icons.sports_kabaddi_rounded : Icons.notifications_active_rounded, size: 16),
      label: Text(onlineTarget ? 'Duel ⚔️' : 'Invite 🔔'),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), elevation: 2),
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${friend.name}?'),
        content: const Text('They will be removed from your friends list. You can send a new request later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () { Navigator.pop(ctx); onRemove(); }, child: const Text('Remove', style: TextStyle(color: Color(0xFFEF4444)))),
        ],
      ),
    );
  }
}

class _CountdownText extends StatelessWidget {
  final BattleChallenge challenge;
  final int totalSeconds;
  const _CountdownText({required this.challenge, required this.totalSeconds});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i).asBroadcastStream(),
      builder: (context, snapshot) {
        final elapsed = DateTime.now().difference(challenge.createdAt).inSeconds;
        final remaining = (totalSeconds - elapsed).clamp(0, totalSeconds);
        if (remaining <= 0) return const Text('⌛');
        return Text('$remaining' 's ✕', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold));
      },
    );
  }
}
