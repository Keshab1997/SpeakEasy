import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_spoken_english_app/features/game/screens/modes/fill_in_blanks_mode.dart';

void main() {
  testWidgets('shows Bengali meaning and fits answers on a compact screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: FillInBlanksModeScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('বাংলা অর্থ'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);

    final optionFinder = find.byWidgetPredicate(
      (widget) =>
          widget is InkWell &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
                'fill-blank-option-',
              ),
    );
    expect(optionFinder, findsNWidgets(4));
    expect(
        tester.getRect(find.text('বাংলা অর্থ')).bottom, lessThanOrEqualTo(640));
    for (final element in tester.widgetList<InkWell>(optionFinder)) {
      final rect = tester.getRect(find.byWidget(element));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(640));
    }

    tester.view.physicalSize = const Size(360, 568);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
        tester.getRect(find.text('বাংলা অর্থ')).bottom, lessThanOrEqualTo(568));
    for (final element in tester.widgetList<InkWell>(optionFinder)) {
      expect(
        tester.getRect(find.byWidget(element)).bottom,
        lessThanOrEqualTo(568),
      );
    }
  });
}
