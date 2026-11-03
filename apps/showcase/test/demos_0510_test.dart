import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/media_page.dart';

/// 0.51.0 showcase demo: long-press select in the media page's album, the bar, and the fake save job.

void main() {
  testWidgets('media page: hold a photo, tap another, Save to gallery runs the job dialog to the end', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const UiApp(home: MediaPage()));
    await tester.pump(const Duration(milliseconds: 300));

    final p1 = find.bySemanticsLabel('Photo 1');
    await tester.ensureVisible(find.byType(UiSelectable).first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(UiSelectionBar), findsNothing);
    await tester.longPress(p1);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.bySemanticsLabel('Photo 2'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel('2 selected'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final save = find.byWidgetPredicate((w) => (w is UiIconButton && w.label == 'Save to gallery') || (w is UiButton && w.label == 'Save to gallery'));
    expect(save, findsOneWidget);
    await tester.ensureVisible(save);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(UiTaskProgress), findsOneWidget);
    expect(find.text('Saving 2 photos'), findsOneWidget);
    // Two files at 120ms each, then the dialog closes and the selection ends.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(UiTaskProgress), findsNothing);
    expect(find.byType(UiSelectionBar), findsNothing);
    expect(find.text('Saved 2 photos.'), findsOneWidget);
  });
}
