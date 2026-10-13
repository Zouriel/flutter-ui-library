// Runs the fixtures shared with the Angular library against the Dart engine. The same JSON files
// are copied to the web repo (projects/ui/form-builder/src/fixtures) and run there by
// shared-fixtures.spec.ts, so both engines are held to identical expectations. The web engine is
// the reference: when they disagree, the Dart port is the one to fix.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/areas/form_engine.dart';

const _dir = 'test/form_engine/fixtures';

dynamic load(String name) => jsonDecode(File('$_dir/$name').readAsStringSync());

/// Compares JSON values structurally (`1 == 1.0`, key order ignored), with a readable failure.
void expectJson(Object? actual, Object? expected, String reason) {
  expect(jsonEquals(actual, expected), isTrue, reason: '$reason\n  got:  ${jsonEncode(actual)}\n  want: ${jsonEncode(expected)}');
}

UiJson obj(Object? v) => (v as Map).cast<String, Object?>();
List<dynamic> arr(Object? v) => v as List<dynamic>;

void main() {
  test('all shared fixtures are present', () {
    final files = Directory(_dir).listSync().map((f) => f.uri.pathSegments.last).where((n) => n.endsWith('.json')).toList()..sort();
    expect(files, [
      'calc.json', 'conditions.json', 'definition.json', 'describe.json', 'engine-rules.json', 'engine-scholarship.json', //
      'http-sources.json', 'scholarship.answers.json', 'scholarship.definition.json', 'slug.json', 'values.json',
    ]);
  });

  runEngine('engine-scholarship.json');
  runEngine('engine-rules.json');
  conditionsAndCalc();
  valuesAndSlugs();
  definitionHelpers();
  httpSources();
}

// ── Engine scenarios ──────────────────────────────────────────────────────────────────────────

void runEngine(String file) {
  final fx = obj(load(file));
  group('engine: $file', () {
    for (final c in arr(fx['cases']).map(obj)) {
      test(c['name'] as String, () {
        final definition = c['definition'] ?? (c['definitionFile'] != null ? load(c['definitionFile'] as String) : fx['definition'] ?? load(fx['definitionFile'] as String));
        final data = c['data'] ?? (c['dataFile'] != null ? load(c['dataFile'] as String) : null);
        final mode = c['mode'] == null ? null : UiFormMode.values.byName(c['mode'] as String);
        final e = UiFormEngine.fromJson(definition, data: data == null ? null : obj(data), mode: mode, today: () => c['today'] as String);
        (String, String?) at(String addr) {
          final parts = addr.split('@');
          if (parts.length == 1) return (addr, null);
          final g = e.index[parts[0]]!.repeat!;
          final rows = e.rows(g.id);
          final n = int.parse(parts[1]);
          return (parts[0], n < rows.length ? rows[n] : 'missing-row-$n');
        }

        String name(String id, String? row) {
          final g = e.index[id]?.repeat;
          return row != null && g != null ? '$id@${e.rows(g.id).indexOf(row)}' : id;
        }

        final steps = arr(c['steps']);
        for (var i = 0; i < steps.length; i++) {
          final step = obj(steps[i]);
          final where = '${c['name']} — step ${i + 1}';
          if (step.containsKey('set')) {
            final (id, row) = at(step['set'] as String);
            e.setValue(id, row, step['value']);
          } else if (step.containsKey('touch')) {
            final (id, row) = at(step['touch'] as String);
            e.markTouched(id, row);
          } else if (step.containsKey('addRow')) {
            e.addRow(step['addRow'] as String);
          } else if (step.containsKey('removeRow')) {
            final g = step['removeRow'] as String;
            e.removeRow(g, e.rows(g)[step['index'] as int]);
          } else if (step.containsKey('moveRow')) {
            final g = step['moveRow'] as String;
            e.moveRow(g, e.rows(g)[step['index'] as int], step['delta'] as int);
          } else if (step.containsKey('next')) {
            expect(e.next(), step['next'], reason: '$where: next');
          } else if (step.containsKey('back')) {
            expect(e.back(), step['back'], reason: '$where: back');
          } else if (step.containsKey('goTo')) {
            e.goTo(step['goTo'] as int);
          } else if (step.containsKey('submit')) {
            final s = e.submit();
            final want = step['submit'];
            if (want == false) {
              expect(s, isNull, reason: '$where: submit');
            } else if (want == true) {
              expect(s, isNotNull, reason: '$where: submit');
            } else {
              expectJson({'formId': s?.formId, 'revision': s?.revision, 'data': s?.data}, want, '$where: submit');
            }
          } else if (step.containsKey('expect')) {
            checkEngine(e, obj(step['expect']), where, at, name);
          }
        }
        e.dispose();
      });
    }
  });
}

void checkEngine(UiFormEngine e, UiJson x, String where, (String, String?) Function(String) at, String Function(String, String?) name) {
  void per(String key, Object? Function(String id, String? row) read) {
    for (final MapEntry(key: addr, value: want) in obj(x[key] ?? const {}).entries) {
      final (id, row) = at(addr);
      expectJson(read(id, row), want, '$where: $key of $addr');
    }
  }

  if (x.containsKey('mode')) expect(e.mode.name, x['mode'], reason: '$where: mode');
  if (x.containsKey('path')) expectJson(e.path, x['path'], '$where: path');
  if (x.containsKey('pageIndex')) expect(e.pageIndex, x['pageIndex'], reason: '$where: pageIndex');
  if (x.containsKey('step')) expect(e.step, x['step'], reason: '$where: step');
  if (x.containsKey('isLastPage')) expect(e.isLastPage, x['isLastPage'], reason: '$where: isLastPage');
  per('visible', (id, row) => e.instanceState(id, row).visible);
  per('disabled', (id, row) => e.instanceState(id, row).disabled);
  per('required', (id, row) => e.instanceState(id, row).required);
  per('pending', (id, row) => e.instanceState(id, row).pending);
  per('value', (id, row) => e.instanceState(id, row).value);
  per('raw', (id, row) => e.rawValue(id, row));
  per('errors', (id, row) => e.instanceState(id, row).errors);
  per('warnings', (id, row) => e.instanceState(id, row).warnings);
  per('errorsShown', (id, row) => e.errorsShown(id, row));
  per('display', (id, row) => formatValue(e.field(id)!, e.instanceState(id, row).value, locale: 'en_US'));
  per('dataPath', (id, row) => e.dataPath(id, row));
  per('instanceLabel', (id, row) => e.instanceLabel(id, row));
  per('sourceParams', (id, row) => e.sourceParams(id, row));
  for (final MapEntry(key: g, value: n) in obj(x['rows'] ?? const {}).entries) {
    expect(e.rows(g).length, n, reason: '$where: rows of $g');
  }
  for (final MapEntry(key: g, value: v) in obj(x['canAddRow'] ?? const {}).entries) {
    expect(e.canAddRow(g), v, reason: '$where: canAddRow $g');
  }
  for (final MapEntry(key: g, value: v) in obj(x['canRemoveRow'] ?? const {}).entries) {
    expect(e.canRemoveRow(g), v, reason: '$where: canRemoveRow $g');
  }
  for (final MapEntry(key: p, value: want) in obj(x['pageErrors'] ?? const {}).entries) {
    final got = [for (final it in e.pageErrors(int.parse(p))) {'field': name(it.id, it.row), 'label': it.label, 'message': it.message}];
    expectJson(got, want, '$where: pageErrors of page $p');
  }
  if (x.containsKey('data')) expectJson(e.data, x['data'], '$where: data');
  for (final MapEntry(key: k, value: v) in obj(x['dataHas'] ?? const {}).entries) {
    expectJson(e.data[k], v, '$where: data.$k');
  }
  for (final k in arr(x['dataLacks'] ?? const [])) {
    expect(e.data.containsKey(k), isFalse, reason: '$where: data lacks $k');
  }
  if (x.containsKey('dirty')) expect(e.dirty, x['dirty'], reason: '$where: dirty');
  if (x.containsKey('changes')) expectJson([for (final ch in e.changes) ch.toJson()], x['changes'], '$where: changes');
}

// ── Rules, calculations and wording ─────────────────────────────────────────────────────────────

void conditionsAndCalc() {
  group('conditions.json', () {
    final fx = obj(load('conditions.json'));
    for (final c in arr(fx['cases']).map(obj)) {
      test(c['name'] as String, () {
        final values = obj(c['values']);
        final ctx = UiFbConditionFns(
          value: (r) => values[r],
          visible: (r) => (c['visible'] as Map?)?[r] as bool? ?? true,
          complete: (r) => (c['complete'] as Map?)?[r] as bool? ?? true,
          rows: (r) {
            final rows = c['rows'] as Map?;
            return rows != null && rows.containsKey(r) ? rows[r] as int? : 0;
          },
          today: () => fx['today'] as String,
        );
        expect(evaluateCondition(UiFbCondition.maybe(c['condition']), ctx), c['expected']);
      });
    }
  });

  group('calc.json', () {
    final fx = obj(load('calc.json'));
    for (final c in arr(fx['cases']).map(obj)) {
      test(c['name'] as String, () {
        final values = obj(c['values']);
        final ctx = UiFbCalcFns(
          values: (r) => (values[r] as List?)?.cast<Object?>() ?? const [],
          rows: (r) => (c['rows'] as Map?)?[r] as int?,
          today: () => fx['today'] as String,
        );
        expectJson(evaluateCalc(UiFbCalc.fromJson(c['calc']), ctx), c['expected'], c['name'] as String);
      });
    }
  });

  group('describe.json', () {
    final fx = obj(load('describe.json'));
    final names = obj(fx['names']);
    final labels = obj(fx['labels']);
    final d = UiFbDescribeFns(
      name: (r) => names[r] as String? ?? r,
      value: (r, v) => (labels[r] as Map?)?[jsonValueString(v)] as String? ?? jsonValueString(v),
    );
    test('describes conditions', () {
      for (final c in arr(fx['conditions']).map(obj)) {
        expect(describeCondition(UiFbCondition.maybe(c['condition']), d), c['expected']);
      }
    });
    test('knows when a condition is finished', () {
      for (final c in arr(fx['complete']).map(obj)) {
        expect(conditionComplete(UiFbCondition.maybe(c['condition'])), c['expected'], reason: jsonEncode(c['condition']));
      }
    });
    test('describes calculations', () {
      for (final c in arr(fx['calcs']).map(obj)) {
        expect(describeCalc(UiFbCalc.fromJson(c['calc']), (r) => names[r] as String? ?? r), c['expected']);
      }
    });
  });
}

/// `String(v)` as the web fixtures' describer uses it.
String jsonValueString(Object? v) => v is num && v == v.truncate() ? v.toInt().toString() : (v is String ? v : jsonEncode(v));

// ── Values, formatting and keys ─────────────────────────────────────────────────────────────────

void valuesAndSlugs() {
  group('slug.json', () {
    final fx = obj(load('slug.json'));
    test('makes keys from labels', () {
      for (final c in arr(fx['slugs']).map(obj)) {
        expect(fbSlug(c['label'] as String), c['expected'], reason: c['label'] as String);
      }
    });
    test('checks keys', () {
      for (final c in arr(fx['keys']).map(obj)) {
        expect(fbKeyValid(c['key'] as String), c['expected'], reason: c['key'] as String);
      }
    });
  });

  group('values.json', () {
    final fx = obj(load('values.json'));
    test('coerces answers to their field’s shape', () {
      for (final c in arr(fx['coerce']).map(obj)) {
        final f = UiFbField.fromJson(obj(c['field']));
        expectJson(coerceValue(f, c['value']), c['expected'], '${f.type.name} ${jsonEncode(c['value'])}');
      }
    });
    test('reads saved choices', () {
      for (final c in arr(fx['choices']).map(obj)) {
        expectJson(optionValueOf(c['value']), c['optionValueOf'], jsonEncode(c['value']));
        expectJson(toChoice(c['value']), c['toChoice'], jsonEncode(c['value']));
      }
    });
    test('knows when a source has more pages', () {
      for (final c in arr(fx['hasMore']).map(obj)) {
        final p = obj(c['page']);
        final page = UiFbSourcePage(
          items: [for (final i in arr(p['items'])) UiFbSourceItem(value: i as Object, label: '$i')],
          hasMore: p['hasMore'] as bool?,
          total: p['total'] as num?,
        );
        expect(sourceHasMore(page, c['loaded'] as int, c['pageSize'] as int), c['expected'], reason: jsonEncode(c));
      }
    });
    test('formats answers for people', () {
      expect(fx['locale'], 'en-US');
      for (final c in arr(fx['format']).map(obj)) {
        final f = UiFbField.fromJson(obj(c['field']));
        expect(formatValue(f, c['value'], locale: 'en_US'), c['expected'], reason: '${f.type.name} ${jsonEncode(c['value'])}');
      }
    });
  });
}

// ── Definition helpers ──────────────────────────────────────────────────────────────────────────

void definitionHelpers() {
  group('definition.json', () {
    final fx = obj(load('definition.json'));
    UiFormDefinition defOf(UiJson c) => UiFormDefinition.fromJson(c['definition'] ?? load(c['definitionFile'] as String));

    test('lints', () {
      for (final c in arr(fx['lint']).map(obj)) {
        expectJson([for (final p in lintDefinition(defOf(c))) p.toJson()], c['expected'], c['name'] as String);
      }
    });
    test('finds loops', () {
      for (final c in arr(fx['cycles']).map(obj)) {
        expectJson(findCycles(defOf(c)), c['expected'], c['name'] as String);
      }
    });
    test('finds references', () {
      final r = obj(fx['references']);
      final d = defOf(r);
      for (final MapEntry(key: id, value: want) in obj(r['referencesTo']).entries) {
        expectJson([for (final x in referencesTo(d, id)) x.toJson()], want, id);
      }
      for (final MapEntry(key: id, value: want) in obj(r['externalReferences']).entries) {
        expectJson([for (final x in externalReferences(d, id)) x.toJson()], want, id);
      }
      for (final MapEntry(key: id, value: want) in obj(r['subtreeIds']).entries) {
        expectJson(subtreeIds(d, id), want, id);
      }
    });
    test('removes references', () {
      for (final c in arr(fx['removeReferences']).map(obj)) {
        final ids = arr(c['ids']).cast<String>();
        final before = defOf(c);
        final snapshot = jsonEncode(before.toJson());
        expectJson(removeReferences(before, ids).toJson(), c['expected'], c['name'] as String);
        expect(jsonEncode(before.toJson()), snapshot, reason: 'the definition passed in is left alone');
      }
    });
    test('migrates', () {
      for (final c in arr(fx['migrate']).map(obj)) {
        expectJson(migrateDefinition(c['raw']).toJson(), c['expected'], jsonEncode(c['raw']));
      }
      for (final c in arr(fx['migrateGenerated']).map(obj)) {
        final d = migrateDefinition(c['raw']);
        expect(d.pages.length, c['pages']);
        expect(d.id, isNotEmpty);
        expect(d.pages.every((p) => p.id.isNotEmpty), isTrue);
        expect(d.schemaVersion, 1);
      }
    });
    test('round-trips definitions unchanged', () {
      for (final c in arr(fx['roundtrip']).map(obj)) {
        final json = c['definition'] ?? load(c['definitionFile'] as String);
        expectJson(UiFormDefinition.fromJson(json).toJson(), json, '${c['name']}: fromJson → toJson');
        expectJson(migrateDefinition(json).toJson(), json, '${c['name']}: migrateDefinition');
        expect(jsonEncode(UiFormDefinition.fromJson(json).clone().toJson()), jsonEncode(UiFormDefinition.fromJson(json).toJson()));
      }
    });
    test('keeps keys unique per data scope', () {
      for (final c in arr(fx['uniqueKey']).map(obj)) {
        expect(uniqueKey(defOf(c), c['base'] as String, c['id'] as String?), c['expected'], reason: '${c['base']} ${c['id']}');
      }
    });
    test('remembers renamed keys', () {
      for (final c in arr(fx['renameKey']).map(obj)) {
        var d = defOf(c);
        for (final s in arr(c['steps'])) {
          d = renameKey(d, (s as List)[0] as String, s[1] as String);
        }
        final el = indexDefinition(d)[c['id']]!.element;
        final json = {
          'key': el is UiFbField ? el.key : (el as UiFbGroup).key,
          if ((el is UiFbField ? el.keyHistory : (el as UiFbGroup).keyHistory) case final h?) 'keyHistory': h,
        };
        expectJson(json, c['expected'], jsonEncode(c['steps']));
      }
    });
    test('moves elements', () {
      for (final c in arr(fx['move']).map(obj)) {
        final d = defOf(c);
        final t = obj(c['target']);
        final out = moveElement(d, c['id'] as String, UiFbDropTarget(containerId: t['containerId'] as String, index: t['index'] as int));
        if (c['unchanged'] == true) {
          expect(identical(out, d), isTrue, reason: c['name'] as String);
          continue;
        }
        final got = <String, List<String>>{};
        for (final MapEntry(key: id, value: entry) in indexDefinition(out).entries) {
          final el = entry.element;
          if (el is UiFbPage) got[id] = [for (final x in el.elements) x.id];
          if (el is UiFbGroup) got[id] = [for (final x in el.elements) x.id];
        }
        expectJson(got, c['expected'], c['name'] as String);
      }
    });
    test('summarises what changed between versions', () {
      for (final c in arr(fx['diff']).map(obj)) {
        expectJson(diffDefinitions(UiFormDefinition.fromJson(c['before']), UiFormDefinition.fromJson(c['after'])).toJson(), c['expected'], 'diff');
      }
    });
    test('offers operators and checks that fit', () {
      for (final MapEntry(key: kind, value: ops) in obj(fx['operatorsFor']).entries) {
        expectJson([for (final o in operatorsFor(UiFbSubjectKind.values.byName(kind))) o.op.name], ops, kind);
      }
      for (final c in arr(fx['validatorsFor']).map(obj)) {
        final types = validatorsFor(UiFbFieldType(c['type'] as String), c['format'] as String?, uiFbBuiltinValidators).map((d) => d.type).toList();
        expectJson(types, c['expected'], c['type'] as String);
      }
      for (final t in arr(fx['typesCompatible'])) {
        final l = t as List;
        expect(typesCompatible(UiFbFieldType(l[0] as String), UiFbFieldType(l[1] as String)), l[2], reason: '$l');
      }
    });
    test('starts new forms with the app’s defaults', () {
      final c = obj(fx['createDefinition']);
      final d = createDefinition(title: c['title'] as String, defaults: UiFbSettings.fromJson(c['defaults']));
      expectJson(d.settings!.toJson(), c['expectedSettings'], 'settings');
      expect(d.title, c['title']);
      expect(d.pages.length, 1);
    });
  });
}

// ── Lists set up in settings ────────────────────────────────────────────────────────────────────

void httpSources() {
  group('http-sources.json', () {
    final fx = obj(load('http-sources.json'));
    UiJson page(Object? items, Object? total, Object? hasMore) => {
      'items': [
        for (final i in arr(items).map(obj)) {'value': i['value'], 'label': i['label'], 'description': i['description']},
      ],
      'total': total,
      'hasMore': hasMore,
    };
    UiJson pageOf(UiFbSourcePage p) => page([for (final i in p.items) i.toJson()], p.total, p.hasMore);

    test('builds request addresses', () {
      for (final c in arr(fx['sourceUrl']).map(obj)) {
        final cfg = UiFbHttpSourceConfig.fromJson(c['config']);
        final url = sourceUrl(cfg, query: c['query'] as String, page: c['page'] as int, pageSize: c['pageSize'] as int, params: obj(c['params']));
        expect(url, c['expected'], reason: cfg.url);
      }
    });
    test('reads replies, and explains a reply that does not match', () {
      for (final c in arr(fx['readSourceReply']).map(obj)) {
        final cfg = UiFbHttpSourceConfig.fromJson(c['config']);
        if (c['error'] != null) {
          expect(
            () => readSourceReply(cfg, c['reply'], c['pageSize'] as int),
            throwsA(isA<UiFbSourceError>().having((e) => e.message, 'message', c['error'])),
            reason: c['name'] as String,
          );
        } else {
          final want = obj(c['expected']);
          expectJson(pageOf(readSourceReply(cfg, c['reply'], c['pageSize'] as int)), page(want['items'], want['total'], want['hasMore']), c['name'] as String);
        }
      }
    });
    test('fills label patterns', () {
      for (final c in arr(fx['fillPattern']).map(obj)) {
        expect(fillPattern(c['obj'], c['pattern'] as String), c['expected'], reason: c['pattern'] as String);
      }
    });
    test('only allows listed servers', () {
      for (final c in arr(fx['originAllowed']).map(obj)) {
        expect(originAllowed(c['url'] as String, arr(c['allowed']).cast<String>()), c['expected'], reason: c['url'] as String);
      }
      for (final c in arr(fx['originOf']).map(obj)) {
        expect(originOf(c['url'] as String), c['expected'], reason: c['url'] as String);
      }
    });
    test('searches through the app’s fetch hook, and refuses other servers', () async {
      final s = obj(fx['search']);
      final cfg = UiFbHttpSourceConfig.fromJson(s['config']);
      final seen = <String>[];
      final allowed = arr(s['allowed']).cast<String>();
      final src = httpOptionSource(cfg, UiFbHttpSourcesOptions(allowedOrigins: allowed, fetch: (url, signal) async {
        seen.add(url);
        return s['reply'];
      }));
      final res = await src.search(UiFbSourceQuery(query: '', page: 1, pageSize: cfg.pageSize!, params: const {}));
      expectJson([for (final i in res.items) i.label], s['expectedLabels'], 'labels');
      expectJson(seen, s['expectedUrls'], 'urls');
      final blocked = httpOptionSource(cfg.copyWith(url: s['blockedUrl'] as String), UiFbHttpSourcesOptions(allowedOrigins: allowed, fetch: (url, signal) async => s['reply']));
      await expectLater(
        Future.sync(() => blocked.search(UiFbSourceQuery(query: '', page: 1, pageSize: 2, params: const {}))),
        throwsA(isA<UiFbSourceError>().having((e) => e.message, 'message', s['blockedError'])),
      );
    });
    test('turns global settings into sources', () {
      final g = obj(fx['globalSettings']);
      final settings = UiFormGlobalSettings.fromJson(g['settings']);
      expectJson(sourcesFromSettings(settings).map((x) => x.type).toList(), g['expectedTypes'], 'types');
      expectJson(settings.toJson(), g['settings'], 'settings round-trip');
    });
  });
}
