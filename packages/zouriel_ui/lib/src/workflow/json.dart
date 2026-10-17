/// JSON helpers shared by the workflow model. The model is typed views (extension types) over the
/// spec JSON, so these read values leniently: a missing or mistyped key gives the default rather
/// than throwing, and every key the view doesn't know stays in the map untouched.
library;

import '../form_builder/engine/js.dart';

export '../form_builder/engine/js.dart' show UiJson, jsonClone, jsonEquals, jsonStringify, jsString, jsNumberToString;

/// A JSON object (`{}` for anything else). Maps from `jsonDecode` are used as they are, so the
/// view and the stored JSON stay the same object.
UiJson wfMap(Object? v) {
  if (v is Map<String, Object?>) return v;
  if (v is Map) return v.cast<String, Object?>();
  return <String, Object?>{};
}

/// A JSON object or null.
UiJson? wfMapOrNull(Object? v) => v is Map ? wfMap(v) : null;

String wfStr(Object? v, [String fallback = '']) => v is String ? v : (v == null ? fallback : jsString(v));
String? wfStrOrNull(Object? v) => v == null ? null : (v is String ? v : jsString(v));
num? wfNum(Object? v) => v is num ? v : null;
int? wfInt(Object? v) => v is num ? v.toInt() : null;
bool? wfBool(Object? v) => v is bool ? v : null;

/// A list read with [read] (empty when absent).
List<T> wfList<T>(Object? v, T Function(Object? x) read) => v is List ? [for (final x in v) read(x)] : <T>[];

/// A list read with [read], or null when absent.
List<T>? wfListOrNull<T>(Object? v, T Function(Object? x) read) => v is List ? [for (final x in v) read(x)] : null;

List<String> wfStrings(Object? v) => wfList(v, (x) => wfStr(x));
List<String>? wfStringsOrNull(Object? v) => wfListOrNull(v, (x) => wfStr(x));

/// `{...base, ...patch}` with keys whose patch value is null removed (the web `undefined`).
/// Existing keys keep their place; new keys go at the end, like a JavaScript spread.
UiJson wfPatch(UiJson base, UiJson patch) {
  final out = <String, Object?>{...base};
  patch.forEach((k, v) {
    if (v == null) {
      out.remove(k);
    } else {
      out[k] = v;
    }
  });
  return out;
}

/// [json] without null values (an object built with optional keys).
UiJson wfCompact(UiJson json) => {
  for (final e in json.entries)
    if (e.value != null) e.key: e.value,
};
