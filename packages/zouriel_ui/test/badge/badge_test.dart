import 'dart:math' as math;
import 'dart:ui' as ui;

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

    testWidgets('premium is a violet metal with light text, and UiTier names the same tiers', (tester) async {
      await pumpUi(tester, const UiBadge(label: 'Premium', tier: UiTier.premium));
      final t = tester.element(find.byType(UiBadge)).ui;
      final d = decorationOf(tester);
      expect((d.gradient! as LinearGradient).colors, t.gradientTierPremium.colors);
      expect(t.gradientTierPremium.colors, [t.tierPremium, t.tierPremiumLight, t.tierPremium]);
      expect((d.border! as Border).top.color, t.tierPremiumBorder);
      expect(textOf(tester, 'Premium').color, t.tierPremiumContrast);
      // Violet: blue over red over green; the label is the light side.
      expect(t.tierPremium.b > t.tierPremium.r && t.tierPremium.r > t.tierPremium.g, isTrue);
      expect(lum(t.tierPremiumContrast), greaterThan(lum(t.tierPremiumLight)));
      expect(UiTier.values, [UiBadgeTier.gold, UiBadgeTier.platinum, UiBadgeTier.premium]);
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
      UiBadge(label: 'Premium', tier: UiBadgeTier.premium),
      UiBadge(dot: true, tier: UiBadgeTier.gold),
      UiBadge(dot: true, tier: UiBadgeTier.platinum),
      UiBadge(dot: true, tier: UiBadgeTier.premium),
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

  group('avatar crop', () {
    // A 300x200 image; the face box is off-centre and not square (90 x 40 px).
    const box = UiAvatarCrop(x: 0.5, y: 0.1, w: 0.2, h: 0.2);

    testWidgets('maps a known box to the expected size and position', (tester) async {
      final l = uiAvatarCropLayout(box, padding: 0.25, aspect: 1.5)!;
      // padded box x 0.45-0.75, y 0.05-0.35 -> 0.3 x 0.3; 90 x 60 px, so the 90px side fills
      expect([l.width, l.height].map((v) => v.round()), [333, 222]);
      expect(l.left.round(), -150);
      expect(l.top, 0); // centre would be 5.6; kept inside the image edge
      final z = uiAvatarCropLayout(const UiAvatarCrop(x: 0.4, y: 0.4, w: 0.2, h: 0.2), padding: 0, aspect: 1)!;
      expect([z.width, z.left, z.top].map((v) => v.round()), [500, -200, -200]);
      expect(uiAvatarCropLayout(const UiAvatarCrop(x: 0.4, y: 0.4, w: 0.2, h: 0.2), padding: 0.5)!.width, closeTo(250, 1e-9));
      final e = uiAvatarCropLayout(const UiAvatarCrop(x: 0, y: 0, w: 0.4, h: 0.4))!;
      expect([e.width, e.left, e.top], [200, 0, 0]);
      expect(uiAvatarCropLayout(const UiAvatarCrop(x: 0.1, y: 0.1, w: 0, h: 0.2)), isNull);
      final r = UiAvatarCrop.fromRect(const Rect.fromLTWH(0.5, 0.1, 0.2, 0.2));
      expect([r.x, r.y, r.w, r.h], [closeTo(0.5, 1e-9), closeTo(0.1, 1e-9), closeTo(0.2, 1e-9), closeTo(0.2, 1e-9)]);
    });

    testWidgets('paints the image at that place inside the avatar, and waits for the size', (tester) async {
      final img = (await tester.runAsync(() => createTestImage(width: 300, height: 200)))!;
      await pumpUi(tester, Center(child: UiAvatar(image: _SizedImage(img), crop: box, dimension: 100, name: 'Ada Lovelace')));
      await tester.pump();
      final avatar = tester.getRect(find.byType(UiAvatar));
      final picture = tester.getRect(find.byType(Image));
      // inside the 1px border the avatar is 98 wide: 333.3% x 222.2%, left -150%, top 0
      expect(picture.width, closeTo(98 * 10 / 3, 0.01));
      expect(picture.height, closeTo(98 * 200 / 90, 0.01));
      expect(picture.left - avatar.left - 1, closeTo(-1.5 * 98, 0.01));
      expect(picture.top - avatar.top - 1, closeTo(0, 0.01));
    });

    testWidgets('without a crop the image fills the avatar as before', (tester) async {
      final img = (await tester.runAsync(() => createTestImage(width: 300, height: 200)))!;
      await pumpUi(tester, Center(child: UiAvatar(image: _SizedImage(img), dimension: 100)));
      await tester.pump();
      expect(tester.getSize(find.byType(Image)), const Size(98, 98));
      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
    });

    testWidgets('falls back to initials when a cropped image fails', (tester) async {
      await pumpUi(tester, const UiAvatar(image: _FailingImage(), crop: box, name: 'Ali Zahir'));
      await tester.pumpAndSettle();
      expect(find.text('AZ'), findsOneWidget);
    });
  });
}

/// A decoded test image of a given size, handed out as is.
class _SizedImage extends ImageProvider<_SizedImage> {
  const _SizedImage(this.image);
  final ui.Image image;
  @override
  Future<_SizedImage> obtainKey(ImageConfiguration configuration) => Future.value(this);
  @override
  ImageStreamCompleter loadImage(_SizedImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image.clone())));
  @override
  bool operator ==(Object other) => other is _SizedImage && identical(other.image, image);
  @override
  int get hashCode => identityHashCode(image);
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
