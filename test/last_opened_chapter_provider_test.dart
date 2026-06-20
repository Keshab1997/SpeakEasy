import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:flutter_spoken_english_app/providers/last_opened_chapter_provider.dart';

void main() {
  late Directory tempDir;
  late Box settingsBox;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_test_');
    Hive.init(tempDir.path);
    settingsBox = await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    await settingsBox.clear();
  });

  group('LastOpenedChapterNotifier', () {
    test('initial state is null when no chapter has been opened', () {
      final notifier = LastOpenedChapterNotifier();
      expect(notifier.state, isNull);
    });

    test('setOpened updates state with type, chapter, and zero progress', () {
      final notifier = LastOpenedChapterNotifier();
      notifier.setOpened('grammar', 3);
      expect(notifier.state, isNotNull);
      expect(notifier.state!.type, 'grammar');
      expect(notifier.state!.chapter, 3);
      expect(notifier.state!.progress, 0.0);
    });

    test('updateProgress updates state.progress when chapter matches', () {
      final notifier = LastOpenedChapterNotifier();
      notifier.setOpened('grammar', 3);
      notifier.updateProgress('grammar', 3, 0.5);
      expect(notifier.state!.progress, 0.5);
    });

    test('updateProgress does NOT update state when chapter differs', () {
      final notifier = LastOpenedChapterNotifier();
      notifier.setOpened('grammar', 3);
      notifier.updateProgress('grammar', 5, 0.7);
      expect(notifier.state!.chapter, 3);
      expect(notifier.state!.progress, 0.0);
    });

    test('setOpened replaces previous last-opened chapter', () {
      final notifier = LastOpenedChapterNotifier();
      notifier.setOpened('grammar', 3);
      notifier.setOpened('vocabulary', 7);
      expect(notifier.state!.type, 'vocabulary');
      expect(notifier.state!.chapter, 7);
    });

    test('updateProgress clamps progress to [0.0, 1.0]', () {
      final notifier = LastOpenedChapterNotifier();
      notifier.setOpened('grammar', 3);
      notifier.updateProgress('grammar', 3, 1.5);
      expect(notifier.state!.progress, 1.0);
      notifier.updateProgress('grammar', 3, -0.5);
      expect(notifier.state!.progress, 0.0);
    });
  });
}
