import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Screen shown when the app is in maintenance mode.
/// Users cannot proceed past this screen until maintenance is turned off.
class MaintenanceScreen extends StatelessWidget {
  final String message;

  const MaintenanceScreen({
    super.key,
    this.message = 'App is under maintenance. Please come back later.',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Maintenance icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  size: 72,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Under Maintenance',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'We\'ll be back soon!',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}