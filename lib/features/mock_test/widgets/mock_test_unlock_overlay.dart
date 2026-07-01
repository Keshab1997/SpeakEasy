import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Full-screen celebration overlay shown when a student scores a perfect score
/// (score == total) on a mock test and unlocks the next test.
///
/// Displays a gold-themed animated card over a semi-transparent backdrop
/// with confetti particles. The card scales and fades in with a spring
/// animation, and the trophy icon bounces separately.
class MockTestUnlockOverlay extends StatefulWidget {
  final int completedTestNumber;
  final String completedTestTitle;
  final int score;
  final int total;
  final int nextTestNumber;
  final int totalCompleted;
  final int totalTests;
  final int xpReward;
  final int coinReward;
  final VoidCallback onTakeNextTest;
  final VoidCallback onDismiss;

  const MockTestUnlockOverlay({
    super.key,
    required this.completedTestNumber,
    required this.completedTestTitle,
    required this.score,
    required this.total,
    required this.nextTestNumber,
    required this.totalCompleted,
    required this.totalTests,
    this.xpReward = 50,
    this.coinReward = 25,
    required this.onTakeNextTest,
    required this.onDismiss,
  });

  @override
  State<MockTestUnlockOverlay> createState() => _MockTestUnlockOverlayState();
}

class _MockTestUnlockOverlayState extends State<MockTestUnlockOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;

  late final AnimationController _contentController;
  late final Animation<double> _contentFade;

  late final ConfettiController _confettiController;

  bool _isLastTest = false;

  @override
  void initState() {
    super.initState();

    _isLastTest = widget.nextTestNumber > widget.totalTests;

    // Entry animation: scale 0 → 1.05 → 1.0 with spring feel
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeIn),
    );

    // Trophy bounce animation (starts after card appears)
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bounceAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    // Content staggered fade-in
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _contentFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );

    // Confetti particle controller
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    // Start animations
    _entryController.forward();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _bounceController.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _contentController.forward();
    });
    _confettiController.play();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _bounceController.dispose();
    _contentController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  List<Color> get _confettiColors => [
        const Color(0xFFFF9800), // Gold
        const Color(0xFFFFC107), // Amber
        Colors.white,
        Colors.yellowAccent,
        const Color(0xFF4CAF50), // Green (AppColors.secondary)
      ];

  /// Draws a simple 5-pointed star path for confetti particles.
  static Path _drawStar(Size size) {
    const numPoints = 5;
    const outerRadius = 6.0;
    const innerRadius = 2.5;
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);

    for (var i = 0; i < numPoints * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = (pi * i / numPoints) - pi / 2;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = widget.totalCompleted / widget.totalTests;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Semi-transparent backdrop (tap to dismiss)
          GestureDetector(
            onTap: widget.onDismiss,
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, _) => Container(
                color: Colors.black.withOpacity(0.55 * _fadeAnimation.value),
              ),
            ),
          ),

          // Confetti particle system
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: _confettiColors,
              numberOfParticles: 20,
              maxBlastForce: 20,
              minBlastForce: 5,
              gravity: 0.2,
              particleDrag: 0.05,
              createParticlePath: _drawStar,
            ),
          ),

          // Celebration card (wrapped to absorb taps on margin area)
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // prevent taps from passing to backdrop
              child: AnimatedBuilder(
                animation: _entryController,
                builder: (context, _) {
                  final scale = _scaleAnimation.value;
                  final opacity = _fadeAnimation.value;
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: _buildCard(context, theme, isDark, progress),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    double progress,
  ) {
    const goldColor = Color(0xFFFF9800);
    const goldColorLight = Color(0xFFFFC107);

    return Container(
      width: 320,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: goldColor.withOpacity(0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: goldColor.withOpacity(0.4),
            blurRadius: 40,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Trophy icon with bounce
            AnimatedBuilder(
              animation: _bounceController,
              builder: (context, _) {
                final bounce = _bounceAnimation.value;
                return Transform.scale(
                  scale: 0.8 + (bounce * 0.4),
                  child: const Text('🏆', style: TextStyle(fontSize: 72)),
                );
              },
            ),
            const SizedBox(height: 12),

            // "PERFECT SCORE!" header
            const Text(
              'PERFECT SCORE!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: goldColorLight,
              ),
            ),
            const SizedBox(height: 8),

            // Score
            Text(
              '🎉 You scored ${widget.score}/${widget.total}!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 4),

            // Test completed
            Text(
              widget.completedTestTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.secondary, size: 18),
                SizedBox(width: 6),
                Text(
                  'Completed ✅',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),

            // Divider
            if (!_isLastTest) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1),
              ),

              // Next test unlocked
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_open_rounded,
                      color: goldColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Mock Test ${widget.nextTestNumber} Unlocked!',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: goldColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'You\'ve earned the right to advance! 🎯',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1),
              ),
              Text(
                '🎉 You completed all ${widget.totalTests} tests!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: goldColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'What an incredible achievement! 🌟',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
            ],

            // Progress bar
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color
                            ?.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      '${widget.totalCompleted}/${widget.totalTests}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedBuilder(
                    animation: _contentController,
                    builder: (context, _) => LinearProgressIndicator(
                      value: progress * _contentFade.value,
                      backgroundColor:
                          isDark ? Colors.grey[800] : Colors.grey[200],
                      color: AppColors.secondary,
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),

            // Rewards
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.xpReward > 0) ...[
                  _RewardChip(
                    icon: '⚡',
                    label: '+${widget.xpReward} XP',
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                ],
                if (widget.coinReward > 0)
                  _RewardChip(
                    icon: '🪙',
                    label: '+${widget.coinReward}',
                    color: AppColors.warning,
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Buttons
            if (!_isLastTest)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: widget.onTakeNextTest,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text(
                    'TAKE NEXT TEST',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: widget.onDismiss,
                  icon: const Icon(Icons.emoji_events_rounded),
                  label: const Text(
                    'VIEW RESULTS',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                ),
              ),

            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.onDismiss,
              child: Text(
                'Stay & Review',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small badge showing a reward (XP or coins).
class _RewardChip extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;

  const _RewardChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
