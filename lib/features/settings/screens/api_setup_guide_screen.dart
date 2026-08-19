import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ApiSetupGuideScreen extends StatelessWidget {
  const ApiSetupGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Setup Guide', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('How to Get Your Free API Key',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),

            _StepCard(
              number: 1,
              title: 'Visit the API Key Page',
              description: 'Open this link in your browser:',
              code: 'https://api.chatanywhere.tech/v1/oauth/free/render',
              icon: Icons.language_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            _StepCard(
              number: 2,
              title: 'Sign in with GitHub',
              description: 'Login using your GitHub account.\n'
                  'Don\'t have one? Create at:\nhttps://github.com/signup',
              icon: Icons.login_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            _StepCard(
              number: 3,
              title: 'Click Authorize',
              description: 'Grant the app permission to generate your API key. '
                  'Your key will appear on screen after authorization.',
              icon: Icons.verified_user_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            _StepCard(
              number: 4,
              title: 'Copy Your API Key',
              description: 'Copy the sk-... key that is shown.\n'
                  'It looks like: sk-1s0qzwDE6Ww...',
              icon: Icons.content_copy_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            _StepCard(
              number: 5,
              title: 'Paste in Settings',
              description: 'Go back → Profile → Settings → AI Teacher section.\n'
                  'Paste your API key in the "API Key" field.',
              icon: Icons.settings_applications_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            _StepCard(
              number: 6,
              title: 'Tap "Test Connection"',
              description: 'After pasting, tap "Test Connection" to verify.\n'
                  'If successful, you\'re all set! Start chatting in AI Teacher.',
              icon: Icons.wifi_find_rounded,
              isDark: isDark,
            ),

            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withValues(alpha: 0.1), AppColors.primary.withValues(alpha: 0.04)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Default Settings',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoRow('Base URL', 'https://api.chatanywhere.tech/v1'),
                  _infoRow('Model (free)', 'gpt-4o-mini — 200次/日'),
                  _infoRow('Alt Model', 'deepseek-v3 — 30次/日'),
                  _infoRow('Alt Model', 'gpt-5-mini — 5次/日'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Center(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 4),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int number;
  final String title;
  final String description;
  final String? code;
  final IconData icon;
  final bool isDark;

  const _StepCard({
    required this.number,
    required this.title,
    required this.description,
    this.code,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$number',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(title,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(description,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.5)),
                if (code != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                    ),
                    child: SelectableText(
                      code!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
