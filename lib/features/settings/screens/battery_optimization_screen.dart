import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';

/// Guides the user through re-enabling push notifications on devices that
/// aggressively kill background apps (Realme / OPPO / Vivo / Xiaomi / POCO /
/// OnePlus / Huawei / Honor / Samsung).
///
/// The root cause of "notifications arrive only while the app is open":
/// these OEMs block the app from receiving FCM pushes once it is swiped away,
/// unless (1) auto-start is allowed and (2) battery optimization is disabled.
/// No code change can force this — the user must flip these two switches.
class BatteryOptimizationScreen extends StatefulWidget {
  const BatteryOptimizationScreen({super.key});

  @override
  State<BatteryOptimizationScreen> createState() =>
      _BatteryOptimizationScreenState();
}

class _BatteryOptimizationScreenState extends State<BatteryOptimizationScreen> {
  static const MethodChannel _channel =
      MethodChannel('com.speakeasy.english.learn/device');

  String _manufacturer = '';
  bool _detected = false;
  bool _isIgnoringBatteryOptimizations = false;

  @override
  void initState() {
    super.initState();
    _detectManufacturer();
    _checkBatteryOptimization();
  }

  Future<void> _detectManufacturer() async {
    try {
      final m = await _channel.invokeMethod<String>('getManufacturer');
      if (mounted) {
        setState(() {
          _manufacturer = (m ?? '').toLowerCase();
          _detected = true;
        });
      }
    } catch (e) {
      debugPrint('BatteryOptimizationScreen: getManufacturer failed — $e');
      if (mounted) setState(() => _detected = true);
    }
  }

  Future<void> _checkBatteryOptimization() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final ignoring =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      if (mounted) {
        setState(() => _isIgnoringBatteryOptimizations = ignoring ?? false);
      }
    } catch (e) {
      debugPrint('BatteryOptimizationScreen: isIgnoring failed — $e');
    }
  }

  Future<void> _requestIgnoreBatteryOptimizations() async {
    var ok = false;
    try {
      ok = await _channel
              .invokeMethod<bool>('requestIgnoreBatteryOptimizations') ??
          false;
    } catch (e) {
      debugPrint(
          'BatteryOptimizationScreen: requestIgnoreBatteryOptimizations failed — $e');
    }
    if (ok) {
      // The system prompt takes the user away; re-check on return.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await _checkBatteryOptimization();
    }
    if (mounted && !_isIgnoringBatteryOptimizations) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'বিকল্প হিসেবে নিচের "Battery optimization settings" বাটনে গিয়ে SpeakEasy-কে "Don\'t optimize" করুন।'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openAutoStart() async {
    try {
      final ok =
          await _channel.invokeMethod<bool>('openAutoStartSettings') ?? false;
      if (!ok) await _openAppDetails();
    } catch (e) {
      debugPrint('BatteryOptimizationScreen: openAutoStart failed — $e');
      await _openAppDetails();
    }
  }

  Future<void> _openBatterySettings() async {
    try {
      final ok = await _channel
              .invokeMethod<bool>('openBatteryOptimizationSettings') ??
          false;
      if (!ok) await _openAppDetails();
    } catch (e) {
      debugPrint('BatteryOptimizationScreen: openBatterySettings failed — $e');
      await _openAppDetails();
    }
  }

  Future<void> _openAppDetails() async {
    try {
      await _channel.invokeMethod<bool>('openAppDetailsSettings');
    } catch (e) {
      debugPrint('BatteryOptimizationScreen: openAppDetails failed — $e');
    }
  }

  bool get _isProblematicOem {
    const brands = [
      'realme', 'oppo', 'vivo', 'iqoo', 'xiaomi', 'redmi', 'poco',
      'oneplus', 'huawei', 'honor', 'samsung', 'infinix', 'tecno',
      'micromax', 'lava', 'itel', 'nokia', 'motorola',
    ];
    return brands.any(_manufacturer.contains);
  }

  String get _brandLabel {
    if (_manufacturer.contains('realme')) return 'Realme';
    if (_manufacturer.contains('oppo')) return 'OPPO';
    if (_manufacturer.contains('oneplus')) return 'OnePlus';
    if (_manufacturer.contains('vivo')) return 'Vivo';
    if (_manufacturer.contains('iqoo')) return 'iQOO';
    if (_manufacturer.contains('xiaomi')) return 'Xiaomi';
    if (_manufacturer.contains('redmi')) return 'Redmi';
    if (_manufacturer.contains('poco')) return 'POCO';
    if (_manufacturer.contains('huawei')) return 'Huawei';
    if (_manufacturer.contains('honor')) return 'Honor';
    if (_manufacturer.contains('samsung')) return 'Samsung';
    if (_manufacturer.contains('infinix')) return 'Infinix';
    if (_manufacturer.contains('tecno')) return 'Tecno';
    if (_manufacturer.isNotEmpty) return _manufacturer;
    return 'your phone';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? Colors.white : AppColors.onBackgroundLight;
    final textSub = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Fix',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _warningCard(isDark),
            const SizedBox(height: 16),
            if (_detected) _detectedChip(isDark),
            const SizedBox(height: 16),
            Text('কেন নোটিফিকেশন আসছে না?',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textMain)),
            const SizedBox(height: 6),
            Text(
              '$_brandLabel phone-এ অ্যাপ বন্ধ (swipe) করলে ফোনটা অ্যাপটাকে পুরোপুরি বন্ধ করে দেয়। '
              'তাই ব্যাটারি বাঁচানোর জন্য push notification আর ঢুকতে পারে না। '
              'নিচের ২টা সেটিং চালু করলেই notification আবার আসবে — অ্যাপ খোলা না থাকলেও।',
              style: TextStyle(fontSize: 14, height: 1.5, color: textSub),
            ),
            const SizedBox(height: 24),

            _stepCard(
              isDark,
              step: '১',
              title: 'Auto-start / Autostart চালু করুন',
              description:
                  'ফোনের অটো-স্টার্ট তালিকায় SpeakEasy-কে "Allow" করুন, যাতে অ্যাপ বন্ধ থাকলেও ব্যাকগ্রাউন্ডে notification পেতে পারে।',
              buttonLabel: 'Open Auto-start settings',
              icon: Icons.play_circle_outline_rounded,
              onTap: _openAutoStart,
            ),
            const SizedBox(height: 12),

            _stepCard(
              isDark,
              step: '২',
              title: 'Battery optimization বন্ধ করুন',
              description:
                  'Battery saver-এ SpeakEasy-কে "Don\'t optimize" / "Unrestricted" করুন। '
                  'না হলে ফোন ব্যাটারি বাঁচাতে notification ব্লক করে দেয়।',
              buttonLabel: _isIgnoringBatteryOptimizations
                  ? '✓ Already allowed'
                  : 'Allow (No battery optimization)',
              icon: Icons.battery_saver_rounded,
              highlight: !_isIgnoringBatteryOptimizations,
              onTap: _requestIgnoreBatteryOptimizations,
            ),
            const SizedBox(height: 12),

            _stepCard(
              isDark,
              step: '৩',
              title: 'সেটিংস ম্যানুয়ালি খুলুন (ঐচ্ছিক)',
              description:
                  'উপরের বাটন কাজ না করলে এখান থেকে অ্যাপের Settings খুলে নিজে হাতে "Auto-start" ও "Battery" অপশন দুটো চালু করুন।',
              buttonLabel: 'Open battery settings',
              icon: Icons.settings_rounded,
              onTap: _openBatterySettings,
            ),
            const SizedBox(height: 24),

            Text(
              '⚡ এই সেটিং করলে WhatsApp/Facebook-এর মতোই notification আসবে। '
              'সেটিং-এর নাম ফোনের version অনুযায়ী একটু আলাদা হতে পারে, কিন্তু উপায় একই।',
              style: TextStyle(fontSize: 12.5, height: 1.5, color: textSub),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _warningCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_off_outlined,
              color: AppColors.warning, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'আপনার ফোনে অ্যাপ বন্ধ থাকলে notification আসছে না — এটা ফোনের ব্যাটারি সেভিং সেটিংয়ের কারণে। '
              'নিচের ধাপগুলো ফলো করলেই ঠিক হয়ে যাবে।',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: isDark ? Colors.white : AppColors.onBackgroundLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detectedChip(bool isDark) {
    return Row(
      children: [
        Icon(Icons.phone_android_rounded,
            size: 16,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        const SizedBox(width: 6),
        Text(
          _isProblematicOem
              ? 'Device detected: $_brandLabel — এই ব্র্যান্ডে এই সমস্যা খুব common।'
              : 'Device detected: $_brandLabel',
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _stepCard(
    bool isDark, {
    required String step,
    required String title,
    required String description,
    required String buttonLabel,
    required IconData icon,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    final border = highlight
        ? AppColors.success
        : (isDark ? AppColors.borderDark : AppColors.borderLight);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(step,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(description,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              )),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: highlight ? AppColors.success : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(icon, size: 18),
              label: Text(buttonLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              onPressed: onTap,
            ),
          ),
        ],
      ),
    );
  }
}
