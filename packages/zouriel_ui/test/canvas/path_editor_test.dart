import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// The editor fills 400 x 300 and fits the 100 x 100 artboard: 300 / 135 px a unit, centred on (50, 50).
const double _px = 300 / 135;
Offset _screen(double x, double y) => Offset(200 + (x - 50) * _px, 150 + (y - 50) * _px);

class _Host extends StatefulWidget {
  const _Host({required this.mode, this.items = const [], this.selectedId, this.brush = const UiBrush()});
  final UiPathEditorMode mode;
  final List<UiPathItem> items;
  final String? selectedId;
  final UiBrush brush;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late UiPathEditorMode mode = widget.mode;
  late List<UiPathItem> items = widget.items;
  late String? selectedId = widget.selectedId;
  late UiBrush brush = widget.brush;
  bool straight = false;
  bool loupe = true;
  UiPointRef? point;
  List<UiPointRef> points = const [];
  final strokes = <UiInkStroke>[];
  final changes = <List<UiPathItem>>[];
  final key = GlobalKey<UiPathEditorState>();
  int pens = 0;

  void setMode(UiPathEditorMode m) => setState(() => mode = m);
  void update(VoidCallback f) => setState(f);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 400,
        height: 300,
        child: UiPathEditor(
          key: key,
          items: items,
          mode: mode,
          brush: brush,
          straightLine: straight,
          loupe: loupe,
          selectedId: selectedId,
          onSelectedIdChanged: (v) => setState(() => selectedId = v),
          selectedPoint: point,
          onSelectedPointChanged: (v) => setState(() => point = v),
          selectedPoints: points,
          onSelectedPointsChanged: (v) => setState(() => points = v),
          onItemsChanged: (v) => setState(() {
            changes.add(v);
            items = v;
          }),
          onStroke: strokes.add,
          onPenDetected: () => pens++,
        ),
      );
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

Future<void> _tap(WidgetTester tester, Offset at, {PointerDeviceKind kind = PointerDeviceKind.mouse}) async {
  final g = await tester.startGesture(at, kind: kind);
  await g.up();
  await tester.pump();
}

final _square = UiPathItem(id: 'sq', contours: [rectContour(20, 20, 40, 40)]);

void main() {
  testWidgets('a plain wheel scrolls the page; Ctrl + wheel zooms the editor instead', (tester) async {
    final scroll = ScrollController();
    await pumpUi(
      tester,
      SingleChildScrollView(
        controller: scroll,
        child: Column(children: [const _Host(mode: UiPathEditorMode.objects), const SizedBox(height: 2000)]),
      ),
      size: const Size(800, 600),
    );
    final at = tester.getCenter(find.byType(UiPathEditor));
    tester.binding.handlePointerEvent(PointerScrollEvent(position: at, scrollDelta: const Offset(0, 100)));
    await tester.pump();
    expect(scroll.offset, greaterThan(0));
    scroll.jumpTo(0);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    tester.binding.handlePointerEvent(PointerScrollEvent(position: tester.getCenter(find.byType(UiPathEditor)), scrollDelta: const Offset(0, 100)));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(scroll.offset, 0);
  });

  group('pen', () {
    testWidgets('taps place corners; tapping the first point closes the shape into a new item', (tester) async {
      await pumpUi(tester, const _Host(mode: UiPathEditorMode.pen), size: const Size(800, 600));
      await _tap(tester, _screen(10, 10));
      await _tap(tester, _screen(80, 10));
      await _tap(tester, _screen(80, 80));
      expect(_host(tester).key.currentState!.penCount, 3);
      await _tap(tester, _screen(10, 10));
      final h = _host(tester);
      expect(h.items, hasLength(1));
      expect(h.items[0].contours[0].closed, isTrue);
      expect(h.items[0].contours[0].points, hasLength(3));
      expect(h.selectedId, h.items[0].id);
      expect(h.key.currentState!.penCount, 0);
    });

    testWidgets('dragging while placing a point makes it a curve with handles in line; Enter finishes a line', (tester) async {
      await pumpUi(tester, const _Host(mode: UiPathEditorMode.pen), size: const Size(800, 600));
      await _tap(tester, _screen(10, 50));
      final g = await tester.startGesture(_screen(50, 50), kind: PointerDeviceKind.mouse);
      await g.moveTo(_screen(55, 50));
      await g.moveTo(_screen(60, 40));
      await g.up();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      final p = _host(tester).items.single.contours.single.points[1];
      expect(p.handleOut!.dx, closeTo(60, 0.01));
      expect(p.handleOut!.dy, closeTo(40, 0.01));
      expect(p.handleIn!.dx, closeTo(40, 0.01));
      expect(p.handleIn!.dy, closeTo(60, 0.01));
      expect(_host(tester).items.single.contours.single.closed, isFalse);
    });

    testWidgets('Shift keeps the next point to 45 degrees; Backspace takes back the last point', (tester) async {
      await pumpUi(tester, const _Host(mode: UiPathEditorMode.pen), size: const Size(800, 600));
      await _tap(tester, _screen(10, 10));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _tap(tester, _screen(50, 14));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await _tap(tester, _screen(90, 90));
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(_host(tester).key.currentState!.penCount, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      final pts = _host(tester).items.single.contours.single.points;
      expect(pts[1].y, closeTo(10, 0.01));
    });

    testWidgets('leaving the pen finishes the path', (tester) async {
      await pumpUi(tester, const _Host(mode: UiPathEditorMode.pen), size: const Size(800, 600));
      await _tap(tester, _screen(10, 10));
      await _tap(tester, _screen(50, 50));
      final h = _host(tester);
      h.setMode(UiPathEditorMode.objects);
      await tester.pump();
      await tester.pump();
      expect(h.items, hasLength(1));
      expect(h.items[0].contours[0].points, hasLength(2));
    });
  });

  group('draw', () {
    testWidgets('a stroke is reported with its samples and the area it paints', (tester) async {
      await pumpUi(tester, const _Host(mode: UiPathEditorMode.draw), size: const Size(800, 600));
      final g = await tester.startGesture(_screen(10, 50), kind: PointerDeviceKind.mouse);
      for (var x = 12.0; x <= 90; x += 4) {
        await g.moveTo(_screen(x, 50));
      }
      await g.up();
      final s = _host(tester).strokes.single;
      expect(s.samples.length, greaterThan(5));
      expect(s.pieces, isNotEmpty);
      expect(s.shape, isNull);
      // Ends where the pointer lifted (the last move, at 88), not where the steadied line had got to.
      expect(s.samples.last.x, closeTo(88, 1e-6));
      expect(_host(tester).items, isEmpty);
    });

    testWidgets("a pen's pressure is used; once a pen is seen, a finger pans instead of drawing; a resting hand is ignored", (tester) async {
      await pumpUi(tester, const _Host(mode: UiPathEditorMode.draw, brush: UiBrush(kind: UiBrushKind.pencil, size: 4)), size: const Size(800, 600));
      final pen = await tester.createGesture(kind: PointerDeviceKind.stylus, pointer: 5);
      await pen.downWithCustomEvent(_screen(10, 50), PointerDownEvent(pointer: 5, position: _screen(10, 50), kind: PointerDeviceKind.stylus, pressure: 0.9, pressureMax: 1));
      expect(_host(tester).pens, 1);
      // A palm landing while the pen draws.
      final palm = await tester.startGesture(_screen(60, 80));
      await palm.up();
      for (var x = 14.0; x <= 60; x += 4) {
        await pen.moveTo(_screen(x, 50));
      }
      await pen.up();
      final s = _host(tester).strokes.single;
      expect(s.samples.first.pressure, closeTo(0.9, 1e-9));
      // A finger now pans: no stroke.
      final f = await tester.startGesture(_screen(30, 30));
      await f.moveBy(const Offset(60, 0));
      await f.up();
      expect(_host(tester).strokes, hasLength(1));
    });

    testWidgets('holding still at the end of a loop snaps it to a circle', (tester) async {
      await pumpUi(tester, const _Host(mode: UiPathEditorMode.draw), size: const Size(800, 600));
      final g = await tester.startGesture(_screen(80, 50), kind: PointerDeviceKind.mouse);
      for (var i = 1; i <= 48; i++) {
        final a = i / 48 * 2 * math.pi;
        await g.moveTo(_screen(50 + 30 * math.cos(a), 50 + 30 * math.sin(a)));
      }
      await tester.pump(const Duration(milliseconds: 700));
      await g.up();
      final s = _host(tester).strokes.single;
      expect(s.shape, isA<UiInkEllipse>());
    });
  });

  group('Shift-click straight strokes', () {
    Future<void> shiftTap(WidgetTester tester, Offset at) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _tap(tester, at);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    }

    /// How far [p] is from the segment a-b.
    double off(UiInkSample p, Offset a, Offset b) {
      final v = b - a;
      final t = (((p.x - a.dx) * v.dx + (p.y - a.dy) * v.dy) / (v.dx * v.dx + v.dy * v.dy)).clamp(0.0, 1.0);
      return (p.offset - (a + v * t)).distance;
    }

    void along(UiInkStroke s, Offset a, Offset b) {
      expect(s.samples.first.x, closeTo(a.dx, 1e-6));
      expect(s.samples.first.y, closeTo(a.dy, 1e-6));
      expect(s.samples.last.x, closeTo(b.dx, 1e-6));
      expect(s.samples.last.y, closeTo(b.dy, 1e-6));
      expect(s.samples.length, greaterThan(2));
      for (final p in s.samples) {
        expect(off(p, a, b), lessThan(1e-6));
      }
      expect(s.pieces, hasLength(s.samples.length - 1));
    }

    testWidgets('a Shift-click strokes straight from where the last stroke ended, with the current brush', (tester) async {
      await pumpUi(tester, const _Host(mode: UiPathEditorMode.draw, brush: UiBrush(kind: UiBrushKind.brush, size: 6)), size: const Size(800, 600));
      final g = await tester.startGesture(_screen(10, 50), kind: PointerDeviceKind.mouse);
      for (var x = 14.0; x <= 30; x += 4) {
        await g.moveTo(_screen(x, 50));
      }
      await g.up();
      final end = _host(tester).strokes.single.samples.last.offset;
      await shiftTap(tester, _screen(70, 20));
      final strokes = _host(tester).strokes;
      expect(strokes, hasLength(2));
      expect(strokes[1].brush, const UiBrush(kind: UiBrushKind.brush, size: 6));
      expect(strokes[1].shape, isNull);
      along(strokes[1], end, const Offset(70, 20));
    });

    testWidgets('Shift-clicks chain, each one stroke from the point before', (tester) async {
      await pumpUi(tester, const _Host(mode: UiPathEditorMode.draw), size: const Size(800, 600));
      await _tap(tester, _screen(10, 10));
      await shiftTap(tester, _screen(60, 10));
      await shiftTap(tester, _screen(60, 70));
      final strokes = _host(tester).strokes;
      expect(strokes, hasLength(3));
      along(strokes[1], const Offset(10, 10), const Offset(60, 10));
      along(strokes[2], const Offset(60, 10), const Offset(60, 70));
    });

    testWidgets('the eraser erases along the line', (tester) async {
      await pumpUi(tester, const _Host(mode: UiPathEditorMode.draw, brush: UiBrush(kind: UiBrushKind.eraser, size: 8)), size: const Size(800, 600));
      await _tap(tester, _screen(10, 30));
      await shiftTap(tester, _screen(90, 30));
      final s = _host(tester).strokes[1];
      expect(s.brush.kind, UiBrushKind.eraser);
      along(s, const Offset(10, 30), const Offset(90, 30));
    });

    testWidgets('with no point remembered, a Shift-click is a plain dot (and is remembered)', (tester) async {
      await pumpUi(tester, const _Host(mode: UiPathEditorMode.draw), size: const Size(800, 600));
      await shiftTap(tester, _screen(40, 40));
      final strokes = _host(tester).strokes;
      expect(strokes.single.samples, hasLength(1));
      expect(strokes.single.samples.single.x, closeTo(40, 1e-6));
      await shiftTap(tester, _screen(80, 40));
      along(strokes[1], const Offset(40, 40), const Offset(80, 40));
    });

    testWidgets('another brush, another mode, an undo by the host or clearLineStart() forget the point', (tester) async {
      await pumpUi(tester, const _Host(mode: UiPathEditorMode.draw), size: const Size(800, 600));
      final h = _host(tester);
      Future<void> dotAt(double x, double y) async {
        await shiftTap(tester, _screen(x, y));
        expect(h.strokes.last.samples.every((p) => (p.x - x).abs() < 1e-6 && (p.y - y).abs() < 1e-6), isTrue, reason: '($x, $y)');
      }

      // The host keeps each stroke as an item: that change keeps the point.
      Future<void> keep() async {
        h.update(() => h.items = [...h.items, UiPathItem(id: 's${h.strokes.length}', contours: [rectContour(0, 0, 1, 1)])]);
        await tester.pump();
      }

      await _tap(tester, _screen(10, 10));
      await keep();
      await shiftTap(tester, _screen(50, 10));
      await keep();
      along(h.strokes[1], const Offset(10, 10), const Offset(50, 10));
      // Undo: the host takes the line back.
      h.update(() => h.items = h.items.sublist(0, 1));
      await tester.pump();
      await dotAt(50, 50);

      h.update(() => h.brush = const UiBrush(kind: UiBrushKind.marker, size: 4));
      await tester.pump();
      await dotAt(20, 80);

      h.setMode(UiPathEditorMode.objects);
      await tester.pump();
      h.setMode(UiPathEditorMode.draw);
      await tester.pump();
      await dotAt(30, 80);

      h.key.currentState!.clearLineStart();
      await tester.pump();
      await dotAt(40, 80);
    });

    testWidgets('keeps the point when the host reshapes the stroke it kept a moment later (as a tidied outline)', (tester) async {
      await pumpUi(tester, const _Host(mode: UiPathEditorMode.draw), size: const Size(800, 600));
      final h = _host(tester);
      await _tap(tester, _screen(10, 10));
      h.update(() => h.items = [...h.items, UiPathItem(id: 'kept', contours: [rectContour(9, 9, 2, 2)])]);
      await tester.pump();
      // A beat later the host swaps in a cleaner outline for the same item.
      h.update(() => h.items = [for (final i in h.items) i.id == 'kept' ? UiPathItem(id: 'kept', contours: [rectContour(8, 8, 4, 4)]) : i]);
      await tester.pump();
      await shiftTap(tester, _screen(60, 10));
      along(h.strokes[1], const Offset(10, 10), const Offset(60, 10));
    });

    testWidgets('Shift + drag strokes straight to where the drag starts, then carries on freehand in the same stroke', (tester) async {
      await pumpUi(tester, const _Host(mode: UiPathEditorMode.draw), size: const Size(800, 600));
      await _tap(tester, _screen(10, 10));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      final g = await tester.startGesture(_screen(50, 10), kind: PointerDeviceKind.mouse);
      for (final y in const [20.0, 30.0, 40.0]) {
        await g.moveTo(_screen(50, y));
      }
      await g.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      final s = _host(tester).strokes;
      expect(s, hasLength(2));
      expect(s[1].samples.first.offset, const Offset(10, 10));
      final corner = s[1].samples.indexWhere((p) => (p.x - 50).abs() < 1e-6 && (p.y - 10).abs() < 1e-6);
      expect(corner, greaterThan(1));
      for (final p in s[1].samples.take(corner + 1)) {
        expect(p.y, closeTo(10, 1e-6));
      }
      expect(s[1].samples.last.y, closeTo(40, 1e-6));
    });

    testWidgets('shows a faint line from the point to the pointer while Shift is held, and drops it on release', (tester) async {
      await pumpUi(tester, const _Host(mode: UiPathEditorMode.draw), size: const Size(800, 600));
      final state = _host(tester).key.currentState!;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: _screen(70, 70));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await mouse.moveTo(_screen(70, 72));
      await tester.pump();
      expect(state.linePreview, isNull); // nothing remembered yet
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await _tap(tester, _screen(20, 20));
      await mouse.moveTo(_screen(70, 60));
      await tester.pump();
      expect(state.linePreview, isNull); // no Shift
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      var (a, b) = state.linePreview!;
      expect((a - const Offset(20, 20)).distance, lessThan(1e-6));
      expect((b - const Offset(70, 60)).distance, lessThan(1e-6));
      await mouse.moveTo(_screen(80, 30));
      await tester.pump();
      (a, b) = state.linePreview!;
      expect((b - const Offset(80, 30)).distance, lessThan(1e-6));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(state.linePreview, isNull);
      await mouse.removePointer();
    });

    testWidgets('straightLine connects every press after the first, without Shift', (tester) async {
      await pumpUi(tester, const _Host(mode: UiPathEditorMode.draw), size: const Size(800, 600));
      final h = _host(tester);
      h.update(() => h.straight = true);
      await tester.pump();
      await _tap(tester, _screen(10, 90), kind: PointerDeviceKind.touch);
      await _tap(tester, _screen(90, 90), kind: PointerDeviceKind.touch);
      await _tap(tester, _screen(90, 10), kind: PointerDeviceKind.touch);
      expect(h.strokes, hasLength(3));
      expect(h.strokes[0].samples, hasLength(1));
      along(h.strokes[1], const Offset(10, 90), const Offset(90, 90));
      along(h.strokes[2], const Offset(90, 90), const Offset(90, 10));
    });
  });

  group('objects', () {
    testWidgets('tap selects, drag moves (one change on release), tap outside clears', (tester) async {
      await pumpUi(tester, _Host(mode: UiPathEditorMode.objects, items: [_square]), size: const Size(800, 600));
      await _tap(tester, _screen(40, 40));
      expect(_host(tester).selectedId, 'sq');
      final g = await tester.startGesture(_screen(40, 40), kind: PointerDeviceKind.mouse);
      await g.moveTo(_screen(45, 40));
      await g.moveTo(_screen(50, 50));
      await tester.pump();
      expect(_host(tester).changes, isEmpty);
      await g.up();
      await tester.pump();
      expect(_host(tester).changes, hasLength(1));
      expect(pathBounds(_host(tester).items[0].contours)!.left, closeTo(30, 0.01));
      await _tap(tester, _screen(90, 90));
      expect(_host(tester).selectedId, isNull);
    });

    testWidgets('a corner knob scales from the opposite corner; arrows nudge; brackets step the selection', (tester) async {
      await pumpUi(tester, _Host(mode: UiPathEditorMode.objects, items: [_square], selectedId: 'sq'), size: const Size(800, 600));
      final g = await tester.startGesture(_screen(60, 60), kind: PointerDeviceKind.mouse);
      await g.moveTo(_screen(65, 65));
      await g.moveTo(_screen(80, 80));
      await g.up();
      await tester.pump();
      expect(pathBounds(_host(tester).items[0].contours), const Rect.fromLTRB(20, 20, 80, 80));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(pathBounds(_host(tester).items[0].contours)!.left, closeTo(19, 1e-9));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_host(tester).selectedId, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.pump();
      expect(_host(tester).selectedId, 'sq');
    });
  });

  group('points', () {
    testWidgets('Shift-click selects several points, and dragging one moves them all', (tester) async {
      await pumpUi(tester, _Host(mode: UiPathEditorMode.points, items: [_square], selectedId: 'sq'), size: const Size(800, 600));
      await _tap(tester, _screen(20, 20));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _tap(tester, _screen(60, 20));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(_host(tester).points, const [UiPointRef(0, 0), UiPointRef(0, 1)]);
      final g = await tester.startGesture(_screen(60, 20), kind: PointerDeviceKind.mouse);
      await g.moveTo(_screen(60, 15));
      await g.moveTo(_screen(60, 10));
      await g.up();
      await tester.pump();
      expect(_host(tester).items[0].contours[0].points.map((p) => p.y.round()), [10, 10, 60, 60]);
    });

    testWidgets('a long press adds a point to the selection on a touch screen', (tester) async {
      await pumpUi(tester, _Host(mode: UiPathEditorMode.points, items: [_square], selectedId: 'sq'), size: const Size(800, 600));
      await _tap(tester, _screen(20, 20), kind: PointerDeviceKind.touch);
      final g = await tester.startGesture(_screen(60, 60));
      await tester.pump(const Duration(milliseconds: 500));
      await g.up();
      await tester.pump();
      expect(_host(tester).points, const [UiPointRef(0, 0), UiPointRef(0, 2)]);
    });

    testWidgets('a double tap switches a point between corner and curve; a tap on an edge adds a point', (tester) async {
      await pumpUi(tester, _Host(mode: UiPathEditorMode.points, items: [_square], selectedId: 'sq'), size: const Size(800, 600));
      await _tap(tester, _screen(20, 20));
      await _tap(tester, _screen(20, 20));
      expect(_host(tester).items[0].contours[0].points[0].smooth, isTrue);
      await _tap(tester, _screen(40, 60));
      expect(_host(tester).items[0].contours[0].points, hasLength(5));
      expect(_host(tester).point, const UiPointRef(0, 3));
    });

    testWidgets('a mouse drag across empty space selects the points inside; Delete removes them', (tester) async {
      await pumpUi(tester, _Host(mode: UiPathEditorMode.points, items: [_square], selectedId: 'sq'), size: const Size(800, 600));
      final g = await tester.startGesture(_screen(5, 5), kind: PointerDeviceKind.mouse);
      await g.moveTo(_screen(30, 30));
      await g.moveTo(_screen(70, 30));
      await g.up();
      await tester.pump();
      expect(_host(tester).points, const [UiPointRef(0, 0), UiPointRef(0, 1)]);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      final c = _host(tester).items[0].contours.single;
      expect(c.points, hasLength(2));
      expect(c.closed, isFalse);
    });

    testWidgets('Alt-dragging a corner pulls curve handles out of it', (tester) async {
      await pumpUi(tester, _Host(mode: UiPathEditorMode.points, items: [_square], selectedId: 'sq'), size: const Size(800, 600));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      final g = await tester.startGesture(_screen(60, 20), kind: PointerDeviceKind.mouse);
      await g.moveTo(_screen(64, 18));
      await g.moveTo(_screen(70, 15));
      await g.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();
      final p = _host(tester).items[0].contours[0].points[1];
      expect(p.handleOut!.dx, closeTo(70, 0.01));
      expect(p.handleIn!.dx, closeTo(50, 0.01));
      expect(p.handleIn!.dy, closeTo(25, 0.01));
    });
  });

  testWidgets('pinch zooms; the view is labelled', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, _Host(mode: UiPathEditorMode.objects, items: [_square]), size: const Size(800, 600));
    expect(find.bySemanticsLabel('Shape editor'), findsOneWidget);
    final a = await tester.startGesture(const Offset(150, 150), pointer: 1);
    final b = await tester.startGesture(const Offset(250, 150), pointer: 2);
    await a.moveTo(const Offset(100, 150));
    await b.moveTo(const Offset(300, 150));
    await a.up();
    await b.up();
    await tester.pump();
    // Twice the zoom about (50, 50), which stayed between the fingers: this spot was unit 65 (outside
    // the square), and is now 57.5 (inside).
    await _tap(tester, Offset(200 + 7.5 * _px * 2, 150));
    expect(_host(tester).selectedId, 'sq');
    expect(_host(tester).changes, isEmpty);
    handle.dispose();
  });

  testWidgets('golden: objects frame, points with handles, a cut, and the pen', (tester) async {
    final items = [
      UiPathItem(id: 'a', contours: [ellipseContour(30, 35, 22, 22)]),
      UiPathItem(id: 'b', contours: [starContour(50, 15, 45, 45)]),
      UiPathItem(id: 'c', contours: [rectContour(15, 62, 70, 26, 8)], op: UiPathOp.cut),
    ];
    await expectThemedGolden(tester, 'path_editor', width: 390, height: 580, (context) => Column(spacing: 12, children: [
          SizedBox(height: 260, child: UiPathEditor(items: items, selectedId: 'b')),
          SizedBox(
            height: 260,
            child: UiPathEditor(items: items, mode: UiPathEditorMode.points, selectedId: 'a', selectedPoint: const UiPointRef(0, 1), selectedPoints: const [UiPointRef(0, 0), UiPointRef(0, 1)]),
          ),
        ]));
  });
  group('loupe', () {
    Finder paint() => find.descendant(of: find.byType(UiPathEditor), matching: find.byType(CustomPaint)).first;
    Offset? loupe(WidgetTester tester) => (tester.widget<CustomPaint>(paint()).painter as dynamic).loupe as Offset?;

    testWidgets('shows what a painting finger hides, magnified, beside it, and goes when it lifts', (tester) async {
      await pumpUi(tester, const _Host(mode: UiPathEditorMode.draw, brush: UiBrush(kind: UiBrushKind.marker, size: 6)), size: const Size(800, 600));
      final origin = tester.getTopLeft(find.byType(UiPathEditor));
      final g = await tester.startGesture(_screen(50, 50), kind: PointerDeviceKind.touch);
      await tester.pump();
      expect(loupe(tester), _screen(50, 50) - origin);
      await g.moveTo(_screen(60, 55));
      await tester.pump();
      final finger = _screen(60, 55) - origin;
      expect(loupe(tester), finger);
      final place = uiLoupePlace(finger, const Size(400, 300));
      expect(place.center.dx, lessThan(finger.dx));
      expect(place.center.dy, lessThan(finger.dy));
      // The brush's outline (6 units across) at twice the zoom, in the middle of the loupe.
      expect(tester.renderObject(paint()), paints..circle(x: place.center.dx, y: place.center.dy, radius: 3 * _px * 2));
      await g.up();
      await tester.pump();
      expect(loupe(tester), isNull);
      expect(_host(tester).strokes, hasLength(1));
    });

    testWidgets('never for a mouse, nor with loupe off, and a second finger (a pinch) puts it away', (tester) async {
      await pumpUi(tester, const _Host(mode: UiPathEditorMode.draw), size: const Size(800, 600));
      final m = await tester.startGesture(_screen(50, 50), kind: PointerDeviceKind.mouse);
      await m.moveTo(_screen(60, 50));
      await tester.pump();
      expect(loupe(tester), isNull);
      await m.up();
      await tester.pump();

      final a = await tester.startGesture(_screen(50, 50), kind: PointerDeviceKind.touch, pointer: 2);
      await tester.pump();
      expect(loupe(tester), isNotNull);
      final b = await tester.startGesture(_screen(80, 50), kind: PointerDeviceKind.touch, pointer: 3);
      await tester.pump();
      expect(loupe(tester), isNull);
      await b.up();
      await a.up();
      await tester.pump();

      final h = _host(tester);
      h.update(() => h.loupe = false);
      await tester.pump();
      final c = await tester.startGesture(_screen(50, 50), kind: PointerDeviceKind.touch, pointer: 4);
      await tester.pump();
      expect(loupe(tester), isNull);
      await c.up();
      await tester.pump();
    });
  });
}
