/// JavaScript value semantics the form engine depends on.
///
/// The Angular engine is the reference: a form must behave the same in both. Its rules lean on
/// JavaScript's `String(v)`, `Number(v)`, truthiness and `Math.round`, which differ from Dart's
/// (`10.0.toString()` is `10.0`, `(-2.5).round()` is `-3`). These helpers reproduce the JS results
/// for JSON values (null, bool, num, String, List, Map).
library;

import 'dart:convert';

/// A JSON object, as decoded by `jsonDecode`.
typedef UiJson = Map<String, Object?>;

/// JS `String(v)` for a JSON value.
String jsString(Object? v) {
  if (v == null) return 'null';
  if (v is String) return v;
  if (v is bool) return v ? 'true' : 'false';
  if (v is num) return jsNumberToString(v);
  if (v is List) return v.map((x) => x == null ? '' : jsString(x)).join(',');
  if (v is Map) return '[object Object]';
  return v.toString();
}

/// JS `Number.prototype.toString` for a Dart number.
String jsNumberToString(num n) {
  if (n is int) return n.toString();
  final d = n.toDouble();
  if (d.isNaN) return 'NaN';
  if (d.isInfinite) return d > 0 ? 'Infinity' : '-Infinity';
  if (d == 0) return '0';
  final s = d.toString();
  // Dart writes integral doubles below 1e21 as `10.0`; JS writes `10`.
  if (s.endsWith('.0')) return s.substring(0, s.length - 2);
  return s;
}

final RegExp _jsDecimal = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$');
final RegExp _jsRadix = RegExp(r'^0([xXoObB])([0-9a-fA-F]+)$');

/// JS `Number(v)`: a number, or NaN.
double jsNumber(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1 : 0;
  if (v is List) return jsNumber(jsString(v));
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return 0;
    if (s == 'Infinity' || s == '+Infinity') return double.infinity;
    if (s == '-Infinity') return double.negativeInfinity;
    if (_jsDecimal.hasMatch(s)) return double.parse(s);
    final m = _jsRadix.firstMatch(s);
    if (m != null) {
      final radix = switch (m.group(1)!.toLowerCase()) { 'x' => 16, 'o' => 8, _ => 2 };
      final n = int.tryParse(m.group(2)!, radix: radix);
      return n?.toDouble() ?? double.nan;
    }
    return double.nan;
  }
  return double.nan;
}

/// A finite number as the tidiest Dart number: whole values become `int` (as JSON writes them).
num tidyNum(num n) {
  if (n is int) return n;
  if (n.isFinite && n == n.truncateToDouble() && n.abs() < 9007199254740992) return n.toInt();
  return n;
}

/// JS truthiness (`!!v`).
bool jsTruthy(Object? v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return !(v == 0 || v.isNaN);
  if (v is String) return v.isNotEmpty;
  return true;
}

/// JS `Math.round`: halves round up (towards +Infinity).
double jsRound(double x) {
  if (!x.isFinite) return x;
  final f = x.floorToDouble();
  return x - f >= 0.5 ? f + 1 : f;
}

/// A deep copy of a JSON value (like `structuredClone`).
Object? jsonClone(Object? v) {
  if (v is Map) return <String, Object?>{for (final e in v.entries) e.key as String: jsonClone(e.value)};
  if (v is List) return [for (final x in v) jsonClone(x)];
  return v;
}

/// A deep copy of a JSON object.
UiJson jsonCloneMap(Map<String, Object?> m) => jsonClone(m) as UiJson;

/// Structural equality of JSON values; key order doesn't matter, `1 == 1.0`.
bool jsonEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is num && b is num) return a == b;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !jsonEquals(a[k], b[k])) return false;
    }
    return true;
  }
  return a == b;
}

/// `JSON.stringify` for a JSON value (non-JSON objects fall back to their `toJson`/`toString`).
String jsonStringify(Object? v) => jsonEncode(v, toEncodable: (o) {
  try {
    return (o as dynamic).toJson();
  } catch (_) {
    return o.toString();
  }
});

/// JS `a.localeCompare`-free ordering of strings: by UTF-16 code units, like `<` in JS.
int jsCompareStrings(String a, String b) => a.compareTo(b);
