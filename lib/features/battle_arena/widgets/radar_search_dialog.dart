import 'dart:math';
import 'package:flutter/material.dart';

class RadarSearchDialog extends StatefulWidget {
  final String statusMessage;
  final VoidCallback onCancel;

  const RadarSearchDialog({
    super.key,
    required this.statusMessage,
    required this.onCancel,
  });

  @override
  State<RadarSearchDialog> createState() => _RadarSearchDialogState();
}

class _RadarSearchDialogState extends State<RadarSearchDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'MATCHMAKING ⚔️',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 24),

            // Animated Radar Scanner
            SizedBox(
              height: 140,
              width: 140,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _RadarPainter(
                      animationValue: _controller.value,
                      primaryColor: const Color(0xFF3B82F6),
                    ),
                    child: Center(
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF3B82F6), width: 2),
                        ),
                        child: const Icon(
                          Icons.radar_rounded,
                          color: Color(0xFF3B82F6),
                          size: 28,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Status message
            Text(
              widget.statusMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Auto-connecting with AI Bot in 6s if no live player is found',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),

            // Cancel Button
            OutlinedButton(
              onPressed: widget.onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: const Text('Cancel Search'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double animationValue;
  final Color primaryColor;

  _RadarPainter({required this.animationValue, required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw static concentric circles
    final circlePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, maxRadius * 0.4, circlePaint);
    canvas.drawCircle(center, maxRadius * 0.7, circlePaint);
    canvas.drawCircle(center, maxRadius, circlePaint);

    // Draw pulsating ripple waves
    for (int i = 0; i < 2; i++) {
      final waveValue = (animationValue + (i * 0.5)) % 1.0;
      final waveRadius = waveValue * maxRadius;
      final wavePaint = Paint()
        ..color = primaryColor.withValues(alpha: (1.0 - waveValue) * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, waveRadius, wavePaint);
    }

    // Draw sweeping radar angle
    final sweepAngle = animationValue * 2 * pi;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: 2 * pi,
        colors: [
          Colors.transparent,
          primaryColor.withValues(alpha: 0.0),
          primaryColor.withValues(alpha: 0.35),
        ],
        stops: const [0.0, 0.75, 1.0],
        transform: GradientRotation(sweepAngle),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
