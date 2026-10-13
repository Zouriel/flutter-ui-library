import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../form_renderer/fakes.dart';

void main() {
  test('a shared fixture loads into the builder and comes back unchanged, also after edit + undo', () {
    final raw = fixture('scholarship.definition.json')! as Map;
    final expected = jsonEncode(migrateDefinition(raw).toJson());
    final c = UiFormBuilderController(definition: UiFormDefinition.fromJson(raw));
    expect(jsonEncode(c.def.toJson()), expected);
    final first = c.def.pages[0].elements.first.id;
    c.updateField(first, (f) => f.label = 'Changed');
    c.duplicate(first);
    c.nudge(first, 1);
    c.addPage();
    c.undo();
    c.undo();
    c.undo();
    c.undo();
    expect(jsonEncode(c.def.toJson()), expected);
    // With the lists the sample uses, nothing needs fixing.
    c.optionSourceDefs = [peopleSource().def, coursesSource];
    expect(c.problems.where((p) => p.severity == 'error'), isEmpty);
  });

  test('a form built in Flutter is the web JSON: it migrates unchanged, lints clean and runs in the engine', () {
    final c = UiFormBuilderController(definition: createDefinition(title: 'Membership'));
    final page = c.def.pages[0].id;

    // A yes/no question, a text question shown only when it's ticked, and a required email.
    final member = createField(UiFbFieldType.toggle, def: c.def, label: 'Already a member?');
    c.add(member, UiFbDropTarget(containerId: page, index: 0));
    final number = createField(UiFbFieldType.text, def: c.def, label: 'Membership number');
    c.add(number);
    c.updateAny(number.id, (el) => el.visibility = UiFbVisibility(action: 'show', when: UiFbConditionRule(ref: member.id, op: UiFbOperator.isTrue)));
    final email = createField(UiFbFieldType.email, def: c.def, label: 'Email');
    c.add(email);
    c.updateField(email.id, (f) => f.required = UiFbToggle.flag(true));

    // A repeating section with a number inside, and a total of it outside.
    final kids = createGroup(def: c.def, repeat: true);
    c.select(null);
    c.add(kids);
    c.setGroupTitle(kids.id, 'Children');
    final age = createField(UiFbFieldType.number, def: c.def, label: 'Age');
    c.add(age, UiFbDropTarget(containerId: kids.id, index: 0));
    final total = createField(UiFbFieldType.calculated, def: c.def, label: 'Total age');
    c.add(total, UiFbDropTarget(containerId: page, index: c.page.elements.length));
    c.updateField(total.id, (f) => f.calc = UiFbCalc(op: UiFbCalcOp.sum, args: [UiFbCalcRefArg(age.id)]));

    // A second page, skipped for members.
    c.addPage();
    final p2 = c.def.pages[1].id;
    c.add(createField(UiFbFieldType.textarea, def: c.def, label: 'Why join?'), UiFbDropTarget(containerId: p2, index: 0));
    c.updatePage(p2, (p) => p.visibility = UiFbVisibility(action: 'hide', when: UiFbConditionRule(ref: member.id, op: UiFbOperator.isTrue)));

    final json = c.def.toJson();
    // Through text and back, as the host stores it.
    final stored = jsonDecode(jsonEncode(json)) as Map;
    expect(jsonEncode(migrateDefinition(stored).toJson()), jsonEncode(json));
    expect(lintDefinition(c.def).where((p) => p.severity == 'error'), isEmpty);

    // The shape is the web's: keys, a repeat with a key, a calc, rules by id.
    final els = (json['pages']! as List)[0]['elements'] as List;
    expect([for (final e in els) (e as Map)['key']], ['already_a_member', 'membership_number', 'email', 'children', 'total_age']);
    expect((els[1] as Map)['visibility'], {
      'action': 'show',
      'when': {'ref': member.id, 'op': 'isTrue'},
    });
    expect((els[3] as Map)['repeat'], {'min': 1, 'addLabel': 'Add another', 'itemLabel': 'Entry {n}'});
    expect((els[4] as Map)['calc'], {
      'op': 'sum',
      'args': [
        {'ref': age.id},
      ],
    });
    expect((json['pages']! as List)[0]['title'], 'Page 1');

    // And the engine runs it.
    final engine = UiFormEngine(definition: UiFormDefinition.fromJson(stored), today: () => '2026-10-14');
    expect(engine.instanceState(number.id, null).visible, isFalse);
    engine.setValue(member.id, null, true);
    expect(engine.instanceState(number.id, null).visible, isTrue);
    engine.setValue(number.id, null, 'M-100');
    engine.setValue(email.id, null, 'a@b.mv');
    final row = engine.rows(kids.id).first;
    engine.setValue(age.id, row, 7);
    expect(engine.instanceState(total.id, null).value, 7);
    final data = engine.data;
    expect(data['already_a_member'], true);
    expect(data['membership_number'], 'M-100');
    expect(data['children'], [
      {'age': 7},
    ]);
    engine.dispose();
  });
}
