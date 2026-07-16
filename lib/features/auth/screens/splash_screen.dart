import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/user_model.dart';
import '../../../services/remote_config_service.dart';
import '../../../services/hive_service.dart';
import '../../intro/screens/intro_screen.dart';
import '../../admin/screens/maintenance_screen.dart';
import '../../admin/screens/force_update_screen.dart';
import '../../home/screens/main_navigation_screen.dart';
import 'login_screen.dart';
import '../../../services/in_app_update_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();

    // Listen to auth state — navigate as soon as it resolves (not loading)
    Future.delayed(const Duration(seconds: 2), _listenAndNavigate);

    // Safety timeout: if auth doesn't resolve within 10s, navigate to login
    Future.delayed(const Duration(seconds: 10), _timeoutNavigate);
  }

  void _timeoutNavigate() {
    if (!_navigated && mounted) {
      _navigateToLogin();
    }
  }

  void _listenAndNavigate() {
    // Watch live; as soon as auth is no longer loading, navigate once
    ref.listenManual(authProvider, (_, next) {
      if (!next.isLoading && mounted) {
        next.whenOrNull(
          data: _navigateToNext,
          error: (_, __) => _navigateToLogin(),
        );
      }
    }, fireImmediately: true);
  }

  Future<void> _navigateToNext(UserModel? user) async {
    if (_navigated) return;
    _navigated = true;

    // Check if onboarding has been completed
    if (!HiveService.isOnboardingCompleted()) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const IntroScreen()),
        );
      }
      return;
    }

    // Fetch remote config to check maintenance/force-update status
    try {
      final config = await RemoteConfigService.getConfig();

      // Check maintenance mode first
      if (config.maintenanceMode.enabled) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => MaintenanceScreen(
                message: config.maintenanceMode.message,
              ),
            ),
          );
        }
        return;
      }

      // Check force update
      if (config.forceUpdate.enabled) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ForceUpdateScreen(
                updateInfo: config.forceUpdate,
              ),
            ),
          );
        }
        return;
      }

      // Check for soft / in-app update (Google Play In-App Update)
      final inAppService = InAppUpdateService();
      final hasUpdate = await inAppService.isUpdateAvailable();
      if (hasUpdate && await inAppService.shouldShowUpdate()) {
        await inAppService.startFlexibleUpdate();
        // After dialog is dismissed, continue to normal navigation
      }
    } catch (_) {
      // If remote config fails, proceed with normal flow
    }

    // Normal navigation
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => user != null
              ? const MainNavigationScreen()
              : const LoginScreen(),
        ),
      );
    }
  }

  void _navigateToLogin() {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.primaryGradient,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.translate_rounded,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                // App Title
                const Text(
                  'SpeakEasy',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                // App Subtitle
                Text(
                  'Your AI English Speaking Partner',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 48),
                // Small indicator
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
