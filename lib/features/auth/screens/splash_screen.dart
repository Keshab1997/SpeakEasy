import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/hive_service.dart';
import '../../../services/in_app_update_service.dart';
import '../../../services/remote_config_service.dart';
import '../../admin/screens/force_update_screen.dart';
import '../../admin/screens/maintenance_screen.dart';
import '../../home/screens/main_navigation_screen.dart';
import '../../intro/screens/intro_screen.dart';
import 'login_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  bool _navigated = false;
  bool _navigationStarted = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
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
    if (_navigated || _navigationStarted) return;
    _navigationStarted = true;

    try {
      if (!HiveService.isOnboardingCompleted()) {
        _pushReplacement(const IntroScreen());
        return;
      }

      try {
        final config = await RemoteConfigService.getConfig()
            .timeout(const Duration(seconds: 8));

        if (config.maintenanceMode.enabled) {
          _pushReplacement(
            MaintenanceScreen(message: config.maintenanceMode.message),
          );
          return;
        }

        if (config.forceUpdate.enabled) {
          _pushReplacement(
            ForceUpdateScreen(updateInfo: config.forceUpdate),
          );
          return;
        }

        try {
          final inAppService = InAppUpdateService();
          final hasUpdate = await inAppService
              .isUpdateAvailable()
              .timeout(const Duration(seconds: 5), onTimeout: () => false);
          if (hasUpdate && await inAppService.shouldShowUpdate()) {
            await inAppService.startFlexibleUpdate();
          }
        } catch (_) {}
      } catch (_) {}

      _pushReplacement(
        user != null ? const MainNavigationScreen() : const LoginScreen(),
      );
    } finally {
      _navigationStarted = false;
    }
  }

  void _pushReplacement(Widget screen) {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _navigateToLogin() {
    if (_navigated || !mounted) return;
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
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF0B1120), Color(0xFF1E1B4B), Color(0xFF0F172A)]
                : const [Color(0xFFF8FAFC), Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 1),

              // 🌟 Hero Character Image (Full & Beautiful)
              Expanded(
                flex: 7,
                child: Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        constraints: BoxConstraints(
                          maxHeight: size.height * 0.52,
                          maxWidth: size.width * 0.92,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Soft Ambient Glow behind Character
                            Container(
                              width: size.width * 0.7,
                              height: size.width * 0.7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.18 : 0.12),
                              ),
                            ),
                            // Character Illustration
                            Image.asset(
                              'assets/images/splash_character_android.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 🏷️ Bottom Branding Section
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // App Name with Gradient Glow
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFFEC4899)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Text(
                          'SpeakEasy',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tagline Badge Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFF2563EB).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : const Color(0xFF2563EB).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          'Your AI English Speaking Partner 🗣️',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Bengali Subtitle
                      Text(
                        'বাংলা থেকে সহজে ইংরেজি শেখার সেরা অ্যাপ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontFamily: 'NotoSansBengali',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Sleek Loading Indicator
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? const Color(0xFF60A5FA) : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
