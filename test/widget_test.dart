import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:flutter_spoken_english_app/providers/last_opened_chapter_provider.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_widget_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await Hive.box('settings').clear();
  });

  test('lastOpenedChapterProvider exposes state through ProviderContainer', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Initial state is null when no chapter has been opened
    expect(container.read(lastOpenedChapterProvider), isNull);

    // setOpened updates state observable through the container
    container
        .read(lastOpenedChapterProvider.notifier)
        .setOpened('grammar', 3);
    final state = container.read(lastOpenedChapterProvider);
    expect(state, isNotNull);
    expect(state!.type, 'grammar');
    expect(state.chapter, 3);
    expect(state.progress, 0.0);
  });
}
