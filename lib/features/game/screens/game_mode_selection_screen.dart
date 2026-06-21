import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/game_mode_service.dart';
import '../../../providers/game/sound_provider.dart';
import 'mode_game_screen.dart';

class GameModeSelectionScreen extends ConsumerWidget {
  const GameModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Modes', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose a game mode', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...GameModeType.values.map((modeType) {
              final config = GameModeConfig.fromType(modeType);
              return _ModeCard(
                config: config,
                onTap: () {
                  ref.read(soundProvider.notifier).playButtonTap();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ModeGameScreen(modeType: modeType),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final GameModeConfig config;
  final VoidCallback onTap;

  const _ModeCard({required this.config, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _getGradientColors(config.type)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _getGradientColors(config.type).first.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(config.icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    config.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (config.hasTimer) ...[
                        const Icon(Icons.timer, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text('${config.timeLimit}s', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 12),
                      ],
                      if (config.hasLives) ...[
                        const Icon(Icons.favorite, color: Colors.red, size: 14),
                        const SizedBox(width: 4),
                        Text('${config.initialLives}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 12),
                      ],
                      if (config.hasHints) ...[
                        const Icon(Icons.lightbulb, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text('${config.hintCount}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }

  List<Color> _getGradientColors(GameModeType type) {
    switch (type) {
      case GameModeType.fillInBlank:
        return [Colors.blue, Colors.lightBlue];
      case GameModeType.chooseCorrectTense:
        return [Colors.green, Colors.lightGreen];
      case GameModeType.sentenceBuilder:
        return [Colors.orange, Colors.deepOrange];
      case GameModeType.errorDetection:
        return [Colors.red, Colors.redAccent];
      case GameModeType.translationChallenge:
        return [Colors.purple, Colors.deepPurple];
      case GameModeType.speedQuiz:
        return [Colors.teal, Colors.cyan];
    }
  }
}