import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/vocabulary_chapter_model.dart';
import '../../../providers/vocab_progress_provider.dart';
import '../../../services/hive_service.dart';

class ChapterWordsScreen extends ConsumerStatefulWidget {
  final VocabularyChapter chapter;
  const ChapterWordsScreen({super.key, required this.chapter});

  @override
  ConsumerState<ChapterWordsScreen> createState() => _ChapterWordsScreenState();
}

class _ChapterWordsScreenState extends ConsumerState<ChapterWordsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Mark chapter as read + save as last opened for Continue Learning
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vocabProgressProvider.notifier).markRead(widget.chapter.chapter);
      HiveService.setLastOpenedChapter('vocabulary', widget.chapter.chapter);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent > 0) {
      final pct = _scrollController.offset / _scrollController.position.maxScrollExtent;
      HiveService.setChapterProgress('vocabulary', widget.chapter.chapter, pct);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chapter ${widget.chapter.chapter}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(widget.chapter.title,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
      ),
      body: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: widget.chapter.words.length,
        itemBuilder: (context, index) {
          final w = widget.chapter.words[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    w.word[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                  ),
                ),
              ),
              title:
                  Text(w.word, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (w.pronunciation.isNotEmpty)
                    Text(w.pronunciation,
                        style: const TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                            fontSize: 12)),
                  Text(
                    w.banglaMeaning.isNotEmpty ? w.banglaMeaning : w.meaning,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              onTap: () => _showDetail(context, w, theme),
            ),
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, ChapterWord w, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(w.word,
                  style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900, color: AppColors.primary)),
            ),
            if (w.pronunciation.isNotEmpty)
              Center(
                child: Text(w.pronunciation,
                    style: const TextStyle(
                        color: Colors.grey, fontStyle: FontStyle.italic)),
              ),
            const SizedBox(height: 20),
            _tile('Meaning', w.meaning, AppColors.primary),
            const SizedBox(height: 10),
            _tile('বাংলা অর্থ', w.banglaMeaning, AppColors.secondary),
            const SizedBox(height: 10),
            _tile('Example', w.exampleSentence, AppColors.accent),
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, String value, Color color) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}
