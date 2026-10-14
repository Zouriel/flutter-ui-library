import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

Future<UiSnackbarController> _host(WidgetTester tester, {double offset = 0}) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final c = UiSnackbarController();
  addTearDown(c.dispose);
  await tester.pumpWidget(UiApp(
    builder: (context, child) => UiSnackbarHost(controller: c, offset: offset, child: child!),
    home: const SizedBox.expand(),
  ));
  return c;
}

void main() {
  group('UiSnackbarController + UiSnackbarHost', () {
    testWidgets('one at a time: a new notice replaces the current one', (tester) async {
      final c = await _host(tester);
      c.show('Deleted “Title”');
      c.show('Deleted “Photo”');
      await tester.pumpAndSettle();
      expect(find.byType(UiSnackbar), findsOneWidget);
      expect(find.text('Deleted “Photo”'), findsOneWidget);
      c.dismiss();
      await tester.pumpAndSettle();
    });

    testWidgets('the action runs once and dismisses', (tester) async {
      final c = await _host(tester);
      var undone = 0;
      c.show('Deleted “Title”', action: UiSnackbarAction(label: 'Undo', run: () => undone++));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(c.current, isNull);
      expect(find.byType(UiSnackbar), findsNothing);
    });

    testWidgets('leaves after 4s, or 10s with an action', (tester) async {
      final c = await _host(tester);
      c.show('Saved');
      await tester.pump(const Duration(milliseconds: 3900));
      expect(c.current, isNotNull);
      await tester.pump(const Duration(milliseconds: 200));
      expect(c.current, isNull);
      c.show('Deleted', action: UiSnackbarAction(label: 'Undo', run: () {}));
      await tester.pump(const Duration(milliseconds: 9900));
      expect(c.current, isNotNull);
      await tester.pump(const Duration(milliseconds: 200));
      expect(c.current, isNull);
      await tester.pumpAndSettle();
    });

    testWidgets('pause holds it; resume continues with at least one second', (tester) async {
      final c = await _host(tester);
      c.show('Hold');
      await tester.pump(const Duration(milliseconds: 3700));
      c.pause();
      await tester.pump(const Duration(seconds: 10));
      expect(c.current, isNotNull);
      c.resume();
      await tester.pump(const Duration(milliseconds: 900));
      expect(c.current, isNotNull, reason: '300ms were left, but resuming gives at least a second');
      await tester.pump(const Duration(milliseconds: 200));
      expect(c.current, isNull);
      await tester.pumpAndSettle();
    });

    testWidgets('dismiss(id) only removes that notice', (tester) async {
      final c = await _host(tester);
      final first = c.show('One');
      c.show('Two');
      c.dismiss(first);
      expect(c.current?.message, 'Two');
      c.dismiss();
      await tester.pumpAndSettle();
    });

    testWidgets('sits centred at the bottom, lifted by offset', (tester) async {
      final c = await _host(tester, offset: 76);
      c.show('Grouped', duration: Duration.zero);
      await tester.pumpAndSettle();
      final r = tester.getRect(find.byType(UiSnackbar));
      expect(r.center.dx, closeTo(195, 0.5));
      final t = tester.element(find.byType(UiSnackbar)).ui;
      expect(r.bottom, closeTo(844 - t.space4 - 76, 0.5));
    });

    testWidgets('each notice is a live region with its title and message', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await _host(tester);
      c.show('Move it to trim further.', title: 'Stopped at a keyframe', duration: Duration.zero);
      await tester.pumpAndSettle();
      final data = tester.getSemantics(find.byType(UiSnackbar)).getSemanticsData();
      expect(data.flagsCollection.isLiveRegion, isTrue);
      expect(data.label, contains('Stopped at a keyframe'));
      expect(data.label, contains('Move it to trim further.'));
      handle.dispose();
    });

    testWidgets('meets the tap-target, label and contrast guidelines', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final handle = tester.ensureSemantics();
      final c = await _host(tester);
      c.show('Deleted “Title”', action: UiSnackbarAction(label: 'Undo', run: () {}), duration: Duration.zero);
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  testWidgets('golden: plain, with Undo, with a title', (tester) async {
    await expectThemedGolden(tester, 'snackbars', height: 260, (context) => Column(spacing: 8, children: [
          const UiSnackbar(message: 'Grouped'),
          UiSnackbar(message: 'Deleted “Title”', actionLabel: 'Undo', onAction: () {}),
          const UiSnackbar(title: 'Stopped at a keyframe', message: 'Move or delete that keyframe to trim further.'),
        ]));
  });
}
