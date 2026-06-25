import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/game/sound_provider.dart';
import '../../../services/hive_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late int _timerSeconds;
  late int _questionCount;
  late String _difficulty;

  @override
  void initState() {
    super.initState();
    _timerSeconds = HiveService.getGameTimerSeconds();
    _questionCount = HiveService.getGameQuestionCount();
    _difficulty = HiveService.getGameDifficulty();
  }

  String _formatTimer(int s) {
    if (s <= 0) return 'No timer';
    final m = s ~/ 60;
    final r = s % 60;
    return m > 0 ? '$m:${r.toString().padLeft(2, '0')}' : '${r}s';
  }

  String _difficultyLabel(String d) {
    switch (d) {
      case 'easy':
        return 'Easy';
      case 'intermediate':
        return 'Intermediate';
      case 'hard':
        return 'Hard';
      default:
        return 'Easy';
    }
  }

  Future<void> _pickTimer() async {
    const options = [0, 30, 45, 60, 90, 120];
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Default Timer'),
        children: options.map((s) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, s),
            child: Row(
              children: [
                Icon(
                  s == _timerSeconds ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(_formatTimer(s)),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (selected != null && selected != _timerSeconds) {
      await HiveService.setGameTimerSeconds(selected);
      setState(() => _timerSeconds = selected);
    }
  }

  Future<void> _pickQuestionCount() async {
    const options = [5, 10, 15, 20, 25];
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Questions Per Game'),
        children: options.map((c) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, c),
            child: Row(
              children: [
                Icon(
                  c == _questionCount ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text('$c questions'),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (selected != null && selected != _questionCount) {
      await HiveService.setGameQuestionCount(selected);
      setState(() => _questionCount = selected);
    }
  }

  Future<void> _pickDifficulty() async {
    const options = ['easy', 'intermediate', 'hard'];
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Default Difficulty'),
        children: options.map((d) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, d),
            child: Row(
              children: [
                Icon(
                  d == _difficulty ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(_difficultyLabel(d)),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (selected != null && selected != _difficulty) {
      await HiveService.setGameDifficulty(selected);
      setState(() => _difficulty = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final soundState = ref.watch(soundProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.settings, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Game Preferences',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Customize your gaming experience',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Sound Section
          _SettingsSection(
            title: 'Sound',
            children: [
              SwitchListTile(
                title: const Text('Sound Effects'),
                subtitle: const Text('Enable game sounds & music'),
                value: !soundState.isMuted,
                onChanged: (value) {
                  ref.read(soundProvider.notifier).setMuted(!value);
                  if (value) ref.read(soundProvider.notifier).playButtonTap();
                },
                secondary: Icon(soundState.isMuted ? Icons.volume_off : Icons.volume_up, color: AppColors.primary),
              ),
              if (!soundState.isMuted)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.volume_down, size: 20),
                      Expanded(
                        child: Slider(
                          value: soundState.volume,
                          min: 0.0,
                          max: 1.0,
                          onChanged: (value) => ref.read(soundProvider.notifier).setVolume(value),
                          activeColor: AppColors.primary,
                        ),
                      ),
                      const Icon(Icons.volume_up, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        '${(soundState.volume * 100).toInt()}%',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Game Settings Section
          _SettingsSection(
            title: 'Game Preferences',
            children: [
              ListTile(
                leading: const Icon(Icons.timer, color: AppColors.primary),
                title: const Text('Default Timer'),
                subtitle: Text(_formatTimer(_timerSeconds)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickTimer,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.quiz, color: AppColors.primary),
                title: const Text('Questions Per Game'),
                subtitle: Text('$_questionCount questions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickQuestionCount,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.tune, color: AppColors.primary),
                title: const Text('Default Difficulty'),
                subtitle: Text(_difficultyLabel(_difficulty)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickDifficulty,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Tip Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: Colors.orange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: For general app settings like theme, notifications, and account, use the main Settings from your profile.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
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
