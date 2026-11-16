/// Version history of a form: a snapshot is kept every time the form is published, and any
/// earlier version can be brought back as a new draft. Pure functions plus a ready-made
/// in-memory store; an app with a backend implements [UiFbRevisionStore] itself.
///
/// The Angular twin is `revisions.ts` in `@zouriel/ui/form-builder`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'definition.dart';
import 'js.dart' show UiJson;
import 'schema.dart';

/// One published version of a form.
class UiFbRevision {
  UiFbRevision({
    required this.formId,
    required this.revision,
    required this.definition,
    required this.publishedAt,
    this.publishedBy,
    this.summary,
    this.diff,
  });

  /// Reads what [toJson] wrote.
  factory UiFbRevision.fromJson(Object? json) {
    final j = json is Map ? json.cast<String, Object?>() : <String, Object?>{};
    final d = j['diff'];
    return UiFbRevision(
      formId: '${j['formId'] ?? ''}',
      revision: (j['revision'] is num ? (j['revision'] as num).toInt() : 1),
      definition: UiFormDefinition.fromJson(j['definition']),
      publishedAt: '${j['publishedAt'] ?? ''}',
      publishedBy: j['publishedBy'] as String?,
      summary: j['summary'] as String?,
      diff: d is Map ? _diffFromJson(d.cast<String, Object?>()) : null,
    );
  }

  final String formId;
  final int revision;

  /// The full definition as published.
  final UiFormDefinition definition;

  /// An ISO 8601 date and time.
  final String publishedAt;
  final String? publishedBy;

  /// One line saying what this version changed.
  final String? summary;

  /// What changed since the version before it (stored so the history needn't recompute it).
  final UiFbDiff? diff;

  /// A deep copy (the definition is copied; the diff is shared, nothing changes it).
  UiFbRevision clone() => UiFbRevision(
    formId: formId,
    revision: revision,
    definition: definition.clone(),
    publishedAt: publishedAt,
    publishedBy: publishedBy,
    summary: summary,
    diff: diff,
  );

  UiJson toJson() => {
    'formId': formId,
    'revision': revision,
    'definition': definition.toJson(),
    'publishedAt': publishedAt,
    if (publishedBy != null) 'publishedBy': publishedBy,
    if (summary != null) 'summary': summary,
    if (diff != null) 'diff': diff!.toJson(),
  };
}

UiFbDiff _diffFromJson(UiJson j) {
  List<String> strs(Object? v) => v is List ? [for (final x in v) '$x'] : <String>[];
  List<UiJson> maps(Object? v) => v is List ? [for (final x in v) if (x is Map) x.cast<String, Object?>()] : <UiJson>[];
  final d = UiFbDiff();
  d.added.addAll(strs(j['added']));
  d.removed.addAll(strs(j['removed']));
  d.archived.addAll(strs(j['archived']));
  d.restored.addAll(strs(j['restored']));
  d.rulesChanged.addAll(strs(j['rulesChanged']));
  d.summary.addAll(strs(j['summary']));
  for (final r in maps(j['renamedKeys'])) {
    d.renamedKeys.add(UiFbRenamedKey(id: '${r['id']}', from: '${r['from']}', to: '${r['to']}'));
  }
  for (final t in maps(j['typeChanged'])) {
    d.typeChanged.add(UiFbTypeChange(id: '${t['id']}', from: UiFbFieldType('${t['from']}'), to: UiFbFieldType('${t['to']}'), compatible: t['compatible'] == true));
  }
  for (final o in maps(j['optionsRemoved'])) {
    d.optionsRemoved.add(UiFbOptionsRemoved(id: '${o['id']}', values: strs(o['values'])));
  }
  return d;
}

/// A store failure the history shows to people as it is (for example "Version 7 of this form was not found.").
class UiFbRevisionError implements Exception {
  const UiFbRevisionError(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Where an app keeps its form versions. Every method may return a value or a Future.
abstract interface class UiFbRevisionStore {
  /// Every published version of the form, newest first.
  FutureOr<List<UiFbRevision>> listRevisions(String formId);
  FutureOr<UiFbRevision?> getRevision(String formId, int revision);

  /// Stores a version, replacing an entry with the same form and revision number.
  FutureOr<void> saveRevision(UiFbRevision entry);

  /// A new DRAFT with the content of [targetRevision], built with [rollbackDefinition]. Nothing is published.
  FutureOr<UiFormDefinition> rollback(String formId, int targetRevision, [UiFormDefinition? current]);
}

/// Optional details for [fbCreateRevision].
class UiFbRevisionMeta {
  const UiFbRevisionMeta({this.publishedBy, this.summary, this.publishedAt});
  final String? publishedBy;
  final String? summary;
  final String? publishedAt;
}

/// A one-line summary from a diff's lines: the first three, then "and N more".
String fbRevisionSummary(UiFbDiff? diff) {
  final lines = diff?.summary ?? const <String>[];
  if (lines.isEmpty) return 'No changes to the questions';
  final shown = lines.take(3).join('. ');
  return lines.length > 3 ? '$shown, and ${lines.length - 3} more' : shown;
}

/// The snapshot to store when [definition] is published. [previous] is the version published before it.
UiFbRevision fbCreateRevision(UiFormDefinition definition, {UiFormDefinition? previous, UiFbRevisionMeta meta = const UiFbRevisionMeta()}) {
  final def = definition.clone();
  final diff = previous == null ? null : diffDefinitions(previous, def);
  return UiFbRevision(
    formId: def.id,
    revision: (def.revision ?? 1).toInt(),
    definition: def,
    publishedAt: meta.publishedAt ?? DateTime.now().toUtc().toIso8601String(),
    summary: meta.summary ?? (previous != null ? fbRevisionSummary(diff) : 'First version'),
    publishedBy: (meta.publishedBy ?? '').isEmpty ? null : meta.publishedBy,
    diff: diff,
  );
}

// ── Rollback ─────────────────────────────────────────────────────────────────────────────────

void _walk(List<UiFbElement> elements, void Function(UiFbElement el) fn) {
  for (final el in elements) {
    fn(el);
    if (el is UiFbGroup) _walk(el.elements, fn);
  }
}

Set<String> _idsOf(UiFormDefinition def) {
  final ids = <String>{};
  for (final p in def.pages) {
    _walk(p.elements, (e) => ids.add(e.id));
  }
  return ids;
}

Map<String, UiFbElement> _byId(UiFormDefinition def) {
  final m = <String, UiFbElement>{};
  for (final p in def.pages) {
    _walk(p.elements, (e) => m[e.id] = e);
  }
  return m;
}

List<String> _mergeHistory(String? own, List<List<String>?> lists) {
  final out = <String>[];
  for (final l in lists) {
    for (final k in l ?? const <String>[]) {
      if (k.isNotEmpty && k != own && !out.contains(k)) out.add(k);
    }
  }
  return out;
}

void _setArchived(UiFbElement e) {
  switch (e) {
    case UiFbField():
      e.archived = true;
    case UiFbGroup():
      e.archived = true;
    case UiFbStatic():
      e.archived = true;
  }
}

/// A copy of a removed element that stays on the form as archived, minus children the target still has elsewhere.
UiFbElement _archivedCopy(UiFbElement el, Set<String> keep) {
  final copy = UiFbElement.fromJson(el.toJson());
  void mark(UiFbElement e) {
    _setArchived(e);
    if (e is UiFbGroup) {
      e.elements = e.elements.where((c) => !keep.contains(c.id)).toList();
      e.elements.forEach(mark);
    }
  }

  mark(copy);
  return copy;
}

/// The draft that brings [target] back while keeping every saved answer readable. Pure: neither input changes.
///
/// - It has [target]'s content, but [current]'s `id` and `revision`, so the next publish counts up cleanly.
/// - A question or section in [current] that [target] doesn't have stays, archived, on the page it was on
///   (the last page if that page is gone; inside its section if that section still exists).
/// - An option in [current] that [target] doesn't have stays, archived.
/// - If a question's data key differs, the restored one takes [target]'s key and `keyHistory` gains the
///   old keys (never its own), so answers saved under any older key still load.
/// - Anything archived in [current] but live in [target] is live again.
UiFormDefinition rollbackDefinition(UiFormDefinition target, UiFormDefinition current) {
  final out = target.clone();
  out.id = current.id;
  out.revision = current.revision;

  final cur = _byId(current);
  final targetIds = _idsOf(target);
  final resultById = _byId(out);

  // Keys and options of elements both versions have.
  for (final MapEntry(key: id, value: el) in resultById.entries.toList()) {
    final old = cur[id];
    if (old == null) continue;
    final ownKey = el is UiFbField ? el.key : (el is UiFbGroup ? el.key : null);
    final oldKey = old is UiFbField ? old.key : (old is UiFbGroup ? old.key : null);
    final elHistory = el is UiFbField ? el.keyHistory : (el is UiFbGroup ? el.keyHistory : null);
    final oldHistory = old is UiFbField ? old.keyHistory : (old is UiFbGroup ? old.keyHistory : null);
    if ((el is UiFbField || el is UiFbGroup) && (old is UiFbField || old is UiFbGroup)) {
      final history = _mergeHistory(ownKey, [elHistory, oldHistory, if (oldKey != null) [oldKey]]);
      if (history.isNotEmpty) {
        if (el is UiFbField) el.keyHistory = history;
        if (el is UiFbGroup) el.keyHistory = history;
      }
    }
    if (el is UiFbField && old is UiFbField && (old.options ?? const []).isNotEmpty) {
      final have = {for (final o in el.options ?? const <UiFbOption>[]) o.value};
      final extra = [
        for (final o in old.options!)
          if (!have.contains(o.value)) UiFbOption.fromJson(o.toJson())..archived = true,
      ];
      if (extra.isNotEmpty) el.options = [...(el.options ?? const <UiFbOption>[]), ...extra];
    }
  }

  // Elements only the current draft has: kept, archived.
  final lastPage = out.pages.isEmpty ? null : out.pages.last;
  void place(UiFbElement el, String pageId, String? groupId) {
    final group = groupId == null ? null : resultById[groupId];
    final into = group is UiFbGroup ? group.elements : null;
    final page = out.pages.where((p) => p.id == pageId).firstOrNull ?? lastPage;
    final list = into ?? page?.elements;
    final copy = _archivedCopy(el, targetIds);
    list?.add(copy);
    _walk([copy], (e) => resultById[e.id] = e);
  }

  void collect(List<UiFbElement> elements, String pageId, String? groupId) {
    for (final el in elements) {
      if (!targetIds.contains(el.id)) {
        place(el, pageId, groupId);
      } else if (el is UiFbGroup) {
        collect(el.elements, pageId, el.id);
      }
    }
  }

  for (final p in current.pages) {
    collect(p.elements, p.id, null);
  }
  return out;
}

// ── In-memory store ──────────────────────────────────────────────────────────────────────────

/// A synchronous revision store for demos, tests and small apps. It is a [ChangeNotifier] and
/// [all] / [revisions] are [ValueListenable]s, so a widget can rebuild when a version is saved.
///
/// The package has no storage layer, so keeping the history across restarts takes a [load] / [save]
/// pair (the web store's `storageKey` keeps it in `localStorage`): [load] returns the JSON text
/// [save] was last given, or null; both may throw (blocked or full storage), the history then stays in memory.
class UiFbMemoryRevisionStore extends ChangeNotifier implements UiFbRevisionStore {
  UiFbMemoryRevisionStore({String? Function()? load, this._save}) {
    if (load != null) _all.value = _read(load);
  }

  final void Function(String json)? _save;
  final ValueNotifier<List<UiFbRevision>> _all = ValueNotifier(const []);
  final Map<String, _Derived> _derived = {};

  /// Every stored revision of every form (for widgets that react to changes).
  ValueListenable<List<UiFbRevision>> get all => _all;

  /// The form's revisions, newest first, as a listenable.
  ValueListenable<List<UiFbRevision>> revisions(String formId) => _derived.putIfAbsent(formId, () => _Derived(_all, formId));

  @override
  List<UiFbRevision> listRevisions(String formId) => revisions(formId).value;

  @override
  UiFbRevision? getRevision(String formId, int revision) => _all.value.where((r) => r.formId == formId && r.revision == revision).firstOrNull;

  @override
  void saveRevision(UiFbRevision entry) {
    final copy = entry.clone();
    _all.value = [
      for (final r in _all.value)
        if (!(r.formId == copy.formId && r.revision == copy.revision)) r,
      copy,
    ];
    _persist();
    notifyListeners();
  }

  @override
  UiFormDefinition rollback(String formId, int targetRevision, [UiFormDefinition? current]) {
    final target = getRevision(formId, targetRevision);
    if (target == null) throw UiFbRevisionError('Version $targetRevision of this form was not found.');
    final base = current ?? listRevisions(formId).firstOrNull?.definition ?? target.definition;
    return rollbackDefinition(target.definition, base);
  }

  /// Forgets the history of one form, or of every form.
  void clear([String? formId]) {
    _all.value = formId == null ? const [] : [for (final r in _all.value) if (r.formId != formId) r];
    _persist();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final d in _derived.values) {
      d.dispose();
    }
    _all.dispose();
    super.dispose();
  }

  List<UiFbRevision> _read(String? Function() load) {
    try {
      final raw = load();
      final parsed = raw == null || raw.isEmpty ? const [] : jsonDecode(raw);
      return parsed is List ? [for (final x in parsed) UiFbRevision.fromJson(x)] : const [];
    } catch (_) {
      return const [];
    }
  }

  void _persist() {
    final save = _save;
    if (save == null) return;
    try {
      save(jsonEncode([for (final r in _all.value) r.toJson()]));
    } catch (_) {
      // Storage full or blocked: keep it in memory.
    }
  }
}

/// One form's revisions, newest first, recomputed when the store's list changes.
class _Derived extends ChangeNotifier implements ValueListenable<List<UiFbRevision>> {
  _Derived(this._source, this._formId) {
    _source.addListener(_changed);
  }

  final ValueListenable<List<UiFbRevision>> _source;
  final String _formId;
  List<UiFbRevision>? _cached;

  void _changed() {
    _cached = null;
    notifyListeners();
  }

  @override
  List<UiFbRevision> get value => _cached ??= List<UiFbRevision>.unmodifiable(_source.value.where((r) => r.formId == _formId).toList()..sort((x, y) => y.revision.compareTo(x.revision)));

  @override
  void dispose() {
    _source.removeListener(_changed);
    super.dispose();
  }
}
