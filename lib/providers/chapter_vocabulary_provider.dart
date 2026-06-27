import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

/// Loads all vocabulary chapters: Firestore first, JSON fallback.
final allChaptersProvider =
    FutureProvider<List<VocabularyChapter>>((ref) async {
  // Try Firestore first
  final firestoreChapters = await _loadFromFirestore();
  if (firestoreChapters != null) {
    debugPrint('📖 Loaded ${firestoreChapters.length} chapters from Firestore');
    return firestoreChapters;
  }

  // Fallback to JSON assets
  debugPrint('📖 Firestore empty, loading vocabulary from JSON assets');
  final paths = await ref.watch(chapterAssetPathsProvider.future);
  final chapters = await Future.wait(paths.map(_loadChapter));
  chapters.sort((a, b) => a.chapter.compareTo(b.chapter));
  return chapters;
});

/// Loads vocabulary chapters from Firestore.
/// Returns null if the collection is empty (so caller can fall back to JSON).
Future<List<VocabularyChapter>?> _loadFromFirestore() async {
  final firestore = FirebaseFirestore.instance;
  final chaptersSnapshot = await firestore
      .collection('content_vocabulary_chapters')
      .orderBy('chapterNumber', descending: false)
      .get();

  if (chaptersSnapshot.docs.isEmpty) return null;

  final chapters = <VocabularyChapter>[];

  for (final chapterDoc in chaptersSnapshot.docs) {
    final data = chapterDoc.data();
    final chapterNumber = data['chapterNumber'] as int? ?? 0;
    final title = data['title'] as String? ?? '';
    final level = data['level'] as String? ?? 'Beginner';

    // Fetch words for this chapter
    final wordsSnapshot = await firestore
        .collection('content_vocabulary_words')
        .where('chapterId', isEqualTo: chapterDoc.id)
        .get();

    final words = wordsSnapshot.docs.map((wordDoc) {
      final w = wordDoc.data();
      return ChapterWord(
        word: w['word'] as String? ?? '',
        pronunciation: w['pronunciation'] as String? ?? '',
        meaning: w['meaning'] as String? ?? '',
        banglaMeaning: w['banglaMeaning'] as String? ?? '',
        exampleSentence: w['exampleSentence'] as String? ?? '',
      );
    }).toList();

    chapters.add(VocabularyChapter(
      chapter: chapterNumber,
      title: title,
      level: level,
      words: words,
    ));
  }

  return chapters;
}

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

/// Reloads chapters from Firestore by invalidating the provider.
Future<void> refreshChapters(WidgetRef ref) async {
  ref.invalidate(allChaptersProvider);
  await ref.read(allChaptersProvider.future);
}