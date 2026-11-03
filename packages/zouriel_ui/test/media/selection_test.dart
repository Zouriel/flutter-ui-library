import 'dart:ui' show CheckedState, GestureSettings, Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// A phone's touch slop (about 8dp), not the test default of 18 (AGENTS.md 2026-10-14).
void phoneSlop(WidgetTester tester) {
  tester.view.gestureSettings = GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
  addTearDown(tester.view.resetGestureSettings);
}

/// A grid of [n] 120px tiles in a vertical scroll view, the way an album lays them out.
class _Grid extends StatefulWidget {
  const _Grid({this.onLong, this.onTapped, this.controller});
  static const n = 30;
  final ValueChanged<int>? onLong;
  final ValueChanged<int>? onTapped;
  final ScrollController? controller;
  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> {
  final selected = <int>{};
  bool get selecting => selected.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 390,
      height: 600,
      child: SingleChildScrollView(
        controller: widget.controller,
        child: Wrap(children: [
          for (var i = 0; i < _Grid.n; i++)
            SizedBox(
              width: 130,
              height: 130,
              child: UiSelectable(
                key: ValueKey(i),
                semanticLabel: 'Photo ${i + 1}',
                selected: selected.contains(i),
                selecting: selecting,
                onTap: () {
                  widget.onTapped?.call(i);
                  if (selecting) setState(() => selected.contains(i) ? selected.remove(i) : selected.add(i));
                },
                onLongPress: () {
                  widget.onLong?.call(i);
                  setState(() => selected.add(i));
                },
                child: ColoredBox(color: i.isEven ? const Color(0xFF223344) : const Color(0xFFEEEEEE)),
              ),
            ),
        ]),
      ),
    );
  }
}

List<UiSelectionAction> _actions() => const [
      UiSelectionAction(id: 'share', label: 'Share', icon: UiIcon(HugeIcons.strokeRoundedShare08)),
      UiSelectionAction(id: 'save', label: 'Save to gallery', icon: UiIcon(HugeIcons.strokeRoundedDownload04)),
      UiSelectionAction(id: 'delete', label: 'Delete', icon: UiIcon(HugeIcons.strokeRoundedDelete02), danger: true),
    ];

void main() {
  group('UiSelectable', () {
    testWidgets('tap calls onTap; long press calls onLongPress with a selection click haptic', (tester) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final taps = <int>[], longs = <int>[];
      await pumpUi(tester, _Grid(onTapped: taps.add, onLong: longs.add));
      await tester.tap(find.byKey(const ValueKey(1)));
      await tester.pumpAndSettle();
      expect(taps, [1]);
      expect(longs, isEmpty);
      expect(find.byType(UiSelectionMark), findsNothing, reason: 'not selecting: no marks');

      await tester.longPress(find.byKey(const ValueKey(2)));
      await tester.pumpAndSettle();
      expect(longs, [2]);
      expect(taps, [1], reason: 'a long press is not also a tap');
      expect(haptics, ['HapticFeedbackType.selectionClick']);
      // Now selecting: every tile has a mark, and taps toggle.
      expect(find.byType(UiSelectionMark), findsNWidgets(find.byType(UiSelectable).evaluate().length));
      await tester.tap(find.byKey(const ValueKey(1)));
      await tester.pumpAndSettle();
      final state = tester.state<_GridState>(find.byType(_Grid));
      expect(state.selected, {1, 2});
    });

    testWidgets('long press works inside a scroll view, but a finger that scrolls never long-presses (phone slop)', (tester) async {
      phoneSlop(tester);
      final longs = <int>[];
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await pumpUi(tester, _Grid(onLong: longs.add, controller: scroll));

      // Scroll: the finger moves 60px up over 700ms, longer than a long press takes.
      final g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey(4))));
      for (var i = 0; i < 14; i++) {
        await g.moveBy(const Offset(0, -5));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(40));
      expect(longs, isEmpty, reason: 'scrolling must not select');

      // A finger that stays put (a tremor under the slop) selects.
      final g2 = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey(7))));
      await g2.moveBy(const Offset(0, 2));
      await tester.pump(const Duration(milliseconds: 600));
      await g2.up();
      await tester.pumpAndSettle();
      expect(longs, [7]);
    });

    testWidgets('a second finger going down on another tile while a long press is pending cancels it (a pinch)', (tester) async {
      phoneSlop(tester);
      final longs = <int>[];
      await pumpUi(tester, _Grid(onLong: longs.add));
      final a = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey(1))), pointer: 71);
      await tester.pump(const Duration(milliseconds: 100));
      final b = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey(5))), pointer: 72);
      await tester.pump(const Duration(milliseconds: 900)); // both held well past the long-press time
      expect(longs, isEmpty);
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(longs, isEmpty);
      expect(find.byType(UiSelectionMark), findsNothing, reason: 'no selection mode');

      // And afterwards one finger long-presses again as usual.
      await tester.longPress(find.byKey(const ValueKey(2)));
      await tester.pumpAndSettle();
      expect(longs, [2]);
    });

    testWidgets('a long press can not start while another finger is already down', (tester) async {
      phoneSlop(tester);
      final longs = <int>[];
      await pumpUi(tester, _Grid(onLong: longs.add));
      final a = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey(5))), pointer: 73);
      // The second lands on tile 1 while the first is still down on tile 5.
      await tester.pump(const Duration(milliseconds: 100));
      final b = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey(1))), pointer: 74);
      await tester.pump(const Duration(milliseconds: 900));
      expect(longs, isEmpty, reason: 'neither the first finger\'s tile nor the second\'s');
      await a.up();
      await b.up();
      await tester.pumpAndSettle();

      // Also with the earlier finger off every tile (on the page outside the grid).
      final c = await tester.startGesture(const Offset(200, 700), pointer: 75);
      final d = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey(3))), pointer: 76);
      await tester.pump(const Duration(milliseconds: 900));
      expect(longs, isEmpty);
      await c.up();
      await d.up();
      await tester.pumpAndSettle();
      expect(longs, isEmpty);
    });

    testWidgets('selected: shrinks with a primary outline and a filled mark with a check; unselected: an empty ring', (tester) async {
      Widget tile(bool selected, {bool reduce = false}) => MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: SizedBox(
              width: 120,
              height: 120,
              child: UiSelectable(selected: selected, selecting: true, semanticLabel: 'P', onTap: () {}, child: const SizedBox.expand()),
            ),
          );
      await pumpUi(tester, tile(false));
      final ctx = tester.element(find.byType(UiSelectable));
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      expect(find.byType(UiIcon), findsNothing, reason: 'empty ring, no check');
      final ring = tester.widget<AnimatedContainer>(find.descendant(of: find.byType(UiSelectionMark), matching: find.byType(AnimatedContainer)));
      final ringDeco = ring.decoration! as BoxDecoration;
      expect(ringDeco.border!.top.color, ctx.ui.mediaOnScrim);
      expect(ringDeco.color!.a, lessThan(1), reason: 'a see-through scrim inside the ring');

      await pumpUi(tester, tile(true));
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, uiSelectableScale);
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration, greaterThan(Duration.zero));
      final mark = tester.widget<AnimatedContainer>(find.descendant(of: find.byType(UiSelectionMark), matching: find.byType(AnimatedContainer)));
      expect((mark.decoration! as BoxDecoration).color, ctx.ui.primary);
      expect(tester.widget<UiIcon>(find.byType(UiIcon)).icon, HugeIcons.strokeRoundedTick02);
      final outline = tester.widget<AnimatedContainer>(find.descendant(of: find.byType(AnimatedScale), matching: find.byType(AnimatedContainer)).first);
      expect((outline.foregroundDecoration! as BoxDecoration).border!.top.color, ctx.ui.primary);

      // Reduced motion: no animation.
      await pumpUi(tester, tile(true, reduce: true));
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration, Duration.zero);
    });

    testWidgets('not selecting: the child is untouched (no scale, no outline, no mark)', (tester) async {
      await pumpUi(tester, SizedBox(width: 120, height: 120, child: UiSelectable(selected: true, selecting: false, onTap: () {}, child: const SizedBox.expand())));
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      final c = tester.widget<AnimatedContainer>(find.descendant(of: find.byType(AnimatedScale), matching: find.byType(AnimatedContainer)).first);
      expect((c.foregroundDecoration! as BoxDecoration).border!.top.color.a, 0);
      expect(find.byType(UiSelectionMark), findsNothing);
    });

    testWidgets('semantics: label, selected, checked only while selecting, and a long-press action', (tester) async {
      final handle = tester.ensureSemantics();
      Future<SemanticsData> data(bool selected, bool selecting) async {
        await pumpUi(tester, SizedBox(
          width: 120,
          height: 120,
          child: UiSelectable(selected: selected, selecting: selecting, semanticLabel: 'Beach', onTap: () {}, onLongPress: () {}, child: const SizedBox.expand()),
        ));
        return tester.getSemantics(find.bySemanticsLabel('Beach')).getSemanticsData();
      }

      var d = await data(false, false);
      expect(d.hasAction(SemanticsAction.tap), isTrue);
      expect(d.hasAction(SemanticsAction.longPress), isTrue);
      expect(d.flagsCollection.isButton, isTrue);
      expect(d.flagsCollection.isChecked, CheckedState.none, reason: 'not a checkbox until selecting');

      d = await data(false, true);
      expect(d.flagsCollection.isChecked, CheckedState.isFalse);
      expect(d.flagsCollection.isSelected, Tristate.isFalse);

      d = await data(true, true);
      expect(d.flagsCollection.isChecked, CheckedState.isTrue);
      expect(d.flagsCollection.isSelected, Tristate.isTrue);
      expect(d.hasAction(SemanticsAction.longPress), isTrue);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('golden: marks read on white and black pictures, selected and not', (tester) async {
      await expectThemedGolden(
        tester,
        'selectable',
        height: 180,
        (context) => Wrap(spacing: 4, runSpacing: 4, children: [
          for (final (c, sel) in const [(Color(0xFFFFFFFF), false), (Color(0xFFFFFFFF), true), (Color(0xFF000000), false), (Color(0xFF000000), true)])
            SizedBox(
              width: 84,
              height: 84,
              child: UiSelectable(
                selected: sel,
                selecting: true,
                onTap: () {},
                child: ColoredBox(color: c),
              ),
            ),
          SizedBox(width: 84, height: 84, child: UiSelectable(selected: false, selecting: false, onTap: () {}, child: const ColoredBox(color: Color(0xFF000000)))),
        ]),
      );
    });
  });

  group('UiSelectionBar', () {
    testWidgets('count, Select all that becomes Clear, cancel, and the toggle hidden without callbacks', (tester) async {
      var all = 0, clear = 0, cancel = 0;
      Widget bar(int count, {int? total = 10, bool withAll = true, bool withClear = true}) => SizedBox(
            width: 600,
            child: UiSelectionBar(
              count: count,
              total: total,
              onSelectAll: withAll ? () => all++ : null,
              onClear: withClear ? () => clear++ : null,
              onCancel: () => cancel++,
            ),
          );
      await pumpUi(tester, bar(3), size: const Size(600, 400));
      expect(find.text('3 selected'), findsOneWidget);
      await tester.tap(find.text('Select all'));
      expect(all, 1);
      await tester.tap(find.bySemanticsLabel('Cancel selection'));
      expect(cancel, 1);

      await pumpUi(tester, bar(10), size: const Size(600, 400));
      expect(find.text('Select all'), findsNothing);
      await tester.tap(find.text('Clear'));
      expect(clear, 1);

      await pumpUi(tester, bar(10, withClear: false), size: const Size(600, 400));
      expect(find.text('Clear'), findsNothing);
      expect(find.text('Select all'), findsNothing);
      await pumpUi(tester, bar(3, withAll: false), size: const Size(600, 400));
      expect(find.text('Select all'), findsNothing);
      await pumpUi(tester, bar(3, total: null), size: const Size(600, 400));
      expect(find.text('Select all'), findsOneWidget, reason: 'no total: it never turns into Clear');
    });

    testWidgets('actions: id on press, off while nothing is selected or when not enabled, danger style', (tester) async {
      final pressed = <String>[];
      Widget bar(int count) => SizedBox(
            width: 900,
            child: UiSelectionBar(
              count: count,
              total: 10,
              onSelectAll: () {},
              onCancel: () {},
              actions: [..._actions(), const UiSelectionAction(id: 'print', label: 'Print', enabled: false)],
              onAction: pressed.add,
            ),
          );
      await pumpUi(tester, bar(0), size: const Size(900, 400));
      for (final l in ['Share', 'Save to gallery', 'Delete', 'Print']) {
        expect(tester.widget<UiButton>(find.widgetWithText(UiButton, l)).onPressed, isNull, reason: '$l with 0 selected');
      }
      await pumpUi(tester, bar(2), size: const Size(900, 400));
      await tester.tap(find.text('Share'));
      await tester.tap(find.text('Delete'));
      await tester.tap(find.text('Print'));
      expect(pressed, ['share', 'delete']);
      expect(tester.widget<UiButton>(find.widgetWithText(UiButton, 'Delete')).variant, UiButtonVariant.destructive);
      expect(tester.widget<UiButton>(find.widgetWithText(UiButton, 'Share')).variant, UiButtonVariant.ghost);
    });

    testWidgets('at 360 with three actions they shrink to labelled icon buttons; nothing overflows at 320', (tester) async {
      final handle = tester.ensureSemantics();
      final pressed = <String>[];
      for (final width in [320.0, 360.0]) {
        await pumpUi(
          tester,
          SizedBox(width: width, child: UiSelectionBar(count: 12, total: 40, onSelectAll: () {}, onClear: () {}, onCancel: () {}, actions: _actions(), onAction: pressed.add)),
          size: Size(width, 640),
        );
        expect(tester.takeException(), isNull, reason: 'overflow at $width');
        expect(find.text('Share'), findsNothing, reason: 'icon only at $width');
        expect(find.widgetWithText(UiButton, 'Select all'), findsNothing);
        for (final l in ['Share', 'Save to gallery', 'Delete', 'Select all']) {
          final b = find.byWidgetPredicate((w) => w is UiIconButton && w.label == l);
          expect(b, findsOneWidget, reason: l);
          expect(find.ancestor(of: b, matching: find.byWidgetPredicate((w) => w is UiTooltip && w.message == l)), findsOneWidget, reason: '$l tooltip');
          expect(tester.getRect(b).right, lessThanOrEqualTo(width + 0.5), reason: '$l inside the bar at $width');
        }
        expect(find.bySemanticsLabel(RegExp('^Save to gallery')), findsOneWidget);
        await tester.tap(find.byWidgetPredicate((w) => w is UiIconButton && w.label == 'Delete'));
      }
      expect(pressed, ['delete', 'delete']);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      // Wide: every label shows.
      await pumpUi(tester, SizedBox(width: 760, child: UiSelectionBar(count: 12, total: 40, onSelectAll: () {}, onCancel: () {}, actions: _actions(), onAction: (_) {})), size: const Size(760, 640));
      for (final l in ['Share', 'Save to gallery', 'Delete', 'Select all']) {
        expect(find.text(l), findsOneWidget, reason: l);
      }
      handle.dispose();
    });

    testWidgets('the count is a live region, so changes are announced politely', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, SizedBox(width: 600, child: UiSelectionBar(count: 4, onCancel: () {})), size: const Size(600, 400));
      final d = tester.getSemantics(find.text('4 selected')).getSemanticsData();
      expect(d.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('strings come from UiStrings (Dhivehi)', (tester) async {
      tester.view.physicalSize = const Size(600, 400) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(
        config: const UiConfig(strings: UiStrings.dv),
        home: SizedBox(width: 600, child: UiSelectionBar(count: 2, total: 2, onClear: () {}, onCancel: () {})),
      ));
      await tester.pumpAndSettle();
      expect(find.text('2 ހޮވިފައި'), findsOneWidget);
      expect(find.text(UiStrings.dv.clearSelection), findsOneWidget);
    });

    testWidgets('golden: wide with labels, narrow with icons', (tester) async {
      await expectThemedGolden(
        tester,
        'selection_bar',
        width: 400,
        height: 250,
        (context) => Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [
          UiSelectionBar(count: 12, total: 40, onSelectAll: () {}, onCancel: () {}, actions: _actions().take(1).toList(), onAction: (_) {}),
          SizedBox(width: 328, child: UiSelectionBar(count: 40, total: 40, onSelectAll: () {}, onClear: () {}, onCancel: () {}, actions: _actions(), onAction: (_) {})),
          SizedBox(width: 288, child: UiSelectionBar(count: 0, total: 40, onSelectAll: () {}, onCancel: () {}, actions: _actions(), onAction: (_) {})),
        ]),
      );
    });
  });
}
