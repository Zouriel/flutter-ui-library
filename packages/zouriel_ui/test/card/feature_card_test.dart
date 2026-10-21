import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

const _icon = UiIcon(HugeIcons.strokeRoundedStethoscope);

UiFeatureCard card({
  VoidCallback? onPressed,
  bool enabled = true,
  UiFeatureTone tone = UiFeatureTone.primary,
  UiFeatureLayout layout = UiFeatureLayout.vertical,
  UiSize size = UiSize.md,
  Widget? icon = _icon,
  String? actionLabel = 'Book now',
}) =>
    UiFeatureCard(
      key: const ValueKey('card'),
      icon: icon,
      eyebrow: 'New',
      title: 'Find a doctor',
      description: 'See who is free today and book in a minute.',
      actionLabel: actionLabel,
      onPressed: onPressed,
      enabled: enabled,
      tone: tone,
      layout: layout,
      size: size,
    );

Finder get _badge => find.ancestor(of: find.byType(UiIcon).first, matching: find.byType(Container)).first;

void main() {
  testWidgets('the whole card is one button: tap anywhere fires onPressed', (tester) async {
    var n = 0;
    await pumpUi(tester, SizedBox(width: 340, child: card(onPressed: () => n++)));
    await tester.tap(find.text('Find a doctor'));
    await tester.tap(find.text('Book now'));
    await tester.tapAt(tester.getBottomRight(find.byKey(const ValueKey('card'))) - const Offset(8, 8));
    expect(n, 3);
  });

  testWidgets('disabled or without onPressed: not tappable; disabled is dimmed', (tester) async {
    final handle = tester.ensureSemantics();
    var n = 0;
    await pumpUi(tester, SizedBox(width: 340, child: card(onPressed: () => n++, enabled: false)));
    await tester.tap(find.text('Find a doctor'), warnIfMissed: false);
    expect(n, 0);
    expect(find.byType(Opacity), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.5);
    final data = tester.getSemantics(find.byType(UiFeatureCard)).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isEnabled.toString(), contains('isFalse'));

    await pumpUi(tester, SizedBox(width: 340, child: card()));
    expect(find.byType(Opacity), findsNothing);
    expect(find.byType(UiInteractive), findsNothing, reason: 'a static card is no target');
    expect(find.semantics.byFlag(SemanticsFlag.isButton), findsNothing);

    // Disabled with no action and no handler: a dimmed static card, not a disabled button (the web
    // card without actionLabel / href).
    await pumpUi(tester, SizedBox(width: 340, child: card(enabled: false, actionLabel: null)));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.5);
    expect(find.byType(UiInteractive), findsNothing);
    expect(find.semantics.byFlag(SemanticsFlag.isButton), findsNothing);
    handle.dispose();
  });

  testWidgets('one labelled node: "title, action", described by the description, no nested target', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, SizedBox(width: 340, child: card(onPressed: () {})));
    expect(find.semantics.byFlag(SemanticsFlag.isButton), findsOneWidget);
    final data = tester.getSemantics(find.byType(UiFeatureCard)).getSemanticsData();
    expect(data.label, 'Find a doctor, Book now');
    expect(data.hint, 'See who is free today and book in a minute.');
    expect(find.byType(UiInteractive), findsOneWidget);
    // Without an action label the title alone names it.
    await pumpUi(tester, SizedBox(width: 340, child: card(onPressed: () {}, actionLabel: null)));
    expect(tester.getSemantics(find.byType(UiFeatureCard)).getSemanticsData().label, 'Find a doctor');
    expect(find.text('Book now'), findsNothing);
    handle.dispose();
  });

  for (final theme in [UiThemeName.light, UiThemeName.dark, UiThemeName.maldives, UiThemeName.maldivesDark, UiThemeName.lightOrange, UiThemeName.darkTeal]) {
    testWidgets('meets the tap target, label and contrast guidelines in ${theme.name}', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final handle = tester.ensureSemantics();
      await pumpUi(
        tester,
        SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, spacing: 12, children: [
            for (final tone in UiFeatureTone.values)
              UiFeatureCard(icon: _icon, eyebrow: 'New', title: 'Tone ${tone.name}', description: 'Short text.', actionLabel: 'Open', tone: tone, onPressed: () {}, layout: UiFeatureLayout.horizontal),
          ]),
        ),
        theme: theme,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  }

  // textContrastGuideline samples the card's one merged node as a whole, so the title's contrast
  // hides a faint description. Check every drawn text colour against the washed surface instead.
  testWidgets('every text is AA (4.5:1) on its washed surface, in every theme and tone', (tester) async {
    double ratio(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
    }

    final fails = <String>[];
    for (final theme in UiThemeName.values) {
      for (final tone in UiFeatureTone.values) {
        await pumpUi(tester, SizedBox(width: 360, child: card(onPressed: () {}, tone: tone)), theme: theme);
        final t = uiThemeTokens[theme]!;
        final toneColor = tone == UiFeatureTone.accent ? t.accent : t.primary;
        final grounds = [t.surface, if (tone != UiFeatureTone.neutral) Color.lerp(t.surface, toneColor, 0.03)!];
        for (final p in tester.renderObjectList<RenderParagraph>(find.descendant(of: find.byKey(const ValueKey('card')), matching: find.byType(RichText)))) {
          final c = p.text.style!.color!;
          for (final g in grounds) {
            final r = ratio(c, g);
            if (r < 4.5) fails.add('${theme.name}/${tone.name}: "${p.text.toPlainText()}" ${r.toStringAsFixed(2)}:1');
          }
        }
      }
    }
    // The icon on the 14% badge tint (primary, brand) is a graphic: 3:1.
    for (final theme in UiThemeName.values) {
      final t = uiThemeTokens[theme]!;
      final r = ratio(t.primary, Color.lerp(t.surface, t.primary, 0.14)!);
      if (r < 3) fails.add('${theme.name}: badge icon ${r.toStringAsFixed(2)}:1');
    }
    expect(fails, isEmpty);
  });

  testWidgets('sizes: badge 48 / 56, padding 24 / 32 inside the 1px border', (tester) async {
    await pumpUi(tester, SizedBox(width: 340, child: card(onPressed: () {})));
    final cardBox = tester.getRect(find.byKey(const ValueKey('card')));
    expect(tester.getSize(_badge), const Size(48, 48));
    expect(tester.getTopLeft(_badge) - cardBox.topLeft, const Offset(25, 25), reason: '1px border + 24');
    expect(tester.getSize(find.byType(UiIcon).first), const Size(24, 24));
    await pumpUi(tester, SizedBox(width: 340, child: card(onPressed: () {}, size: UiSize.lg)));
    final big = tester.getRect(find.byKey(const ValueKey('card')));
    expect(tester.getSize(_badge), const Size(56, 56));
    expect(tester.getTopLeft(_badge) - big.topLeft, const Offset(33, 33), reason: '1px border + 32');
    expect(tester.getSize(find.byType(UiIcon).first), const Size(28, 28));
  });

  testWidgets('vertical stacks the badge over the text; horizontal puts it beside, at the start', (tester) async {
    await pumpUi(tester, SizedBox(width: 340, child: card(onPressed: () {})));
    expect(tester.getTopLeft(find.text('NEW')), Offset(tester.getTopLeft(_badge).dx, tester.getBottomLeft(_badge).dy + 16));
    await pumpUi(tester, SizedBox(width: 340, child: card(onPressed: () {}, layout: UiFeatureLayout.horizontal)));
    expect(tester.getTopLeft(find.text('NEW')).dx, tester.getTopRight(_badge).dx + 16);
    expect(tester.getTopLeft(find.text('NEW')).dy, tester.getTopLeft(_badge).dy, reason: 'badge top-aligned with the text');
  });

  testWidgets('RTL: badge on the right, arrow points left', (tester) async {
    await pumpUi(
      tester,
      SizedBox(width: 340, child: Directionality(textDirection: TextDirection.rtl, child: card(onPressed: () {}, layout: UiFeatureLayout.horizontal))),
    );
    final c = tester.getRect(find.byKey(const ValueKey('card')));
    expect(tester.getTopRight(_badge).dx, c.right - 25);
    expect(tester.getTopRight(find.text('NEW')).dx, tester.getTopLeft(_badge).dx - 16);
    final arrow = tester.widget<UiIcon>(find.byType(UiIcon).last);
    expect(arrow.icon, HugeIcons.strokeRoundedArrowLeft02);
    expect(tester.getTopRight(find.byType(UiIcon).last).dx, lessThan(tester.getTopLeft(find.text('Book now')).dx));
  });

  testWidgets('in a stretched row the actions line up at the bottom; on its own the card hugs its content', (tester) async {
    await pumpUi(tester, SizedBox(width: 380, child: card(onPressed: () {})));
    final hug = tester.getSize(find.byKey(const ValueKey('card'))).height;
    expect(hug, lessThan(400));
    await pumpUi(
      tester,
      SizedBox(
        width: 700,
        height: 420,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
          Expanded(child: UiFeatureCard(key: const ValueKey('a'), title: 'Short', actionLabel: 'Go A', onPressed: () {})),
          Expanded(child: UiFeatureCard(key: const ValueKey('b'), title: 'Longer', description: 'A description\nover\nseveral\nlines.', actionLabel: 'Go B', onPressed: () {})),
        ]),
      ),
    );
    expect(tester.getBottomLeft(find.text('Go A')).dy, tester.getBottomLeft(find.text('Go B')).dy);
    expect(tester.getBottomLeft(find.text('Go A')).dy, closeTo(420 - 25, 1));
  });

  testWidgets('golden: tones, layouts, lg', (tester) async {
    await expectThemedGolden(
      tester,
      'feature_card',
      (context) => SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
          for (final tone in UiFeatureTone.values)
            UiFeatureCard(
              icon: const UiIcon(HugeIcons.strokeRoundedStethoscope),
              eyebrow: tone.name,
              title: 'Find a doctor',
              description: 'See who is free today and book in a minute.',
              actionLabel: 'Book now',
              tone: tone,
              layout: tone.index.isEven ? UiFeatureLayout.horizontal : UiFeatureLayout.vertical,
              onPressed: () {},
            ),
          UiFeatureCard(
            icon: const UiIcon(HugeIcons.strokeRoundedHospital01),
            title: 'For clinics',
            description: 'List your doctors and take bookings.',
            actionLabel: 'Get started',
            tone: UiFeatureTone.brand,
            size: UiSize.lg,
            onPressed: () {},
          ),
          const UiFeatureCard(title: 'Disabled', description: 'Coming soon.', actionLabel: 'Open', enabled: false, onPressed: null),
        ]),
      ),
      themes: const [UiThemeName.dark, UiThemeName.light, UiThemeName.maldives],
      height: 1340,
    );
  });
}
