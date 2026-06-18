import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/hive_service.dart';

final vocabProgressProvider =
    StateNotifierProvider<VocabProgressNotifier, List<int>>(
  (ref) => VocabProgressNotifier(),
);

class VocabProgressNotifier extends StateNotifier<List<int>> {
  VocabProgressNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    if (!Hive.isBoxOpen('vocab_progress')) {
      await Hive.openBox('vocab_progress');
    }
    state = HiveService.getReadChapters();
  }

  Future<void> markRead(int chapterNumber) async {
    await HiveService.markChapterRead(chapterNumber);
    state = HiveService.getReadChapters();
  }

  Future<void> resetProgress() async {
    await Hive.box('vocab_progress').put('readChapters', <int>[]);
    state = [];
  }

  bool isRead(int chapterNumber) => state.contains(chapterNumber);
}
