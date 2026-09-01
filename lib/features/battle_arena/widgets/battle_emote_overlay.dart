import 'dart:ui';
import 'package:flutter/material.dart';

/// Quick-emote picker tray with a glassmorphism look.
class BattleEmoteOverlay extends StatelessWidget {
  final ValueChanged<String> onSelectEmote;

  const BattleEmoteOverlay({
    super.key,
    required this.onSelectEmote,
  });

  static const List<String> emotes = ['🔥', '😎', '👏', '🤯', '⚡', '🏆'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.25 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: emotes.map((emote) {
              return _BouncyEmoteButton(
                emote: emote,
                onTap: () => onSelectEmote(emote),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _BouncyEmoteButton extends StatefulWidget {
  final String emote;
  final VoidCallback onTap;

  const _BouncyEmoteButton({required this.emote, required this.onTap});

  @override
  State<_BouncyEmoteButton> createState() => _BouncyEmoteButtonState();
}

class _BouncyEmoteButtonState extends State<_BouncyEmoteButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 1.35 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
          ),
          child: Text(
            widget.emote,
            style: const TextStyle(fontSize: 26),
          ),
        ),
      ),
    );
  }
}

/// A polished floating emote bubble shown above a player's avatar.
///
/// Pops in with a bounce, floats gently and fades out.
/// [accentColor] tints the bubble so it's clearly visible:
/// blue = you, purple = AI bot, red = online opponent.
class FloatingEmoteBubble extends StatefulWidget {
  final String emote;
  final Color accentColor;

  const FloatingEmoteBubble({
    super.key,
    required this.emote,
    this.accentColor = const Color(0xFF8B5CF6),
  });

  @override
  State<FloatingEmoteBubble> createState() => _FloatingEmoteBubbleState();
}

class _FloatingEmoteBubbleState extends State<FloatingEmoteBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.25).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 22,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 13),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 0.92), weight: 25),
    ]).animate(_animController);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 63),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_animController);

    _slideAnimation = Tween<double>(begin: 6.0, end: -36.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.accentColor,
                      Color.lerp(widget.accentColor, Colors.black, 0.35)!,
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.55),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  widget.emote,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
