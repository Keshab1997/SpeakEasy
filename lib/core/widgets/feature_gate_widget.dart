import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../../services/remote_config_service.dart';

/// A widget that conditionally shows its child based on a remote feature toggle.
///
/// If the feature is disabled, shows a "Coming Soon" placeholder instead.
/// The feature key must match one of the keys in [FeatureToggles].
class FeatureGateWidget extends StatelessWidget {
  final String featureKey;
  final Widget child;
  final Widget? placeholder;

  const FeatureGateWidget({
    super.key,
    required this.featureKey,
    required this.child,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: RemoteConfigService.isFeatureEnabled(featureKey),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return child; // Show the feature while loading
        }
        if (snapshot.data == true) {
          return child;
        }
        return placeholder ?? _buildComingSoon(context);
      },
    );
  }

  Widget _buildComingSoon(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.rocket_launch_outlined,
            size: 40,
            color: AppColors.primary.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Coming Soon',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This feature is currently disabled',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}