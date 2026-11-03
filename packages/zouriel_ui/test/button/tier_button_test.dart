import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

double _lum(Color c) {
  double f(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double _contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

BoxDecoration _deco(WidgetTester tester, [Finder? of]) =>
    tester.widget<AnimatedContainer>(find.descendant(of: of ?? find.byType(UiButton), matching: find.byType(AnimatedContainer))).decoration! as BoxDecoration;

TextStyle _label(WidgetTester tester, String text) => tester.renderObject<RenderParagraph>(find.text(text)).text.style!;

void main() {
  testWidgets('a tier button is the metal: its sheen, contrast label, edge, weight 600; tier wins over variant', (tester) async {
    for (final tier in UiTier.values) {
      await pumpUi(tester, UiButton(label: 'Buy', tier: tier, variant: UiButtonVariant.ghost, onPressed: () {}));
      final t = tester.element(find.byType(UiButton)).ui;
      final d = _deco(tester);
      expect(d.color, isNull, reason: '$tier');
      expect((d.gradient! as LinearGradient).colors, tier.gradient(t).colors, reason: '$tier');
      expect((d.border! as Border).top.color, tier.border(t), reason: '$tier');
      expect(_label(tester, 'Buy').color, tier.contrast(t), reason: '$tier');
      expect(_label(tester, 'Buy').fontWeight, FontWeight.w600);
    }
  });

  testWidgets('hover brightens toward the light stop, press darkens toward the base, and the label keeps AA', (tester) async {
    await pumpUi(tester, UiButton(label: 'Buy', tier: UiTier.premium, onPressed: () {}));
    final t = tester.element(find.byType(UiButton)).ui;
    List<Color> colors() => (_deco(tester).gradient! as LinearGradient).colors;
    final rest = colors();

    // Hover highlights show in traditional (pointer) highlight mode, as on a desktop.
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(UiButton)));
    await tester.pumpAndSettle();
    final hover = colors();
    expect(_lum(hover.first), greaterThan(_lum(rest.first)));

    await mouse.down(tester.getCenter(find.byType(UiButton)));
    await tester.pump(const Duration(milliseconds: 50));
    final pressed = colors();
    expect(_lum(pressed[1]), lessThan(_lum(rest[1])));
    await mouse.up();
    await tester.pumpAndSettle();

    for (final c in [...hover, ...pressed]) {
      expect(_contrast(UiTier.premium.contrast(t), c), greaterThanOrEqualTo(4.5), reason: '$c');
    }
  });

  testWidgets('keyboard focus draws the ring in the tier edge colour over a page-coloured gap', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await pumpUi(tester, UiButton(label: 'Gold', tier: UiTier.gold, focusNode: node, onPressed: () {}));
    final t = tester.element(find.byType(UiButton)).ui;
    expect(_deco(tester).boxShadow, isEmpty);
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    node.requestFocus();
    await tester.pumpAndSettle();
    final ring = _deco(tester).boxShadow!;
    expect(ring, uiTierFocusRing(UiTier.gold, t));
    expect(ring.first.color, t.tierGoldBorder);
    expect(ring.last.color, t.bg);
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  testWidgets('disabled dims like other buttons; loading keeps full colour with a contrast spinner', (tester) async {
    await tester.pumpWidget(const UiApp(home: Column(children: [
      UiButton(label: 'Off', tier: UiTier.platinum, onPressed: null),
      UiButton(label: 'Busy', tier: UiTier.premium, loading: true, onPressed: _noop),
    ])));
    await tester.pump(const Duration(milliseconds: 400));
    final t = tester.element(find.byType(UiButton).first).ui;
    final opacities = tester.widgetList<AnimatedOpacity>(find.descendant(of: find.byType(UiButton), matching: find.byType(AnimatedOpacity))).map((o) => o.opacity).toList();
    expect(opacities, [0.5, 1]);
    final spinner = tester.widget<UiSpinner>(find.byType(UiSpinner));
    expect(spinner.color, t.tierPremiumContrast);
  });

  testWidgets('works with size, block and an icon', (tester) async {
    await pumpUi(tester, SizedBox(
      width: 300,
      child: Column(children: [
        UiButton(label: 'Large', tier: UiTier.gold, size: UiSize.lg, icon: const UiIcon(HugeIcons.strokeRoundedCrown), onPressed: () {}),
        UiButton(label: 'Wide', tier: UiTier.platinum, block: true, onPressed: () {}),
      ]),
    ));
    final t = tester.element(find.byType(UiButton).first).ui;
    expect(tester.getSize(find.descendant(of: find.byType(UiButton).first, matching: find.byType(AnimatedContainer))).height, t.sizeLg);
    expect(tester.getSize(find.byType(UiButton).last).width, 300);
    final icon = tester.widget<IconTheme>(find.descendant(of: find.byType(UiButton).first, matching: find.byType(IconTheme)).first);
    expect(icon.data.color, t.tierGoldContrast);
  });

  group('platinum sweep', () {
    Future<CustomPaint> hoverAndRead(WidgetTester tester) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(UiButton)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      return tester.widget<CustomPaint>(find.descendant(of: find.byKey(const ValueKey('ui-tier-sweep')), matching: find.byType(CustomPaint)));
    }

    bool running(CustomPaint p) => (p.painter! as dynamic).progress.isAnimating as bool;

    testWidgets('a light band crosses the button once on hover', (tester) async {
      await pumpUi(tester, UiButton(label: 'Platinum', tier: UiTier.platinum, onPressed: () {}));
      expect(running(await hoverAndRead(tester)), isTrue);
      await tester.pumpAndSettle();
      expect(running(tester.widget<CustomPaint>(find.descendant(of: find.byKey(const ValueKey('ui-tier-sweep')), matching: find.byType(CustomPaint)))), isFalse);
    });

    testWidgets('no sweep when the platform asks for no animations', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pumpUi(tester, UiButton(label: 'Platinum', tier: UiTier.platinum, onPressed: () {}));
      expect(running(await hoverAndRead(tester)), isFalse);
    });

    testWidgets('only platinum sweeps', (tester) async {
      await pumpUi(tester, UiButton(label: 'Gold', tier: UiTier.gold, onPressed: () {}));
      expect(find.byKey(const ValueKey('ui-tier-sweep')), findsNothing);
    });
  });

  test('every tier holds AA on both stops and a 3:1 focus ring on every page, in every theme', () {
    expect(uiThemeTokens.length, UiThemeName.values.length);
    uiThemeTokens.forEach((name, t) {
      for (final tier in UiTier.values) {
        for (final stop in [tier.base(t), tier.light(t)]) {
          expect(_contrast(tier.contrast(t), stop), greaterThanOrEqualTo(4.5), reason: '$name $tier text on $stop');
        }
        for (final ground in [t.bg, t.surface, t.surfaceRaised]) {
          final solid = Color.alphaBlend(ground, t.bg);
          expect(_contrast(tier.border(t), solid), greaterThanOrEqualTo(3), reason: '$name $tier ring on $solid');
        }
      }
    });
  });

  testWidgets('meets the Android tap-target, labelled-target and contrast guidelines', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final handle = tester.ensureSemantics();
    await pumpUi(tester, Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final tier in UiTier.values) UiButton(label: tier.name, tier: tier, onPressed: () {}),
      ]),
    ));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('golden: tier buttons', (tester) async {
    await expectThemedGolden(tester, 'button_tier', height: 150, (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          UiButton(label: 'Get Gold', tier: UiTier.gold, onPressed: () {}),
          UiButton(label: 'Get Platinum', tier: UiTier.platinum, onPressed: () {}),
          UiButton(label: 'Go Premium', tier: UiTier.premium, onPressed: () {}),
        ]),
        Wrap(spacing: 8, runSpacing: 8, children: [
          UiButton(label: 'Small', tier: UiTier.gold, size: UiSize.sm, onPressed: () {}),
          const UiButton(label: 'Busy', tier: UiTier.platinum, loading: true, onPressed: _noop),
          const UiButton(label: 'Off', tier: UiTier.premium, onPressed: null),
        ]),
      ],
    ));
  });
}

void _noop() {}
