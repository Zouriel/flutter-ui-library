import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/bits.dart';
import 'package:zouriel_ui/src/workflow/editors.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

void main() {
  testWidgets('a rule is one column: the value and Remove, how to compare, then what to compare with before the value', (tester) async {
    const tokens = [UiWfToken(path: 'entity.amount', label: 'Amount', group: 'Application', type: 'number')];
    await pumpUi(
      tester,
      SizedBox(
        width: 296,
        child: WfRuleEditor(
          rule: UiWfCondition.fromJson({'ref': 'entity.amount', 'op': 'gt', 'value': {'const': 5000}}),
          tokens: tokens,
          onChanged: (_) {},
          onRemove: () {},
        ),
      ),
    );
    Rect at(String label) => tester.getRect(find.byWidgetPredicate((w) => w is WfSelect && w.label == label));
    final ref = tester.getRect(find.byType(WfTokenSelect).first);
    expect(at('How to compare').top, greaterThan(ref.bottom - 1));
    expect(at('How to compare').left, ref.left);
    expect(at('How to compare').right, closeTo(ref.right, 0.5), reason: 'the rows under the value stop at its right edge');
    final mode = at('Compare with');
    expect(mode.top, greaterThan(at('How to compare').bottom - 1));
    final value = tester.getRect(find.byType(WfValueInput));
    expect(mode.right, lessThan(value.left), reason: 'what to compare with comes before the value it switches');
  });

  testWidgets('the state badge has UiBadge metrics', (tester) async {
    await pumpUi(tester, const UiWorkflowStateBadge(label: 'Draft'));
    expect(tester.getSize(find.byType(UiWorkflowStateBadge)).height, 20);
  });

  testWidgets('a pair with one field gives it the whole row', (tester) async {
    await pumpUi(tester, const SizedBox(width: 320, child: WfPair(children: [SizedBox(key: Key('a'), height: 10)])));
    expect(tester.getSize(find.byKey(const Key('a'))).width, 320);
  });
}
