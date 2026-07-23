import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeleton_widget.dart';
import '../../../providers/grammar_provider.dart';
import 'grammar_test_screen.dart';

class GrammarTestListScreen extends ConsumerStatefulWidget {
  const GrammarTestListScreen({super.key});

  @override
  ConsumerState<GrammarTestListScreen> createState() => _GrammarTestListScreenState();
}

class _GrammarTestListScreenState extends ConsumerState<GrammarTestListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _levels = <String>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chaptersAsync = ref.watch(chaptersByLevelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.quiz_rounded, color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Grammar Test', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
      body: chaptersAsync.when(
        loading: () => ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          itemBuilder: (_, __) => const SkeletonListTile(),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (map) {
          _levels
            ..clear()
            ..addAll(map.keys);
          if (_levels.isEmpty) {
            return const Center(child: Text('No grammar chapters available.'));
          }
          return _buildLevelGrid(map, isDark);
        },
      ),
    );
  }

  Widget _buildLevelGrid(Map<String, List> map, bool isDark) {
    final emojis = {'Beginner': '🌱', 'Intermediate': '📖', 'Advanced': '🚀'};
    final gradients = {
      'Beginner': AppColors.primaryGradient,
      'Intermediate': AppColors.purpleGradient,
      'Advanced': AppColors.secondaryGradient,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _levels.map((level) {
        final chapters = map[level]!;
        final grad = gradients[level] ?? AppColors.primaryGradient;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Row(
                children: [
                  Text('${emojis[level] ?? ''} ', style: const TextStyle(fontSize: 18)),
                  Text(
                    '$level (${chapters.length})',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const Spacer(),
                  Text(
                    'Test Yourself',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                  ),
                ],
              ),
            ),
            ...chapters.map((ch) => _buildChapterCard(ch, grad, isDark)),
            const SizedBox(height: 20),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildChapterCard(chapter, List<Color> gradient, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GrammarTestScreen(chapter: chapter),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradient),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${chapter.chapter}',
                        style: const TextStyle(
                          color: Colors.white,
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
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${chapter.topics.length} topics',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: AppColors.accent, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Quiz',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
