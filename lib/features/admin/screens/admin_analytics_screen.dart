import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/analytics_service.dart';
import 'package:intl/intl.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  AppAnalytics? _analytics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AnalyticsService.getAnalytics();
      if (mounted) {
        setState(() {
          _analytics = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              await AnalyticsService.refresh();
              _loadData();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(isDark, theme),
    );
  }

  Widget _buildBody(bool isDark, ThemeData theme) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: _skel(isDark, 80)),
            const SizedBox(width: 10),
            Expanded(child: _skel(isDark, 80)),
            const SizedBox(width: 10),
            Expanded(child: _skel(isDark, 80)),
            const SizedBox(width: 10),
            Expanded(child: _skel(isDark, 80)),
          ]),
          const SizedBox(height: 20),
          _skel(isDark, 200),
          const SizedBox(height: 20),
          _skel(isDark, 180),
          const SizedBox(height: 20),
          _skel(isDark, 160),
        ],
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('Failed to load analytics',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final analytics = _analytics!;
    final screenWidth = MediaQuery.of(context).size.width;

    return RefreshIndicator(
      onRefresh: () async {
        await AnalyticsService.refresh();
        await _loadData();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards Row
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final cards = [
                    _StatCardData(
                      label: 'Today Active',
                      value: '${analytics.todayActiveUsers}',
                      icon: Icons.person_outline_rounded,
                      gradient: AppColors.primaryGradient,
                    ),
                    _StatCardData(
                      label: 'New This Week',
                      value: '${analytics.newUsersThisWeek}',
                      icon: Icons.person_add_alt_rounded,
                      gradient: AppColors.secondaryGradient,
                    ),
                    _StatCardData(
                      label: 'Lessons Today',
                      value: '${analytics.todayLessonsCompleted}',
                      icon: Icons.check_circle_outline_rounded,
                      gradient: AppColors.accentGradient,
                    ),
                    _StatCardData(
                      label: 'Total Users',
                      value: '${analytics.totalUsers}',
                      icon: Icons.groups_rounded,
                      gradient: AppColors.purpleGradient,
                    ),
                  ];
                  final card = cards[i];
                  return Container(
                    width: screenWidth * 0.4,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: card.gradient),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: card.gradient.first.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(card.icon, color: Colors.white.withOpacity(0.9),
                            size: 22),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(card.value,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                )),
                            Text(card.label,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Line Chart: Daily Signups (7 days)
            _buildSectionTitle('User Growth (Last 7 Days)', Icons.trending_up_rounded),
            const SizedBox(height: 8),
            _buildDailySignupsChart(analytics.dailySignups, isDark, theme),
            const SizedBox(height: 24),

            // Row: Pie Chart + Bar Chart side by side on wide screens
            _buildSectionTitle('Module Usage & Streak Distribution',
                Icons.analytics_rounded),
            const SizedBox(height: 8),
            SizedBox(
              height: 320,
              child: Row(
                children: [
                  // Pie chart (module stats)
                  Expanded(
                    child: _buildPieChart(analytics.moduleStats, isDark, theme),
                  ),
                  const SizedBox(width: 12),
                  // Bar chart (streak distribution)
                  Expanded(
                    child: _buildStreakChart(
                        analytics.streakDistribution, isDark, theme),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Last refreshed timestamp
            Center(
              child: Text(
                'Auto-refreshes every 60 seconds',
                style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16)),
      ],
    );
  }

  // ──────────────────────────────────────────────
  //  LINE CHART – Daily Signups
  // ──────────────────────────────────────────────
  Widget _buildDailySignupsChart(
      List<AnalyticsDataPoint> data, bool isDark, ThemeData theme) {
    if (data.isEmpty) {
      return _buildEmptyChart(isDark, 'No signup data yet');
    }

    final maxY = data
        .map((d) => d.count.toDouble())
        .reduce((a, b) => a > b ? a : b);
    final ceiling = maxY < 5 ? 5.0 : (maxY * 1.3).ceilToDouble();

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: ceiling / 4,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: (isDark ? Colors.grey[700] : Colors.grey[200])!,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min) return const SizedBox.shrink();
                  return Text(
                    '${value.toInt()}',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) {
                    return const SizedBox.shrink();
                  }
                  final formatter = DateFormat('E');
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      formatter.format(data[idx].date).substring(0, 3),
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: 0,
          maxY: ceiling,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                data.length,
                (i) => FlSpot(i.toDouble(), data[i].count.toDouble()),
              ),
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.primary,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withOpacity(0.3),
                    AppColors.primary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  PIE CHART – Module Stats
  // ──────────────────────────────────────────────
  Widget _buildPieChart(
      List<ModuleStat> data, bool isDark, ThemeData theme) {
    if (data.isEmpty || data.every((d) => d.completedCount == 0)) {
      return _buildEmptyChart(isDark, 'No module data');
    }

    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      AppColors.purpleGradient[0],
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        children: [
          const Text('Modules',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: List.generate(
                  data.length,
                  (i) {
                    final isNotEmpty = data[i].completedCount > 0;
                    return PieChartSectionData(
                      color: colors[i % colors.length],
                      value: isNotEmpty
                          ? data[i].completedCount.toDouble()
                          : 1,
                      title: isNotEmpty ? '${data[i].completedCount}' : '',
                      radius: 40,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Legend
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: List.generate(data.length, (i) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('${data[i].icon} ${data[i].name}',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  BAR CHART – Streak Distribution
  // ──────────────────────────────────────────────
  Widget _buildStreakChart(
      StreakDistribution data, bool isDark, ThemeData theme) {
    final barData = [
      _BarData('🔥 Active\n≥3 days', data.activeUsers, AppColors.success),
      _BarData('⚠️ At Risk\n1-2 days', data.atRiskUsers, AppColors.warning),
      _BarData('💤 Inactive\n0 days', data.inactiveUsers, AppColors.error),
    ];

    final maxY = barData
        .map((d) => d.value.toDouble())
        .reduce((a, b) => a > b ? a : b);
    final ceiling = maxY < 5 ? 5.0 : (maxY * 1.4).ceilToDouble();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        children: [
          const Text('Streak Distribution',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: ceiling,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ceiling / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: (isDark ? Colors.grey[700] : Colors.grey[200])!,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.min) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= barData.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          barData[idx].label.split('\n')[0],
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(barData.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: barData[i].value.toDouble(),
                        color: barData[i].color,
                        width: 28,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          // Legend
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: barData.map((d) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: d.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 3),
                  Text('${d.value}',
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart(bool isDark, String message) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Center(
        child: Text(message,
            style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _skel(bool isDark, double height) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  Helper data classes
// ──────────────────────────────────────────────
class _StatCardData {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  _StatCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });
}

class _BarData {
  final String label;
  final int value;
  final Color color;

  _BarData(this.label, this.value, this.color);
}