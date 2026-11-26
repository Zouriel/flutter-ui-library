import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

void main() {
  test('UiCard exposes the three Angular glass strengths', () {
    expect(const UiCard(child: SizedBox()).glassStrength, UiCardGlassStrength.frosted);
    expect(const UiCard(glassStrength: UiCardGlassStrength.clear, child: SizedBox()).glassStrength, UiCardGlassStrength.clear);
    expect(const UiCard(glassStrength: UiCardGlassStrength.liquid, child: SizedBox()).glassStrength, UiCardGlassStrength.liquid);
  });

  testWidgets('clear uses the card AA filter and liquid uses a light un squeezed filter', (tester) async {
    await pumpUi(tester, const UiCard(glass: true, glassStrength: UiCardGlassStrength.clear, child: Text('Clear')));
    final clear = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    final t = tester.element(find.text('Clear')).ui;
    expect(clear.filter, uiGlassCardFilter(t));

    await pumpUi(tester, const UiCard(glass: true, glassStrength: UiCardGlassStrength.liquid, child: Text('Liquid')));
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(tester.widget<BackdropFilter>(find.byType(BackdropFilter)).filter, isNot(uiGlassCardFilter(t)));
    expect(t.glassLiquidTint, lessThanOrEqualTo(0.2));
    expect(t.glassLiquidBlur, lessThanOrEqualTo(3));
  });

  testWidgets('high contrast makes clear solid and liquid fall back to frosted', (tester) async {
    await tester.pumpWidget(UiApp(
      home: MediaQuery(
        data: const MediaQueryData(highContrast: true),
        child: const UiCard(glass: true, glassStrength: UiCardGlassStrength.clear, child: Text('Clear')),
      ),
    ));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration, isA<BoxDecoration>());

    await tester.pumpWidget(UiApp(
      home: MediaQuery(
        data: const MediaQueryData(highContrast: true),
        child: const UiCard(glass: true, glassStrength: UiCardGlassStrength.liquid, child: Text('Liquid')),
      ),
    ));
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(tester.widget<BackdropFilter>(find.byType(BackdropFilter)).filter, isA<ImageFilter>());
  });

  testWidgets('liquid adds a text halo to inherited text without changing the child API', (tester) async {
    await pumpUi(tester, const UiCard(glass: true, glassStrength: UiCardGlassStrength.liquid, child: Text('Legible')));
    final style = DefaultTextStyle.of(tester.element(find.text('Legible'))).style;
    expect(style.shadows, hasLength(3));
  });

  testWidgets('golden: the three card glass strengths', (tester) async {
    await expectThemedGolden(tester, 'card_glass_strengths', height: 300, (context) => Stack(
          children: [
            const Positioned.fill(child: UiLiquidBackdrop()),
            Padding(
              padding: EdgeInsets.all(context.ui.space4),
              child: Row(
                spacing: context.ui.space3,
                children: [
                  for (final strength in UiCardGlassStrength.values)
                    Expanded(
                      child: UiCard(
                        glass: true,
                        glassStrength: strength,
                        children: [
                          UiText(strength.name, variant: UiTextVariant.h5),
                          const UiText('See the flow through the surface.', variant: UiTextVariant.caption),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ));
  });
}
