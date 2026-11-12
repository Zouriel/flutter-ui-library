import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

final _ctx = GlobalKey();

Widget _box(String id, String label, {double w = 120, double h = 40}) => UiTourAnchor(
      id: id,
      child: SizedBox(width: w, height: h, child: Center(child: Text(label))),
    );

/// A page with four anchors spread over the screen and a focusable field.
Widget _page({bool withC = true, FocusNode? focus}) => Builder(
      key: _ctx,
      builder: (context) => Stack(children: [
        Positioned(left: 20, top: 100, child: _box('a', 'A')),
        Positioned(right: 20, top: 300, child: _box('b', 'B')),
        if (withC) Positioned(left: 40, bottom: 60, child: _box('c', 'C')),
        Positioned(left: 150, top: 500, child: Focus(focusNode: focus, child: const SizedBox(width: 10, height: 10))),
      ]),
    );

const _spec = UiTourSpec('tour.test', [
  UiTourStep('a', 'Your events show up here.'),
  UiTourStep('b', 'Invitations land here.', title: 'Inbox'),
  UiTourStep('missing', 'Never shown.'),
  UiTourStep('c', 'Start an event.'),
]);

Future<void> _pumpApp(WidgetTester tester, Widget home, {Size size = const Size(390, 844), bool animate = true}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = size * 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(theme: UiThemeName.light, config: UiConfig(animations: animate), home: home));
  await tester.pump();
}

/// Lets the tour scroll, settle and fade in (it never "settles" for pumpAndSettle while the ring breathes).
Future<void> _steps(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Every label in the semantics tree as built (finders also see nodes that BlockSemantics drops).
List<String> _labels(WidgetTester tester) {
  final out = <String>[];
  bool visit(SemanticsNode n) {
    if (n.label.isNotEmpty) out.add(n.label);
    n.visitChildren(visit);
    return true;
  }

  visit(tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
  return out;
}

Rect _bubble(WidgetTester tester) => tester.getRect(find.ancestor(of: find.textContaining(' of '), matching: find.byType(DecoratedBox)).first);

void main() {
  testWidgets('cuts the hole round the anchor (6px out), counts only steps that have an anchor', (tester) async {
    await _pumpApp(tester, _page());
    final done = UiTour.start(_ctx.currentContext!, _spec);
    await _steps(tester);
    expect(UiTour.active, 'tour.test');
    expect(UiTour.debugHole, tester.getRect(find.byWidgetPredicate((w) => w is UiTourAnchor && w.id == 'a')).inflate(6));
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('Your events show up here.'), findsOneWidget);
    expect(find.text('Back'), findsNothing);

    await tester.tap(find.text('Next'));
    await _steps(tester);
    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    expect(UiTour.debugHole, tester.getRect(find.byWidgetPredicate((w) => w is UiTourAnchor && w.id == 'b')).inflate(6));

    await tester.tap(find.text('Back'));
    await _steps(tester);
    expect(find.text('1 of 3'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await _steps(tester);
    await tester.tap(find.text('Next'));
    await _steps(tester);
    expect(find.text('3 of 3'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(await done, UiTourOutcome.finished);
    expect(UiTour.active, isNull);
    expect(find.text('3 of 3'), findsNothing);
  });

  testWidgets('Skip, Turn off tips and Escape end it with their outcomes', (tester) async {
    await _pumpApp(tester, _page());
    var f = UiTour.start(_ctx.currentContext!, _spec);
    await _steps(tester);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(await f, UiTourOutcome.skipped);

    f = UiTour.start(_ctx.currentContext!, _spec);
    await _steps(tester);
    await tester.tap(find.text('Turn off tips'));
    await tester.pump();
    expect(await f, UiTourOutcome.turnedOff);

    f = UiTour.start(_ctx.currentContext!, _spec);
    await _steps(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(await f, UiTourOutcome.closed);

    f = UiTour.start(_ctx.currentContext!, const UiTourSpec('t', [UiTourStep('a', 'x')], turnOff: false));
    await _steps(tester);
    expect(find.text('Turn off tips'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
    UiTour.stop();
    await tester.pump();
    expect(await f, UiTourOutcome.closed);
  });

  testWidgets('with no anchors on the page it ends closed at once; more than 5 steps are cut to 5', (tester) async {
    await _pumpApp(tester, _page());
    expect(await UiTour.start(_ctx.currentContext!, const UiTourSpec('t', [UiTourStep('nope', 'x')])), UiTourOutcome.closed);
    final many = UiTourSpec('t', [for (var i = 0; i < 7; i++) UiTourStep(i.isEven ? 'a' : 'b', 'Step $i')]);
    final f = UiTour.start(_ctx.currentContext!, many);
    await _steps(tester);
    expect(find.text('1 of 5'), findsOneWidget);
    UiTour.stop();
    await tester.pump();
    await f;
  });

  testWidgets('a second tour ends the first with closed', (tester) async {
    await _pumpApp(tester, _page());
    final first = UiTour.start(_ctx.currentContext!, _spec);
    await _steps(tester);
    final second = UiTour.start(_ctx.currentContext!, const UiTourSpec('two', [UiTourStep('b', 'Second')]));
    expect(await first, UiTourOutcome.closed);
    await _steps(tester);
    expect(find.text('Second'), findsOneWidget);
    expect(UiTour.active, 'two');
    UiTour.stop();
    await tester.pump();
    await second;
  });

  testWidgets('an anchor gone mid-tour is skipped; Next past the last one finishes', (tester) async {
    final withC = ValueNotifier(true);
    await _pumpApp(tester, ValueListenableBuilder<bool>(valueListenable: withC, builder: (_, c, _) => _page(withC: c)));
    final f = UiTour.start(_ctx.currentContext!, _spec);
    await _steps(tester);
    await tester.tap(find.text('Next'));
    await _steps(tester);
    withC.value = false;
    await tester.pump();
    // Step 2 of 3 still says Next (c was there at the start); c is gone, so Next finishes.
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(await f, UiTourOutcome.finished);
  });

  testWidgets('Next on the first step finishes when every later anchor has gone', (tester) async {
    final withC = ValueNotifier(true);
    await _pumpApp(tester, ValueListenableBuilder<bool>(valueListenable: withC, builder: (_, c, _) => _page(withC: c)));
    const spec = UiTourSpec('tour.first', [UiTourStep('a', 'First.'), UiTourStep('c', 'Second.')]);
    final f = UiTour.start(_ctx.currentContext!, spec);
    await _steps(tester);
    withC.value = false;
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(await f, UiTourOutcome.finished);
  });

  testWidgets('moves focus into the bubble (Next), keeps Tab inside, and gives it back afterwards', (tester) async {
    final field = FocusNode();
    addTearDown(field.dispose);
    await _pumpApp(tester, _page(focus: field));
    field.requestFocus();
    await tester.pump();
    final f = UiTour.start(_ctx.currentContext!, _spec);
    await _steps(tester);
    expect(field.hasFocus, isFalse);
    final inBubble = FocusManager.instance.primaryFocus!;
    expect(find.descendant(of: find.byType(Semantics).hitTestable(), matching: find.text('Next')), findsWidgets);
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(field.hasFocus, isFalse, reason: 'Tab left the bubble');
    }
    expect(inBubble.context, isNotNull);
    // Enter on the focused Next goes on.
    UiTour.stop();
    await tester.pump();
    await f;
    expect(field.hasFocus, isTrue);
  });

  testWidgets('scrolls an anchor that is off screen inside a list into view first', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pumpApp(
      tester,
      Builder(
        key: _ctx,
        // Built children only: a lazy list's unbuilt rows have no anchor to find.
        builder: (_) => SingleChildScrollView(
          controller: controller,
          child: Column(children: [
            for (var i = 0; i < 40; i++) SizedBox(height: 80, child: Text('Row $i')),
            _box('far', 'Far'),
            for (var i = 0; i < 10; i++) SizedBox(height: 80, child: Text('More $i')),
          ]),
        ),
      ),
    );
    expect(controller.offset, 0);
    final f = UiTour.start(_ctx.currentContext!, const UiTourSpec('t', [UiTourStep('far', 'Down here.')]));
    await _steps(tester, 40);
    expect(controller.offset, greaterThan(2000));
    final anchor = tester.getRect(find.byWidgetPredicate((w) => w is UiTourAnchor && w.id == 'far'));
    expect(const Rect.fromLTWH(0, 0, 390, 844).contains(anchor.center), isTrue);
    expect(UiTour.debugHole, anchor.inflate(6));
    expect(find.text('Down here.'), findsOneWidget);
    UiTour.stop();
    await tester.pump();
    await f;
  });

  for (final size in const [Size(390, 844), Size(1440, 900)]) {
    testWidgets('the bubble stays inside a ${size.width.toInt()} wide screen for anchors at every edge', (tester) async {
      final spots = <String, Alignment>{
        'tl': Alignment.topLeft,
        'tr': Alignment.topRight,
        'bl': Alignment.bottomLeft,
        'br': Alignment.bottomRight,
        'mid': Alignment.center,
      };
      await _pumpApp(
        tester,
        Builder(
          key: _ctx,
          builder: (_) => Stack(children: [
            for (final MapEntry(:key, :value) in spots.entries) Align(alignment: value, child: _box(key, key, w: 60, h: 30)),
            // A tall anchor that leaves no room above or below.
            Positioned(left: 100, top: 20, bottom: 20, child: _box('tall', 'tall', w: 40, h: double.infinity)),
          ]),
        ),
        size: size,
      );
      for (final id in [...spots.keys, 'tall']) {
        final f = UiTour.start(_ctx.currentContext!, UiTourSpec('t', [UiTourStep(id, 'A tip about this place, long enough to wrap onto a second line.')]));
        await _steps(tester);
        final b = _bubble(tester);
        final screen = Offset.zero & size;
        expect(screen.deflate(11.9).contains(b.topLeft) && screen.deflate(11.9).contains(b.bottomRight), isTrue, reason: '$id: $b');
        expect(b.width, 320);
        UiTour.stop();
        await tester.pump();
        await f;
      }
    });
  }

  testWidgets('a phone tap (8dp touch slop) on Next works; the page behind takes no taps', (tester) async {
    var pageTaps = 0;
    await _pumpApp(
      tester,
      Builder(
        key: _ctx,
        builder: (_) => Stack(children: [
          Positioned.fill(child: GestureDetector(onTap: () => pageTaps++)),
          Positioned(left: 20, top: 100, child: _box('a', 'A')),
          Positioned(left: 20, top: 400, child: _box('b', 'B')),
        ]),
      ),
    );
    tester.view.gestureSettings = ui.GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
    final f = UiTour.start(_ctx.currentContext!, const UiTourSpec('t', [UiTourStep('a', 'one'), UiTourStep('b', 'two')]));
    await _steps(tester);
    await tester.tapAt(const Offset(200, 700));
    await tester.tapAt(tester.getCenter(find.text('A')));
    await tester.pump();
    expect(pageTaps, 0);
    final g = await tester.startGesture(tester.getCenter(find.text('Next')), kind: PointerDeviceKind.touch);
    await g.moveBy(const Offset(3, 2));
    await g.up();
    await _steps(tester);
    expect(find.text('two'), findsOneWidget);
    UiTour.stop();
    await tester.pump();
    await f;
  });

  testWidgets('semantics: a named route with the count, buttons named, the page hidden', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpApp(tester, _page());
    final f = UiTour.start(_ctx.currentContext!, _spec);
    await _steps(tester);
    expect(find.bySemanticsLabel('1 of 3'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('1 of 3')).flagsCollection.scopesRoute, isTrue);
    expect(find.bySemanticsLabel('Next'), findsOneWidget);
    expect(find.bySemanticsLabel('Skip'), findsOneWidget);
    expect(find.bySemanticsLabel('Turn off tips'), findsOneWidget);
    expect(_labels(tester), isNot(contains('A')));
    UiTour.stop();
    await tester.pump();
    await f;
    expect(_labels(tester), contains('A'));
    handle.dispose();
  });

  testWidgets('announces "Step n of total: text" on each step', (tester) async {
    final said = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (m) async {
      final data = (m as Map)['data'] as Map;
      if (data['message'] != null) said.add(data['message'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, null));
    await _pumpApp(tester, _page());
    final f = UiTour.start(_ctx.currentContext!, _spec);
    await _steps(tester);
    await tester.tap(find.text('Next'));
    await _steps(tester);
    expect(said, ['Step 1 of 3: Your events show up here.', 'Step 2 of 3: Inbox. Invitations land here.']);
    UiTour.stop();
    await tester.pump();
    await f;
  });

  testWidgets('with animations off the hole jumps straight to the next anchor', (tester) async {
    await _pumpApp(tester, _page(), animate: false);
    final f = UiTour.start(_ctx.currentContext!, _spec);
    await _steps(tester, 3);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump();
    expect(UiTour.debugHole, tester.getRect(find.byWidgetPredicate((w) => w is UiTourAnchor && w.id == 'b')).inflate(6));
    UiTour.stop();
    await tester.pump();
    await f;
  });

  testWidgets('Dhivehi strings and labels override', (tester) async {
    await _pumpApp(tester, _page());
    final f = UiTour.start(
      _ctx.currentContext!,
      const UiTourSpec('t', [UiTourStep('a', 'x'), UiTourStep('b', 'y')], labels: UiTourLabels(next: 'Onward', step: 'Step {n}/{total}')),
    );
    await _steps(tester);
    expect(find.text('Onward'), findsOneWidget);
    expect(find.text('Step 1/2'), findsOneWidget);
    UiTour.stop();
    await tester.pump();
    await f;
  });
}

