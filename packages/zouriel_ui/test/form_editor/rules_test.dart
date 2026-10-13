import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import 'support.dart';

/// Holds a condition the way the inspector does, writing back whatever the editor emits.
class RuleHost extends StatefulWidget {
  const RuleHost({super.key, this.initial, this.forId});
  final UiFbCondition? initial;
  final String? forId;
  @override
  State<RuleHost> createState() => RuleHostState();
}

class RuleHostState extends State<RuleHost> {
  late UiFbCondition? value = widget.initial;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: UiFbConditionEditor(condition: value, forId: widget.forId, onChanged: (c) => setState(() => value = c)),
    ),
  );
}

final def = formOf([
  fj('country', 'radio', {
    'label': 'Country',
    'options': [
      {'id': 'o1', 'value': 'mv', 'label': 'Maldives'},
      {'id': 'o2', 'value': 'lk', 'label': 'Sri Lanka'},
    ],
  }),
  fj('age', 'number', {'label': 'Age'}),
  fj('start', 'date', {'label': 'Start'}),
  fj('end', 'date', {'label': 'End'}),
  fj('me', 'text', {'label': 'Me'}),
]);

Future<(RuleHostState, UiFormBuilderController)> pumpRules(WidgetTester tester, {UiFbCondition? initial, String forId = 'me'}) async {
  final c = UiFormBuilderController(definition: def);
  tester.view.physicalSize = const Size(390, 1400) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(home: UiFbBuilderScope(controller: c, child: RuleHost(initial: initial, forId: forId))));
  await tester.pumpAndSettle();
  return (tester.state<RuleHostState>(find.byType(RuleHost)), c);
}

void main() {
  testWidgets('builds a rule as a sentence: question, comparison, value', (tester) async {
    final (h, c) = await pumpRules(tester);
    expect(find.text('Add a group of rules'), findsNothing, reason: 'nothing to group yet');
    await tapText(tester, 'Add rule');
    // Starts on the first question it may ask about, with its first comparison.
    expect(h.value!.toJson(), {'ref': 'country', 'op': 'eq'});
    await choose(tester, select('Value'), 'Sri Lanka');
    expect(h.value!.toJson(), {'ref': 'country', 'op': 'eq', 'value': {'const': 'lk'}});
    expect(c.describe(h.value), '“Country” is Sri Lanka');
    // A comparison of the same shape keeps the value.
    await choose(tester, select('Comparison'), 'is not');
    expect(h.value!.toJson(), {'ref': 'country', 'op': 'neq', 'value': {'const': 'lk'}});
    // Another question resets the comparison to one it supports.
    await choose(tester, select('Question'), 'Age');
    expect(h.value!.toJson(), {'ref': 'age', 'op': 'eq'});
    await choose(tester, select('Comparison'), 'is between');
    final boxes = find.descendant(of: find.byType(UiNumberInput), matching: find.byType(EditableText));
    await tester.enterText(boxes.at(0), '18');
    await tester.enterText(boxes.at(1), '30');
    await tester.pumpAndSettle();
    expect(h.value!.toJson(), {'ref': 'age', 'op': 'between', 'value': {'const': 18}, 'value2': {'const': 30}});
    expect(c.describe(h.value), '“Age” is between 18 and 30');
  });

  testWidgets('combines rules with all/any/none and one level of groups', (tester) async {
    final (h, c) = await pumpRules(tester, initial: UiFbCondition.fromJson({'ref': 'age', 'op': 'gte', 'value': {'const': 18}}));
    await tapText(tester, 'Add rule');
    // A second rule starts from the question asked about last.
    expect(h.value!.toJson(), {
      'match': 'all',
      'conditions': [
        {'ref': 'age', 'op': 'gte', 'value': {'const': 18}},
        {'ref': 'age', 'op': 'eq'},
      ],
    });
    await choose(tester, select('How to combine these rules'), 'Any of these');
    expect((h.value! as UiFbConditionGroup).match, 'any');
    expect(find.text('OR'), findsOneWidget);
    await tapText(tester, 'Add a group of rules');
    final g = h.value! as UiFbConditionGroup;
    expect(g.conditions.last.toJson(), {
      'match': 'any',
      'conditions': [
        {'ref': 'country', 'op': 'eq'},
      ],
    });
    expect(find.text('Add a group of rules'), findsOneWidget, reason: 'only the top level offers groups');
    // Removing the group and a rule leaves one rule; only an "all" group of one is unwrapped.
    await tester.tap(find.byWidgetPredicate((w) => w is UiIconButton && w.label == 'Remove this group'));
    await tester.pumpAndSettle();
    expect(find.byType(UiFbConditionEditor), findsOneWidget);
    await choose(tester, select('How to combine these rules'), 'All of these');
    await tester.tap(find.byWidgetPredicate((w) => w is UiIconButton && w.label == 'Remove this rule').last);
    await tester.pumpAndSettle();
    expect(h.value!.toJson(), {'ref': 'age', 'op': 'gte', 'value': {'const': 18}});
    expect(c.describe(h.value), '“Age” is at least 18');
  });

  testWidgets('dates compare with a value, another answer, or today ± days', (tester) async {
    final (h, _) = await pumpRules(tester, initial: UiFbCondition.fromJson({'ref': 'end', 'op': 'after'}));
    await choose(tester, select('Compare with'), 'another answer');
    await choose(tester, select('Other answer'), 'Start');
    expect(h.value!.toJson(), {'ref': 'end', 'op': 'after', 'value': {'ref': 'start'}});
    await choose(tester, select('Compare with'), 'a date from today');
    await tester.enterText(find.descendant(of: find.byType(UiNumberInput), matching: find.byType(EditableText)), '7');
    await tester.pumpAndSettle();
    expect(h.value!.toJson(), {'ref': 'end', 'op': 'after', 'value': {'today': 7}});
    expect(find.text('0 is today, 7 is a week from now, -7 a week ago.'), findsOneWidget);
  });

  testWidgets('never offers the rule’s own question, and says so when there is nothing to ask about', (tester) async {
    await pumpRules(tester, forId: 'age');
    await tapText(tester, 'Add rule');
    await tester.tap(select('Question'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(UiListboxPanel), matching: find.text('Age')), findsNothing);
    expect(find.descendant(of: find.byType(UiListboxPanel), matching: find.text('Country')), findsOneWidget);
  });

  testWidgets('an empty form explains that rules need other questions', (tester) async {
    final c = UiFormBuilderController(definition: formOf([fj('only', 'text')]));
    await tester.pumpWidget(UiApp(home: UiFbBuilderScope(controller: c, child: const RuleHost(forId: 'only'))));
    await tester.pumpAndSettle();
    expect(find.text('Add other questions to the form first. Rules compare with other answers.'), findsOneWidget);
  });
}
