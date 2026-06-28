import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/grammar_chapter_model.dart';
import '../services/vocab_remote_service.dart';

const _grammarVersionKey = 'grammar_cache_version';
const _currentGrammarVersion = 3;

final grammarAssetPathsProvider = FutureProvider<List<String>>((ref) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  return manifest
      .listAssets()
      .where((p) =>
          p.startsWith('assets/json/grammar/') && p.endsWith('.json'))
      .toList()
    ..sort();
});

/// Loads all grammar chapters from local JSON assets.
/// JSON files contain full structured data (topics, formulas, rules, etc.),
/// unlike Firestore which only stores simplified content.
final allGrammarChaptersProvider =
    FutureProvider<List<GrammarChapter>>((ref) async {
  debugPrint('📚 Loading grammar from JSON assets');
  await _bustOldCache();
  final paths = await ref.watch(grammarAssetPathsProvider.future);

  final results = await Future.wait(paths.map((path) async {
    try {
      return await _loadChapter(path);
    } catch (e) {
      debugPrint('Failed to load chapter: $path — $e');
      return null;
    }
  }));

  final chapters = results.whereType<GrammarChapter>().toList();
  chapters.sort((a, b) => a.chapter.compareTo(b.chapter));
  debugPrint('📚 Loaded ${chapters.length} grammar chapters from JSON assets');
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

/// Reloads grammar chapters by invalidating the provider.
Future<void> refreshGrammarChapters(WidgetRef ref) async {
  ref.invalidate(allGrammarChaptersProvider);
  await ref.read(allGrammarChaptersProvider.future);
}