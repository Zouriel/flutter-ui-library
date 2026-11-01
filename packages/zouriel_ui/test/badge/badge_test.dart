import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

void main() {
  testWidgets('chip remove button is named after the chip and calls onRemove', (tester) async {
    final handle = tester.ensureSemantics();
    var removed = 0;
    await pumpUi(tester, UiChip(label: 'flutter', onRemove: () => removed++));
    expect(find.bySemanticsLabel('Remove flutter'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Remove flutter'));
    expect(removed, 1);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('avatar shows initials, is named, and falls back when the image fails', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const Row(children: [
      UiAvatar(name: 'Aminath Shareef'),
      UiAvatar(name: 'Cher'),
      UiAvatar(image: _FailingImage(), name: 'Ali Zahir', alt: 'Ali'),
    ]));
    expect(find.text('AS'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('AZ'), findsOneWidget);
    expect(find.bySemanticsLabel('Ali'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('avatar group caps at max and announces the rest', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const UiAvatarGroup(max: 2, children: [
      UiAvatar(name: 'A One'), UiAvatar(name: 'B Two'), UiAvatar(name: 'C Three'), UiAvatar(name: 'D Four'),
    ]));
    expect(find.text('+2'), findsOneWidget);
    expect(find.bySemanticsLabel('2 more'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('badges hug their text instead of stretching', (tester) async {
    await pumpUi(tester, const SizedBox(width: 300, child: Wrap(children: [UiBadge(label: 'New')])));
    expect(tester.getSize(find.byType(UiBadge)).width, lessThan(60));
    expect(tester.getSize(find.byType(UiBadge)).height, 20);
  });

  group('tier', () {
    BoxDecoration decorationOf(WidgetTester tester) => tester.widget<Container>(find.descendant(of: find.byType(UiBadge), matching: find.byType(Container)).first).decoration! as BoxDecoration;
    TextStyle textOf(WidgetTester tester, String label) => tester.renderObject<RenderParagraph>(find.text(label)).text.style!;

    double lum(Color c) {
      double f(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }

    double contrast(Color a, Color b) {
      final x = lum(a), y = lum(b);
      return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
    }

    testWidgets('a badge without a tier stays on its tone', (tester) async {
      await pumpUi(tester, const UiBadge(label: 'Active', tone: UiStatus.success));
      final t = tester.element(find.byType(UiBadge)).ui;
      final d = decorationOf(tester);
      expect(d.gradient, isNull);
      expect(d.color, t.success);
      expect(textOf(tester, 'Active').color, t.successContrast);
    });

    testWidgets('draws the metal from its tokens, and wins over the tone', (tester) async {
      await pumpUi(tester, const UiBadge(label: 'Gold pass', tier: UiBadgeTier.gold, tone: UiStatus.success));
      var t = tester.element(find.byType(UiBadge)).ui;
      var d = decorationOf(tester);
      expect(d.color, isNull);
      expect((d.gradient! as LinearGradient).colors, t.gradientTierGold.colors);
      expect((d.border! as Border).top.color, t.tierGoldBorder);
      expect(textOf(tester, 'Gold pass').color, t.tierGoldContrast);

      await pumpUi(tester, const UiBadge(label: 'Platinum pass', tier: UiBadgeTier.platinum));
      t = tester.element(find.byType(UiBadge)).ui;
      d = decorationOf(tester);
      expect((d.gradient! as LinearGradient).colors, t.gradientTierPlatinum.colors);
      expect((d.border! as Border).top.color, t.tierPlatinumBorder);
      expect(textOf(tester, 'Platinum pass').color, t.tierPlatinumContrast);
    });

    testWidgets('keeps the badge size and works as a dot', (tester) async {
      await pumpUi(tester, const UiBadge(label: 'Gold pass', tier: UiBadgeTier.gold));
      expect(tester.getSize(find.byType(UiBadge)).height, 20);
      await pumpUi(tester, const UiBadge(dot: true, tier: UiBadgeTier.platinum, semanticLabel: 'Platinum'));
      expect(tester.getSize(find.byType(UiBadge)), const Size(8, 8));
      expect(decorationOf(tester).gradient, isNotNull);
    });

    test('the sheen runs straight across, as on the web', () {
      final g = uiThemeTokens[UiThemeName.dark]!.gradientTierGold;
      expect(g.angle, 90);
      expect(g.colors.length, 3);
    });

    test('text holds AA on every stop, and the pill shows on every page, in every theme', () {
      expect(uiThemeTokens.length, UiThemeName.values.length);
      uiThemeTokens.forEach((name, t) {
        for (final tier in UiBadgeTier.values) {
          for (final stop in tier.gradient(t).colors) {
            expect(contrast(tier.contrast(t), stop), greaterThanOrEqualTo(4.5), reason: '$name $tier text on $stop');
          }
          final fill = tier.gradient(t).colors.first;
          for (final ground in [t.bg, t.surface, t.surfaceRaised]) {
            // Translucent surfaces are judged over the page they sit on.
            final solid = Color.alphaBlend(ground, t.bg);
            final best = math.max(contrast(tier.border(t), solid), contrast(fill, solid));
            expect(best, greaterThanOrEqualTo(3), reason: '$name $tier on $solid');
          }
        }
      });
    });
  });

  testWidgets('golden: tier badges', (tester) async {
    await expectThemedGolden(tester, 'badge_tier', height: 80, (context) => const Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      UiBadge(label: 'Gold pass', tier: UiBadgeTier.gold),
      UiBadge(label: 'Platinum pass', tier: UiBadgeTier.platinum),
      UiBadge(dot: true, tier: UiBadgeTier.gold),
      UiBadge(dot: true, tier: UiBadgeTier.platinum),
    ]));
  });

  testWidgets('golden: badges, chips and avatars', (tester) async {
    await expectThemedGolden(tester, 'badge_chip_avatar', height: 360, (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        const Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          UiBadge(label: 'Neutral'), UiBadge(label: 'New', tone: UiStatus.primary), UiBadge(label: 'Active', tone: UiStatus.success),
          UiBadge(label: 'Pending', tone: UiStatus.warning), UiBadge(label: '3', tone: UiStatus.danger), UiBadge(dot: true, tone: UiStatus.success),
        ]),
        Wrap(spacing: 8, runSpacing: 8, children: [
          UiChip(label: 'Removable', onRemove: () {}),
          const UiChip(label: 'Primary', tone: UiStatus.primary),
          const UiChip(label: 'Danger', tone: UiStatus.danger),
        ]),
        const Row(spacing: 8, children: [
          UiAvatar(name: 'Aminath Shareef', size: UiSize.sm), UiAvatar(name: 'Ali Zahir'), UiAvatar(name: 'Mariyam', size: UiSize.lg), UiAvatar(name: 'Sq', square: true),
        ]),
        const UiAvatarGroup(max: 3, children: [UiAvatar(name: 'A One'), UiAvatar(name: 'B Two'), UiAvatar(name: 'C Three'), UiAvatar(name: 'D Four')]),
      ],
    ));
  });
}

/// An image that always fails to load.
class _FailingImage extends ImageProvider<_FailingImage> {
  const _FailingImage();
  @override
  Future<_FailingImage> obtainKey(ImageConfiguration configuration) => Future.value(this);
  @override
  ImageStreamCompleter loadImage(_FailingImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Future.error(Exception('404')));
}
