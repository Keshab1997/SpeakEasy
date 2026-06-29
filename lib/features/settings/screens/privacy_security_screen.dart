import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy & Security',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroCard(isDark),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Your Privacy'),
            const SizedBox(height: 8),
            _buildInfoCard(
              isDark: isDark,
              children: const [
                _InfoTile(
                  icon: Icons.person_outline_rounded,
                  iconColor: AppColors.primary,
                  title: 'Profile Information',
                  description:
                      'Your name, email, learning level, and profile photo are used only to personalize your learning experience.',
                ),
                Divider(height: 1),
                _InfoTile(
                  icon: Icons.school_outlined,
                  iconColor: AppColors.secondary,
                  title: 'Learning Progress',
                  description:
                      'Your lessons, quiz scores, streaks, XP, and coins help the app show your progress and achievements.',
                ),
                Divider(height: 1),
                _InfoTile(
                  icon: Icons.cloud_outlined,
                  iconColor: AppColors.info,
                  title: 'Cloud Sync',
                  description:
                      'When you sign in, some progress data may sync with Firebase so you can continue learning later.',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Security Tips'),
            const SizedBox(height: 8),
            _buildInfoCard(
              isDark: isDark,
              children: const [
                _InfoTile(
                  icon: Icons.lock_outline_rounded,
                  iconColor: AppColors.warning,
                  title: 'Keep Your Account Safe',
                  description:
                      'Use a strong password and do not share your login details with anyone.',
                ),
                Divider(height: 1),
                _InfoTile(
                  icon: Icons.vpn_key_outlined,
                  iconColor: Colors.purple,
                  title: 'API Key Safety',
                  description:
                      'If you add an AI API key, keep it private. Do not share screenshots or copies of your key.',
                ),
                Divider(height: 1),
                _InfoTile(
                  icon: Icons.logout_rounded,
                  iconColor: AppColors.error,
                  title: 'Sign Out on Shared Devices',
                  description:
                      'Always sign out if you use this app on another person’s phone or a shared device.',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Device Permissions'),
            const SizedBox(height: 8),
            _buildInfoCard(
              isDark: isDark,
              children: const [
                _InfoTile(
                  icon: Icons.mic_none_rounded,
                  iconColor: AppColors.primary,
                  title: 'Microphone',
                  description:
                      'Microphone access is used for speaking practice and pronunciation features.',
                ),
                Divider(height: 1),
                _InfoTile(
                  icon: Icons.camera_alt_outlined,
                  iconColor: AppColors.secondary,
                  title: 'Camera & Photos',
                  description:
                      'Camera or photo access is used only when you choose to update your profile picture.',
                ),
                Divider(height: 1),
                _InfoTile(
                  icon: Icons.notifications_none_rounded,
                  iconColor: AppColors.accent,
                  title: 'Notifications',
                  description:
                      'Notifications may be used for daily practice reminders, word-of-the-day alerts, and learning streak reminders.',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Data Control'),
            const SizedBox(height: 8),
            _buildInfoCard(
              isDark: isDark,
              children: const [
                _InfoTile(
                  icon: Icons.delete_sweep_outlined,
                  iconColor: AppColors.error,
                  title: 'Clear Local Cache',
                  description:
                      'You can clear locally stored cache from the Profile screen. Cloud data may reload again after sign-in.',
                ),
                Divider(height: 1),
                _InfoTile(
                  icon: Icons.settings_outlined,
                  iconColor: Colors.purple,
                  title: 'Manage Preferences',
                  description:
                      'You can control theme, notifications, learning language, and AI key settings from the Settings page.',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildNoteCard(isDark),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.primaryGradient),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_rounded, color: Colors.white, size: 36),
          SizedBox(height: 14),
          Text(
            'Your data stays protected',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'We use your information only to improve your English learning experience and keep your progress safe.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: isDark ? Colors.white60 : Colors.black45,
      ),
    );
  }

  Widget _buildInfoCard({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildNoteCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.info.withOpacity(0.18)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final uri = Uri.parse('https://keshab1997.github.io/Flutter-Spoken-English-App/privacy_policy.html');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.open_in_new_rounded, color: AppColors.info),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Full Privacy Policy',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'View our complete privacy policy online',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black45,
                      fontSize: 12,
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

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
