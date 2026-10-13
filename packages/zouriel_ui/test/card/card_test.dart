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
