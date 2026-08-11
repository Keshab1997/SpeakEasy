import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:flutter_spoken_english_app/core/theme/light_theme.dart';
import 'package:flutter_spoken_english_app/core/utils/grammar_text_parser.dart';
import 'package:flutter_spoken_english_app/features/grammar/screens/grammar_detail_screen.dart';
import 'package:flutter_spoken_english_app/models/grammar_chapter_model.dart';

GrammarChapter _loadAlphabetChapter() {
  final raw = File('assets/json/grammar/chapter_01_alphabet.json')
      .readAsStringSync();
  return GrammarChapter.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    // The detail screen persists scroll position via Hive on init/dispose,
    // so the boxes it touches must exist before pumping the widget.
    tempDir = Directory.systemTemp.createTempSync('grammar_detail_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
    await Hive.openBox('vocab_cache');
  });

  tearDownAll(() async {
    // NOTE: no Hive.close()/deleteFromDisk() here. The screen keeps Hive
    // boxes open and its dispose() runs real file I/O inside flutter_test's
    // fake-async zone; trying to close/delete the DB in suite teardown wedges
    // the runner. The temp dir is disposable.
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('Parser renders each Alphabet chapter string as one clean span', () {
    final chapter = _loadAlphabetChapter();
    final texts = <String>[
      chapter.title,
      chapter.description,
      chapter.banglaDescription,
      ...chapter.topics.expand((t) => [
            t.name,
            t.banglaName,
            t.definition,
            t.banglaDefinition,
            t.formula,
            t.tips,
            ...t.rules,
            ...t.examples.expand((e) => [e.en, e.bn]),
          ]),
      ...chapter.commonMistakes.expand((m) => [
            m.wrong,
            m.correct,
            m.explanation,
          ]),
    ];

    for (final text in texts) {
      if (text.isEmpty) continue;
      final span = GrammarTextParser.highlightAuto(text);
      expect(span, isA<TextSpan>());
      final ts = span as TextSpan;
      // Single run: no per-word spans, so Bengali shaping is never split.
      expect(ts.children, isNull,
          reason: '"$text" must stay a single clean run');
      expect(ts.style?.backgroundColor, isNull,
          reason: '"$text" must have no highlight box behind words');
    }
  });

  testWidgets('Alphabet → Vowels lesson renders clean Bengali text',
      (tester) async {
    // Phone-like surface so multi-line Bengali wrapping is exercised.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final chapter = _loadAlphabetChapter();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: lightTheme,
          home: GrammarDetailScreen(chapter: chapter),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The Vowels topic sits below the fold: keep scrolling until its card is
    // built and visible, then confirm it renders with the Bengali font.
    final vowelsTitle = find.textContaining('স্বরধ্বনি');
    await tester.scrollUntilVisible(
      vowelsTitle.first,
      400,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Let the scroll-position debounce timer fire and persist.
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull,
        reason: 'scrolling to the Vowels lesson must not overflow/clip');
    expect(vowelsTitle, findsWidgets,
        reason: 'Vowels topic must be reachable on the page');

    // Bengali titles must use the bundled Noto Sans Bengali family.
    final bengaliTexts = tester.widgetList<Text>(find.byWidgetPredicate(
        (w) => w is Text && (w.data?.contains('স্বরধ্বনি') ?? false)));
    expect(bengaliTexts, isNotEmpty);
    expect(bengaliTexts.first.style?.fontFamily, 'NotoSansBengali');

    // Every built rich-text run must be free of background highlight boxes.
    for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
      final spans = <TextSpan>[];
      rt.text.visitChildren((span) {
        if (span is TextSpan) spans.add(span);
        return true;
      });
      for (final span in spans) {
        expect(span.style?.backgroundColor, isNull,
            reason: 'no colored highlight box behind words');
      }
    }

    // Unmount the screen while the test still controls the clock so the
    // State.dispose() Hive write is drained inside FakeAsync instead of in
    // suite teardown (which would hang on the real file I/O).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
  });
}