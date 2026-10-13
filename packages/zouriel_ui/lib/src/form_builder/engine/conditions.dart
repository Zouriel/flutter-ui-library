import 'field_types.dart';
import 'js.dart';
import 'option_sources.dart';
import 'schema.dart';

/// What a condition can ask about the form while it is being filled in.
abstract interface class UiFbConditionContext {
  /// The current answer of a field (in the asking element's repeat row, if it shares one).
  Object? value(String ref);
  bool visible(String ref);
  bool complete(String ref);

  /// Number of entries in a repeatable group; null when `ref` isn't one (rules read that as 0).
  int? rows(String ref);

  /// Today as `YYYY-MM-DD`.
  String today();
}

/// A [UiFbConditionContext] from functions (handy for tests and simple hosts).
class UiFbConditionFns implements UiFbConditionContext {
  UiFbConditionFns({
    required this._value,
    bool Function(String ref)? visible,
    bool Function(String ref)? complete,
    int? Function(String ref)? rows,
    required this._today,
  }) : _visible = visible ?? ((_) => true),
       _complete = complete ?? ((_) => true),
       _rows = rows ?? ((_) => 0);

  final Object? Function(String) _value;
  final bool Function(String) _visible;
  final bool Function(String) _complete;
  final int? Function(String) _rows;
  final String Function() _today;

  @override
  Object? value(String ref) => _value(ref);
  @override
  bool visible(String ref) => _visible(ref);
  @override
  bool complete(String ref) => _complete(ref);
  @override
  int? rows(String ref) => _rows(ref);
  @override
  String today() => _today();
}

/// Empty: null, '', an empty list, or NaN.
bool isEmptyValue(Object? v) => v == null || v == '' || (v is List && v.isEmpty) || (v is double && v.isNaN);

String _two(int n) => n.toString().padLeft(2, '0');

/// A date as `YYYY-MM-DD` (its local calendar day).
String isoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// `YYYY-MM-DD` shifted by `days`.
String addDays(String iso, num days) {
  final p = iso.split('-').map((s) => jsNumber(s)).toList();
  final y = p.isNotEmpty ? p[0] : double.nan;
  final m = p.length > 1 ? p[1] : double.nan;
  final d = p.length > 2 ? p[2] : double.nan;
  if (!y.isFinite || !m.isFinite || !d.isFinite || !days.isFinite) return 'NaN-NaN-NaN';
  return isoDate(DateTime(y.toInt(), m.toInt(), d.toInt() + days.toInt()));
}

/// The value an operand stands for right now.
Object? resolveOperand(UiFbOperand? o, UiFbConditionContext ctx) {
  if (o == null) return null;
  return switch (o) {
    UiFbRefOperand(:final ref) => ctx.value(ref),
    UiFbTodayOperand(:final days) => addDays(ctx.today(), days == 0 ? 0 : days),
    UiFbConstOperand(:final value) => value,
  };
}

String _norm(Object? v) => (v == null ? '' : jsString(v)).trim().toLowerCase();

/// A number from a number or a numeric string; null otherwise (booleans are not numbers here).
double? _num(Object? v) {
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is String && v.trim().isNotEmpty) {
    final n = jsNumber(v);
    if (n.isFinite) return n;
  }
  return null;
}

/// Orders numbers numerically and everything else (ISO dates, HH:MM times) as text.
num? _compare(Object? a, Object? b) {
  if (isEmptyValue(a) || isEmptyValue(b)) return null;
  final na = _num(a);
  final nb = _num(b);
  if (na != null && nb != null) return na - nb;
  final sa = jsString(a);
  final sb = jsString(b);
  final c = sa.compareTo(sb);
  return c < 0 ? -1 : c > 0 ? 1 : 0;
}

bool _same(Object? a, Object? b) {
  if (a is bool || b is bool) return jsTruthy(a) == jsTruthy(b);
  final c = _compare(a, b);
  if (c != null && _num(a) != null && _num(b) != null) return c == 0;
  return _norm(a) == _norm(b);
}

List<Object?> _asList(Object? v) => v is List ? v.cast<Object?>() : (isEmptyValue(v) ? const [] : [v]);

bool _evalRule(UiFbConditionRule r, UiFbConditionContext ctx) {
  switch (r.op) {
    case UiFbOperator.visible:
      return ctx.visible(r.ref);
    case UiFbOperator.hidden:
      return !ctx.visible(r.ref);
    case UiFbOperator.complete:
      return ctx.complete(r.ref);
    case UiFbOperator.incomplete:
      return !ctx.complete(r.ref);
    case UiFbOperator.rowsGte:
      return (ctx.rows(r.ref) ?? 0) >= (_num(resolveOperand(r.value, ctx)) ?? double.infinity);
    case UiFbOperator.rowsLte:
      return (ctx.rows(r.ref) ?? 0) <= (_num(resolveOperand(r.value, ctx)) ?? double.negativeInfinity);
  }
  // Answers from a data source are saved as { value, label }; rules compare the value.
  final v = optionValueOf(ctx.value(r.ref));
  switch (r.op) {
    case UiFbOperator.empty:
      return isEmptyValue(v) || v == false;
    case UiFbOperator.notEmpty:
      return !isEmptyValue(v) && v != false;
    case UiFbOperator.isTrue:
      return v == true;
    case UiFbOperator.isFalse:
      return v != true;
  }
  final info = operatorInfo(r.op);
  final target = optionValueOf(resolveOperand(r.value, ctx));
  // An unfinished rule ("Age is more than …") never matches.
  if (info.arity > 0 && isEmptyValue(target)) {
    return r.op == UiFbOperator.neq || r.op == UiFbOperator.noneOf || r.op == UiFbOperator.excludes ? !isEmptyValue(v) : false;
  }
  switch (r.op) {
    case UiFbOperator.eq:
      return _same(v, target);
    case UiFbOperator.neq:
      return !_same(v, target);
    case UiFbOperator.contains:
      return _norm(v).contains(_norm(target));
    case UiFbOperator.notContains:
      return !_norm(v).contains(_norm(target));
    case UiFbOperator.startsWith:
      return _norm(v).startsWith(_norm(target));
    case UiFbOperator.endsWith:
      return _norm(v).endsWith(_norm(target));
    case UiFbOperator.gt || UiFbOperator.after:
      final c = _compare(v, target);
      return c != null && c > 0;
    case UiFbOperator.gte || UiFbOperator.onOrAfter:
      final c = _compare(v, target);
      return c != null && c >= 0;
    case UiFbOperator.lt || UiFbOperator.before:
      final c = _compare(v, target);
      return c != null && c < 0;
    case UiFbOperator.lte || UiFbOperator.onOrBefore:
      final c = _compare(v, target);
      return c != null && c <= 0;
    case UiFbOperator.between:
      final hi = optionValueOf(resolveOperand(r.value2, ctx));
      final lo = _compare(v, target);
      final up = _compare(v, hi);
      return lo != null && up != null && lo >= 0 && up <= 0;
    case UiFbOperator.anyOf:
      return _asList(target).any((t) => _same(v, t));
    case UiFbOperator.noneOf:
      return !_asList(target).any((t) => _same(v, t));
    case UiFbOperator.includes:
      return _asList(v).any((x) => _same(x, target));
    case UiFbOperator.excludes:
      return !_asList(v).any((x) => _same(x, target));
    case UiFbOperator.includesAny:
      return _asList(target).any((t) => _asList(v).any((x) => _same(x, t)));
    case UiFbOperator.includesAll:
      return _asList(target).every((t) => _asList(v).any((x) => _same(x, t)));
    case UiFbOperator.countGte:
      return _asList(v).length >= (_num(target) ?? double.infinity);
    case UiFbOperator.countLte:
      return _asList(v).length <= (_num(target) ?? double.negativeInfinity);
  }
  return false;
}

/// Whether a condition holds. No condition, or an empty group, holds (it doesn't restrict anything yet).
bool evaluateCondition(UiFbCondition? c, UiFbConditionContext ctx) {
  if (c == null) return true;
  return switch (c) {
    UiFbConditionGroup(:final conditions, :final match) =>
      conditions.isEmpty ||
          (match == 'all'
              ? conditions.every((x) => evaluateCondition(x, ctx))
              : match == 'any'
              ? conditions.any((x) => evaluateCondition(x, ctx))
              : !conditions.any((x) => evaluateCondition(x, ctx))),
    UiFbConditionRule() => _evalRule(c, ctx),
  };
}

/// How the describer names things and shows values.
abstract interface class UiFbDescribeContext {
  String name(String ref);

  /// Shows a stored value the way people recognise it (e.g. an option's label).
  String value(String ref, Object? v);
}

/// A [UiFbDescribeContext] from functions.
class UiFbDescribeFns implements UiFbDescribeContext {
  UiFbDescribeFns({required this._name, required this._value});
  final String Function(String) _name;
  final String Function(String, Object?) _value;
  @override
  String name(String ref) => _name(ref);
  @override
  String value(String ref, Object? v) => _value(ref, v);
}

String _describeOperand(UiFbConditionRule rule, UiFbOperand? o, UiFbDescribeContext d) {
  if (o == null) return '…';
  switch (o) {
    case UiFbRefOperand(:final ref):
      return '“${d.name(ref)}”';
    case UiFbTodayOperand(:final days):
      final n = days;
      return n == 0 ? 'today' : n > 0 ? '${jsNumberToString(n)} day${n == 1 ? '' : 's'} from today' : '${jsNumberToString(-n)} day${n == -1 ? '' : 's'} ago';
    case UiFbConstOperand(:final value):
      if (isEmptyValue(value)) return '…';
      final info = operatorInfo(rule.op);
      if (info.countValue) return jsString(value);
      if (value is List) {
        final parts = [for (final x in value) d.value(rule.ref, x)];
        return parts.length > 1 ? '${parts.sublist(0, parts.length - 1).join(', ')} or ${parts.last}' : (parts.isEmpty ? '…' : parts[0]);
      }
      return d.value(rule.ref, value);
  }
}

/// "Country is any of UK or US and Age is at least 18"
String describeCondition(UiFbCondition? c, UiFbDescribeContext d, {bool nested = false}) {
  if (c == null) return 'always';
  switch (c) {
    case UiFbConditionGroup(:final conditions, :final match):
      if (conditions.isEmpty) return 'always';
      final parts = [for (final x in conditions) describeCondition(x, d, nested: true)];
      if (match == 'none') return 'none of these: ${parts.join('; ')}';
      final joined = parts.join(match == 'all' ? ' and ' : ' or ');
      return nested && parts.length > 1 ? '($joined)' : joined;
    case UiFbConditionRule():
      final info = operatorInfo(c.op);
      final name = '“${d.name(c.ref)}”';
      if (info.countValue) return '$name ${info.label.replaceFirst('…', _describeOperand(c, c.value, d))}';
      if (info.arity == 0) return '$name ${info.label}';
      if (info.arity == 2) return '$name ${info.label} ${_describeOperand(c, c.value, d)} and ${_describeOperand(c, c.value2, d)}';
      return '$name ${info.label} ${_describeOperand(c, c.value, d)}';
  }
}

/// Whether every rule in a condition has what it needs (a field, and values where needed).
bool conditionComplete(UiFbCondition? c) {
  if (c == null) return true;
  switch (c) {
    case UiFbConditionGroup(:final conditions):
      return conditions.every(conditionComplete);
    case UiFbConditionRule():
      if (c.ref.isEmpty) return false;
      final info = operatorInfo(c.op);
      bool filled(UiFbOperand? o) => switch (o) {
        null => false,
        UiFbRefOperand(:final ref) => ref.isNotEmpty,
        UiFbTodayOperand() => true,
        UiFbConstOperand(:final value) => !isEmptyValue(value),
      };
      if (info.arity >= 1 && !filled(c.value)) return false;
      if (info.arity == 2 && !filled(c.value2)) return false;
      return true;
  }
}
