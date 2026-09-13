import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/friend_providers.dart';
import '../services/friend_service.dart';

/// Incoming friend requests — Accept / Decline.
/// Opened from the MY FRIENDS header chip in the Battle Lobby.
class FriendRequestsScreen extends ConsumerWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final requestsAsync = ref.watch(incomingFriendRequestsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Friend Requests',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mail_outline_rounded,
                      size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text('No pending friend requests',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Requests from other learners will appear here.',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final req = requests[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      backgroundImage: req.fromUserPhoto.isNotEmpty
                          ? NetworkImage(req.fromUserPhoto)
                          : null,
                      child: req.fromUserPhoto.isEmpty
                          ? Text(
                              req.fromUserName.isNotEmpty
                                  ? req.fromUserName[0].toUpperCase()
                                  : 'P',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8B5CF6)),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.fromUserName,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text('${req.fromUserTrophies} Trophies 🏆',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFFF59E0B))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Decline
                    IconButton(
                      tooltip: 'Decline',
                      onPressed: () => ref
                          .read(friendServiceProvider)
                          .rejectFriendRequest(req.id),
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFFEF4444)),
                    ),
                    // Accept
                    ElevatedButton(
                      onPressed: () => ref
                          .read(friendServiceProvider)
                          .acceptFriendRequest(req),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Accept',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load requests')),
      ),
    );
  }
}
