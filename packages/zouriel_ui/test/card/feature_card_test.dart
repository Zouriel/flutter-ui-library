import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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

  // ── 0.38: the compact tinted tile (size sm, card action, clamp, tinted surface, control radius) ──

  testWidgets('size sm: 40px badge, 20px icon, 16px padding, body-strong title, small description', (tester) async {
    await pumpUi(tester, SizedBox(width: 340, child: card(onPressed: () {}, size: UiSize.sm)));
    final t = uiThemeTokens[UiThemeName.dark]!;
    final box = tester.getRect(find.byKey(const ValueKey('card')));
    expect(tester.getSize(_badge), const Size(40, 40));
    expect(tester.getTopLeft(_badge) - box.topLeft, const Offset(17, 17), reason: '1px border + 16');
    expect(tester.getSize(find.byType(UiIcon).first), const Size(20, 20));
    final title = tester.renderObject<RenderParagraph>(find.descendant(of: find.text('Find a doctor'), matching: find.byType(RichText))).text.style!;
    expect([title.fontSize, title.fontWeight], [t.fontSizeMd, FontWeight.w600]);
    final desc = tester.renderObject<RenderParagraph>(find.descendant(of: find.text('See who is free today and book in a minute.'), matching: find.byType(RichText))).text.style!;
    expect(desc.fontSize, t.fontSizeSm);
    expect(tester.getTopLeft(find.text('NEW')).dy, tester.getBottomLeft(_badge).dy + 12, reason: 'space3 under the badge');
  });

  UiFeatureCard tile({
    VoidCallback? onPressed,
    String? description = 'See who is free today and book in a minute.',
    String? actionLabel,
    bool trailingArrow = true,
    UiFeatureLayout layout = UiFeatureLayout.vertical,
    UiFeatureSurface surface = UiFeatureSurface.tinted,
    UiFeatureTone tone = UiFeatureTone.primary,
    int? lines = 2,
    bool controlRadius = true,
    bool? radius,
    Widget? icon = _icon,
    Key key = const ValueKey('card'),
  }) =>
      UiFeatureCard(
        key: key,
        icon: icon,
        title: 'Find a doctor',
        description: description,
        actionLabel: actionLabel,
        onPressed: onPressed,
        size: UiSize.sm,
        surface: surface,
        tone: tone,
        layout: layout,
        trailingArrow: trailingArrow,
        descriptionLines: lines,
        controlRadius: controlRadius,
        radius: radius,
      );

  Finder arrow() => find.byKey(const ValueKey('ui-feature-card-arrow'));

  testWidgets('trailingArrow without an action label: one button named "title, description", nothing nested', (tester) async {
    final handle = tester.ensureSemantics();
    var n = 0;
    await pumpUi(tester, SizedBox(width: 340, child: tile(onPressed: () => n++)));
    expect(find.semantics.byFlag(SemanticsFlag.isButton), findsOneWidget);
    expect(find.byType(UiInteractive), findsOneWidget);
    final data = tester.getSemantics(find.byType(UiFeatureCard)).getSemanticsData();
    expect(data.label, 'Find a doctor, See who is free today and book in a minute.');
    expect(data.hint, isEmpty, reason: 'the description is already in the name');
    expect(arrow(), findsOneWidget);
    await tester.tapAt(tester.getBottomRight(find.byKey(const ValueKey('card'))) - const Offset(6, 6));
    await tester.tap(arrow());
    expect(n, 2);
    // No description: the title names it.
    await pumpUi(tester, SizedBox(width: 340, child: tile(onPressed: () {}, description: null)));
    expect(tester.getSemantics(find.byType(UiFeatureCard)).getSemanticsData().label, 'Find a doctor');
    // An action label wins: its own arrow, no trailing one, the old name.
    await pumpUi(tester, SizedBox(width: 340, child: tile(onPressed: () {}, actionLabel: 'Book now')));
    expect(arrow(), findsNothing);
    expect(tester.getSemantics(find.byType(UiFeatureCard)).getSemanticsData().label, 'Find a doctor, Book now');
    // Without trailingArrow nothing changes from 0.37: the title names it, the description is the hint.
    await pumpUi(tester, SizedBox(width: 340, child: tile(onPressed: () {}, trailingArrow: false)));
    expect(arrow(), findsNothing);
    final plain = tester.getSemantics(find.byType(UiFeatureCard)).getSemanticsData();
    expect([plain.label, plain.hint], ['Find a doctor', 'See who is free today and book in a minute.']);
    handle.dispose();
  });

  testWidgets('the trailing arrow ends the badge row (vertical) or the title row, and flips in RTL', (tester) async {
    Future<void> pump(TextDirection dir, UiFeatureLayout layout) => pumpUi(
          tester,
          SizedBox(width: 340, child: Directionality(textDirection: dir, child: tile(onPressed: () {}, layout: layout))),
        );
    await pump(TextDirection.ltr, UiFeatureLayout.vertical);
    var c = tester.getRect(find.byKey(const ValueKey('card')));
    var a = tester.getRect(arrow());
    expect(a.right, c.right - 17, reason: '1px border + 16 from the end');
    expect(a.center.dy, tester.getCenter(_badge).dy, reason: 'centred on the badge');
    expect(tester.widget<UiIcon>(find.descendant(of: arrow(), matching: find.byType(UiIcon))).icon, HugeIcons.strokeRoundedArrowRight02);
    // The title keeps the full width (the arrow is not in its row).
    expect(tester.getSize(find.text('Find a doctor')).width, greaterThan(0));
    expect(tester.getRect(find.text('Find a doctor')).top, greaterThan(a.bottom));

    await pump(TextDirection.rtl, UiFeatureLayout.vertical);
    c = tester.getRect(find.byKey(const ValueKey('card')));
    a = tester.getRect(arrow());
    expect(a.left, c.left + 17);
    expect(tester.getTopRight(_badge).dx, c.right - 17, reason: 'badge at the start (right)');
    expect(tester.widget<UiIcon>(find.descendant(of: arrow(), matching: find.byType(UiIcon))).icon, HugeIcons.strokeRoundedArrowLeft02);

    await pump(TextDirection.ltr, UiFeatureLayout.horizontal);
    c = tester.getRect(find.byKey(const ValueKey('card')));
    a = tester.getRect(arrow());
    final title = tester.getRect(find.text('Find a doctor'));
    expect(a.right, c.right - 17);
    expect(a.center.dy, closeTo(title.top + 15 * 1.35 / 2, 0.5), reason: 'centred on the first title line');
    await pump(TextDirection.rtl, UiFeatureLayout.horizontal);
    c = tester.getRect(find.byKey(const ValueKey('card')));
    expect(tester.getRect(arrow()).left, c.left + 17);
  });

  testWidgets('descriptionLines clamps the description with an ellipsis; null shows it all', (tester) async {
    const long = 'A nurse comes to your home for injections, dressings, blood tests and checks, any day of the week.';
    RenderParagraph desc() => tester.renderObject<RenderParagraph>(find.descendant(of: find.text(long), matching: find.byType(RichText)));
    await pumpUi(tester, SizedBox(width: 200, child: tile(onPressed: () {}, description: long)));
    expect([desc().maxLines, desc().overflow], [2, TextOverflow.ellipsis]);
    expect(desc().didExceedMaxLines, isTrue);
    final lineH = uiThemeTokens[UiThemeName.dark]!.fontSizeSm * 1.4;
    expect(desc().size.height, closeTo(2 * lineH, 1));
    await pumpUi(tester, SizedBox(width: 200, child: tile(onPressed: () {}, description: long, lines: null)));
    expect(desc().maxLines, isNull);
    expect(desc().size.height, greaterThan(3 * lineH));
  });

  BoxDecoration deco(WidgetTester tester, [Key key = const ValueKey('card')]) =>
      tester.widget<AnimatedContainer>(find.descendant(of: find.byKey(key), matching: find.byType(AnimatedContainer)).first).decoration! as BoxDecoration;

  testWidgets('tinted: a wash in the tone, no border, no shadow until hover', (tester) async {
    final t = uiThemeTokens[UiThemeName.dark]!;
    // A desktop: hover highlights follow the mouse there (on Android the focus manager is in touch mode).
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await pumpUi(tester, Padding(padding: const EdgeInsets.all(20), child: SizedBox(width: 340, child: tile(onPressed: () {}))));
    var d = deco(tester);
    expect((d.border! as Border).top.color.a, 0, reason: 'transparent border');
    expect(d.boxShadow, isEmpty);
    expect(d.gradient, isNull);
    expect(d.color, Color.lerp(Color.lerp(t.surface, t.text, 0.04), t.primary, 0.08));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('card'))));
    await tester.pumpAndSettle();
    d = deco(tester);
    expect(d.boxShadow, t.shadow2);
    expect((d.border! as Border).top.color.a, 0, reason: 'still no border on hover');
    await mouse.moveTo(const Offset(385, 830));
    await tester.pumpAndSettle();
    expect(deco(tester).boxShadow, isEmpty, reason: 'the shadow goes again');
    debugDefaultTargetPlatformOverride = null;
    // Brand: no gradient edge on the tinted surface. Standard keeps the 0.37 look.
    await pumpUi(tester, SizedBox(width: 340, child: tile(onPressed: () {}, tone: UiFeatureTone.brand)));
    expect(deco(tester).gradient, isNull);
    expect(deco(tester).color, Color.lerp(Color.lerp(t.surface, t.text, 0.04), t.primary, 0.08));
    await pumpUi(tester, SizedBox(width: 340, child: tile(onPressed: () {}, surface: UiFeatureSurface.standard)));
    expect((deco(tester).border! as Border).top.color, t.border);
    expect(deco(tester).boxShadow, t.shadow1);
  });

  // Every drawn text colour against the tinted fill, in every theme and tone; the badge icon at 3:1.
  testWidgets('tinted text and icons are AA on the wash in every theme and tone', (tester) async {
    double ratio(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
    }

    Color flat(Color c, Color on) => Color.alphaBlend(c, on);
    final fails = <String>[];
    for (final theme in UiThemeName.values) {
      for (final tone in UiFeatureTone.values) {
        await pumpUi(
          tester,
          SizedBox(
            width: 360,
            child: UiFeatureCard(
              key: const ValueKey('card'),
              icon: _icon,
              eyebrow: 'New',
              title: 'Find a doctor',
              description: 'See who is free today.',
              actionLabel: 'Book now',
              onPressed: () {},
              size: UiSize.sm,
              tone: tone,
              surface: UiFeatureSurface.tinted,
            ),
          ),
          theme: theme,
        );
        final fill = deco(tester).color!;
        for (final p in tester.renderObjectList<RenderParagraph>(find.descendant(of: find.byKey(const ValueKey('card')), matching: find.byType(RichText)))) {
          final r = ratio(flat(p.text.style!.color!, fill), fill);
          if (r < 4.5) fails.add('${theme.name}/${tone.name}: "${p.text.toPlainText()}" ${r.toStringAsFixed(2)}:1');
        }
        if (tone == UiFeatureTone.primary || tone == UiFeatureTone.brand) {
          final t = uiThemeTokens[theme]!;
          final badge = Color.lerp(t.surface, t.primary, 0.18)!;
          final r = ratio(t.primary, badge);
          if (r < 3) fails.add('${theme.name}/${tone.name}: badge icon ${r.toStringAsFixed(2)}:1');
        }
      }
      // The trailing arrow (a graphic): 3:1.
      await pumpUi(tester, SizedBox(width: 360, child: tile(onPressed: () {})), theme: theme);
      final c = tester.widget<UiIcon>(find.descendant(of: arrow(), matching: find.byType(UiIcon))).color!;
      final fill = deco(tester).color!;
      if (ratio(flat(c, fill), fill) < 3) fails.add('${theme.name}: arrow ${ratio(flat(c, fill), fill).toStringAsFixed(2)}:1');
    }
    expect(fails, isEmpty);
  });

  testWidgets('tinted tiles meet the tap target, label and contrast guidelines', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final handle = tester.ensureSemantics();
    for (final theme in [UiThemeName.light, UiThemeName.dark, UiThemeName.maldives, UiThemeName.maldivesDark]) {
      await pumpUi(
        tester,
        SizedBox(
          width: 360,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
              Expanded(child: tile(onPressed: () {}, key: const ValueKey('a'))),
              Expanded(child: tile(onPressed: () {}, key: const ValueKey('b'), tone: UiFeatureTone.accent, description: 'A nurse comes to you.')),
            ]),
          ),
        ),
        theme: theme,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }
    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('two tiles in an IntrinsicHeight row are the same height', (tester) async {
    await pumpUi(
      tester,
      SizedBox(
        width: 360,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
            Expanded(child: tile(onPressed: () {}, key: const ValueKey('a'), description: 'Short.')),
            Expanded(child: tile(onPressed: () {}, key: const ValueKey('b'), description: 'A much longer description that wraps to two lines.')),
          ]),
        ),
      ),
    );
    final a = tester.getSize(find.byKey(const ValueKey('a'))).height;
    expect(a, tester.getSize(find.byKey(const ValueKey('b'))).height);
    expect(tester.takeException(), isNull);
  });

  testWidgets("controlRadius: the card and badge take a text field's radius; square when corners are off", (tester) async {
    final t = uiThemeTokens[UiThemeName.maldives]!;
    Future<void> pump({bool? radius, UiConfig config = const UiConfig()}) async {
      tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(
        theme: UiThemeName.maldives,
        config: config,
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 340,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const UiInput(key: ValueKey('field'), placeholder: 'Ask', semanticLabel: 'Ask'),
              tile(onPressed: () {}, radius: radius),
            ]),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    BorderRadius fieldRadius() =>
        (tester.widget<AnimatedContainer>(find.descendant(of: find.byKey(const ValueKey('field')), matching: find.byType(AnimatedContainer)).first).decoration! as BoxDecoration)
            .borderRadius! as BorderRadius;
    BorderRadius badgeRadius() => (tester.widget<Container>(_badge).decoration! as BoxDecoration).borderRadius! as BorderRadius;

    await pump();
    expect(fieldRadius(), BorderRadius.circular(t.radius));
    expect(deco(tester).borderRadius, fieldRadius());
    expect(badgeRadius(), fieldRadius());
    await pump(radius: false);
    expect(deco(tester).borderRadius, BorderRadius.zero);
    await pump(config: const UiConfig(radius: false));
    expect(fieldRadius(), BorderRadius.zero);
    expect(deco(tester).borderRadius, BorderRadius.zero);
    expect(badgeRadius(), BorderRadius.zero);
  });

  // English in RTL would show its full stop at the start, so the RTL golden drops it.
  Widget startScreen(BuildContext context, {double width = 358, String end = '.'}) => SizedBox(
        width: width,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
          const UiInput(placeholder: 'Describe how you feel', semanticLabel: 'Ask'),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
              Expanded(
                child: UiFeatureCard(
                  icon: const UiIcon(HugeIcons.strokeRoundedStethoscope),
                  title: 'Find a doctor',
                  description: 'Book a clinic visit near you$end',
                  size: UiSize.sm,
                  surface: UiFeatureSurface.tinted,
                  controlRadius: true,
                  trailingArrow: true,
                  descriptionLines: 2,
                  onPressed: () {},
                ),
              ),
              Expanded(
                child: UiFeatureCard(
                  icon: const UiIcon(HugeIcons.strokeRoundedAmbulance),
                  title: 'Nurse at home',
                  description: 'A nurse comes to you$end',
                  tone: UiFeatureTone.accent,
                  size: UiSize.sm,
                  surface: UiFeatureSurface.tinted,
                  controlRadius: true,
                  trailingArrow: true,
                  descriptionLines: 2,
                  onPressed: () {},
                ),
              ),
            ]),
          ),
        ]),
      );

  testWidgets('golden: compact tinted tiles under a field (phone, LTR)', (tester) async {
    await expectThemedGolden(
      tester,
      'feature_card_compact',
      (context) => Align(alignment: Alignment.topLeft, child: startScreen(context)),
      themes: const [UiThemeName.dark, UiThemeName.light, UiThemeName.maldives, UiThemeName.maldivesDark],
      height: 260,
    );
  });

  testWidgets('golden: compact tinted tiles under a field (phone, RTL)', (tester) async {
    await expectThemedGolden(
      tester,
      'feature_card_compact_rtl',
      (context) => Directionality(textDirection: TextDirection.rtl, child: Align(alignment: Alignment.topRight, child: startScreen(context, end: ''))),
      themes: const [UiThemeName.dark, UiThemeName.light, UiThemeName.maldives, UiThemeName.maldivesDark],
      height: 260,
    );
  });

  testWidgets('golden: compact tinted tiles under a field (desktop, 640 wide)', (tester) async {
    await expectThemedGolden(
      tester,
      'feature_card_compact_wide',
      (context) => Align(alignment: Alignment.topLeft, child: startScreen(context, width: 640)),
      themes: const [UiThemeName.light, UiThemeName.maldivesDark],
      width: 672,
      height: 230,
    );
  });
}
