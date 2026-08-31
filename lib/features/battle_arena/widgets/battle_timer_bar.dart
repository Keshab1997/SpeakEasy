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
                Icon(Icons.timer_outlined, size: 16, color: barColor),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: barColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
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
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            tween: Tween<double>(begin: progress, end: progress),
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              );
            },
          ),
        ),
      ],
    );
  }
}
