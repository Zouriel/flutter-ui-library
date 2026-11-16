import 'package:flutter/widgets.dart';

import '../engine/calc.dart';
import '../engine/conditions.dart';
import '../engine/definition.dart';
import '../engine/field_types.dart';
import '../engine/format.dart';
import '../engine/js.dart';
import '../engine/localize.dart';
import '../engine/option_sources.dart';
import '../engine/schema.dart';
import '../engine/validators.dart';

/// Something a rule can ask about: a field, a section or a page.
class UiFbRefOption {
  const UiFbRefOption({required this.id, required this.label, required this.kind, required this.where});
  final String id;
  final String label;
  final UiFbSubjectKind kind;

  /// Where it is, for telling same-named things apart.
  final String where;
}

const int _historyLimit = 200;

/// Edits to the same setting within this window undo together (typing a label).
const Duration _mergeWindow = Duration(milliseconds: 1200);

/// Whether two definitions are the same form with the same content. `revision` is host metadata
/// (bumped on publish) and is ignored.
bool sameForm(UiFormDefinition a, UiFormDefinition b) {
  if (identical(a, b)) return true;
  if (a.id != b.id) return false;
  final ja = a.toJson()..remove('revision');
  final jb = b.toJson()..remove('revision');
  return jsonEquals(ja, jb);
}

/// Undo and redo step through content; the revision the host gave the form stays as it is now.
UiFormDefinition _keepRevision(UiFormDefinition target, UiFormDefinition current) {
  if (target.revision == current.revision) return target;
  return target.clone()..revision = current.revision;
}

/// [value] without [code]'s entries in any text map (a map whose values are all strings and that
/// has [code] as a key). A map left with only the default locale collapses to a plain string.
Object? _stripLocale(Object? value, String code, String def) {
  if (value is List) return [for (final v in value) _stripLocale(v, code, def)];
  if (value is! Map) return value;
  final out = <String, Object?>{};
  for (final e in value.entries) {
    final k = '${e.key}';
    final v = e.value;
    if (k == 'supportedLocales') {
      out[k] = v;
    } else if (v is Map && v.containsKey(code) && v.values.every((x) => x is String)) {
      final rest = {for (final x in v.entries) if (x.key != code) '${x.key}': x.value as String};
      out[k] = rest.isEmpty ? '' : (rest.length == 1 && rest.keys.first == def ? rest[def] : rest);
    } else {
      out[k] = _stripLocale(v, code, def);
    }
  }
  return out;
}

int _builderSeq = 0;

/// The form builder's state (the web `FbBuilderStore`): the definition being edited, what's
/// selected, and undo/redo. Every change goes through [commit] so it can be undone.
///
/// [UiFormBuilder] makes one for itself; pass your own to drive it from outside (select, undo,
/// read [problems] or [diff] before publishing). Definitions are never changed in place: each edit
/// commits a new copy, so the one you were handed stays as it was.
class UiFormBuilderController extends ChangeNotifier {
  UiFormBuilderController({UiFormDefinition? definition, DateTime Function()? clock})
    : _def = definition != null ? migrateDefinition(definition) : createDefinition(),
      _clock = clock ?? DateTime.now;

  /// Prefix for ids, unique per builder.
  final String uid = 'fb${++_builderSeq}';
  final DateTime Function() _clock;

  UiFormDefinition _def;
  UiFormDefinition? _published;
  int _submissionCount = 0;
  List<UiFbValidatorDef> _validatorDefs = uiFbBuiltinValidators;
  List<UiFbOptionSourceDef> _optionSourceDefs = const [];
  String? _selectedId;
  int _pageIndex = 0;
  String? _editLocaleRaw;

  /// Bumped on every change, including ones the host configures silently, so the scope rebuilds.
  int _epoch = 0;

  final List<UiFormDefinition> _past = [];
  final List<UiFormDefinition> _future = [];
  ({String key, DateTime at})? _lastMerge;

  // Caches, per definition.
  UiFbIndex? _index;
  List<UiFbProblem>? _problems;
  UiFbDiff? _diff;
  bool _diffDone = false;

  void _changed({bool notify = true}) {
    _index = null;
    _problems = null;
    _diff = null;
    _diffDone = false;
    _epoch++;
    if (notify) notifyListeners();
  }

  int get epoch => _epoch;

  /// The form being built.
  UiFormDefinition get def => _def;

  /// The version people are answering now; drives "this field has answers" warnings.
  UiFormDefinition? get published => _published;
  int get submissionCount => _submissionCount;
  List<UiFbValidatorDef> get validatorDefs => _validatorDefs;

  /// Lists the app can search.
  List<UiFbOptionSourceDef> get optionSourceDefs => _optionSourceDefs;

  /// An element id, a page id, or null for the form itself.
  String? get selectedId => _selectedId;
  int get pageIndex => _pageIndex;

  bool get canUndo => _past.isNotEmpty;
  bool get canRedo => _future.isNotEmpty;

  /// Sets what the host knows (published copy, answer count, checks, lists). [notify] false is for
  /// calls made while building (the builder rebuilds its scope anyway).
  void configure({
    UiFormDefinition? published,
    bool clearPublished = false,
    int? submissionCount,
    List<UiFbValidatorDef>? validatorDefs,
    List<UiFbOptionSourceDef>? optionSourceDefs,
    bool notify = true,
  }) {
    if (published != null || clearPublished) _published = published;
    if (submissionCount != null) _submissionCount = submissionCount;
    if (validatorDefs != null) _validatorDefs = validatorDefs;
    if (optionSourceDefs != null) _optionSourceDefs = optionSourceDefs;
    _changed(notify: notify);
  }

  set published(UiFormDefinition? v) => configure(published: v, clearPublished: v == null);
  set submissionCount(int v) => configure(submissionCount: v);
  set validatorDefs(List<UiFbValidatorDef> v) => configure(validatorDefs: v);
  set optionSourceDefs(List<UiFbOptionSourceDef> v) => configure(optionSourceDefs: v);

  // ── Languages ───────────────────────────────────────────────────────────────────────────

  /// The languages of the form, the default one first.
  List<UiFbResolvedLocale> get locales => fbLocales(_def);
  String get defaultLocale => fbDefaultLocale(_def);

  /// Whether the form has more than one language.
  bool get multilingual => locales.length > 1;

  /// The language being written now. Falls back to the default when the chosen one is gone.
  String get editLocale {
    final raw = _editLocaleRaw;
    return raw != null && locales.any((l) => l.code == raw) ? raw : defaultLocale;
  }

  /// Direction of the default language (for the hint under a translation input).
  UiFbDir get defaultDir => fbLocaleDir(_def, defaultLocale);

  /// Writing direction of the edit language.
  UiFbDir get editDir => fbLocaleDir(_def, editLocale);

  /// Whether the edit language is not the default one (so the default text is shown as a hint).
  bool get translating => editLocale != defaultLocale;

  void setEditLocale(String code) {
    _editLocaleRaw = locales.any((l) => l.code == code) ? code : null;
    _changed();
  }

  /// [t] in the edit language with no fallback: '' when it isn't translated yet. For inputs.
  String text(UiFbText? t) => fbTextIn(t, editLocale, defaultLocale);

  /// The default language's text, for the hint under an input while translating ('' when editing the default).
  String defaultText(UiFbText? t) => translating ? fbText(t, defaultLocale, defaultLocale) : '';

  /// [t] as it shows on the canvas: the edit language, falling back to the default.
  String shown(UiFbText? t) => fbText(t, editLocale, defaultLocale);

  /// [current] with the edit language's text set to [value].
  UiFbText setText(UiFbText? current, String value) => fbSetText(current, editLocale, value, defaultLocale);

  /// Like [setText], but null when the result is empty (an optional text left blank).
  UiFbText? setTextOpt(UiFbText? current, String value) {
    final t = setText(current, value);
    return t.plain == '' ? null : t;
  }

  /// Adds a language; false when the code is empty or already there.
  bool addLocale(String code, {String? label, UiFbDir? dir}) {
    code = code.trim();
    if (code.isEmpty || locales.any((l) => l.code.toLowerCase() == code.toLowerCase())) return false;
    final all = locales;
    final next = _def.clone()
      ..defaultLocale = all.first.code
      ..supportedLocales = [
        for (final l in all) UiFbLocale(code: l.code, label: l.label, dir: l.dir),
        UiFbLocale(code: code, label: label != null && label.trim().isNotEmpty ? label.trim() : null, dir: dir ?? fbDefaultDir(code)),
      ];
    commit(next);
    return true;
  }

  /// Removes a language and its text from every question, as one undoable edit.
  void removeLocale(String code) {
    if (code == defaultLocale || !locales.any((l) => l.code == code)) return;
    final json = _def.clone()..supportedLocales = [for (final l in locales) if (l.code != code) UiFbLocale(code: l.code, label: l.label, dir: l.dir)];
    final stripped = _stripLocale(json.toJson(), code, defaultLocale);
    commit(migrateDefinition(stripped!));
  }

  void setDefaultLocale(String code) {
    if (!locales.any((l) => l.code == code) || code == defaultLocale) return;
    final all = locales;
    commit(_def.clone()
      ..defaultLocale = code
      ..supportedLocales = [for (final l in all) UiFbLocale(code: l.code, label: l.label, dir: l.dir)]);
  }

  void setLocaleDir(String code, UiFbDir dir) {
    commit(_def.clone()..supportedLocales = [for (final l in locales) UiFbLocale(code: l.code, label: l.label, dir: l.code == code ? dir : l.dir)]);
  }

  // ── Derived ─────────────────────────────────────────────────────────────────────────────

  UiFbIndex get index => _index ??= indexDefinition(_def);

  /// Problems from the definition, plus sourced fields whose list this app doesn't offer or whose
  /// required settings are empty.
  List<UiFbProblem> get problems => _problems ??= [...lintDefinition(_def), ..._sourceProblems()];

  List<UiFbProblem> _sourceProblems() {
    final out = <UiFbProblem>[];
    for (final e in index.values) {
      final f = e.asField;
      if (f == null || f.source == null || f.archived == true) continue;
      final src = f.source!;
      final d = _optionSourceDefs.where((d) => d.type == src.type).firstOrNull;
      final name = '“${this.name(f.id)}”';
      if (d == null) {
        out.add(UiFbProblem(severity: 'error', targetId: f.id, message: '$name uses a data source this app doesn’t provide (“${src.type}”). Pick another, or switch to a typed list.'));
        continue;
      }
      for (final p in d.params ?? const <UiFbSourceParamSpec>[]) {
        final v = src.params?[p.key];
        final set = switch (v) {
          UiFbRefOperand(:final ref) => ref.isNotEmpty,
          UiFbConstOperand(:final value) => value != null && value != '',
          _ => false,
        };
        if (p.required && !set) out.add(UiFbProblem(severity: 'error', targetId: f.id, message: '$name needs “${p.label}” set for its ${d.label} list.'));
      }
    }
    return out;
  }

  /// Ids of elements with an error.
  Set<String> get problemIds => {for (final p in problems) if (p.severity == 'error') p.targetId};

  /// How many errors there are.
  int get errorCount => problems.where((p) => p.severity == 'error').length;

  UiFbPage get page => _def.pages[_pageIndex.clamp(0, _def.pages.length - 1)];
  UiFbIndexEntry? get selected => _selectedId == null ? null : index[_selectedId];

  /// What changed since [published], or null when nothing is published.
  UiFbDiff? get diff {
    if (!_diffDone) {
      _diff = _published == null ? null : diffDefinitions(_published!, _def);
      _diffDone = true;
    }
    return _diff;
  }

  /// Whether the form already has answers (so some changes need care).
  bool get live => _published != null && _submissionCount > 0;

  // ── History ─────────────────────────────────────────────────────────────────────────────

  /// Takes a definition from the host. A different form (another id, or other content) replaces
  /// the builder's and clears history. The same form handed back with only its `revision` changed
  /// (the host stored a published copy) is adopted and history is kept, so undo still works after
  /// publishing. [notify] false is for calls made while building.
  void load(Object raw, {bool notify = true}) {
    if (identical(raw, _def)) return;
    final next = migrateDefinition(raw);
    if (sameForm(next, _def)) {
      _def = next;
      _changed(notify: notify);
      return;
    }
    _def = next;
    _past.clear();
    _future.clear();
    _lastMerge = null;
    _index = null;
    if (_selectedId != null && !index.containsKey(_selectedId)) _selectedId = null;
    _pageIndex = _pageIndex.clamp(0, next.pages.length - 1);
    _changed(notify: notify);
  }

  /// Replaces the whole definition as ONE undoable edit (restoring a revision), keeping the host's `revision`.
  void replace(Object raw) {
    final next = _keepRevision(migrateDefinition(raw), _def);
    commit(next);
    if (_selectedId != null && !index.containsKey(_selectedId)) _selectedId = null;
    if (_pageIndex >= _def.pages.length) _pageIndex = _def.pages.length - 1;
    _changed();
  }

  /// Forgets undo/redo history (e.g. the host saved and wants a fresh start).
  void clearHistory() {
    _past.clear();
    _future.clear();
    _lastMerge = null;
    _changed();
  }

  /// Applies a change. Changes with the same [mergeKey] in quick succession undo as one.
  void commit(UiFormDefinition next, {String? mergeKey}) {
    if (identical(next, _def)) return;
    final now = _clock();
    final last = _lastMerge;
    final merge = mergeKey != null && last != null && last.key == mergeKey && now.difference(last.at) < _mergeWindow;
    if (!merge) {
      _past.add(_def);
      if (_past.length > _historyLimit) _past.removeAt(0);
    }
    _lastMerge = mergeKey != null ? (key: mergeKey, at: now) : null;
    _future.clear();
    _def = next;
    _changed();
  }

  void undo() {
    if (_past.isEmpty) return;
    final prev = _past.removeLast();
    _future.add(_def);
    _def = _keepRevision(prev, _def);
    _afterTravel();
  }

  void redo() {
    if (_future.isEmpty) return;
    final next = _future.removeLast();
    _past.add(_def);
    _def = _keepRevision(next, _def);
    _afterTravel();
  }

  void _afterTravel() {
    _lastMerge = null;
    _index = null;
    if (_selectedId != null && !index.containsKey(_selectedId)) _selectedId = null;
    if (_pageIndex >= _def.pages.length) _pageIndex = _def.pages.length - 1;
    _changed();
  }

  // ── Selection ───────────────────────────────────────────────────────────────────────────

  /// Selects an element or page (null for the form) and shows its page.
  void select(String? id) {
    _selectedId = id;
    final entry = id == null ? null : index[id];
    if (entry != null) _pageIndex = entry.pageIndex;
    _changed();
  }

  /// Shows another page, selecting nothing.
  void showPage(int i) {
    _pageIndex = i.clamp(0, _def.pages.length - 1);
    _selectedId = null;
    _changed();
  }

  // ── Elements ────────────────────────────────────────────────────────────────────────────

  /// Where a new element goes: inside a selected section, right after the selection, or at the end
  /// of the current page.
  UiFbDropTarget defaultTarget() {
    final sel = selected;
    if (sel != null && sel.kind == 'group' && sel.asGroup!.archived != true) {
      return UiFbDropTarget(containerId: sel.id, index: sel.asGroup!.elements.length);
    }
    if (sel != null && sel.kind != 'page') return UiFbDropTarget(containerId: sel.parentId, index: sel.index + 1);
    return UiFbDropTarget(containerId: page.id, index: page.elements.length);
  }

  /// Adds [el] at [target] (default: [defaultTarget]) and selects it.
  void add(UiFbElement el, [UiFbDropTarget? target]) {
    var to = target ?? defaultTarget();
    if (!canDrop(_def, el, to.containerId)) to = UiFbDropTarget(containerId: page.id, index: page.elements.length);
    commit(insertElement(_def, el, to));
    select(el.id);
  }

  /// Moves an element; false when nothing changed.
  bool move(String id, UiFbDropTarget target) {
    final next = moveElement(_def, id, target);
    if (identical(next, _def)) return false;
    commit(next);
    return true;
  }

  /// Moves up/down among its siblings; at the edge of a section it steps out of it.
  bool nudge(String id, int delta) {
    final e = index[id];
    if (e == null || e.kind == 'page') return false;
    final parent = index[e.parentId];
    final siblings = parent?.kind == 'page' ? (parent!.element as UiFbPage).elements : parent?.asGroup?.elements ?? const <UiFbElement>[];
    final to = e.index + delta;
    if (to >= 0 && to < siblings.length) return move(id, UiFbDropTarget(containerId: e.parentId, index: delta > 0 ? to + 1 : to));
    if (parent?.kind == 'group') return move(id, UiFbDropTarget(containerId: parent!.parentId, index: delta > 0 ? parent.index + 1 : parent.index));
    return false;
  }

  void duplicate(String id) {
    final r = duplicateElement(_def, id);
    commit(r.def);
    select(r.id);
  }

  /// Deletes an element and any rules that mention it or anything inside it.
  void remove(String id) {
    final ids = subtreeIds(_def, id);
    commit(removeReferences(removeElement(_def, id), ids));
    if (ids.contains(_selectedId)) {
      _selectedId = null;
      _changed();
    }
  }

  void setArchived(String id, bool archived) => updateAny(id, (el) {
    if (el is UiFbField) el.archived = archived ? true : null;
    if (el is UiFbGroup) el.archived = archived ? true : null;
    if (el is UiFbStatic) el.archived = archived ? true : null;
  });

  /// Changes a field: [edit] gets a copy to change in place.
  void updateField(String id, void Function(UiFbField f) edit, {String? mergeKey}) =>
      commit(updateElement(_def, id, (el) => el is UiFbField ? (el..let(edit)) : el), mergeKey: mergeKey);

  void updateGroup(String id, void Function(UiFbGroup g) edit, {String? mergeKey}) =>
      commit(updateElement(_def, id, (el) => el is UiFbGroup ? (el..let(edit)) : el), mergeKey: mergeKey);

  void updateStatic(String id, void Function(UiFbStatic s) edit, {String? mergeKey}) =>
      commit(updateElement(_def, id, (el) => el is UiFbStatic ? (el..let(edit)) : el), mergeKey: mergeKey);

  /// Changes any element (field, group or static), for settings they share.
  void updateAny(String id, void Function(UiFbElement el) edit, {String? mergeKey}) =>
      commit(updateElement(_def, id, (el) => el..let(edit)), mergeKey: mergeKey);

  /// Retitles a section. Like a question's key following its label, a section's key follows its
  /// title while it still has the key it was given automatically and no answers are saved under it.
  void setGroupTitle(String id, String value) {
    final g = index[id]?.asGroup;
    if (g == null) return;
    final dl = defaultLocale;
    final title = setText(g.title, value);
    // The key follows the default-language title only.
    final cur = fbTextIn(g.title, dl, dl);
    final base = cur.isNotEmpty ? cur : fbText(g.title, dl, dl);
    final slug = fbSlug(base.isNotEmpty ? base : (g.repeat != null ? 'items' : 'section'));
    String stem(String k) => k.replaceFirst(RegExp(r'_\d+$'), '');
    final key = g.key;
    final auto = key != null && key.isNotEmpty && !hasAnswers(id) && (stem(key) == 'items' || stem(key) == slug || stem(key) == 'section');
    final next = auto && !translating && value.trim().isNotEmpty ? uniqueKey(_def, fbSlug(value), id) : key;
    updateGroup(id, (g) {
      g.title = title.plain == '' ? null : title;
      g.key = next;
    }, mergeKey: 'title:$id');
  }

  void rename(String id, String key) => commit(renameKey(_def, id, key), mergeKey: 'key:$id');

  // ── Pages and form ──────────────────────────────────────────────────────────────────────

  void updatePage(String id, void Function(UiFbPage p) edit, {String? mergeKey}) =>
      commit(updatePageOf(_def, id, edit), mergeKey: mergeKey);

  void addPage() {
    final p = createPage()..title = UiFbText('Page ${_def.pages.length + 1}');
    final next = _def.clone();
    // A form that had one untitled page gets a title on it, now that there are steps.
    if (next.pages.length == 1 && fbText(next.pages[0].title).isEmpty) next.pages[0].title = const UiFbText('Page 1');
    next.pages.add(p);
    commit(next);
    _pageIndex = _def.pages.length - 1;
    select(p.id);
  }

  void removePage(String id) {
    if (_def.pages.length < 2) return;
    final ids = subtreeIds(_def, id);
    final next = _def.clone()..pages.removeWhere((p) => p.id == id);
    commit(removeReferences(next, ids));
    _pageIndex = _pageIndex.clamp(0, _def.pages.length - 1);
    _selectedId = null;
    _changed();
  }

  void movePage(String id, int delta) {
    final i = _def.pages.indexWhere((p) => p.id == id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= _def.pages.length) return;
    final next = _def.clone();
    final p = next.pages.removeAt(i);
    next.pages.insert(j, p);
    commit(next);
    _pageIndex = j;
    _changed();
  }

  void updateForm({UiFbText? title, UiFbText? description, bool clearDescription = false, String? mergeKey}) {
    final next = _def.clone();
    if (title != null) next.title = title;
    if (description != null || clearDescription) next.description = description;
    commit(next, mergeKey: mergeKey);
  }

  /// Changes the form's settings; [edit] gets a copy.
  void updateSettings(void Function(UiFbSettings s) edit, {String? mergeKey}) {
    final next = _def.clone();
    edit(next.settings ??= UiFbSettings());
    commit(next, mergeKey: mergeKey);
  }

  // ── Questions about the form ────────────────────────────────────────────────────────────

  String name(String id) {
    final e = index[id];
    return e != null ? elementName(e.element, _def, editLocale) : 'Deleted question';
  }

  UiFbField? field(String id) => index[id]?.asField;

  /// Whether answers already exist for an element (so deleting it would lose them).
  bool hasAnswers(String id) => live && indexDefinition(_published!).containsKey(id);

  List<UiFbReference> externalRefs(String id) => externalReferences(_def, id);

  /// Words for a condition, using labels people recognise.
  String describe(UiFbCondition? c) => describeCondition(
    c,
    UiFbDescribeFns(
      name: name,
      value: (ref, v) {
        final f = field(ref);
        if (f == null) return jsString(v);
        final s = formatValue(f, v);
        return s.isNotEmpty ? s : jsString(v);
      },
    ),
  );

  String describeCalcOf(UiFbField f) => describeCalc(f.calc, name);

  /// What a rule on element [forId] may ask about: every field outside it, plus sections and
  /// pages. Fields inside a repeating section can only be asked about from inside the same section
  /// (they have one answer per entry).
  List<UiFbRefOption> refOptions(String? forId) {
    final idx = index;
    final me = forId == null ? null : idx[forId];
    // Its own contents and the sections around it would make a loop.
    final own = {...(forId != null ? subtreeIds(_def, forId) : const <String>[]), ...?me?.groups.map((g) => g.id)};
    final myRepeat = me?.kind == 'group' && me!.asGroup!.repeat != null ? me.asGroup : me?.repeat;
    final out = <UiFbRefOption>[];
    for (final e in idx.values) {
      if (own.contains(e.id) && e.id != forId) continue;
      if (e.id == forId && e.kind == 'field') continue;
      final el = e.asElement;
      if (el != null && el.archived == true) continue;
      final where = elementName(e.page, _def, editLocale);
      if (e.kind == 'page') {
        if (_def.pages.length > 1 && e.id != forId) out.add(UiFbRefOption(id: e.id, label: elementName(e.element, _def, editLocale), kind: UiFbSubjectKind.page, where: 'Page'));
        continue;
      }
      if (e.repeat != null && e.repeat!.id != myRepeat?.id) continue;
      if (e.kind == 'group') {
        if (e.id == forId) continue;
        out.add(UiFbRefOption(id: e.id, label: elementName(el, _def, editLocale), kind: e.asGroup!.repeat != null ? UiFbSubjectKind.repeat : UiFbSubjectKind.group, where: where));
      } else if (e.kind == 'field') {
        final f = e.asField!;
        out.add(UiFbRefOption(id: e.id, label: shown(f.label).isNotEmpty ? shown(f.label) : f.key, kind: valueKindOf(f.type, f.props?.format).subject, where: where));
      }
    }
    return out;
  }

  /// Checks that make sense for a field.
  List<UiFbValidatorDef> validatorsForField(UiFbField f) => validatorsFor(f.type, f.props?.format, _validatorDefs);
}

/// `updatePage` from the engine, under a name that doesn't clash with the controller's method.
UiFormDefinition updatePageOf(UiFormDefinition def, String id, void Function(UiFbPage p) edit) => updatePage(def, id, (p) => p..let(edit));

extension _Let<T> on T {
  void let(void Function(T it) fn) => fn(this);
}

/// Gives the builder's panels their [UiFormBuilderController]. [UiFormBuilder] puts one in place;
/// wrap a panel in your own to use it on its own.
class UiFbBuilderScope extends StatefulWidget {
  const UiFbBuilderScope({super.key, required this.controller, required this.child});

  final UiFormBuilderController controller;
  final Widget child;

  /// The nearest controller; the caller rebuilds on every change.
  static UiFormBuilderController of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<_FbInherited>();
    assert(s != null, 'No UiFbBuilderScope above this builder panel');
    return s!.controller;
  }

  /// The nearest controller, or null outside a builder (the form-wide settings panel also works alone).
  static UiFormBuilderController? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_FbInherited>()?.controller;

  @override
  State<UiFbBuilderScope> createState() => _UiFbBuilderScopeState();
}

class _UiFbBuilderScopeState extends State<UiFbBuilderScope> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(UiFbBuilderScope old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) => _FbInherited(controller: widget.controller, epoch: widget.controller.epoch, child: widget.child);
}

class _FbInherited extends InheritedWidget {
  const _FbInherited({required this.controller, required this.epoch, required super.child});
  final UiFormBuilderController controller;
  final int epoch;

  @override
  bool updateShouldNotify(_FbInherited old) => old.controller != controller || old.epoch != epoch;
}
