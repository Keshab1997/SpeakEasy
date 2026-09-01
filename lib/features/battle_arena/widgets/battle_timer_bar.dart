import 'package:flutter/material.dart';

class BattleTimerBar extends StatelessWidget {
  final int remainingSeconds;
  final int totalSeconds;

  const BattleTimerBar({
    super.key,
    required this.remainingSeconds,
    this.totalSeconds = 15,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = (remainingSeconds / totalSeconds).clamp(0.0, 1.0);

    Color barColor;
    if (progress > 0.5) {
      barColor = const Color(0xFF10B981); // Emerald Green
    } else if (progress > 0.25) {
      barColor = const Color(0xFFF59E0B); // Amber
    } else {
      barColor = const Color(0xFFEF4444); // Urgent Red
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.bolt_rounded, size: 16, color: barColor),
                const SizedBox(width: 4),
                Text(
                  'Round Timer',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: barColor,
                  ),
                ),
              ],
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: barColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: barColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${remainingSeconds}s',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: barColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Smoothly drains once per second
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 950),
                      curve: Curves.linear,
                      width: constraints.maxWidth * progress,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            barColor.withValues(alpha: 0.65),
                            barColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: barColor.withValues(alpha: 0.55),
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
