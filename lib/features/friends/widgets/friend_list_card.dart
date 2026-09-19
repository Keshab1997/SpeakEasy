import 'package:flutter/material.dart';
import '../models/friend_models.dart';

/// Card for one entry of MY FRIENDS in the battle lobby.
/// Shows live online/offline state, one-tap challenge (live when online,
/// async when offline) and long-press to remove.
class FriendListCard extends StatelessWidget {
  final Friend friend;
  final bool isOnline;
  final bool isInBattle;
  final bool isChallenging;
  final VoidCallback onChallenge;
  final VoidCallback onRemove;

  const FriendListCard({
    super.key,
    required this.friend,
    required this.isOnline,
    this.isInBattle = false,
    this.isChallenging = false,
    required this.onChallenge,
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
                  backgroundImage: friend.photoUrl.isNotEmpty
                      ? NetworkImage(friend.photoUrl)
                      : null,
                  child: friend.photoUrl.isEmpty
                      ? Text(
                          friend.name.isNotEmpty
                              ? friend.name[0].toUpperCase()
                              : 'P',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981)),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isOnline
                          ? (isInBattle
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981))
                          : const Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        width: 2,
                      ),
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
                  Text(
                    friend.name,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          color: Color(0xFFF59E0B), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${friend.trophies} 🏆',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFF59E0B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: (isOnline
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF94A3B8))
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isOnline
                              ? (isInBattle ? '⚔️ IN BATTLE' : 'ONLINE')
                              : 'OFFLINE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isOnline
                                ? const Color(0xFF10B981)
                                : const Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: (isChallenging || (isOnline && isInBattle))
                  ? null
                  : onChallenge,
              icon: const Icon(Icons.sports_kabaddi_rounded, size: 16),
              label: Text(isOnline && isInBattle
                  ? 'Busy'
                  : (isChallenging ? 'Pending ⏳' : 'Duel ⚔️')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${friend.name}?'),
        content: const Text(
            'They will be removed from your friends list. You can send a new request later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRemove();
            },
            child: const Text('Remove',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }
}
