import 'package:flutter/services.dart';

/// A reliable haptic feedback helper that works across Android and iOS.
///
/// Flutter's built-in [HapticFeedback.lightImpact] / [.mediumImpact] rely on
/// `performHapticFeedback` on Android, which is NOT supported on many devices
/// (especially Chinese ROMs, older Android, or custom launchers).
///
/// This helper falls back to [HapticFeedback.vibrate] which uses the raw
/// `Vibrator` API and works on virtually every device that has a vibrator.
class HapticService {
  /// Light vibration – use for correct answers, positive feedback.
  static void correct() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {
      HapticFeedback.vibrate();
    }
  }

  /// Medium vibration – use for wrong answers, negative feedback.
  static void wrong() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {
      HapticFeedback.vibrate();
    }
  }

  /// Heavy vibration – use for major events (boss battle, wrong with streak).
  static void heavy() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {
      HapticFeedback.vibrate();
    }
  }
}
