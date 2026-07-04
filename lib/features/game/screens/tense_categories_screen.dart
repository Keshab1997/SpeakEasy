import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/game/sound_provider.dart';
import '../../../providers/game/game_provider.dart';
import 'question_screen.dart';
import 'grammar_rules_screen.dart';

// ─── Tense Info Model ────────────────────────────────────────────────────────

class _TenseInfo {
  final String id;
  final String name;
  final String description;
  final String example;
  final String rulesAssetPath;

  _TenseInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.example,
    required this.rulesAssetPath,
  });
}

// ─── Main Screen ─────────────────────────────────────────────────────────────

class TenseCategoriesScreen extends ConsumerWidget {
  const TenseCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tense Categories', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Banner
            _buildInfoBanner(context),

            const SizedBox(height: 20),

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
                  rulesAssetPath: 'assets/json/game/rules/01_present_indefinite_rules.json',
                ),
                _TenseInfo(
                  id: 'present_continuous',
                  name: 'Present Continuous',
                  description: 'Actions happening now',
                  example: 'I am eating breakfast now.',
                  rulesAssetPath: 'assets/json/game/rules/02_present_continuous_rules.json',
                ),
                _TenseInfo(
                  id: 'present_perfect',
                  name: 'Present Perfect',
                  description: 'Completed actions with present relevance',
                  example: 'I have eaten breakfast.',
                  rulesAssetPath: 'assets/json/game/rules/03_present_perfect_rules.json',
                ),
                _TenseInfo(
                  id: 'present_perfect_continuous',
                  name: 'Present Perfect Continuous',
                  description: 'Actions started in past, continuing',
                  example: 'I have been eating for 10 minutes.',
                  rulesAssetPath: 'assets/json/game/rules/04_present_perfect_continuous_rules.json',
                ),
              ],
              ref: ref,
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
                  rulesAssetPath: 'assets/json/game/rules/05_past_indefinite_rules.json',
                ),
                _TenseInfo(
                  id: 'past_continuous',
                  name: 'Past Continuous',
                  description: 'Ongoing actions in the past',
                  example: 'I was eating breakfast at 8 AM.',
                  rulesAssetPath: 'assets/json/game/rules/06_past_continuous_rules.json',
                ),
                _TenseInfo(
                  id: 'past_perfect',
                  name: 'Past Perfect',
                  description: 'Actions before another past action',
                  example: 'I had eaten before he arrived.',
                  rulesAssetPath: 'assets/json/game/rules/07_past_perfect_rules.json',
                ),
                _TenseInfo(
                  id: 'past_perfect_continuous',
                  name: 'Past Perfect Continuous',
                  description: 'Ongoing actions before past events',
                  example: 'I had been eating for an hour.',
                  rulesAssetPath: 'assets/json/game/rules/08_past_perfect_continuous_rules.json',
                ),
              ],
              ref: ref,
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
                  rulesAssetPath: 'assets/json/game/rules/09_future_indefinite_rules.json',
                ),
                _TenseInfo(
                  id: 'future_continuous',
                  name: 'Future Continuous',
                  description: 'Ongoing future actions',
                  example: 'I will be eating at 8 AM.',
                  rulesAssetPath: 'assets/json/game/rules/10_future_continuous_rules.json',
                ),
                _TenseInfo(
                  id: 'future_perfect',
                  name: 'Future Perfect',
                  description: 'Actions that will be completed',
                  example: 'I will have eaten by 9 AM.',
                  rulesAssetPath: 'assets/json/game/rules/11_future_perfect_rules.json',
                ),
                _TenseInfo(
                  id: 'future_perfect_continuous',
                  name: 'Future Perfect Continuous',
                  description: 'Ongoing actions up to a future point',
                  example: 'I will have been eating for an hour.',
                  rulesAssetPath: 'assets/json/game/rules/12_future_perfect_continuous_rules.json',
                ),
              ],
              ref: ref,
            ),

            const SizedBox(height: 24),

            // Special Categories
            _SpecialCategoriesSection(
              onCategoryTap: (categoryId, categoryName, rulesPath) {
                ref.read(soundProvider.notifier).playButtonTap();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GrammarRulesScreen(
                      tenseId: categoryId,
                      tenseName: categoryName,
                      rulesAssetPath: rulesPath,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.15),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tips_and_updates, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 প্রথমে Rules পড়ো, তারপর Practice করো!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'প্রতিটি tense-এর নিচে "Rules দেখুন" বা "Practice" বাটনে চাপ দাও।',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tense Section ───────────────────────────────────────────────────────────

class _TenseSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_TenseInfo> tenses;
  final WidgetRef ref;

  const _TenseSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.tenses,
    required this.ref,
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
              ref: ref,
            )),
      ],
    );
  }
}

// ─── Tense Card ──────────────────────────────────────────────────────────────

class _TenseCard extends StatelessWidget {
  final _TenseInfo tense;
  final Color color;
  final WidgetRef ref;

  const _TenseCard({
    required this.tense,
    required this.color,
    required this.ref,
  });

  void _openRules(BuildContext context) {
    ref.read(soundProvider.notifier).playButtonTap();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GrammarRulesScreen(
          tenseId: tense.id,
          tenseName: tense.name,
          rulesAssetPath: tense.rulesAssetPath,
        ),
      ),
    );
  }

  void _startPractice(BuildContext context) {
    ref.read(soundProvider.notifier).playButtonTap();
    // tense.id is the snake_case key; GameService normalises it to the JSON
    // tenseType label automatically.
    ref.read(gameProvider.notifier).loadQuestions(
      tenseType: tense.id,
      limit: 15,
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestionScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tense.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tense.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.format_quote, color: Colors.white70, size: 14),
                      const SizedBox(width: 6),
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

          // ── Action Buttons ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Rules Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openRules(context),
                    icon: Icon(Icons.menu_book_rounded, size: 16, color: color),
                    label: Text(
                      'Rules দেখুন',
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: color.withOpacity(0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Practice Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _startPractice(context),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Practice',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Special Categories ──────────────────────────────────────────────────────

class _SpecialCategoriesSection extends StatelessWidget {
  final void Function(String categoryId, String categoryName, String rulesPath) onCategoryTap;

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
                gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
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
                description: 'Compare tenses side by side',
                icon: Icons.compare,
                color: Colors.orange,
                onTap: () => onCategoryTap(
                  'comparison',
                  'Tense Comparison',
                  'assets/json/game/rules/13_comparison_rules.json',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SpecialCategoryCard(
                title: 'Special Usage',
                description: 'Common mistakes & tips',
                icon: Icons.warning,
                color: Colors.deepOrange,
                onTap: () => onCategoryTap(
                  'special_usage',
                  'Special Usage & Common Mistakes',
                  'assets/json/game/rules/14_special_usage_rules.json',
                ),
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