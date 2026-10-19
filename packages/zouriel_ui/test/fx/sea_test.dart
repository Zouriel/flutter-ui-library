import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// Pumps [child] in a 300 × 300 box at the top left, in [theme], with motion as asked.
Future<void> pumpBox(WidgetTester tester, Widget child,
    {UiThemeName theme = UiThemeName.maldives, bool reduced = false, bool animations = true, bool loose = false}) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduced),
    child: UiApp(
      theme: theme,
      config: UiConfig(animations: animations),
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 300, height: 300, child: loose ? Align(alignment: Alignment.topLeft, child: child) : child),
      ),
    ),
  ));
}

/// Whether anything is still animating once a fresh tree has settled its own entrance (the theme
/// cross-fade, a one-shot reveal): only continuous motion keeps scheduling frames.
Future<bool> stillTicking(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  return tester.binding.hasScheduledFrame;
}

/// The innermost [CustomPaint] under [of]: the painted shape itself.
Rect paintRect(WidgetTester tester, Finder of) => tester.getRect(find.descendant(of: of, matching: find.byType(CustomPaint)).last);

/// A 1 × 1 transparent PNG.
final MemoryImage pixel = MemoryImage(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='));

double opacityAbove(WidgetTester tester, Finder of) =>
    tester.widgetList<Opacity>(find.ancestor(of: of, matching: find.byType(Opacity))).fold(1.0, (a, o) => a * o.opacity);

double liftAbove(WidgetTester tester, Finder of) => tester
    .widgetList<Transform>(find.ancestor(of: of, matching: find.byType(Transform)))
    .fold(0.0, (a, t) => a + t.transform.getTranslation().y);

void main() {
  group('UiWaveFooter', () {
    testWidgets('pinned to the bottom of its space at its height, hidden from screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBox(tester, const Stack(children: [Positioned.fill(child: UiWaveFooter(height: 90, opacity: 0.4))]));
      final r = paintRect(tester, find.byType(UiWaveFooter));
      expect(r, const Rect.fromLTWH(0, 210, 300, 90));
      expect(tester.widget<Opacity>(find.descendant(of: find.byType(UiWaveFooter), matching: find.byType(Opacity))).opacity, 0.4);
      expect(find.descendant(of: find.byType(UiWaveFooter), matching: find.byType(IgnorePointer)), findsWidgets);
      expect(tester.getSemantics(find.byType(UiWaveFooter)).getSemanticsData().label, isEmpty);
      handle.dispose();
    });

    testWidgets('drifts at full motion only', (tester) async {
      await pumpBox(tester, const UiWaveFooter(layers: 2));
      expect(await stillTicking(tester), isTrue, reason: 'the tide keeps ticking');
      await pumpBox(tester, const UiWaveFooter(), reduced: true);
      expect(await stillTicking(tester), isFalse, reason: 'reduced motion stops the drift');
      await pumpBox(tester, const UiWaveFooter(), animations: false);
      expect(await stillTicking(tester), isFalse, reason: 'animations off stops the drift');
    });

    test('takes 2 or 3 layers', () {
      expect(() => UiWaveFooter(layers: 4), throwsAssertionError);
    });
  });

  group('UiOceanHero', () {
    testWidgets('content over the sky; photo and sweep optional and decorative', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBox(tester, const UiOceanHero(fill: true, child: Center(child: Text('Find a doctor'))));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Find a doctor'), findsOneWidget);
      expect(tester.getSize(find.byType(UiOceanHero)), const Size(300, 300), reason: 'fill takes the whole space');
      expect(find.byType(Image), findsNothing);
      expect(find.bySemanticsLabel('Find a doctor'), findsOneWidget);
      await pumpBox(tester, UiOceanHero(fill: true, src: pixel, shimmer: false, child: const Text('x')));
      expect(find.byType(Image), findsOneWidget);
      expect(await stillTicking(tester), isFalse, reason: 'no sweep, nothing ticks');
      handle.dispose();
    });

    testWidgets('the sweep runs at full motion and stops under reduced motion', (tester) async {
      await pumpBox(tester, const UiOceanHero(fill: true));
      expect(await stillTicking(tester), isTrue);
      await pumpBox(tester, const UiOceanHero(fill: true), reduced: true);
      expect(await stillTicking(tester), isFalse);
    });
  });

  group('corner decor', () {
    testWidgets('sits in its corner at its scale', (tester) async {
      await pumpBox(tester, const Stack(children: [
        Positioned.fill(child: UiCoralDecor(scale: 0.5)),
        Positioned.fill(child: UiPalmDecor(corner: UiDecorCorner.tr)),
      ]));
      expect(paintRect(tester, find.byType(UiCoralDecor)), const Rect.fromLTWH(0, 236, 80, 64));
      expect(paintRect(tester, find.byType(UiPalmDecor)), const Rect.fromLTWH(140, 0, 160, 176));
    });

    testWidgets('floats up to 4px at full motion; still otherwise', (tester) async {
      await pumpBox(tester, const UiCoralDecor());
      await tester.pump(const Duration(milliseconds: 2500));
      final lift = liftAbove(tester, find.byType(CustomPaint).last);
      expect(lift, inInclusiveRange(-4, -0.5));
      await pumpBox(tester, const UiCoralDecor(), reduced: true);
      await tester.pump(const Duration(milliseconds: 2500));
      expect(liftAbove(tester, find.byType(CustomPaint).last), 0);
    });
  });

  group('UiSunrise', () {
    testWidgets('fades in and rises, then shows the logo at full strength', (tester) async {
      await pumpBox(tester, const UiSunrise(size: 80, child: Text('FD')), loose: true);
      expect(tester.getSize(find.byType(UiSunrise)), const Size(128, 128));
      await tester.pump(const Duration(milliseconds: 200));
      expect(opacityAbove(tester, find.text('FD')), inExclusiveRange(0, 1));
      expect(liftAbove(tester, find.text('FD')), greaterThan(0));
      await tester.pump(const Duration(milliseconds: 600));
      expect(opacityAbove(tester, find.text('FD')), 1);
      expect(liftAbove(tester, find.text('FD')), 0);
    });

    testWidgets('reduced motion: a fade with no rise; animations off: shown at once', (tester) async {
      await pumpBox(tester, const UiSunrise(child: Text('FD')), reduced: true);
      await tester.pump(const Duration(milliseconds: 200));
      expect(opacityAbove(tester, find.text('FD')), inExclusiveRange(0, 1));
      expect(liftAbove(tester, find.text('FD')), 0);
      await tester.pumpAndSettle();
      await pumpBox(tester, const UiSunrise(child: Text('Now')), animations: false);
      await tester.pump();
      expect(opacityAbove(tester, find.text('Now')), 1);
      expect(await stillTicking(tester), isFalse, reason: 'no idle pulse either');
    });

    testWidgets('the logo is drawn in the accent contrast colour', (tester) async {
      await pumpBox(tester, const UiSunrise(child: Text('FD')), animations: false);
      final style = DefaultTextStyle.of(tester.element(find.text('FD'))).style;
      expect(style.color, uiThemeTokens[UiThemeName.maldives]!.accentContrast);
    });
  });

  group('UiSeaSurface', () {
    testWidgets('scopes maldives and paints its background, with the decor asked for', (tester) async {
      await pumpBox(tester, const UiSeaSurface(coral: UiDecorCorner.bl, child: SizedBox(height: 200, child: Text('Hello'))), theme: UiThemeName.dark, loose: true);
      final m = uiThemeTokens[UiThemeName.maldives]!;
      expect(tester.widgetList<ColoredBox>(find.descendant(of: find.byType(UiSeaSurface), matching: find.byType(ColoredBox))).first.color, m.bg);
      expect(DefaultTextStyle.of(tester.element(find.text('Hello'))).style.fontFamily, contains('Poppins'));
      expect(find.byType(UiWaveFooter), findsOneWidget);
      expect(find.byType(UiCoralDecor), findsOneWidget);
      expect(find.byType(UiPalmDecor), findsNothing);
      expect(tester.getSize(find.byType(UiSeaSurface)).height, 200, reason: 'sized by its content; the backdrop fills it');
    });

    testWidgets('theme null keeps the surrounding theme', (tester) async {
      await pumpBox(tester, const UiSeaSurface(theme: null, waves: false, child: SizedBox(height: 50)), theme: UiThemeName.light);
      expect(tester.widgetList<ColoredBox>(find.descendant(of: find.byType(UiSeaSurface), matching: find.byType(ColoredBox))).first.color,
          uiThemeTokens[UiThemeName.light]!.bg);
      expect(find.byType(UiWaveFooter), findsNothing);
    });

    testWidgets('text on it meets contrast guidelines', (tester) async {
      await pumpBox(tester, UiSeaSurface(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const UiText('Book a visit', variant: UiTextVariant.h3),
            const UiText('Waves along the bottom', variant: UiTextVariant.caption),
            UiButton(label: 'Get guidance', variant: UiButtonVariant.accent, onPressed: () {}),
          ]),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });
  });

  group('UiTide', () {
    Widget list() => Column(children: [for (var i = 0; i < 3; i++) UiTide(index: i, delay: const Duration(milliseconds: 100), step: const Duration(milliseconds: 50), child: Text('item $i'))]);

    testWidgets('staggers each item by its index, fading and sliding up 8px', (tester) async {
      await pumpBox(tester, list());
      await tester.pump(const Duration(milliseconds: 160));
      expect(opacityAbove(tester, find.text('item 0')), greaterThan(0));
      expect(opacityAbove(tester, find.text('item 2')), 0, reason: 'starts at 200ms');
      expect(liftAbove(tester, find.text('item 2')), 8);
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        expect(opacityAbove(tester, find.text('item $i')), 1);
        expect(liftAbove(tester, find.text('item $i')), 0);
      }
    });

    testWidgets('reduced motion fades without the slide; animations off shows at once', (tester) async {
      await pumpBox(tester, list(), reduced: true);
      await tester.pump(const Duration(milliseconds: 160));
      expect(liftAbove(tester, find.text('item 0')), 0);
      await tester.pumpAndSettle();
      await pumpBox(tester, list(), animations: false);
      await tester.pump();
      expect(opacityAbove(tester, find.text('item 2')), 1);
    });
  });

  group('text effects', () {
    testWidgets('UiGradientText reads as its text; the tide runs only in maldives', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBox(tester, const UiGradientText('Find Doctor'));
      expect(find.bySemanticsLabel('Find Doctor'), findsOneWidget);
      expect(await stillTicking(tester), isTrue);
      await pumpBox(tester, const UiGradientText('Find Doctor'), theme: UiThemeName.lightTeal);
      expect(await stillTicking(tester), isFalse, reason: 'other themes draw it still');
      handle.dispose();
    });

    testWidgets('UiGlow adds the theme glow and shimmers it in maldives', (tester) async {
      await pumpBox(tester, const UiGlow(child: Text('Glow')));
      final at = DefaultTextStyle.of(tester.element(find.text('Glow'))).style.shadows!;
      expect(at, hasLength(uiThemeTokens[UiThemeName.maldives]!.glowAmber.length));
      await tester.pump(const Duration(milliseconds: 4000));
      final mid = DefaultTextStyle.of(tester.element(find.text('Glow'))).style.shadows!;
      expect(mid.first.color.a, greaterThan(at.first.color.a), reason: 'brightest half-way through the loop');
    });

    testWidgets('UiPulse pulses at full motion only', (tester) async {
      await pumpBox(tester, const UiPulse(child: Text('AI')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(opacityAbove(tester, find.text('AI')), inExclusiveRange(0.75, 1));
      await pumpBox(tester, const UiPulse(child: Text('AI')), reduced: true);
      await tester.pump(const Duration(milliseconds: 600));
      expect(opacityAbove(tester, find.text('AI')), 1);
    });
  });

  group('sea shapes', () {
    test('every shape has parts that stay inside its viewBox', () {
      expect(uiSeaShapes.keys, unorderedEquals(['wave1', 'wave2', 'wave3', 'coral', 'palm']));
      for (final MapEntry(:key, :value) in uiSeaShapes.entries) {
        for (final p in value.parts) {
          final b = p.toPath().getBounds();
          expect(b.left >= 0 && b.top >= 0 && b.right <= value.size.width && b.bottom <= value.size.height, isTrue, reason: '$key ${p.tone}: $b');
        }
      }
    });

    test('waves repeat every half width, so a half-width drift has no seam', () {
      for (final name in ['wave1', 'wave2', 'wave3']) {
        final ops = uiSeaShapes[name]!.parts.single.ops;
        double? yAt(double x) {
          for (var i = 0; i < ops.length; i++) {
            if (ops[i] == x && i + 1 < ops.length && ops[i + 1] != x) return ops[i + 1];
          }
          return null;
        }

        expect(yAt(1440), ops[2], reason: name);
        expect(yAt(2880), ops[2], reason: name);
      }
    });

    test('each tone falls back to a theme role outside maldives', () {
      final dark = uiThemeTokens[UiThemeName.dark]!, m = uiThemeTokens[UiThemeName.maldives]!;
      expect(uiSeaTone(dark, UiSeaTone.lagoon), dark.secondary);
      expect(uiSeaTone(dark, UiSeaTone.coral), dark.accent);
      expect(uiSeaTone(m, UiSeaTone.lagoon), m.lagoon);
      expect(uiSeaTone(m, UiSeaTone.oceanDeep), m.oceanDeep);
    });
  });

  group('theme icon colour', () {
    testWidgets('loose icons and ghost buttons take Lagoon in maldives; filled and active ones keep their colour', (tester) async {
      final m = uiThemeTokens[UiThemeName.maldives]!;
      await pumpBox(tester, Column(children: [
        const UiIcon(HugeIcons.strokeRoundedHome01, key: Key('loose')),
        UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedSearch01, key: Key('ghost')), label: 'Search', onPressed: () {}),
        UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedSent, key: Key('filled')), label: 'Send', variant: UiButtonVariant.primary, onPressed: () {}),
        const UiBottomNav(items: [
          UiBottomNavItem(label: 'Home', value: 'home', icon: HugeIcons.strokeRoundedHome01),
          UiBottomNavItem(label: 'Search', value: 'search', icon: HugeIcons.strokeRoundedSearch01),
        ], active: 'home', safeArea: false),
      ]), animations: false);
      Color? color(Finder f) => IconTheme.of(tester.element(f)).color;
      expect(color(find.byKey(const Key('loose'))), m.icon);
      expect(color(find.byKey(const Key('ghost'))), m.icon);
      expect(color(find.byKey(const Key('filled'))), m.primaryContrast);
      final nav = tester.widgetList<UiIcon>(find.descendant(of: find.byType(UiBottomNav), matching: find.byType(UiIcon))).map((i) => i.color).toList();
      expect(nav, [m.primary, m.icon], reason: 'the current page in Ocean Deep, the others Lagoon');
    });

    testWidgets('other themes keep icons in the text colour', (tester) async {
      await pumpBox(tester, const UiIcon(HugeIcons.strokeRoundedHome01, key: Key('loose')), theme: UiThemeName.lightTeal, animations: false);
      expect(IconTheme.of(tester.element(find.byKey(const Key('loose')))).color, uiThemeTokens[UiThemeName.lightTeal]!.text);
    });
  });

  group('section label', () {
    testWidgets('auto is the bracket marker on Dark Orange and the eyebrow elsewhere', (tester) async {
      await pumpBox(tester, const UiSectionLabel(index: '01', label: 'Work'), theme: UiThemeName.darkOrange, animations: false);
      expect(find.text('['), findsOneWidget);
      await pumpBox(tester, const UiSectionLabel(index: '01', label: 'Work'), animations: false);
      await tester.pumpAndSettle(); // the theme cross-fade switches its name half-way
      expect(find.text('['), findsNothing);
      expect(find.text('WORK'), findsOneWidget);
      await pumpBox(tester, const UiSectionLabel(index: '01', label: 'Work', variant: UiSectionLabelVariant.bracket), animations: false);
      expect(find.text('['), findsOneWidget);
    });
  });

  group('goldens', () {
    const themes = [UiThemeName.dark, UiThemeName.light, UiThemeName.maldives];
    Widget box(BuildContext context, Widget child, {double height = 140}) => ClipRRect(
          borderRadius: BorderRadius.circular(context.ui.radiusLg),
          child: SizedBox(height: height, child: child),
        );

    testWidgets('wave footer', (tester) async {
      await expectThemedGolden(tester, 'sea_wave_footer', themes: themes, height: 330, (context) => Column(spacing: 12, children: [
            box(context, const Stack(children: [Positioned.fill(child: UiWaveFooter(height: 110, opacity: 0.6))])),
            box(context, const Stack(children: [Positioned.fill(child: UiWaveFooter(layers: 2, height: 80))])),
          ]));
    });

    testWidgets('ocean hero', (tester) async {
      await expectThemedGolden(tester, 'sea_ocean_hero', themes: themes, height: 240, (context) => box(
            context,
            height: 200,
            UiOceanHero(
              fill: true,
              shimmer: false,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Align(alignment: Alignment.bottomLeft, child: Text('Find Doctor', style: context.uiText.h2.copyWith(color: context.ui.mist ?? context.ui.text))),
              ),
            ),
          ));
    });

    testWidgets('coral and palm decor', (tester) async {
      await expectThemedGolden(tester, 'sea_decor', themes: themes, height: 330, (context) => Column(spacing: 12, children: [
            box(context, const Stack(children: [
              Positioned.fill(child: UiCoralDecor(scale: 0.8)),
              Positioned.fill(child: UiPalmDecor(corner: UiDecorCorner.br, scale: 0.75)),
            ])),
            box(context, const Stack(children: [
              Positioned.fill(child: UiCoralDecor(corner: UiDecorCorner.tr, scale: 0.8)),
              Positioned.fill(child: UiPalmDecor(corner: UiDecorCorner.tl, scale: 0.75)),
            ])),
          ]));
    });

    testWidgets('sunrise and text effects', (tester) async {
      await expectThemedGolden(tester, 'sea_sunrise', themes: themes, height: 300, (context) => Column(spacing: 8, children: [
            const UiSunrise(size: 96, child: UiIcon(HugeIcons.strokeRoundedStethoscope02)),
            UiGradientText('Find Doctor', style: context.uiText.h2),
            UiGlow(child: Text('Care across the atolls', style: context.uiText.label)),
            const UiPulse(child: UiIcon(HugeIcons.strokeRoundedAiBrain01)),
          ]));
    });

    testWidgets('sea surface and tide', (tester) async {
      await expectThemedGolden(tester, 'sea_surface', themes: themes, height: 420, (context) => ClipRRect(
            borderRadius: BorderRadius.circular(context.ui.radiusLg),
            child: UiSeaSurface(
              theme: null,
              coral: UiDecorCorner.bl,
              palm: UiDecorCorner.br,
              decorScale: 0.6,
              waveHeight: 90,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
                  const UiText('Book a visit', variant: UiTextVariant.h3),
                  for (var i = 0; i < 3; i++)
                    UiTide(index: i, child: UiCard(padding: UiSize.sm, child: Text('Dr. ${['Aisha Rasheed', 'Ibrahim Naseem', 'Mariyam Shifa'][i]}'))),
                  UiButton(label: 'Get guidance', variant: UiButtonVariant.accent, block: true, onPressed: () {}),
                ]),
              ),
            ),
          ));
    });
  });
}
