import 'dart:math' as math;

import 'conditions.dart';
import 'js.dart';
import 'schema.dart';

abstract interface class UiFbCalcContext {
  /// The answers behind a reference. One value for an ordinary field; one per entry for a field
  /// inside a repeatable section asked about from outside it.
  List<Object?> values(String ref);

  /// Number of entries, when `ref` is a repeatable group (otherwise `null`).
  int? rows(String ref);
  String today();
}

/// A [UiFbCalcContext] from functions.
class UiFbCalcFns implements UiFbCalcContext {
  UiFbCalcFns({required this._values, int? Function(String ref)? rows, required this._today}) : _rows = rows ?? ((_) => null);
  final List<Object?> Function(String) _values;
  final int? Function(String) _rows;
  final String Function() _today;
  @override
  List<Object?> values(String ref) => _values(ref);
  @override
  int? rows(String ref) => _rows(ref);
  @override
  String today() => _today();
}

class UiFbCalcOpInfo {
  const UiFbCalcOpInfo({required this.op, required this.label, required this.verb, required this.hint, this.arity, this.dates = false, this.text = false});
  final UiFbCalcOp op;
  final String label;

  /// How the inputs are described: "Add up Price and Tax".
  final String verb;
  final String hint;

  /// Exact number of inputs, when it has one.
  final int? arity;

  /// Inputs are dates rather than numbers.
  final bool dates;
  final bool text;
}

const List<UiFbCalcOpInfo> uiFbCalcOps = [
  UiFbCalcOpInfo(op: UiFbCalcOp.sum, label: 'Add up', verb: 'Total of', hint: 'Adds all the inputs together. Inside a repeating section it adds every entry.'),
  UiFbCalcOpInfo(op: UiFbCalcOp.subtract, label: 'Subtract', verb: 'Difference of', hint: 'The first input minus all the others.'),
  UiFbCalcOpInfo(op: UiFbCalcOp.multiply, label: 'Multiply', verb: 'Product of', hint: 'Multiplies the inputs, e.g. quantity × price.'),
  UiFbCalcOpInfo(op: UiFbCalcOp.divide, label: 'Divide', verb: 'Ratio of', hint: 'The first input divided by the second.', arity: 2),
  UiFbCalcOpInfo(op: UiFbCalcOp.average, label: 'Average', verb: 'Average of', hint: 'The mean of all the inputs.'),
  UiFbCalcOpInfo(op: UiFbCalcOp.min, label: 'Smallest', verb: 'Smallest of', hint: 'The lowest of the inputs.'),
  UiFbCalcOpInfo(op: UiFbCalcOp.max, label: 'Largest', verb: 'Largest of', hint: 'The highest of the inputs.'),
  UiFbCalcOpInfo(op: UiFbCalcOp.count, label: 'Count', verb: 'Count of', hint: 'How many answers are filled in. Counts ticked options, and entries in a repeating section.'),
  UiFbCalcOpInfo(op: UiFbCalcOp.ageYears, label: 'Age in years', verb: 'Age from', hint: 'Whole years from a date until today (or until a second date).', dates: true),
  UiFbCalcOpInfo(op: UiFbCalcOp.daysBetween, label: 'Days between', verb: 'Days between', hint: 'Days from the first date to the second (or to today).', dates: true),
  UiFbCalcOpInfo(op: UiFbCalcOp.concat, label: 'Join text', verb: 'Joined text of', hint: 'Puts the inputs together, separated by spaces.', text: true),
];

UiFbCalcOpInfo calcOpInfo(UiFbCalcOp op) => uiFbCalcOps.firstWhere((o) => o.op == op, orElse: () => uiFbCalcOps[0]);

double? _toNum(Object? v) {
  if (v is bool) return v ? 1 : 0;
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is String && v.trim().isNotEmpty) {
    final n = jsNumber(v);
    if (n.isFinite) return n;
  }
  return null;
}

final RegExp _datePrefix = RegExp(r'^\d{4}-\d{2}-\d{2}');

/// A calendar day as a UTC date (so day differences never see a clock change).
DateTime? _parseDate(Object? v) {
  if (v is! String || !_datePrefix.hasMatch(v)) return null;
  final p = v.substring(0, 10).split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}

List<Object?> _argValues(UiFbCalcArg a, UiFbCalcContext ctx) => switch (a) {
  UiFbCalcRefArg(:final ref) => ctx.values(ref),
  UiFbCalcNestedArg(:final calc) => [evaluateCalc(calc, ctx)],
  UiFbCalcConstArg(:final value) => [value],
};

/// The result of a calculation, or `null` when there's nothing to work it out from yet. Numbers
/// come back as `int` when whole (as JSON writes them), `double` otherwise; `concat` gives a String.
Object? evaluateCalc(UiFbCalc? c, UiFbCalcContext ctx) {
  if (c == null) return null;
  num? round(double? n) {
    if (n == null || !n.isFinite) return null;
    final d = c.decimals;
    if (d == null) return tidyNum(jsRound(n * 1e10) / 1e10);
    final f = math.pow(10, d).toDouble();
    return tidyNum(jsRound(n * f) / f);
  }

  final perArg = [for (final a in c.args) _argValues(a, ctx)];
  final nums = [for (final vs in perArg) for (final v in vs) _toNum(v)].whereType<double>().toList();
  switch (c.op) {
    case UiFbCalcOp.sum:
      return nums.isNotEmpty ? round(nums.fold<double>(0, (s, n) => s + n)) : null;
    case UiFbCalcOp.subtract:
      final totals = [for (final vs in perArg) vs.map(_toNum).whereType<double>().fold<double>(0, (s, n) => s + n)];
      if (nums.isEmpty) return null;
      final first = totals.isNotEmpty ? totals.first : 0.0;
      return round(first - totals.skip(1).fold<double>(0, (s, n) => s + n));
    case UiFbCalcOp.multiply:
      return nums.isNotEmpty ? round(nums.fold<double>(1, (s, n) => s * n)) : null;
    case UiFbCalcOp.divide:
      final a = _toNum(perArg.isNotEmpty && perArg[0].isNotEmpty ? perArg[0][0] : null);
      final b = _toNum(perArg.length > 1 && perArg[1].isNotEmpty ? perArg[1][0] : null);
      return a == null || b == null || b == 0 ? null : round(a / b);
    case UiFbCalcOp.average:
      return nums.isNotEmpty ? round(nums.fold<double>(0, (s, n) => s + n) / nums.length) : null;
    case UiFbCalcOp.min:
      return nums.isNotEmpty ? round(nums.reduce(math.min)) : null;
    case UiFbCalcOp.max:
      return nums.isNotEmpty ? round(nums.reduce(math.max)) : null;
    case UiFbCalcOp.count:
      var n = 0;
      for (var i = 0; i < c.args.length; i++) {
        final a = c.args[i];
        final rows = a is UiFbCalcRefArg ? ctx.rows(a.ref) : null;
        if (rows != null) {
          n += rows;
          continue;
        }
        for (final v in perArg[i]) {
          n += v is List ? v.length : (isEmptyValue(v) || v == false ? 0 : 1);
        }
      }
      return n;
    case UiFbCalcOp.ageYears || UiFbCalcOp.daysBetween:
      final from = _parseDate(perArg.isNotEmpty && perArg[0].isNotEmpty ? perArg[0][0] : null);
      final second = perArg.length > 1 && perArg[1].isNotEmpty ? perArg[1][0] : null;
      final to = _parseDate(second ?? ctx.today());
      if (from == null || to == null) return null;
      if (c.op == UiFbCalcOp.daysBetween) return to.difference(from).inDays;
      var years = to.year - from.year;
      if (to.month < from.month || (to.month == from.month && to.day < from.day)) years--;
      return years;
    case UiFbCalcOp.concat:
      final text = [
        for (final vs in perArg)
          for (final v in vs)
            if (!isEmptyValue(v)) v is List ? v.map((x) => x == null ? '' : jsString(x)).join(', ') : jsString(v),
      ];
      return text.isNotEmpty ? text.join(' ') : null;
  }
  return null;
}

/// "Total of “Price” and “Tax”"
String describeCalc(UiFbCalc? c, String Function(String ref) name) {
  if (c == null || c.args.isEmpty) return 'Not set up yet';
  final parts = [
    for (final a in c.args)
      switch (a) {
        UiFbCalcRefArg(:final ref) => '“${name(ref)}”',
        UiFbCalcNestedArg(:final calc) => '(${describeCalc(calc, name)})',
        UiFbCalcConstArg(:final value) => jsString(value),
      },
  ];
  final list = parts.length > 1 ? '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}' : parts[0];
  final info = calcOpInfo(c.op);
  if (c.op == UiFbCalcOp.ageYears && parts.length == 1) return 'Age from ${parts[0]}';
  if (c.op == UiFbCalcOp.daysBetween && parts.length == 1) return 'Days from ${parts[0]} until today';
  return '${info.verb} $list';
}
