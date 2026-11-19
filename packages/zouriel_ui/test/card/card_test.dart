import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

void main() {
  testWidgets('a tappable card is one labelled button', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pumpUi(tester, UiCard(onTap: () => taps++, semanticLabel: 'Open report', child: const UiText('Report')));
    await tester.tap(find.text('Report'));
    expect(taps, 1);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('children, gap, align and enabled lay out body and respect disabled state', (tester) async {
    var taps = 0;
    await pumpUi(tester, SizedBox(
      width: 180,
      child: Column(spacing: 12, children: [
        UiCard(
          padding: UiSize.sm,
          gap: 2,
          align: UiStackAlign.center,
          onTap: () => taps++,
          semanticLabel: 'Aisha, 12 photos',
          children: const [
            UiText('Aisha', variant: UiTextVariant.label),
            UiText('12 photos', variant: UiTextVariant.caption),
          ],
        ),
        UiCard(
          onTap: () => taps++,
          enabled: false,
          semanticLabel: 'Disabled card',
          child: const UiText('Disabled'),
        ),
      ]),
    ));
    final t = tester.element(find.text('Aisha')).ui;
    final aishaRect = tester.getRect(find.text('Aisha'));
    final countRect = tester.getRect(find.text('12 photos'));
    expect(countRect.top - aishaRect.bottom, closeTo(t.space2, 0.5));
    expect((aishaRect.center.dx - countRect.center.dx).abs(), lessThan(1.0));

    await tester.tap(find.text('Aisha'));
    expect(taps, 1);

    await tester.tap(find.text('Disabled'));
    expect(taps, 1);
    final op = tester.widget<Opacity>(find.ancestor(of: find.text('Disabled'), matching: find.byType(Opacity)).first);
    expect(op.opacity, 0.5);
  });

  testWidgets('golden: interactive face cards with children, gap, align and disabled', (tester) async {
    await expectThemedGolden(tester, 'card_layout_interactive', height: 210, (context) => Row(
      spacing: 12,
      children: [
        Expanded(
          child: UiCard(
            padding: UiSize.sm,
            gap: 1,
            align: UiStackAlign.center,
            onTap: () {},
            semanticLabel: 'Aisha Ibrahim, 24 photos',
            children: const [
              UiAvatar(name: 'Aisha Ibrahim', dimension: 64),
              UiText('Aisha Ibrahim', variant: UiTextVariant.label, truncate: true),
              UiText('24 photos', variant: UiTextVariant.caption),
            ],
          ),
        ),
        Expanded(
          child: UiCard(
            padding: UiSize.sm,
            gap: 1,
            align: UiStackAlign.center,
            onTap: () {},
            enabled: false,
            semanticLabel: 'Ali Zahir, 8 photos',
            children: const [
              UiAvatar(name: 'Ali Zahir', dimension: 64),
              UiText('Ali Zahir', variant: UiTextVariant.label, truncate: true),
              UiText('8 photos', variant: UiTextVariant.caption),
            ],
          ),
        ),
      ],
    ));
  });

  testWidgets('a vertical divider fills its row; a horizontal one fills the width', (tester) async {
    await pumpUi(tester, const SizedBox(width: 200, child: Column(children: [
      SizedBox(height: 30, child: Row(children: [UiText('a'), UiDivider(axis: Axis.vertical), UiText('b')])),
      UiDivider(),
    ])));
    final rules = find.descendant(of: find.byType(UiDivider), matching: find.byType(ColoredBox));
    expect(tester.getSize(rules.first), const Size(1, 30));
    expect(tester.getSize(rules.last), const Size(200, 1));
  });

  testWidgets('golden: card with header and footer, dividers', (tester) async {
    await expectThemedGolden(tester, 'card_divider', height: 330, (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          header: const UiText('Monthly report', variant: UiTextVariant.h4),
          footer: Row(mainAxisAlignment: MainAxisAlignment.end, children: [UiButton(label: 'Open', size: UiSize.sm, onPressed: () {})]),
          child: const UiText('Revenue grew 12% on last month.'),
        ),
        const UiDivider(),
        const UiDivider(label: 'or'),
        const SizedBox(height: 24, child: Row(children: [UiText('Left'), UiDivider(axis: Axis.vertical), UiText('Right')])),
      ],
    ));
  });
}
