import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/grammar_chapter_model.dart';
import '../services/vocab_remote_service.dart';

const _grammarVersionKey = 'grammar_cache_version';
const _currentGrammarVersion = 2;

final grammarAssetPathsProvider = FutureProvider<List<String>>((ref) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  return manifest
      .listAssets()
      .where((p) =>
          p.startsWith('assets/json/grammar/') && p.endsWith('.json'))
      .toList()
    ..sort();
});

final allGrammarChaptersProvider =
    FutureProvider<List<GrammarChapter>>((ref) async {
  await _bustOldCache();
  final paths = await ref.watch(grammarAssetPathsProvider.future);
  final chapters = await Future.wait(paths.map(_loadChapter));
  chapters.sort((a, b) => a.chapter.compareTo(b.chapter));
  return chapters;
});

Future<void> _bustOldCache() async {
  final box = await VocabRemoteService.getCacheBox();
  final version = box.get(_grammarVersionKey) as int?;
  if (version != _currentGrammarVersion) {
    await VocabRemoteService.clearGrammarCache();
    await box.put(_grammarVersionKey, _currentGrammarVersion);
  }
}

Future<GrammarChapter> _loadChapter(String assetPath) async {
  final raw = await VocabRemoteService.loadChapterJson(assetPath);
  return GrammarChapter.fromJson(
      const JsonDecoder().convert(raw) as Map<String, dynamic>);
}

final chaptersByLevelProvider =
    Provider<AsyncValue<Map<String, List<GrammarChapter>>>>((ref) {
  return ref.watch(allGrammarChaptersProvider).whenData((chapters) {
    final map = <String, List<GrammarChapter>>{};
    for (final c in chapters) {
      map.putIfAbsent(c.level, () => []).add(c);
    }
    return map;
  });
});
