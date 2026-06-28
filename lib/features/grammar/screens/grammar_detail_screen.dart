import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/grammar_text_parser.dart';
import '../../../models/grammar_chapter_model.dart';
import '../../../providers/last_opened_chapter_provider.dart';
import '../../../services/vocab_remote_service.dart';
import 'grammar_master_screen.dart';

class GrammarDetailScreen extends ConsumerStatefulWidget {
  final GrammarChapter chapter;

  const GrammarDetailScreen({super.key, required this.chapter});

  @override
  ConsumerState<GrammarDetailScreen> createState() =>
      _GrammarDetailScreenState();
}

class _GrammarDetailScreenState extends ConsumerState<GrammarDetailScreen> {
  final _scrollController = ScrollController();
  double _lastScrollOffset = 0;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _restoreScrollPosition();
    // Defer provider state mutation to after the current frame: Riverpod
    // forbids modifying a provider while the widget tree is being built,
    // and initState runs synchronously during element mount.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(lastOpenedChapterProvider.notifier)
          .setOpened('grammar', widget.chapter.chapter);
    });
  }

  Future<void> _restoreScrollPosition() async {
    final box = await VocabRemoteService.getCacheBox();
    final saved =
        box.get('scroll_pos_chapter_${widget.chapter.chapter}') as double?;
    if (saved != null && saved > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(saved.clamp(
            0,
            _scrollController.position.maxScrollExtent,
          ));
        } else {
          WidgetsBinding.instance.addPostFrameCallback((__) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(saved.clamp(
                0,
                _scrollController.position.maxScrollExtent,
              ));
            }
          });
        }
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _lastScrollOffset = _scrollController.offset;
    // Debounce: save scroll position 300ms after user stops scrolling
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _saveScrollPosition();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _saveScrollPosition();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveScrollPosition() async {
    if (_lastScrollOffset <= 0) return;
    final box = await VocabRemoteService.getCacheBox();
    await box.put('scroll_pos_chapter_${widget.chapter.chapter}',
        _lastScrollOffset);
    // Save scroll progress % for Continue Learning
    if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
      final pct = _lastScrollOffset / _scrollController.position.maxScrollExtent;
      ref.read(lastOpenedChapterProvider.notifier).updateProgress('grammar', widget.chapter.chapter, pct);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chapter.title,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        children: [
          if (widget.chapter.description.isNotEmpty)
            _DescriptionHero(
              description: widget.chapter.description,
              banglaDescription: widget.chapter.banglaDescription,
            ),
          if (widget.chapter.topics.isNotEmpty) ...[
            const SizedBox(height: 16),
            _MasterGuideCard(chapter: widget.chapter),
          ],
          const SizedBox(height: 8),
          ...widget.chapter.topics
              .map((topic) => _TopicCard(topic: topic)),
          if (widget.chapter.commonMistakes.isNotEmpty) ...[
            const SizedBox(height: 20),
            _CommonMistakesSection(
                mistakes: widget.chapter.commonMistakes),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GrammarRichText(
            text: description,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          GrammarRichText(
            text: banglaDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
              height: 1.7,
            ),
          ),
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
      padding: const EdgeInsets.only(top: 16, bottom: 8),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
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
            const _SectionLabel(bangla: 'সংজ্ঞা', english: 'Definition'),
            GrammarRichText(
              text: topic.definition,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(height: 1.7, fontWeight: FontWeight.w500),
            ),
          ],
          if (topic.banglaDefinition.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.primary.withOpacity(0.08)),
              ),
              child: GrammarRichText(
                text: topic.banglaDefinition,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey[700], height: 1.7),
              ),
            ),
          ],
          if (topic.formula.isNotEmpty) ...[
            const _SectionLabel(bangla: 'সূত্র', english: 'Formula'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.accent.withOpacity(0.15)),
              ),
              child: FormulaRichText(
                formula: topic.formula,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                    height: 1.5),
              ),
            ),
          ],
          if (topic.rules.isNotEmpty) ...[
            const _SectionLabel(bangla: 'নিয়মসমূহ', english: 'Rules'),
            ...GrammarTextParser.buildRuleWidgets(
              topic.rules,
              context: context,
              isDark: isDark,
            ),
          ],
          if (topic.examples.isNotEmpty) ...[
            const _SectionLabel(bangla: 'উদাহরণ', english: 'Examples'),
            ...topic.examples.map((ex) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
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
                          const Text('EN ',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: GrammarRichText(
                              text: ex.en,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('বাং ',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accent)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: GrammarRichText(
                              text: ex.bn,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(
                                      color: Colors.grey[600],
                                      height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
          ],
          if (topic.tips.isNotEmpty) ...[
            const _SectionLabel(bangla: 'পরামর্শ', english: 'Tips'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
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
                    child: GrammarRichText(
                      text: topic.tips,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(height: 1.6),
                    ),
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

class _MasterGuideCard extends StatelessWidget {
  final GrammarChapter chapter;
  const _MasterGuideCard({required this.chapter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GrammarMasterScreen(chapter: chapter),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.12),
              AppColors.purpleGradient[0].withOpacity(0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Master Guide',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    'Interactive Q&A with detailed AI teacher explanations',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: AppColors.primary, size: 20),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark(context) ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(12),
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
                          child: GrammarRichText(
                            text: m.wrong,
                            style: TextStyle(
                                color: Colors.red.shade700,
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.w500,
                                height: 1.3),
                          ),
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
                          child: GrammarRichText(
                            text: m.correct,
                            style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                                height: 1.3),
                          ),
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
                              child: GrammarRichText(
                                text: m.explanation,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600], height: 1.5),
                              ),
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
