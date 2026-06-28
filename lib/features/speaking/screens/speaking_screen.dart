import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'pronunciation_screen.dart';

/// Mode enum for the different speaking practice types
enum SpeakingMode {
  readAloud,
  listenAndRepeat,
  banglaToEnglish,
  freeSpeaking,
}

class SpeakingScreen extends StatelessWidget {
  const SpeakingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final practiceModes = <Map<String, dynamic>>[
      {
        'title': 'Read Aloud',
        'subtitle': 'Read English sentences aloud and check your accuracy.',
        'icon': Icons.record_voice_over_rounded,
        'badge': 'Popular',
        'color': AppColors.primary,
        'bgGradient': AppColors.primaryGradient,
        'mode': SpeakingMode.readAloud,
      },
      {
        'title': 'Listen & Repeat',
        'subtitle': 'Hear native pronunciation and repeat after it.',
        'icon': Icons.hearing_rounded,
        'badge': 'Recommended',
        'color': AppColors.secondary,
        'bgGradient': AppColors.secondaryGradient,
        'mode': SpeakingMode.listenAndRepeat,
      },
      {
        'title': 'Bangla → English',
        'subtitle': 'See Bangla text, speak the English translation.',
        'icon': Icons.translate_rounded,
        'badge': 'New',
        'color': AppColors.accent,
        'bgGradient': AppColors.accentGradient,
        'mode': SpeakingMode.banglaToEnglish,
      },
      {
        'title': 'Free Speaking',
        'subtitle': 'Open microphone practice with live transcription.',
        'icon': Icons.mic_none_rounded,
        'badge': '',
        'color': Colors.purple,
        'bgGradient': AppColors.purpleGradient,
        'mode': SpeakingMode.freeSpeaking,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Speaking Practice',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header stats summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(context, 'Read Aloud', '🎯', Icons.record_voice_over_rounded, AppColors.primary),
                  Container(height: 30, width: 1, color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  _buildStatItem(context, 'Listening', '🎧', Icons.hearing_rounded, AppColors.secondary),
                  Container(height: 30, width: 1, color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  _buildStatItem(context, 'Speaking', '🎤', Icons.mic_rounded, Colors.orange),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Choose Practice Mode',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: practiceModes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final mode = practiceModes[index];
                final grad = mode['bgGradient'] as List<Color>;
                final modeBadge = mode['badge'] as String;
                final m = mode['mode'] as SpeakingMode;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PronunciationScreen(mode: m),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: grad),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            mode['icon'] as IconData,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      mode['title'] as String,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (modeBadge.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: grad[0].withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        modeBadge,
                                        style: TextStyle(
                                          color: grad[0],
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mode['subtitle'] as String,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      BuildContext context, String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
