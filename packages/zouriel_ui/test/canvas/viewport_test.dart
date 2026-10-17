import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

Future<UiCanvasViewportController> pumpViewport(
  WidgetTester tester, {
  Size size = const Size(800, 600),
  double cw = 400,
  double ch = 300,
  VoidCallback? onTap,
  List<UiMinimapItem> items = const [UiMinimapItem(Rect.fromLTWH(0, 0, 100, 50))],
  Widget? child,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  tester.view.gestureSettings = ui.GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
  addTearDown(tester.view.reset);
  final c = UiCanvasViewportController();
  addTearDown(c.dispose);
  await tester.pumpWidget(UiApp(
    home: UiCanvasViewport(
      controller: c,
      contentWidth: cw,
      contentHeight: ch,
      minimap: true,
      minimapItems: items,
      onBackgroundTap: onTap,
      child: child ?? const SizedBox.expand(),
    ),
  ));
  await tester.pump();
  return c;
}

void main() {
  testWidgets('fit centres the content and never zooms past 100%', (tester) async {
    final c = await pumpViewport(tester);
    expect(c.view.zoom, 1);
    expect(c.view.x, (800 - 400) / 2);
    expect(c.view.y, (600 - 300) / 2);
    expect(c.autoFit, isTrue);
  });

  testWidgets('large content is zoomed out to fit inside the padding', (tester) async {
    final c = await pumpViewport(tester, cw: 1600, ch: 600);
    expect(c.view.zoom, closeTo((800 - 64) / 1600, 1e-9));
    expect(c.view.x, closeTo((800 - 1600 * c.view.zoom) / 2, 1e-9));
  });

  testWidgets('auto-fit follows size changes until the person pans', (tester) async {
    final c = await pumpViewport(tester);
    tester.view.physicalSize = const Size(600, 600) * 2;
    await tester.pump();
    expect(c.view.x, (600 - 400) / 2);
    // Pan with a mouse drag on empty space.
    final g = await tester.startGesture(const Offset(300, 100), kind: PointerDeviceKind.mouse);
    await g.moveBy(const Offset(40, 0));
    await g.moveBy(const Offset(40, 0));
    await g.up();
    await tester.pump();
    expect(c.autoFit, isFalse);
    final x = c.view.x;
    expect(x, greaterThan((600 - 400) / 2));
    tester.view.physicalSize = const Size(800, 600) * 2;
    await tester.pump();
    expect(c.view.x, x);
  });

  testWidgets('keyboard: + zooms in, - out, 0 fits, arrows pan', (tester) async {
    final c = await pumpViewport(tester);
    await tester.tapAt(const Offset(700, 50)); // focus the canvas
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.pump();
    expect(c.view.zoom, closeTo(1.2, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.pump();
    expect(c.view.zoom, closeTo(1 / 1.2, 1e-9));
    final x = c.view.x;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(c.view.x, x + 40);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.pump();
    expect(c.view.zoom, 1);
    expect(c.autoFit, isTrue);
  });

  testWidgets('ctrl + wheel zooms around the pointer; a plain wheel pans', (tester) async {
    final c = await pumpViewport(tester);
    final before = c.view;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final p = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(p.hover(const Offset(400, 300)));
    await tester.sendEventToBinding(p.scroll(const Offset(0, -100)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(c.view.zoom, greaterThan(before.zoom));
    // The world point under the pointer stays put.
    expect(c.localToWorld(const Offset(400, 300)).dx, closeTo((400 - before.x) / before.zoom, 1e-6));
    final z = c.view;
    await tester.sendEventToBinding(p.scroll(const Offset(0, 50)));
    await tester.pump();
    expect(c.view.zoom, z.zoom);
    expect(c.view.y, z.y - 50);
  });

  testWidgets('two fingers pinch to zoom', (tester) async {
    final c = await pumpViewport(tester);
    final a = await tester.startGesture(const Offset(350, 300));
    final b = await tester.startGesture(const Offset(450, 300));
    for (var i = 1; i <= 5; i++) {
      await a.moveTo(Offset(350 - i * 10, 300));
      await b.moveTo(Offset(450 + i * 10, 300));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pump();
    expect(c.view.zoom, closeTo(2, 0.05));
  });

  testWidgets('the minimap shows only when the canvas is at least 520x340', (tester) async {
    await pumpViewport(tester);
    expect(find.byType(CustomPaint), findsWidgets);
    final big = find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_MinimapPainter');
    expect(big, findsOneWidget);
    await pumpViewport(tester, size: const Size(500, 600));
    expect(big, findsNothing);
    await pumpViewport(tester, size: const Size(800, 300));
    expect(big, findsNothing);
  });

  testWidgets('a tap on empty space is a background tap, a pan is not', (tester) async {
    var taps = 0;
    await pumpViewport(tester, onTap: () => taps++);
    await tester.tapAt(const Offset(300, 100));
    expect(taps, 1);
    final g = await tester.startGesture(const Offset(300, 100));
    for (var i = 0; i < 5; i++) {
      await g.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    await g.up();
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('the zoom buttons zoom and fit; reveal scrolls a rectangle into view', (tester) async {
    final c = await pumpViewport(tester);
    await tester.tap(find.bySemanticsLabel('Zoom in'));
    await tester.pump();
    expect(c.view.zoom, closeTo(1.2, 1e-9));
    expect(find.text('120%'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Fit to view'));
    await tester.pump();
    expect(c.view.zoom, 1);
    c.reveal(const Rect.fromLTWH(900, 0, 100, 50));
    expect(c.worldToLocal(const Offset(1000, 0)).dx, closeTo(800 - 24, 1e-9));
  });
}
