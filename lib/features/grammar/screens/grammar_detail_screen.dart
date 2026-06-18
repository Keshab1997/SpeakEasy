import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/grammar_chapter_model.dart';

class GrammarDetailScreen extends StatelessWidget {
  final GrammarChapter chapter;

  const GrammarDetailScreen({super.key, required this.chapter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(chapter.title,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (chapter.description.isNotEmpty)
            _DescriptionHero(
              description: chapter.description,
              banglaDescription: chapter.banglaDescription,
            ),
          const SizedBox(height: 8),
          ...chapter.topics.map((topic) => _TopicCard(topic: topic)),
          if (chapter.commonMistakes.isNotEmpty) ...[
            const SizedBox(height: 20),
            _CommonMistakesSection(mistakes: chapter.commonMistakes),
          ],
        ],
      ),
    );
  }
}

class _DescriptionHero extends StatelessWidget {
  final String description;
  final String banglaDescription;
  const _DescriptionHero({
    required this.description,
    required this.banglaDescription,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                height: 1.6,
              )),
          const SizedBox(height: 12),
          Text(banglaDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
                height: 1.7,
              )),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String bangla;
  final String english;
  const _SectionLabel({required this.bangla, required this.english});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(bangla,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.3,
              )),
          const SizedBox(width: 6),
          Text(english,
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final GrammarTopic topic;
  const _TopicCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(topic.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        )),
                    if (topic.banglaName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(topic.banglaName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (topic.definition.isNotEmpty) ...[
            _SectionLabel(bangla: 'সংজ্ঞা', english: 'Definition'),
            Text(topic.definition,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(height: 1.7, fontWeight: FontWeight.w500)),
          ],
          if (topic.banglaDefinition.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.primary.withOpacity(0.08)),
              ),
              child: Text(topic.banglaDefinition,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey[700], height: 1.7)),
            ),
          ],
          if (topic.formula.isNotEmpty) ...[
            _SectionLabel(bangla: 'সূত্র', english: 'Formula'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.accent.withOpacity(0.15)),
              ),
              child: Text(topic.formula,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                      height: 1.5)),
            ),
          ],
          if (topic.rules.isNotEmpty) ...[
            _SectionLabel(bangla: 'নিয়মসমূহ', english: 'Rules'),
            ...topic.rules.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 1, right: 12),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('${e.key + 1}',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      Expanded(
                        child: Text(e.value,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(height: 1.5)),
                      ),
                    ],
                  ),
                )),
          ],
          if (topic.examples.isNotEmpty) ...[
            _SectionLabel(bangla: 'উদাহরণ', english: 'Examples'),
            ...topic.examples.map((ex) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isDark
                            ? Colors.grey[800]!
                            : Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('EN ',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(ex.en,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FontStyle.italic,
                                    height: 1.4)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('বাং ',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accent)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(ex.bn,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(
                                        color: Colors.grey[600],
                                        height: 1.4)),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
          ],
          if (topic.tips.isNotEmpty) ...[
            _SectionLabel(bangla: 'পরামর্শ', english: 'Tips'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue.withOpacity(0.12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lightbulb_outline,
                        color: Colors.blue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(topic.tips,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(height: 1.6)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommonMistakesSection extends StatelessWidget {
  final List<GrammarMistake> mistakes;
  const _CommonMistakesSection({required this.mistakes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.red, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('সাধারণ ভুল',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text('Common Mistakes',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey[400])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...mistakes.map((m) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark(context) ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isDark(context)
                          ? AppColors.borderDark
                          : Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 12),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(m.wrong,
                              style: TextStyle(
                                  color: Colors.red.shade700,
                                  decoration: TextDecoration.lineThrough,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 12),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(m.correct,
                              style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3)),
                        ),
                      ],
                    ),
                    if (m.explanation.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(m.explanation,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600], height: 1.5)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              )),
        ],
      ),
    );
  }

  bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}
