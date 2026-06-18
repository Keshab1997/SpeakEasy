import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vocabulary_chapter_model.dart';
import '../services/vocab_remote_service.dart';

/// Auto-detects all chapter_XX.json files from AssetManifest — no hardcoding needed
final chapterAssetPathsProvider = FutureProvider<List<String>>((ref) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  return manifest
      .listAssets()
      .where((p) =>
          (p.startsWith('assets/json/vocabulary/Beginner/') ||
           p.startsWith('assets/json/vocabulary/Intermediate/') ||
           p.startsWith('assets/json/vocabulary/Advanced/')) &&
          p.endsWith('.json'))
      .toList()
    ..sort();
});

final allChaptersProvider = FutureProvider<List<VocabularyChapter>>((ref) async {
  final paths = await ref.watch(chapterAssetPathsProvider.future);
  final chapters = await Future.wait(paths.map(_loadChapter));
  chapters.sort((a, b) => a.chapter.compareTo(b.chapter));
  return chapters;
});

/// Loads a single chapter: remote → Hive cache → local asset fallback
Future<VocabularyChapter> _loadChapter(String assetPath) async {
  final raw = await VocabRemoteService.loadChapterJson(assetPath);
  return VocabularyChapter.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Chapters grouped by level: {'Beginner': [...], 'Intermediate': [...], ...}
final chaptersByLevelProvider =
    Provider<AsyncValue<Map<String, List<VocabularyChapter>>>>((ref) {
  return ref.watch(allChaptersProvider).whenData((chapters) {
    final map = <String, List<VocabularyChapter>>{};
    for (final c in chapters) {
      map.putIfAbsent(c.level, () => []).add(c);
    }
    return map;
  });
});
