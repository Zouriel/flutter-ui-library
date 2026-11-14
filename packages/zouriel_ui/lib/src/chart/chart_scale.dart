import 'dart:math' as math;

/// The y scale of a chart (the web `UiChartScale`): a zero-based domain on round numbers and the
/// gridline values in it.
class UiChartScale {
  const UiChartScale({required this.min, required this.max, required this.ticks});

  /// Bottom of the plot: 0, or a round number below the lowest negative value.
  final double min;

  /// Top of the plot: a round number at or above the highest value (1 when every value is 0).
  final double max;

  /// Gridline values from [min] to [max], evenly spaced and always including 0.
  final List<double> ticks;
}

double _clean(double n) {
  final c = double.parse(n.toStringAsPrecision(12));
  return c == 0 ? 0 : c;
}

/// The web `uiChartScale`: a y scale that starts from zero, on round steps (1, 2, 2.5 or 5 times a
/// power of ten): the smallest such step that needs at most four intervals, or five when the data
/// has values on both sides of zero. Values that are not finite count as 0. With no data, or all
/// zeros, the scale is 0 to 1 with a single tick at 0.
UiChartScale uiChartScale(Iterable<num> values) {
  var lo = 0.0;
  var hi = 0.0;
  for (final v in values) {
    if (!v.isFinite) continue;
    if (v < lo) lo = v.toDouble();
    if (v > hi) hi = v.toDouble();
  }
  if (lo == 0 && hi == 0) return const UiChartScale(min: 0, max: 1, ticks: [0]);
  final most = lo < 0 && hi > 0 ? 5 : 4;
  int below(double step) => (-lo / step - 1e-9).ceil();
  int above(double step) => (hi / step - 1e-9).ceil();
  var step = 0.0;
  search:
  for (var exp = (math.log(hi - lo) / math.ln10).floor() - 2;; exp++) {
    for (final m in const [1.0, 2.0, 2.5, 5.0]) {
      step = _clean(m * math.pow(10, exp).toDouble());
      if (below(step) + above(step) <= most) break search;
    }
  }
  return UiChartScale(
    min: _clean(-below(step) * step),
    max: _clean(above(step) * step),
    ticks: [for (var i = -below(step); i <= above(step); i++) _clean(i * step)],
  );
}

/// How an x label lines up in its band: centred, or pulled in from an edge of the plot.
enum UiChartLabelAlign { start, center, end }

/// One x label that is shown (the web `UiChartLabel`).
class UiChartLabel {
  const UiChartLabel(this.index, this.align);
  final int index;
  final UiChartLabelAlign align;

  @override
  bool operator ==(Object other) => other is UiChartLabel && other.index == index && other.align == align;

  @override
  int get hashCode => Object.hash(index, align);

  @override
  String toString() => 'UiChartLabel($index, ${align.name})';
}

/// The web `uiChartLabels`: which x labels to show so that none overlap: every label when they
/// fit, otherwise every nth, counted back from the last category (the latest is always labelled).
/// [widths] are the labels' widths, [band] the width of one category and [gap] the least space
/// between two labels. A band of 0 shows every label.
List<UiChartLabel> uiChartLabels(List<double> widths, double band, {double gap = 8}) {
  final n = widths.length;
  if (n == 0) return const [];
  if (!(band > 0)) return [for (var i = 0; i < n; i++) UiChartLabel(i, UiChartLabelAlign.center)];
  final widest = widths.reduce(math.max);
  // The last label lines up with the plot's end when it is wider than its band; leave room for that shift.
  final step = math.max(1, ((widest + gap + math.max(0, (widest - band) / 2)) / band).ceil());
  final total = band * n;
  final out = <UiChartLabel>[];
  double? nextLeft;
  for (var index = n - 1; index >= 0; index -= step) {
    final w = widths[index];
    final centre = (index + 0.5) * band;
    var align = UiChartLabelAlign.center;
    var left = centre - w / 2;
    if (left < 0) {
      align = UiChartLabelAlign.start;
      left = index * band;
    } else if (left + w > total) {
      align = UiChartLabelAlign.end;
      left = (index + 1) * band - w;
    }
    // A label pulled in from the edge can reach its neighbour: leave it out, the neighbour stays.
    if (nextLeft != null && left + w + gap > nextLeft) continue;
    if (left < 0) continue;
    out.add(UiChartLabel(index, align));
    nextLeft = left;
  }
  return out.reversed.toList();
}
