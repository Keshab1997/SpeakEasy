import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../home/widgets/spoken_rules_screen.dart';
import '../../vocabulary/screens/vocabulary_screen.dart';
import '../../verb_forms/screens/verb_forms_screen.dart';
import '../../grammar/screens/grammar_list_screen.dart';

class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_stories_rounded, color: AppColors.primary, size: 26),
            SizedBox(width: 8),
            Text('Learning', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('What do you want to learn?',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Explore lessons, vocabulary, and grammar rules.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
              const SizedBox(height: 24),

              _buildLearningCard(
                context: context,
                title: 'Spoken Rules',
                subtitle: 'Master spoken English rules and expressions',
                icon: Icons.auto_stories_rounded,
                gradient: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpokenRulesScreen())),
              ),
              const SizedBox(height: 16),
              _buildLearningCard(
                context: context,
                title: 'Vocabulary',
                subtitle: 'Build your word bank with categorized lessons',
                icon: Icons.menu_book_rounded,
                gradient: AppColors.primaryGradient,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VocabularyScreen())),
              ),
              const SizedBox(height: 16),
              _buildLearningCard(
                context: context,
                title: 'Verb Forms',
                subtitle: 'Master V1, V2, V3, V4, V5 forms of English verbs',
                icon: Icons.transform_rounded,
                gradient: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerbFormsScreen())),
              ),
              const SizedBox(height: 16),
              _buildLearningCard(
                context: context,
                title: 'Grammar',
                subtitle: 'Understand English grammar from beginner to advanced',
                icon: Icons.edit_note_rounded,
                gradient: AppColors.purpleGradient,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GrammarListScreen())),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLearningCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: Colors.white, size: 36),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
