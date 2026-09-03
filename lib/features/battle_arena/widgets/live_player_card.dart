import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/battle_models.dart';
import '../services/battle_leaderboard_service.dart';

class LivePlayerCard extends StatelessWidget {
  final BattlePresenceUser user;
  final bool isChallenging;
  final VoidCallback onChallenge;

  const LivePlayerCard({
    super.key,
    required this.user,
    this.isChallenging = false,
    required this.onChallenge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      // Tap the card (not the Duel button) to see the player's profile/stats.
      onTap: () => _showProfile(context, user, isDark),
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
          // Avatar with green pulsing dot
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                child: user.photoUrl.isEmpty
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'P',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
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
                    color: user.isInBattle
                        ? const Color(0xFFF59E0B) // Amber = in a duel
                        : const Color(0xFF10B981), // Green = online
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (user.isInBattle
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981))
                            .withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Name and Trophies
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${user.trophies} 🏆',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFF59E0B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: (user.isInBattle
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981))
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        user.isInBattle ? '⚔️ IN BATTLE' : 'ONLINE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: user.isInBattle
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Challenge button (disabled while the player is in a duel)
          ElevatedButton.icon(
            onPressed: (isChallenging || user.isInBattle) ? null : onChallenge,
            icon: const Icon(Icons.sports_kabaddi_rounded, size: 16),
            label: Text(user.isInBattle
                ? 'Busy'
                : (isChallenging ? 'Sent...' : 'Duel ⚔️')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              elevation: 2,
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _showProfile(BuildContext context, BattlePresenceUser user, bool isDark) {
    String division(int t) {
      if (t >= 1500) return '💎 Grandmaster';
      if (t >= 800) return '🥇 Master';
      if (t >= 300) return '🥈 Challenger';
      return '🥉 Novice';
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return FutureBuilder<BattlePresenceUser?>(
          future: BattleLeaderboardService().getPlayerProfile(user.id),
          builder: (context, snap) {
            // Use enriched data when available; fall back to the streamed
            // presence user so the sheet never appears empty.
            final u = (snap.hasData && snap.data != null) ? snap.data! : user;
            final isLoading = snap.connectionState == ConnectionState.waiting;
            final played = u.totalMatches;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        height: 2,
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    backgroundImage:
                        u.photoUrl.isNotEmpty ? NetworkImage(u.photoUrl) : null,
                    child: u.photoUrl.isEmpty
                        ? Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(u.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(division(u.trophies),
                      style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _stat('🏆 Trophies', '${u.trophies}'),
                      _stat('⚔️ Battles', '$played'),
                      _stat('🔥 Streak', '${u.winStreak}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _stat('✅ Wins', '${u.wins}', color: const Color(0xFF10B981)),
                      _stat('❌ Losses', '${u.losses}', color: const Color(0xFFEF4444)),
                      _stat('📈 Win Rate',
                          played == 0 ? '—' : '${u.winRate.toStringAsFixed(0)}%'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (played == 0)
                    Text(
                      isLoading ? 'Loading stats...' : 'No ranked online battles yet',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    )
                  else if (u.totalMatches > 0)
                    Text(
                      '${u.draws} Draws • Best Streak ${u.winStreak} 🔥',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _stat(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
