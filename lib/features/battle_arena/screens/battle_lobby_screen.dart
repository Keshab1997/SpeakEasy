import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/auth_provider.dart';
import '../../friends/models/friend_models.dart';
import '../../friends/providers/friend_providers.dart';
import '../../friends/screens/friend_requests_screen.dart';
import '../../friends/services/friend_service.dart';
import '../../friends/widgets/friend_list_card.dart';
import '../models/battle_models.dart';
import '../providers/battle_arena_provider.dart';
import '../providers/battle_presence_provider.dart';
import '../services/battle_matchmaking_service.dart';
import '../services/battle_presence_service.dart';
import '../widgets/live_player_card.dart';
import '../widgets/recent_player_card.dart';
import '../widgets/radar_search_dialog.dart';
import 'battle_leaderboard_screen.dart';
import 'battle_waiting_room_screen.dart';

class BattleLobbyScreen extends ConsumerStatefulWidget {
  const BattleLobbyScreen({super.key});

  @override
  ConsumerState<BattleLobbyScreen> createState() => _BattleLobbyScreenState();
}

class _BattleLobbyScreenState extends ConsumerState<BattleLobbyScreen> {
  String? _challengingUserId;

  @override
  void initState() {
    super.initState();
    // Presence heartbeat runs while the lobby is open. (Challenge popups and
    // arena navigation are handled app-wide by GlobalBattleChallengeGate.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).asData?.value;
      if (user != null) {
        final stats = ref.read(battleArenaProvider).stats;
        ref.read(battlePresenceServiceProvider).startPresenceHeartbeat(
              userId: user.id,
              name: user.name,
              photoUrl: user.photoUrl,
              trophies: stats.trophies,
            );
      }
    });
  }

  @override
  void dispose() {
    // Stop the presence heartbeat when the lobby leaves the nav stack —
    // previously it kept running on every screen for the whole app session
    // (wasted writes + false "online" presence in Home/Quiz/etc.).
    // During an active duel the arena route sits ON TOP of the lobby, so
    // the lobby stays mounted and the heartbeat keeps running (required —
    // the server auto-forfeit relies on it).
    final user = ref.read(authProvider).asData?.value;
    if (user != null) {
      ref.read(battlePresenceServiceProvider).stopPresenceHeartbeat(user.id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final battleState = ref.watch(battleArenaProvider);
    final onlineUsersAsync = ref.watch(onlineBattleUsersProvider);
    // Reactive pending-challenge tracking — disables Duel buttons instantly
    // across the whole lobby when a challenge to that user is pending.
    // Forfeit/exit from a duel returns here — notify the trophy loss.
    ref.listen<BattleArenaState>(battleArenaProvider, (previous, next) {
      if (previous != null &&
          previous.status == BattleArenaStatus.inDuel &&
          next.status == BattleArenaStatus.idle &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You surrendered the battle — 10 Trophies lost. ⚔️'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('⚔️ Battle Arena', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Leaderboard & Stats',
            icon: const Icon(Icons.leaderboard_rounded, color: Color(0xFFF59E0B)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BattleLeaderboardScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 0. Pending challenge banner (challenges postponed with
              //    "Later" stay actionable from here — never a dead end).
              SliverToBoxAdapter(child: _buildPendingChallengeBanner()),

              // 1. Top Hero Card: Stats & Division
              SliverToBoxAdapter(
                child: _buildHeroStatsCard(context, theme, isDark, battleState.stats),
              ),

              // 2. Big Quick Match Button
              SliverToBoxAdapter(
                child: _buildQuickMatchButton(context, isDark),
              ),

              // 2.5 My Friends (live presence + one-tap challenge)
              ..._buildFriendsSection(theme, isDark),

              // 3. Section Title: Live Warriors
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ONLINE LEARNERS',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const Spacer(),
                      onlineUsersAsync.when(
                        data: (users) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${users.length} Active',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Live Players List
              onlineUsersAsync.when(
                data: (users) {
                  if (users.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.people_outline_rounded, size: 40, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              'No other players online right now',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Hit Quick Match to instantly duel with an AI Challenger! 🤖',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final u = users[index];
                        final pendingMap = ref.watch(outgoingPendingChallengeMapProvider);
                        final pending = pendingMap[u.id];
                        return LivePlayerCard(
                          user: u,
                          isChallenging: _challengingUserId == u.id,
                          pendingChallenge: pending,
                          onChallenge: () => _sendDirectChallenge(u),
                          onCancel: pending != null ? () => _cancelPendingChallenge(pending) : null,
                        );
                      },
                      childCount: users.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text('Could not load live players', style: TextStyle(color: Colors.grey[500])),
                    ),
                  ),
                ),
              ),

              // 5. Recently Active Warriors (offline players who played
              //    within the last 7 days — async challenge them!)
              ..._buildRecentlyActiveSection(theme, isDark),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),

          // Searching Radar Dialog
          if (battleState.status == BattleArenaStatus.searching)
            RadarSearchDialog(
              statusMessage: battleState.searchStatusMessage,
              onCancel: () {
                ref.read(battleArenaProvider.notifier).resetLobby();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHeroStatsCard(BuildContext context, ThemeData theme, bool isDark, BattleStats stats) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      stats.division,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: Color(0xFFFBBF24), size: 30),
                      const SizedBox(width: 8),
                      Text(
                        '${stats.trophies}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Trophies',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: const Center(
                  child: Text('⚔️', style: TextStyle(fontSize: 32)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat('Battles', '${stats.totalMatches}'),
              _buildMiniStat('Wins', '${stats.wins}'),
              _buildMiniStat('Win Rate', '${stats.winRate.toStringAsFixed(0)}%'),
              _buildMiniStat('Streak', '🔥 ${stats.winStreak}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildQuickMatchButton(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final error =
                await ref.read(battleArenaProvider.notifier).startQuickMatch();
            if (error != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(error), behavior: SnackBarBehavior.floating),
              );
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
                SizedBox(width: 10),
                Text(
                  'QUICK 1v1 MATCH',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(width: 8),
                Text('⚔️', style: TextStyle(fontSize: 20)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Section: MY FRIENDS — accepted friends with live presence dots,
  /// one-tap challenge (live when online, async when offline), plus a chip
  /// that opens the Friend Requests inbox (with unread count badge).
  List<Widget> _buildFriendsSection(ThemeData theme, bool isDark) {
    final friendsAsync = ref.watch(myFriendsProvider);
    final requestsCount = ref
            .watch(incomingFriendRequestsProvider)
            .asData
            ?.value
            .length ??
        0;
    final onlineUsers = ref.watch(onlineBattleUsersProvider).asData?.value ?? [];
    final onlineById = {for (final u in onlineUsers) u.id: u};
    final friends = friendsAsync.asData?.value ?? [];
    // Hide the whole section when there's nothing to show/manage.
    if (friends.isEmpty && requestsCount == 0) return const [];

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
          child: Row(
            children: [
              const Icon(Icons.groups_rounded, size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Text(
                'MY FRIENDS',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              // Requests inbox chip (with badge)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const FriendRequestsScreen()));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: requestsCount > 0
                          ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                          : const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mail_rounded,
                          size: 12,
                          color: requestsCount > 0
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          requestsCount > 0
                              ? 'Requests ($requestsCount)'
                              : 'Requests',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: requestsCount > 0
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      if (friends.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'No friends yet — tap ➕ on any player card to send a request!',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        )
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final f = friends[index];
              final presence = onlineById[f.id];
              final isOnline = presence != null;
              final pendingMap = ref.watch(outgoingPendingChallengeMapProvider);
              final pending = pendingMap[f.id];
              return FriendListCard(
                friend: f,
                isOnline: isOnline,
                isInBattle: presence?.isInBattle ?? false,
                isChallenging: _challengingUserId == f.id,
                pendingChallenge: pending,
                onChallenge: () => _challengeFriend(f, online: isOnline),
                onCancel: pending != null ? () => _cancelPendingChallenge(pending) : null,
                onRemove: () => _removeFriend(f),
              );
            },
            childCount: friends.length,
          ),
        ),
    ];
  }

  /// Challenge a friend — live duel when they're online, async challenge
  /// (delivered on their next login) when they're offline.
  Future<void> _challengeFriend(Friend friend, {required bool online}) async {
    await _sendChallenge(
      toId: friend.id,
      toName: friend.name,
      toPhoto: friend.photoUrl,
      toTrophies: friend.trophies,
      async: !online,
    );
  }

  Future<void> _cancelPendingChallenge(BattleChallenge challenge) async {
    try {
      await BattleMatchmakingService().deleteChallenge(challenge.id);
      if (challenge.roomId != null) {
        await BattleMatchmakingService().deleteRoom(challenge.roomId!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Challenge cancelled ✕'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not cancel challenge'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _removeFriend(Friend friend) async {
    final currentUser = ref.read(authProvider).asData?.value;
    if (currentUser == null) return;
    try {
      await FriendService().removeFriend(currentUser.id, friend.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${friend.name} removed from your friends.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {}
  }

  /// Section: offline warriors active within the last 7 days. Challenging
  /// one of them sends an async challenge that waits (up to 48h) and is
  /// delivered — popup + push — the next time they open the app.
  List<Widget> _buildRecentlyActiveSection(ThemeData theme, bool isDark) {
    final recentUsersAsync = ref.watch(recentlyActiveBattleUsersProvider);
    return recentUsersAsync.maybeWhen<List<Widget>>(
      data: (users) {
        if (users.isEmpty) return const [];
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 4),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 14, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 6),
                  Text(
                    'RECENTLY ACTIVE',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${users.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Offline warriors from the last 7 days — challenge them and they\'ll get it when they\'re back online 🔔',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final u = users[index];
                final pendingMap = ref.watch(outgoingPendingChallengeMapProvider);
                final pending = pendingMap[u.id];
                return RecentPlayerCard(
                  user: u,
                  isChallenging: _challengingUserId == u.id,
                  pendingChallenge: pending,
                  onChallenge: () => _sendDirectChallenge(u, async: true),
                  onCancel: pending != null ? () => _cancelPendingChallenge(pending) : null,
                );
              },
              childCount: users.length,
            ),
          ),
        ];
      },
      orElse: () => const [],
    );
  }

  /// Sends a 1v1 challenge to [targetUser]. With [async] true the target is
  /// offline: the challenge stays pending up to 48h and is delivered when
  /// they return online (popup via GlobalBattleChallengeGate + OneSignal push).
  Future<void> _sendDirectChallenge(BattlePresenceUser targetUser,
      {bool async = false}) async {
    await _sendChallenge(
      toId: targetUser.id,
      toName: targetUser.name,
      toPhoto: targetUser.photoUrl,
      toTrophies: targetUser.trophies,
      async: async,
    );
  }

  /// ROOM-FIRST challenge send: creates the waiting room FIRST, then the
  /// challenge doc (carrying the roomId). For a live target the sender is
  /// dropped into the waiting room immediately; for an offline (async)
  /// target they stay in the lobby and get pulled in when it's accepted.
  /// ── SPAM-PROTECTION GUARD ──────────────────────────────────
  /// Returns true if a pending outgoing challenge to [toId] already exists.
  bool _hasPendingTo(String toId) {
    return ref.read(outgoingPendingIdsProvider).contains(toId);
  }

  Future<void> _sendChallenge({
    required String toId,
    required String toName,
    required String toPhoto,
    required int toTrophies,
    required bool async,
    bool isRematch = false,
  }) async {
    final currentUser = ref.read(authProvider).asData?.value;
    if (currentUser == null) return;

    // ── 0) CONCURRENCY + DUPLICATE GUARD ─────────────────────
    // Prevent double-tap spam and multiple parallel challenge flows.
    if (_challengingUserId != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait — sending previous challenge… ⏳'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (_hasPendingTo(toId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Already challenged $toName — waiting for reply ⏳'),
            backgroundColor: const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _challengingUserId = toId);
    final stats = ref.read(battleArenaProvider).stats;

    try {
      final matchmaking = BattleMatchmakingService();
      // 1) Prepare the room (seed questions + answer key) before inviting.
      final room = await matchmaking.createWaitingRoom(
        player1: BattlePlayer(
          id: currentUser.id,
          name: currentUser.name,
          photoUrl: currentUser.photoUrl,
          trophies: stats.trophies,
        ),
        player2: BattlePlayer(
          id: toId,
          name: toName,
          photoUrl: toPhoto,
          trophies: toTrophies,
        ),
      );

      // 2) Send the challenge referencing that room. If it's rejected
      //    (blocked by spam protection), remove the room we just made so
      //    nothing is left behind. Also clean any superseded old room.
      try {
        await ref.read(battlePresenceServiceProvider).sendChallenge(
              fromUserId: currentUser.id,
              fromUserName: currentUser.name,
              fromUserPhoto: currentUser.photoUrl,
              fromUserTrophies: stats.trophies,
              toUserId: toId,
              type: async ? 'async' : 'live',
              isRematch: isRematch,
              roomId: room.id,
              onSupersededRoom: (oldRoomId) {
                if (oldRoomId != null && oldRoomId != room.id) {
                  // Fire-and-forget delete of orphaned previous room.
                  matchmaking.deleteRoom(oldRoomId);
                }
              },
            );
      } catch (e) {
        await matchmaking.deleteRoom(room.id);
        rethrow;
      }

      if (!mounted) return;
      if (async) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Challenge sent! $toName will get it when they come online 🔔'),
            backgroundColor: const Color(0xFF8B5CF6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _openWaitingRoom(room, challengeId: 'ch_${currentUser.id}_$toId');
      }
    } on ChallengeBlockedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.code == 'permission-denied'
              ? 'Could not send the challenge (permission error). Please update the app and try again.'
              : 'Failed to send challenge.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send challenge.')),
      );
    } finally {
      if (mounted) {
        setState(() => _challengingUserId = null);
      }
    }
  }

  void _openWaitingRoom(BattleRoom room, {required String challengeId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BattleWaitingRoomScreen(
          roomId: room.id,
          challengeId: challengeId,
          isHost: true,
        ),
      ),
    );
  }

  /// Banner for pending incoming challenges (e.g. ones postponed via
  /// "Later") — tapping Respond reopens the accept/decline sheet.
  Widget _buildPendingChallengeBanner() {
    return ref.watch(incomingChallengesProvider).when(
          data: (challenges) {
            if (challenges.isEmpty) return const SizedBox.shrink();
            final c = challenges.first;
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFFEF4444)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Text('⚔️', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${c.fromUserName} challenged you!',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => ref
                        .read(reshowChallengeProvider.notifier)
                        .state = c,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text('Respond',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
  }
}
