import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// 0.39.0: badgeTone, enter / enterDelay, hover and focus motion, and custom colors.

const _icon = UiIcon(HugeIcons.strokeRoundedStethoscope);
final _mint = UiFeatureCardColors.tryParse(surface: '#E1F4EF', accent: '#4B8791')!;
final _blue = UiFeatureCardColors.tryParse(surface: '#E5F0FA', accent: '#4B8791')!;

Widget _tile({
  UiFeatureTone tone = UiFeatureTone.accent,
  UiFeatureTone? badgeTone,
  UiFeatureCardColors? colors,
  bool enter = false,
  Duration enterDelay = Duration.zero,
  String? actionLabel,
}) =>
    SizedBox(
      width: 180,
      child: UiFeatureCard(
        key: const ValueKey('card'),
        icon: _icon,
        title: 'Nurse at home',
        description: 'A nurse comes to you.',
        size: UiSize.sm,
        surface: UiFeatureSurface.tinted,
        controlRadius: true,
        trailingArrow: true,
        descriptionLines: 2,
        tone: tone,
        badgeTone: badgeTone,
        colors: colors,
        enter: enter,
        enterDelay: enterDelay,
        actionLabel: actionLabel,
        onPressed: () {},
      ),
    );

Future<void> _pump(WidgetTester tester, Widget child, {UiThemeName theme = UiThemeName.maldives, bool reduced = false}) async {
  tester.view.physicalSize = const Size(390, 600) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(
    theme: theme,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.all(16), child: child)),
      ),
    ),
  ));
}

/// The badge: the box right around the icon.
BoxDecoration _badge(WidgetTester tester) => tester
    .widgetList<Container>(find.ancestor(of: find.byWidget(_icon), matching: find.byType(Container)))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .first;

Color _iconColor(WidgetTester tester) => IconTheme.of(tester.element(find.byWidget(_icon))).color!;

/// The card's own box (fill and border).
BoxDecoration _cardBox(WidgetTester tester) => tester
    .widgetList<AnimatedContainer>(find.descendant(of: find.byKey(const ValueKey('card')), matching: find.byType(AnimatedContainer)))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .last;

double _enterOpacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.ancestor(of: find.byType(UiInteractive), matching: find.byType(Opacity)).first).opacity;

double _iconScale(WidgetTester tester) => tester.widget<AnimatedScale>(find.byKey(const ValueKey('ui-feature-card-icon'))).scale;
double _arrowShift(WidgetTester tester) => tester.widget<AnimatedSlide>(find.byKey(const ValueKey('ui-feature-card-arrow'))).offset.dx;

void main() {
  group('badgeTone', () {
    testWidgets('left out: the badge is the card tone, as before', (tester) async {
      await _pump(tester, _tile());
      final t = uiThemeTokens[UiThemeName.maldives]!;
      expect(_badge(tester).color, t.accent);
      expect(_iconColor(tester), t.accentContrast);
    });

    testWidgets('an accent card with a primary badge, and a primary card with an accent badge', (tester) async {
      final t = uiThemeTokens[UiThemeName.maldives]!;
      await _pump(tester, _tile(badgeTone: UiFeatureTone.primary));
      expect(_badge(tester).color, Color.lerp(t.surface, t.primary, 0.18));
      expect(_iconColor(tester), t.primary);
      await _pump(tester, _tile(tone: UiFeatureTone.primary, badgeTone: UiFeatureTone.accent));
      expect(_badge(tester).color, t.accent);
      expect(_iconColor(tester), t.accentContrast);
    });

    // The combinations 0.39 adds: a primary (or brand) badge on an accent card. (An accent badge is the
    // accent tone's own badge, unchanged by badgeTone; it is 2.95:1 in lightPurpleGold, a theme matter.)
    test('the icon is 3:1 on a primary or brand badge in every theme (default and tinted surface)', () {
      final fails = <String>[];
      for (final name in UiThemeName.values) {
        final t = uiThemeTokens[name]!;
        for (final k in [0.14, 0.18]) {
          final r = uiContrast(t.primary, Color.lerp(t.surface, t.primary, k)!);
          if (r < 3) fails.add('$name primary badge ($k): ${r.toStringAsFixed(2)}');
        }
      }
      expect(fails, isEmpty);
    });
  });

  group('enter', () {
    testWidgets('plays once after its delay, and not again on a rebuild or theme change', (tester) async {
      await _pump(tester, _tile(enter: true, enterDelay: const Duration(milliseconds: 90)));
      expect(_enterOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 80));
      expect(_enterOpacity(tester), 0, reason: 'still waiting out the delay');
      await tester.pump(const Duration(milliseconds: 100));
      final mid = _enterOpacity(tester);
      expect(mid, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_enterOpacity(tester), 1);
      await _pump(tester, _tile(enter: true, enterDelay: const Duration(milliseconds: 90), tone: UiFeatureTone.primary), theme: UiThemeName.maldivesDark);
      await tester.pump();
      expect(_enterOpacity(tester), 1, reason: 'no replay');
      await tester.pumpAndSettle();
      expect(_enterOpacity(tester), 1);
    });

    testWidgets('reduced motion: shown at once', (tester) async {
      await _pump(tester, _tile(enter: true, enterDelay: const Duration(milliseconds: 90)), reduced: true);
      expect(find.ancestor(of: find.byType(UiInteractive), matching: find.byType(Opacity)), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('off by default', (tester) async {
      await _pump(tester, _tile());
      expect(find.ancestor(of: find.byType(UiInteractive), matching: find.byType(Opacity)), findsNothing);
    });
  });

  group('hover and focus motion', () {
    testWidgets('hover lifts the icon and nudges the arrow; leaving puts them back', (tester) async {
      await _pump(tester, _tile());
      expect([_iconScale(tester), _arrowShift(tester)], [1, 0]);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(UiFeatureCard)));
      await tester.pump();
      expect(_iconScale(tester), 1.08);
      expect(_arrowShift(tester), greaterThan(0));
      await mouse.moveTo(const Offset(380, 590));
      await tester.pump();
      expect([_iconScale(tester), _arrowShift(tester)], [1, 0]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('keyboard focus does the same; in RTL the arrow nudges left', (tester) async {
      await _pump(tester, Directionality(textDirection: TextDirection.rtl, child: _tile()));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_iconScale(tester), 1.08);
      expect(_arrowShift(tester), lessThan(0));
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('none of it under reduced motion', (tester) async {
      await _pump(tester, _tile(), reduced: true);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(UiFeatureCard)));
      await tester.pump();
      expect([_iconScale(tester), _arrowShift(tester)], [1, 0]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });

  group('colors', () {
    testWidgets("draws the app's surface and accent; the title stays the theme text; accent border only on hover", (tester) async {
      await _pump(tester, _tile(colors: _mint, actionLabel: 'Request'));
      final t = uiThemeTokens[UiThemeName.maldives]!;
      expect(_cardBox(tester).color, uiParseColor('#E1F4EF'));
      expect(_badge(tester).color, const UiFeatureCardColors(surface: Color.fromARGB(255, 225, 244, 239), accent: Color.fromARGB(255, 75, 135, 145)).badgeOnLight);
      expect(_iconColor(tester), uiParseColor('#4B8791'));
      expect(tester.widget<Text>(find.text('Nurse at home')).style?.color ?? DefaultTextStyle.of(tester.element(find.text('Nurse at home'))).style.color, t.text);
      expect((_cardBox(tester).border! as Border).top.color.a, 0, reason: 'no border at rest');
      final ink = tester.widget<Text>(find.text('Request')).style!.color!;
      expect(uiContrast(ink, uiParseColor('#E1F4EF')!), greaterThanOrEqualTo(4.5));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(UiFeatureCard)));
      await tester.pump();
      expect((_cardBox(tester).border! as Border).top.color, uiParseColor('#4B8791'));
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    // 0.40.2: on the web a device in dark mode with a light app showed the dark pair (the tokens were read
    // before the stylesheet loaded). Here the card reads the UiApp theme, never the platform brightness.
    testWidgets('a device in dark mode with a light UiApp: the light pair on the very first frame', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await _pump(tester, Row(children: [Expanded(child: _tile(colors: _mint)), Expanded(child: _tile(colors: _blue))]));
      // No pumpAndSettle: the first frame already has them.
      final boxes = tester
          .widgetList<AnimatedContainer>(find.descendant(of: find.byKey(const ValueKey('card')), matching: find.byType(AnimatedContainer)))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color)
          .toSet();
      expect(boxes, containsAll([uiParseColor('#E1F4EF'), uiParseColor('#E5F0FA')]));
    });

    testWidgets('with a UiThemeController (device dark): light first, follows a switch to dark and back', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final c = UiThemeController(theme: UiThemeName.maldives);
      addTearDown(c.dispose);
      await tester.pumpWidget(UiApp(
        controller: c,
        home: Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.all(16), child: _tile(colors: _mint))),
      ));
      expect(_cardBox(tester).color, uiParseColor('#E1F4EF'));
      c.set(UiThemeName.maldivesDark);
      await tester.pumpAndSettle();
      expect(_cardBox(tester).color, isNot(uiParseColor('#E1F4EF')));
      expect(_cardBox(tester).color!.computeLuminance(), lessThan(0.2));
      c.set(UiThemeName.maldives);
      await tester.pumpAndSettle();
      expect(_cardBox(tester).color, uiParseColor('#E1F4EF'));
    });

    test('the same colours as the web (light mint, derived maldives-dark and darkTeal, measured in Chrome)', () {
      Color rgb(int r, int g, int b) => Color.fromARGB(255, r, g, b);
      UiFeatureResolvedColors on(UiThemeName n) {
        final t = uiThemeTokens[n]!;
        return uiResolveFeatureColors(_mint, themeSurface: t.surface, themeText: t.text, themeMuted: t.textMuted, dark: t.surface.computeLuminance() < 0.2);
      }

      final light = on(UiThemeName.maldives);
      expect([light.surface, light.badge, light.accent], [rgb(225, 244, 239), rgb(204, 229, 226), rgb(75, 135, 145)]);
      final md = on(UiThemeName.maldivesDark);
      expect([md.surface, md.badge, md.accent], [rgb(24, 56, 66), rgb(37, 71, 81), rgb(118, 164, 171)]);
      final dt = on(UiThemeName.darkTeal);
      expect([dt.surface, dt.badge, dt.accent], [rgb(24, 46, 45), rgb(35, 61, 62), rgb(104, 154, 163)]);
    });

    test("the owner's colours read well in every theme (as given on light themes, derived on dark)", () {
      final fails = <String>[];
      for (final name in UiThemeName.values) {
        final t = uiThemeTokens[name]!;
        final dark = t.surface.computeLuminance() < 0.2;
        for (final (label, c) in [('mint', _mint), ('blue', _blue)]) {
          final r = uiResolveFeatureColors(c, themeSurface: t.surface, themeText: t.text, themeMuted: t.textMuted, dark: dark);
          if (!dark && (r.surface != c.surface || r.accent != c.accent)) fails.add('$name/$label: light colours changed');
          void need(String what, Color fg, Color bg, double n) {
            final x = uiContrast(fg, bg);
            if (x < n) fails.add('$name/$label: $what ${x.toStringAsFixed(2)} < $n');
          }

          final text = Color.alphaBlend(t.text, r.surface);
          need('title', text, r.surface, 4.5);
          need('description', r.desc, r.surface, 4.5);
          need('icon on its badge', r.accent, r.badge, 3);
          need('arrow', r.accent, r.surface, dark ? 4.5 : 3);
          need('action words', r.ink, r.surface, 4.5);
        }
      }
      expect(fails, isEmpty);
    });

    test('reads hex and rgb strings; anything else falls back (tryParse is null)', () {
      expect(uiParseColor('#E1F4EF'), const Color.fromARGB(255, 225, 244, 239));
      expect(uiParseColor('#abc'), const Color.fromARGB(255, 170, 187, 204));
      expect(uiParseColor('rgb(75, 135, 145)'), const Color.fromARGB(255, 75, 135, 145));
      expect(uiParseColor('rgba(75 135 145 / 0.5)'), const Color.fromARGB(255, 75, 135, 145));
      for (final bad in ['mint', '#12', '#gggggg', 'rgb(300, 0, 0)', '', 'hsl(0 0% 0%)']) {
        expect(uiParseColor(bad), isNull, reason: bad);
      }
      expect(UiFeatureCardColors.tryParse(surface: 'mint', accent: '#4B8791'), isNull);
      expect(UiFeatureCardColors.tryParse(surface: '#E1F4EF', accent: '#4B8791', accentDark: 'teal'), isNull);
    });
  });

  testWidgets('golden: the Dhirumi colours, badge tones (maldives, maldives dark)', (tester) async {
    await expectThemedGolden(
      tester,
      'feature_card_colors',
      (context) => Column(spacing: 12, children: [
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
            Expanded(child: _tile(colors: _mint)),
            Expanded(child: _tile(colors: _blue)),
          ]),
        ),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
            Expanded(child: _tile(badgeTone: UiFeatureTone.primary)),
            Expanded(child: _tile(tone: UiFeatureTone.primary, badgeTone: UiFeatureTone.accent)),
          ]),
        ),
      ]),
      themes: const [UiThemeName.maldives, UiThemeName.maldivesDark],
      height: 400,
    );
  });
}

extension on UiFeatureCardColors {
  /// The light badge: 14% of the accent over the surface, in whole channels.
  Color get badgeOnLight => Color.fromARGB(
        255,
        (accent.r * 255 * 0.14 + surface.r * 255 * 0.86).round(),
        (accent.g * 255 * 0.14 + surface.g * 255 * 0.86).round(),
        (accent.b * 255 * 0.14 + surface.b * 255 * 0.86).round(),
      );
}
