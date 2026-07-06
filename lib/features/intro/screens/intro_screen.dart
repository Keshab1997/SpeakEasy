import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/hive_service.dart';

class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_IntroItem> _pages = [
    _IntroItem(
      icon: Icons.menu_book_rounded,
      title: '৭০+ গ্রামার লেসন',
      subtitle: 'বাংলায় ইংরেজি গ্রামার শিখুন\nA-Z পর্যন্ত সম্পূর্ণ কোর্স',
      color: const Color(0xFF6C63FF),
    ),
    _IntroItem(
      icon: Icons.sports_esports_rounded,
      title: 'গেম খেলে শিখুন',
      subtitle: '১০+ মজার গেম মোড\nখেলতে খেলতে ইংরেজি শিখুন',
      color: const Color(0xFFFF6B6B),
    ),
    _IntroItem(
      icon: Icons.record_voice_over_rounded,
      title: 'AI টিচার ও স্পিকিং',
      subtitle: 'AI-এর সাথে কথা বলুন\nস্পিকিং প্র্যাকটিস করুন',
      color: const Color(0xFF4ECDC4),
    ),
    _IntroItem(
      icon: Icons.emoji_events_rounded,
      title: 'শুরু করুন',
      subtitle: 'প্রতিদিন প্র্যাকটিস করুন\nস্ট্রিক ধরে রাখুন, লিডারবোর্ডে জায়গা করুন',
      color: AppColors.primary,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNextPressed() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() {
    HiveService.setOnboardingCompleted();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _skipOnboarding() {
    HiveService.setOnboardingCompleted();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button (top-right)
            Padding(
              padding: const EdgeInsets.only(right: 20, top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: _skipOnboarding,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),

            // PageView slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final item = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: size.width * 0.35,
                          height: size.width * 0.35,
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.icon,
                            size: size.width * 0.16,
                            color: item.color,
                          ),
                        ),
                        SizedBox(height: size.height * 0.05),
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white60 : Colors.grey[600],
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom section: dots + button
            Padding(
              padding: EdgeInsets.only(
                bottom: size.height * 0.06,
                left: 40,
                right: 40,
              ),
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: _currentPage == index ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? _pages[_currentPage].color
                              : (isDark ? Colors.white24 : Colors.grey.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Next / Get Started button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _onNextPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pages[_currentPage].color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? 'শুরু করুন'
                            : 'Next',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _IntroItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}
