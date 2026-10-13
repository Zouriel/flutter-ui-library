import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// The spacing steps the layout widgets accept as a `gap` (the web `--ui-space-N`):
/// 0, 1, 2, 3, 4, 6, 8, 12, 20 → 0, 4, 8, 12, 16, 24, 32, 48, 80 px.
double uiSpace(UiTokens t, int step) => switch (step) {
      0 => 0,
      1 => t.space1,
      2 => t.space2,
      3 => t.space3,
      4 => t.space4,
      6 => t.space6,
      8 => t.space8,
      12 => t.space12,
      20 => t.space20,
      _ => throw ArgumentError.value(step, 'gap', 'Use a spacing step: 0, 1, 2, 3, 4, 6, 8, 12 or 20'),
    };

/// Container widths, the web `ui-container` `size`.
enum UiContainerSize { sm, md, lg, xl, full }

/// `ui-container`: centres its child at a maximum width (sm 640, md 860, lg 1100, xl 1320, full
/// unlimited) with the 16px side padding.
class UiContainer extends StatelessWidget {
  const UiContainer({super.key, required this.child, this.size = UiContainerSize.lg});

  final Widget child;
  final UiContainerSize size;

  static double maxWidthOf(UiContainerSize s) => switch (s) {
        UiContainerSize.sm => 640,
        UiContainerSize.md => 860,
        UiContainerSize.lg => 1100,
        UiContainerSize.xl => 1320,
        UiContainerSize.full => double.infinity,
      };

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      widthFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidthOf(size)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.ui.space4),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

/// Cross-axis alignment for [UiStack] (the web `align`).
enum UiStackAlign { start, center, end, stretch }

/// Main-axis distribution for [UiStack] (the web `justify`).
enum UiStackJustify { start, center, end, spaceBetween }

/// `ui-stack`: a row or column with a token gap and alignment. With [wrap] a row flows onto more
/// lines (a [Wrap]).
class UiStack extends StatelessWidget {
  const UiStack({
    super.key,
    required this.children,
    this.direction = Axis.vertical,
    this.gap = 3,
    this.align = UiStackAlign.stretch,
    this.justify = UiStackJustify.start,
    this.wrap = false,
  });

  final List<Widget> children;
  final Axis direction;

  /// Spacing step, see [uiSpace].
  final int gap;
  final UiStackAlign align;
  final UiStackJustify justify;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final g = uiSpace(context.ui, gap);
    if (wrap) {
      return Wrap(
        direction: direction,
        spacing: g,
        runSpacing: g,
        alignment: switch (justify) {
          UiStackJustify.start => WrapAlignment.start,
          UiStackJustify.center => WrapAlignment.center,
          UiStackJustify.end => WrapAlignment.end,
          UiStackJustify.spaceBetween => WrapAlignment.spaceBetween,
        },
        crossAxisAlignment: switch (align) {
          UiStackAlign.center => WrapCrossAlignment.center,
          UiStackAlign.end => WrapCrossAlignment.end,
          _ => WrapCrossAlignment.start,
        },
        children: children,
      );
    }
    final flex = Flex(
      direction: direction,
      spacing: justify == UiStackJustify.spaceBetween ? 0 : g,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: switch (justify) {
        UiStackJustify.start => MainAxisAlignment.start,
        UiStackJustify.center => MainAxisAlignment.center,
        UiStackJustify.end => MainAxisAlignment.end,
        UiStackJustify.spaceBetween => MainAxisAlignment.spaceBetween,
      },
      crossAxisAlignment: switch (align) {
        UiStackAlign.start => CrossAxisAlignment.start,
        UiStackAlign.center => CrossAxisAlignment.center,
        UiStackAlign.end => CrossAxisAlignment.end,
        UiStackAlign.stretch => CrossAxisAlignment.stretch,
      },
      children: children,
    );
    // A stretched row is as tall as its tallest child, like CSS flex, even with no height given.
    return direction == Axis.horizontal && align == UiStackAlign.stretch ? IntrinsicHeight(child: flex) : flex;
  }
}

/// `ui-spacer`: takes the free space in a row or column, pushing its siblings apart.
class UiSpacer extends StatelessWidget {
  const UiSpacer({super.key, this.flex = 1});

  final int flex;

  @override
  Widget build(BuildContext context) => Spacer(flex: flex);
}

/// `ui-grid`: equal columns with a token gap. Give [columns] for a fixed count, or [minColumnWidth]
/// for a responsive grid that fits as many columns of at least that width as there is room for
/// (CSS `repeat(auto-fit, minmax(min, 1fr))`: with fewer children than columns, they widen to fill).
///
/// Cells in a row share the row's height, like CSS grid's default stretch.
class UiGrid extends StatelessWidget {
  const UiGrid({
    super.key,
    required this.children,
    this.columns = 12,
    this.minColumnWidth,
    this.gap = 4,
    this.collapseEmptyColumns = true,
  });

  final List<Widget> children;
  final int columns;

  /// Responsive: the narrowest a column may be. Overrides [columns].
  final double? minColumnWidth;

  /// Spacing step for both row and column gaps, see [uiSpace].
  final int gap;

  /// With [minColumnWidth]: whether unused columns collapse so a short last page of items fills the
  /// row (auto-fit, the default) or keep their width (auto-fill, as thumbnail grids want).
  final bool collapseEmptyColumns;

  /// How many columns fit [width] for the given minimum and gap.
  static int fitColumns(double width, double min, double gap) => math.max(1, ((width + gap) / (min + gap)).floor());

  @override
  Widget build(BuildContext context) {
    return _GridLayout(
      columns: columns,
      minColumnWidth: minColumnWidth,
      gap: uiSpace(context.ui, gap),
      collapse: collapseEmptyColumns,
      children: children,
    );
  }
}

class _GridLayout extends MultiChildRenderObjectWidget {
  const _GridLayout({required this.columns, required this.minColumnWidth, required this.gap, required this.collapse, required super.children});

  final int columns;
  final double? minColumnWidth;
  final double gap;
  final bool collapse;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderGrid(columns, minColumnWidth, gap, collapse);

  @override
  void updateRenderObject(BuildContext context, _RenderGrid r) {
    r
      ..columns = columns
      ..minColumnWidth = minColumnWidth
      ..gap = gap
      ..collapse = collapse;
  }
}

class _GridParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderGrid extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _GridParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _GridParentData> {
  _RenderGrid(this._columns, this._min, this._gap, this._collapse);

  int _columns;
  set columns(int v) {
    if (v != _columns) {
      _columns = v;
      markNeedsLayout();
    }
  }

  double? _min;
  set minColumnWidth(double? v) {
    if (v != _min) {
      _min = v;
      markNeedsLayout();
    }
  }

  double _gap;
  set gap(double v) {
    if (v != _gap) {
      _gap = v;
      markNeedsLayout();
    }
  }

  bool _collapse;
  set collapse(bool v) {
    if (v != _collapse) {
      _collapse = v;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _GridParentData) child.parentData = _GridParentData();
  }

  int _cols(double width) {
    var c = _min != null ? UiGrid.fitColumns(width, _min!, _gap) : math.max(1, _columns);
    if (_min != null && _collapse && childCount > 0) c = math.min(c, childCount);
    return c;
  }

  Size _layout(BoxConstraints constraints, {required bool dry}) {
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : (_min ?? 100) * math.max(1, _columns);
    final cols = _cols(width);
    final cellW = math.max(0.0, (width - _gap * (cols - 1)) / cols);
    var y = 0.0;
    var child = firstChild;
    var row = <RenderBox>[];
    void flush() {
      if (row.isEmpty) return;
      var h = 0.0;
      for (final c in row) {
        final s = dry ? c.getDryLayout(BoxConstraints.tightFor(width: cellW)) : (c..layout(BoxConstraints.tightFor(width: cellW), parentUsesSize: true)).size;
        h = math.max(h, s.height);
      }
      for (var i = 0; i < row.length; i++) {
        final c = row[i];
        if (!dry) {
          // Stretch every cell to the row's height, as CSS grid does.
          if (c.size.height != h) c.layout(BoxConstraints.tightFor(width: cellW, height: h), parentUsesSize: true);
          (c.parentData! as _GridParentData).offset = Offset(i * (cellW + _gap), y);
        }
      }
      y += h + _gap;
      row = [];
    }

    while (child != null) {
      row.add(child);
      if (row.length == cols) flush();
      child = childAfter(child);
    }
    flush();
    final height = childCount == 0 ? 0.0 : y - _gap;
    return constraints.constrain(Size(width, height));
  }

  @override
  void performLayout() => size = _layout(constraints, dry: false);

  @override
  Size computeDryLayout(BoxConstraints constraints) => _layout(constraints, dry: true);

  @override
  double computeMinIntrinsicHeight(double width) => _layout(BoxConstraints(maxWidth: width), dry: true).height;
  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}

/// `ui-aspect-ratio`: holds its child at a width:height [ratio] (e.g. `16 / 9`). The child is
/// stretched to fill the box and anything outside it is clipped, so give images `BoxFit.cover`.
class UiAspectRatio extends StatelessWidget {
  const UiAspectRatio({super.key, required this.child, this.ratio = 16 / 9, this.borderRadius});

  final Widget child;
  final double ratio;

  /// Clip to rounded corners (the web inherits the host's radius).
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: ratio,
      child: ClipRRect(borderRadius: borderRadius ?? BorderRadius.zero, child: SizedBox.expand(child: child)),
    );
  }
}

/// Which way a [UiScrollArea] scrolls; the other axis is clipped.
enum UiScrollAxis { y, x, both }

/// `ui-scroll-area`: a scroll box with a thin themed scrollbar and a [maxHeight]. It scrolls on
/// [axis] and clips the other.
class UiScrollArea extends StatefulWidget {
  const UiScrollArea({super.key, required this.child, this.maxHeight = 240, this.axis = UiScrollAxis.y, this.controller});

  final Widget child;
  final double maxHeight;
  final UiScrollAxis axis;

  /// The vertical controller (or the horizontal one for [UiScrollAxis.x]).
  final ScrollController? controller;

  @override
  State<UiScrollArea> createState() => _UiScrollAreaState();
}

class _UiScrollAreaState extends State<UiScrollArea> {
  ScrollController? _own;
  final ScrollController _cross = ScrollController();

  ScrollController get _main => widget.controller ?? (_own ??= ScrollController());

  @override
  void dispose() {
    _own?.dispose();
    _cross.dispose();
    super.dispose();
  }

  Widget _bar(ScrollController c, Widget child, {required bool vertical}) {
    final t = context.ui;
    return RawScrollbar(
      controller: c,
      thumbVisibility: true,
      thickness: 5,
      radius: Radius.circular(t.radiusPill),
      thumbColor: t.border,
      crossAxisMargin: 2,
      notificationPredicate: (n) => n.metrics.axis == (vertical ? Axis.vertical : Axis.horizontal),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (widget.axis) {
      case UiScrollAxis.y:
        content = _bar(_main, SingleChildScrollView(controller: _main, child: widget.child), vertical: true);
      case UiScrollAxis.x:
        content = _bar(_main, SingleChildScrollView(controller: _main, scrollDirection: Axis.horizontal, child: widget.child), vertical: false);
      case UiScrollAxis.both:
        content = _bar(
          _main,
          _bar(
            _cross,
            SingleChildScrollView(
              controller: _main,
              child: SingleChildScrollView(controller: _cross, scrollDirection: Axis.horizontal, child: widget.child),
            ),
            vertical: false,
          ),
          vertical: true,
        );
    }
    return ConstrainedBox(constraints: BoxConstraints(maxHeight: widget.maxHeight), child: ClipRect(child: content));
  }
}
