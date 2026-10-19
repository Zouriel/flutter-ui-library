import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// A panel in the surface colour (not the page colour), as see-through controls usually sit on.
Widget _panel(Widget child) => Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: context.ui.surface, border: Border.all(color: context.ui.border)),
        child: child,
      ),
    );

Future<void> _focusOn(WidgetTester tester, Finder f) async {
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
  Focus.of(tester.element(f)).requestFocus();
  await tester.pumpAndSettle();
}

void main() {
  for (final theme in [UiThemeName.dark, UiThemeName.light]) {
    testWidgets('${theme.name}: a focused ghost button keeps the panel colour inside its ring', (tester) async {
      final key = GlobalKey();
      final t = uiThemeTokens[theme]!;
      await pumpUi(tester, RepaintBoundary(key: key, child: _panel(UiButton(label: 'Ghost', variant: UiButtonVariant.ghost, onPressed: () {}))), theme: theme);
      await _focusOn(tester, find.text('Ghost'));
      final btn = tester.getRect(find.descendant(of: find.byType(UiButton), matching: find.byType(AnimatedContainer)).first);
      final origin = tester.getTopLeft(find.byKey(key));
      final image = await tester.runAsync(() => (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage());
      final bytes = (await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
      Color at(Offset p) {
        final o = p - origin;
        final i = (o.dy.floor() * image!.width + o.dx.floor()) * 4;
        return Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
      }

      // Inside, between the label and the edge: the panel, not the page colour of the ring's gap.
      expect(at(btn.topLeft + const Offset(3, 3)), t.surface);
      // Outside: the 2px gap, then the ring.
      expect(at(Offset(btn.center.dx, btn.top - 1)), t.focusRing.last.color);
      expect(at(Offset(btn.center.dx, btn.top - 3)), t.focusRing.first.color);
      expect(at(Offset(btn.center.dx, btn.top - 6)), t.surface);
    });
  }

  testWidgets('golden: focused ghost button and calendar day on a panel', (tester) async {
    debugDisableShadows = false;
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390 * 2, 480) * 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(
      theme: UiThemeName.dark,
      home: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final th in [UiThemeName.dark, UiThemeName.light])
          SizedBox(
            width: 390,
            height: 480,
            child: UiThemeScope(
              theme: th,
              child: Builder(
                builder: (context) => ColoredBox(
                  color: context.ui.bg,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 16, children: [
                      Row(spacing: 12, children: [
                        UiButton(label: th == UiThemeName.dark ? 'Ghost' : 'Ghost ', variant: UiButtonVariant.ghost, onPressed: () {}),
                        UiButton(label: 'Link', variant: UiButtonVariant.link, onPressed: () {}),
                      ]),
                      UiCalendar(value: th == UiThemeName.dark ? '2026-03-09' : '2026-03-10', onChanged: (_) {}),
                    ])),
                  ),
                ),
              ),
            ),
          ),
      ]),
    ));
    await tester.pumpAndSettle();
    // Dark: the ghost button has focus; light: a calendar day has focus.
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    Focus.of(tester.element(find.text('Ghost'))).requestFocus();
    await tester.pumpAndSettle();
    final ghostRect = tester.getRect(find.text('Ghost'));
    expect(ghostRect.left, lessThan(390));
    try {
      await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/focus_ring_on_panel_ghost.png'));
      Focus.of(tester.element(find.text('17').last)).requestFocus();
      await tester.pumpAndSettle();
      // Off the chosen day onto a plain (see-through) one.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/focus_ring_on_panel_day.png'));
    } finally {
      debugDisableShadows = true;
    }
  });
}
