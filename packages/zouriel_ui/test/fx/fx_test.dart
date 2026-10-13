import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import '../media/media_helpers.dart';

/// Pumps [child] with the OS reduced-motion setting on.
Future<void> pumpReduced(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MediaQuery(
    data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
    child: UiApp(home: Align(alignment: Alignment.topLeft, child: child)),
  ));
}

double opacityOf(WidgetTester tester, Finder of) => tester.widget<Opacity>(find.ancestor(of: of, matching: find.byType(Opacity)).first).opacity;

void main() {
  group('UiReveal', () {
    testWidgets('hidden until scrolled into view, then fades and rises in', (tester) async {
      final c = ScrollController();
      addTearDown(c.dispose);
      await pumpUi(tester, SizedBox(height: 600, width: 390, child: SingleChildScrollView(controller: c, child: Column(children: [
        const SizedBox(height: 900),
        const UiReveal(child: SizedBox(height: 100, width: 100, child: Text('Hello'))),
        const SizedBox(height: 900),
      ]))));
      expect(opacityOf(tester, find.text('Hello')), 0);
      c.jumpTo(600);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = opacityOf(tester, find.text('Hello'));
      expect(mid, inExclusiveRange(0, 1));
      expect(tester.widget<Transform>(find.ancestor(of: find.text('Hello'), matching: find.byType(Transform)).last).transform.getTranslation().y, greaterThan(0));
      await tester.pumpAndSettle();
      expect(opacityOf(tester, find.text('Hello')), 1);
    });

    testWidgets('reduced motion: a 6px lift only; animations off: shown at once', (tester) async {
      await pumpReduced(tester, const UiReveal(mode: UiRevealMode.left, child: SizedBox(height: 100, width: 100, child: Text('Hi'))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      final tr = tester.widgetList<Transform>(find.ancestor(of: find.text('Hi'), matching: find.byType(Transform))).map((t) => t.transform.getTranslation()).toList();
      expect(tr.any((v) => v.x != 0), isFalse, reason: 'no slide');
      expect(tr.map((v) => v.y).reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(6));
      await tester.pumpAndSettle();

      await tester.pumpWidget(UiApp(config: const UiConfig(animations: false), home: const UiReveal(child: SizedBox(height: 100, child: Text('Now')))));
      await tester.pump();
      expect(opacityOf(tester, find.text('Now')), 1);
    });
  });

  testWidgets('UiSplitText: one label for screen readers, letters stagger in', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(UiApp(home: const Align(alignment: Alignment.topLeft, child: SizedBox(width: 300, child: UiSplitText('Hi you')))));
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.bySemanticsLabel('Hi you'), findsOneWidget);
    // The first letter has started; the last has not.
    expect(opacityOf(tester, find.text('H')), greaterThan(0));
    expect(opacityOf(tester, find.text('u')), 0);
    await tester.pumpAndSettle();
    expect(opacityOf(tester, find.text('u')), 1);
    handle.dispose();
  });

  testWidgets('UiMarquee loops, pauses while pressed, stands still under reduced motion', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(UiApp(home: const Align(alignment: Alignment.topLeft, child: SizedBox(width: 390, child: UiMarquee(items: ['Design', 'Build', 'Ship'], duration: Duration(seconds: 10))))));
    double shift() => tester.widget<FractionalTranslation>(find.descendant(of: find.byType(UiMarquee), matching: find.byType(FractionalTranslation))).translation.dx;
    await tester.pump(const Duration(seconds: 2));
    final a = shift();
    expect(a, lessThan(0));
    // Read once: the loop's copy is hidden.
    expect(find.bySemanticsLabel('Design'), findsOneWidget);
    final g = await tester.startGesture(tester.getCenter(find.byType(UiMarquee)));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(shift(), closeTo(a, 0.02));
    await g.up();
    handle.dispose();

    await pumpReduced(tester, const SizedBox(width: 390, child: UiMarquee(items: ['A', 'B'])));
    await tester.pump(const Duration(seconds: 5));
    expect(shift(), 0);
  });

  group('UiDriftRow', () {
    Widget row({UiDriftDirection dir = UiDriftDirection.right}) => SizedBox(
          width: 300,
          height: 60,
          child: UiDriftRow(direction: dir, speed: 50, children: [for (var i = 0; i < 10; i++) SizedBox(width: 80, child: Text('Card $i'))]),
        );

    testWidgets('drifts, pauses after a touch and resumes after resumeDelay', (tester) async {
      await tester.pumpWidget(UiApp(home: Align(alignment: Alignment.topLeft, child: row())));
      ScrollPosition pos() => tester.state<ScrollableState>(find.byType(Scrollable)).position;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final moved = pos().pixels;
      expect(moved, greaterThan(20));
      // Touch: the drift stops (following the finger) ...
      final g = await tester.startGesture(const Offset(150, 30));
      await g.up();
      final held = pos().pixels;
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(pos().pixels, closeTo(held, 0.5));
      // ... and picks up again once the delay has passed.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1600)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(pos().pixels, greaterThan(held + 5));
    });

    testWidgets('reduced motion: no drift, still scrollable', (tester) async {
      await pumpReduced(tester, row());
      await tester.pump(const Duration(seconds: 2));
      ScrollPosition pos() => tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(pos().pixels, 0);
      await tester.drag(find.byType(UiDriftRow), const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(pos().pixels, greaterThan(50));
    });
  });

  testWidgets('UiIntroLoader holds, leaves and reports done; shorter under reduced motion', (tester) async {
    var done = 0;
    await tester.pumpWidget(UiApp(home: UiIntroLoader(onDone: () => done++, child: const Text('Logo'))));
    expect(find.text('Logo'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(done, 1);
    expect(find.text('Logo'), findsNothing);

    done = 0;
    await pumpReduced(tester, UiIntroLoader(key: const ValueKey('r'), onDone: () => done++, child: const Text('Logo')));
    await tester.pump(const Duration(milliseconds: 470));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(done, 1);
  });

  testWidgets('UiScrollProgress tracks the scroll position', (tester) async {
    final c = ScrollController();
    addTearDown(c.dispose);
    await pumpUi(tester, SizedBox(width: 390, height: 400, child: UiScrollProgress(child: ListView(controller: c, children: [for (var i = 0; i < 20; i++) const SizedBox(height: 100)]))));
    double fill() => tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor!;
    expect(fill(), 0);
    c.jumpTo(800); // max = 2000 - 400
    await tester.pump();
    expect(fill(), closeTo(0.5, 0.001));
  });

  testWidgets('UiMagnetic tilts while pressed and springs back; off under reduced motion', (tester) async {
    var taps = 0;
    await pumpUi(tester, UiMagnetic(child: UiButton(label: 'Pull', onPressed: () => taps++)));
    final g = await tester.startGesture(tester.getTopRight(find.byType(UiButton)) + const Offset(-4, 4));
    await tester.pump(const Duration(milliseconds: 200));
    final m = tester.widget<AnimatedContainer>(find.descendant(of: find.byType(UiMagnetic), matching: find.byType(AnimatedContainer)).first).transform!;
    expect(m.isIdentity(), isFalse);
    await g.up();
    await tester.pumpAndSettle();
    expect(taps, 1, reason: 'the press still reaches the child');
    await pumpReduced(tester, UiMagnetic(child: UiButton(label: 'Still', onPressed: () {})));
    expect(find.descendant(of: find.byType(UiMagnetic), matching: find.byType(AnimatedContainer)).evaluate().where((e) => (e.widget as AnimatedContainer).transform != null), isEmpty);
  });

  testWidgets('UiSectionLabel reads as one label', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const UiSectionLabel(index: '00', label: 'Index'));
    expect(find.bySemanticsLabel('00 Index'), findsOneWidget);
    expect(find.text('INDEX'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('golden: section label, split text, marquee, glyph field, scroll progress, intro', (tester) async {
    await expectThemedGoldenAfter(tester, 'fx', height: 560, themes: const [UiThemeName.darkOrange, UiThemeName.light], (context) {
      final t = context.ui;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: [
        const UiSectionLabel(index: '01', label: 'Work'),
        UiSplitText('Mohamed builds', style: context.uiText.h1),
        const UiMarquee(items: ['Design', 'Build', 'Ship', 'Repeat']),
        SizedBox(height: 120, child: DecoratedBox(
          decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(t.radius)),
          child: const ClipRect(child: UiGlyphField(opacity: 0.9, cell: 14)),
        )),
        SizedBox(height: 60, child: UiScrollProgress(child: ListView(controller: ScrollController(initialScrollOffset: 300), children: [for (var i = 0; i < 12; i++) const SizedBox(height: 60)]))),
        const SizedBox(height: 120, child: UiIntroLoader(child: UiText('zouriel', variant: UiTextVariant.h2))),
      ]);
    }, before: (tester) async {
      await tester.pump(const Duration(milliseconds: 700));
    });
  });
}
