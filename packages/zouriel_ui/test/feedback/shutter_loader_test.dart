import 'dart:math' as math;
import 'dart:ui' show Paint;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/feedback/shutter_loader.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

// 0.72.0: the shutter loader (variant B, "blades click"), the app-wide spinner switch.

/// The spec's formula for blade i at distance a, written out again here (not shared with the code).
(Offset, Offset) _blade(int i, double a) {
  const r = 3.05, c = 5.0, a0 = 1.47;
  final th = i * math.pi / 3 + 0.26;
  final nx = math.cos(th), ny = math.sin(th);
  final tx = -ny, ty = nx;
  final sEnd = math.sqrt(r * r - a * a) * 0.97;
  final sStart = -0.85 * (a / a0) - 0.15 * (1 - a / a0);
  final qx = c + a * nx, qy = c + a * ny;
  return (Offset(qx + sStart * tx, qy + sStart * ty), Offset(qx + sEnd * tx, qy + sEnd * ty));
}

/// The distance from the centre (5, 5) to the segment p-q.
double _centreDistance(Offset p, Offset q) {
  const c = Offset(5, 5);
  final d = q - p;
  final t = (((c - p).dx * d.dx + (c - p).dy * d.dy) / d.distanceSquared).clamp(0.0, 1.0);
  return (p + d * t - c).distance;
}

Matcher _closeTo(Offset o) => isA<Offset>().having((x) => (x - o).distance, 'distance', lessThan(1e-9));

void main() {
  group('geometry', () {
    test('open blades (v = 0) match the formula', () {
      final blades = uiShutterBlades(uiShutterBladeDistance(0));
      expect(blades, hasLength(6));
      for (var i = 0; i < 6; i++) {
        final (p, q) = _blade(i, 1.47);
        expect(blades[i].$1, _closeTo(p), reason: 'blade $i start');
        expect(blades[i].$2, _closeTo(q), reason: 'blade $i end');
      }
      // Open: each blade keeps 1.47 from the centre, a clear hexagonal opening.
      for (final (p, q) in blades) {
        expect(_centreDistance(p, q), closeTo(1.47, 1e-9));
      }
    });

    test('shut blades (v = 1) nearly meet the centre and still reach the ring', () {
      final a = uiShutterBladeDistance(1);
      expect(a, closeTo(0.08 * 1.47, 1e-12));
      final blades = uiShutterBlades(a);
      for (var i = 0; i < 6; i++) {
        final (p, q) = _blade(i, a);
        expect(blades[i].$1, _closeTo(p));
        expect(blades[i].$2, _closeTo(q));
        expect(_centreDistance(blades[i].$1, blades[i].$2), lessThan(0.15));
        // The far end stays just inside the ring (r 3.05).
        expect((blades[i].$2 - const Offset(5, 5)).distance, closeTo(3.05 * 0.97, 0.1));
      }
    });
  });

  group('timing', () {
    test('three clicks shut at 0.09 s, 0.44 s and 0.79 s, open at rest, loop every 2.1 s', () {
      expect(uiShutterClosedAt(0), 0);
      expect(uiShutterBladeDistance(uiShutterClosedAt(0.09)), closeTo(0.08 * 1.47, 1e-6));
      expect(uiShutterClosedAt(0.44), closeTo(1, 1e-6));
      expect(uiShutterClosedAt(0.79), closeTo(1, 1e-6));
      // Reopening: half way through the 200 ms open it is mostly open again (ease-out).
      expect(uiShutterClosedAt(0.19), lessThan(0.2));
      expect(uiShutterClosedAt(0.29), closeTo(0, 1e-6));
      expect(uiShutterClosedAt(1.5), 0);
      expect(uiShutterBladeDistance(uiShutterClosedAt(1.5)), 1.47);
      expect(uiShutterClosedAt(2.1 + 0.09), closeTo(1, 1e-6));
      expect(uiShutterCycle, const Duration(milliseconds: 2100));
    });

    test('never more than three flashes a second', () {
      // Count shut moments (v crossing 0.5 upward) through one loop, sampled every 5 ms.
      var shuts = 0;
      var prev = 0.0;
      for (var ms = 0; ms <= 2100; ms += 5) {
        final v = uiShutterClosedAt(ms / 1000);
        if (prev < 0.5 && v >= 0.5) shuts++;
        prev = v;
      }
      expect(shuts, 3);
      expect(shuts / 2.1, lessThan(3));
    });

    test('the reduced-motion pulse goes 1 -> 0.55 -> 1', () {
      expect(uiShutterPulseAt(0), closeTo(1, 1e-9));
      expect(uiShutterPulseAt(1.05), closeTo(0.55, 1e-9));
      expect(uiShutterPulseAt(2.1), closeTo(1, 1e-9));
    });
  });

  group('UiShutterLoader', () {
    testWidgets('draws the ring and the blades at the burst\'s frame', (tester) async {
      // The loop's clock starts on the first frame.
      await tester.pumpWidget(const UiApp(home: Center(child: UiShutterLoader(size: 40))));
      await tester.pump(const Duration(milliseconds: 90));
      final shut = uiShutterBlades(uiShutterBladeDistance(uiShutterClosedAt(0.09)));
      expect(
        find.byType(UiShutterLoader),
        paints
          ..circle(x: 5, y: 5, radius: 3.05, style: PaintingStyle.stroke)
          ..line(p1: shut[0].$1, p2: shut[0].$2),
      );
      await tester.pump(const Duration(milliseconds: 1410)); // 1.5 s: open, at rest
      final open = uiShutterBlades(1.47);
      expect(find.byType(UiShutterLoader), paints..circle()..line(p1: open[0].$1, p2: open[0].$2));
    });

    testWidgets('reduced motion: blades stay open while the mark pulses', (tester) async {
      await tester.pumpWidget(const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: UiApp(home: Center(child: UiShutterLoader(size: 40))),
      ));
      final open = uiShutterBlades(1.47);
      final alphas = <double>[];
      for (final ms in [90, 350, 600]) {
        await tester.pump(Duration(milliseconds: ms));
        // Every blade frame is the open one: no movement at the click moments.
        expect(find.byType(UiShutterLoader), paints..circle()..line(p1: open[0].$1, p2: open[0].$2));
        var alpha = 1.0;
        expect(
          find.byType(UiShutterLoader),
          paints
            ..something((method, args) {
              if (method != #saveLayer) return false;
              alpha = (args[1] as Paint).color.a;
              return true;
            }),
        );
        alphas.add(alpha);
      }
      // 0.09 s, 0.44 s, 1.04 s: fading toward 0.55.
      expect(alphas[0], greaterThan(alphas[1]));
      expect(alphas[1], greaterThan(alphas[2]));
      expect(alphas[2], closeTo(0.55, 0.01));
    });

    testWidgets('takes the surrounding text colour, else its color', (tester) async {
      await tester.pumpWidget(const UiApp(
        home: Center(
          child: DefaultTextStyle(style: TextStyle(color: Color(0xFF00FF00)), child: UiShutterLoader(size: 40)),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byType(UiShutterLoader), paints..circle(color: const Color(0xFF00FF00)));
      await tester.pumpWidget(const UiApp(home: Center(child: UiShutterLoader(size: 40, color: Color(0xFF0000FF)))));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byType(UiShutterLoader), paints..circle(color: const Color(0xFF0000FF)));
    });

    testWidgets('is announced like the spinner; decorative is silent; size scales', (tester) async {
      final handle = tester.ensureSemantics();
      // It never settles (it loops), so pump a frame rather than pumpUi.
      Future<void> pump(Widget w) async {
        await tester.pumpWidget(UiApp(home: Align(alignment: Alignment.topLeft, child: w)));
        await tester.pump(const Duration(milliseconds: 300));
      }

      await pump(const UiShutterLoader(size: 24));
      expect(tester.getSize(find.byType(UiShutterLoader)), const Size(24, 24));
      final data = tester.getSemantics(find.byType(UiShutterLoader)).getSemanticsData();
      expect(data.label, 'Loading…');
      expect(data.flagsCollection.isLiveRegion, isTrue);
      await pump(const UiShutterLoader(label: 'Saving photos'));
      expect(tester.getSemantics(find.byType(UiShutterLoader)).getSemanticsData().label, 'Saving photos');
      await pump(const Row(children: [UiShutterLoader(decorative: true)]));
      expect(find.bySemanticsLabel('Loading…'), findsNothing);
      handle.dispose();
    });
  });

  group('UiConfig.spinner', () {
    testWidgets('shutter: a loading UiButton draws the shutter; the default draws the ring', (tester) async {
      Widget app(UiConfig config) => UiApp(config: config, home: Center(child: UiButton(label: 'Save', loading: true, onPressed: () {})));
      await tester.pumpWidget(app(const UiConfig()));
      expect(find.byType(UiSpinner), findsOneWidget);
      expect(find.byType(UiShutterLoader), findsNothing);
      expect(find.descendant(of: find.byType(UiSpinner), matching: find.byType(RotationTransition)), findsOneWidget);

      await tester.pumpWidget(app(const UiConfig(spinner: UiSpinnerStyle.shutter)));
      await tester.pump(const Duration(milliseconds: 300)); // the theme change animates
      expect(find.byType(UiShutterLoader), findsOneWidget);
      expect(find.descendant(of: find.byType(UiSpinner), matching: find.byType(RotationTransition)), findsNothing);
      // Same size and colour as the ring it replaces: the button's text size and text colour.
      final spinner = tester.widget<UiSpinner>(find.byType(UiSpinner));
      final shutter = tester.widget<UiShutterLoader>(find.byType(UiShutterLoader));
      expect(shutter.size, spinner.size);
      expect(shutter.color, spinner.color);
      expect(shutter.decorative, isTrue);
    });

    test('defaults to the ring and the platform overscroll; copyWith keeps and changes them', () {
      const c = UiConfig();
      expect(c.spinner, UiSpinnerStyle.ring);
      expect(c.overscroll, UiOverscrollStyle.platform);
      final s = c.copyWith(spinner: UiSpinnerStyle.shutter);
      expect(s.spinner, UiSpinnerStyle.shutter);
      expect(s.copyWith(glass: true).spinner, UiSpinnerStyle.shutter);
      expect(c.copyWith(overscroll: UiOverscrollStyle.shutter).overscroll, UiOverscrollStyle.shutter);
    });
  });

  testWidgets('golden: sizes, in a button, in a card', (tester) async {
    await expectThemedGolden(
      tester,
      'shutter_loader',
      // The buttons' spinners draw the shutter, as with `UiConfig(spinner: UiSpinnerStyle.shutter)`.
      (context) => UiTheme(
        data: context.uiTheme.copyWith(config: context.uiTheme.config.copyWith(spinner: UiSpinnerStyle.shutter)),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          const Row(spacing: 16, children: [UiShutterLoader(), UiShutterLoader(size: 24), UiShutterLoader(size: 48), UiShutterLoader(size: 96)]),
          Row(spacing: 12, children: [
            UiButton(label: 'Saving', loading: true, onPressed: () {}),
            UiButton(label: 'Saving', variant: UiButtonVariant.secondary, loading: true, onPressed: () {}),
          ]),
          const UiCard(child: Row(spacing: 12, children: [UiShutterLoader(size: 28), Text('Loading photos…')])),
        ],
      ),
      ),
      height: 330,
    );
  });
}
