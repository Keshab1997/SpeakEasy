import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/game/sound_provider.dart';
import '../../../services/sound_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final soundService = ref.watch(soundServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          _SettingsSection(
            title: 'Appearance',
            children: [
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Enable dark theme'),
                value: themeState.isDark,
                onChanged: (value) => ref.read(themeProvider.notifier).setThemeMode(
                  value ? ThemeMode.dark : ThemeMode.light,
                ),
                secondary: Icon(themeState.isDark ? Icons.dark_mode : Icons.light_mode, color: AppColors.primary),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Sound Section
          _SettingsSection(
            title: 'Sound',
            children: [
              SwitchListTile(
                title: const Text('Sound Effects'),
                subtitle: const Text('Enable game sounds'),
                value: !soundService.isMuted,
                onChanged: (value) {
                  soundService.setMuted(!value);
                  if (value) soundService.playButtonTap();
                },
                secondary: Icon(soundService.isMuted ? Icons.volume_off : Icons.volume_up, color: AppColors.primary),
              ),
              if (!soundService.isMuted)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.volume_down, size: 20),
                      Expanded(
                        child: Slider(
                          value: soundService.volume,
                          onChanged: (value) => soundService.setVolume(value),
                          activeColor: AppColors.primary,
                        ),
                      ),
                      const Icon(Icons.volume_up, size: 20),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Game Settings Section
          _SettingsSection(
            title: 'Game Settings',
            children: [
              ListTile(
                leading: const Icon(Icons.timer, color: AppColors.primary),
                title: const Text('Default Timer'),
                subtitle: const Text('60 seconds'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Show timer selection dialog
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.quiz, color: AppColors.primary),
                title: const Text('Questions Per Game'),
                subtitle: const Text('10 questions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Show question count selection dialog
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.tune, color: AppColors.primary),
                title: const Text('Default Difficulty'),
                subtitle: const Text('Beginner'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Show difficulty selection dialog
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Account Section
          _SettingsSection(
            title: 'Account',
            children: [
              ListTile(
                leading: const Icon(Icons.sync, color: AppColors.primary),
                title: const Text('Sync Data'),
                subtitle: const Text('Sync with Firebase'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement sync
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sync feature coming soon!')),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: AppColors.error),
                title: const Text('Clear Local Data'),
                subtitle: const Text('Delete all cached data'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showClearDataDialog(context);
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // About Section
          _SettingsSection(
            title: 'About',
            children: [
              ListTile(
                leading: const Icon(Icons.info, color: AppColors.primary),
                title: const Text('Version'),
                subtitle: const Text('1.0.0'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.help, color: AppColors.primary),
                title: const Text('Help & Support'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Open help page
                },
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Reset Progress Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showResetProgressDialog(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Reset All Progress', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Local Data?'),
        content: const Text('This will delete all cached data. Your progress will be preserved if synced.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Local data cleared')),
              );
            },
            child: const Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showResetProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Progress?'),
        content: const Text('This will permanently delete all your progress, XP, coins, and achievements. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Progress reset')),
              );
            },
            child: const Text('Reset', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          ...children,
        ],
      ),
    );
  }
}