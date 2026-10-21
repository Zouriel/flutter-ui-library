import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// See-through glass on UiBottomSheet and UiFloatingPanel (0.41.2), the twin of the web
/// `--ui-glass-sheet-*` tokens and style-contract checks.

const _black = Color(0xff000000);
const _white = Color(0xffffffff);

/// [c] composited over the opaque [ground].
Color _over(Color c, Color ground) => Color.from(
      alpha: 1,
      red: c.r * c.a + ground.r * (1 - c.a),
      green: c.g * c.a + ground.g * (1 - c.a),
      blue: c.b * c.a + ground.b * (1 - c.a),
    );

/// A backdrop colour after the glass filter's colour matrix (the blur leaves a flat colour alone).
Color _filtered(UiTokens t, Color c, {UiGlassStrength strength = UiGlassStrength.frosted}) {
  final m = uiGlassSheetMatrix(t, strength: strength);
  double ch(int row) => ((m[row * 5] * c.r + m[row * 5 + 1] * c.g + m[row * 5 + 2] * c.b) + m[row * 5 + 4] / 255).clamp(0, 1);
  return Color.from(alpha: 1, red: ch(0), green: ch(1), blue: ch(2));
}

/// The colours MapTiler's dataviz and dataviz-dark styles draw Male in (sampled from real tiles at
/// zoom 15-16, every colour covering more than 0.2% of a 390x844 view: water, buildings, land, parks,
/// roads): the realistic worst cases clear glass is made for. The same lists as the web
/// style-contract spec.
const _lightMap = [Color(0xffd1e6e9), Color(0xffd2e7ea), Color(0xffdedede), Color(0xffe1e1e1), Color(0xffe6e6e6), Color(0xffedf5e1), Color(0xfffaf9f9), Color(0xffffffff)];
const _darkMap = [Color(0xff000000), Color(0xff141414), Color(0xff222222), Color(0xff292929), Color(0xff323232)];
bool _dark(UiTokens t) => uiContrast(_black, t.surface) < uiContrast(_white, t.surface);

Widget _page(UiThemeName theme, Widget glass, {bool highContrast = false, Color left = _black, Color right = _white}) => UiApp(
      theme: theme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: highContrast),
          child: Stack(children: [
            // Half black, half white: the two worst cases side by side.
            Positioned.fill(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: ColoredBox(color: left)), Expanded(child: ColoredBox(color: right))])),
            glass,
          ]),
        ),
      ),
    );

Widget _sheet({bool glass = true, UiGlassStrength strength = UiGlassStrength.frosted}) =>
    UiBottomSheet(snaps: const [0, 1], snap: 1, title: 'Find a nurse', glass: glass, glassStrength: strength, child: const SizedBox(height: 10));

Finder _inSheet(Type t) => find.descendant(of: find.byType(UiBottomSheet), matching: find.byType(t));
Finder _inPanel(Type t) => find.descendant(of: find.byType(UiFloatingPanel), matching: find.byType(t));

Iterable<Color?> _fills(WidgetTester tester, Finder f) =>
    tester.widgetList<DecoratedBox>(f).map((d) => d.decoration).whereType<BoxDecoration>().map((d) => d.color);

void main() {
  test('the colour matrix lands black on the floor and white on the ceiling, in every theme', () {
    for (final name in UiThemeName.values) {
      final t = uiThemeTokens[name]!;
      expect(t.glassSheetCeiling, greaterThan(t.glassSheetFloor), reason: '$name shows nothing through');
      expect(t.glassSheetTint, inExclusiveRange(0, 1), reason: '$name tint');
      expect(t.glassSheetBg.a, closeTo(t.glassSheetTint, 0.01), reason: '$name tint colour');
      expect(t.glassSheetBlur, greaterThanOrEqualTo(8));
      expect(_filtered(t, _black).r, closeTo(t.glassSheetFloor, 1e-9));
      expect(_filtered(t, _white).g, closeTo(t.glassSheetCeiling, 1e-9));
    }
  });

  test('clear (0.41.3): the matrix squeezes into the clear range, keeps a grey grey and saturates colour', () {
    for (final name in UiThemeName.values) {
      final t = uiThemeTokens[name]!;
      final c = UiGlassStrength.clear;
      expect(_filtered(t, _black, strength: c).r, closeTo(t.glassClearFloor, 1e-6), reason: '$name');
      expect(_filtered(t, _white, strength: c).b, closeTo(t.glassClearCeiling, 1e-6), reason: '$name');
      final grey = _filtered(t, const Color(0xff808080), strength: c);
      expect(grey.r, closeTo(grey.b, 1e-6), reason: '$name: a grey stays grey');
      expect(t.glassClearSaturate, inInclusiveRange(1, 2));
    }
    // CSS saturate(1.8) on the water colour, by hand: blue minus red grows.
    final t = uiThemeTokens[UiThemeName.maldivesDark]!;
    final w = _filtered(t, const Color(0xffd1e6e9), strength: UiGlassStrength.clear);
    expect(w.b - w.r, greaterThan(t.glassClearCeiling * (0xe9 - 0xd1) / 255));
  });

  test('clear (0.41.3): far more of the map shows through than frosted, with a light tint and blur', () {
    final fails = <String>[];
    for (final name in UiThemeName.values) {
      final t = uiThemeTokens[name]!;
      final through = (1 - t.glassClearTint) * (t.glassClearCeiling - t.glassClearFloor);
      final frosted = (1 - t.glassSheetTint) * (t.glassSheetCeiling - t.glassSheetFloor);
      if (through < 0.4) fails.add('$name: only ${(through * 100).round()}% of the map contrast comes through');
      if (through < 1.5 * frosted) fails.add('$name: clear $through is not clearer than frosted $frosted');
      if (t.glassClearTint <= 0 || t.glassClearTint > 0.2) fails.add('$name: tint ${t.glassClearTint}');
      if (t.glassClearBlur < 2 || t.glassClearBlur > 4) fails.add('$name: blur ${t.glassClearBlur}');
      if ((t.glassClearBg.a - t.glassClearTint).abs() > 0.01) fails.add('$name: tint colour');
    }
    expect(fails, isEmpty);
  });

  test("clear (0.41.3): text, muted text, primary and status colours AA and icons 3:1 over a map in the theme's brightness", () {
    final fails = <String>[];
    for (final name in UiThemeName.values) {
      final t = uiThemeTokens[name]!;
      for (final ground in _dark(t) ? _darkMap : _lightMap) {
        final panel = _over(t.glassClearBg, _filtered(t, ground, strength: UiGlassStrength.clear));
        for (final (fg, c, need) in [
          ('text', t.text, 4.5), ('textMuted', t.textMuted, 4.5), ('primary', t.primary, 4.5), ('success', t.success, 4.5),
          ('danger', t.danger, 4.5), ('warning', t.warning, 3.0), if (t.icon != null) ('icon', t.icon!, 3.0),
        ]) {
          final r = uiContrast(_over(c, panel), panel);
          if (r < need) fails.add('$name: $fg over $ground is ${r.toStringAsFixed(2)}:1, needs $need:1');
        }
      }
    }
    expect(fails, isEmpty);
  });

  test('frosted: text, muted text, primary and status colours stay AA on glass over pure white and pure black, in every theme', () {
    final fails = <String>[];
    for (final name in UiThemeName.values) {
      final t = uiThemeTokens[name]!;
      for (final (where, ground) in [('black', _black), ('white', _white)]) {
        final panel = _over(t.glassSheetBg, _filtered(t, ground));
        for (final (fg, c, need) in [
          ('text', t.text, 4.5), ('textMuted', t.textMuted, 4.5), ('primary', t.primary, 4.5), ('success', t.success, 4.5),
          ('danger', t.danger, 4.5), ('warning', t.warning, 3.0), if (t.icon != null) ('icon', t.icon!, 3.0),
        ]) {
          final r = uiContrast(_over(c, panel), panel);
          if (r < need) fails.add('$name: $fg on glass over $where is ${r.toStringAsFixed(2)}:1, needs $need:1');
        }
      }
    }
    expect(fails, isEmpty);
  });

  testWidgets('UiBottomSheet is solid by default, even with UiConfig.glass on', (tester) async {
    await tester.pumpWidget(UiApp(config: const UiConfig(glass: true), home: Stack(children: [_sheet(glass: false)])));
    await tester.pumpAndSettle();
    expect(_inSheet(BackdropFilter), findsNothing);
    expect(_fills(tester, _inSheet(DecoratedBox)), contains(uiThemeTokens[UiThemeName.dark]!.surface));
  });

  testWidgets('glassStrength defaults to clear on both widgets', (tester) async {
    expect(UiBottomSheet(glass: true, child: const SizedBox()).glassStrength, UiGlassStrength.clear);
    expect(const UiFloatingPanel(child: SizedBox()).glassStrength, UiGlassStrength.clear);
  });

  for (final (strength, name) in [
    for (final s in UiGlassStrength.values)
      for (final n in [UiThemeName.light, UiThemeName.dark, UiThemeName.maldives, UiThemeName.maldivesDark]) (s, n),
  ]) {
    testWidgets('UiBottomSheet ${strength.name} glass blurs and squeezes the backdrop and tints it translucent (${name.name})', (tester) async {
      await tester.pumpWidget(_page(name, _sheet(strength: strength)));
      await tester.pumpAndSettle();
      final t = uiThemeTokens[name]!;
      final filter = tester.widget<BackdropFilter>(_inSheet(BackdropFilter));
      expect(filter.filter, uiGlassSheetFilter(t, strength: strength));
      expect(filter.filter, isNot(uiGlassSheetFilter(t, strength: strength == UiGlassStrength.clear ? UiGlassStrength.frosted : UiGlassStrength.clear)));
      final fills = _fills(tester, _inSheet(DecoratedBox)).toList();
      expect(fills, contains(uiGlassSheetTint(t, strength: strength)));
      expect(fills, isNot(contains(t.surface)));
      expect(t.glassSheetBg.a, lessThan(1));
      // The title row and handle are inside the glass.
      expect(find.descendant(of: _inSheet(BackdropFilter), matching: find.text('Find a nurse')), findsOneWidget);
    });
  }

  testWidgets('UiBottomSheet glass is solid under the high-contrast setting', (tester) async {
    await tester.pumpWidget(_page(UiThemeName.light, _sheet(), highContrast: true));
    await tester.pumpAndSettle();
    expect(_inSheet(BackdropFilter), findsNothing);
    expect(_fills(tester, _inSheet(DecoratedBox)), contains(uiThemeTokens[UiThemeName.light]!.surface));
  });

  testWidgets('UiFloatingPanel glass uses the same see-through surface; high contrast and glass: false are solid', (tester) async {
    final t = uiThemeTokens[UiThemeName.maldives]!;
    await tester.pumpWidget(_page(UiThemeName.maldives, const UiFloatingPanel(glass: true, child: Text('Status'))));
    await tester.pumpAndSettle();
    expect(tester.widget<BackdropFilter>(_inPanel(BackdropFilter)).filter, uiGlassSheetFilter(t, strength: UiGlassStrength.clear));
    expect(_fills(tester, _inPanel(DecoratedBox)), contains(t.glassClearBg));

    await tester.pumpWidget(_page(UiThemeName.maldives, const UiFloatingPanel(glass: true, glassStrength: UiGlassStrength.frosted, child: Text('Status'))));
    await tester.pumpAndSettle();
    expect(tester.widget<BackdropFilter>(_inPanel(BackdropFilter)).filter, uiGlassSheetFilter(t));
    expect(_fills(tester, _inPanel(DecoratedBox)), contains(t.glassSheetBg));

    await tester.pumpWidget(_page(UiThemeName.maldives, const UiFloatingPanel(glass: true, child: Text('Status')), highContrast: true));
    await tester.pumpAndSettle();
    expect(_inPanel(BackdropFilter), findsNothing);
    expect(_fills(tester, _inPanel(DecoratedBox)), contains(t.surfaceRaised));

    await tester.pumpWidget(_page(UiThemeName.maldives, const UiFloatingPanel(child: Text('Status'))));
    await tester.pumpAndSettle();
    expect(_inPanel(BackdropFilter), findsNothing);
  });

  // The rendered pixels, not just the widget tree: a glass sheet over black and white halves, read back.
  for (final name in UiThemeName.values) {
    testWidgets('rendered glass over black and white keeps text AA (${name.name})', (tester) async {
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: _page(name, _sheet(strength: UiGlassStrength.frosted))));
      await tester.pumpAndSettle();
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!;
      }))!;
      Color at(int x, int y) {
        final i = (y * 400 + x) * 4;
        return Color.fromARGB(255, bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
      }
      final t = uiThemeTokens[name]!;
      // Deep in the empty body, far from the black/white edge (x = 200) so the blur doesn't mix them.
      for (final (where, x, ground) in [('black', 40, _black), ('white', 360, _white)]) {
        final px = at(x, 300);
        final want = _over(t.glassSheetBg, _filtered(t, ground));
        expect((px.r - want.r).abs(), lessThan(3 / 255), reason: '$where red ${px.r} vs ${want.r}');
        expect((px.g - want.g).abs(), lessThan(3 / 255), reason: '$where green');
        expect((px.b - want.b).abs(), lessThan(3 / 255), reason: '$where blue');
        for (final c in [t.text, t.textMuted, t.primary]) {
          expect(uiContrast(_over(c, px), px), greaterThanOrEqualTo(4.5), reason: '$name over $where');
        }
      }
    });
  }

  // Clear glass's rendered pixels over the two ends of a map in the theme's brightness.
  for (final name in UiThemeName.values) {
    testWidgets('rendered clear glass over map colours matches the model and keeps text AA (${name.name})', (tester) async {
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final t = uiThemeTokens[name]!;
      final (a, b) = _dark(t) ? (const Color(0xff000000), const Color(0xff323232)) : (const Color(0xffdedede), const Color(0xffd1e6e9));
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: _page(name, _sheet(strength: UiGlassStrength.clear), left: a, right: b)));
      await tester.pumpAndSettle();
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!;
      }))!;
      Color at(int x, int y) {
        final i = (y * 400 + x) * 4;
        return Color.fromARGB(255, bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
      }
      for (final (x, ground) in [(40, a), (360, b)]) {
        final px = at(x, 300);
        final want = _over(t.glassClearBg, _filtered(t, ground, strength: UiGlassStrength.clear));
        expect((px.r - want.r).abs(), lessThan(3 / 255), reason: '$ground red ${px.r} vs ${want.r}');
        expect((px.g - want.g).abs(), lessThan(3 / 255), reason: '$ground green');
        expect((px.b - want.b).abs(), lessThan(3 / 255), reason: '$ground blue');
        for (final c in [t.text, t.textMuted, t.primary]) {
          expect(uiContrast(_over(c, px), px), greaterThanOrEqualTo(4.5), reason: '$name over $ground');
        }
      }
    });
  }
}
