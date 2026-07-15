import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';

class VocabRemoteService {
  static const String _baseUrl =
      'https://raw.githubusercontent.com/Keshab1997/Flutter-Spoken-English-App/main/assets';

  static const String _cacheBox = 'vocab_cache';
  static const String _manifestKey = 'remote_manifest';

  static Future<Box> getCacheBox() async {
    if (!Hive.isBoxOpen(_cacheBox)) {
      await Hive.openBox(_cacheBox);
    }
    return Hive.box(_cacheBox);
  }

  static Future<Box> _getBox() async => getCacheBox();

  /// Loads chapter JSON with offline-first strategy:
  /// 1) Hive cache (fastest) → 2) local asset bundle (always available)
  /// 3) GitHub raw (background, updates cache for next launch)
  static Future<String> loadChapterJson(String assetPath) async {
    final box = await _getBox();
    final relative = assetPath.replaceFirst('assets/', '');

    // 1) Hive cache — fastest
    final cached = box.get('chapter_$relative') as String?;
    if (cached != null) return cached;

    // 2) Local asset bundle — always available, no network needed
    final localData = await rootBundle.loadString(assetPath);

    // 3) GitHub raw — background update (never blocks UI)
    _tryRemoteUpdate(relative, box, localData);

    return localData;
  }

  /// Tries to fetch the latest chapter JSON from GitHub.
  /// On success, updates Hive cache for faster subsequent loads.
  /// On failure (e.g. offline), caches the local data so the next
  /// launch skips the HTTP attempt entirely.
  static Future<void> _tryRemoteUpdate(
    String relative,
    Box box,
    String localData,
  ) async {
    try {
      final url = '$_baseUrl/$relative';
      final resp = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 5),
          );
      if (resp.statusCode == 200) {
        await box.put('chapter_$relative', resp.body);
        return;
      }
    } catch (_) {
      // Offline or timeout — fall through to cache local data
    }
    // Cache local data so subsequent launches avoid HTTP altogether
    await box.put('chapter_$relative', localData);
  }

  /// Optional: fetch the list of available chapter paths from remote
  static Future<List<String>?> fetchRemoteManifest() async {
    const manifestUrl = '$_baseUrl/json/vocabulary_manifest.json';
    try {
      final resp = await http.get(Uri.parse(manifestUrl)).timeout(
            const Duration(seconds: 5),
          );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final paths = (data['paths'] as List).cast<String>();
        final box = await _getBox();
        await box.put(_manifestKey, paths);
        return paths;
      }
    } catch (_) {}

    final box = await _getBox();
    final cached = box.get(_manifestKey) as List?;
    return cached?.cast<String>();
  }

  /// Clear all cached vocab data (force fresh fetch next time)
  static Future<void> clearCache() async {
    final box = await _getBox();
    await box.clear();
  }

  /// Clear only grammar-related cache entries
  static Future<void> clearGrammarCache() async {
    final box = await _getBox();
    final keys = box.keys.where(
        (k) => k is String && k.startsWith('chapter_assets/json/grammar/'));
    for (final k in keys) {
      await box.delete(k);
    }
  }
}
