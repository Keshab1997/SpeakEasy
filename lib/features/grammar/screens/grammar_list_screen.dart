import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeleton_widget.dart';
import '../../../models/grammar_chapter_model.dart';
import '../../../providers/grammar_provider.dart';
import '../../../services/vocab_remote_service.dart';
import 'grammar_detail_screen.dart';

class GrammarListScreen extends ConsumerStatefulWidget {
  const GrammarListScreen({super.key});

  @override
  ConsumerState<GrammarListScreen> createState() => _GrammarListScreenState();
}

class _GrammarListScreenState extends ConsumerState<GrammarListScreen> {
  final _scrollController = ScrollController();
  int _selectedTab = 0;
  bool _isRefreshing = false;

  static const _sectionHeaderHeight = 52.0;
  static const _cardHeight = 90.0;
  static const _sectionBottomSpacing = 16.0;

  void _onTabTap(int index, Map<String, List<GrammarChapter>> map) {
    setState(() => _selectedTab = index);
    final levels = map.keys.toList();
    if (index >= levels.length) return;

    double offset = 16; // ListView top padding
    for (int i = 0; i < index; i++) {
      offset += _sectionHeaderHeight;
      offset += map[levels[i]]!.length * _cardHeight;
      offset += _sectionBottomSpacing;
    }

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _clearCacheAndRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      await VocabRemoteService.clearGrammarCache();
      ref.invalidate(allGrammarChaptersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared! Refreshing data...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to clear cache.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chaptersAsync = ref.watch(chaptersByLevelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grammar'),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _isRefreshing ? null : _clearCacheAndRefresh,
            tooltip: 'Clear cache & refresh',
          ),
        ],
        bottom: chaptersAsync.whenOrNull(
          data: (map) {
            final levels = map.keys.toList();
            if (levels.isEmpty) return null;
            return PreferredSize(
              preferredSize: const Size.fromHeight(40),
              child: _LevelTabs(
                levels: levels,
                selected: _selectedTab,
                onTap: (i) => _onTabTap(i, map),
              ),
            );
          },
        ),
      ),
      body: chaptersAsync.when(
        loading: () => ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          itemBuilder: (_, __) => const SkeletonListTile(),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (map) {
          final levels = map.keys.toList();
          if (levels.isEmpty) {
            return const Center(child: Text('No grammar chapters available.'));
          }
          return _LevelSections(
            levels: levels,
            map: map,
            scrollController: _scrollController,
          );
        },
      ),
    );
  }
}

class _LevelTabs extends StatelessWidget {
  final List<String> levels;
  final int selected;
  final ValueChanged<int> onTap;

  const _LevelTabs({
    required this.levels,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final emojis = {'Beginner': '🌱', 'Intermediate': '📖', 'Advanced': '🚀'};
    final tabs = levels.map((l) => '${emojis[l] ?? ''} $l').toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = i == selected;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _LevelSections extends StatelessWidget {
  final List<String> levels;
  final Map<String, List<GrammarChapter>> map;
  final ScrollController scrollController;

  const _LevelSections({
    required this.levels,
    required this.map,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: levels.map((level) {
        return _GrammarSection(
          level: level,
          chapters: map[level]!,
        );
      }).toList(),
    );
  }
}

class _GrammarSection extends StatelessWidget {
  final String level;
  final List<GrammarChapter> chapters;

  const _GrammarSection({
    required this.level,
    required this.chapters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emojis = {'Beginner': '🌱', 'Intermediate': '📖', 'Advanced': '🚀'};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Text(
            '${emojis[level] ?? ''} $level',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        ...chapters.map((ch) => _GrammarCard(chapter: ch)),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _GrammarCard extends StatelessWidget {
  final GrammarChapter chapter;
  const _GrammarCard({required this.chapter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: theme.cardColor,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GrammarDetailScreen(chapter: chapter),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${chapter.chapter}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (chapter.topics.isNotEmpty)
                        Text(
                          '${chapter.topics.length} topics',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
