// Behaviour the shared fixtures can't express in JSON: app-registered (async) checks, listeners,
// picked files, the definition editing helpers that mint ids, and the JS value semantics the
// port relies on.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/areas/form_engine.dart';
import 'package:zouriel_ui/src/form_builder/engine/js.dart';

UiFbField f(String id, UiFbFieldType type, {String? label, UiFbToggle? required, List<UiFbValidatorRule>? validators}) =>
    UiFbField(id: id, type: type, key: id, label: label ?? id.toUpperCase(), required: required, validators: validators);

UiFormDefinition form(List<UiFbElement> elements) => UiFormDefinition(id: 'form1', title: 'T', revision: 3, pages: [UiFbPage(id: 'p1', elements: elements)]);

Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  group('app-registered checks', () {
    test('an async check blocks while pending, then shows its message', () async {
      final taken = UiFbValidatorDef(type: 'usernameFree', label: 'Username is free', defaultMessage: 'That username is taken.', validate: (v, p, c) async => v != 'admin');
      final e = UiFormEngine(
        definition: form([f('user', UiFbFieldType.text, validators: [UiFbValidatorRule(id: 'v', type: 'usernameFree')])]),
        validators: [taken],
        today: () => '2026-10-11',
      );
      var notified = 0;
      e.addListener(() => notified++);
      e.setValue('user', null, 'admin');
      expect(e.instanceState('user', null).pending, isTrue);
      expect(e.submit(), isNull);
      // Discovered to be async on first run, then debounced 400ms.
      await wait(500);
      final st = e.instanceState('user', null);
      expect(st.pending, isFalse);
      expect(st.errors, ['That username is taken.']);
      expect(notified, greaterThan(1));
      e.setValue('user', null, 'ada');
      expect(e.instanceState('user', null).pending, isTrue);
      await wait(500);
      expect(e.instanceState('user', null).errors, isEmpty);
      expect(e.submit(), isNotNull);
      e.dispose();
    });

    test('debounced checks: only the newest answer is checked; a crash never blocks', () async {
      final asked = <Object?>[];
      final def = UiFbValidatorDef(
        type: 'remote', label: 'Remote', defaultMessage: '{label} is not {thing}.', debounceMs: 30, //
        validate: (v, p, c) {
          asked.add(v);
          if (v == 'boom') throw StateError('server down');
          return Future.value(v == 'ok');
        },
      );
      final e = UiFormEngine(
        definition: form([f('code', UiFbFieldType.text, validators: [UiFbValidatorRule(id: 'v', type: 'remote', params: {'thing': 'known'})])]),
        validators: [def],
      );
      e.setValue('code', null, 'a');
      e.setValue('code', null, 'ab');
      e.setValue('code', null, 'abc');
      await wait(80);
      expect(asked, ['abc']);
      expect(e.instanceState('code', null).errors, ['CODE is not known.']);
      e.setValue('code', null, 'boom');
      await wait(80);
      expect(e.instanceState('code', null).pending, isFalse);
      expect(e.instanceState('code', null).errors, isEmpty);
      e.dispose();
    });

    test('a sync app check runs like the built-ins, and a throwing one passes', () {
      final even = UiFbValidatorDef(type: 'even', label: 'Even', defaultMessage: '{label} must be even.', valueKinds: const [UiFbValueKind.number], validate: (v, p, c) => (v as num) % 2 == 0);
      final broken = UiFbValidatorDef(type: 'broken', label: 'Broken', defaultMessage: 'x', validate: (v, p, c) => throw StateError('bug'));
      final e = UiFormEngine(
        definition: form([f('n', UiFbFieldType.number, validators: [UiFbValidatorRule(id: 'a', type: 'even'), UiFbValidatorRule(id: 'b', type: 'broken')])]),
        validators: [even, broken],
      );
      e.setValue('n', null, 3);
      expect(e.instanceState('n', null).errors, ['N must be even.']);
      expect(validatorsFor(UiFbFieldType.number, null, [...uiFbBuiltinValidators, even]).map((d) => d.type), contains('even'));
      e.dispose();
    });
  });

  group('engine plumbing', () {
    test('listeners hear every change and can stop listening', () {
      final e = UiFormEngine(definition: form([f('a', UiFbFieldType.text)]));
      var n = 0;
      void listener() => n++;
      e.addListener(listener);
      e.setValue('a', null, 'x');
      e.markTouched('a', null);
      e.markTouched('a', null);
      expect(n, 2);
      e.removeListener(listener);
      e.setValue('a', null, 'y');
      expect(n, 2);
    });

    test('picked files are kept for the submission under their data path', () {
      final e = UiFormEngine(
        definition: form([
          UiFbGroup(id: 'g', key: 'docs', repeat: UiFbRepeat(min: 1), elements: [f('file', UiFbFieldType.file)]),
        ]),
        now: () => DateTime.utc(2026, 10, 13, 9, 30, 0, 123, 456),
      );
      final row = e.rows('g').first;
      final handle = Object();
      e.setFiles('file', row, [UiFbPickedFile(name: 'cv.pdf', size: 1200, type: 'application/pdf', handle: handle)]);
      expect(e.rawValue('file', row), [{'name': 'cv.pdf', 'size': 1200, 'type': 'application/pdf'}]);
      final s = e.submit()!;
      expect(s.submittedAt, '2026-10-13T09:30:00.123Z');
      expect(s.files.keys, ['docs[0].file']);
      expect(identical(s.files['docs[0].file']!.single.handle, handle), isTrue);
      expect(s.data, {'docs': [{'file': [{'name': 'cv.pdf', 'size': 1200, 'type': 'application/pdf'}]}]});
      // Files the host already uploaded carry their URL and need no handover.
      e.setFiles('file', row, const [], uploaded: const [UiFbFileValue(name: 'cv.pdf', size: 1200, type: 'application/pdf', url: 'https://x.test/cv.pdf')]);
      expect(e.submit()!.files, isEmpty);
    });

    test('restoring a removed entry puts it back where it was, answers and all', () {
      final e = UiFormEngine(definition: form([UiFbGroup(id: 'g', key: 'g', repeat: UiFbRepeat(min: 0), elements: [f('a', UiFbFieldType.text)])]));
      final r2 = e.addRow('g')!;
      e.addRow('g');
      e.setValue('a', r2, 'second');
      final removed = e.removeRow('g', r2)!;
      expect(e.rows('g').length, 2);
      e.restoreRow(removed);
      expect(e.rows('g')[1], r2);
      expect(e.rawValue('a', r2), 'second');
    });

    test('the engine works on its own copy of the definition', () {
      final d = form([f('a', UiFbFieldType.text)]);
      final e = UiFormEngine(definition: d);
      d.pages.first.elements.clear();
      expect(e.instancesOn(0).map((i) => i.id), ['a']);
    });
  });

  group('editing definitions', () {
    test('new elements get fresh ids, unique keys and their type’s defaults', () {
      var d = createDefinition(title: 'Test');
      expect(d.settings!.toJson(), isEmpty);
      final a = createField(UiFbFieldType.text, def: d, label: 'First name');
      d = insertElement(d, a, UiFbDropTarget(containerId: d.pages[0].id, index: 0));
      final b = createField(UiFbFieldType.text, def: d, label: 'First name');
      expect(a.key, 'first_name');
      expect(b.key, 'first_name_2');
      expect(a.id, isNot(b.id));
      expect(a.id, matches(RegExp(r'^fld_[0-9a-z]{4}[0-9a-z]{2}[0-9a-z]{5}$')));
      final money = createField(UiFbFieldType.currency);
      expect(money.props!.toJson(), {'decimals': 2, 'currency': 'USD', 'min': 0});
      final pick = createField(UiFbFieldType.radio);
      expect(pick.options!.map((o) => o.value), ['option_1', 'option_2', 'option_3']);
      expect(createField(UiFbFieldType.calculated).calc!.toJson(), {'op': 'sum', 'args': []});
      final rep = createGroup(def: d, repeat: true);
      expect(rep.toJson()..remove('id'), {'kind': 'group', 'title': 'Repeating section', 'key': 'items', 'repeat': {'min': 1, 'addLabel': 'Add another', 'itemLabel': 'Entry {n}'}, 'elements': []});
      expect(createStatic('divider').text, isNull);
      expect(createStatic('heading').text, 'Heading');
    });

    test('duplicating a section gives fresh ids, unique keys, and its own rules follow the copy', () {
      final a = f('a', UiFbFieldType.text)..key = 'first_name';
      final b = f('b', UiFbFieldType.number)
        ..key = 'age'
        ..visibility = UiFbVisibility(action: 'show', when: UiFbConditionRule(ref: 'a', op: UiFbOperator.notEmpty));
      final outside = f('o', UiFbFieldType.text)..visibility = UiFbVisibility(action: 'show', when: UiFbConditionRule(ref: 'a', op: UiFbOperator.notEmpty));
      final d = form([UiFbGroup(id: 'g', elements: [a, b]), outside]);
      final before = jsonEncode(d.toJson());
      final (:def, :id) = duplicateElement(d, 'g');
      expect(jsonEncode(d.toJson()), before, reason: 'the original is untouched');
      expect(def.pages[0].elements.map((e) => e.id).toList(), ['g', id, 'o']);
      final copy = def.pages[0].elements[1] as UiFbGroup;
      final ca = copy.elements[0] as UiFbField;
      final cb = copy.elements[1] as UiFbField;
      expect(ca.id, isNot('a'));
      expect(ca.key, 'first_name_2');
      expect(cb.key, 'age_2');
      expect((cb.visibility!.when as UiFbConditionRule).ref, ca.id);
      expect(((def.pages[0].elements[2] as UiFbField).visibility!.when as UiFbConditionRule).ref, 'a');
    });

    test('removing and updating return new definitions', () {
      final d = form([f('a', UiFbFieldType.text), f('b', UiFbFieldType.text)]);
      final out = updateElement(removeElement(d, 'a'), 'b', (el) => (el as UiFbField)..label = 'Bee');
      expect(out.pages[0].elements.map((e) => (e as UiFbField).label), ['Bee']);
      expect(d.pages[0].elements.length, 2);
      expect((d.pages[0].elements[1] as UiFbField).label, 'B');
      expect(updatePage(d, 'p1', (p) => p..title = 'One').pages[0].title, 'One');
      expect(canDrop(d, d.pages[0].elements[0], 'nope'), isFalse);
      expect(allFields(d).length, 2);
      expect(elementName(d.pages[0], d), 'Page 1');
      expect(elementName(null), 'Missing item');
    });
  });

  group('JavaScript value semantics', () {
    test('String(v)', () {
      expect(jsString(10.0), '10');
      expect(jsString(2.5), '2.5');
      expect(jsString(-0.0), '0');
      expect(jsString(1e21), '1e+21');
      expect(jsString(1e-7), '1e-7');
      expect(jsString(['a', null, 3]), 'a,,3');
      expect(jsString({'a': 1}), '[object Object]');
      expect(jsString(true), 'true');
    });

    test('Number(v)', () {
      expect(jsNumber(' 12 '), 12);
      expect(jsNumber(''), 0);
      expect(jsNumber('0x1f'), 31);
      expect(jsNumber('1e3'), 1000);
      expect(jsNumber('.5'), 0.5);
      expect(jsNumber('12px').isNaN, isTrue);
      expect(jsNumber(true), 1);
      expect(jsNumber(['7']), 7);
      expect(jsNumber({}).isNaN, isTrue);
    });

    test('Math.round', () {
      expect(jsRound(2.5), 3);
      expect(jsRound(-2.5), -2);
      expect(jsRound(0.49999999999999994), 0);
    });
  });
}
