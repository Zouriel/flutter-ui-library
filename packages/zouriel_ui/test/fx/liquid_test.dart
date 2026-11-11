import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

Future<void> pumpBackdrop(WidgetTester tester, {UiThemeName theme = UiThemeName.rugged, bool reduced = false, bool animations = true, Widget? over}) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduced),
    child: UiApp(
      theme: theme,
      config: UiConfig(animations: animations),
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          height: 300,
          child: Stack(children: [?over, const Positioned.fill(child: UiLiquidBackdrop())]),
        ),
      ),
    ),
  ));
}

UiLiquidPainter painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(const ValueKey('ui-liquid-backdrop'))).painter! as UiLiquidPainter;

void main() {
  testWidgets('fills its box and is hidden from screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBackdrop(tester);
    expect(tester.getSize(find.byKey(const ValueKey('ui-liquid-backdrop'))), const Size(300, 300));
    expect(find.descendant(of: find.byType(UiLiquidBackdrop), matching: find.byType(ExcludeSemantics)), findsWidgets);
    expect(tester.getSemantics(find.byType(UiLiquidBackdrop)).label, isEmpty);
    handle.dispose();
  });

  testWidgets('never takes the pointer: a tap goes to what is behind it', (tester) async {
    var taps = 0;
    await pumpBackdrop(tester, over: Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++)));
    await tester.tapAt(const Offset(150, 150));
    expect(taps, 1);
  });

  testWidgets('paints from the theme: the brand main, and the second and accent pooled at their strengths', (tester) async {
    await pumpBackdrop(tester, theme: UiThemeName.glacierDark);
    final t = uiThemeTokens[UiThemeName.glacierDark]!;
    final p = painter(tester);
    expect(p.main, t.liquidMain);
    expect(p.second, Color.lerp(t.liquidMain, t.liquidSecond, t.liquidSecondStrength!));
    expect(p.accent, Color.lerp(t.liquidMain, t.liquidAccent, t.liquidAccentStrength!));
    expect(p.sheen, t.glassHighlightTop);
  });

  testWidgets('falls back to the background, secondary and primary in a theme without liquid colours', (tester) async {
    await pumpBackdrop(tester, theme: UiThemeName.goldBlack);
    final t = uiThemeTokens[UiThemeName.goldBlack]!;
    expect(t.liquidMain, isNull);
    final p = painter(tester);
    expect(p.main, t.bg);
    expect(p.second, Color.lerp(t.bg, t.secondary, 0.18));
    expect(p.accent, Color.lerp(t.bg, t.primary, 0.14));
  });

  testWidgets('flows at full motion: the pools move and frames keep coming', (tester) async {
    await pumpBackdrop(tester);
    expect(painter(tester).moving, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(painter(tester).time.value, greaterThan(1));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  for (final (label, reduced, animations) in [('under reduced motion', true, true), ('with the library animations off', false, false)]) {
    testWidgets('stands still $label', (tester) async {
      await pumpBackdrop(tester, reduced: reduced, animations: animations);
      expect(painter(tester).moving, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(painter(tester).time.value, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  }

  testWidgets('golden: the backdrop under a glass card in liquid themes and Navy', (tester) async {
    await expectThemedGolden(
      tester,
      'liquid_backdrop',
      (context) => SizedBox(
        height: 260,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(children: [
            const Positioned.fill(child: UiLiquidBackdrop()),
            Center(
              child: SizedBox(
                width: 220,
                child: UiCard(
                  glass: true,
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
                    UiText('Glass over the flow', variant: UiTextVariant.h5),
                    UiButton(onPressed: () {}, child: const Text('Continue')),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
      themes: const [UiThemeName.rugged, UiThemeName.glacierDark, UiThemeName.cocoa, UiThemeName.violetDark, UiThemeName.navy, UiThemeName.dark],
      width: 300,
      height: 300,
    );
  });
}
