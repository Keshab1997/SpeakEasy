import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../models/battle_models.dart';
import '../providers/battle_arena_provider.dart';
import '../providers/battle_presence_provider.dart';
import '../widgets/live_player_card.dart';
import '../widgets/radar_search_dialog.dart';
import 'battle_arena_screen.dart';

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final battleState = ref.watch(battleArenaProvider);
    final onlineUsersAsync = ref.watch(onlineBattleUsersProvider);
    final incomingChallengesAsync = ref.watch(incomingChallengesProvider);

    // Listen to status change to open arena screen
    ref.listen<BattleArenaState>(battleArenaProvider, (previous, next) {
      if (previous?.status != BattleArenaStatus.inDuel && next.status == BattleArenaStatus.inDuel) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BattleArenaScreen()),
        );
      }
    });

    // Listen to incoming challenges
    incomingChallengesAsync.whenData((challenges) {
      if (challenges.isNotEmpty && mounted && battleState.status == BattleArenaStatus.idle) {
        final challenge = challenges.first;
        _showIncomingChallengeModal(context, challenge);
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
      ),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Top Hero Card: Stats & Division
              SliverToBoxAdapter(
                child: _buildHeroStatsCard(context, theme, isDark, battleState.stats),
              ),

              // 2. Big Quick Match Button
              SliverToBoxAdapter(
                child: _buildQuickMatchButton(context, isDark),
              ),

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
                            color: const Color(0xFF10B981).withOpacity(0.15),
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
                        return LivePlayerCard(
                          user: u,
                          isChallenging: _challengingUserId == u.id,
                          onChallenge: () => _sendDirectChallenge(u),
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
            color: const Color(0xFF4338CA).withOpacity(0.3),
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
                      color: Colors.white.withOpacity(0.15),
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
                  color: Colors.white.withOpacity(0.1),
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
          onTap: () {
            ref.read(battleArenaProvider.notifier).startQuickMatch();
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
                  color: const Color(0xFFEF4444).withOpacity(0.4),
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

  Future<void> _sendDirectChallenge(BattlePresenceUser targetUser) async {
    final currentUser = ref.read(authProvider).asData?.value;
    if (currentUser == null) return;

    setState(() => _challengingUserId = targetUser.id);
    final stats = ref.read(battleArenaProvider).stats;

    try {
      await ref.read(battlePresenceServiceProvider).sendChallenge(
            fromUserId: currentUser.id,
            fromUserName: currentUser.name,
            fromUserPhoto: currentUser.photoUrl,
            fromUserTrophies: stats.trophies,
            toUserId: targetUser.id,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Challenge sent to ${targetUser.name}! ⚔️'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send challenge.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _challengingUserId = null);
      }
    }
  }

  void _showIncomingChallengeModal(BuildContext context, BattleChallenge challenge) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚔️ 1v1 CHALLENGE RECEIVED!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 30,
                backgroundImage: challenge.fromUserPhoto.isNotEmpty ? NetworkImage(challenge.fromUserPhoto) : null,
                child: challenge.fromUserPhoto.isEmpty ? Text(challenge.fromUserName[0].toUpperCase()) : null,
              ),
              const SizedBox(height: 10),
              Text(
                '${challenge.fromUserName} wants to duel with you!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text('${challenge.fromUserTrophies} Trophies 🏆', style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref.read(battlePresenceServiceProvider).respondToChallenge(challenge.id, false);
                        Navigator.pop(ctx);
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

                        final room = await BattleMatchmakingService().createDirectChallengeRoom(
                          player1: player1,
                          player2: player2,
                        );

                        await ref.read(battlePresenceServiceProvider).respondToChallenge(
                              challenge.id,
                              true,
                              roomId: room.id,
                            );

                        if (mounted) {
                          Navigator.pop(ctx);
                          ref.read(battleArenaProvider.notifier).startFromRoom(room);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Accept Duel ⚔️', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
