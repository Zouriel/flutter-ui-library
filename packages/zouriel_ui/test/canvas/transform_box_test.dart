import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

class _Stage extends StatefulWidget {
  const _Stage({this.box = const UiBox(x: 100, y: 100, w: 80, h: 40, rotate: 15), this.disabled = false});
  final UiBox box;

  final bool disabled;

  @override
  State<_Stage> createState() => _StageState();
}

class _StageState extends State<_Stage> {
  late final UiBox box = widget.box;
  final key = GlobalKey<UiTransformBoxState>();
  final starts = <UiTransformMode>[];
  final moves = <UiBox>[];
  final ends = <UiBox>[];
  final taps = <UiTransformTap>[];
  int activations = 0;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 390,
        height: 400,
        child: Stack(children: [
          UiTransformBox(
            key: key,
            box: box,
            minSize: 10,
            label: 'Card',
            disabled: widget.disabled,
            onTransformStart: starts.add,
            onTransform: moves.add,
            onTransformEnd: ends.add,
            onTap: taps.add,
            onActivate: () => activations++,
          ),
        ]),
      );
}

_StageState _stage(WidgetTester tester) => tester.state<_StageState>(find.byType(_Stage));

void main() {
  group('pinch', () {
    testWidgets('grows equally from every side about its centre, keeping proportions and rotation', (tester) async {
      await pumpUi(tester, const _Stage());
      // Fingers either side of the centre (140, 120), spreading from 80 apart to 160. They land beside the box.
      final a = await tester.createGesture(pointer: 1, kind: PointerDeviceKind.touch);
      final b = await tester.createGesture(pointer: 2, kind: PointerDeviceKind.touch);
      await a.down(const Offset(100, 300));
      await b.down(const Offset(180, 300));
      _stage(tester).key.currentState!.startPinch(1, const Offset(100, 120), 2, const Offset(180, 120));
      await b.moveTo(const Offset(220, 120));
      await a.moveTo(const Offset(60, 120));
      await b.up();
      await a.up();
      final s = _stage(tester);
      expect(s.starts, [UiTransformMode.resize]);
      expect(s.ends, hasLength(1));
      final end = s.ends.last;
      expect(end.w, closeTo(160, 1e-6));
      expect(end.h, closeTo(80, 1e-6));
      expect(end.center.dx, closeTo(140, 1e-6));
      expect(end.center.dy, closeTo(120, 1e-6));
      expect(end.rotate, 15);
    });

    testWidgets('zooms toward the fingers: the point between them stays under them', (tester) async {
      await pumpUi(tester, const _Stage());
      final a = await tester.createGesture(pointer: 1, kind: PointerDeviceKind.touch);
      final b = await tester.createGesture(pointer: 2, kind: PointerDeviceKind.touch);
      await a.down(const Offset(100, 300));
      await b.down(const Offset(120, 300));
      _stage(tester).key.currentState!.startPinch(1, const Offset(100, 110), 2, const Offset(120, 110));
      await a.moveTo(const Offset(90, 110));
      await b.moveTo(const Offset(130, 110));
      await b.up();
      await a.up();
      final end = _stage(tester).ends.last;
      expect(end.w, closeTo(160, 1e-6));
      // (110, 110) was 30 left and 10 up of the centre (140, 120); twice as far now.
      expect(end.center.dx, closeTo(170, 1e-6));
      expect(end.center.dy, closeTo(130, 1e-6));
    });

    testWidgets('never shrinks below the smallest size; fingers that land and lift change nothing', (tester) async {
      await pumpUi(tester, const _Stage());
      var a = await tester.createGesture(pointer: 1, kind: PointerDeviceKind.touch);
      var b = await tester.createGesture(pointer: 2, kind: PointerDeviceKind.touch);
      await a.down(const Offset(100, 300));
      await b.down(const Offset(200, 300));
      _stage(tester).key.currentState!.startPinch(1, const Offset(100, 300), 2, const Offset(200, 300));
      await b.moveTo(const Offset(101, 300));
      await b.up();
      await a.up();
      final end = _stage(tester).ends.last;
      expect(end.h, closeTo(10, 1e-6));
      expect(end.w, closeTo(20, 1e-6));

      a = await tester.createGesture(pointer: 3, kind: PointerDeviceKind.touch);
      b = await tester.createGesture(pointer: 4, kind: PointerDeviceKind.touch);
      await a.down(const Offset(100, 300));
      await b.down(const Offset(200, 300));
      _stage(tester).key.currentState!.startPinch(3, const Offset(100, 300), 4, const Offset(200, 300));
      await a.up();
      await b.up();
      expect(_stage(tester).ends, hasLength(1));
    });

    testWidgets('a second finger while one drags the box turns the drag into a pinch', (tester) async {
      await pumpUi(tester, const _Stage());
      final a = await tester.startGesture(const Offset(140, 120), pointer: 1);
      final b = await tester.startGesture(const Offset(240, 120), pointer: 2);
      await b.moveTo(const Offset(340, 120));
      await a.up();
      await b.up();
      final s = _stage(tester);
      expect(s.starts, [UiTransformMode.move, UiTransformMode.resize]);
      expect(s.ends, hasLength(1));
      // The first finger held the centre while the second spread away: twice the size, and the
      // point under the first finger (the centre) stayed put.
      expect(s.ends[0].w, closeTo(160, 1e-6));
      expect(s.ends[0].center.dx, closeTo(140, 1e-6));
      expect(s.key.currentState!.pinching, isFalse);
    });

    testWidgets('a mouse drag is never turned into a pinch', (tester) async {
      await pumpUi(tester, const _Stage());
      final a = await tester.startGesture(const Offset(140, 120), pointer: 1, kind: PointerDeviceKind.mouse);
      final b = await tester.startGesture(const Offset(240, 120), pointer: 2);
      expect(_stage(tester).key.currentState!.pinching, isFalse);
      await b.up();
      await a.up();
    });
  });

  testWidgets('dragging the body moves it; a still press is a tap, two are an activation', (tester) async {
    await pumpUi(tester, const _Stage(box: UiBox(x: 100, y: 100, w: 80, h: 40)));
    final g = await tester.startGesture(const Offset(140, 120));
    await g.moveBy(const Offset(10, 0));
    await g.moveBy(const Offset(20, 15));
    await g.up();
    final s = _stage(tester);
    expect(s.starts, [UiTransformMode.move]);
    expect(s.ends.single, const UiBox(x: 130, y: 115, w: 80, h: 40));
    expect(s.moves.last, s.ends.single);

    await tester.tapAt(const Offset(140, 120));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(140, 120));
    expect(s.taps, hasLength(2));
    expect(s.activations, 1);
    expect(s.ends, hasLength(1));
  });

  testWidgets('a corner handle resizes with the opposite corner fixed; Shift keeps proportions', (tester) async {
    await pumpUi(tester, const _Stage(box: UiBox(x: 100, y: 100, w: 80, h: 40)));
    final se = tester.getCenter(find.byKey(const Key('ui-transform-se')));
    expect(se, const Offset(180, 140));
    var g = await tester.startGesture(se);
    await g.moveBy(const Offset(10, 10));
    await g.moveBy(const Offset(10, 0));
    await g.up();
    expect(_stage(tester).ends.last, const UiBox(x: 100, y: 100, w: 100, h: 50));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    g = await tester.startGesture(se);
    await g.moveBy(const Offset(40, 0));
    await g.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    final kept = _stage(tester).ends.last;
    expect(kept.w / kept.h, closeTo(2, 1e-9));
    expect(kept.x, 100);
  });

  test('resizing a rotated box keeps the opposite edge where it was on screen', () {
    const o = UiBox(x: 0, y: 0, w: 100, h: 50, rotate: 90);
    // Rotated 90 degrees, the box's right edge (the e handle) faces down: dragging down 20 grows it.
    final r = uiResizeBox(o, 1, 0, 0, 20);
    expect(r.w, closeTo(120, 1e-9));
    // The w edge, now at the top, stays put: the centre moved down by half the growth.
    expect(r.center.dy, closeTo(o.center.dy + 10, 1e-9));
    expect(r.center.dx, closeTo(o.center.dx, 1e-9));
    final centred = uiResizeBox(const UiBox(x: 0, y: 0, w: 100, h: 50), 1, 1, 10, 10, fromCenter: true);
    expect(centred, const UiBox(x: -10, y: -10, w: 120, h: 70));
    expect(uiResizeBox(const UiBox(x: 0, y: 0, w: 100, h: 50), -1, 0, 500, 0, minSize: 4).w, 4);
  });

  testWidgets('the knob rotates about the centre, settling on right angles', (tester) async {
    await pumpUi(tester, const _Stage(box: UiBox(x: 100, y: 100, w: 80, h: 40)));
    final knob = tester.getCenter(find.byKey(const Key('ui-transform-rotate')));
    expect(knob.dx, 140);
    expect(knob.dy, lessThan(100));
    // A quarter turn clockwise: from above the centre to its right, a hair short.
    final g = await tester.startGesture(knob);
    await g.moveTo(const Offset(160, 50));
    await g.moveTo(const Offset(230, 118));
    await g.up();
    final s = _stage(tester);
    expect(s.starts, [UiTransformMode.rotate]);
    expect(s.ends.last.rotate, 90);
  });

  testWidgets('keyboard: arrows nudge, Shift by ten, Alt resizes, brackets rotate; held keys build up', (tester) async {
    await pumpUi(tester, const _Stage(box: UiBox(x: 100, y: 100, w: 80, h: 40)));
    await tester.tapAt(const Offset(140, 120));
    final s = _stage(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(s.ends.last, const UiBox(x: 101, y: 100, w: 80, h: 40));
    // The host hasn't applied it: the next press builds on the last nudge.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(s.ends.last.x, 102);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(s.ends.last, const UiBox(x: 102, y: 110, w: 80, h: 40, rotate: 15));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    expect(s.ends.last.w, 79);
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
    expect(s.ends.last.rotate, 14);
  });

  testWidgets('disabled: no handles, no keys, no drags', (tester) async {
    await pumpUi(tester, const _Stage(box: UiBox(x: 100, y: 100, w: 80, h: 40), disabled: true));
    expect(find.byKey(const Key('ui-transform-se')), findsNothing);
    expect(find.byKey(const Key('ui-transform-rotate')), findsNothing);
    final g = await tester.startGesture(const Offset(140, 120));
    await g.moveBy(const Offset(30, 0));
    await g.up();
    expect(_stage(tester).ends, isEmpty);
  });

  testWidgets('touch: 48dp handles, edge handles only where they fit; semantics actions', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const _Stage(box: UiBox(x: 100, y: 100, w: 200, h: 60)));
    expect(tester.getSize(find.byKey(const Key('ui-transform-nw'))), const Size(48, 48));
    expect(tester.getSize(find.byKey(const Key('ui-transform-rotate'))), const Size(48, 48));
    // 200 wide fits the top and bottom handles; 60 tall doesn't fit the side ones.
    expect(find.byKey(const Key('ui-transform-n')), findsOneWidget);
    expect(find.byKey(const Key('ui-transform-e')), findsNothing);
    final node = tester.getSemantics(find.bySemanticsLabel('Card'));
    expect(node.value, '100, 100, 200 by 60');
    tester.semantics.customAction(find.semantics.byLabel('Card'), const CustomSemanticsAction(label: 'Move right'));
    expect(_stage(tester).ends.last.x, 101);
    handle.dispose();
  });

  testWidgets('golden: selection on a stage, with size readout, rotated, and disabled', (tester) async {
    await expectThemedGolden(tester, 'transform_box', height: 300, (context) {
      final t = context.ui;
      Widget thing(UiBox b) => Positioned(
            left: b.x,
            top: b.y,
            width: b.w,
            height: b.h,
            child: Transform.rotate(
              angle: b.rotate * 3.14159265 / 180,
              child: DecoratedBox(decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(6), border: Border.all(color: t.borderStrong))),
            ),
          );
      const a = UiBox(x: 30, y: 70, w: 130, h: 70);
      const b = UiBox(x: 220, y: 90, w: 90, h: 60, rotate: 20);
      const c = UiBox(x: 60, y: 200, w: 100, h: 40);
      return DecoratedBox(
        decoration: BoxDecoration(color: t.surfaceSubtle, borderRadius: BorderRadius.circular(8)),
        child: Stack(children: [
          thing(a),
          thing(b),
          thing(c),
          const UiTransformBox(box: a, showSize: true),
          const UiTransformBox(box: b, cornersOnly: true),
          const UiTransformBox(box: c, disabled: true),
        ]),
      );
    });
  });
}
