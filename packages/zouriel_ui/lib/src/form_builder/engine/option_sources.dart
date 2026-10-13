import 'dart:async';

import 'js.dart';
import 'schema.dart';

/// One choice a source offers. `value` is what rules compare; `label` is what people see.
class UiFbSourceItem {
  const UiFbSourceItem({required this.value, required this.label, this.description});

  /// A `String` or a `num`.
  final Object value;
  final String label;

  /// A second line under the label in the list (an email, a code…). Not saved.
  final String? description;

  UiJson toJson() => {'value': value, 'label': label, if (description != null) 'description': description};

  @override
  bool operator ==(Object other) => other is UiFbSourceItem && other.value == value && other.label == label && other.description == description;

  @override
  int get hashCode => Object.hash(value, label, description);

  @override
  String toString() => 'UiFbSourceItem(${toJson()})';
}

/// How a sourced answer is saved: the value and, alongside it, the label it had when it was
/// picked, so saved answers stay readable even if the source later renames or removes the record.
/// In answers it is the JSON map `{ "value": …, "label": … }`; this class reads and writes it.
class UiFbChoice {
  const UiFbChoice({required this.value, required this.label});
  final Object value;
  final String label;

  UiJson toJson() => {'value': value, 'label': label};

  @override
  bool operator ==(Object other) => other is UiFbChoice && other.value == value && other.label == label;

  @override
  int get hashCode => Object.hash(value, label);
}

/// Lets a running request know it is no longer wanted (the Dart stand-in for `AbortSignal`).
class UiFbAbortSignal {
  bool _aborted = false;
  final List<void Function()> _listeners = [];

  bool get aborted => _aborted;

  /// Calls [fn] when aborted (straight away if it already is).
  void onAbort(void Function() fn) {
    if (_aborted) {
      fn();
    } else {
      _listeners.add(fn);
    }
  }
}

/// Owns a [UiFbAbortSignal] and aborts it (the stand-in for `AbortController`).
class UiFbAbortController {
  final UiFbAbortSignal signal = UiFbAbortSignal();

  void abort() {
    if (signal._aborted) return;
    signal._aborted = true;
    for (final fn in [...signal._listeners]) {
      fn();
    }
    signal._listeners.clear();
  }
}

/// What `search` is asked for.
class UiFbSourceQuery {
  UiFbSourceQuery({required this.query, required this.page, required this.pageSize, required this.params, UiFbAbortSignal? signal})
    : signal = signal ?? UiFbAbortSignal();

  /// What the person typed (trimmed). Empty when the list first opens.
  final String query;

  /// 1 for the first page.
  final int page;
  final int pageSize;

  /// The source's settings for this field. Values may come from other answers.
  final Map<String, Object?> params;

  /// Aborted when a newer search replaces this one.
  final UiFbAbortSignal signal;
}

/// One page of results. Give `hasMore`, or `total`, or neither (a full page means there may be more).
class UiFbSourcePage {
  const UiFbSourcePage({required this.items, this.hasMore, this.total});
  final List<UiFbSourceItem> items;
  final bool? hasMore;
  final num? total;

  UiJson toJson() => {'items': [for (final i in items) i.toJson()], 'hasMore': hasMore, 'total': total};
}

/// A setting admins fill in for a source, e.g. which faculty's courses to list.
class UiFbSourceParamSpec {
  const UiFbSourceParamSpec({required this.key, required this.label, this.kind, this.options, this.hint, this.placeholder, this.required = false});

  factory UiFbSourceParamSpec.fromJson(Object? json) {
    final j = json is Map ? json.cast<String, Object?>() : const <String, Object?>{};
    return UiFbSourceParamSpec(
      key: j['key'] as String? ?? '',
      label: j['label'] as String? ?? '',
      kind: j['kind'] as String?,
      options: (j['options'] as List?)?.map((o) {
        final m = (o as Map).cast<String, Object?>();
        return (value: m['value'] as String? ?? '', label: m['label'] as String? ?? '');
      }).toList(),
      hint: j['hint'] as String?,
      placeholder: j['placeholder'] as String?,
      required: j['required'] == true,
    );
  }

  final String key;
  final String label;

  /// How a fixed value is entered: `text`, `number` or `select`. Every param can also take another
  /// question's answer.
  final String? kind;
  final List<({String value, String label})>? options;
  final String? hint;
  final String? placeholder;

  /// Searching waits until this has a value (e.g. Cities need a Country first).
  final bool required;

  UiJson toJson() => {
    'key': key,
    'label': label,
    if (kind != null) 'kind': kind,
    if (options != null) 'options': [for (final o in options!) {'value': o.value, 'label': o.label}],
    if (hint != null) 'hint': hint,
    if (placeholder != null) 'placeholder': placeholder,
    if (required) 'required': true,
  };
}

/// A list of options that lives in your app, usually behind an API. Pass sources to the engine
/// (`optionSources`); they appear in the builder as data sources for dropdowns and multi-selects,
/// and the renderer searches them page by page as people type.
abstract interface class UiFbOptionSourceDef {
  /// Stored in the form JSON. Keep it stable.
  String get type;

  /// What admins see, e.g. "Students".
  String get label;
  String? get description;
  List<UiFbSourceParamSpec>? get params;

  /// Results per page. Default 20.
  int? get pageSize;

  /// Don't search until this many characters are typed (for huge lists). Default 0.
  int? get minQueryLength;

  /// Pause after typing before searching. Default 250ms.
  int? get debounceMs;

  FutureOr<UiFbSourcePage> search(UiFbSourceQuery q);
}

/// A [UiFbOptionSourceDef] from a search function.
class UiFbOptionSource implements UiFbOptionSourceDef {
  const UiFbOptionSource({
    required this.type,
    required this.label,
    this.description,
    this.params,
    this.pageSize,
    this.minQueryLength,
    this.debounceMs,
    required this._search,
  });

  @override
  final String type;
  @override
  final String label;
  @override
  final String? description;
  @override
  final List<UiFbSourceParamSpec>? params;
  @override
  final int? pageSize;
  @override
  final int? minQueryLength;
  @override
  final int? debounceMs;
  final FutureOr<UiFbSourcePage> Function(UiFbSourceQuery q) _search;

  @override
  FutureOr<UiFbSourcePage> search(UiFbSourceQuery q) => _search(q);
}

/// Field types that can take their options from a source (long lists need search, not a wall of radios).
const List<UiFbFieldType> uiFbSourceFieldTypes = [UiFbFieldType.select, UiFbFieldType.multiselect];

/// Whether an answer is a saved `{ value, label }` (any map with a `value`).
bool isChoice(Object? v) => v is Map && v.containsKey('value');

/// The comparable part of an answer: a saved `{ value, label }` gives its value; anything else is itself.
Object? optionValueOf(Object? v) {
  if (v is List) return [for (final x in v) optionValueOf(x)];
  return isChoice(v) ? (v as Map)['value'] : v;
}

/// Turns whatever was stored into `{ value, label }` (a bare value keeps itself as its label).
UiJson? toChoice(Object? v) {
  if (v == null || v == '') return null;
  if (isChoice(v)) {
    final m = v as Map;
    final label = m['label'] ?? m['value'];
    return {'value': m['value'], 'label': jsString(label)};
  }
  return {'value': v, 'label': jsString(v)};
}

/// Whether a page of results was the last one.
bool sourceHasMore(UiFbSourcePage page, int loaded, int pageSize) {
  if (page.hasMore != null) return page.hasMore!;
  if (page.total != null) return loaded < page.total!;
  return page.items.length >= pageSize;
}
