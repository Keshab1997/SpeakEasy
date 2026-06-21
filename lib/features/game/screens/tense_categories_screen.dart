import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/game/sound_provider.dart';
import '../../../providers/game/game_provider.dart';
import 'question_screen.dart';

class TenseCategoriesScreen extends ConsumerWidget {
  const TenseCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tense Categories', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Present Tenses Section
            _TenseSection(
              title: 'Present Tenses',
              icon: Icons.today,
              color: Colors.green,
              tenses: [
                _TenseInfo(
                  id: 'present_indefinite',
                  name: 'Present Indefinite',
                  description: 'Simple Present - habits, routines, general truths',
                  example: 'I eat breakfast every day.',
                ),
                _TenseInfo(
                  id: 'present_continuous',
                  name: 'Present Continuous',
                  description: 'Actions happening now',
                  example: 'I am eating breakfast now.',
                ),
                _TenseInfo(
                  id: 'present_perfect',
                  name: 'Present Perfect',
                  description: 'Completed actions with present relevance',
                  example: 'I have eaten breakfast.',
                ),
                _TenseInfo(
                  id: 'present_perfect_continuous',
                  name: 'Present Perfect Continuous',
                  description: 'Actions started in past, continuing',
                  example: 'I have been eating for 10 minutes.',
                ),
              ],
              onTenseTap: (tenseId) {
                ref.read(soundProvider.notifier).playButtonTap();
                ref.read(gameProvider.notifier).loadQuestions(
                  tenseType: tenseId,
                  limit: 15,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuestionScreen()),
                );
              },
            ),

            const SizedBox(height: 24),

            // Past Tenses Section
            _TenseSection(
              title: 'Past Tenses',
              icon: Icons.history,
              color: Colors.blue,
              tenses: [
                _TenseInfo(
                  id: 'past_indefinite',
                  name: 'Past Indefinite',
                  description: 'Simple Past - completed past actions',
                  example: 'I ate breakfast yesterday.',
                ),
                _TenseInfo(
                  id: 'past_continuous',
                  name: 'Past Continuous',
                  description: 'Ongoing actions in the past',
                  example: 'I was eating breakfast at 8 AM.',
                ),
                _TenseInfo(
                  id: 'past_perfect',
                  name: 'Past Perfect',
                  description: 'Actions before another past action',
                  example: 'I had eaten before he arrived.',
                ),
                _TenseInfo(
                  id: 'past_perfect_continuous',
                  name: 'Past Perfect Continuous',
                  description: 'Ongoing actions before past events',
                  example: 'I had been eating for an hour.',
                ),
              ],
              onTenseTap: (tenseId) {
                ref.read(soundProvider.notifier).playButtonTap();
                ref.read(gameProvider.notifier).loadQuestions(
                  tenseType: tenseId,
                  limit: 15,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuestionScreen()),
                );
              },
            ),

            const SizedBox(height: 24),

            // Future Tenses Section
            _TenseSection(
              title: 'Future Tenses',
              icon: Icons.schedule,
              color: Colors.purple,
              tenses: [
                _TenseInfo(
                  id: 'future_indefinite',
                  name: 'Future Indefinite',
                  description: 'Simple Future - future actions and predictions',
                  example: 'I will eat breakfast tomorrow.',
                ),
                _TenseInfo(
                  id: 'future_continuous',
                  name: 'Future Continuous',
                  description: 'Ongoing future actions',
                  example: 'I will be eating at 8 AM.',
                ),
                _TenseInfo(
                  id: 'future_perfect',
                  name: 'Future Perfect',
                  description: 'Actions that will be completed',
                  example: 'I will have eaten by 9 AM.',
                ),
                _TenseInfo(
                  id: 'future_perfect_continuous',
                  name: 'Future Perfect Continuous',
                  description: 'Ongoing actions up to a future point',
                  example: 'I will have been eating for an hour.',
                ),
              ],
              onTenseTap: (tenseId) {
                ref.read(soundProvider.notifier).playButtonTap();
                ref.read(gameProvider.notifier).loadQuestions(
                  tenseType: tenseId,
                  limit: 15,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuestionScreen()),
                );
              },
            ),

            const SizedBox(height: 24),

            // Special Categories
            _SpecialCategoriesSection(
              onCategoryTap: (categoryId) {
                ref.read(soundProvider.notifier).playButtonTap();
                ref.read(gameProvider.notifier).loadQuestions(
                  tenseType: categoryId,
                  limit: 15,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuestionScreen()),
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _TenseSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_TenseInfo> tenses;
  final Function(String) onTenseTap;

  const _TenseSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.tenses,
    required this.onTenseTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...tenses.map((tense) => _TenseCard(
          tense: tense,
          color: color,
          onTap: () => onTenseTap(tense.id),
        )),
      ],
    );
  }
}

class _TenseCard extends StatelessWidget {
  final _TenseInfo tense;
  final Color color;
  final VoidCallback onTap;

  const _TenseCard({
    required this.tense,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tense.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tense.description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.format_quote,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tense.example,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
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

class _SpecialCategoriesSection extends StatelessWidget {
  final Function(String) onCategoryTap;

  const _SpecialCategoriesSection({required this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.star, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Special Categories',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SpecialCategoryCard(
                title: 'Comparison',
                description: 'Compare tenses',
                icon: Icons.compare,
                color: Colors.orange,
                onTap: () => onCategoryTap('comparison'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SpecialCategoryCard(
                title: 'Special Usage',
                description: 'Common mistakes',
                icon: Icons.warning,
                color: Colors.deepOrange,
                onTap: () => onCategoryTap('special_usage'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SpecialCategoryCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SpecialCategoryCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TenseInfo {
  final String id;
  final String name;
  final String description;
  final String example;

  _TenseInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.example,
  });
}