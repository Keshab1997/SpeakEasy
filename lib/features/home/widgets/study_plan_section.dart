import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/grammar_chapter_model.dart';
import '../../../models/vocabulary_chapter_model.dart';
import '../../../models/todo_item.dart';
import '../../../providers/grammar_provider.dart';
import '../../../providers/chapter_vocabulary_provider.dart';
import '../../../providers/todo_list_provider.dart';
import '../../../services/hive_service.dart';
import '../../grammar/screens/grammar_detail_screen.dart';
import '../../grammar/screens/grammar_test_list_screen.dart';
import '../../vocabulary/screens/chapter_words_screen.dart';
import '../../vocabulary/screens/vocabulary_test_screen.dart';

class StudyPlanSection extends ConsumerStatefulWidget {
  const StudyPlanSection({super.key});

  @override
  ConsumerState<StudyPlanSection> createState() => _StudyPlanSectionState();
}

class _StudyPlanSectionState extends ConsumerState<StudyPlanSection> {
  bool _weeklyTestDue = false;
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkWeeklyTest();
  }

  void _checkWeeklyTest() {
    final info = HiveService.getWeeklyTestInfo();
    if (info == null) {
      setState(() => _weeklyTestDue = true);
      return;
    }
    final lastDateStr = info['lastTestDate'] as String?;
    if (lastDateStr == null) {
      setState(() => _weeklyTestDue = true);
      return;
    }
    final lastDate = DateTime.parse(lastDateStr);
    if (DateTime.now().difference(lastDate).inDays >= 7) {
      setState(() => _weeklyTestDue = true);
    }
  }

  void _startWeeklyTest() {
    final id = ref.read(todoListProvider.notifier).pickRandomForWeeklyTest();
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete at least one chapter first!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    HiveService.saveWeeklyTestInfo({
      'lastTestDate': DateTime.now().toIso8601String(),
      'lastTestChapterId': id,
    });
    setState(() => _weeklyTestDue = false);

    final type = id.split('_')[0];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => type == 'grammar'
            ? const GrammarTestListScreen()
            : const VocabularyTestScreen(),
      ),
    );
  }

  List<Widget> _buildCards(
      StudyPlanState s, List<TodoItem> allItems, bool isDark,
      List<GrammarChapter> grammarChapters, List<VocabularyChapter> vocabChapters) {
    final vocabItem = s.nextVocabId != null ? allItems.firstWhere((i) => i.id == s.nextVocabId) : null;
    final grammarItem = s.nextGrammarId != null ? allItems.firstWhere((i) => i.id == s.nextGrammarId) : null;

    GrammarChapter? findGrammar(int num) {
      for (final c in grammarChapters) {
        if (c.chapter == num) return c;
      }
      return null;
    }

    VocabularyChapter? findVocab(int num) {
      for (final c in vocabChapters) {
        if (c.chapter == num) return c;
      }
      return null;
    }

    final cards = <Widget>[];
    if (vocabItem != null) {
      final chapter = findVocab(vocabItem.chapterNumber);
      cards.add(_ChapterCard(
        item: vocabItem,
        isDark: isDark,
        isSkipped: s.skippedIds.contains(vocabItem.id),
        onNavigate: chapter != null
            ? () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ChapterWordsScreen(chapter: chapter)))
            : null,
        onToggle: () => ref.read(todoListProvider.notifier).toggleComplete(vocabItem.id),
      ));
    } else {
      cards.add(const _AllDoneCard(type: 'vocabulary chapters'));
    }
    cards.add(const SizedBox(height: 8));
    if (grammarItem != null) {
      final chapter = findGrammar(grammarItem.chapterNumber);
      cards.add(_ChapterCard(
        item: grammarItem,
        isDark: isDark,
        isSkipped: s.skippedIds.contains(grammarItem.id),
        onNavigate: chapter != null
            ? () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => GrammarDetailScreen(chapter: chapter)))
            : null,
        onToggle: () => ref.read(todoListProvider.notifier).toggleComplete(grammarItem.id),
      ));
    } else {
      cards.add(const _AllDoneCard(type: 'grammar chapters'));
    }
    return cards;
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 22, height: 22, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 8),
            Container(width: 100, height: 20, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
          ],
        ),
        const SizedBox(height: 16),
        Container(width: double.infinity, height: 40, decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(8))),
        const SizedBox(height: 8),
        Container(width: double.infinity, height: 40, decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(8))),
        const SizedBox(height: 12),
        Container(width: double.infinity, height: 80, decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(20))),
        const SizedBox(height: 8),
        Container(width: double.infinity, height: 80, decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(20))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final studyState = ref.watch(todoListProvider);
    final grammarAsync = ref.watch(allGrammarChaptersProvider);
    final vocabAsync = ref.watch(allChaptersProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final items = studyState.items;
    if (items.isEmpty) {
      if (grammarAsync.isLoading || vocabAsync.isLoading) {
        return _buildLoadingSkeleton(isDark);
      }
      return const SizedBox.shrink();
    }

    final grammarChapters = grammarAsync.asData?.value ?? [];
    final vocabChapters = vocabAsync.asData?.value ?? [];
    final pending = items.where((i) => i.status == TodoStatus.pending).toList();
    final completed = items.where((i) => i.status == TodoStatus.completed).toList();

    final grammarTotal = items.where((i) => i.type == 'grammar').length;
    final grammarDone = items.where((i) => i.type == 'grammar' && i.status == TodoStatus.completed).length;
    final grammarPct = grammarTotal == 0 ? 0.0 : grammarDone / grammarTotal;
    final vocabTotal = items.where((i) => i.type == 'vocabulary').length;
    final vocabDone = items.where((i) => i.type == 'vocabulary' && i.status == TodoStatus.completed).length;
    final vocabPct = vocabTotal == 0 ? 0.0 : vocabDone / vocabTotal;

    final grammarSkipped = studyState.skippedIds.where((id) => id.startsWith('grammar_')).length;
    final vocabSkipped = studyState.skippedIds.where((id) => id.startsWith('vocab_')).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text('Study Plan',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${pending.length} pending',
                  style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Progress bars — Grammar + Vocabulary separately
        _ProgressRow(
          label: 'Grammar',
          color: AppColors.purpleGradient[0],
          done: grammarDone,
          total: grammarTotal,
          pct: grammarPct,
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _ProgressRow(
          label: 'Vocabulary',
          color: AppColors.primary,
          done: vocabDone,
          total: vocabTotal,
          pct: vocabPct,
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // Weekly test banner
        if (_weeklyTestDue && studyState.completedCount > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF3F51B5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.quiz_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WEEKLY TEST',
                          style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      SizedBox(height: 2),
                      Text('Time for your weekly mock test!',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _startWeeklyTest,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Start',
                        style: TextStyle(color: Color(0xFF3F51B5), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),

        // Skip warnings — separate for Grammar & Vocabulary
        if (grammarSkipped > 0)
          _SkipWarning(count: grammarSkipped, label: 'Grammar'),
        if (vocabSkipped > 0)
          _SkipWarning(count: vocabSkipped, label: 'Vocabulary'),

        // Two cards: Vocab + Grammar
        ...[
          ..._buildCards(studyState, items, isDark, grammarChapters, vocabChapters),
        ],

        // Completed sections — collapsible
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _showCompleted = !_showCompleted),
            child: Row(
              children: [
                Text('Completed',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.grey)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${completed.length}',
                      style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Icon(
                  _showCompleted ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: Colors.grey,
                  size: 18,
                ),
              ],
            ),
          ),
          if (_showCompleted)
            ...completed.reversed.take(20).map((item) => _CompactCompletedRow(
                  item: item,
                  onUndo: () {
                    ref.read(todoListProvider.notifier).toggleComplete(item.id);
                  },
                )),
        ],
      ],
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final TodoItem item;
  final bool isDark;
  final bool isSkipped;
  final VoidCallback? onNavigate;
  final VoidCallback onToggle;

  const _ChapterCard({
    required this.item,
    required this.isDark,
    required this.isSkipped,
    this.onNavigate,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = item.type;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _typeColor(type).withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _typeColor(type).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onNavigate,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _typeColor(type).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          '${item.chapterNumber}',
                          style: TextStyle(
                            color: _typeColor(type),
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _typeColor(type).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  type == 'grammar' ? 'GRAMMAR' : 'VOCAB',
                                  style: TextStyle(
                                    color: _typeColor(type),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(item.level,
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                              if (isSkipped) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('SKIPPED',
                                      style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.title,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _typeColor(type),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) =>
      type == 'grammar' ? AppColors.purpleGradient[0] : AppColors.primary;
}

class _SkipWarning extends StatelessWidget {
  final int count;
  final String label;

  const _SkipWarning({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count $label chapter${count > 1 ? 's' : ''} skipped — complete them first!',
              style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final Color color;
  final int done;
  final int total;
  final double pct;
  final bool isDark;

  const _ProgressRow({
    required this.label,
    required this.color,
    required this.done,
    required this.total,
    required this.pct,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
            Text('$done/$total',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 5,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  final String type;
  const _AllDoneCard({this.type = 'chapters'});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.celebration_rounded, color: Colors.green, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'All $type done! 🎉',
              style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactCompletedRow extends StatelessWidget {
  final TodoItem item;
  final VoidCallback onUndo;

  const _CompactCompletedRow({required this.item, required this.onUndo});

  @override
  Widget build(BuildContext context) {
    final type = item.type;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: GestureDetector(
        onTap: onUndo,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 18),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: (type == 'grammar' ? AppColors.purpleGradient[0] : AppColors.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(type == 'grammar' ? 'G' : 'V',
                    style: TextStyle(
                      color: type == 'grammar' ? AppColors.purpleGradient[0] : AppColors.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    )),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                      decoration: TextDecoration.lineThrough,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text(
                _formatDate(item.completedAt!),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(width: 4),
              Icon(Icons.undo_rounded, color: Colors.grey.shade400, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yest';
    return '${d.day}/${d.month}';
  }
}
