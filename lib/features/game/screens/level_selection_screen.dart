import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/game/level_model.dart';
import '../../../providers/game/xp_provider.dart';
import '../../../providers/game/sound_provider.dart';
import 'category_selection_screen.dart';

class LevelSelectionScreen extends ConsumerWidget {
  const LevelSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xpState = ref.watch(xpProvider);
    final theme = Theme.of(context);

    // Load levels from JSON
    final levels = _loadLevels();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Level', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose your level', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...levels.map((level) => _LevelCard(
              level: level,
              currentXP: xpState.currentXP,
              onTap: () {
                ref.read(soundProvider.notifier).playButtonTap();
                if (level.unlocked) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategorySelectionScreen(level: level),
                    ),
                  );
                }
              },
            )),
          ],
        ),
      ),
    );
  }

  List<LevelModel> _loadLevels() {
    // In production, load from repository
    // For now, return hardcoded levels matching JSON
    return [
      LevelModel(
        id: 'beginner',
        name: 'Beginner',
        description: 'Master the basics of English tenses',
        order: 1,
        unlocked: true,
        completed: false,
        totalStars: 0,
        requiredXP: 0,
        categories: [
          TenseCategory(
            id: 'present_tenses',
            name: 'Present Tenses',
            description: 'Simple Present, Present Continuous, Present Perfect, Present Perfect Continuous',
            questionCount: 20,
            unlocked: true,
            completed: false,
            stars: 0,
          ),
          TenseCategory(
            id: 'past_tenses',
            name: 'Past Tenses',
            description: 'Simple Past, Past Continuous, Past Perfect, Past Perfect Continuous',
            questionCount: 20,
            unlocked: false,
            completed: false,
            stars: 0,
          ),
          TenseCategory(
            id: 'future_tenses',
            name: 'Future Tenses',
            description: 'Simple Future, Future Continuous, Future Perfect, Future Perfect Continuous',
            questionCount: 20,
            unlocked: false,
            completed: false,
            stars: 0,
          ),
          TenseCategory(
            id: 'comparison',
            name: 'Comparison',
            description: 'Compare and contrast different tenses',
            questionCount: 15,
            unlocked: false,
            completed: false,
            stars: 0,
          ),
          TenseCategory(
            id: 'special_usage',
            name: 'Special Usage',
            description: 'Special cases and common mistakes',
            questionCount: 15,
            unlocked: false,
            completed: false,
            stars: 0,
          ),
          TenseCategory(
            id: 'boss_level',
            name: 'Boss Level',
            description: 'Ultimate test of all beginner tenses',
            questionCount: 25,
            unlocked: false,
            completed: false,
            stars: 0,
          ),
        ],
      ),
      LevelModel(
        id: 'intermediate',
        name: 'Intermediate',
        description: 'Advance your tense mastery',
        order: 2,
        unlocked: false,
        completed: false,
        totalStars: 0,
        requiredXP: 500,
        categories: [],
      ),
      LevelModel(
        id: 'advanced',
        name: 'Advanced',
        description: 'Master complex tense structures',
        order: 3,
        unlocked: false,
        completed: false,
        totalStars: 0,
        requiredXP: 1500,
        categories: [],
      ),
    ];
  }
}

class _LevelCard extends StatelessWidget {
  final LevelModel level;
  final int currentXP;
  final VoidCallback onTap;

  const _LevelCard({
    required this.level,
    required this.currentXP,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnlocked = level.unlocked;
    final isCompleted = level.completed;
    final canUnlock = currentXP >= level.requiredXP;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isUnlocked
              ? LinearGradient(colors: _getLevelColors(level.id))
              : null,
          color: isUnlocked ? null : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: _getLevelColors(level.id).first.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Level Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: isUnlocked ? LinearGradient(colors: _getLevelColors(level.id)) : null,
                color: isUnlocked ? null : Colors.grey[400],
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getLevelIcon(level.id),
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            // Level Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        level.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isUnlocked ? null : Colors.grey[600],
                        ),
                      ),
                      if (isCompleted) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    level.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isUnlocked ? null : Colors.grey[500],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (!isUnlocked && !canUnlock)
                    Text(
                      'Requires ${level.requiredXP} XP',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (isUnlocked && !isCompleted)
                    Row(
                      children: [
                        ...List.generate(3, (index) {
                          return Icon(
                            index < (level.totalStars / 2).round() ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          '${level.categories.length} categories',
                          style: theme.textTheme.bodySmall,
                        ),
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
                size: 18,
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

  IconData _getLevelIcon(String levelId) {
    switch (levelId) {
      case 'beginner':
        return Icons.school;
      case 'intermediate':
        return Icons.trending_up;
      case 'advanced':
        return Icons.emoji_events;
      default:
        return Icons.quiz;
    }
  }
}