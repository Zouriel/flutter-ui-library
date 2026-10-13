import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

Widget box(String k, {double h = 20}) => SizedBox(key: ValueKey(k), height: h);

void main() {
  group('UiGrid', () {
    testWidgets('fixed columns share the width and the gap', (tester) async {
      await pumpUi(tester, SizedBox(width: 316, child: UiGrid(columns: 3, gap: 4, children: [for (var i = 0; i < 5; i++) box('$i')])));
      // (316 - 2 * 16) / 3 = 94.67
      expect(tester.getSize(find.byKey(const ValueKey('0'))).width, closeTo(94.67, 0.01));
      expect(tester.getTopLeft(find.byKey(const ValueKey('1'))).dx - tester.getTopRight(find.byKey(const ValueKey('0'))).dx, closeTo(16, 0.01));
      // The fourth child starts the second row, one gap below the first.
      expect(tester.getTopLeft(find.byKey(const ValueKey('3'))).dy - tester.getBottomLeft(find.byKey(const ValueKey('0'))).dy, closeTo(16, 0.01));
    });

    testWidgets('minColumnWidth fits as many columns as there is room for', (tester) async {
      Future<int> cols(double w, {int n = 8}) async {
        await pumpUi(tester, SizedBox(width: w, child: UiGrid(minColumnWidth: 100, gap: 2, children: [for (var i = 0; i < n; i++) box('$i')])));
        final y0 = tester.getTopLeft(find.byKey(const ValueKey('0'))).dy;
        var c = 0;
        for (var i = 0; i < n; i++) {
          if (tester.getTopLeft(find.byKey(ValueKey('$i'))).dy == y0) c++;
        }
        return c;
      }

      expect(await cols(390), 3); // (390 + 8) / 108 = 3.68
      expect(await cols(216), 2);
      expect(await cols(90), 1);
      // auto-fit: two children in room for three widen to fill the row.
      await pumpUi(tester, SizedBox(width: 390, child: UiGrid(minColumnWidth: 100, gap: 2, children: [box('a'), box('b')])));
      expect(tester.getSize(find.byKey(const ValueKey('a'))).width, closeTo(191, 0.01));
    });

    testWidgets('cells in a row stretch to the tallest', (tester) async {
      await pumpUi(tester, SizedBox(width: 300, child: UiGrid(columns: 2, children: [box('short', h: 10), box('tall', h: 60)])));
      expect(tester.getSize(find.byKey(const ValueKey('short'))).height, 60);
    });
  });

  testWidgets('UiStack: column stretches, row hugs, gap is the token step', (tester) async {
    await pumpUi(tester, SizedBox(width: 200, child: UiStack(gap: 2, children: [box('a'), box('b')])));
    expect(tester.getSize(find.byKey(const ValueKey('a'))).width, 200);
    expect(tester.getTopLeft(find.byKey(const ValueKey('b'))).dy - tester.getBottomLeft(find.byKey(const ValueKey('a'))).dy, 8);
    await pumpUi(tester, UiStack(direction: Axis.horizontal, align: UiStackAlign.center, gap: 4, children: [
      const SizedBox(key: ValueKey('x'), width: 10, height: 10),
      const SizedBox(key: ValueKey('y'), width: 10, height: 30),
    ]));
    expect(tester.getTopLeft(find.byKey(const ValueKey('y'))).dx - tester.getTopRight(find.byKey(const ValueKey('x'))).dx, 16);
    expect(tester.getCenter(find.byKey(const ValueKey('x'))).dy, tester.getCenter(find.byKey(const ValueKey('y'))).dy);
    expect(() => uiSpace(uiThemeTokens[UiThemeName.dark]!, 5), throwsArgumentError);
  });

  testWidgets('UiSpacer pushes siblings apart', (tester) async {
    await pumpUi(tester, SizedBox(width: 300, child: Row(children: [box('a', h: 10).sized(20), const UiSpacer(), box('b', h: 10).sized(20)])));
    expect(tester.getTopRight(find.byKey(const ValueKey('b'))).dx, 300);
  });

  testWidgets('UiContainer caps the width and centres', (tester) async {
    await pumpUi(tester, SizedBox(width: 1000, child: UiContainer(size: UiContainerSize.sm, child: box('c'))), size: const Size(1000, 600));
    // 640 max, minus 16px padding each side.
    expect(tester.getSize(find.byKey(const ValueKey('c'))).width, 608);
    expect(tester.getTopLeft(find.byKey(const ValueKey('c'))).dx, 180 + 16);
  });

  testWidgets('UiAspectRatio holds the ratio and fills its child', (tester) async {
    await pumpUi(tester, SizedBox(width: 320, child: UiAspectRatio(ratio: 16 / 9, child: Container(key: const ValueKey('img')))));
    expect(tester.getSize(find.byKey(const ValueKey('img'))), const Size(320, 180));
  });

  testWidgets('UiScrollArea caps the height and scrolls the chosen axis', (tester) async {
    await pumpUi(tester, SizedBox(width: 200, child: UiScrollArea(maxHeight: 100, child: Column(children: [for (var i = 0; i < 10; i++) box('r$i')]))));
    expect(tester.getSize(find.byType(UiScrollArea)).height, 100);
    await tester.drag(find.byType(UiScrollArea), const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('r0'))).dy, lessThan(0));
    // Short content hugs.
    await pumpUi(tester, SizedBox(width: 200, child: UiScrollArea(maxHeight: 100, child: box('only'))));
    expect(tester.getSize(find.byType(UiScrollArea)).height, 20);
  });

  group('UiPanelSection', () {
    testWidgets('the heading toggles the body and announces expanded', (tester) async {
      final handle = tester.ensureSemantics();
      final changes = <bool>[];
      await pumpUi(tester, SizedBox(width: 300, child: UiPanelSection(title: 'Layers', badge: '4', onOpenChanged: changes.add, child: const UiText('Body'))));
      expect(find.text('Body'), findsOneWidget);
      expect(find.text('LAYERS'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Layers').first), matchesSemantics(label: 'Layers', isButton: true, hasExpandedState: true, isExpanded: true, hasTapAction: true, isFocusable: true, hasEnabledState: true, isEnabled: true, hasFocusAction: true));
      await tester.tap(find.text('LAYERS'));
      await tester.pumpAndSettle();
      expect(find.text('Body'), findsNothing);
      expect(changes, [false]);
      handle.dispose();
    });

    testWidgets('controlled open follows the parent; non-collapsible always shows', (tester) async {
      await pumpUi(tester, SizedBox(width: 300, child: Column(children: const [
        UiPanelSection(title: 'Shut', open: false, child: Text('hidden')),
        UiPanelSection(title: 'Fixed', collapsible: false, open: false, child: Text('shown')),
      ])));
      expect(find.text('hidden'), findsNothing);
      expect(find.text('shown'), findsOneWidget);
      await tester.tap(find.text('SHUT'));
      await tester.pump();
      expect(find.text('hidden'), findsNothing, reason: 'controlled: the parent decides');
    });

    testWidgets('heading is a 48dp target on Android and meets guidelines', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final handle = tester.ensureSemantics();
      await pumpUi(tester, SizedBox(width: 300, child: UiPanelSection(title: 'Fill', child: const UiText('x'))));
      expect(tester.getSize(find.byType(UiInteractive)).height, 48);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('UiSidebarLayout', () {
    Widget shell({bool? open, ValueChanged<bool>? onOpen, GlobalKey<UiSidebarLayoutState>? key}) => UiSidebarLayout(
          key: key,
          open: open,
          onOpenChanged: onOpen,
          sidebar: const Text('NAV'),
          header: const Text('Title'),
          body: const Text('Page'),
        );

    testWidgets('wide: sidebar beside the page, no menu button', (tester) async {
      await pumpUi(tester, SizedBox(width: 1000, height: 600, child: shell()), size: const Size(1000, 600));
      expect(find.bySemanticsLabel('Toggle navigation'), findsNothing);
      expect(tester.getTopLeft(find.text('NAV')).dx, 0);
      expect(tester.getTopLeft(find.text('Page')).dx, greaterThan(248));
    });

    testWidgets('narrow: menu opens a drawer; backdrop, Escape and back close it', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, SizedBox(width: 390, height: 700, child: shell()));
      expect(tester.getTopLeft(find.text('NAV')).dx, lessThan(0));
      expect(find.semantics.byLabel('Page'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Toggle navigation'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('NAV')).dx, greaterThanOrEqualTo(0));
      // The page behind is hidden from screen readers while the drawer is open.
      expect(find.semantics.byLabel('Page'), findsNothing);
      await tester.tapAt(const Offset(370, 400));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('NAV')).dx, lessThan(0), reason: 'backdrop');

      await tester.tap(find.bySemanticsLabel('Toggle navigation'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('NAV')).dx, lessThan(0), reason: 'escape');

      await tester.tap(find.bySemanticsLabel('Toggle navigation'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('NAV')).dx, lessThan(0));
      handle.dispose();
    });

    testWidgets('controlled open + state methods', (tester) async {
      final key = GlobalKey<UiSidebarLayoutState>();
      final changes = <bool>[];
      await pumpUi(tester, SizedBox(width: 390, height: 700, child: shell(key: key, onOpen: changes.add)));
      key.currentState!.toggle();
      await tester.pumpAndSettle();
      expect(key.currentState!.isOpen, isTrue);
      key.currentState!.close();
      await tester.pumpAndSettle();
      expect(changes, [true, false]);
      await pumpUi(tester, SizedBox(width: 390, height: 700, child: shell(open: true)));
      expect(tester.getTopLeft(find.text('NAV')).dx, greaterThanOrEqualTo(0));
    });

    testWidgets('menu button meets the touch guidelines', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final handle = tester.ensureSemantics();
      await pumpUi(tester, SizedBox(width: 390, height: 700, child: shell()));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('UiSplitter', () {
    testWidgets('drag moves the divider within 10–90%, keys nudge by 2%', (tester) async {
      final ratios = <double>[];
      await pumpUi(tester, SizedBox(width: 380, height: 200, child: UiSplitter(
        onRatioChanged: ratios.add,
        first: const SizedBox.expand(key: ValueKey('a')),
        second: const SizedBox.expand(key: ValueKey('b')),
      )));
      expect(tester.getSize(find.byKey(const ValueKey('a'))).width, closeTo(189.5, 0.01));
      await tester.dragFrom(const Offset(190, 100), const Offset(-95, 0));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const ValueKey('a'))).width, closeTo(94.75, 1));
      await tester.dragFrom(Offset(tester.getSize(find.byKey(const ValueKey('a'))).width, 100), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(ratios.last, 10);

      final handle = tester.ensureSemantics();
      final slider = find.bySemanticsLabel('Resize panes');
      expect(tester.getSemantics(slider).value, '10%');
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(ratios.last, 12);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(ratios.last, 10);
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
      handle.dispose();
    });

    testWidgets('vertical splitter stacks the panes', (tester) async {
      await pumpUi(tester, SizedBox(width: 300, height: 401, child: UiSplitter(
        axis: Axis.vertical,
        initialRatio: 25,
        first: const SizedBox.expand(key: ValueKey('a')),
        second: const SizedBox.expand(key: ValueKey('b')),
      )));
      expect(tester.getSize(find.byKey(const ValueKey('a'))), const Size(300, 100));
      expect(tester.getSize(find.byKey(const ValueKey('b'))), const Size(300, 300));
    });
  });

  group('UiResizeHandle', () {
    testWidgets('dragging away from the panel grows it; release snaps; keys step', (tester) async {
      var size = 200.0;
      final ends = <double>[];
      await pumpUi(tester, StatefulBuilder(builder: (context, set) => SizedBox(width: 300, child: UiResizeHandle(
        size: size,
        min: 100,
        max: 400,
        snaps: const [240, 320],
        onChanged: (v) => set(() => size = v),
        onResizeEnd: ends.add,
      ))));
      await tester.drag(find.byType(UiResizeHandle), const Offset(0, -30));
      await tester.pumpAndSettle();
      expect(size, 240, reason: '230 is within 28 of the 240 snap');
      expect(ends.last, 240);
      await tester.drag(find.byType(UiResizeHandle), const Offset(0, 300));
      expect(size, 100, reason: 'clamped to min');
      await tester.pump();

      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(size, 116);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(size, 400);
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
      await tester.tap(find.byType(UiResizeHandle));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(UiResizeHandle));
      await tester.pumpAndSettle();
      expect(size, 240, reason: 'double tap cycles to the first snap past the end');
    });
  });

  testWidgets('golden: grid, stack, panel sections, splitter, resize handle', (tester) async {
    await expectThemedGolden(tester, 'layout', height: 610, (context) {
      final t = context.ui;
      Widget cell(String s) => Container(
            padding: EdgeInsets.all(t.space2),
            decoration: BoxDecoration(color: t.surfaceRaised, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radiusSm)),
            child: UiText(s, variant: UiTextVariant.caption),
          );
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
        UiGrid(minColumnWidth: 90, gap: 2, children: [for (var i = 1; i <= 5; i++) cell(i == 2 ? 'Cell $i\nwith two lines' : 'Cell $i')]),
        UiStack(direction: Axis.horizontal, gap: 2, children: [cell('Left'), const UiSpacer(), cell('Right')]).withFixedRow(),
        DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
          child: Column(children: [
            UiPanelSection(title: 'Sections', badge: '4', actions: [UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedAdd01), label: 'Add', size: UiSize.sm, onPressed: () {})], child: const UiText('Hero, About, Gallery, RSVP')),
            const UiPanelSection(title: 'Theme colours', initiallyOpen: false, child: SizedBox()),
            const UiPanelSection(title: 'Layout', collapsible: false, child: UiText('Always shown')),
          ]),
        ),
        SizedBox(height: 90, child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: t.border)),
          child: UiSplitter(initialRatio: 35, first: Center(child: cell('Pane A')), second: Center(child: cell('Pane B'))),
        )),
        UiResizeHandle(size: 200, onChanged: (_) {}),
      ]);
    });
  });
}

extension on Widget {
  Widget sized(double w) => SizedBox(width: w, child: this);
  Widget withFixedRow() => SizedBox(width: double.infinity, child: Row(children: [Expanded(child: this)]));
}
