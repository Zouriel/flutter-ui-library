import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'button.dart';

/// `ui-button-group`: joins a row of [UiButton]s (or [UiIconButton]s) into one shape. Inner corners
/// go square and neighbouring borders overlap into one line. The group is named by [label] for
/// screen readers. It doesn't manage selection; use [UiSegmented] for one-of-many.
class UiButtonGroup extends StatelessWidget {
  const UiButtonGroup({super.key, required this.children, this.label});

  final List<Widget> children;

  /// The group's accessible name.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      explicitChildNodes: true,
      child: UiJoinedRow(children: children),
    );
  }
}

/// Lays buttons out edge to edge with a 1px overlap (so two borders read as one), squares their
/// inner corners via [UiButtonJoin], and paints the hovered or focused one on top so its border and
/// focus ring aren't covered by a neighbour. Used by [UiButtonGroup] and the split button.
class UiJoinedRow extends StatefulWidget {
  const UiJoinedRow({super.key, required this.children});
  final List<Widget> children;

  @override
  State<UiJoinedRow> createState() => _UiJoinedRowState();
}

class _UiJoinedRowState extends State<UiJoinedRow> {
  int? _focused, _hovered;

  @override
  Widget build(BuildContext context) {
    final n = widget.children.length;
    return _OverlapRow(
      raised: _focused ?? _hovered,
      children: [
        for (var i = 0; i < n; i++)
          MouseRegion(
            onEnter: (_) => setState(() => _hovered = i),
            onExit: (_) => setState(() => _hovered = _hovered == i ? null : _hovered),
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              includeSemantics: false,
              onFocusChange: (f) => setState(() => _focused = f ? i : (_focused == i ? null : _focused)),
              child: UiButtonJoin(first: i == 0, last: i == n - 1, child: widget.children[i]),
            ),
          ),
      ],
    );
  }
}

class _OverlapRow extends MultiChildRenderObjectWidget {
  const _OverlapRow({required super.children, this.raised});
  final int? raised;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderOverlapRow(raised, Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, _RenderOverlapRow r) {
    r
      ..raised = raised
      ..textDirection = Directionality.of(context);
  }
}

class _OverlapParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderOverlapRow extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _OverlapParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _OverlapParentData> {
  _RenderOverlapRow(this._raised, this._dir);

  static const double overlap = 1;

  int? _raised;
  set raised(int? v) {
    if (v == _raised) return;
    _raised = v;
    markNeedsPaint();
  }

  TextDirection _dir;
  set textDirection(TextDirection v) {
    if (v == _dir) return;
    _dir = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _OverlapParentData) child.parentData = _OverlapParentData();
  }

  List<RenderBox> get _children {
    final out = <RenderBox>[];
    var c = firstChild;
    while (c != null) {
      out.add(c);
      c = childAfter(c);
    }
    return out;
  }

  @override
  void performLayout() {
    final kids = _children;
    final inner = BoxConstraints(maxHeight: constraints.maxHeight);
    var h = 0.0;
    for (final c in kids) {
      c.layout(inner, parentUsesSize: true);
      if (c.size.height > h) h = c.size.height;
    }
    var w = 0.0;
    for (var i = 0; i < kids.length; i++) {
      if (i > 0) w -= overlap;
      final pd = kids[i].parentData! as _OverlapParentData;
      pd.offset = Offset(w, (h - kids[i].size.height) / 2);
      w += kids[i].size.width;
    }
    if (_dir == TextDirection.rtl) {
      for (final c in kids) {
        final pd = c.parentData! as _OverlapParentData;
        pd.offset = Offset(w - pd.offset.dx - c.size.width, pd.offset.dy);
      }
    }
    size = constraints.constrain(Size(w < 0 ? 0 : w, h));
  }

  @override
  double computeMinIntrinsicHeight(double width) => _children.fold(0.0, (m, c) => m > c.getMinIntrinsicHeight(double.infinity) ? m : c.getMinIntrinsicHeight(double.infinity));
  @override
  double computeMaxIntrinsicHeight(double width) => _children.fold(0.0, (m, c) => m > c.getMaxIntrinsicHeight(double.infinity) ? m : c.getMaxIntrinsicHeight(double.infinity));
  @override
  double computeMinIntrinsicWidth(double height) {
    final k = _children;
    return k.fold(0.0, (s, c) => s + c.getMinIntrinsicWidth(height)) - overlap * (k.isEmpty ? 0 : k.length - 1);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final k = _children;
    return k.fold(0.0, (s, c) => s + c.getMaxIntrinsicWidth(height)) - overlap * (k.isEmpty ? 0 : k.length - 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final kids = _children;
    final raised = _raised != null && _raised! < kids.length ? kids[_raised!] : null;
    for (final c in kids) {
      if (c != raised) context.paintChild(c, (c.parentData! as _OverlapParentData).offset + offset);
    }
    if (raised != null) context.paintChild(raised, (raised.parentData! as _OverlapParentData).offset + offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
