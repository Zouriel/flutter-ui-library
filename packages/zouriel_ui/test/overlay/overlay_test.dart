import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'screens.dart';

const _items = [
  UiMenuItem(label: 'Edit', value: 'edit', icon: HugeIcons.strokeRoundedEdit02),
  UiMenuItem(label: 'Archive', value: 'archive', disabled: true),
  UiMenuItem(label: 'Share', value: 'share'),
  UiMenuItem(label: 'Delete', value: 'delete', danger: true),
];

Future<void> _place(WidgetTester tester, Alignment where, Widget child) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(home: Align(alignment: where, child: child)));
  await tester.pumpAndSettle();
}

void main() {
  group('UiTooltip', () {
    Widget anchor({UiTooltipPosition position = UiTooltipPosition.top, double w = 80, double h = 30}) => UiTooltip(
          message: 'Helpful text',
          position: position,
          child: SizedBox(key: const Key('anchor'), width: w, height: h),
        );

    testWidgets('a mouse hover shows it above the anchor; leaving hides it', (tester) async {
      await _place(tester, Alignment.center, anchor());
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(const Key('anchor'))));
      await tester.pumpAndSettle();
      expect(find.text('Helpful text'), findsOneWidget);
      final panel = tester.getRect(find.byType(UiTooltipPanel));
      expect(panel.bottom, tester.getRect(find.byKey(const Key('anchor'))).top - 4);
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(find.text('Helpful text'), findsNothing);
    });

    testWidgets('long-press shows it on touch and it hides after touchDuration', (tester) async {
      await _place(tester, Alignment.center, anchor());
      await tester.longPress(find.byKey(const Key('anchor')));
      await tester.pump();
      expect(find.text('Helpful text'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1400));
      expect(find.text('Helpful text'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('Helpful text'), findsNothing);
    });

    testWidgets('keyboard focus shows it and Escape hides it', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      await _place(tester, Alignment.center, UiTooltip(message: 'Save the file', child: UiButton(label: 'Save', focusNode: node, onPressed: () {})));
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text('Save the file'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Save the file'), findsNothing);
    });

    testWidgets('flips below when there is no room above', (tester) async {
      await _place(tester, Alignment.topCenter, anchor());
      await tester.longPress(find.byKey(const Key('anchor')));
      await tester.pump();
      expect(tester.getRect(find.byType(UiTooltipPanel)).top, tester.getRect(find.byKey(const Key('anchor'))).bottom + 4);
    });

    testWidgets('never covers its anchor: a tall anchor sends it to a side', (tester) async {
      // Nearly full-height anchor: no room above or below, so it goes to the right.
      await _place(tester, Alignment.centerLeft, anchor(h: 820, w: 100));
      await tester.longPress(find.byKey(const Key('anchor')));
      await tester.pump();
      final a = tester.getRect(find.byKey(const Key('anchor')));
      final p = tester.getRect(find.byType(UiTooltipPanel));
      expect(p.overlaps(a), isFalse);
      expect(p.left, a.right + 4);
    });

    testWidgets('the layout keeps 8px from the screen edge along its side', (tester) async {
      await _place(tester, Alignment.topRight, Padding(padding: const EdgeInsets.only(top: 100), child: anchor(w: 20)));
      await tester.longPress(find.byKey(const Key('anchor')));
      await tester.pump();
      expect(tester.getRect(find.byType(UiTooltipPanel)).right, 390 - 8);
    });

    testWidgets('screen readers get the text as the anchor\'s tooltip', (tester) async {
      final handle = tester.ensureSemantics();
      await _place(tester, Alignment.center, UiTooltip(message: 'Delete forever', child: UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedDelete02), label: 'Delete', onPressed: () {})));
      final data = tester.getSemantics(find.byType(UiIconButton)).getSemanticsData();
      expect(data.tooltip, 'Delete forever');
      expect(data.label, 'Delete');
      handle.dispose();
    });

    testWidgets('an empty message shows nothing', (tester) async {
      await _place(tester, Alignment.center, const UiTooltip(message: '', child: SizedBox(key: Key('anchor'), width: 80, height: 30)));
      await tester.longPress(find.byKey(const Key('anchor')));
      await tester.pump();
      expect(find.byType(UiTooltipPanel), findsNothing);
    });
  });

  group('UiPopover', () {
    Widget pop({String? label = 'Filters', UiPopoverPlacement placement = UiPopoverPlacement.bottomStart, FocusNode? trigger, FocusNode? inner}) => UiPopover(
          label: label,
          placement: placement,
          builder: (context, toggle, open) => UiButton(label: open ? 'Close' : 'Open', focusNode: trigger, onPressed: toggle),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Panel body'),
            UiButton(label: 'Inside', focusNode: inner, onPressed: () {}),
          ]),
        );

    testWidgets('the trigger toggles it; an outside tap closes it', (tester) async {
      await _place(tester, Alignment.topLeft, Padding(padding: const EdgeInsets.all(40), child: pop()));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Panel body'), findsOneWidget);
      expect(tester.getRect(find.text('Panel body')).top, greaterThan(tester.getRect(find.text('Close')).bottom));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Panel body'), findsNothing);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(300, 700));
      await tester.pumpAndSettle();
      expect(find.text('Panel body'), findsNothing);
    });

    testWidgets('does not take focus; Escape from inside returns it to the trigger', (tester) async {
      final trigger = FocusNode(), inner = FocusNode();
      addTearDown(trigger.dispose);
      addTearDown(inner.dispose);
      await _place(tester, Alignment.center, pop(trigger: trigger, inner: inner));
      trigger.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Panel body'), findsOneWidget);
      expect(trigger.hasPrimaryFocus, isTrue, reason: 'opening does not move focus');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(inner.hasPrimaryFocus, isTrue, reason: 'Tab reaches the panel after the trigger');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Panel body'), findsNothing);
      expect(trigger.hasPrimaryFocus, isTrue);
    });

    testWidgets('the panel is a dialog named by its label', (tester) async {
      final handle = tester.ensureSemantics();
      await _place(tester, Alignment.center, pop());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Filters'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('top placement opens above; near the bottom bottom-start flips above', (tester) async {
      await _place(tester, Alignment.center, KeyedSubtree(key: const Key('a'), child: pop(placement: UiPopoverPlacement.top)));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(UiFloatingPanel)).bottom, lessThanOrEqualTo(tester.getRect(find.text('Close')).top));
      await _place(tester, Alignment.bottomLeft, KeyedSubtree(key: const Key('b'), child: pop()));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(UiFloatingPanel)).bottom, lessThanOrEqualTo(tester.getRect(find.text('Close')).top));
    });

    testWidgets('controlled: open and onOpenChanged', (tester) async {
      var open = true;
      final log = <bool>[];
      await _place(tester, Alignment.center, StatefulBuilder(builder: (context, set) => UiPopover(
            open: open,
            onOpenChanged: (v) {
              log.add(v);
              set(() => open = v);
            },
            label: 'Info',
            builder: (context, toggle, o) => UiButton(label: 'Toggle', onPressed: toggle),
            content: const Text('Shown'),
          )));
      await tester.pumpAndSettle();
      expect(find.text('Shown'), findsOneWidget);
      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();
      expect(find.text('Shown'), findsNothing);
      expect(log, [false]);
    });
  });

  group('UiMenu', () {
    Widget menu(List<String> log, {FocusNode? trigger}) => UiMenu(
          items: _items,
          onSelect: (i) => log.add(i.value),
          builder: (context, toggle, open) => UiButton(label: 'Actions', focusNode: trigger, onPressed: toggle),
        );

    testWidgets('tapping an item selects it and closes; disabled items do nothing', (tester) async {
      final log = <String>[];
      await _place(tester, Alignment.topLeft, Padding(padding: const EdgeInsets.all(40), child: menu(log)));
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      expect(find.text('Share'), findsOneWidget);
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(log, ['share']);
      expect(find.text('Share'), findsNothing);
    });

    testWidgets('keyboard: focus moves to the first item, arrows skip disabled and wrap, Enter selects, focus returns', (tester) async {
      final log = <String>[];
      final trigger = FocusNode();
      addTearDown(trigger.dispose);
      await _place(tester, Alignment.center, menu(log, trigger: trigger));
      trigger.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      String label() => _items[int.parse(FocusManager.instance.primaryFocus!.debugLabel!.split(' ').last)].label;
      expect(label(), 'Edit');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(label(), 'Share', reason: 'Archive is disabled');
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(label(), 'Delete');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(label(), 'Edit', reason: 'wraps');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(label(), 'Delete');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(log, ['delete']);
      expect(trigger.hasPrimaryFocus, isTrue);
    });

    testWidgets('opened with the mouse, Escape still gives focus to the trigger', (tester) async {
      final trigger = FocusNode();
      addTearDown(trigger.dispose);
      await _place(tester, Alignment.center, menu([], trigger: trigger));
      await tester.tap(find.text('Actions'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(trigger.hasFocus, isFalse, reason: 'a click does not focus the trigger');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Share'), findsNothing);
      expect(trigger.hasPrimaryFocus, isTrue);
    });

    testWidgets('Escape closes and returns focus; Tab closes and moves on', (tester) async {
      final trigger = FocusNode(), after = FocusNode();
      addTearDown(trigger.dispose);
      addTearDown(after.dispose);
      await _place(tester, Alignment.center, Column(mainAxisSize: MainAxisSize.min, children: [
        menu([], trigger: trigger),
        UiButton(label: 'After', focusNode: after, onPressed: () {}),
      ]));
      trigger.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsNothing);
      expect(trigger.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsNothing);
      expect(after.hasPrimaryFocus, isTrue);
    });

    testWidgets('near the right edge it lines up with the trigger\'s right edge', (tester) async {
      await _place(tester, Alignment.topRight, Padding(padding: const EdgeInsets.fromLTRB(0, 40, 16, 0), child: menu([])));
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      final trigger = tester.getRect(find.byType(UiButton));
      expect(tester.getRect(find.byType(UiFloatingPanel)).right, closeTo(trigger.right, 0.01));
    });

    testWidgets('items are 48dp tall on touch and meet the guidelines', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final handle = tester.ensureSemantics();
      // No disabled item: it is dimmed on purpose (like the web) and would fail the contrast check.
      await _place(tester, Alignment.topLeft, Padding(
        padding: const EdgeInsets.all(40),
        child: UiMenu(items: [for (final i in _items) if (!i.disabled) i], onSelect: (_) {}, builder: (context, toggle, open) => UiButton(label: 'Actions', onPressed: toggle)),
      ));
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.ancestor(of: find.text('Share'), matching: find.byType(AnimatedContainer)).first).height, 48);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('UiContextMenu', () {
    Widget area(List<String> log) => UiContextMenu(
          items: _items,
          onSelect: (i) => log.add(i.value),
          child: const SizedBox(key: Key('area'), width: 300, height: 300),
        );

    testWidgets('long-press opens it at the finger and picking an item closes it', (tester) async {
      final log = <String>[];
      await _place(tester, Alignment.topLeft, area(log));
      await tester.longPressAt(const Offset(100, 120));
      await tester.pumpAndSettle();
      final panel = tester.getRect(find.byType(UiFloatingPanel));
      expect(panel.topLeft, const Offset(100, 120));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(log, ['edit']);
      expect(find.byType(UiFloatingPanel), findsNothing);
    });

    testWidgets('right-click opens it; it flips and shifts near the corner; a tap outside closes it', (tester) async {
      await _place(tester, Alignment.bottomRight, area([]));
      final p = tester.getBottomRight(find.byKey(const Key('area'))) - const Offset(5, 5);
      await tester.tapAt(p, buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      final panel = tester.getRect(find.byType(UiFloatingPanel));
      expect(panel.bottom, lessThanOrEqualTo(844 - 8));
      expect(panel.right, lessThanOrEqualTo(390 - 8));
      expect(panel.bottom, lessThanOrEqualTo(p.dy), reason: 'flipped above the pointer');
      expect(panel.top, lessThan(p.dy - 100));
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byType(UiFloatingPanel), findsNothing);
    });

    testWidgets('Escape closes it and gives focus back', (tester) async {
      final before = FocusNode();
      addTearDown(before.dispose);
      await _place(tester, Alignment.topLeft, Column(children: [
        UiButton(label: 'Before', focusNode: before, onPressed: () {}),
        area([]),
      ]));
      before.requestFocus();
      await tester.pump();
      await tester.longPressAt(const Offset(100, 200));
      await tester.pumpAndSettle();
      expect(before.hasPrimaryFocus, isFalse, reason: 'the first item has focus');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(UiFloatingPanel), findsNothing);
      expect(before.hasPrimaryFocus, isTrue);
    });

    testWidgets('screen readers can open it with the long-press action', (tester) async {
      final handle = tester.ensureSemantics();
      await _place(tester, Alignment.topLeft, area([]));
      final node = tester.getSemantics(find.byKey(const Key('area')));
      expect(node.getSemanticsData().hasAction(SemanticsAction.longPress), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.longPress);
      await tester.pumpAndSettle();
      expect(find.byType(UiFloatingPanel), findsOneWidget);
      handle.dispose();
    });
  });

  group('UiBackdrop', () {
    testWidgets('fills its parent, fades in and reports taps', (tester) async {
      var taps = 0;
      await pumpUi(tester, SizedBox(width: 200, height: 100, child: UiBackdrop(onTap: () => taps++)));
      expect(tester.getSize(find.byType(UiBackdrop)), const Size(200, 100));
      await tester.tap(find.byType(UiBackdrop));
      expect(taps, 1);
    });

    testWidgets('is hidden from screen readers unless labelled', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, SizedBox(width: 200, height: 100, child: UiBackdrop(onTap: () {})));
      expect(find.bySemanticsLabel('Close'), findsNothing);
      await pumpUi(tester, SizedBox(width: 200, height: 100, child: UiBackdrop(onTap: () {}, semanticLabel: 'Close')));
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
      handle.dispose();
    });
  });

  testWidgets('golden: menu, popover, tooltip and context menu over a page', (tester) async {
    debugDisableShadows = false;
    await pumpScreens(tester, (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [
            UiMenu(open: true, items: _items, onSelect: (_) {}, builder: (context, toggle, open) => UiButton(label: 'Menu', variant: UiButtonVariant.outline, onPressed: toggle)),
            const SizedBox(height: 190),
            Row(children: [
              UiTooltip(message: 'Tooltip text', child: UiButton(key: const Key('tip'), label: 'Hold me', onPressed: () {})),
              const Spacer(),
              UiPopover(
                open: true,
                label: 'Details',
                placement: UiPopoverPlacement.bottomEnd,
                builder: (context, toggle, open) => UiButton(label: 'Popover', variant: UiButtonVariant.outline, onPressed: toggle),
                content: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, spacing: 4, children: [
                  UiText('Popover', variant: UiTextVariant.label),
                  UiText('Panel content can be anything: text, a form, a list.', variant: UiTextVariant.caption),
                ]),
              ),
            ]),
            const SizedBox(height: 90),
            UiContextMenu(
              items: _items,
              onSelect: (_) {},
              child: Container(
                key: const Key('ctx'),
                height: 150,
                alignment: Alignment.center,
                decoration: BoxDecoration(border: Border.all(color: context.ui.border), borderRadius: BorderRadius.circular(8)),
                child: UiText('Long-press here', variant: UiTextVariant.caption),
              ),
            ),
          ]),
        ));
    await tester.longPressAt(tester.getTopLeft(find.byKey(const Key('ctx')).at(1)) + const Offset(150, 30));
    await tester.pumpAndSettle();
    // Hover, so the context menu (closed by any press outside it) stays open.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('tip')).at(0)));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('screens')), matchesGoldenFile('goldens/overlays_open.png'));
    await mouse.removePointer();
    debugDisableShadows = true;
  });
}
