import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/game/achievement_model.dart';

/// A full-screen celebration overlay shown when an achievement is unlocked.
///
/// Displays a rarity-themed animated card over a semi-transparent backdrop
/// with confetti particles. The card scales and fades in with a spring
/// animation, and the achievement icon bounces separately.
class AchievementUnlockOverlay extends StatefulWidget {
  final AchievementModel achievement;
  final VoidCallback onDismiss;

  const AchievementUnlockOverlay({
    super.key,
    required this.achievement,
    required this.onDismiss,
  });

  @override
  State<AchievementUnlockOverlay> createState() =>
      _AchievementUnlockOverlayState();
}

class _AchievementUnlockOverlayState extends State<AchievementUnlockOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;

  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();

    // ── Entry animation: scale 0 → 1.05 → 1.0 with spring feel ──
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

    // ── Icon bounce animation (starts after card appears) ──
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bounceAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    // ── Confetti particle controller ──
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    // ── Start animations ──
    _entryController.forward();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _bounceController.forward();
    });
    _confettiController.play();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _bounceController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // ── Rarity configuration ──

  Map<String, dynamic> get _rarityConfig {
    final r = widget.achievement.rarity;
    switch (r) {
      case 'Legendary':
        return {
          'particleCount': 25,
          'glowRadius': 40.0,
          'glowOpacity': 0.5,
        };
      case 'Epic':
        return {
          'particleCount': 20,
          'glowRadius': 30.0,
          'glowOpacity': 0.4,
        };
      case 'Rare':
        return {
          'particleCount': 15,
          'glowRadius': 20.0,
          'glowOpacity': 0.3,
        };
      case 'Uncommon':
        return {
          'particleCount': 10,
          'glowRadius': 15.0,
          'glowOpacity': 0.25,
        };
      default: // Common
        return {
          'particleCount': 5,
          'glowRadius': 10.0,
          'glowOpacity': 0.15,
        };
    }
  }

  List<Color> get _confettiColors {
    final base = widget.achievement.rarityColor;
    return [
      base,
      base.withOpacity(0.7),
      Colors.white,
      Colors.amberAccent,
      Colors.yellowAccent,
    ];
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final a = widget.achievement;
    final rarityColor = a.rarityColor;
    final config = _rarityConfig;
    final particleCount = config['particleCount'] as int;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── Semi-transparent backdrop (tap to dismiss) ──
          GestureDetector(
            onTap: widget.onDismiss,
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, _) => Container(
                color: Colors.black.withOpacity(0.55 * _fadeAnimation.value),
              ),
            ),
          ),

          // ── Confetti particle system ──
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: _confettiColors,
              numberOfParticles: particleCount,
              maxBlastForce: 20,
              minBlastForce: 5,
              gravity: 0.2,
              particleDrag: 0.05,
              createParticlePath: _drawStar,
            ),
          ),

          // ── Achievement card (wrapped to absorb taps on
          //    rounded corners and margin area) ──
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
                      child: _buildCard(context, a, rarityColor, config),
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
    AchievementModel a,
    Color rarityColor,
    Map<String, dynamic> config,
  ) {
    final glowRadius = config['glowRadius'] as double;
    final glowOpacity = config['glowOpacity'] as double;
    final theme = Theme.of(context);

    return Container(
      width: 300,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: rarityColor.withOpacity(0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: rarityColor.withOpacity(glowOpacity),
            blurRadius: glowRadius,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Achievement emoji icon ──
            AnimatedBuilder(
              animation: _bounceController,
              builder: (context, _) {
                final bounce = _bounceAnimation.value;
                return Transform.scale(
                  scale: 0.8 + (bounce * 0.4),
                  child: Text(a.icon, style: const TextStyle(fontSize: 64)),
                );
              },
            ),
            const SizedBox(height: 12),

            // ── "ACHIEVEMENT UNLOCKED!" header ──
            Text(
              'ACHIEVEMENT UNLOCKED!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
                color: rarityColor,
              ),
            ),
            const SizedBox(height: 16),

            // ── Achievement title ──
            Text(
              a.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // ── Description ──
            Text(
              a.description,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),

            // ── Rarity badge ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: rarityColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                a.rarity.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: rarityColor,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Rewards row ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (a.xpReward > 0) ...[
                  _RewardChip(
                    icon: '⚡',
                    label: '+${a.xpReward} XP',
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                ],
                if (a.coinReward > 0)
                  _RewardChip(
                    icon: '🪙',
                    label: '+${a.coinReward}',
                    color: AppColors.warning,
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Continue button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: rarityColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'CONTINUE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
