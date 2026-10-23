import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

// Density (0.45.0): compact makes things smaller, not tighter. The web twin is
// projects/ui/src/lib/density.spec.ts plus the browser check audit/density.mjs.

Future<void> _pump(WidgetTester tester, UiDensity density, Widget child, {double width = 390}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = Size(width, 844) * 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(config: UiConfig(density: density), home: Align(alignment: Alignment.topLeft, child: child)));
  await tester.pumpAndSettle();
}

UiThemeData _theme(WidgetTester tester, Finder f) => UiTheme.of(tester.element(f));

/// The painted heights of the decorated boxes inside [f] (the visual control, not its 48dp target).
Set<double> _boxHeights(WidgetTester tester, Finder f) => {
      for (final e in find.descendant(of: f, matching: find.byType(DecoratedBox)).evaluate())
        (e.renderObject! as RenderBox).size.height,
    };

const _probe = Key('probe');

Widget _sample() => Column(
      key: _probe,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UiButton(label: 'Book', onPressed: () {}),
        const UiIcon(HugeIcons.strokeRoundedNotification01),
        UiSwitch(value: true, label: 'Notify', onChanged: (_) {}),
        UiCheckbox(value: true, label: 'Remember', onChanged: (_) {}),
      ],
    );

void main() {
  test('comfortable, the default, keeps every size as it was', () {
    expect(const UiConfig().density, UiDensity.comfortable);
    final d = UiThemeData(name: UiThemeName.dark);
    expect(d.compact, isFalse);
    final t = d.tokens;
    expect([t.fontSizeSm, t.fontSizeMd, t.fontSizeLg], [13, 15, 18]);
    expect([t.fontSizeH1, t.fontSizeH2, t.fontSizeH3, t.fontSizeH5, t.fontSizeH6], [40, 30, 22, 16, 14.4]);
    expect([t.sizeSm, t.sizeMd, t.sizeLg, t.sizeXl], [26, 30, 38, 56]);
    expect([t.fontScale, t.densityScale], [1, 1]);
    expect([d.typography.h1.fontSize, d.typography.h3.fontSize, d.typography.body.fontSize], [40, 22, 15]);
  });

  test('compact: type one step smaller, headings about 10% smaller, controls lower', () {
    for (final name in UiThemeName.values) {
      final c = UiThemeData(name: name, config: const UiConfig(density: UiDensity.compact));
      final base = uiThemeTokens[name]!;
      final t = c.tokens;
      expect(c.compact, isTrue);
      expect([t.fontSizeSm, t.fontSizeMd, t.fontSizeLg], [12, 14, 16], reason: '$name');
      for (final (a, b) in [(t.fontSizeH1, base.fontSizeH1), (t.fontSizeH2, base.fontSizeH2), (t.fontSizeH3, base.fontSizeH3), (t.fontSizeH5, base.fontSizeH5), (t.fontSizeH6, base.fontSizeH6)]) {
        expect(a / b, inInclusiveRange(0.88, 0.94), reason: '$name $a/$b');
      }
      expect([t.sizeSm, t.sizeMd, t.sizeLg], [24, base.sizeMd - 4, base.sizeLg - 4]);
      expect(t.fontScale, 0.93);
      expect(t.densityScale, 0.9);
      expect(c.typography.body.fontSize, 14);
      expect(c.typography.h3.fontSize, 20);
    }
  });

  test('compact changes sizes only: spacing, radii, the xl size and the colours stay', () {
    final base = uiThemeTokens[UiThemeName.maldives]!;
    final t = base.withCompactDensity();
    expect([t.space1, t.space2, t.space3, t.space4, t.space6, t.space8, t.space12, t.space20],
        [base.space1, base.space2, base.space3, base.space4, base.space6, base.space8, base.space12, base.space20]);
    expect([t.radius, t.radiusXs, t.radiusSm, t.radiusLg, t.radiusPill], [base.radius, base.radiusXs, base.radiusSm, base.radiusLg, base.radiusPill]);
    expect(t.sizeXl, base.sizeXl);
    expect(t.sizeTouch, base.sizeTouch);
    expect(t.primary, base.primary);
    expect(uiCompactDensityTokens.keys.where((k) => RegExp(r'^--ui-(space-|radius|size-touch|size-xl)').hasMatch(k)), isEmpty);
  });

  testWidgets('compact draws icons, the switch and the checkbox 10% smaller and buttons 26 high', (tester) async {
    await _pump(tester, UiDensity.comfortable, _sample());
    expect(tester.getSize(find.byType(UiIcon)), const Size(20, 20));
    expect(_boxHeights(tester, find.byType(UiButton)), contains(30.0));

    await _pump(tester, UiDensity.compact, _sample());
    expect(tester.getSize(find.byType(UiIcon)).width, closeTo(18, 0.001));
    expect(_boxHeights(tester, find.byType(UiButton)), contains(26.0));
    expect(_boxHeights(tester, find.byType(UiSwitch)), contains(closeTo(22 * 0.9, 0.001)));
    expect(_boxHeights(tester, find.byType(UiCheckbox)), contains(closeTo(18 * 0.9, 0.001)));
  });

  testWidgets('compact keeps every tap target at least 48dp', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, UiDensity.compact, _sample());
    expect(tester.getSize(find.byType(UiButton)).height, greaterThanOrEqualTo(48));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('auto is compact below 600 wide and follows resizes', (tester) async {
    await _pump(tester, UiDensity.auto, _sample(), width: 599);
    expect(_theme(tester, find.byKey(_probe)).compact, isTrue);
    expect(_theme(tester, find.byKey(_probe)).tokens.fontSizeMd, 14);

    tester.view.physicalSize = const Size(600, 844) * 2;
    await tester.pumpAndSettle();
    expect(_theme(tester, find.byKey(_probe)).compact, isFalse);
    expect(_theme(tester, find.byKey(_probe)).tokens.fontSizeMd, 15);

    tester.view.physicalSize = const Size(599, 844) * 2;
    await tester.pumpAndSettle();
    expect(_theme(tester, find.byKey(_probe)).compact, isTrue);
    expect(UiDensity.auto.isCompactAt(599.9), isTrue);
    expect(UiDensity.auto.isCompactAt(uiCompactBelow), isFalse);
  });

  testWidgets('a controller switches density at runtime', (tester) async {
    final c = UiThemeController();
    addTearDown(c.dispose);
    await tester.pumpWidget(UiApp(controller: c, home: _sample()));
    await tester.pumpAndSettle();
    expect(_theme(tester, find.byKey(_probe)).compact, isFalse);
    c.setConfig(c.config.copyWith(density: UiDensity.compact));
    await tester.pumpAndSettle();
    expect(_theme(tester, find.byKey(_probe)).compact, isTrue);
    expect(tester.getSize(find.byType(UiIcon)).width, closeTo(18, 0.001));
  });

  testWidgets('UiDensityScope draws one subtree compact; theme islands keep the density', (tester) async {
    await _pump(
      tester,
      UiDensity.comfortable,
      Column(children: [
        const UiIcon(HugeIcons.strokeRoundedHome01, key: Key('outside')),
        UiDensityScope(
          density: UiDensity.compact,
          child: UiThemeScope(theme: UiThemeName.light, child: const UiIcon(HugeIcons.strokeRoundedHome01, key: Key('inside'))),
        ),
      ]),
    );
    expect(tester.getSize(find.byKey(const Key('outside'))).width, 20);
    expect(tester.getSize(find.byKey(const Key('inside'))).width, closeTo(18, 0.001));
    expect(_theme(tester, find.byKey(const Key('inside'))).name, UiThemeName.light);
  });

  testWidgets('golden: comfortable and compact side by side', (tester) async {
    Widget sample(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            const UiText('Find a nurse', variant: UiTextVariant.h3),
            const UiText('Body text, inputs, chips and buttons follow the density.'),
            const UiInput(placeholder: 'Search an island'),
            const Row(spacing: 8, children: [UiChip(label: 'Home visit'), UiChip(label: 'Today'), UiAvatar(name: 'Aisha Rasheed'), UiIcon(HugeIcons.strokeRoundedNotification01)]),
            Row(spacing: 12, children: [
              UiSwitch(value: true, label: 'Notify me', onChanged: (_) {}),
              UiCheckbox(value: true, label: 'Remember', onChanged: (_) {}),
            ]),
            Row(spacing: 12, children: [
              UiButton(label: 'Book', variant: UiButtonVariant.primary, onPressed: () {}),
              UiButton(label: 'Later', variant: UiButtonVariant.outline, onPressed: () {}),
            ]),
          ],
        );
    await expectThemedGolden(
      tester,
      'density_comfortable_compact',
      height: 380,
      (context) => Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 16, children: [
        Expanded(child: Builder(builder: sample)),
        Expanded(child: UiDensityScope(density: UiDensity.compact, child: Builder(builder: sample))),
      ]),
      width: 640,
    );
  });
}
