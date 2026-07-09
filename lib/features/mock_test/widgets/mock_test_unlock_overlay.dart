import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/mock_test_provider.dart';
import '../../../providers/game/coin_provider.dart';
import '../../../services/ad_service.dart';
import '../../../services/remote_config_service.dart';

/// Full-screen overlay shown when a student taps a locked mock test.
///
/// Offers two unlock methods:
///   🪙 Pay coins → Permanent unlock
///   📺 Watch ad  → 24-hour temporary unlock
class MockTestUnlockOverlay extends ConsumerStatefulWidget {
  final int testNumber;
  final String testTitle;
  final VoidCallback onUnlocked;
  final VoidCallback onDismiss;

  const MockTestUnlockOverlay({
    super.key,
    required this.testNumber,
    required this.testTitle,
    required this.onUnlocked,
    required this.onDismiss,
  });

  @override
  ConsumerState<MockTestUnlockOverlay> createState() =>
      _MockTestUnlockOverlayState();
}

class _MockTestUnlockOverlayState extends ConsumerState<MockTestUnlockOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  int _coinPrice = 300;
  bool _adEnabled = true;
  int _adDurationHours = 24;
  bool _loadingConfig = true;
  bool _processingCoin = false;
  bool _processingAd = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const ElasticOutCurve(0.85),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeIn,
    );
    _entryController.forward();
    _loadConfig();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final price = await RemoteConfigService.getMockTestCoinPrice();
      final adEnabled = await RemoteConfigService.isMockTestAdUnlockEnabled();
      final adHours = await RemoteConfigService.getMockTestAdUnlockDurationHours();
      if (mounted) {
        setState(() {
          _coinPrice = price;
          _adEnabled = adEnabled;
          _adDurationHours = adHours;
          _loadingConfig = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingConfig = false);
    }
  }

  Future<void> _unlockWithCoins() async {
    if (_processingCoin) return;
    setState(() {
      _processingCoin = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(mockTestProvider.notifier);
      final success = await notifier.unlockWithCoins(widget.testNumber, _coinPrice);

      if (!mounted) return;

      if (success) {
        // Refresh coin state to update UI
        ref.read(coinProvider.notifier).refresh();
        widget.onUnlocked();
      } else {
        setState(() {
          _errorMessage = 'Not enough coins! 🪙\nYou need $_coinPrice coins to unlock.';
          _processingCoin = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Something went wrong. Please try again.';
          _processingCoin = false;
        });
      }
    }
  }

  Future<void> _unlockWithAd() async {
    if (_processingAd) return;
    setState(() {
      _processingAd = true;
      _errorMessage = null;
    });

    try {
      final adService = AdService();
      // Load the ad first
      await adService.loadRewardedAd();
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Use a Completer to wait for the reward callback
      final rewardCompleter = Completer<void>();

      // Show and check result
      final shown = await adService.showRewardedAd(
        onRewardEarned: () {
          // Ad watched successfully — unlock the test
          final notifier = ref.read(mockTestProvider.notifier);
          notifier.unlockWithAd(
            widget.testNumber,
            duration: Duration(hours: _adDurationHours),
          );
          rewardCompleter.complete();
        },
      );

      if (!mounted) return;

      if (shown) {
        // Wait for the reward callback (user watches full ad)
        await rewardCompleter.future.timeout(
          const Duration(minutes: 2),
          onTimeout: () {
            if (!rewardCompleter.isCompleted) {
              rewardCompleter.completeError(TimeoutException('Ad watch timed out'));
            }
          },
        );

        if (mounted) {
          widget.onUnlocked();
          return;
        }
      }

      if (mounted) {
        setState(() {
          _errorMessage = 'Could not show ad right now. Try again later.';
          _processingAd = false;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ad timed out. Please try again.';
          _processingAd = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Something went wrong. Please try again.';
          _processingAd = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coins = ref.watch(coinProvider).currentCoins;
    final canAfford = coins >= _coinPrice;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                      : [Colors.white, const Color(0xFFF8F9FF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Lock Icon ──
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.orangeAccent, Colors.deepOrange],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepOrange.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Title ──
                    Text(
                      '🔒 Test ${widget.testNumber} is Locked',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.testTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Divider ──
                    Container(
                      height: 1,
                      color: (isDark ? Colors.white12 : Colors.black12),
                    ),
                    const SizedBox(height: 20),

                    // ── Choose Method Text ──
                    Text(
                      'Choose how to unlock:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Coins Balance ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(
                            '$coins coins available',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Option 1: Pay Coins ──
                    _buildOptionButton(
                      context: context,
                      icon: '🪙',
                      title: 'Pay $_coinPrice Coins',
                      subtitle: 'Permanent unlock — one-time payment',
                      color: Colors.amber.shade700,
                      enabled: canAfford && !_loadingConfig && !_processingCoin && !_processingAd,
                      loading: _processingCoin,
                      onTap: _unlockWithCoins,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),

                    // ── Option 2: Watch Ad ──
                    if (_adEnabled)
                      _buildOptionButton(
                        context: context,
                        icon: '📺',
                        title: 'Watch an Ad',
                        subtitle: '${_adDurationHours}h temporary unlock',
                        color: Colors.purple.shade400,
                        enabled: !_loadingConfig && !_processingCoin && !_processingAd,
                        loading: _processingAd,
                        onTap: _unlockWithAd,
                        isDark: isDark,
                      ),

                    // ── Error Message ──
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ── Cancel ──
                    TextButton(
                      onPressed: widget.onDismiss,
                      child: Text(
                        'Maybe later',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required BuildContext context,
    required String icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool enabled,
    required bool loading,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: enabled ? color.withOpacity(0.12) : (isDark ? Colors.white10 : Colors.grey.shade100),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: AnimatedOpacity(
            opacity: enabled ? 1.0 : 0.5,
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: enabled ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: loading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                              ),
                            )
                          : Text(icon, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: enabled ? color : (isDark ? Colors.white38 : Colors.black38),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: enabled
                                ? (isDark ? Colors.white60 : Colors.black54)
                                : (isDark ? Colors.white24 : Colors.black26),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (enabled)
                    Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
