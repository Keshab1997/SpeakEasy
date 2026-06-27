import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
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

/// Loads all grammar chapters: Firestore first, JSON fallback.
final allGrammarChaptersProvider =
    FutureProvider<List<GrammarChapter>>((ref) async {
  // Try Firestore first
  final firestoreChapters = await _loadGrammarFromFirestore();
  if (firestoreChapters != null) {
    debugPrint(
        '📚 Loaded ${firestoreChapters.length} grammar chapters from Firestore');
    return firestoreChapters;
  }

  // Fallback to JSON assets
  debugPrint('📚 Firestore empty, loading grammar from JSON assets');
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
  return chapters;
});

/// Loads grammar chapters from Firestore.
/// Returns null if the collection is empty (so caller can fall back to JSON).
Future<List<GrammarChapter>?> _loadGrammarFromFirestore() async {
  final firestore = FirebaseFirestore.instance;
  final chaptersSnapshot = await firestore
      .collection('content_grammar_chapters')
      .orderBy('chapterNumber', descending: false)
      .get();

  if (chaptersSnapshot.docs.isEmpty) return null;

  return chaptersSnapshot.docs.map((doc) {
    final data = doc.data();
    final chapterNumber = data['chapterNumber'] as int? ?? 0;
    final title = data['title'] as String? ?? '';
    final content = data['content'] as String? ?? '';

    return GrammarChapter(
      chapter: chapterNumber,
      level: 'Beginner', // Not stored in Firestore; default to Beginner
      title: title,
      description: content,
      banglaDescription: '',
      topics: const [],
      commonMistakes: const [],
    );
  }).toList();
}

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

/// Reloads grammar chapters from Firestore by invalidating the provider.
Future<void> refreshGrammarChapters(WidgetRef ref) async {
  ref.invalidate(allGrammarChaptersProvider);
  await ref.read(allGrammarChaptersProvider.future);
}