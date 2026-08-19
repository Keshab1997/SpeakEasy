import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key});

  static final List<Map<String, dynamic>> articles = [
    {
      'title': 'A / An (Indefinite Articles)',
      'rule': 'Used before non-specific or general nouns.',
      'usage': '"A" before consonant sounds, "An" before vowel sounds.',
      'examples': ['A book', 'A university', 'An apple', 'An hour'],
      'color': AppColors.primary,
    },
    {
      'title': 'The (Definite Article)',
      'rule': 'Used before specific or known nouns.',
      'usage': 'When both speaker and listener know what is being referred to.',
      'examples': ['The sun', 'The book on the table', 'The President'],
      'color': AppColors.secondary,
    },
    {
      'title': 'Zero Article (No Article)',
      'rule': 'Used before general plural nouns, uncountable nouns, and proper nouns.',
      'usage': 'When speaking in general.',
      'examples': ['Cats are animals', 'Water is essential', 'I love music'],
      'color': const Color(0xFF8B5CF6),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Articles', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: articles.length,
        itemBuilder: (context, index) {
          final article = articles[index];
          final color = article['color'] as Color;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    article['title'] as String,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  article['rule'] as String,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  article['usage'] as String,
                  style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14),
                ),
                const SizedBox(height: 12),
                const Text('Examples:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: (article['examples'] as List<String>).map((ex) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(ex, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
