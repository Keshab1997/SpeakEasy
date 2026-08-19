import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class TenseScreen extends StatefulWidget {
  const TenseScreen({super.key});

  @override
  State<TenseScreen> createState() => _TenseScreenState();
}

class _TenseScreenState extends State<TenseScreen> {
  int _selectedTenseIndex = 0;

  final tenses = [
    {
      'name': 'Present Simple',
      'formula': 'Subject + V1 + Object',
      'usage': 'Facts, habits, routines',
      'example': 'I eat rice every day.',
      'banglaExample': 'আমি প্রতিদিন ভাত খাই।',
    },
    {
      'name': 'Present Continuous',
      'formula': 'Subject + am/is/are + V4 + Object',
      'usage': 'Ongoing actions now',
      'example': 'I am eating rice now.',
      'banglaExample': 'আমি এখন ভাত খাচ্ছি।',
    },
    {
      'name': 'Present Perfect',
      'formula': 'Subject + have/has + V3 + Object',
      'usage': 'Completed actions with present relevance',
      'example': 'I have eaten rice.',
      'banglaExample': 'আমি ভাত খেয়েছি।',
    },
    {
      'name': 'Past Simple',
      'formula': 'Subject + V2 + Object',
      'usage': 'Completed past actions',
      'example': 'I ate rice yesterday.',
      'banglaExample': 'আমি গতকাল ভাত খেয়েছিলাম।',
    },
    {
      'name': 'Future Simple',
      'formula': 'Subject + will + V1 + Object',
      'usage': 'Future actions',
      'example': 'I will eat rice tomorrow.',
      'banglaExample': 'আমি আগামীকাল ভাত খাব।',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tense = tenses[_selectedTenseIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('Tense', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: tenses.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedTenseIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: ActionChip(
                    label: Text(tenses[index]['name']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: () => setState(() => _selectedTenseIndex = index),
                    backgroundColor: isSelected ? AppColors.primary : null,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: AppColors.primaryGradient),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tense['name']!, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(tense['usage']!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoCard(theme, 'Formula', tense['formula']!, Icons.functions_rounded, AppColors.accent),
                  const SizedBox(height: 12),
                  _buildInfoCard(theme, 'Example', tense['example']!, Icons.format_quote_rounded, AppColors.secondary),
                  const SizedBox(height: 12),
                  _buildInfoCard(theme, 'Bangla', tense['banglaExample']!, Icons.translate_rounded, AppColors.primary),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tips_and_updates_rounded, color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text('Practice Tip', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try making 3 sentences in ${tense['name']} about your daily life to practice.',
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, String label, String content, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w500, height: 1.4)),
        ],
      ),
    );
  }
}
