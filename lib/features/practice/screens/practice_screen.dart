import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../vocabulary/screens/vocabulary_test_screen.dart';
import '../../grammar/screens/grammar_test_list_screen.dart';
import '../../conversation/screens/conversation_screen.dart';
import '../../listening/screens/listening_screen.dart';
import '../../speaking/screens/speaking_screen.dart';
import '../../translator/screens/banglish_translator_screen.dart';
import '../../verb_forms/screens/verb_form_practice_screen.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  static const _categories = [
    _Category(
      title: 'Vocab Test',
      subtitle: 'Test your vocabulary',
      icon: Icons.quiz_rounded,
      gradient: AppColors.accentGradient,
      target: _Target.vocabTest,
    ),
    _Category(
      title: 'Grammar Test',
      subtitle: 'Practice with tests',
      icon: Icons.quiz_rounded,
      gradient: AppColors.infoGradient,
      target: _Target.grammarTest,
    ),
    _Category(
      title: 'Conversation',
      subtitle: 'Real-life dialogues',
      icon: Icons.forum_rounded,
      gradient: AppColors.secondaryGradient,
      target: _Target.conversation,
    ),
    _Category(
      title: 'Listening',
      subtitle: 'Improve listening',
      icon: Icons.headset_rounded,
      gradient: AppColors.infoGradient,
      target: _Target.listening,
    ),
    _Category(
      title: 'Speaking',
      subtitle: 'Practice pronunciation',
      icon: Icons.mic_rounded,
      gradient: AppColors.pinkGradient,
      target: _Target.speaking,
    ),
    _Category(
      title: 'Translate',
      subtitle: 'Banglish translator',
      icon: Icons.translate_rounded,
      gradient: [Color(0xFF00BCD4), Color(0xFF009688)],
      target: _Target.translate,
    ),
    _Category(
      title: 'Verb Forms Quiz',
      subtitle: 'Practice V1-V5',
      icon: Icons.transform_rounded,
      gradient: AppColors.accentGradient,
      target: _Target.verbFormsQuiz,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.rocket_launch_rounded, color: AppColors.primary, size: 26),
            SizedBox(width: 8),
            Text('Practice', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
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
              Text('Test & Practice',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Reinforce your learning with tests and practice sessions.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.3,
                ),
                itemCount: _categories.length,
                itemBuilder: (_, i) => _buildCard(context, _categories[i], isDark, theme),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, _Category cat, bool isDark, ThemeData theme) {
    final gradient = cat.gradient;
    return GestureDetector(
      onTap: () => _navigate(context, cat.target),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [
            BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(cat.icon, color: Colors.white, size: 26),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cat.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(cat.subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, _Target target) {
    switch (target) {
      case _Target.vocabTest:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const VocabularyTestScreen()));
      case _Target.grammarTest:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const GrammarTestListScreen()));
      case _Target.conversation:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversationScreen()));
      case _Target.listening:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ListeningScreen()));
      case _Target.speaking:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SpeakingScreen()));
      case _Target.translate:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const BanglishTranslatorScreen()));
      case _Target.verbFormsQuiz:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const VerbFormPracticeScreen()));
    }
  }
}

enum _Target {
  vocabTest,
  grammarTest,
  conversation,
  listening,
  speaking,
  translate,
  verbFormsQuiz,
}

class _Category {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final _Target target;

  const _Category({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.target,
  });
}
