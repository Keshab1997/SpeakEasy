import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/hive_service.dart';

/// Immutable snapshot of the most recently opened chapter in the app.
///
/// Used by the Home screen's Continue Learning section to render the
/// resume card reactively (without polling Hive on every frame).
class LastOpenedChapter {
  final String type; // 'grammar' | 'vocabulary'
  final int chapter;
  final double progress; // 0.0–1.0

  const LastOpenedChapter({
    required this.type,
    required this.chapter,
    this.progress = 0.0,
  });

  LastOpenedChapter copyWith({
    String? type,
    int? chapter,
    double? progress,
  }) {
    return LastOpenedChapter(
      type: type ?? this.type,
      chapter: chapter ?? this.chapter,
      progress: progress ?? this.progress,
    );
  }

  /// Loads the last-opened chapter from Hive. Returns null if none.
  ///
  /// Note: `HiveService.getLastOpenedChapter()` reads the 'settings' box,
  /// which must be open before this is called. The box is opened in
  /// `HiveService.initialize()` during app startup.
  static LastOpenedChapter? fromHive() {
    final raw = HiveService.getLastOpenedChapter();
    if (raw == null) return null;
    final type = raw['type'] as String;
    final chapter = raw['chapter'] as int;
    final progress = HiveService.getChapterProgress(type, chapter);
    return LastOpenedChapter(
      type: type,
      chapter: chapter,
      progress: progress,
    );
  }
}

/// Notifier that mirrors the "last opened chapter" state from Hive into
/// Riverpod so widgets (especially HomeScreen in the IndexedStack) rebuild
/// reactively when a chapter is opened or scrolled.
///
/// All writes are forwarded to [HiveService] so persistence behavior is
/// unchanged.
class LastOpenedChapterNotifier extends StateNotifier<LastOpenedChapter?> {
  LastOpenedChapterNotifier() : super(LastOpenedChapter.fromHive());

  /// Records that the user opened [type] chapter [chapter].
  /// Persists to Hive and updates in-memory state.
  void setOpened(String type, int chapter) {
    HiveService.setLastOpenedChapter(type, chapter);
    final progress = HiveService.getChapterProgress(type, chapter);
    state = LastOpenedChapter(
      type: type,
      chapter: chapter,
      progress: progress,
    );
  }

  /// Updates the scroll progress for [type] chapter [chapter].
  ///
  /// Always persists to Hive (so any chapter's progress can be queried
  /// later), but only updates in-memory [state] when this is the chapter
  /// currently shown on the Continue Learning card. Other chapters'
  /// scroll deltas are not relevant to the visible card.
  void updateProgress(String type, int chapter, double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    HiveService.setChapterProgress(type, chapter, clamped);
    if (state != null && state!.type == type && state!.chapter == chapter) {
      state = state!.copyWith(progress: clamped);
    }
  }
}

final lastOpenedChapterProvider =
    StateNotifierProvider<LastOpenedChapterNotifier, LastOpenedChapter?>(
  (ref) => LastOpenedChapterNotifier(),
);
