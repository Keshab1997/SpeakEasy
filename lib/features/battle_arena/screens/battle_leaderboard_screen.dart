import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/auth_provider.dart';
import '../models/battle_models.dart';
import '../providers/battle_arena_provider.dart';
import '../services/battle_history_service.dart';
import '../services/battle_leaderboard_service.dart';

/// Battle stats hub with three tabs: Leaderboard, My Matches, Badges.
class BattleLeaderboardScreen extends ConsumerStatefulWidget {
  const BattleLeaderboardScreen({super.key});

  @override
  ConsumerState<BattleLeaderboardScreen> createState() =>
      _BattleLeaderboardScreenState();
}

class _BattleLeaderboardScreenState
    extends ConsumerState<BattleLeaderboardScreen> {
  final _service = BattleLeaderboardService();
  final _historyService = BattleHistoryService();

  List<LeaderboardEntry> _entries = [];
  LeaderboardEntry? _myRank;
  List<BattleHistoryRecord> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final me = ref.read(authProvider).asData?.value;
    final results = await Future.wait([
      _service.getTopPlayers(forceRefresh: true),
      _historyService.getRecords(),
      if (me != null) _service.getMyRank(me.id) else Future.value(null),
    ]);
    if (!mounted) return;
    setState(() {
      _entries = results[0] as List<LeaderboardEntry>;
      _history = results[1] as List<BattleHistoryRecord>;
      _myRank = results.length > 2 ? results[2] as LeaderboardEntry? : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = ref.watch(battleArenaProvider).stats;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('🏆 Battle Stats'),
          bottom: const TabBar(
            labelColor: Color(0xFFF59E0B),
            indicatorColor: Color(0xFFF59E0B),
            tabs: [
              Tab(icon: Icon(Icons.leaderboard_rounded), text: 'Leaders'),
              Tab(icon: Icon(Icons.history_rounded), text: 'Matches'),
              Tab(icon: Icon(Icons.military_tech_rounded), text: 'Badges'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: TabBarView(
                  children: [
                    _buildLeaderboardTab(isDark, stats),
                    _buildHistoryTab(isDark),
                    _buildBadgesTab(isDark, stats),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Leaderboard ──────────────────────────────────────────────────────
  Widget _buildLeaderboardTab(bool isDark, BattleStats stats) {
    if (_entries.isEmpty) {
      return _emptyState(
        isDark,
        icon: Icons.emoji_events_outlined,
        title: 'No ranked players yet',
        subtitle: 'Play an ONLINE 1v1 battle to appear on the leaderboard! ⚔️',
      );
    }

    final podium = _entries.take(3).toList();
    final rest = _entries.length > 3 ? _entries.sublist(3) : <LeaderboardEntry>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_myRank != null) _myRankCard(isDark, _myRank!),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (podium.length > 1) _podium(podium[1], 2, isDark, height: 78),
            if (podium.isNotEmpty) _podium(podium[0], 1, isDark, height: 100),
            if (podium.length > 2) _podium(podium[2], 3, isDark, height: 60),
          ],
        ),
        const SizedBox(height: 20),
        ...rest.map((e) => _rankTile(e, isDark)),
      ],
    );
  }

  Widget _myRankCard(bool isDark, LeaderboardEntry me) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF4338CA)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage:
                me.photoUrl.isNotEmpty ? NetworkImage(me.photoUrl) : null,
            child: me.photoUrl.isEmpty
                ? Text(me.name.isNotEmpty ? me.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('YOUR RANK',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold)),
                Text(me.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text('${me.wins}W · ${me.losses}L · ${me.winRate.toStringAsFixed(0)}% win',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Column(
            children: [
              Text('#${me.rank}',
                  style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 26,
                      fontWeight: FontWeight.w900)),
              Text('${me.trophies} 🏆',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _podium(LeaderboardEntry e, int place, bool isDark,
      {required double height}) {
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: place == 1 ? 30 : 24,
          backgroundImage:
              e.photoUrl.isNotEmpty ? NetworkImage(e.photoUrl) : null,
          backgroundColor: const Color(0xFF334155),
          child: e.photoUrl.isEmpty
              ? Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white))
              : null,
        ),
        const SizedBox(height: 6),
        Text(medals[place]!, style: TextStyle(fontSize: place == 1 ? 26 : 20)),
        const SizedBox(height: 4),
        Text(e.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: place == 1 ? 14 : 12,
                color: isDark ? Colors.white : const Color(0xFF1E293B))),
        Text('${e.trophies} 🏆',
            style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11)),
        Container(
          width: 60,
          height: height,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: place == 1
                  ? [const Color(0xFFF59E0B), const Color(0xFFB45309)]
                  : place == 2
                      ? [const Color(0xFF94A3B8), const Color(0xFF475569)]
                      : [const Color(0xFFB45309), const Color(0xFF78350F)],
            ),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 6),
          child: Text('$place',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Widget _rankTile(LeaderboardEntry e, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text('#${e.rank}',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.grey[500],
                    fontSize: 15)),
          ),
          CircleAvatar(
            radius: 18,
            backgroundImage:
                e.photoUrl.isNotEmpty ? NetworkImage(e.photoUrl) : null,
            backgroundColor: const Color(0xFF334155),
            child: e.photoUrl.isEmpty
                ? Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 12))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${e.wins}W · ${e.losses}L',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          Text('${e.trophies} 🏆',
              style: const TextStyle(
                  fontWeight: FontWeight.w900, color: Color(0xFFF59E0B))),
        ],
      ),
    );
  }

  // ── Match history ───────────────────────────────────────────────────
  Widget _buildHistoryTab(bool isDark) {
    if (_history.isEmpty) {
      return _emptyState(
        isDark,
        icon: Icons.sports_kabaddi_rounded,
        title: 'No battles yet',
        subtitle: 'Your finished matches will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, i) {
        final r = _history[i];
        final color = r.result == 'win'
            ? const Color(0xFF10B981)
            : r.result == 'draw'
                ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444);
        final emoji = r.result == 'win'
            ? '🏆'
            : r.result == 'draw'
                ? '🤝'
                : '💔';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'vs ${r.opponentName}${r.isBot ? ' 🤖' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${r.myScore} – ${r.opponentScore} pts',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    Text(
                      _dateLabel(r.playedAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Text(
                r.trophyDelta >= 0 ? '+${r.trophyDelta}' : '${r.trophyDelta}',
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: color, fontSize: 16),
              ),
            ],
          ),
        );
      },
    );
  }

  String _dateLabel(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  // ── Badges ──────────────────────────────────────────────────────────
  Widget _buildBadgesTab(bool isDark, BattleStats stats) {
    final earned = BattleHistoryService.earnedBadges(
      totalMatches: stats.totalMatches,
      wins: stats.wins,
      winStreak: stats.winStreak,
      bestStreak: stats.winStreak, // local Hive tracks current; best approx.
      recent: _history,
    ).toSet();

    final all = BattleHistoryService.badgeCatalog.entries.toList();
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: all.length,
      itemBuilder: (context, i) {
        final id = all[i].key;
        final b = all[i].value;
        final has = earned.contains(id);
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: has
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                opacity: has ? 1 : 0.25,
                child: Text(b['emoji']!,
                    style: TextStyle(fontSize: has ? 34 : 30)),
              ),
              const SizedBox(height: 6),
              Text(b['title']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: has
                          ? (isDark ? Colors.white : const Color(0xFF1E293B))
                          : Colors.grey[500])),
              const SizedBox(height: 2),
              Text(b['desc']!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: Colors.grey[500])),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState(bool isDark,
      {required IconData icon, required String title, required String subtitle}) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 56, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Center(
          child: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF1E293B))),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ),
      ],
    );
  }
}
