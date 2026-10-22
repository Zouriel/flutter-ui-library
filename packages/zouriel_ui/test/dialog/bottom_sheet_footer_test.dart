import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// 0.44.0 (visit UX L3): UiBottomSheet.footer, and (L4) UiFloatingPanel.insetEnd.

class _Host {
  int snap = 1;
  List<double> snaps = const [0.15, 0.5, 0.9];
  double keyboard = 0;
  final covers = <double>[];
  final sheet = GlobalKey<UiBottomSheetState>();
  late StateSetter set;
}

Future<_Host> _pump(WidgetTester tester, {bool footer = true, double safeBottom = 20, bool glass = false, UiGlassStrength strength = UiGlassStrength.clear}) async {
  final h = _Host();
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(StatefulBuilder(builder: (context, set) {
    h.set = set;
    return UiApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            padding: EdgeInsets.only(bottom: safeBottom),
            viewInsets: EdgeInsets.only(bottom: h.keyboard),
          ),
          child: Stack(children: [
            const SizedBox.expand(),
            UiBottomSheet(
              key: h.sheet,
              title: 'Visit',
              snaps: h.snaps,
              snap: h.snap,
              onSnapChanged: (i) => set(() => h.snap = i),
              onCoverChanged: h.covers.add,
              glass: glass,
              glassStrength: strength,
              footer: footer ? UiButton(label: 'Start the visit', block: true, onPressed: () {}) : null,
              child: Column(children: [for (var i = 0; i < 40; i++) SizedBox(height: 40, child: Text('Line $i'))]),
            ),
          ]),
        ),
      ),
    );
  }));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  return h;
}

Rect _footer(WidgetTester tester) => tester.getRect(find.byKey(const ValueKey('ui-bottom-sheet-footer')));

void main() {
  testWidgets('the footer sits at the bottom of the visible sheet at every snap, the safe area under its padding', (tester) async {
    final h = await _pump(tester);
    for (final snap in [1, 2, 0]) {
      h.set(() => h.snap = snap);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_footer(tester).bottom, 844, reason: 'snap $snap');
      expect(tester.getRect(find.widgetWithText(UiButton, 'Start the visit')).bottom, lessThanOrEqualTo(844 - 20 - 12 + 0.5), reason: 'snap $snap');
      // Hit-testable: the button is really on top.
      expect(find.text('Start the visit').hitTestable(), findsOneWidget, reason: 'snap $snap');
    }
  });

  testWidgets('a peek too short for the header and the footer is raised to fit them', (tester) async {
    final h = await _pump(tester);
    h.set(() => h.snap = 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // 15% of 844 is 127px: less than the handle, title row, hairline and footer.
    final sheetTop = tester.getTopLeft(find.text('Visit')).dy;
    final f = _footer(tester);
    expect(f.top, greaterThan(sheetTop + 16));
    expect(844 - f.top, greaterThan(60));
    // The cover counts all of it.
    expect(h.covers.last, greaterThan(844 * 0.15 + 1));
    expect(h.covers.last, closeTo(844 - (sheetTop - 30), 40));
  });

  testWidgets('the body scrolls above the footer: its last line can be read', (tester) async {
    final h = await _pump(tester);
    h.set(() => h.snap = 2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.drag(find.text('Line 5'), const Offset(0, -3000));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getRect(find.text('Line 39')).bottom, lessThanOrEqualTo(_footer(tester).top + 0.5));
  });

  testWidgets('with the keyboard up the footer rests on the keyboard, no safe-area padding', (tester) async {
    final h = await _pump(tester);
    h.set(() => h.keyboard = 300);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final f = _footer(tester);
    expect(f.bottom, 844 - 300);
    expect(tester.getRect(find.widgetWithText(UiButton, 'Start the visit')).bottom, closeTo(844 - 300 - 12, 0.5));
  });

  testWidgets('on a glass sheet the footer is frosted whatever glassStrength, so the body never shows through (0.44.2)', (tester) async {
    for (final strength in UiGlassStrength.values) {
      await _pump(tester, glass: true, strength: strength);
      final t = tester.element(find.byType(UiBottomSheet)).ui;
      final bar = find.byKey(const ValueKey('ui-bottom-sheet-footer'));
      final filters = tester.widgetList<BackdropFilter>(find.descendant(of: bar, matching: find.byType(BackdropFilter))).toList();
      expect(filters, hasLength(1), reason: '$strength: one backdrop filter under the footer');
      expect(filters.single.filter, uiGlassSheetFilter(t, strength: UiGlassStrength.frosted), reason: '$strength: the frosted filter');
      final fills = tester
          .widgetList<DecoratedBox>(find.descendant(of: bar, matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color)
          .toList();
      expect(fills.first, t.glassSheetBg, reason: '$strength: the frosted tint');
    }
    // The two strengths really differ, so the checks above can tell them apart.
    final t = tester.element(find.byType(UiBottomSheet)).ui;
    expect(uiGlassSheetFilter(t, strength: UiGlassStrength.clear), isNot(uiGlassSheetFilter(t, strength: UiGlassStrength.frosted)));
    expect(t.glassClearBg, isNot(t.glassSheetBg));
  });

  testWidgets('without a footer nothing changes: the given snaps', (tester) async {
    final h = await _pump(tester, footer: false);
    h.set(() => h.snap = 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('ui-bottom-sheet-footer')), findsNothing);
    expect(h.covers.last, closeTo(844 * 0.15, 0.5));
    expect(h.sheet.currentState!.footerHeight, 0);
  });

  group('UiFloatingPanel.insetEnd', () {
    Future<Rect> panel(WidgetTester tester, {double insetEnd = 0, TextDirection dir = TextDirection.ltr}) async {
      tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
          child: Directionality(
            textDirection: dir,
            child: Stack(children: [
              const SizedBox.expand(),
              UiFloatingPanel(placement: UiFloatingPanelPlacement.top, insetEnd: insetEnd, semanticLabel: 'Visit', child: const Text('On the way')),
            ]),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      return tester.getRect(find.ancestor(of: find.text('On the way'), matching: find.byType(DecoratedBox)).first);
    }

    testWidgets('keeps that many px free at the inline end, mirrored in RTL', (tester) async {
      final plain = await panel(tester);
      expect(plain.left, 16);
      expect(plain.right, 390 - 16);
      final ltr = await panel(tester, insetEnd: 72);
      expect(ltr.left, 16);
      expect(ltr.right, 390 - 16 - 72);
      final rtl = await panel(tester, insetEnd: 72, dir: TextDirection.rtl);
      expect(rtl.left, 16 + 72);
      expect(rtl.right, 390 - 16);
    });
  });

  testWidgets('golden: a sheet at its peek with a footer', (tester) async {
    await expectThemedGolden(
      tester,
      'bottom_sheet_footer',
      (context) => Stack(children: [
        const SizedBox.expand(),
        UiBottomSheet(
          title: 'Aminath is on the way',
          snaps: const [0.3, 0.9],
          footer: UiButton(label: 'Message the nurse', block: true, onPressed: () {}),
          child: const Text('Arriving in about 8 minutes.'),
        ),
      ]),
      height: 420,
    );
  });
}
