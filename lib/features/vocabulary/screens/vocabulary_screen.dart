import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/chapter_vocabulary_provider.dart';
import '../../../providers/vocab_progress_provider.dart';
import 'chapter_words_screen.dart';

class VocabularyScreen extends ConsumerWidget {
  const VocabularyScreen({super.key});

  static const _levelOrder = ['Beginner', 'Intermediate', 'Advanced'];
  static const _levelEmojis = {
    'Beginner': '🌱',
    'Intermediate': '📖',
    'Advanced': '🚀',
  };
  static const _levelColors = {
    'Beginner': AppColors.primary,
    'Intermediate': Color(0xFF7C3AED),
    'Advanced': Color(0xFFEA580C),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chaptersAsync = ref.watch(chaptersByLevelProvider);
    final readChapters = ref.watch(vocabProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset Progress',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Reset Progress'),
                  content: const Text('All chapter progress will be cleared. Are you sure?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(vocabProgressProvider.notifier).resetProgress();
              }
            },
          ),
        ],
      ),
      body: chaptersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (byLevel) {
          if (byLevel.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No chapters found.\nAdd chapter JSON files to\nassets/json/vocabulary/',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final totalChapters = byLevel.values.fold(0, (s, l) => s + l.length);
          final completedCount = readChapters.length;
          final progressPct = totalChapters == 0 ? 0.0 : completedCount / totalChapters;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // Overall progress card
              Container(
                margin: const EdgeInsets.only(bottom: 16, top: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: AppColors.primaryGradient),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Overall Progress',
                            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('$completedCount / $totalChapters chapters',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progressPct,
                        minHeight: 8,
                        backgroundColor: Colors.white.withOpacity(0.25),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              for (final level in _levelOrder)
                if (byLevel.containsKey(level)) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 10),
                    child: Row(
                      children: [
                        Text(_levelEmojis[level]!,
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Text(
                          level,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: _levelColors[level],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${byLevel[level]!.length} chapters',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  for (final chapter in byLevel[level]!)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: (_levelColors[level] ?? AppColors.primary)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '${chapter.chapter}',
                              style: TextStyle(
                                color:
                                    _levelColors[level] ?? AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        title: Text(chapter.title,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${chapter.words.length} words',
                            style: const TextStyle(fontSize: 12)),
                        trailing: readChapters.contains(chapter.chapter)
                            ? const Icon(Icons.check_circle_rounded,
                                color: Colors.green, size: 24)
                            : const Icon(Icons.chevron_right_rounded,
                                color: Colors.grey),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ChapterWordsScreen(chapter: chapter)),
                        ),
                      ),
                    ),
                  const Divider(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }
}
