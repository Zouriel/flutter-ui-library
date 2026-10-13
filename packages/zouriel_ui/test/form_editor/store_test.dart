import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import 'support.dart';

List<String> ids(UiFormBuilderController s, [int page = 0]) => [for (final e in s.def.pages[page].elements) e.id];

void main() {
  UiFormBuilderController store(UiFormDefinition def, {FakeClock? clock}) => UiFormBuilderController(definition: def, clock: clock?.call);

  group('UiFormBuilderController', () {
    test('lets a section key follow its title until it is renamed by hand', () {
      final s = store(formOf([fj('a', 'text'), createGroup(repeat: true).toJson()..['id'] = 'g']));
      String? key() => s.index['g']!.asGroup!.key;
      expect(key(), 'items');
      s.setGroupTitle('g', 'Dependants');
      expect(key(), 'dependants');
      s.setGroupTitle('g', 'Children');
      expect(key(), 'children');
      s.updateGroup('g', (g) => g.key = 'kids');
      s.setGroupTitle('g', 'Young people');
      expect(key(), 'kids');
    });

    test('keeps a section without a key keyless when it is retitled', () {
      final s = store(formOf([createGroup().toJson()..['id'] = 'g']));
      s.setGroupTitle('g', 'Contact details');
      expect(s.index['g']!.asGroup!.key, isNull);
      expect(s.index['g']!.asGroup!.title, 'Contact details');
    });

    test('adds right after the selection and selects the new field', () {
      final s = store(formOf([fj('a', 'text'), fj('b', 'text')]));
      s.select('a');
      final n = createField(UiFbFieldType.email, def: s.def);
      s.add(n);
      expect(ids(s), ['a', n.id, 'b']);
      expect(s.selectedId, n.id);
    });

    test('adds into a selected section, and at the end of the page with nothing selected', () {
      final s = store(formOf([
        {'kind': 'group', 'id': 'g', 'elements': <Object?>[]},
      ]));
      s.select('g');
      s.add(createField(UiFbFieldType.text, def: s.def));
      expect(s.index['g']!.asGroup!.elements, hasLength(1));
      s.select(null);
      final last = createField(UiFbFieldType.text, def: s.def);
      s.add(last);
      expect(ids(s).last, last.id);
    });

    test('a repeat dropped into a repeat goes to the page instead', () {
      final s = store(formOf([
        {'kind': 'group', 'id': 'r', 'key': 'r', 'repeat': <String, Object?>{}, 'elements': <Object?>[]},
      ]));
      s.add(createGroup(def: s.def, repeat: true), const UiFbDropTarget(containerId: 'r', index: 0));
      expect(s.index['r']!.asGroup!.elements, isEmpty);
      expect(ids(s), hasLength(2));
    });

    test('moves, refusing a move that changes nothing', () {
      final s = store(formOf([fj('a', 'text'), fj('b', 'text'), fj('c', 'text')]));
      expect(s.move('a', const UiFbDropTarget(containerId: 'p1', index: 3)), isTrue);
      expect(ids(s), ['b', 'c', 'a']);
      expect(s.move('a', const UiFbDropTarget(containerId: 'p1', index: 3)), isFalse);
      s.undo();
      expect(ids(s), ['a', 'b', 'c']);
    });

    test('undoes and redoes, and treats quick typing in one box as one step', () {
      final clock = FakeClock();
      final s = store(formOf([fj('a', 'text')]), clock: clock);
      for (final l in ['N', 'Na', 'Name']) {
        s.updateField('a', (f) => f.label = l, mergeKey: 'label:a');
        clock.advance(const Duration(milliseconds: 300));
      }
      s.updateField('a', (f) => f.help = 'Your name');
      s.undo();
      expect(s.field('a')!.help, isNull);
      expect(s.field('a')!.label, 'Name');
      s.undo();
      expect(s.field('a')!.label, 'A');
      expect(s.canUndo, isFalse);
      s.redo();
      expect(s.field('a')!.label, 'Name');
      expect(s.canRedo, isTrue);
    });

    test('typing after a pause is its own step', () {
      final clock = FakeClock();
      final s = store(formOf([fj('a', 'text')]), clock: clock);
      s.updateField('a', (f) => f.label = 'One', mergeKey: 'label:a');
      clock.advance(const Duration(seconds: 2));
      s.updateField('a', (f) => f.label = 'Two', mergeKey: 'label:a');
      s.undo();
      expect(s.field('a')!.label, 'One');
    });

    test('never changes the definition it was handed', () {
      final def = formOf([fj('a', 'text')]);
      final before = jsonEncode(def.toJson());
      final s = store(def);
      s.updateField('a', (f) => f.label = 'Changed');
      s.add(createField(UiFbFieldType.number, def: s.def));
      expect(jsonEncode(def.toJson()), before);
    });

    test('keeps history when the host hands back the same form with a new revision (publishing)', () {
      final s = store(formOf([fj('a', 'text')]));
      s.updateField('a', (f) => f.label = 'Name');
      expect(s.canUndo, isTrue);
      // The host publishes: a new object, revision bumped, content as the builder has it.
      s.load(s.def.clone()..revision = 3);
      expect(s.canUndo, isTrue);
      expect(s.def.revision, 3);
      // A copy that went through JSON is still the same form.
      s.load(jsonDecode(jsonEncode((s.def.clone()..revision = 4).toJson())) as Object);
      expect(s.canUndo, isTrue);
      // Undo steps back through content; the revision the host gave stays.
      s.undo();
      expect(s.field('a')!.label, 'A');
      expect(s.def.revision, 4);
      s.redo();
      expect(s.field('a')!.label, 'Name');
      expect(s.def.revision, 4);
    });

    test('clears history for another form, for other content, or when asked', () {
      final s = store(formOf([fj('a', 'text')]));
      s.updateField('a', (f) => f.label = 'Name');
      s.load(formOf([fj('a', 'text', {'label': 'Name'})], id: 'other'));
      expect(s.canUndo, isFalse);
      s.updateField('a', (f) => f.label = 'Again');
      s.load(formOf([fj('a', 'text', {'label': 'Changed elsewhere'})], id: 'other'));
      expect(s.canUndo, isFalse);
      s.updateField('a', (f) => f.label = 'Once more');
      s.undo();
      s.clearHistory();
      expect(s.canUndo, isFalse);
      expect(s.canRedo, isFalse);
    });

    test('moves out of a section when nudged past its edge', () {
      final s = store(formOf([
        fj('a', 'text'),
        {'kind': 'group', 'id': 'g', 'elements': [fj('in', 'text')]},
      ]));
      s.nudge('in', -1);
      expect(ids(s), ['a', 'in', 'g']);
      s.nudge('a', -1);
      expect(ids(s), ['a', 'in', 'g'], reason: 'the first item on a page stays put');
      s.nudge('a', 1);
      expect(ids(s), ['in', 'a', 'g']);
    });

    test('duplicates right after the original with a fresh key, and selects the copy', () {
      // Ids are random tokens in real forms; here the key differs from the id so the copy's
      // reference remapping (which swaps exact ids) can't touch it.
      final s = store(formOf([fj('a', 'text', {'key': 'name'}), fj('b', 'text')]));
      s.duplicate('a');
      final copy = s.selectedId!;
      expect(ids(s), ['a', copy, 'b']);
      expect(s.field(copy)!.key, 'name_2');
    });

    test('deletes rules that mentioned a deleted question', () {
      final s = store(formOf([
        fj('a', 'toggle'),
        fj('b', 'text', {
          'visibility': {
            'action': 'show',
            'when': {'ref': 'a', 'op': 'isTrue'},
          },
        }),
      ]));
      expect(s.externalRefs('a'), hasLength(1));
      s.select('a');
      s.remove('a');
      expect(s.field('b')!.visibility, isNull);
      expect(s.selectedId, isNull);
      expect(s.problems.where((p) => p.severity == 'error'), isEmpty);
    });

    test('only protects answers once the published form has some', () {
      final def = formOf([fj('a', 'text')]);
      final s = store(def);
      s.published = def;
      expect(s.hasAnswers('a'), isFalse);
      s.submissionCount = 3;
      expect(s.hasAnswers('a'), isTrue);
      s.add(createField(UiFbFieldType.text, def: s.def));
      expect(s.hasAnswers(s.selectedId!), isFalse);
    });

    test('lists what changed since publishing', () {
      final def = formOf([fj('a', 'text')]);
      final s = store(def)..published = def;
      expect(s.diff!.summary, isEmpty);
      s.updateField('a', (f) => f.key = 'name');
      expect(s.diff!.summary, ['Renamed the data key of “A” from “a” to “name”']);
    });

    test('offers rules only what they can sensibly ask about', () {
      final s = store(formOf([
        fj('a', 'text'),
        {
          'kind': 'group',
          'id': 'r',
          'key': 'r',
          'repeat': <String, Object?>{},
          'elements': [fj('qty', 'number'), fj('price', 'number')],
        },
      ]));
      // Outside the repeat: other top-level fields and the section itself, not fields inside it.
      expect([for (final o in s.refOptions('a')) o.id], ['r']);
      // Inside an entry: its siblings (same entry) and outside fields.
      expect([for (final o in s.refOptions('qty')) o.id]..sort(), ['a', 'price']);
      expect(s.refOptions('qty').firstWhere((o) => o.id == 'price').kind, UiFbSubjectKind.number);
    });

    test('flags sourced fields whose list is missing or not set up', () {
      final s = store(formOf([
        fj('who', 'select', {
          'source': {'type': 'courses', 'params': <String, Object?>{}},
        }),
      ]));
      expect(s.problems.single.message, contains('doesn’t provide (“courses”)'));
      s.optionSourceDefs = [
        UiFbOptionSource(
          type: 'courses',
          label: 'Courses',
          params: const [UiFbSourceParamSpec(key: 'programme', label: 'Programme', required: true)],
          search: (q) => const UiFbSourcePage(items: []),
        ),
      ];
      expect(s.problems.single.message, '“WHO” needs “Programme” set for its Courses list.');
      expect(s.problemIds, {'who'});
    });

    test('titles the first page when a second one is added, and moves and removes pages', () {
      final s = store(createDefinition());
      s.addPage();
      expect([for (final p in s.def.pages) p.title], ['Page 1', 'Page 2']);
      expect(s.pageIndex, 1);
      final second = s.def.pages[1].id;
      s.movePage(second, -1);
      expect(s.def.pages.first.id, second);
      expect(s.pageIndex, 0);
      s.removePage(second);
      expect(s.def.pages, hasLength(1));
      s.removePage(s.def.pages.first.id);
      expect(s.def.pages, hasLength(1), reason: 'the last page stays');
      s.undo();
      expect(s.def.pages, hasLength(2));
    });

    test('updates settings without leaving empty keys behind', () {
      final s = store(createDefinition());
      s.updateSettings((st) => st.submitLabel = 'Send');
      expect(s.def.settings!.toJson(), {'submitLabel': 'Send'});
      s.updateSettings((st) => st.submitLabel = null);
      expect(s.def.settings!.toJson(), isEmpty);
    });

    test('describes rules with labels people recognise', () {
      final s = store(formOf([
        fj('c', 'radio', {
          'label': 'Country',
          'options': [
            {'id': 'o1', 'value': 'mv', 'label': 'Maldives'},
          ],
        }),
      ]));
      expect(s.describe(UiFbCondition.fromJson({'ref': 'c', 'op': 'eq', 'value': {'const': 'mv'}})), '“Country” is Maldives');
    });
  });
}
