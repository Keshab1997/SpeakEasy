import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/game/level_model.dart';
import '../../../providers/game/sound_provider.dart';
import '../../../providers/game/game_provider.dart';
import 'question_screen.dart';
import 'boss_battle_screen.dart';

class CategorySelectionScreen extends ConsumerWidget {
  final LevelModel level;

  const CategorySelectionScreen({super.key, required this.level});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(level.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Level Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _getLevelColors(level.id)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    level.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${level.totalStars} / ${level.categories.length * 15}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.quiz, color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${level.categories.fold(0, (sum, c) => sum + c.questionCount)} questions',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Categories
            Text('Categories', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...level.categories.map((category) => _CategoryCard(
              category: category,
              levelId: level.id,
              onTap: () {
                ref.read(soundProvider.notifier).playButtonTap();
                if (category.unlocked) {
                  // Load questions for this category and navigate
                  ref.read(gameProvider.notifier).loadQuestions(
                    tenseType: category.name,
                    limit: category.questionCount,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QuestionScreen()),
                  );
                }
              },
            )),

            const SizedBox(height: 24),

            // Boss Level Button
            if (level.categories.any((c) => c.id == 'boss_level'))
              _BossLevelCard(
                category: level.categories.firstWhere((c) => c.id == 'boss_level'),
                levelId: level.id,
                onTap: () {
                  ref.read(soundProvider.notifier).playButtonTap();
                  if (level.categories.firstWhere((c) => c.id == 'boss_level').unlocked) {
                    ref.read(gameProvider.notifier).loadQuestions(
                      difficulty: 'hard',
                      limit: 25,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BossBattleScreen()),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  List<Color> _getLevelColors(String levelId) {
    switch (levelId) {
      case 'beginner':
        return [Colors.green, Colors.lightGreen];
      case 'intermediate':
        return [Colors.blue, Colors.lightBlue];
      case 'advanced':
        return [Colors.purple, Colors.deepPurple];
      default:
        return [AppColors.primary, AppColors.primary.withOpacity(0.8)];
    }
  }
}

class _CategoryCard extends StatelessWidget {
  final TenseCategory category;
  final String levelId;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.levelId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnlocked = category.unlocked;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isUnlocked
              ? LinearGradient(colors: _getCategoryColors())
              : null,
          color: isUnlocked ? null : Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked ? Colors.transparent : Colors.grey[400]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Category Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: isUnlocked ? LinearGradient(colors: _getCategoryColors()) : null,
                color: isUnlocked ? null : Colors.grey[400],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(),
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // Category Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        category.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isUnlocked ? null : Colors.grey[600],
                        ),
                      ),
                      if (category.completed) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isUnlocked ? null : Colors.grey[500],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (isUnlocked) ...[
                        ...List.generate(3, (index) {
                          return Icon(
                            index < (category.stars / 2).round() ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 14,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          '${category.questionCount} questions',
                          style: theme.textTheme.bodySmall,
                        ),
                      ] else ...[
                        const Icon(Icons.lock, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Locked',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Arrow
            if (isUnlocked)
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white70,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  List<Color> _getCategoryColors() {
    return [AppColors.primary, AppColors.primary.withOpacity(0.8)];
  }

  IconData _getCategoryIcon() {
    return Icons.quiz;
  }
}

class _BossLevelCard extends StatelessWidget {
  final TenseCategory category;
  final String levelId;
  final VoidCallback onTap;

  const _BossLevelCard({
    required this.category,
    required this.levelId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlocked = category.unlocked;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: isUnlocked
              ? const LinearGradient(colors: [Colors.red, Colors.deepOrange])
              : null,
          color: isUnlocked ? null : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
      child: Row(
        children: [
          // Boss Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: isUnlocked
                  ? const LinearGradient(colors: [Colors.red, Colors.deepOrange])
                  : null,
              color: isUnlocked ? null : Colors.grey[400],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(width: 20),
          // Boss Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (category.completed) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  category.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (isUnlocked) ...[
                      ...List.generate(3, (index) {
                        return Icon(
                          index < (category.stars / 2).round() ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                      const SizedBox(width: 8),
                      Text(
                        '${category.questionCount} questions',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ] else ...[
                      const Icon(Icons.lock, color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        'Complete all categories to unlock',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Arrow
          if (isUnlocked)
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 20,
            ),
        ],
      ),
    ),
  );
}
}