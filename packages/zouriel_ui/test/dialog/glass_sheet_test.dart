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
Color _filtered(UiTokens t, Color c) {
  final m = uiGlassSheetMatrix(t);
  double ch(int row, double v) => ((m[row * 5 + row] * v * 255 + m[row * 5 + 4]) / 255).clamp(0, 1);
  return Color.from(alpha: 1, red: ch(0, c.r), green: ch(1, c.g), blue: ch(2, c.b));
}

Widget _page(UiThemeName theme, Widget glass, {bool highContrast = false}) => UiApp(
      theme: theme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: highContrast),
          child: Stack(children: [
            // Half black, half white: the two worst cases side by side.
            const Positioned.fill(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: ColoredBox(color: _black)), Expanded(child: ColoredBox(color: _white))])),
            glass,
          ]),
        ),
      ),
    );

Widget _sheet({bool glass = true}) => UiBottomSheet(snaps: const [0, 1], snap: 1, title: 'Find a nurse', glass: glass, child: const SizedBox(height: 10));

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

  test('text, muted text, primary and status colours stay AA on glass over pure white and pure black, in every theme', () {
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

  for (final name in [UiThemeName.light, UiThemeName.dark, UiThemeName.maldives, UiThemeName.maldivesDark]) {
    testWidgets('UiBottomSheet glass blurs and squeezes the backdrop and tints it translucent (${name.name})', (tester) async {
      await tester.pumpWidget(_page(name, _sheet()));
      await tester.pumpAndSettle();
      final t = uiThemeTokens[name]!;
      final filter = tester.widget<BackdropFilter>(_inSheet(BackdropFilter));
      expect(filter.filter, uiGlassSheetFilter(t));
      final fills = _fills(tester, _inSheet(DecoratedBox)).toList();
      expect(fills, contains(t.glassSheetBg));
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
      await tester.pumpWidget(RepaintBoundary(key: key, child: _page(name, _sheet())));
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
}
