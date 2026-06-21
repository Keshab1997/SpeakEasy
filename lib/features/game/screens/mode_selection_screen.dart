import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/game/game_provider.dart';
import '../../../services/game_service.dart';
import 'question_screen.dart';

class ModeSelectionScreen extends ConsumerWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Mode', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose a game mode', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...GameMode.values.map((mode) => _ModeTile(
              mode: mode,
              onTap: () {
                ref.read(gameProvider.notifier).loadQuestions(
                  mode: mode,
                  limit: mode == GameMode.practice ? 10 : 20,
                );
                Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestionScreen()));
              },
            )),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final GameMode mode;
  final VoidCallback onTap;

  const _ModeTile({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _getModeConfig();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: config.colors),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(config.icon, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(config.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(config.description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }

  _ModeConfig _getModeConfig() {
    switch (mode) {
      case GameMode.practice:
        return _ModeConfig(
          title: 'Practice',
          description: '10 questions, no time limit',
          icon: Icons.school,
          colors: [Colors.blue, Colors.lightBlue],
        );
      case GameMode.quiz:
        return _ModeConfig(
          title: 'Quiz',
          description: '20 questions, test your knowledge',
          icon: Icons.quiz,
          colors: [Colors.purple, Colors.deepPurple],
        );
      case GameMode.challenge:
        return _ModeConfig(
          title: 'Challenge',
          description: '20 hard questions, no mercy',
          icon: Icons.bolt,
          colors: [Colors.orange, Colors.deepOrange],
        );
      case GameMode.timed:
        return _ModeConfig(
          title: 'Timed',
          description: '60 seconds, as many as you can',
          icon: Icons.timer,
          colors: [Colors.red, Colors.redAccent],
        );
      case GameMode.endless:
        return _ModeConfig(
          title: 'Endless',
          description: 'Keep going until you miss',
              icon: Icons.all_inclusive,
          colors: [Colors.teal, Colors.cyan],
        );
    }
  }
}

class _ModeConfig {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> colors;

  _ModeConfig({
    required this.title,
    required this.description,
    required this.icon,
    required this.colors,
  });
}