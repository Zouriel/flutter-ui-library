import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../overlay/screens.dart';

const _tablet = Size(1000, 700);

/// A host with an open/close button per window, inside its own window manager.
class _Host extends StatefulWidget {
  const _Host({required this.windows});
  final List<({String title, GlobalKey<UiWindowState> key, double x, double y, double w, double h})> windows;
  
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late final List<bool> open = [for (final _ in widget.windows) true];
  int closed = 0;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < widget.windows.length; i++) ...[
        UiButton(label: 'Open ${widget.windows[i].title}', onPressed: () => setState(() => open[i] = true)),
        UiWindow(
          key: widget.windows[i].key,
          open: open[i],
          onOpenChanged: (v) => setState(() => open[i] = v),
          onClosed: () => closed++,
          title: widget.windows[i].title,
          initialX: widget.windows[i].x,
          initialY: widget.windows[i].y,
          initialWidth: widget.windows[i].w,
          initialHeight: widget.windows[i].h,
          child: Text('${widget.windows[i].title} body'),
        ),
      ],
    ]);
  }
}

Future<(UiWindowManager, GlobalKey<UiWindowState>)> _pumpOne(
  WidgetTester tester, {
  Size size = _tablet,
  double x = 80,
  double y = 80,
  double w = 440,
  double h = 300,
}) async {
  final key = GlobalKey<UiWindowState>();
  final mgr = await _pump(tester, [(title: 'Test', key: key, x: x, y: y, w: w, h: h)], size: size);
  return (mgr, key);
}

Future<UiWindowManager> _pump(
  WidgetTester tester,
  List<({String title, GlobalKey<UiWindowState> key, double x, double y, double w, double h})> windows, {
  Size size = _tablet,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final mgr = UiWindowManager();
  await tester.pumpWidget(UiApp(home: UiWindowScope(manager: mgr, child: _Host(windows: windows))));
  await tester.pumpAndSettle();
  return mgr;
}

/// Drags the title bar from [from] to [to] (viewport coordinates); returns the gesture, not yet released.
Future<TestGesture> _drag(WidgetTester tester, Offset from, Offset to) async {
  final g = await tester.startGesture(from);
  await g.moveTo(Offset.lerp(from, to, 0.5)!);
  await g.moveTo(to);
  await tester.pump();
  return g;
}

void main() {
  testWidgets('closes through open/onOpenChanged, leaves the manager, and comes back when reopened', (tester) async {
    final (mgr, key) = await _pumpOne(tester);
    expect(mgr.count, 1);
    expect(find.text('Test body'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Test body'), findsNothing);
    expect(mgr.count, 0);
    expect(tester.state<_HostState>(find.byType(_Host)).closed, 1);

    await tester.tap(find.text('Open Test'));
    await tester.pumpAndSettle();
    expect(mgr.count, 1);
    expect(find.text('Test body'), findsOneWidget);
  });

  testWidgets('without onOpenChanged the window closes itself', (tester) async {
    tester.view.physicalSize = _tablet;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(home: UiWindowScope(manager: UiWindowManager(), child: const UiWindow(child: Text('Alone')))));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Alone'), findsNothing);
  });

  testWidgets("docks to the top half for 'top', and restore puts it back", (tester) async {
    final (_, key) = await _pumpOne(tester);
    key.currentState!.dock(UiDockSide.top);
    await tester.pumpAndSettle();
    expect(key.currentState!.bounds, const Rect.fromLTWH(0, 0, 1000, 350));
    expect(tester.getTopLeft(find.text('Test body')).dy, lessThan(80));
    key.currentState!.restore();
    await tester.pump();
    expect(key.currentState!.bounds, const Rect.fromLTWH(80, 80, 440, 300));
  });

  testWidgets('the title bar moves the window with the pointer', (tester) async {
    final (_, key) = await _pumpOne(tester);
    final before = tester.getTopLeft(find.text('Test body'));
    final g = await _drag(tester, const Offset(200, 100), const Offset(260, 160));
    expect(key.currentState!.bounds.topLeft, const Offset(140, 140));
    expect(tester.getTopLeft(find.text('Test body')), before + const Offset(60, 60));
    await g.up();
  });

  testWidgets('keeps at least 48px of the title bar on screen past the right or left edge', (tester) async {
    final (_, key) = await _pumpOne(tester);
    // The window starts at x = 80: an 880px drag would carry it past the right edge.
    var g = await _drag(tester, const Offset(90, 100), const Offset(1000 - 30, 300));
    expect(key.currentState!.bounds.left, 1000 - 48);
    await g.up();
    await tester.pump();
    // Grab what's left of the bar (now at y 280) and bring it back left, then pull it far past the left edge.
    g = await _drag(tester, const Offset(1000 - 20, 300), const Offset(40, 300));
    await g.up();
    await tester.pump();
    expect(key.currentState!.bounds.left, 12);
    g = await _drag(tester, const Offset(440, 300), const Offset(30, 300));
    expect(key.currentState!.bounds.right, 48);
    await g.up();
  });

  testWidgets('never lets the title bar go above the top or below the bottom edge', (tester) async {
    final (_, key) = await _pumpOne(tester);
    // Stops just short of the bottom snap band, so the release doesn't dock.
    var g = await _drag(tester, const Offset(200, 100), const Offset(200, 675));
    // A 49px bar on touch platforms (48dp buttons and the 1px border).
    expect(key.currentState!.bounds.top, 700 - 49);
    await g.up();
    await tester.pump();
    g = await _drag(tester, const Offset(200, 670), const Offset(200, -500));
    expect(key.currentState!.bounds.top, 0);
    await g.up();
  });

  testWidgets('opens inside the viewport even when the initial bounds reach past it', (tester) async {
    final (_, key) = await _pumpOne(tester, x: 5000, y: 40, w: 5000, h: 200);
    final b = key.currentState!.bounds;
    expect(b.width, lessThanOrEqualTo(1000));
    expect(b.left, greaterThanOrEqualTo(0));
    expect(b.right, lessThanOrEqualTo(1000));
  });

  testWidgets('dragging near the left edge shows a preview and docks to the left half on release', (tester) async {
    final (_, key) = await _pumpOne(tester);
    final g = await _drag(tester, const Offset(200, 100), const Offset(10, 400));
    expect(find.byKey(const Key('ui-window-snap-preview')), findsOneWidget);
    expect(tester.getRect(find.byKey(const Key('ui-window-snap-preview'))), const Rect.fromLTWH(0, 0, 500, 700));
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ui-window-snap-preview')), findsNothing);
    expect(key.currentState!.bounds, const Rect.fromLTWH(0, 0, 500, 700));
  });

  testWidgets('Maximize and Restore, by button and by double-tapping the title bar', (tester) async {
    final (_, key) = await _pumpOne(tester);
    await tester.tap(find.bySemanticsLabel('Maximize'));
    await tester.pumpAndSettle();
    expect(key.currentState!.isMaximized, isTrue);
    expect(key.currentState!.bounds, const Rect.fromLTWH(0, 0, 1000, 700));
    await tester.tap(find.bySemanticsLabel('Restore'));
    await tester.pumpAndSettle();
    expect(key.currentState!.bounds, const Rect.fromLTWH(80, 80, 440, 300));

    await tester.tap(find.text('Test'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Test'));
    await tester.pumpAndSettle();
    expect(key.currentState!.isMaximized, isTrue);
  });

  testWidgets('Minimize collapses the window to its title bar', (tester) async {
    final (_, key) = await _pumpOne(tester);
    await tester.tap(find.bySemanticsLabel('Minimize'));
    await tester.pumpAndSettle();
    expect(key.currentState!.isMinimized, isTrue);
    expect(find.text('Test body'), findsNothing);
    expect(find.text('Test'), findsOneWidget);
    key.currentState!.restore();
    await tester.pumpAndSettle();
    expect(find.text('Test body'), findsOneWidget);
  });

  testWidgets('minimized, the Minimize control becomes Restore and brings the window back, still maximized', (tester) async {
    final (_, key) = await _pumpOne(tester);
    key.currentState!.dock(UiDockSide.maximize);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Minimize'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Minimize'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Restore').first);
    await tester.pumpAndSettle();
    expect(key.currentState!.isMinimized, isFalse);
    expect(key.currentState!.isMaximized, isTrue);
    expect(find.text('Test body'), findsOneWidget);
    expect(find.bySemanticsLabel('Minimize'), findsOneWidget);
  });

  testWidgets('resizes from the corner and the edges, never below 220 x 120', (tester) async {
    final (_, key) = await _pumpOne(tester);
    // Bottom-right corner sits on the window's corner (520, 380).
    var g = await _drag(tester, const Offset(518, 378), const Offset(618, 428));
    expect(key.currentState!.bounds, const Rect.fromLTWH(80, 80, 540, 350));
    await g.up();
    await tester.pump();
    // The left edge, pulled far right: stops at the minimum width, with the right edge fixed.
    g = await _drag(tester, const Offset(80, 250), const Offset(900, 250));
    expect(key.currentState!.bounds, const Rect.fromLTWH(620 - 220, 80, 220, 350));
    await g.up();
    await tester.pump();
    g = await _drag(tester, const Offset(500, 80), const Offset(500, 600));
    expect(key.currentState!.bounds.height, 120);
    expect(key.currentState!.bounds.bottom, 430);
    await g.up();
  });

  testWidgets('a press brings a window to the front', (tester) async {
    final a = GlobalKey<UiWindowState>(), b = GlobalKey<UiWindowState>();
    final mgr = await _pump(tester, [
      (title: 'Back', key: a, x: 100, y: 100, w: 400, h: 300),
      (title: 'Front', key: b, x: 200, y: 150, w: 400, h: 300),
    ]);
    expect(mgr.order.last, b.currentState!.id);
    // (150, 300) is only on Back; (300, 350) is on both, and Front is on top.
    expect(tester.hitTestOnBinding(const Offset(300, 350)).path.any((e) => e.target == tester.renderObject(find.text('Front body'))), isFalse);
    await tester.tapAt(const Offset(150, 300));
    await tester.pumpAndSettle();
    expect(mgr.order.last, a.currentState!.id);
    expect(mgr.focusedId, a.currentState!.id);
    // Back now covers Front where they overlap.
    final hit = tester.hitTestOnBinding(tester.getCenter(find.text('Front body')));
    expect(hit.path.any((e) => e.target == tester.renderObject(find.text('Front body'))), isFalse);
    mgr.focus(b.currentState!.id);
    await tester.pumpAndSettle();
    expect(mgr.order.last, b.currentState!.id);
  });

  testWidgets('tile() lays the windows out in a grid; minimizeAll and restoreAll reach every one', (tester) async {
    final a = GlobalKey<UiWindowState>(), b = GlobalKey<UiWindowState>(), c = GlobalKey<UiWindowState>();
    final mgr = await _pump(tester, [
      (title: 'A', key: a, x: 10, y: 10, w: 300, h: 200),
      (title: 'B', key: b, x: 20, y: 20, w: 300, h: 200),
      (title: 'C', key: c, x: 30, y: 30, w: 300, h: 200),
    ]);
    mgr.tile();
    await tester.pumpAndSettle();
    // 8px apart and 8px in from the edges.
    expect(a.currentState!.bounds, const Rect.fromLTWH(8, 8, 488, 338));
    expect(b.currentState!.bounds, const Rect.fromLTWH(504, 8, 488, 338));
    expect(c.currentState!.bounds, const Rect.fromLTWH(8, 354, 488, 338));
    mgr.minimizeAll();
    await tester.pumpAndSettle();
    expect([a, b, c].every((k) => k.currentState!.isMinimized), isTrue);
    mgr.restoreAll();
    await tester.pumpAndSettle();
    expect([a, b, c].every((k) => !k.currentState!.isMinimized), isTrue);
    mgr.dock(b.currentState!.id, UiDockSide.right);
    await tester.pumpAndSettle();
    expect(b.currentState!.bounds, const Rect.fromLTWH(500, 0, 500, 700));
  });

  testWidgets('on a phone it opens as a full-screen sheet with only Close', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844), padding: EdgeInsets.only(top: 24)),
        child: UiWindowScope(manager: UiWindowManager(), child: const UiWindow(title: 'Sheet', child: Text('Sheet body'))),
      ),
    ));
    await tester.pumpAndSettle();
    final state = tester.state<UiWindowState>(find.byType(UiWindow));
    expect(state.isSheet, isTrue);
    expect(find.bySemanticsLabel('Minimize'), findsNothing);
    expect(find.bySemanticsLabel('Maximize'), findsNothing);
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    // Full width, starting under the status bar, down to the bottom.
    final title = tester.getRect(find.text('Sheet'));
    expect(title.top, greaterThan(24));
    expect(title.top, lessThan(24 + 48));
    // A drag on the title bar doesn't move it.
    final g = await _drag(tester, title.center, title.center + const Offset(0, 200));
    await g.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Sheet')), title);
  });

  testWidgets('a named window, labelled controls with full-size touch targets', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpOne(tester);
    final node = tester.getSemantics(find.text('Test body'));
    SemanticsNode? n = node;
    var named = false;
    while (n != null) {
      final d = n.getSemanticsData();
      if (d.flagsCollection.scopesRoute && d.flagsCollection.namesRoute && d.label == 'Test') named = true;
      n = n.parent;
    }
    expect(named, isTrue);
    for (final l in ['Minimize', 'Maximize', 'Close']) {
      expect(tester.getSize(find.bySemanticsLabel(l)), const Size(48, 48));
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('golden: windows on a tablet, the snap preview, and the phone sheet', (tester) async {
    debugDisableShadows = false;
    await pumpScreens(
      tester,
      screen: const Size(620, 420),
      (context) => UiWindowScope(
        manager: UiWindowManager(),
        child: Stack(children: [
          const UiWindow(
            title: 'Activity',
            initialX: 300,
            initialY: 150,
            initialWidth: 280,
            initialHeight: 200,
            child: Text('A second floating window. Tap it to bring it to the front.'),
          ),
          UiWindow(
            title: 'Inspector',
            initialX: 40,
            initialY: 40,
            initialWidth: 340,
            initialHeight: 220,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
              const UiText('Drag the title bar; snap to an edge; resize from the corners.'),
              UiButton(label: 'Apply', size: UiSize.sm, onPressed: () {}),
            ]),
          ),
        ]),
      ),
    );
    await expectScreensGolden(tester, 'window_tablet');

    // Drag the Inspector in the dark screen toward its right edge: the right-half preview shows.
    final bar = tester.getRect(find.text('Inspector').first);
    final g = await tester.startGesture(bar.center);
    await g.moveTo(bar.center + const Offset(100, 40));
    await g.moveTo(const Offset(612, 200));
    await tester.pumpAndSettle();
    await expectScreensGolden(tester, 'window_snap_preview');
    await g.up();
    await tester.pumpAndSettle();
    // A fresh tree: pumpScreens' Navigators would otherwise keep the first page.
    await tester.pumpWidget(const SizedBox());

    await pumpScreens(
      tester,
      padding: const EdgeInsets.only(top: 24),
      (context) => UiWindowScope(
        manager: UiWindowManager(),
        child: const UiWindow(title: 'Inspector', child: UiText('On a phone the window opens as a full-screen sheet with a Close button.')),
      ),
    );
    await expectScreensGolden(tester, 'window_sheet');
    debugDisableShadows = true;
  });
}
