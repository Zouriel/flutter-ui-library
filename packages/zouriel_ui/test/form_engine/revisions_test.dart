// Version history of a form: the snapshot, the in-memory store and the rollback rules
// (port of the web `revisions.spec.ts`).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/form_builder/engine/definition.dart';
import 'package:zouriel_ui/src/form_builder/engine/revisions.dart';
import 'package:zouriel_ui/src/form_builder/engine/schema.dart';

typedef J = Map<String, Object?>;

J f(String id, [J extra = const {}]) => {'kind': 'field', 'id': id, 'type': 'text', 'key': id, 'label': id.toUpperCase(), ...extra};
J sel(String id, List<String> values, [J extra = const {}]) => f(id, {
  'type': 'select',
  'options': [for (final v in values) {'id': 'o_$v', 'value': v, 'label': v}],
  ...extra,
});
J grp(String id, List<J> elements, [J extra = const {}]) => {'kind': 'group', 'id': id, 'key': id, 'elements': elements, ...extra};

UiFormDefinition form(List<List<J>> pages, {int? revision = 1, String id = 'form1'}) => UiFormDefinition.fromJson({
  'schemaVersion': 2,
  'id': id,
  'title': 'T',
  if (revision != null) 'revision': revision,
  'pages': [for (var i = 0; i < pages.length; i++) {'id': 'p${i + 1}', 'elements': pages[i]}],
});

List<UiFbElement> flat(UiFormDefinition d) => [for (final p in d.pages) ...p.elements];
List<Object?> idArchived(Iterable<UiFbElement> els) => [for (final e in els) [e.id, e.archived ?? false]];
String dump(UiFormDefinition d) => jsonEncode(d.toJson());

void main() {
  group('fbCreateRevision', () {
    test('snapshots a deep copy with a diff and a default summary', () {
      final v1 = form([[f('a')]], revision: 1);
      final v2 = form([[f('a'), f('b')]], revision: 2);
      final r = fbCreateRevision(v2, previous: v1, meta: const UiFbRevisionMeta(publishedBy: 'Aisha'));
      expect(r.formId, 'form1');
      expect(r.revision, 2);
      expect(r.publishedBy, 'Aisha');
      expect(r.diff?.added, ['b']);
      expect(r.summary, contains('Added'));
      v2.pages[0].elements.removeLast();
      expect(r.definition.pages[0].elements.length, 2);
      expect(fbCreateRevision(v1).summary, 'First version');
      expect(fbCreateRevision(v1).diff, isNull);
    });

    test('a revision survives a JSON round trip, diff included', () {
      final v1 = form([[f('a')]], revision: 1);
      final v2 = form([[f('a'), f('b')]], revision: 2);
      final r = fbCreateRevision(v2, previous: v1, meta: const UiFbRevisionMeta(publishedBy: 'Aisha', publishedAt: '2026-10-01T09:00:00.000Z'));
      final back = UiFbRevision.fromJson(jsonDecode(jsonEncode(r.toJson())));
      expect(back.publishedAt, '2026-10-01T09:00:00.000Z');
      expect(back.diff?.summary, r.diff?.summary);
      expect(dump(back.definition), dump(r.definition));
    });

    test('fbRevisionSummary shows three lines, then "and N more"', () {
      final d = UiFbDiff();
      expect(fbRevisionSummary(d), 'No changes to the questions');
      expect(fbRevisionSummary(null), 'No changes to the questions');
      d.summary.addAll(['a', 'b', 'c', 'd', 'e']);
      expect(fbRevisionSummary(d), 'a. b. c, and 2 more');
    });
  });

  group('UiFbMemoryRevisionStore', () {
    test('lists newest first, gets, and replaces the same revision', () {
      final s = UiFbMemoryRevisionStore();
      s.saveRevision(fbCreateRevision(form([[f('a')]], revision: 1)));
      s.saveRevision(fbCreateRevision(form([[f('a')]], revision: 2)));
      s.saveRevision(fbCreateRevision(form([[f('a')]], revision: 3)));
      expect(s.listRevisions('form1').map((r) => r.revision), [3, 2, 1]);
      expect(s.getRevision('form1', 2)?.revision, 2);
      expect(s.getRevision('form1', 9), isNull);
      final again = fbCreateRevision(form([[f('a')]], revision: 2));
      s.saveRevision(UiFbRevision(formId: again.formId, revision: 2, definition: again.definition, publishedAt: again.publishedAt, summary: 'edited'));
      expect(s.listRevisions('form1').length, 3);
      expect(s.getRevision('form1', 2)?.summary, 'edited');
      expect(s.revisions('other').value, isEmpty);
      s.clear('form1');
      expect(s.all.value.length, 0);
    });

    test('notifies when a version is saved, for one form and for all', () {
      final s = UiFbMemoryRevisionStore();
      var all = 0, one = 0, other = 0;
      s.all.addListener(() => all++);
      s.revisions('form1').addListener(() => one++);
      s.addListener(() => other++);
      s.saveRevision(fbCreateRevision(form([[f('a')]])));
      expect([all, one, other], [1, 1, 1]);
      expect(s.revisions('form1').value.length, 1);
      s.clear();
      expect([all, one, other], [2, 2, 2]);
    });

    test('rolls back to a draft that keeps the current revision number', () {
      final s = UiFbMemoryRevisionStore();
      s.saveRevision(fbCreateRevision(form([[f('a')]], revision: 1)));
      final draft = s.rollback('form1', 1, form([[f('a'), f('b')]], revision: 4));
      expect(draft.revision, 4);
      expect(draft.id, 'form1');
    });

    test('uses the latest revision as the current one when none is given, and throws for a missing one', () {
      final s = UiFbMemoryRevisionStore();
      s.saveRevision(fbCreateRevision(form([[f('a')]], revision: 1)));
      s.saveRevision(fbCreateRevision(form([[f('a'), f('b')]], revision: 2)));
      final draft = s.rollback('form1', 1);
      expect(draft.revision, 2);
      expect(flat(draft).map((e) => [e.id, e.archived]), [['a', null], ['b', true]]);
      expect(() => s.rollback('form1', 7), throwsA(isA<UiFbRevisionError>().having((e) => e.message, 'message', contains('Version 7'))));
    });

    test('keeps copies: changing a saved definition afterwards does not change the history', () {
      final s = UiFbMemoryRevisionStore();
      final d = form([[f('a')]]);
      s.saveRevision(fbCreateRevision(d));
      d.pages[0].elements.clear();
      final got = s.getRevision('form1', 1)!;
      expect(got.definition.pages[0].elements.length, 1);
    });

    test('persists through load and save, and loads it back', () {
      String? stored;
      UiFbMemoryRevisionStore make() => UiFbMemoryRevisionStore(load: () => stored, save: (j) => stored = j);
      final a = make();
      a.saveRevision(fbCreateRevision(form([[f('a')]], revision: 1)));
      expect(make().listRevisions('form1').length, 1);
      a.clear();
      expect(make().listRevisions('form1').length, 0);
      stored = '{not json';
      expect(make().all.value, isEmpty);
    });

    test('still works when storage is blocked or full', () {
      final s = UiFbMemoryRevisionStore(load: () => throw StateError('blocked'), save: (_) => throw StateError('quota'));
      s.saveRevision(fbCreateRevision(form([[f('a')]], revision: 1)));
      expect(s.listRevisions('form1').length, 1);
    });
  });

  group('rollbackDefinition', () {
    test('keeps the current id and revision', () {
      final out = rollbackDefinition(form([[f('a')]], id: 'old', revision: 1), form([[f('a')]], id: 'cur', revision: 5));
      expect([out.id, out.revision], ['cur', 5]);
    });

    test('has no revision when the current one has none', () {
      final out = rollbackDefinition(form([[f('a')]], revision: 1), form([[f('a')]], revision: null));
      expect(out.revision, isNull);
    });

    test('archives a field added since, on its page, or on the last page when its page is gone', () {
      final target = form([[f('a')]]);
      final current = form([[f('a'), f('b')], [f('c')]]);
      final out = rollbackDefinition(target, current);
      expect(out.pages.length, 1);
      expect(idArchived(out.pages[0].elements), [['a', false], ['b', true], ['c', true]]);
      final two = rollbackDefinition(form([[f('a')], [f('z')]]), current);
      expect(two.pages[0].elements.map((e) => e.id), ['a', 'b']);
      expect(two.pages[1].elements.map((e) => e.id), ['z', 'c']);
    });

    test('archives a section added since, with its children, and puts a new child back inside an existing section', () {
      final out = rollbackDefinition(
        form([[grp('g', [f('x')])]]),
        form([
          [
            grp('g', [f('x'), f('x2')]),
            grp('gn', [f('y')]),
          ],
        ]),
      );
      final els = flat(out);
      final g = els[0] as UiFbGroup;
      expect(idArchived(g.elements), [['x', false], ['x2', true]]);
      final added = els[1] as UiFbGroup;
      expect(added.archived, isTrue);
      expect(added.elements[0].archived, isTrue);
    });

    test('keeps options added since, archived', () {
      final out = rollbackDefinition(form([[sel('s', ['a', 'b'])]]), form([[sel('s', ['a', 'b', 'c'])]]));
      final opts = (flat(out)[0] as UiFbField).options!;
      expect(opts.map((o) => [o.value, o.archived ?? false]), [['a', false], ['b', false], ['c', true]]);
    });

    test('merges key history when a key was renamed, never including its own key', () {
      final target = form([[f('a', {'key': 'old_name', 'keyHistory': ['older']})]]);
      final current = form([[f('a', {'key': 'new_name', 'keyHistory': ['old_name', 'mid']})]]);
      final a = flat(rollbackDefinition(target, current))[0] as UiFbField;
      expect(a.key, 'old_name');
      expect(a.keyHistory, ['older', 'mid', 'new_name']);
    });

    test('merges key history of a section too', () {
      final out = rollbackDefinition(form([[grp('g', [], {'key': 'k1'})]]), form([[grp('g', [], {'key': 'k2'})]]));
      final g = flat(out)[0] as UiFbGroup;
      expect([g.key, g.keyHistory], ['k1', ['k2']]);
    });

    test('brings back what was archived in the current draft', () {
      final out = rollbackDefinition(form([[f('a')]]), form([[f('a', {'archived': true})]]));
      expect(flat(out)[0].archived, isNull);
    });

    test('never changes its inputs', () {
      final target = form([[f('a', {'key': 'k1'})]]);
      final current = form([[f('a', {'key': 'k2'}), sel('s', ['x'])]]);
      final t = dump(target), c = dump(current);
      final out = rollbackDefinition(target, current);
      out.pages[0].elements.clear();
      expect(dump(target), t);
      expect(dump(current), c);
    });

    test('the result is a deep copy of the target', () {
      final target = form([[f('a')]]);
      final out = rollbackDefinition(target, form([[f('a')]]));
      expect(identical(out.pages[0].elements[0], target.pages[0].elements[0]), isFalse);
    });
  });
}
