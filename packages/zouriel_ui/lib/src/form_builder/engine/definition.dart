import 'dart:convert';
import 'dart:math' as math;

import 'field_types.dart';
import 'js.dart';
import 'schema.dart';
import 'slug_table.g.dart';

// ── Ids and keys ─────────────────────────────────────────────────────────────────────────────

int _seq = 0;
final math.Random _random = math.Random();

/// A short id that is unique within a session and very unlikely to collide across sessions.
String fbUid(String prefix) {
  _seq = (_seq + 1) % 1296;
  final rand = List.generate(5, (_) => _random.nextInt(36).toRadixString(36)).join();
  final time = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  return '${prefix}_${time.substring(math.max(0, time.length - 4))}${_seq.toRadixString(36).padLeft(2, '0')}$rand';
}

final RegExp _nonSlug = RegExp(r'[^a-z0-9]+');
final RegExp _edgeUnderscores = RegExp(r'^_+|_+$');
final RegExp _trailingUnderscores = RegExp(r'_+$');

/// "First name (legal)" → "first_name_legal". Always starts with a letter.
String fbSlug(String label) {
  final folded = StringBuffer();
  for (final rune in label.runes) {
    if (rune >= 0x300 && rune <= 0x36F) continue;
    folded.write(fbSlugFold[rune] ?? String.fromCharCode(rune));
  }
  var s = folded.toString().toLowerCase().replaceAll(_nonSlug, '_').replaceAll(_edgeUnderscores, '');
  if (s.length > 40) s = s.substring(0, 40);
  s = s.replaceAll(_trailingUnderscores, '');
  if (s.isEmpty) return 'field';
  return RegExp(r'^[a-z]').hasMatch(s) ? s : 'f_$s';
}

/// A valid key: letters, digits and underscores, starting with a letter.
bool fbKeyValid(String key) => RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(key);

// ── Creating elements ────────────────────────────────────────────────────────────────────────

/// A new, one-page form. [defaults] (e.g. global settings' `defaults`) are copied into its settings.
UiFormDefinition createDefinition({String title = 'Untitled form', UiFbSettings? defaults}) => UiFormDefinition(
  id: fbUid('form'),
  title: title,
  revision: 0,
  settings: defaults?.clone() ?? UiFbSettings(),
  pages: [createPage()],
);

UiFbPage createPage([String? title]) => UiFbPage(id: fbUid('page'), title: title, elements: []);

UiFbField createField(UiFbFieldType type, {UiFormDefinition? def, String? label}) {
  final info = fieldTypeInfo(type);
  final lbl = label ?? info.defaultLabel;
  final field = UiFbField(id: fbUid('fld'), type: type, key: def != null ? uniqueKey(def, fbSlug(lbl), null) : fbSlug(lbl), label: lbl);
  if (info.defaultProps != null) field.props = UiFbFieldProps.fromJson(info.defaultProps);
  if (info.hasOptions) {
    field.options = [for (final l in const ['Option 1', 'Option 2', 'Option 3']) UiFbOption(id: fbUid('opt'), value: fbSlug(l), label: l)];
  }
  if (type == UiFbFieldType.calculated) field.calc = UiFbCalc(op: UiFbCalcOp.sum, args: []);
  return field;
}

UiFbGroup createGroup({UiFormDefinition? def, bool repeat = false}) {
  final g = UiFbGroup(id: fbUid('grp'), title: repeat ? 'Repeating section' : 'Section', elements: []);
  if (repeat) {
    g.key = def != null ? uniqueKey(def, 'items', null) : 'items';
    g.repeat = UiFbRepeat(min: 1, addLabel: 'Add another', itemLabel: 'Entry {n}');
  }
  return g;
}

/// `type` is `heading`, `paragraph` or `divider`.
UiFbStatic createStatic(String type) {
  final text = type == 'heading' ? 'Heading' : type == 'paragraph' ? 'Add some explanation here.' : null;
  return UiFbStatic(id: fbUid('st'), type: type, text: text);
}

// ── Walking and indexing ─────────────────────────────────────────────────────────────────────

class UiFbIndexEntry {
  const UiFbIndexEntry({
    required this.id,
    required this.kind,
    required this.element,
    required this.page,
    required this.pageIndex,
    required this.parentId,
    required this.index,
    required this.groups,
    required this.repeat,
    required this.scopeKeys,
    required this.scope,
    required this.order,
  });

  final String id;

  /// `page`, `field`, `group` or `static`.
  final String kind;

  /// A [UiFbElement], or the [UiFbPage] for a page entry.
  final Object element;
  final UiFbPage page;
  final int pageIndex;

  /// The page or group this element sits in ('' for a page).
  final String parentId;

  /// Position among its siblings.
  final int index;

  /// Enclosing groups, outermost first.
  final List<UiFbGroup> groups;

  /// The nearest enclosing repeatable group, if any.
  final UiFbGroup? repeat;

  /// Keys of enclosing keyed groups, outermost first (repeatables included).
  final List<String> scopeKeys;

  /// Data scope id: the nearest keyed group's id, or `root`. Keys are unique per scope.
  final String scope;

  /// Document order across the whole form.
  final int order;

  /// The element, when this isn't a page.
  UiFbElement? get asElement => element is UiFbElement ? element as UiFbElement : null;
  UiFbField? get asField => element is UiFbField ? element as UiFbField : null;
  UiFbGroup? get asGroup => element is UiFbGroup ? element as UiFbGroup : null;
}

typedef UiFbIndex = Map<String, UiFbIndexEntry>;

UiFbIndex indexDefinition(UiFormDefinition def) {
  final map = <String, UiFbIndexEntry>{};
  var order = 0;
  for (var pageIndex = 0; pageIndex < def.pages.length; pageIndex++) {
    final page = def.pages[pageIndex];
    map[page.id] = UiFbIndexEntry(
      id: page.id, kind: 'page', element: page, page: page, pageIndex: pageIndex, parentId: '', index: pageIndex, //
      groups: const [], repeat: null, scopeKeys: const [], scope: 'root', order: order++,
    );
    void visit(List<UiFbElement> els, String parentId, List<UiFbGroup> groups) {
      for (var index = 0; index < els.length; index++) {
        final el = els[index];
        UiFbGroup? repeat;
        for (final g in groups.reversed) {
          if (g.repeat != null) {
            repeat = g;
            break;
          }
        }
        final keyed = groups.where((g) => g.key != null && g.key!.isNotEmpty).toList();
        map[el.id] = UiFbIndexEntry(
          id: el.id, kind: el.kind, element: el, page: page, pageIndex: pageIndex, parentId: parentId, index: index, groups: groups, //
          repeat: repeat, scopeKeys: [for (final g in keyed) g.key!], scope: keyed.isNotEmpty ? keyed.last.id : 'root', order: order++,
        );
        if (el is UiFbGroup) visit(el.elements, el.id, [...groups, el]);
      }
    }

    visit(page.elements, page.id, const []);
  }
  return map;
}

/// Every element of the form in document order (pages excluded).
List<UiFbElement> allElements(UiFormDefinition def) {
  final out = <UiFbElement>[];
  void visit(List<UiFbElement> els) {
    for (final el in els) {
      out.add(el);
      if (el is UiFbGroup) visit(el.elements);
    }
  }

  for (final p in def.pages) {
    visit(p.elements);
  }
  return out;
}

List<UiFbField> allFields(UiFormDefinition def) => allElements(def).whereType<UiFbField>().toList();

/// A short human name for any element or page ([el] is a [UiFbElement], a [UiFbPage] or null).
String elementName(Object? el, [UiFormDefinition? def]) {
  if (el == null) return 'Missing item';
  if (el is UiFbPage) {
    final i = def != null ? def.pages.indexWhere((p) => identical(p, el)) : -1;
    if (el.title != null && el.title!.isNotEmpty) return el.title!;
    return i >= 0 ? 'Page ${i + 1}' : 'Page';
  }
  if (el is UiFbField) return el.label.isNotEmpty ? el.label : el.key;
  if (el is UiFbGroup) return el.title != null && el.title!.isNotEmpty ? el.title! : (el.repeat != null ? 'Repeating section' : 'Section');
  final s = el as UiFbStatic;
  if (s.type == 'divider') return 'Divider';
  final text = s.text ?? '';
  final cut = text.length > 40 ? text.substring(0, 40) : text;
  return cut.isNotEmpty ? cut : (s.type == 'heading' ? 'Heading' : 'Text block');
}

// ── Edits (each returns a new definition; the one passed in is never changed) ────────────────

List<UiFbElement> _mapElements(List<UiFbElement> els, UiFbElement? Function(UiFbElement el) fn) {
  final out = <UiFbElement>[];
  for (final el in els) {
    final next = fn(el);
    if (next == null) continue;
    if (next is UiFbGroup) next.elements = _mapElements(next.elements, fn);
    out.add(next);
  }
  return out;
}

/// Applies [fn] to every element of a copy of [def] ([fn] may change the element it's given).
UiFormDefinition _mapAll(UiFormDefinition def, UiFbElement? Function(UiFbElement el) fn) {
  final copy = def.clone();
  for (final p in copy.pages) {
    p.elements = _mapElements(p.elements, fn);
  }
  return copy;
}

/// A copy of [def] with element [id] replaced by `fn(copyOfIt)`.
UiFormDefinition updateElement(UiFormDefinition def, String id, UiFbElement Function(UiFbElement el) fn) =>
    _mapAll(def, (el) => el.id == id ? fn(el) : el);

/// A copy of [def] with page [id] replaced by `fn(copyOfIt)`.
UiFormDefinition updatePage(UiFormDefinition def, String id, UiFbPage Function(UiFbPage p) fn) {
  final copy = def.clone();
  copy.pages = [for (final p in copy.pages) p.id == id ? fn(p) : p];
  return copy;
}

/// Where to put an element: inside a page or group, at a position.
class UiFbDropTarget {
  const UiFbDropTarget({required this.containerId, required this.index});
  final String containerId;
  final int index;
}

UiFormDefinition insertElement(UiFormDefinition def, UiFbElement el, UiFbDropTarget target) {
  List<UiFbElement> put(List<UiFbElement> list) {
    final copy = [...list];
    copy.insert(math.max(0, math.min(target.index, copy.length)), UiFbElement.fromJson(el.toJson()));
    return copy;
  }

  if (def.pages.any((p) => p.id == target.containerId)) {
    return updatePage(def, target.containerId, (p) => p..elements = put(p.elements));
  }
  return updateElement(def, target.containerId, (g) => g is UiFbGroup ? (g..elements = put(g.elements)) : g);
}

UiFormDefinition removeElement(UiFormDefinition def, String id) => _mapAll(def, (el) => el.id == id ? null : el);

/// Whether `containerId` is `id` itself or sits inside it (a group can't be dropped into itself).
bool isInside(UiFormDefinition def, String containerId, String id) {
  if (containerId == id) return true;
  final entry = indexDefinition(def)[containerId];
  return entry != null && entry.groups.any((g) => g.id == id);
}

/// Whether an element may go into a container. Repeatable groups can't nest in other repeatable
/// groups, and a group can't go inside itself.
bool canDrop(UiFormDefinition def, UiFbElement el, String containerId) {
  if (isInside(def, containerId, el.id)) return false;
  final container = indexDefinition(def)[containerId];
  if (container == null) return false;
  final inRepeat = container.kind == 'group' ? (container.asGroup!.repeat != null || container.repeat != null) : false;
  if (!inRepeat) return true;
  bool hasRepeat(UiFbElement e) => e is UiFbGroup && (e.repeat != null || e.elements.any(hasRepeat));
  return !hasRepeat(el);
}

/// Moves an element. Returns [def] itself when nothing changes.
UiFormDefinition moveElement(UiFormDefinition def, String id, UiFbDropTarget target) {
  final entry = indexDefinition(def)[id];
  if (entry == null || entry.kind == 'page') return def;
  final el = entry.asElement!;
  if (!canDrop(def, el, target.containerId)) return def;
  var index = target.index;
  // Removing the element first shifts later siblings in the same list up by one.
  if (entry.parentId == target.containerId && entry.index < index) index--;
  if (entry.parentId == target.containerId && entry.index == index) return def;
  return insertElement(removeElement(def, id), el, UiFbDropTarget(containerId: target.containerId, index: index));
}

/// Copies an element (and its children) with fresh ids and unique keys, placed right after it.
({UiFormDefinition def, String id}) duplicateElement(UiFormDefinition def, String id) {
  final entry = indexDefinition(def)[id];
  if (entry == null || entry.kind == 'page') return (def: def, id: id);
  final remap = <String, String>{};
  final clone = UiFbElement.fromJson(entry.asElement!.toJson());
  void freshIds(UiFbElement e) {
    final next = fbUid(e is UiFbField ? 'fld' : e is UiFbGroup ? 'grp' : 'st');
    remap[e.id] = next;
    e.id = next;
    if (e is UiFbField) {
      e.options = e.options?.map((o) => UiFbOption.fromJson(o.toJson()..['id'] = fbUid('opt'))).toList();
      e.validators = e.validators?.map((v) => UiFbValidatorRule.fromJson(v.toJson()..['id'] = fbUid('val'))).toList();
      e.setValue = e.setValue?.map((s) => UiFbSetValue.fromJson(s.toJson()..['id'] = fbUid('set'))).toList();
      e.keyHistory = null;
    }
    if (e is UiFbGroup) {
      e.keyHistory = null;
      e.elements.forEach(freshIds);
    }
  }

  freshIds(clone);
  // References between elements inside the copy follow the copy; outside references stay.
  final remapped = _remapRefs(clone, remap);
  var next = insertElement(def, remapped, UiFbDropTarget(containerId: entry.parentId, index: entry.index + 1));
  // Keys: the copy's own key is unique in its scope; children of a keyed copy live in a new scope.
  void rekeyField(String fid) {
    final current = next;
    next = updateElement(current, fid, (f) => f is UiFbField ? (f..key = uniqueKey(current, f.key, f.id)) : f);
  }

  void rekeyGroup(String gid) {
    final current = next;
    next = updateElement(current, gid, (g) => g is UiFbGroup ? (g..key = uniqueKey(current, g.key!, g.id)) : g);
  }

  if (remapped is UiFbField) {
    rekeyField(remapped.id);
  } else if (remapped is UiFbGroup) {
    if (remapped.key != null && remapped.key!.isNotEmpty) {
      rekeyGroup(remapped.id);
    } else {
      void fix(List<UiFbElement> els) {
        for (final e in els) {
          if (e is UiFbField) rekeyField(e.id);
          if (e is UiFbGroup && (e.key == null || e.key!.isEmpty)) fix(e.elements);
          if (e is UiFbGroup && e.key != null && e.key!.isNotEmpty) rekeyGroup(e.id);
        }
      }

      fix(remapped.elements);
    }
  }
  return (def: next, id: remapped.id);
}

/// Points every reference in [el] at the new ids in [remap]. Ids are unique random tokens, so
/// swapping exact quoted strings can't hit anything else.
UiFbElement _remapRefs(UiFbElement el, Map<String, String> remap) {
  var json = jsonEncode(el.toJson());
  for (final e in remap.entries) {
    json = json.split('"${e.key}"').join('"${e.value}"');
  }
  return UiFbElement.fromJson(jsonDecode(json));
}

/// Whether a key is already used by a field or group in a data scope.
bool _keyTaken(UiFormDefinition def, String key, String scope, String? exceptId) {
  for (final entry in indexDefinition(def).values) {
    if (entry.id == exceptId || entry.scope != scope) continue;
    final el = entry.element;
    if (el is UiFbField && el.key == key) return true;
    if (el is UiFbGroup && el.key == key) return true;
  }
  return false;
}

/// `base`, or `base_2`, `base_3`… — whichever is free in the data scope of element [id] (or the
/// top level when [id] is null or not yet in the form).
String uniqueKey(UiFormDefinition def, String base, String? id) {
  final s = id != null && id.isNotEmpty ? indexDefinition(def)[id]?.scope : null;
  final scope = s != null && s.isNotEmpty ? s : 'root';
  final clean = fbKeyValid(base) ? base : fbSlug(base);
  final stem = clean.replaceFirst(RegExp(r'_\d+$'), '');
  var key = clean;
  var n = 2;
  while (_keyTaken(def, key, scope, id)) {
    key = '${stem}_${n++}';
  }
  return key;
}

/// Changes a field's or group's key, remembering the old one so saved answers still load.
UiFormDefinition renameKey(UiFormDefinition def, String id, String key) => updateElement(def, id, (el) {
  String? old;
  List<String>? history;
  if (el is UiFbField) {
    old = el.key;
    history = el.keyHistory;
  } else if (el is UiFbGroup) {
    old = el.key;
    history = el.keyHistory;
  } else {
    return el;
  }
  List<String>? nextHistory = history;
  if (old != null && old.isNotEmpty && old != key) nextHistory = [...(history ?? const <String>[]).where((k) => k != key), old];
  if (el is UiFbField) {
    el
      ..key = key
      ..keyHistory = nextHistory;
  } else if (el is UiFbGroup) {
    el
      ..key = key
      ..keyHistory = nextHistory;
  }
  return el;
});

// ── References ───────────────────────────────────────────────────────────────────────────────

List<String> conditionRefs(UiFbCondition? c, [List<String>? into]) {
  final out = into ?? <String>[];
  if (c == null) return out;
  switch (c) {
    case UiFbConditionGroup(:final conditions):
      for (final x in conditions) {
        conditionRefs(x, out);
      }
    case UiFbConditionRule():
      out.add(c.ref);
      _operandRefs(c.value, out);
      _operandRefs(c.value2, out);
  }
  return out;
}

void _operandRefs(UiFbOperand? o, List<String> out) {
  if (o is UiFbRefOperand) out.add(o.ref);
}

List<String> calcRefs(UiFbCalc? c, [List<String>? into]) {
  final out = into ?? <String>[];
  for (final a in c?.args ?? const <UiFbCalcArg>[]) {
    if (a is UiFbCalcRefArg) {
      out.add(a.ref);
    } else if (a is UiFbCalcNestedArg) {
      calcRefs(a.calc, out);
    }
  }
  return out;
}

void _toggleRefs(UiFbToggle? t, List<String> out) {
  if (t != null && t.isConditional) conditionRefs(t.when, out);
}

/// What kind of rule a reference sits in: `visibility`, `required`, `disabled`, `setValue`,
/// `validator`, `calc`, `jump` or `source`.
typedef UiFbRefKind = String;

/// Answers a field's option source reads (dependent lists, e.g. Cities of the chosen Country).
List<String> sourceRefs(UiFbField el, [List<String>? into]) {
  final out = into ?? <String>[];
  for (final v in el.source?.params?.values ?? const <UiFbOperand>[]) {
    if (v is UiFbRefOperand && v.ref.isNotEmpty) out.add(v.ref);
  }
  return out;
}

class UiFbReference {
  const UiFbReference({required this.ownerId, required this.kind});

  /// The element or page whose rule mentions the target.
  final String ownerId;
  final UiFbRefKind kind;

  UiJson toJson() => {'ownerId': ownerId, 'kind': kind};

  @override
  bool operator ==(Object other) => other is UiFbReference && other.ownerId == ownerId && other.kind == kind;

  @override
  int get hashCode => Object.hash(ownerId, kind);

  @override
  String toString() => 'UiFbReference($ownerId, $kind)';
}

/// Every rule, calculation and jump that mentions element [id].
List<UiFbReference> referencesTo(UiFormDefinition def, String id) {
  final out = <UiFbReference>[];
  void check(String ownerId, UiFbRefKind kind, List<String> refs) {
    if (ownerId != id && refs.contains(id)) out.add(UiFbReference(ownerId: ownerId, kind: kind));
  }

  for (final page in def.pages) {
    check(page.id, 'visibility', conditionRefs(page.visibility?.when));
    for (final j in page.jumps ?? const <UiFbJump>[]) {
      if (j.to == id && page.id != id) out.add(UiFbReference(ownerId: page.id, kind: 'jump'));
      check(page.id, 'jump', conditionRefs(j.when));
    }
  }
  for (final el in allElements(def)) {
    check(el.id, 'visibility', conditionRefs(el.visibility?.when));
    if (el is UiFbStatic) continue;
    final dis = <String>[];
    _toggleRefs(el is UiFbField ? el.disabled : (el as UiFbGroup).disabled, dis);
    check(el.id, 'disabled', dis);
    if (el is! UiFbField) continue;
    final req = <String>[];
    _toggleRefs(el.required, req);
    check(el.id, 'required', req);
    final sv = <String>[];
    for (final s in el.setValue ?? const <UiFbSetValue>[]) {
      conditionRefs(s.when, sv);
      _operandRefs(s.value, sv);
    }
    check(el.id, 'setValue', sv);
    final va = <String>[];
    for (final v in el.validators ?? const <UiFbValidatorRule>[]) {
      conditionRefs(v.when, va);
      for (final p in (v.params ?? const <String, Object?>{}).values) {
        if (p is String) va.add(p);
      }
    }
    check(el.id, 'validator', va);
    check(el.id, 'calc', calcRefs(el.calc));
    check(el.id, 'source', sourceRefs(el));
  }
  return out;
}

/// Ids of elements inside [id] (its own id included).
List<String> subtreeIds(UiFormDefinition def, String id) {
  final entry = indexDefinition(def)[id];
  if (entry == null) return [];
  final ids = <String>[];
  void visit(Object el) {
    if (el is UiFbPage) {
      ids.add(el.id);
      el.elements.forEach(visit);
    } else if (el is UiFbGroup) {
      ids.add(el.id);
      el.elements.forEach(visit);
    } else {
      ids.add((el as UiFbElement).id);
    }
  }

  visit(entry.element);
  return ids;
}

/// References to [id] or anything inside it, from outside it.
List<UiFbReference> externalReferences(UiFormDefinition def, String id) {
  final inner = subtreeIds(def, id).toSet();
  final seen = <String>{};
  final out = <UiFbReference>[];
  for (final target in inner) {
    for (final r in referencesTo(def, target)) {
      final k = '${r.ownerId}|${r.kind}';
      if (inner.contains(r.ownerId) || seen.contains(k)) continue;
      seen.add(k);
      out.add(r);
    }
  }
  return out;
}

UiFbCondition? _stripCondition(UiFbCondition? c, Set<String> ids) {
  if (c == null) return null;
  switch (c) {
    case UiFbConditionGroup():
      final kept = c.conditions.map((x) => _stripCondition(x, ids)).whereType<UiFbCondition>().toList();
      return kept.isNotEmpty ? (c..conditions = kept) : null;
    case UiFbConditionRule():
      final valueRef = c.value is UiFbRefOperand ? (c.value as UiFbRefOperand).ref : null;
      final value2Ref = c.value2 is UiFbRefOperand ? (c.value2 as UiFbRefOperand).ref : null;
      if (ids.contains(c.ref) || (valueRef != null && valueRef.isNotEmpty && ids.contains(valueRef)) || (value2Ref != null && value2Ref.isNotEmpty && ids.contains(value2Ref))) {
        return null;
      }
      return c;
  }
}

UiFbToggle? _stripToggle(UiFbToggle? t, Set<String> ids) {
  if (t == null || !t.isConditional) return t;
  final when = _stripCondition(t.when, ids);
  return when != null ? UiFbToggle.when(when) : null;
}

UiFbCalc _stripCalc(UiFbCalc c, Set<String> ids) {
  c.args = [
    for (final a in c.args)
      if (!(a is UiFbCalcRefArg && ids.contains(a.ref))) a is UiFbCalcNestedArg ? UiFbCalcNestedArg(_stripCalc(a.calc, ids)) : a,
  ];
  return c;
}

UiFbVisibility? _stripVisibility(UiFbVisibility? v, Set<String> ids) {
  final when = _stripCondition(v?.when, ids);
  return when != null && v != null ? (v..when = when) : null;
}

/// Removes every condition, calculation input and jump that mentions any of [idList].
UiFormDefinition removeReferences(UiFormDefinition def, List<String> idList) {
  final ids = idList.toSet();
  final copy = def.clone();
  for (final p in copy.pages) {
    p.visibility = _stripVisibility(p.visibility, ids);
    p.jumps = p.jumps
        ?.where((j) => !ids.contains(j.to))
        .map((j) => j..when = _stripCondition(j.when, ids))
        .where((j) => j.when != null)
        .toList();
  }
  return _mapAll(copy, (el) {
    el.visibility = _stripVisibility(el.visibility, ids);
    if (el is UiFbStatic) return el;
    if (el is UiFbGroup) return el..disabled = _stripToggle(el.disabled, ids);
    final f = el as UiFbField;
    f.disabled = _stripToggle(f.disabled, ids);
    f.required = _stripToggle(f.required, ids);
    f.setValue = f.setValue
        ?.where((s) => !(s.value is UiFbRefOperand && ids.contains((s.value as UiFbRefOperand).ref)))
        .map((s) => s..when = _stripCondition(s.when, ids))
        .where((s) => s.when != null)
        .toList();
    f.validators = f.validators
        ?.where((v) => !(v.params ?? const <String, Object?>{}).values.any((p) => p is String && ids.contains(p)))
        .map((v) => v..when = _stripCondition(v.when, ids))
        .toList();
    f.calc = f.calc != null ? _stripCalc(f.calc!, ids) : null;
    // A filter that read a deleted answer is dropped; the list then just isn't narrowed by it.
    final src = f.source;
    if (src != null) {
      src.params = {
        for (final e in (src.params ?? const <String, UiFbOperand>{}).entries)
          if (!(e.value is UiFbRefOperand && ids.contains((e.value as UiFbRefOperand).ref))) e.key: e.value,
      };
    }
    return f;
  });
}

// ── Dependencies and checks ──────────────────────────────────────────────────────────────────

/// For each element/page, the ids its own rules and calculation read.
Map<String, Set<String>> dependencyGraph(UiFormDefinition def) {
  final g = <String, Set<String>>{};
  void add(String owner, List<String> refs) {
    if (refs.isEmpty) return;
    (g[owner] ??= <String>{}).addAll(refs);
  }

  for (final p in def.pages) {
    add(p.id, conditionRefs(p.visibility?.when));
    for (final j in p.jumps ?? const <UiFbJump>[]) {
      add(p.id, conditionRefs(j.when));
    }
  }
  for (final el in allElements(def)) {
    add(el.id, conditionRefs(el.visibility?.when));
    if (el is UiFbField) {
      add(el.id, calcRefs(el.calc));
      final r = <String>[];
      _toggleRefs(el.required, r);
      add(el.id, r);
    }
  }
  return g;
}

/// Loops such as "A is worked out from B, and B from A", or "show A when B is shown, show B when
/// A is shown". Each element is tracked as separate facts (shown, value, required, complete), so
/// "show X when section S is complete" is fine even though S's fields are hidden whenever S is.
/// Returns each loop once, as element ids.
List<List<String>> findCycles(UiFormDefinition def) {
  final idx = indexDefinition(def);
  final g = <String, Set<String>>{};
  void dep(String from, String to) => (g[from] ??= <String>{}).add(to);
  void condDeps(String from, UiFbCondition? c) {
    if (c == null) return;
    if (c is UiFbConditionGroup) {
      for (final x in c.conditions) {
        condDeps(from, x);
      }
      return;
    }
    final r = c as UiFbConditionRule;
    final fact = r.op == UiFbOperator.visible || r.op == UiFbOperator.hidden
        ? 'vis'
        : r.op == UiFbOperator.complete || r.op == UiFbOperator.incomplete
        ? 'cmp'
        : 'val';
    dep(from, '$fact:${r.ref}');
    for (final o in [r.value, r.value2]) {
      if (o is UiFbRefOperand) dep(from, 'val:${o.ref}');
    }
  }

  for (var i = 0; i < def.pages.length; i++) {
    final p = def.pages[i];
    condDeps('vis:${p.id}', p.visibility?.when);
    // Whether a page is reached depends on the jumps of every page before it.
    for (var j = 0; j < i; j++) {
      dep('vis:${p.id}', 'jump:${def.pages[j].id}');
    }
    for (final jp in p.jumps ?? const <UiFbJump>[]) {
      condDeps('jump:${p.id}', jp.when);
    }
  }
  for (final MapEntry(key: id, value: entry) in idx.entries) {
    if (entry.kind == 'page') continue;
    final el = entry.asElement!;
    dep('vis:$id', 'vis:${entry.parentId}');
    condDeps('vis:$id', el.visibility?.when);
    if (el is UiFbField) {
      for (final r in calcRefs(el.calc)) {
        dep('val:$id', 'val:$r');
      }
      if (el.required != null && el.required!.isConditional) condDeps('req:$id', el.required!.when);
    }
  }
  // A group or page is complete when every field inside it is shown-and-filled or not required.
  for (final MapEntry(key: id, value: entry) in idx.entries) {
    if (entry.kind != 'group' && entry.kind != 'page') continue;
    for (final inner in subtreeIds(def, id)) {
      if (inner == id || idx[inner]?.kind != 'field') continue;
      dep('cmp:$id', 'vis:$inner');
      dep('cmp:$id', 'val:$inner');
      dep('cmp:$id', 'req:$inner');
    }
  }
  final cycles = <List<String>>[];
  final seen = <String>{};
  final state = <String, int>{};
  final stack = <String>[];
  void visit(String n) {
    state[n] = 1;
    stack.add(n);
    for (final m in g[n] ?? const <String>{}) {
      if (state[m] == 1) {
        final ids = stack.sublist(stack.indexOf(m)).map((x) => x.substring(x.indexOf(':') + 1)).toList();
        final loop = [
          for (var i = 0; i < ids.length; i++)
            if (ids[i] != ids[(i + 1) % ids.length] || ids.length == 1) ids[i],
        ];
        final sig = (loop.toSet().toList()..sort()).join('|');
        if (!seen.contains(sig)) {
          seen.add(sig);
          cycles.add(loop.isNotEmpty ? loop : [ids[0]]);
        }
      } else if (!state.containsKey(m)) {
        visit(m);
      }
    }
    stack.removeLast();
    state[n] = 2;
  }

  for (final n in [...g.keys]) {
    if (!state.containsKey(n)) visit(n);
  }
  return cycles;
}

class UiFbProblem {
  const UiFbProblem({required this.severity, required this.targetId, required this.message});

  /// `error` or `warning`.
  final String severity;

  /// The element or page to jump to when fixing it.
  final String targetId;
  final String message;

  UiJson toJson() => {'severity': severity, 'targetId': targetId, 'message': message};

  @override
  bool operator ==(Object other) => other is UiFbProblem && other.severity == severity && other.targetId == targetId && other.message == message;

  @override
  int get hashCode => Object.hash(severity, targetId, message);

  @override
  String toString() => 'UiFbProblem($severity, $targetId, $message)';
}

/// Everything wrong with a definition, worded for the person building the form.
List<UiFbProblem> lintDefinition(UiFormDefinition def) {
  final out = <UiFbProblem>[];
  final idx = indexDefinition(def);
  String name(String id) => elementName(idx[id]?.element, def);
  void add(String severity, String target, String message) => out.add(UiFbProblem(severity: severity, targetId: target, message: message));
  final keys = <String, String>{};
  for (final entry in idx.values) {
    final el = entry.asElement;
    if (el == null || el.archived == true) continue;
    final key = el is UiFbField ? el.key : (el is UiFbGroup ? el.key : null);
    if (el is UiFbField || (el is UiFbGroup && key != null && key.isNotEmpty)) {
      final k = key ?? '';
      if (k.isEmpty) {
        add('error', el.id, '“${name(el.id)}” needs a data key.');
      } else if (!fbKeyValid(k)) {
        add('error', el.id, 'The data key “$k” may only use letters, numbers and _ and must start with a letter.');
      }
      final sig = '${entry.scope}|$k';
      if (k.isNotEmpty && keys.containsKey(sig)) {
        add('error', el.id, '“${name(el.id)}” and “${name(keys[sig]!)}” both store their answer as “$k”.');
      } else {
        keys[sig] = el.id;
      }
    }
    if (el is UiFbField) {
      if (el.label.trim().isEmpty && el.type != UiFbFieldType.hidden) add('warning', el.id, 'A ${fieldTypeInfo(el.type).label.toLowerCase()} field has no label.');
      // Options from a data source live in the app, so there's nothing typed to check.
      if (fieldTypeInfo(el.type).hasOptions && el.source == null) {
        final live = (el.options ?? const <UiFbOption>[]).where((o) => o.archived != true);
        if (live.isEmpty) add('error', el.id, '“${name(el.id)}” has no options to choose from.');
        final vals = <String>{};
        for (final o in el.options ?? const <UiFbOption>[]) {
          if (vals.contains(o.value)) add('error', el.id, '“${name(el.id)}” has two options stored as “${o.value}”.');
          vals.add(o.value);
        }
      }
      if (el.type == UiFbFieldType.calculated && (el.calc?.args.isEmpty ?? true)) add('warning', el.id, '“${name(el.id)}” doesn’t use any answers yet.');
    }
    if (el is UiFbGroup && el.repeat != null && (el.key == null || el.key!.isEmpty)) {
      add('error', el.id, 'The repeating section “${name(el.id)}” needs a data key to store its entries under.');
    }
    if (el is UiFbGroup && el.repeat != null && el.repeat!.min != null && el.repeat!.max != null && el.repeat!.min! > el.repeat!.max!) {
      add('error', el.id, '“${name(el.id)}” allows at most ${jsString(el.repeat!.max)} entries but needs at least ${jsString(el.repeat!.min)}.');
    }
  }
  // Rules pointing at things that no longer exist, or at archived things.
  final allRefs = <String, Set<String>>{...dependencyGraph(def)};
  for (final el in allElements(def)) {
    if (el is! UiFbField) continue;
    final extra = <String>[];
    if (el.disabled != null && el.disabled!.isConditional) conditionRefs(el.disabled!.when, extra);
    for (final s in el.setValue ?? const <UiFbSetValue>[]) {
      conditionRefs(s.when, extra);
    }
    for (final v in el.validators ?? const <UiFbValidatorRule>[]) {
      conditionRefs(v.when, extra);
    }
    if (extra.isNotEmpty) allRefs[el.id] = {...?allRefs[el.id], ...extra};
  }
  for (final MapEntry(key: owner, value: refs) in allRefs.entries) {
    for (final r in refs) {
      final target = idx[r];
      if (target == null) {
        add('error', owner, 'A rule on “${name(owner)}” refers to a question that was deleted.');
      } else if (target.asElement?.archived == true) {
        add('warning', owner, 'A rule on “${name(owner)}” uses “${name(r)}”, which is archived.');
      }
    }
  }
  // Jumps must go forward.
  for (var i = 0; i < def.pages.length; i++) {
    final p = def.pages[i];
    for (final j in p.jumps ?? const <UiFbJump>[]) {
      if (j.to == 'end') continue;
      final ti = def.pages.indexWhere((x) => x.id == j.to);
      if (ti < 0) {
        add('error', p.id, 'A jump after “${name(p.id)}” goes to a page that was deleted.');
      } else if (ti <= i) {
        add('error', p.id, 'A jump after “${name(p.id)}” goes back to “${name(j.to)}”. Jumps can only go forward.');
      }
    }
  }
  for (final loop in findCycles(def)) {
    add('error', loop[0], 'These depend on each other in a loop: ${loop.map((id) => '“${name(id)}”').join(' $_arrow ')} $_arrow “${name(loop[0])}”.');
  }
  return out;
}

/// "→", built from its code point so the source holds no arrow glyph (the style contract
/// keeps glyphs out of the library; here it is wording, not an icon).
final String _arrow = String.fromCharCode(0x2192);

// ── Loading and comparing versions ───────────────────────────────────────────────────────────

/// Brings a stored definition (JSON, or a [UiFormDefinition]) up to the current schema version
/// and fills in defaults: an id, a title, settings, and at least one page.
UiFormDefinition migrateDefinition(Object? raw) {
  final source = raw is UiFormDefinition ? raw.toJson() : raw;
  final d = source is Map ? jsonCloneMap(source.cast<String, Object?>()) : <String, Object?>{};
  final rawPages = d['pages'];
  final pages = rawPages is List && rawPages.isNotEmpty ? rawPages : [createPage().toJson()];
  String? str(Object? v) => v is String ? v : (v == null ? null : jsString(v));
  final id = str(d['id']);
  d['schemaVersion'] = uiFbSchemaVersion;
  d['id'] = id != null && id.isNotEmpty ? id : fbUid('form');
  d['title'] = d['title'] ?? 'Untitled form';
  d['settings'] = d['settings'] ?? <String, Object?>{};
  d['pages'] = [
    for (final p in pages)
      () {
        final m = p is Map ? p.cast<String, Object?>() : <String, Object?>{};
        final pid = str(m['id']);
        return {...m, 'id': pid != null && pid.isNotEmpty ? pid : fbUid('page'), 'elements': m['elements'] ?? <Object?>[]};
      }(),
  ];
  return UiFormDefinition.fromJson(d);
}

class UiFbRenamedKey {
  const UiFbRenamedKey({required this.id, required this.from, required this.to});
  final String id;
  final String from;
  final String to;
  UiJson toJson() => {'id': id, 'from': from, 'to': to};
}

class UiFbTypeChange {
  const UiFbTypeChange({required this.id, required this.from, required this.to, required this.compatible});
  final String id;
  final UiFbFieldType from;
  final UiFbFieldType to;
  final bool compatible;
  UiJson toJson() => {'id': id, 'from': from.name, 'to': to.name, 'compatible': compatible};
}

class UiFbOptionsRemoved {
  const UiFbOptionsRemoved({required this.id, required this.values});
  final String id;
  final List<String> values;
  UiJson toJson() => {'id': id, 'values': values};
}

class UiFbDiff {
  final List<String> added = [];
  final List<String> removed = [];
  final List<String> archived = [];
  final List<String> restored = [];
  final List<UiFbRenamedKey> renamedKeys = [];
  final List<UiFbTypeChange> typeChanged = [];
  final List<UiFbOptionsRemoved> optionsRemoved = [];
  final List<String> rulesChanged = [];

  /// One line per change, for a "what will change" summary.
  final List<String> summary = [];

  UiJson toJson() => {
    'added': added,
    'removed': removed,
    'archived': archived,
    'restored': restored,
    'renamedKeys': [for (final r in renamedKeys) r.toJson()],
    'typeChanged': [for (final t in typeChanged) t.toJson()],
    'optionsRemoved': [for (final o in optionsRemoved) o.toJson()],
    'rulesChanged': rulesChanged,
    'summary': summary,
  };
}

String _rulesSig(UiFbElement el) {
  if (el is UiFbStatic) return jsonEncode(el.visibility?.toJson());
  if (el is UiFbGroup) return jsonEncode([el.visibility?.toJson(), el.disabled?.toJson(), el.repeat?.toJson()]);
  final f = el as UiFbField;
  return jsonEncode([
    f.visibility?.toJson(),
    f.disabled?.toJson(),
    f.required?.toJson(),
    f.setValue?.map((s) => s.toJson()).toList(),
    f.validators?.map((v) => v.toJson()).toList(),
    f.calc?.toJson(),
  ]);
}

String? _keyOf(UiFbElement e) => e is UiFbField ? e.key : (e is UiFbGroup ? e.key : null);

/// What changed between a published definition and a draft, worded for a confirmation screen.
UiFbDiff diffDefinitions(UiFormDefinition before, UiFormDefinition after) {
  final a = {for (final e in allElements(before)) e.id: e};
  final b = {for (final e in allElements(after)) e.id: e};
  final diff = UiFbDiff();
  String nm(UiFbElement e) => '“${elementName(e)}”';
  for (final MapEntry(key: id, value: e) in b.entries) {
    final old = a[id];
    if (old == null) {
      diff.added.add(id);
      diff.summary.add('Added ${nm(e)}');
      continue;
    }
    if (old.archived != true && e.archived == true) {
      diff.archived.add(id);
      diff.summary.add('Archived ${nm(e)} (its saved answers are kept)');
    }
    if (old.archived == true && e.archived != true) {
      diff.restored.add(id);
      diff.summary.add('Restored ${nm(e)}');
    }
    final ok = _keyOf(old);
    final ek = _keyOf(e);
    if (ok != null && ok.isNotEmpty && ek != null && ek.isNotEmpty && ok != ek) {
      diff.renamedKeys.add(UiFbRenamedKey(id: id, from: ok, to: ek));
      diff.summary.add('Renamed the data key of ${nm(e)} from “$ok” to “$ek”');
    }
    if (old is UiFbField && e is UiFbField) {
      if (old.type != e.type) {
        final compatible = typesCompatible(old.type, e.type) && valueKindOf(old.type) == valueKindOf(e.type);
        diff.typeChanged.add(UiFbTypeChange(id: id, from: old.type, to: e.type, compatible: compatible));
        diff.summary.add('Changed ${nm(e)} from ${fieldTypeInfo(old.type).label} to ${fieldTypeInfo(e.type).label}${compatible ? '' : '. Older answers may not show correctly'}');
      }
      final now = {for (final o in e.options ?? const <UiFbOption>[]) if (o.archived != true) o.value};
      final gone = [for (final o in old.options ?? const <UiFbOption>[]) if (o.archived != true && !now.contains(o.value)) o.value];
      if (old.source == null && e.source == null && gone.isNotEmpty) {
        diff.optionsRemoved.add(UiFbOptionsRemoved(id: id, values: gone));
        diff.summary.add('Removed ${gone.length} option${gone.length > 1 ? 's' : ''} from ${nm(e)}');
      }
      if (old.source?.type != e.source?.type) {
        diff.summary.add(e.source != null ? '${nm(e)} now takes its options from a data source' : '${nm(e)} now uses a typed list of options');
      } else if (jsonEncode(old.source?.toJson()['params'] ?? const {}) != jsonEncode(e.source?.toJson()['params'] ?? const {})) {
        diff.summary.add('Changed the data source settings of ${nm(e)}');
      }
    }
    if (_rulesSig(old) != _rulesSig(e)) {
      diff.rulesChanged.add(id);
      diff.summary.add('Changed the rules of ${nm(e)}');
    }
  }
  for (final MapEntry(key: id, value: e) in a.entries) {
    if (!b.containsKey(id)) {
      diff.removed.add(id);
      diff.summary.add('Deleted ${nm(e)}');
    }
  }
  return diff;
}
