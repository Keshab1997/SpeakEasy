import 'package:flutter/material.dart';
import '../../services/hive_service.dart';
import '../../services/remote_config_service.dart';

class StreakWidget extends StatefulWidget {
  final int currentStreak;
  final int weeklyStreak;
  final String weeklyMilestone;
  final String weeklyMilestoneLabel;
  final int thisWeekActiveDays;
  final int todayXP;
  final int dailyXPTarget;
  final bool hasPracticeToday;
  final bool isStreakFrozen;
  final int streakFreezeCount;
  final VoidCallback? onTap;
  final VoidCallback? onBuyFreeze;
  final VoidCallback? onShare;

  const StreakWidget({
    super.key,
    required this.currentStreak,
    this.weeklyStreak = 0,
    this.weeklyMilestone = '🌱',
    this.weeklyMilestoneLabel = 'Started',
    this.thisWeekActiveDays = 0,
    this.todayXP = 0,
    this.dailyXPTarget = 50,
    this.hasPracticeToday = false,
    this.isStreakFrozen = false,
    this.streakFreezeCount = 0,
    this.onTap,
    this.onBuyFreeze,
    this.onShare,
  });

  @override
  State<StreakWidget> createState() => _StreakWidgetState();
}

class _StreakWidgetState extends State<StreakWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _freezeCost = 100; // default, updated from remote config

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start pulse only if streak > 0
    if (widget.currentStreak > 0) {
      _pulseController.forward();
    }

    _loadFreezeCost();
  }

  Future<void> _loadFreezeCost() async {
    final cost = await RemoteConfigService.getStreakFreezeCost();
    if (mounted) setState(() => _freezeCost = cost);
  }

  @override
  void didUpdateWidget(StreakWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentStreak > 0 && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (widget.currentStreak == 0 && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.currentStreak > 0
              ? isDark
                  ? [
                      const Color(0xFFFF6B35),
                      const Color(0xFFF7931E),
                      const Color(0xFFE85D04),
                    ]
                  : [
                      const Color(0xFFFF6F00),
                      const Color(0xFFFF8F00),
                      const Color(0xFFFF5722),
                    ]
              : isDark
                  ? [
                      const Color(0xFF4A4A4A),
                      const Color(0xFF2D2D2D),
                    ]
                  : [
                      const Color(0xFFBDBDBD),
                      const Color(0xFF9E9E9E),
                    ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: widget.currentStreak > 0
                ? (isDark ? const Color(0xFFFF6B35).withOpacity(0.4) : Colors.orange.withOpacity(0.3))
                : (isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.2)),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ═══ TOP ROW: Streak Counter + Weekly Streak + Freeze Shield ═══
                // FittedBox scales everything down if screen is too narrow
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🔥 Flame Streak Number (daily streak)
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: widget.currentStreak > 0
                                ? _pulseAnimation.value
                                : 1.0,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '🔥',
                                  style: TextStyle(fontSize: 36),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${widget.currentStreak}',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    widget.currentStreak == 1 ? 'day' : 'days',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      // 📅 Weekly Streak Count + Freeze Shield
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Weekly Streak Badge
                          if (widget.weeklyStreak > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_view_week_rounded,
                                    color: Colors.amberAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.weeklyStreak}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'wk',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.weeklyMilestone,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(width: 8),
                          // 🛡️ Streak Freeze Shield
                          if (widget.streakFreezeCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.shield_rounded,
                                    color: Colors.cyanAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '×${widget.streakFreezeCount}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ═══ SUBTITLE ═══
                const SizedBox(height: 2),
                // Use Wrap so badge never overflows
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (widget.hasPracticeToday)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Colors.greenAccent, size: 14),
                          SizedBox(width: 4),
                          Text(
                            "Today's practice done!",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        "Complete a lesson to keep your streak!",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (widget.isStreakFrozen && !widget.hasPracticeToday)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.shade300.withOpacity(0.4),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_rounded,
                                color: Colors.amberAccent, size: 12),
                            SizedBox(width: 3),
                            Text(
                              'Freeze active',
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // ═══ WEEKLY ACTIVITY CALENDAR (7-day grid like Duolingo) ═══
                _buildWeeklyCalendar(),

                const SizedBox(height: 12),

                // ═══ DAILY XP BAR ═══
                _buildDailyXPBar(),

                // ═══ ACTION BUTTONS ═══
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Buy Streak Freeze
                    if (widget.streakFreezeCount < 2)
                      _buildActionChip(
                        icon: Icons.shield_rounded,
                        label: 'Buy Freeze',
                        subtitle: '$_freezeCost',
                        color: Colors.cyanAccent,
                        onTap: widget.onBuyFreeze,
                      ),
                    const SizedBox(width: 8),
                    // Share streak
                    _buildActionChip(
                      icon: Icons.share_rounded,
                      label: 'Share',
                      subtitle: '${widget.currentStreak}d',
                      color: Colors.amberAccent,
                      onTap: widget.onShare,
                    ),
                    if (widget.currentStreak > 0) ...[
                      const Spacer(),
                      // Milestone indicator
                      _buildMilestoneBadge(),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 7-day calendar grid (Duolingo-style)
  /// 7-day attendance calendar with day names & check/cross marks
  Widget _buildWeeklyCalendar() {
    final activity = HiveService.getWeekActivityList();
    final now = DateTime.now();
    // Short day names (Monday-first to match DateTime.weekday)
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 12, color: Colors.white.withOpacity(0.6)),
              const SizedBox(width: 4),
              Text(
                'This Week',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const Spacer(),
              Text(
                '${activity.where((a) => a).length}/7 days',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Day name row — each day takes equal width
          Row(
            children: List.generate(7, (i) {
              final isToday = now.weekday - 1 == i;
              return Expanded(
                child: Center(
                  child: Text(
                    dayLabels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          // Attendance row (✅ present / ❌ absent) — each day takes equal width
          Row(
            children: List.generate(7, (i) {
              final isActive = activity[i];
              final isToday = now.weekday - 1 == i;
              return Expanded(
                child: Center(
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? Colors.green.withOpacity(0.7)
                          : (isToday
                              ? Colors.white.withOpacity(0.1)
                              : Colors.transparent),
                      border: isToday && !isActive
                          ? Border.all(
                              color: Colors.white.withOpacity(0.3), width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: isActive
                          ? const Text('✅', style: TextStyle(fontSize: 14))
                          : (isToday
                              ? const Text('🔵', style: TextStyle(fontSize: 10))
                              : Text(dayLabels[i].substring(0, 1),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.2),
                                  ))),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
  Widget _buildDailyXPBar() {
    final progress = (widget.todayXP / widget.dailyXPTarget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.star_rounded, color: Colors.amberAccent, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Daily Goal',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${widget.todayXP} / ${widget.dailyXPTarget} XP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0
                          ? Colors.greenAccent
                          : Colors.amberAccent,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneBadge() {
    final streak = widget.currentStreak;
    String emoji;
    if (streak >= 100) {
      emoji = '👑';
    } else if (streak >= 30) {
      emoji = '🏆';
    } else if (streak >= 14) {
      emoji = '💪';
    } else if (streak >= 7) {
      emoji = '⭐';
    } else if (streak >= 3) {
      emoji = '🔥';
    } else {
      emoji = '🌱';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 18),
      ),
    );
  }
}