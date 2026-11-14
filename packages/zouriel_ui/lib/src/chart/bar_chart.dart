import 'dart:math' as math;
import 'dart:ui' show FontFeature, PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../theme/theme.dart';
import 'chart_scale.dart';

/// One series of [UiBarChart] (the web `UiBarChartSeries`): a name, a value per category, and
/// optionally its own colour.
class UiBarChartSeries {
  const UiBarChartSeries({required this.name, required this.values, this.color});

  final String name;

  /// One value per category, in the order of the categories. A missing value counts as 0.
  final List<num> values;

  /// Default: the theme's chart colour for this position (`chart1` to `chart4`).
  final Color? color;
}

/// The most series one chart draws (the web `UI_BAR_CHART_MAX_SERIES`).
const int uiBarChartMaxSeries = 4;

/// `ui-bar-chart`: columns over categories, from a zero baseline. One series draws plain columns;
/// two to four draw grouped bars side by side with a legend. Hovering a category with a mouse,
/// tapping it, or focusing the chart and pressing the arrow keys shows its values in a small panel.
///
/// Screen readers get one node named [semanticLabel] whose value is a category and its numbers;
/// its increase and decrease actions move between categories (the web's hidden table and arrow
/// keys), and its tap chooses the category when [onCategorySelect] is set.
class UiBarChart extends StatefulWidget {
  const UiBarChart({
    super.key,
    required this.semanticLabel,
    this.categories = const [],
    this.series = const [],
    this.formatValue,
    this.height = 220,
    this.showValues = false,
    this.selectedIndex,
    this.onCategorySelect,
    this.minCategoryWidth,
    this.emptyLabel,
  });

  /// The chart's name for screen readers (the web `ariaLabel`).
  final String semanticLabel;

  /// The x labels, one per category, oldest first.
  final List<String> categories;

  /// One to four series. One draws plain columns; more draw grouped bars with a legend.
  final List<UiBarChartSeries> series;

  /// Formats a number for the axis, the panel, the value labels and screen readers. Default: the
  /// locale's decimal format.
  final String Function(num value)? formatValue;

  /// Height of the plot. The x labels and the legend come on top of it.
  final double height;

  /// A value above each bar, in text ink. For charts with a few bars.
  final bool showValues;

  /// The chosen category: its band is tinted, with a rule above its label in bold.
  final int? selectedIndex;

  /// A category was tapped, clicked or chosen with Enter or Space (the web `categorySelect`).
  final ValueChanged<int>? onCategorySelect;

  /// Least width of one category. When the plot is narrower than that for all of them it scrolls
  /// sideways inside the chart, starting at the latest; the y axis and the legend stay put.
  final double? minCategoryWidth;

  /// Shown over the axes when there is no data or every value is 0. Default: [UiStrings.noData].
  final String? emptyLabel;

  @override
  State<UiBarChart> createState() => _UiBarChartState();
}

class _UiBarChartState extends State<UiBarChart> {
  // Reversed, so it opens at the latest category (the inline end) and stays there when resized.
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'UiBarChart');
  int? _active;
  bool _keyboard = false;
  bool _ring = false;

  // Geometry of the last build, for the keys and the semantics actions.
  double _band = 0;
  double _innerW = 0;
  double _viewW = 0;

  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(UiBarChart old) {
    super.didUpdateWidget(old);
    if (_active != null && _active! >= widget.categories.length) _active = null;
  }

  List<UiBarChartSeries> get _drawn => widget.series.length > uiBarChartMaxSeries ? widget.series.sublist(0, uiBarChartMaxSeries) : widget.series;

  double _value(UiBarChartSeries s, int i) {
    if (i >= s.values.length) return 0;
    final v = s.values[i];
    return v.isFinite ? v.toDouble() : 0;
  }

  String _fmt(num v) {
    final f = widget.formatValue;
    if (f != null) return f(v);
    return NumberFormat.decimalPattern().format(v == v.roundToDouble() ? v.round() : v);
  }

  Color _color(int i) {
    final t = context.ui;
    return _drawn[i].color ?? [t.chart1, t.chart2, t.chart3, t.chart4][i];
  }

  /// "Feb: Income $50, Spending $75": one category for screen readers.
  String _summary(int i) {
    final drawn = _drawn;
    final parts = [for (final s in drawn) drawn.length > 1 ? '${s.name} ${_fmt(_value(s, i))}' : _fmt(_value(s, i))];
    return '${widget.categories[i]}: ${parts.join(', ')}';
  }

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  /// Left edge of band [i] inside the plot (bands run from the inline start).
  double _bandLeft(int i) => _rtl ? _innerW - (i + 1) * _band : i * _band;

  /// How far the plot's left edge is scrolled out of view.
  double get _hiddenLeft {
    final off = _scroll.hasClients ? _scroll.offset : 0.0;
    final extent = math.max(0.0, _innerW - _viewW);
    return _rtl ? off : extent - off;
  }

  void _show(int? i, {required bool keyboard}) {
    setState(() {
      _active = i;
      _keyboard = keyboard && i != null;
    });
    if (i == null || !keyboard || !_scroll.hasClients || _innerW <= _viewW) return;
    // Bring a band that is scrolled out of the plot into it.
    final left = _bandLeft(i);
    var hidden = _hiddenLeft;
    if (left < hidden) {
      hidden = left;
    } else if (left + _band > hidden + _viewW) {
      hidden = left + _band - _viewW;
    } else {
      return;
    }
    final extent = _innerW - _viewW;
    _scroll.jumpTo((_rtl ? hidden : extent - hidden).clamp(0.0, extent));
  }

  int? _indexAt(double dx) {
    final n = widget.categories.length;
    if (n == 0 || _band <= 0) return null;
    final i = (dx / _band).floor().clamp(0, n - 1);
    return _rtl ? n - 1 - i : i;
  }

  void _move(int delta) {
    final n = widget.categories.length;
    if (n == 0) return;
    final cur = _active;
    final next = cur == null ? (delta < 0 ? n - 1 : 0) : (cur + delta).clamp(0, n - 1);
    _show(next, keyboard: true);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final n = widget.categories.length;
    if (n == 0) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final back = _rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft;
    final forward = _rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight;
    if (k == back) {
      _move(-1);
    } else if (k == forward) {
      _move(1);
    } else if (k == LogicalKeyboardKey.home) {
      _show(0, keyboard: true);
    } else if (k == LogicalKeyboardKey.end) {
      _show(n - 1, keyboard: true);
    } else if (k == LogicalKeyboardKey.escape) {
      if (_active == null) return KeyEventResult.ignored;
      _show(null, keyboard: false);
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.space) {
      if (_active == null) return KeyEventResult.ignored;
      widget.onCategorySelect?.call(_active!);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _onFocus(bool has) {
    final keys = has && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final n = widget.categories.length;
    setState(() => _ring = keys);
    if (!has) {
      _show(null, keyboard: false);
    } else if (keys && n > 0 && _active == null) {
      // Focus from the keyboard starts at the chosen category, or the latest one.
      final sel = widget.selectedIndex;
      _show(sel != null && sel >= 0 && sel < n ? sel : n - 1, keyboard: true);
    }
  }

  double _textWidth(String s, TextStyle style, TextScaler scaler) {
    final p = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)..layout();
    final w = p.width;
    p.dispose();
    return w.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final text = context.uiText;
    final scaler = MediaQuery.textScalerOf(context);
    final drawn = _drawn;
    final cats = widget.categories;
    final n = cats.length;
    final scale = uiChartScale([for (final s in drawn) for (var i = 0; i < n; i++) _value(s, i)]);
    final empty = scale.ticks.length == 1;
    final sel = widget.selectedIndex;

    final axis = text.body.copyWith(fontSize: 12 * t.fontScale, height: 1, color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()]);
    final small = text.body.copyWith(fontSize: 13 * t.fontScale, height: 1.35, color: t.textSecondary);
    final axisH = scaler.scale(12 * t.fontScale);
    final headroom = widget.showValues ? t.space6 : 0.0;
    final footroom = widget.showValues && scale.min < 0 ? t.space6 : 0.0;
    final plotH = widget.height;
    double y(double v) => plotH * (1 - (v - scale.min) / (scale.max - scale.min));
    final zeroY = y(0);

    final tickText = [for (final v in scale.ticks) _fmt(v)];
    final yAxisW = tickText.map((s) => _textWidth(s, axis, scaler)).fold(0.0, math.max);
    // Rule (2) + gap (4) + the label's line, under 8 of air: the web's .xaxis.
    final xAxisH = t.space2 + 2 + t.space1 + scaler.scale(18 * t.fontScale);

    Widget legend() => Padding(
          padding: EdgeInsets.only(bottom: t.space3),
          child: Wrap(spacing: t.space4, runSpacing: t.space1, children: [
            for (var i = 0; i < drawn.length; i++)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  key: ValueKey('ui-bar-chart-swatch-$i'),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: _color(i), borderRadius: BorderRadius.circular(2)),
                ),
                SizedBox(width: t.space2),
                Flexible(child: Text(drawn[i].name, key: ValueKey('ui-bar-chart-legend-$i'), style: small)),
              ]),
          ]),
        );

    Widget frame(BoxConstraints box) {
      final avail = box.maxWidth.isFinite ? box.maxWidth : 480.0;
      final viewW = math.max(0.0, avail - yAxisW - t.space2);
      final minW = widget.minCategoryWidth ?? 0;
      final innerW = math.max(viewW, minW > 0 ? minW * n : 0.0);
      final band = n == 0 ? 0.0 : innerW / n;
      _band = band;
      _innerW = innerW;
      _viewW = viewW;
      final rtl = _rtl;

      // Thin bars: 24 at most, 2 apart, 2 of air at each side of the band.
      final count = math.max(1, drawn.length);
      final barW = math.max(1.0, math.min(24.0, (band - 4 - 2 * (count - 1)) / count));
      final groupW = barW * count + 2 * (count - 1);

      final labelWidths = [for (final c in cats) _textWidth(c, axis.copyWith(fontWeight: FontWeight.w600), scaler)];
      final labels = uiChartLabels(labelWidths, band);

      final plotChildren = <Widget>[
        for (final v in scale.ticks)
          Positioned(
            key: ValueKey('ui-bar-chart-grid-${v == 0 ? 'zero' : v}'),
            left: 0,
            right: 0,
            top: headroom + y(v) - 1,
            height: 1,
            child: ColoredBox(color: v == 0 ? t.borderStrong : t.borderSubtle),
          ),
        for (var i = 0; i < n; i++)
          if (i == _active || i == sel)
            Positioned(
              key: ValueKey('ui-bar-chart-band-$i'),
              left: _bandLeft(i),
              width: band,
              top: headroom,
              height: plotH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.alphaBlend(i == _active ? t.text.withValues(alpha: 0.07) : const Color(0x00000000), i == sel ? t.selected : const Color(0x00000000)),
                  borderRadius: BorderRadius.circular(t.radiusXs),
                ),
              ),
            ),
      ];
      for (var i = 0; i < n; i++) {
        final groupLeft = _bandLeft(i) + (band - groupW) / 2;
        for (var k = 0; k < drawn.length; k++) {
          final v = _value(drawn[k], i);
          final slot = rtl ? drawn.length - 1 - k : k;
          final left = groupLeft + slot * (barW + 2);
          final h = (v.abs() / (scale.max - scale.min)) * plotH;
          final top = v < 0 ? zeroY : zeroY - h;
          if (v != 0) {
            plotChildren.add(AnimatedPositioned(
              key: ValueKey('ui-bar-chart-bar-$i-$k'),
              duration: context.uiAnimate ? t.motionBase : Duration.zero,
              curve: t.easeStandard,
              left: left,
              width: barW,
              top: headroom + top,
              height: math.max(1.0, h),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _color(k),
                  // Rounded at the data end, square on the zero line.
                  borderRadius: v < 0 ? const BorderRadius.vertical(bottom: Radius.circular(4)) : const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
            ));
          }
          if (widget.showValues) {
            final label = _fmt(v);
            final w = _textWidth(label, axis.copyWith(fontWeight: FontWeight.w600), scaler) + 2;
            plotChildren.add(Positioned(
              left: left + barW / 2 - w / 2,
              width: w,
              top: headroom + (v < 0 ? zeroY + h + t.space1 : zeroY - h - t.space1 - axisH),
              child: Text(label, key: ValueKey('ui-bar-chart-value-$i-$k'), maxLines: 1, softWrap: false, overflow: TextOverflow.visible, textAlign: TextAlign.center, style: axis.copyWith(color: t.text, fontWeight: FontWeight.w600)),
            ));
          }
        }
      }
      if (empty) {
        plotChildren.add(Positioned(
          left: 0,
          width: viewW,
          top: headroom,
          height: plotH,
          child: Center(child: Text(widget.emptyLabel ?? context.uiStrings.noData, key: const ValueKey('ui-bar-chart-empty'), textAlign: TextAlign.center, style: small.copyWith(color: t.textMuted))),
        ));
      }

      final xChildren = <Widget>[
        if (sel != null && sel >= 0 && sel < n)
          Positioned(key: const ValueKey('ui-bar-chart-selected-rule'), left: _bandLeft(sel), width: band, top: t.space2, height: 2, child: ColoredBox(color: t.text)),
        for (final l in labels)
          Positioned(
            top: t.space2 + 2 + t.space1,
            left: () {
              final w = labelWidths[l.index];
              final left = _bandLeft(l.index);
              // start and end are the plot's inline edges: mirrored when the bands are.
              final a = rtl ? (l.align == UiChartLabelAlign.start ? UiChartLabelAlign.end : l.align == UiChartLabelAlign.end ? UiChartLabelAlign.start : l.align) : l.align;
              return switch (a) { UiChartLabelAlign.start => left, UiChartLabelAlign.end => left + band - w, UiChartLabelAlign.center => left + band / 2 - w / 2 };
            }(),
            width: labelWidths[l.index],
            child: Text(
              cats[l.index],
              key: ValueKey('ui-bar-chart-label-${l.index}'),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              style: l.index == sel ? axis.copyWith(color: t.text, fontWeight: FontWeight.w600) : axis,
            ),
          ),
      ];

      final plot = SizedBox(
        width: innerW,
        height: headroom + plotH + footroom + xAxisH,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: headroom + plotH + footroom,
            // The whole band is the target for hover and tap, not only the bars.
            child: MouseRegion(
              onHover: (e) {
                if (e.kind != PointerDeviceKind.mouse) return;
                final i = _indexAt(e.localPosition.dx);
                if (i != _active || _keyboard) _show(i, keyboard: false);
              },
              onExit: (_) {
                if (!_keyboard && _active != null) _show(null, keyboard: false);
              },
              child: GestureDetector(
                key: const ValueKey('ui-bar-chart-plot'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  final i = _indexAt(d.localPosition.dx);
                  if (i == null) return;
                  _show(i, keyboard: false);
                  widget.onCategorySelect?.call(i);
                },
                child: Stack(clipBehavior: Clip.none, children: plotChildren),
              ),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, height: xAxisH, child: Stack(clipBehavior: Clip.none, children: xChildren)),
        ]),
      );

      final yAxis = SizedBox(
        width: yAxisW,
        height: headroom + plotH,
        child: Stack(clipBehavior: Clip.none, children: [
          for (var i = 0; i < scale.ticks.length; i++)
            Positioned(
              left: 0,
              right: 0,
              top: headroom + y(scale.ticks[i]) - axisH / 2,
              child: Text(tickText[i], key: ValueKey('ui-bar-chart-tick-$i'), maxLines: 1, softWrap: false, overflow: TextOverflow.visible, textAlign: TextAlign.end, style: axis),
            ),
        ]),
      );

      Widget? tip;
      final a = _active;
      if (a != null && a < n) {
        // Beside the band, on the side with more room, so it never covers the bars it describes.
        final plotLeft = rtl ? 0.0 : yAxisW + t.space2;
        final hiddenLeft = _hiddenLeft;
        final centre = plotLeft + _bandLeft(a) + band / 2 - hiddenLeft;
        final gap = band / 2 + 8;
        final onRight = centre <= avail / 2;
        final maxW = math.max(0.0, onRight ? avail - centre - gap : centre - gap);
        tip = Positioned(
          top: 0,
          left: onRight ? centre + gap : null,
          right: onRight ? null : avail - centre + gap,
          child: IgnorePointer(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Container(
                key: const ValueKey('ui-bar-chart-tip'),
                padding: EdgeInsets.symmetric(vertical: t.space2, horizontal: t.space3),
                decoration: BoxDecoration(
                  color: t.surfaceRaised,
                  border: Border.all(color: t.border),
                  borderRadius: BorderRadius.circular(t.radiusSm),
                  boxShadow: t.shadow2,
                ),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space1, children: [
                  Text(cats[a], key: const ValueKey('ui-bar-chart-tip-title'), style: small),
                  for (var k = 0; k < drawn.length; k++)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 12, height: 3, decoration: BoxDecoration(color: _color(k), borderRadius: BorderRadius.circular(2))),
                      SizedBox(width: t.space2),
                      // Values lead, names follow.
                      Text(_fmt(_value(drawn[k], a)), key: ValueKey('ui-bar-chart-tip-value-$k'), maxLines: 1, softWrap: false, style: small.copyWith(color: t.text, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
                      if (drawn.length > 1) ...[
                        SizedBox(width: t.space2),
                        Flexible(child: Text(drawn[k].name, key: ValueKey('ui-bar-chart-tip-name-$k'), style: small)),
                      ],
                    ]),
                ]),
              ),
            ),
          ),
        );
      }

      return Stack(clipBehavior: Clip.none, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          yAxis,
          SizedBox(width: t.space2),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('ui-bar-chart-scroller'),
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              reverse: true,
              clipBehavior: innerW > viewW ? Clip.hardEdge : Clip.none,
              physics: innerW > viewW ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
              child: plot,
            ),
          ),
        ]),
        ?tip,
      ]);
    }

    final cur = _active ?? (sel != null && sel >= 0 && sel < n ? sel : (n > 0 ? n - 1 : null));
    final walk = cur != null && n > 1 && !empty;
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      value: cur == null || empty ? (empty ? (widget.emptyLabel ?? context.uiStrings.noData) : null) : _summary(cur),
      selected: widget.onCategorySelect != null && cur != null && cur == sel ? true : null,
      increasedValue: walk ? _summary(math.min(n - 1, cur + 1)) : null,
      decreasedValue: walk ? _summary(math.max(0, cur - 1)) : null,
      onIncrease: walk ? () => _show(math.min(n - 1, cur + 1), keyboard: true) : null,
      onDecrease: walk ? () => _show(math.max(0, cur - 1), keyboard: true) : null,
      onTap: widget.onCategorySelect != null && cur != null ? () => widget.onCategorySelect!(cur) : null,
      child: ExcludeSemantics(
        child: TapRegion(
          onTapOutside: (_) {
            if (_active != null && !_keyboard) _show(null, keyboard: false);
          },
          child: Focus(
            focusNode: _focus,
            onKeyEvent: _onKey,
            onFocusChange: _onFocus,
            child: DecoratedBox(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(t.radiusXs), boxShadow: _ring ? t.focusRing : const []),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (drawn.length > 1) legend(),
                // The top tick's label is centred on its gridline: half of it stands above the plot.
                Padding(padding: EdgeInsets.only(top: t.space2), child: LayoutBuilder(builder: (context, box) => _FrameScope(builder: frame, box: box, scroll: _scroll))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rebuilds the frame when the plot scrolls, so the panel stays beside its band.
class _FrameScope extends StatelessWidget {
  const _FrameScope({required this.builder, required this.box, required this.scroll});
  final Widget Function(BoxConstraints box) builder;
  final BoxConstraints box;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: scroll, builder: (context, _) => builder(box));
}
