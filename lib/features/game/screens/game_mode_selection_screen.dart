import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/game_mode_service.dart';
import '../../../providers/game/game_provider.dart';
import '../../../providers/game/timer_provider.dart';
import '../../../providers/game/score_provider.dart';
import '../../../providers/game/sound_provider.dart';
import 'mode_game_screen.dart';
import 'modes/word_match_mode.dart';
import 'modes/verb_learning_mode.dart';

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
            // Word Match — Duolingo-style game
            _buildWordMatchCard(context, ref),
            const SizedBox(height: 8),
            _buildVerbLearningCard(context, ref),
            const SizedBox(height: 8),
            ...GameModeType.values.map((modeType) {
              final config = GameModeConfig.fromType(modeType);
              return _ModeCard(
                config: config,
                onTap: () {
                  ref.read(gameProvider.notifier).reset();
                  ref.read(timerProvider.notifier).resetTimer();
                  ref.read(scoreProvider.notifier).resetScore();
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

  Widget _buildWordMatchCard(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        ref.read(soundProvider.notifier).playButtonTap();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WordMatchModeScreen()),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.3),
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
              child: const Icon(Icons.compare_arrows_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Word Match',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Match Bengali words with their English translations',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.compare_arrows_rounded, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      const Text('6 pairs', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(width: 12),
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      const Text('Score + Streak', style: TextStyle(color: Colors.white70, fontSize: 12)),
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

  Widget _buildVerbLearningCard(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        ref.read(soundProvider.notifier).playButtonTap();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VerbLearningModeScreen()),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF58CC02), Color(0xFF3DA302)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF58CC02).withOpacity(0.3),
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
              child: const Icon(Icons.directions_run_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Verb Learning',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Learn verb forms with Bengali meanings & examples',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.abc_rounded, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      const Text('V1-V5 Forms', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(width: 12),
                      const Icon(Icons.quiz_rounded, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      const Text('Quick Quiz', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
}

class _ModeCard extends StatelessWidget {
  final GameModeConfig config;
  final VoidCallback onTap;

  const _ModeCard({required this.config, required this.onTap});

  @override
  Widget build(BuildContext context) {
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