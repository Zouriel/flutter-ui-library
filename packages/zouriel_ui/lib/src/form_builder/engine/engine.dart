import 'dart:async';
import 'dart:math' as math;

import 'calc.dart';
import 'conditions.dart';
import 'definition.dart';
import 'field_types.dart';
import 'js.dart';
import 'option_sources.dart';
import 'schema.dart';
import 'validators.dart';

/// `create` starts fresh (defaults apply), `edit` opens saved answers, `view` only shows them.
enum UiFormMode { create, edit, view }

/// One rendered copy of an element: top-level, or inside one entry of a repeatable group.
class UiFbInstance {
  const UiFbInstance({required this.id, required this.row, required this.addr});
  final String id;

  /// The repeat entry it belongs to, or `null`.
  final String? row;

  /// `id`, or `row/id` inside a repeat entry. Unique per rendered copy.
  final String addr;
}

class UiFbInstanceState {
  const UiFbInstanceState({
    required this.visible,
    required this.disabled,
    required this.required,
    required this.value,
    this.errors = const [],
    this.warnings = const [],
    this.pending = false,
  });

  static const hidden = UiFbInstanceState(visible: false, disabled: false, required: false, value: null);

  final bool visible;
  final bool disabled;
  final bool required;

  /// The answer, with calculations worked out.
  final Object? value;
  final List<String> errors;
  final List<String> warnings;

  /// An async check is still running.
  final bool pending;

  UiJson toJson() => {'visible': visible, 'disabled': disabled, 'required': required, 'value': value, 'errors': errors, 'warnings': warnings, 'pending': pending};

  @override
  String toString() => 'UiFbInstanceState(${toJson()})';
}

/// An entry taken out of a repeatable group, kept so it can be put back.
class UiFbRemovedRow {
  const UiFbRemovedRow({required this.groupId, required this.rowId, required this.index, required this.values});
  final String groupId;
  final String rowId;
  final int index;
  final Map<String, Object?> values;
}

class UiFbErrorItem {
  const UiFbErrorItem({required this.addr, required this.id, required this.row, required this.label, required this.message});
  final String addr;
  final String id;
  final String? row;
  final String label;
  final String message;

  UiJson toJson() => {'addr': addr, 'id': id, 'row': row, 'label': label, 'message': message};
}

/// The settings the engine runs with (the form's own, with defaults filled in).
class UiFbEngineSettings {
  const UiFbEngineSettings({required this.validateOn, required this.clearHidden, required this.errorSummary, required this.requiredMarker});

  /// `blur` or `submit`.
  final String validateOn;

  /// `onSubmit` or `never`.
  final String clearHidden;
  final bool errorSummary;

  /// `asterisk`, `optional` or `none`.
  final String requiredMarker;
}

class _PendingCheck {
  _PendingCheck(this.key, this.hash, this.rule, this.def, this.value, this.ctx);
  final String key;
  final String hash;
  final UiFbValidatorRule rule;
  final UiFbValidatorDef def;
  final Object? value;
  final UiFbValidatorContext ctx;
}

class _EvalResult {
  _EvalResult(this.states, this.path, this.complete, this.checks);
  final Map<String, UiFbInstanceState> states;

  /// Indexes of pages on the current route through the form.
  final List<int> path;
  final bool Function(String id, String? row) complete;
  final List<_PendingCheck> checks;
}

class _Inflight {
  _Inflight(this.hash, this.abort);
  final String hash;
  final UiFbAbortController abort;
  Timer? timer;
}

/// "Email is required." — or, for a label that is a question, "Answer “Are you a student?”".
String requiredMessage(UiFbField f, String label) {
  if (label.trim().endsWith('?')) return 'Answer “{label}”';
  if (valueKindOf(f.type) == UiFbValueKind.boolean && f.type == UiFbFieldType.checkbox) return '{label} must be ticked.';
  return '{label} is required.';
}

String addrOf(String id, String? row) => row != null && row.isNotEmpty ? '$row/$id' : id;

bool _isObj(Object? v) => v is Map;

/// Normalises a stored or typed answer to the shape its field type uses.
Object? coerceValue(UiFbField field, Object? v) {
  final kind = valueKindOf(field.type, field.props?.format);
  if (v == null) return kind == UiFbValueKind.multi || kind == UiFbValueKind.file ? <Object?>[] : null;
  switch (kind) {
    case UiFbValueKind.number:
      if (field.type == UiFbFieldType.calculated) return v;
      final n = v is num ? v.toDouble() : jsNumber(v);
      return v == '' || !n.isFinite ? null : tidyNum(n);
    case UiFbValueKind.boolean:
      return v == true || v == 'true' || (v is num && v == 1);
    case UiFbValueKind.multi:
      final list = v is List ? v : [v];
      // Sourced answers keep { value, label }; typed lists keep plain values (and unwrap a saved choice).
      if (field.source != null) return list.map(toChoice).whereType<UiJson>().toList();
      return [for (final x in list) jsString(optionValueOf(x))];
    case UiFbValueKind.file:
      return v is List ? v : [v];
    case UiFbValueKind.choice:
      final one = v is List ? (v.isEmpty ? null : v[0]) : v;
      if (one == null || one == '') return null;
      return field.source != null ? toChoice(one) : jsString(optionValueOf(one));
    default:
      return v is String ? v : (v is List ? v.map((x) => x == null ? '' : jsString(x)).join(', ') : jsString(v));
  }
}

Object? _toJsonValue(Object? v) {
  if (v is List) return v;
  return isEmptyValue(v) ? null : v;
}

/// Looks up the first of [keys] present in [src].
(bool, Object?) _pick(Map<String, Object?>? src, List<String> keys) {
  if (src == null) return (false, null);
  for (final k in keys) {
    if (src.containsKey(k)) return (true, src[k]);
  }
  return (false, null);
}

const String _allRows = '*';

class _Ctx implements UiFbConditionContext, UiFbCalcContext {
  _Ctx({required this.valueFn, required this.valuesFn, required this.visibleFn, required this.completeFn, required this.rowsFn, required this.todayFn});
  final Object? Function(String) valueFn;
  final List<Object?> Function(String) valuesFn;
  final bool Function(String) visibleFn;
  final bool Function(String) completeFn;
  final int? Function(String) rowsFn;
  final String Function() todayFn;

  @override
  Object? value(String ref) => valueFn(ref);
  @override
  List<Object?> values(String ref) => valuesFn(ref);
  @override
  bool visible(String ref) => visibleFn(ref);
  @override
  bool complete(String ref) => completeFn(ref);
  @override
  int? rows(String ref) => rowsFn(ref);
  @override
  String today() => todayFn();
}

/// Runs a form: answers, rules, calculations, page route, repeat entries, validation and the JSON
/// that gets submitted. Pure Dart: the renderer is a thin view over it, and tests drive it directly.
///
/// The web version is built on Angular signals; here every change (an answer, an entry added, an
/// async check finishing) re-evaluates the form straight away, runs "set value" rules to a fixed
/// point, starts any async checks, then calls the listeners — the state a running web form is in
/// after its change detection.
class UiFormEngine {
  UiFormEngine({
    required UiFormDefinition definition,
    UiJson? data,
    UiFormMode? mode,
    List<UiFbValidatorDef> validators = const [],
    List<UiFbOptionSourceDef> optionSources = const [],
    String Function()? today,
    DateTime Function()? now,
  }) : definition = migrateDefinition(definition),
       mode = mode ?? (data != null ? UiFormMode.edit : UiFormMode.create),
       _today = today ?? todayIso,
       _now = now ?? DateTime.now,
       _initialData = data != null ? jsonCloneMap(data) : <String, Object?>{} {
    index = indexDefinition(this.definition);
    final s = this.definition.settings;
    settings = UiFbEngineSettings(
      validateOn: s?.validateOn ?? 'blur',
      clearHidden: s?.clearHidden ?? 'onSubmit',
      errorSummary: s?.errorSummary ?? true,
      requiredMarker: s?.requiredMarker ?? 'asterisk',
    );
    _validatorDefs = {for (final d in [...uiFbBuiltinValidators, ...validators]) d.type: d};
    _sourceDefs = {for (final d in optionSources) d.type: d};
    _load();
    // The first full picture (calculations included) is the "unchanged" baseline.
    _baseline = this.data;
    _settle();
  }

  /// Opens a form from stored JSON (migrated to the current schema).
  factory UiFormEngine.fromJson(
    Object? definition, {
    UiJson? data,
    UiFormMode? mode,
    List<UiFbValidatorDef> validators = const [],
    List<UiFbOptionSourceDef> optionSources = const [],
    String Function()? today,
    DateTime Function()? now,
  }) => UiFormEngine(
    definition: migrateDefinition(definition),
    data: data,
    mode: mode,
    validators: validators,
    optionSources: optionSources,
    today: today,
    now: now,
  );

  final UiFormDefinition definition;
  late final UiFbIndex index;
  final UiFormMode mode;
  late final UiFbEngineSettings settings;

  late final Map<String, UiFbValidatorDef> _validatorDefs;
  late final Map<String, UiFbOptionSourceDef> _sourceDefs;
  final String Function() _today;
  final DateTime Function() _now;
  final UiJson _initialData;

  Map<String, Object?> _values = {};
  Map<String, List<String>> _rowIds = {};
  final Map<String, ({String hash, String? result})> _asyncResults = {};
  final Set<String> _touched = {};
  final Set<String> _attempted = {};
  int _pageIndex = 0;

  /// Set by the renderer while a submission is being handed over.
  bool submitting = false;

  /// Files picked in this session, by field address.
  final Map<String, List<UiFbPickedFile>> files = {};

  int _rowSeq = 0;
  final Map<String, UiJson> _rowBase = {};
  final Set<String> _loaded = {};
  final Map<String, Object?> _initialValues = {};
  final Map<String, List<String>> _initialRows = {};
  final Set<String> _everShown = {};
  final Map<String, bool> _setValuePrev = {};
  final Map<String, _Inflight> _inflight = {};
  final Set<String> _asyncTypes = {};
  final List<void Function()> _listeners = [];
  Object? _baseline;
  _EvalResult? _state;
  bool _disposed = false;

  // ── Listening ──────────────────────────────────────────────────────────────────────────────

  /// Called after every change to the form's state (answers, entries, pages, async results).
  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);

  void _notify() {
    for (final l in [..._listeners]) {
      l();
    }
  }

  /// Stops async checks. The engine can still be read afterwards.
  void dispose() {
    _disposed = true;
    for (final f in _inflight.values) {
      f.abort.abort();
      f.timer?.cancel();
    }
    _inflight.clear();
    _listeners.clear();
  }

  // ── Loading ────────────────────────────────────────────────────────────────────────────────

  void _load() {
    final values = <String, Object?>{};
    final rows = <String, List<String>>{};
    final fresh = mode == UiFormMode.create;
    // `isNew`: nothing was saved here before, so defaults apply (always for hidden values).
    void loadEls(List<UiFbElement> els, Map<String, Object?>? src, String? row, bool isNew) {
      for (final el in els) {
        if (el is UiFbField) {
          final addr = addrOf(el.id, row);
          final (found, stored) = _pick(src, [el.key, ...?el.keyHistory]);
          if (found && !fresh) {
            values[addr] = coerceValue(el, stored);
            _loaded.add(addr);
          } else if (el.hasDefaultValue && (isNew || el.type == UiFbFieldType.hidden)) {
            values[addr] = coerceValue(el, jsonClone(el.defaultValue));
          }
          _initialValues[addr] = values[addr];
        } else if (el is UiFbGroup) {
          final hasKey = el.key != null && el.key!.isNotEmpty;
          final (subFound, sub) = hasKey ? _pick(src, [el.key!, ...?el.keyHistory]) : (src != null, src);
          final repeat = el.repeat;
          if (repeat != null) {
            final items = !fresh && sub is List ? sub : const <Object?>[];
            final ids = <String>[];
            for (final item in items) {
              final id = _newRowId();
              _rowBase[id] = _isObj(item) ? (item as Map).cast<String, Object?>() : <String, Object?>{};
              loadEls(el.elements, _isObj(item) ? (item as Map).cast<String, Object?>() : null, id, false);
              ids.add(id);
            }
            if (items.isNotEmpty) _loaded.add(addrOf(el.id, row));
            // New forms start with the minimum number of entries (at least one).
            final min = fresh ? math.max(1, (repeat.min ?? 0).toInt()) : (repeat.min ?? 0).toInt();
            while (ids.length < min) {
              final id = _newRowId();
              loadEls(el.elements, null, id, true);
              ids.add(id);
            }
            rows[el.id] = ids;
            _initialRows[el.id] = [...ids];
          } else {
            if (hasKey && subFound) _loaded.add(addrOf(el.id, row));
            final next = hasKey ? (_isObj(sub) ? (sub as Map).cast<String, Object?>() : null) : src;
            loadEls(el.elements, next, row, isNew);
          }
        }
      }
    }

    for (final p in definition.pages) {
      loadEls(p.elements, _initialData, null, fresh);
    }
    _values = values;
    _rowIds = rows;
  }

  String _newRowId() => 'r${(_rowSeq++).toRadixString(36)}';

  // ── Reacting ───────────────────────────────────────────────────────────────────────────────

  _EvalResult get _current => _state ??= _evaluate();

  /// Re-evaluates after a change: "set value" rules to a fixed point, then async checks.
  void _settle() {
    for (var i = 0; i < 32; i++) {
      if (!_applySetValues()) break;
    }
    _runChecks(_current.checks);
  }

  void _changed() {
    _state = null;
    _settle();
    _notify();
  }

  // ── Reading ────────────────────────────────────────────────────────────────────────────────

  /// Indexes (into `definition.pages`) of the pages on the current route.
  List<int> get path => _current.path;

  /// Index into `definition.pages` of the page being shown.
  int get pageIndex => _pageIndex;
  set pageIndex(int i) {
    _pageIndex = i;
    _notify();
  }

  UiFbPage get page => _pageIndex >= 0 && _pageIndex < definition.pages.length ? definition.pages[_pageIndex] : definition.pages[0];

  /// Position of the current page on the route, for "Step 2 of 4".
  int get step => math.max(0, path.indexOf(_pageIndex));

  bool get isLastPage => path.indexOf(_pageIndex) >= path.length - 1;

  /// Fields that have been left at least once (their errors show from then on), by address.
  Set<String> get touched => Set.unmodifiable(_touched);

  /// Pages someone tried to leave or submit (all their errors show), by page id.
  Set<String> get attempted => Set.unmodifiable(_attempted);

  UiFbInstanceState instanceState(String id, String? row) => _current.states[addrOf(id, row)] ?? UiFbInstanceState.hidden;

  /// The entry ids of a repeatable group, in order.
  List<String> rows(String groupId) => List.unmodifiable(_rowIds[groupId] ?? const <String>[]);

  Object? rawValue(String id, String? row) => _values[addrOf(id, row)];

  /// The registered source a field searches, if it has one and the app provides it.
  UiFbOptionSourceDef? optionSource(String? type) => type == null ? null : _sourceDefs[type];

  /// Another field's answer as seen from [row]: the same repeat entry when both are in it, the
  /// top-level answer otherwise, nothing for a repeat asked from outside.
  Object? answerFor(String ref, String? row) {
    final entry = index[ref];
    if (entry == null) return null;
    if (entry.repeat == null) return instanceState(ref, null).value;
    if (row == null || !(_rowIds[entry.repeat!.id] ?? const []).contains(row)) return null;
    return instanceState(ref, row).value;
  }

  /// A sourced field's settings with other answers filled in (as plain values), as the renderer
  /// passes them to the source's `search`.
  Map<String, Object?> sourceParams(String id, String? row) => {
    for (final e in (field(id)?.source?.params ?? const <String, UiFbOperand>{}).entries)
      e.key: optionValueOf(switch (e.value) {
        UiFbRefOperand(:final ref) => answerFor(ref, row),
        UiFbConstOperand(:final value) => value,
        UiFbTodayOperand() => null,
      }),
  };

  UiFbField? field(String id) => index[id]?.asField;

  /// Whether a field's errors should be on screen yet ("reward early, punish late").
  bool errorsShown(String id, String? row) {
    if (mode == UiFormMode.view) return false;
    final entry = index[id];
    if (entry != null && _attempted.contains(entry.page.id)) return true;
    return settings.validateOn == 'blur' && _touched.contains(addrOf(id, row));
  }

  /// Every rendered copy of the fields on a page, in order.
  List<UiFbInstance> instancesOn(int pageIdx) {
    final out = <UiFbInstance>[];
    void walk(List<UiFbElement> els, String? row) {
      for (final el in els) {
        if (el is UiFbField) {
          out.add(UiFbInstance(id: el.id, row: row, addr: addrOf(el.id, row)));
        } else if (el is UiFbGroup) {
          if (el.repeat != null) {
            for (final r in _rowIds[el.id] ?? const <String>[]) {
              walk(el.elements, r);
            }
          } else {
            walk(el.elements, row);
          }
        }
      }
    }

    if (pageIdx >= 0 && pageIdx < definition.pages.length) walk(definition.pages[pageIdx].elements, null);
    return out;
  }

  /// Errors on a page, in order, worded for the summary box.
  List<UiFbErrorItem> pageErrors(int pageIdx) {
    final states = _current.states;
    return [
      for (final inst in instancesOn(pageIdx))
        if (states[inst.addr] case final st? when st.visible && st.errors.isNotEmpty)
          UiFbErrorItem(addr: inst.addr, id: inst.id, row: inst.row, label: instanceLabel(inst.id, inst.row), message: st.errors[0]),
    ];
  }

  bool pagePending(int pageIdx) {
    final states = _current.states;
    return instancesOn(pageIdx).any((i) => states[i.addr]?.pending ?? false);
  }

  /// "Email" — or "Email (Dependant 2)" inside a repeat entry.
  String instanceLabel(String id, String? row) {
    final entry = index[id];
    final name = elementName(entry?.element);
    if (row == null || entry?.repeat == null) return name;
    final n = rows(entry!.repeat!.id).indexOf(row) + 1;
    final item = (entry.repeat!.repeat?.itemLabel ?? 'Entry {n}').replaceFirst('{n}', '$n');
    return '$name ($item)';
  }

  // ── Changing ───────────────────────────────────────────────────────────────────────────────

  void setValue(String id, String? row, Object? value) {
    if (mode == UiFormMode.view) return;
    final f = field(id);
    _values = {..._values, addrOf(id, row): f != null ? coerceValue(f, value) : value};
    _changed();
  }

  void markTouched(String id, String? row) {
    final a = addrOf(id, row);
    if (_touched.contains(a)) return;
    _touched.add(a);
    _notify();
  }

  bool canAddRow(String groupId) {
    final max = index[groupId]?.asGroup?.repeat?.max;
    return mode != UiFormMode.view && (max == null || rows(groupId).length < max);
  }

  bool canRemoveRow(String groupId) {
    final g = index[groupId]?.asGroup;
    return mode != UiFormMode.view && rows(groupId).length > (g?.repeat?.min ?? 0);
  }

  /// Adds an entry with its fields' defaults. Returns its id, or null at the maximum.
  String? addRow(String groupId) {
    if (!canAddRow(groupId)) return null;
    final g = index[groupId]!.asGroup!;
    final id = _newRowId();
    final defaults = <String, Object?>{};
    void walk(List<UiFbElement> els) {
      for (final el in els) {
        if (el is UiFbField && el.hasDefaultValue) defaults[addrOf(el.id, id)] = coerceValue(el, jsonClone(el.defaultValue));
        if (el is UiFbGroup) walk(el.elements);
      }
    }

    walk(g.elements);
    _values = {..._values, ...defaults};
    _rowIds = {..._rowIds, groupId: [...?_rowIds[groupId], id]};
    _changed();
    return id;
  }

  /// Removes an entry. Returns what was removed, so [restoreRow] can put it back (undo).
  UiFbRemovedRow? removeRow(String groupId, String rowId) {
    if (!canRemoveRow(groupId)) return null;
    final at = rows(groupId).indexOf(rowId);
    final values = {for (final e in _values.entries) if (e.key.startsWith('$rowId/')) e.key: e.value};
    _rowIds = {..._rowIds, groupId: [...?_rowIds[groupId]]..remove(rowId)};
    _values = {for (final e in _values.entries) if (!e.key.startsWith('$rowId/')) e.key: e.value};
    _changed();
    return UiFbRemovedRow(groupId: groupId, rowId: rowId, index: at, values: values);
  }

  /// Puts a removed entry back where it was, answers and all.
  void restoreRow(UiFbRemovedRow removed) {
    if (rows(removed.groupId).contains(removed.rowId)) return;
    _values = {..._values, ...removed.values};
    final list = [...?_rowIds[removed.groupId]];
    list.insert(math.min(math.max(removed.index, 0), list.length), removed.rowId);
    _rowIds = {..._rowIds, removed.groupId: list};
    _changed();
  }

  void moveRow(String groupId, String rowId, int delta) {
    final list = [...?_rowIds[groupId]];
    final i = list.indexOf(rowId);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= list.length) return;
    list[i] = list[j];
    list[j] = rowId;
    _rowIds = {..._rowIds, groupId: list};
    _changed();
  }

  /// Validates the current page and moves on along the route. Returns false if it can't.
  bool next() {
    final i = _pageIndex;
    _attempted.add(definition.pages[i].id);
    if (pageErrors(i).isNotEmpty || pagePending(i)) {
      _notify();
      return false;
    }
    final p = path;
    final at = p.indexOf(i);
    if (at < 0 || at >= p.length - 1) {
      _notify();
      return false;
    }
    pageIndex = p[at + 1];
    return true;
  }

  bool back() {
    final p = path;
    final at = p.indexOf(_pageIndex);
    if (at <= 0) return false;
    pageIndex = p[at - 1];
    return true;
  }

  /// Jumps to a page on the route (e.g. from a review step or an error link).
  void goTo(int pageIdx) {
    if (path.contains(pageIdx)) pageIndex = pageIdx;
  }

  /// Checks every page on the route. Returns the submission when it's all valid, or null (after
  /// moving to the first page with problems).
  UiFormSubmission? submit() {
    final p = path;
    for (final i in p) {
      _attempted.add(definition.pages[i].id);
    }
    for (final i in p) {
      if (pageErrors(i).isNotEmpty || pagePending(i)) {
        pageIndex = i;
        return null;
      }
    }
    final out = <String, List<UiFbPickedFile>>{};
    for (final MapEntry(key: addr, value: list) in files.entries) {
      if (list.isEmpty) continue;
      final slash = addr.indexOf('/');
      final row = slash >= 0 ? addr.substring(0, slash) : null;
      final id = slash >= 0 ? addr.substring(slash + 1) : addr;
      if (instanceState(id, row).visible) out[dataPath(id, row)] = list;
    }
    _notify();
    return UiFormSubmission(formId: definition.id, revision: definition.revision, data: data, submittedAt: _isoNow(), files: out);
  }

  String _isoNow() {
    final s = _now().toUtc().toIso8601String();
    // JS `toISOString()` has milliseconds; Dart may add microseconds.
    final m = RegExp(r'^(.*T\d\d:\d\d:\d\d)(\.\d{1,6})?Z$').firstMatch(s);
    if (m == null) return s;
    final frac = (m.group(2) ?? '.000').padRight(4, '0').substring(0, 4);
    return '${m.group(1)}${frac}Z';
  }

  // ── Output ─────────────────────────────────────────────────────────────────────────────────

  /// The answers as they would be saved right now.
  UiJson get data => _buildData();

  /// Whether the answers differ from what the form was opened with (calculations included).
  bool get dirty => !jsonEquals(data, _baseline);

  /// Each answer that differs from what the form was opened with.
  List<UiFbChange> get changes {
    final out = <UiFbChange>[];
    final vals = _values;
    final rowIds = _rowIds;
    final states = _current.states;
    for (final MapEntry(key: id, value: entry) in index.entries) {
      final group = entry.asGroup;
      if (entry.kind == 'group' && group!.repeat != null) {
        final before = _initialRows[id] ?? const <String>[];
        final now = rowIds[id] ?? const <String>[];
        if (before.length != now.length) out.add(UiFbChange(path: dataPath(id, null), label: elementName(group), from: before.length, to: now.length));
      }
      if (entry.kind != 'field') continue;
      final f = entry.asField!;
      // Calculated and hidden values follow from other answers, so they aren't listed.
      if (f.archived == true || fieldTypeInfo(f.type).noInput) continue;
      final rowList = entry.repeat != null ? (rowIds[entry.repeat!.id] ?? const <String>[]).cast<String?>() : const <String?>[null];
      for (final row in rowList) {
        final addr = addrOf(id, row);
        if (entry.repeat != null && !states.containsKey(addr)) continue;
        final from = _toJsonValue(_initialValues[addr]);
        final o = _output(f, addr, states[addr] ?? UiFbInstanceState.hidden, vals);
        final to = _toJsonValue(o.include ? o.value : null);
        if (!jsonEquals(from, to)) out.add(UiFbChange(path: dataPath(id, row), label: instanceLabel(id, row), from: from, to: to));
      }
    }
    return out;
  }

  /// Where a field's answer sits in the data, e.g. `dependants[1].name`.
  String dataPath(String id, String? row) {
    final entry = index[id];
    if (entry == null) return id;
    final parts = <String>[];
    for (final g in entry.groups) {
      if (g.key == null || g.key!.isEmpty) continue;
      parts.add(g.key!);
      if (g.repeat != null && row != null) parts[parts.length - 1] += '[${rows(g.id).indexOf(row)}]';
    }
    final el = entry.element;
    final key = el is UiFbField ? el.key : (el is UiFbGroup ? el.key : null);
    if (key != null && key.isNotEmpty) parts.add(key);
    return parts.join('.');
  }

  /// A hidden answer is kept when it was saved before and the person never saw it in this
  /// session: rules changing later must not wipe old data.
  bool _keepHidden(String addr) =>
      settings.clearHidden == 'never' || (mode != UiFormMode.create && _loaded.contains(addr) && !_everShown.contains(addr));

  /// Whether a field's answer goes into the data, and as what.
  ({bool include, Object? value}) _output(UiFbField el, String addr, UiFbInstanceState st, Map<String, Object?> vals) {
    var value = el.type == UiFbFieldType.calculated ? st.value : vals[addr];
    // An untouched yes/no shows as "no", so that's what gets saved.
    if (value == null && (el.type == UiFbFieldType.checkbox || el.type == UiFbFieldType.toggle)) value = false;
    if (st.visible || el.type == UiFbFieldType.hidden) return (include: true, value: _toJsonValue(value));
    if (_keepHidden(addr)) return (include: true, value: _toJsonValue(settings.clearHidden == 'never' ? value : _initialValues[addr]));
    return (include: false, value: null);
  }

  UiJson _buildData() {
    final states = _current.states;
    final vals = _values;
    final rowIds = _rowIds;
    final out = jsonCloneMap(_initialData);
    final clears = settings.clearHidden != 'never';
    void write(List<UiFbElement> els, Map<String, Object?> obj, String? row) {
      for (final el in els) {
        if (el is UiFbStatic || el.archived == true) continue;
        final addr = addrOf(el.id, row);
        final st = states[addr] ?? UiFbInstanceState.hidden;
        if (el is UiFbField) {
          for (final k in el.keyHistory ?? const <String>[]) {
            if (k != el.key) obj.remove(k);
          }
          if (el.type == UiFbFieldType.calculated && el.props?.excludeFromData == true) {
            obj.remove(el.key);
            continue;
          }
          final o = _output(el, addr, st, vals);
          if (o.include) {
            obj[el.key] = jsonClone(o.value);
          } else {
            obj.remove(el.key);
          }
          continue;
        }
        final g = el as UiFbGroup;
        if (g.key == null || g.key!.isEmpty) {
          write(g.elements, obj, row);
          continue;
        }
        final key = g.key!;
        final (oldFound, old) = _pick(obj, [key, ...?g.keyHistory]);
        for (final k in g.keyHistory ?? const <String>[]) {
          if (k != key) obj.remove(k);
        }
        if (!st.visible && clears && !_keepHidden(addr)) {
          obj.remove(key);
          continue;
        }
        if (!st.visible && clears) {
          if (oldFound) {
            obj[key] = old;
          } else {
            obj.remove(key);
          }
          continue;
        }
        if (g.repeat != null) {
          obj[key] = [
            for (final r in rowIds[g.id] ?? const <String>[])
              () {
                final base = jsonCloneMap(_rowBase[r] ?? const <String, Object?>{});
                write(g.elements, base, r);
                return base;
              }(),
          ];
        } else {
          final child = old is Map ? <String, Object?>{...old.cast<String, Object?>()} : <String, Object?>{};
          write(g.elements, child, row);
          obj[key] = child;
        }
      }
    }

    for (final p in definition.pages) {
      write(p.elements, out, null);
    }
    return out;
  }

  // ── Evaluation ─────────────────────────────────────────────────────────────────────────────

  _EvalResult _evaluate() {
    final idx = index;
    final def = definition;
    final today = _today();
    final values = _values;
    final rows = _rowIds;
    final asyncResults = _asyncResults;
    final memo = <String, Object?>{};
    final busy = <String>{};
    final checks = <_PendingCheck>[];
    final view = mode == UiFormMode.view;

    /// Runs `fn` once per key; a key that asks about itself gets `fallback` (a loop).
    T once<T>(String key, T fallback, T Function() fn) {
      if (memo.containsKey(key)) return memo[key] as T;
      if (busy.contains(key)) return fallback;
      busy.add(key);
      final v = fn();
      busy.remove(key);
      memo[key] = v;
      return v;
    }

    /// The row an element should be read in, when asked from `row`.
    String? rowFor(UiFbIndexEntry? entry, String? row) {
      if (entry?.repeat == null) return null;
      if (row != null && (rows[entry!.repeat!.id] ?? const []).contains(row)) return row;
      return _allRows;
    }

    late bool Function(String id, String? row) visible;
    late Object? Function(String id, String? row) value;
    late bool Function(String id, String? row) complete;

    _Ctx condCtx(String? row) => _Ctx(
      valueFn: (ref) {
        final r = rowFor(idx[ref], row);
        if (r == _allRows) return null;
        return value(ref, r);
      },
      valuesFn: (ref) {
        final entry = idx[ref];
        final r = rowFor(entry, row);
        if (r != _allRows) return [value(ref, r)];
        return [
          for (final x in rows[entry!.repeat!.id] ?? const <String>[])
            if (visible(ref, x)) value(ref, x),
        ];
      },
      visibleFn: (ref) {
        final entry = idx[ref];
        final r = rowFor(entry, row);
        if (r == _allRows) return (rows[entry!.repeat!.id] ?? const <String>[]).any((x) => visible(ref, x));
        return visible(ref, r);
      },
      completeFn: (ref) {
        final entry = idx[ref];
        final r = rowFor(entry, row);
        if (r == _allRows) return (rows[entry!.repeat!.id] ?? const <String>[]).every((x) => complete(ref, x));
        return complete(ref, r);
      },
      rowsFn: (ref) {
        final g = idx[ref]?.asGroup;
        return g != null && g.repeat != null ? (rows[ref] ?? const []).length : null;
      },
      todayFn: () => today,
    );

    /// A repeat group itself isn't per-entry; anything inside one is.
    String? parentRow(UiFbIndexEntry entry, String? row) => idx[entry.parentId]?.repeat != null ? row : null;

    bool toggle(UiFbToggle? t, String? row) => t?.flag == true || (t != null && t.isConditional && evaluateCondition(t.when, condCtx(row)));

    List<int> pathFn() => once<List<int>>('path', [for (var i = 0; i < def.pages.length; i++) i], () {
      final out = <int>[];
      var i = 0;
      while (i < def.pages.length) {
        final page = def.pages[i];
        final vis = page.visibility;
        final shown = vis == null || evaluateCondition(vis.when, condCtx(null)) == (vis.action == 'show');
        if (!shown) {
          i++;
          continue;
        }
        out.add(i);
        UiFbJump? jump;
        for (final j in page.jumps ?? const <UiFbJump>[]) {
          if (evaluateCondition(j.when, condCtx(null))) {
            jump = j;
            break;
          }
        }
        if (jump == null) {
          i++;
          continue;
        }
        if (jump.to == 'end') break;
        final t = def.pages.indexWhere((p) => p.id == jump!.to);
        i = t > i ? t : i + 1;
      }
      return out.isNotEmpty ? out : [0];
    });

    visible = (id, row) => once<bool>('v:${addrOf(id, row)}', false, () {
      final entry = idx[id];
      if (entry == null) return false;
      if (entry.kind == 'page') return pathFn().contains(entry.pageIndex);
      final el = entry.asElement!;
      if (el.archived == true) return false;
      if (!visible(entry.parentId, parentRow(entry, row))) return false;
      final vis = el.visibility;
      if (vis == null) return true;
      return evaluateCondition(vis.when, condCtx(row)) == (vis.action == 'show');
    });

    value = (id, row) => once<Object?>('val:${addrOf(id, row)}', null, () {
      final f = idx[id]?.asField;
      if (f != null && f.type == UiFbFieldType.calculated) return evaluateCalc(f.calc, condCtx(row));
      return values[addrOf(id, row)];
    });

    late bool Function(String id, String? row) disabled;
    disabled = (id, row) => once<bool>('d:${addrOf(id, row)}', false, () {
      if (view) return true;
      final entry = idx[id];
      if (entry == null || entry.kind == 'page') return false;
      final el = entry.asElement!;
      final dis = el is UiFbField ? el.disabled : (el is UiFbGroup ? el.disabled : null);
      if (el is! UiFbStatic && toggle(dis, row)) return true;
      if (el is UiFbField && el.readOnly == true) return true;
      if (idx[entry.parentId]?.kind != 'group') return false;
      return disabled(entry.parentId, parentRow(entry, row));
    });

    bool required(String id, String? row) => once<bool>('r:${addrOf(id, row)}', false, () {
      final f = idx[id]?.asField;
      return f != null && toggle(f.required, row);
    });

    ({List<String> errors, List<String> warnings, bool pending}) errors(String id, String? row) =>
        once<({List<String> errors, List<String> warnings, bool pending})>('e:${addrOf(id, row)}', (errors: const [], warnings: const [], pending: false), () {
          final errs = <String>[];
          final warns = <String>[];
          var pending = false;
          ({List<String> errors, List<String> warnings, bool pending}) res() => (errors: errs, warnings: warns, pending: pending);
          final f = idx[id]?.asField;
          if (f == null || view || !visible(id, row) || disabled(id, row) || f.type == UiFbFieldType.hidden) return res();
          final v = value(id, row);
          final label = f.label.isNotEmpty ? f.label : f.key;
          final empty = isEmptyValue(v) || (valueKindOf(f.type) == UiFbValueKind.boolean && v != true);
          if (required(id, row) && empty) {
            final custom = f.requiredMessage;
            errs.add(formatMessage(custom != null && custom.isNotEmpty ? custom : requiredMessage(f, label), {'label': label}));
            return res();
          }
          final rules = [...?f.validators];
          final implicit = uiFbImplicitValidator[f.type];
          if (implicit != null && !rules.any((r) => r.type == implicit)) rules.insert(0, UiFbValidatorRule(id: 'implicit_$implicit', type: implicit));
          final ctxBase = condCtx(row);
          for (final rule in rules) {
            final vdef = _validatorDefs[rule.type];
            if (vdef == null) continue;
            if (empty && !vdef.runWhenEmpty) continue;
            if (rule.when != null && !evaluateCondition(rule.when, ctxBase)) continue;
            final params = <String, Object?>{
              for (final p in vdef.params ?? const <UiFbParamSpec>[])
                if (p.hasDefault) p.key: p.defaultValue,
              ...?rule.params,
            };
            final vctx = UiFbValidatorContext(field: f, value: ctxBase.value, label: (ref) => elementName(idx[ref]?.element), today: () => today);
            String message(Object? result) {
              if (result is String) return result;
              final vars = <String, Object?>{'label': label};
              for (final spec in vdef.params ?? const <UiFbParamSpec>[]) {
                final pv = params[spec.key];
                vars[spec.key] = spec.kind == 'field'
                    ? '“${elementName(idx[jsString(pv)]?.element)}”'
                    : spec.kind == 'date'
                    ? describeDateParam(pv)
                    : spec.key == 'comparison'
                    ? comparisonWords(pv)
                    : pv;
              }
              final custom = rule.message;
              return formatMessage(custom != null && custom.isNotEmpty ? custom : vdef.defaultMessage, vars);
            }

            void push(Object? result) {
              if (result == true || result == null) return;
              (rule.severity == 'warning' ? warns : errs).add(message(result));
            }

            final key = '${addrOf(id, row)}|${rule.id}';
            final hash = jsonStringify([v, params]);
            final isAsync = (vdef.debounceMs != null && vdef.debounceMs != 0) || _asyncTypes.contains(vdef.type);
            if (isAsync) {
              final done = asyncResults[key];
              if (done != null && done.hash == hash) {
                push(done.result ?? true);
              } else {
                pending = true;
                checks.add(_PendingCheck(key, hash, rule, vdef, v, vctx));
              }
              continue;
            }
            Object? out;
            try {
              out = vdef.validate(v, params, vctx);
            } catch (_) {
              out = true;
            }
            if (out is Future) {
              // Discovered to be async: remember, and treat like the others from now on.
              _asyncTypes.add(vdef.type);
              out.ignore();
              pending = true;
              checks.add(_PendingCheck(key, hash, rule, vdef, v, vctx));
              continue;
            }
            push(out);
          }
          return res();
        });

    complete = (id, row) => once<bool>('c:${addrOf(id, row)}', false, () {
      final entry = idx[id];
      if (entry == null) return false;
      if (entry.kind == 'field') {
        final e = errors(id, row);
        final v = value(id, row);
        return e.errors.isEmpty && !e.pending && (!isEmptyValue(v) || !required(id, row));
      }
      final children = entry.element is UiFbPage
          ? (entry.element as UiFbPage).elements
          : (entry.asGroup?.elements ?? const <UiFbElement>[]);
      late bool Function(List<UiFbElement> els, String? r) check;
      check = (els, r) => els.every((el) {
        if (el is UiFbStatic || el.archived == true) return true;
        if (el is UiFbGroup) {
          if (!visible(el.id, r)) return true;
          return el.repeat != null ? (rows[el.id] ?? const <String>[]).every((x) => check(el.elements, x)) : check(el.elements, r);
        }
        if (!visible(el.id, r) || disabled(el.id, r)) return true;
        final e = errors(el.id, r);
        return e.errors.isEmpty && !e.pending && (!required(el.id, r) || !isEmptyValue(value(el.id, r)));
      });
      final group = entry.asGroup;
      if (entry.kind == 'group' && group!.repeat != null) return (rows[id] ?? const <String>[]).every((x) => check(children, x));
      return check(children, entry.kind == 'page' ? null : row);
    });

    final states = <String, UiFbInstanceState>{};
    void walk(List<UiFbElement> els, String? row) {
      for (final el in els) {
        final addr = addrOf(el.id, row);
        final vis = visible(el.id, row);
        if (el is UiFbField) {
          final e = errors(el.id, row);
          states[addr] = UiFbInstanceState(
            visible: vis, disabled: disabled(el.id, row), required: required(el.id, row), value: value(el.id, row), //
            errors: e.errors, warnings: e.warnings, pending: e.pending,
          );
        } else {
          states[addr] = UiFbInstanceState(visible: vis, disabled: el is UiFbGroup ? disabled(el.id, row) : false, required: false, value: null);
          if (el is UiFbGroup) {
            if (el.repeat != null) {
              for (final r in rows[el.id] ?? const <String>[]) {
                walk(el.elements, r);
              }
            } else {
              walk(el.elements, row);
            }
          }
        }
      }
    }

    for (final p in def.pages) {
      states[p.id] = UiFbInstanceState(visible: visible(p.id, null), disabled: false, required: false, value: null);
      walk(p.elements, null);
    }
    // Remember everything that has been on screen: a hidden answer that was never shown in this
    // session is history, not something the person just un-chose.
    for (final MapEntry(key: addr, value: st) in states.entries) {
      if (st.visible) _everShown.add(addr);
    }
    return _EvalResult(states, pathFn(), complete, checks);
  }

  /// Starts async checks the latest evaluation is waiting on (debounced, newest wins).
  void _runChecks(List<_PendingCheck> checks) {
    if (_disposed) return;
    for (final c in checks) {
      final cur = _inflight[c.key];
      if (cur?.hash == c.hash) continue;
      if (cur != null) {
        cur.abort.abort();
        cur.timer?.cancel();
      }
      final abort = UiFbAbortController();
      final entry = _Inflight(c.hash, abort);
      _inflight[c.key] = entry;
      void finish(String? msg) {
        if (abort.signal.aborted || _disposed) return;
        _inflight.remove(c.key);
        _asyncResults[c.key] = (hash: c.hash, result: msg);
        _changed();
      }

      void start() {
        entry.timer = null;
        Future<Object?> p;
        try {
          p = Future.sync(() => c.def.validate(c.value, {...?c.rule.params}, c.ctx.withSignal(abort.signal)));
        } catch (_) {
          p = Future.value(true);
        }
        p.then(
          (result) {
            final custom = c.rule.message;
            final msg = result == true || result == null
                ? null
                : result is String
                ? result
                : formatMessage(custom != null && custom.isNotEmpty ? custom : c.def.defaultMessage, {'label': c.ctx.field.label, ...?c.rule.params});
            finish(msg);
          },
          // A check that crashes (e.g. the server is down) doesn't block the form.
          onError: (Object _) => finish(null),
        );
      }

      entry.timer = Timer(Duration(milliseconds: c.def.debounceMs ?? 400), start);
    }
  }

  /// "When … set this field to …" rules fire as their condition becomes true. Returns whether
  /// any value changed.
  bool _applySetValues() {
    final res = _current;
    final updates = <String, Object?>{};
    final rowIds = _rowIds;
    for (final MapEntry(key: id, value: entry) in index.entries) {
      if (entry.kind != 'field') continue;
      final f = entry.asField!;
      if ((f.setValue?.isEmpty ?? true) || f.archived == true) continue;
      final rowList = entry.repeat != null ? (rowIds[entry.repeat!.id] ?? const <String>[]).cast<String?>() : const <String?>[null];
      for (final row in rowList) {
        for (final rule in f.setValue!) {
          final key = '${addrOf(id, row)}|${rule.id}';
          final ctx = _contextFor(row, res);
          final now = evaluateCondition(rule.when, ctx);
          final before = _setValuePrev[key];
          _setValuePrev[key] = now;
          // Fires on a change to true — not on load, so saved answers aren't overwritten.
          if (now && before == false && mode != UiFormMode.view) updates[addrOf(id, row)] = coerceValue(f, resolveOperand(rule.value, ctx));
        }
      }
    }
    if (updates.isEmpty) return false;
    _values = {..._values, ...updates};
    _state = null;
    return true;
  }

  /// A condition context over a finished evaluation.
  UiFbConditionContext _contextFor(String? row, _EvalResult res) {
    final rowIds = _rowIds;
    final states = res.states;
    String? inRow(String ref) {
      final e = index[ref];
      if (e?.repeat == null) return null;
      return row != null && (rowIds[e!.repeat!.id] ?? const []).contains(row) ? row : _allRows;
    }

    return UiFbConditionFns(
      value: (ref) {
        final r = inRow(ref);
        return r == _allRows ? null : states[addrOf(ref, r)]?.value;
      },
      visible: (ref) {
        final r = inRow(ref);
        return r == _allRows ? false : (states[addrOf(ref, r)]?.visible ?? false);
      },
      complete: (ref) {
        final r = inRow(ref);
        return r == _allRows ? false : res.complete(ref, r);
      },
      rows: (ref) => (rowIds[ref] ?? const []).length,
      today: _today,
    );
  }

  /// Stored file metadata plus the picked files, kept for the submission. With [uploaded] (the
  /// host's uploader already stored them) only that metadata is kept.
  void setFiles(String id, String? row, List<UiFbPickedFile> picked, {List<UiFbFileValue>? uploaded}) {
    final addr = addrOf(id, row);
    final meta = uploaded != null ? [for (final f in uploaded) f.toJson()] : [for (final f in picked) UiFbFileValue(name: f.name, size: f.size, type: f.type).toJson()];
    files[addr] = uploaded != null ? [] : picked;
    setValue(id, row, meta);
  }
}
