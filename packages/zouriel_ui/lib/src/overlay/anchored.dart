import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Where a panel opens relative to its anchor (the web CDK connected positions).
enum UiPlacement { bottomStart, bottom, bottomEnd, topStart, top, topEnd, start, end }

/// Shows a panel next to an anchor widget, in the nearest [Overlay], with the web overlays' rules:
/// open on the preferred side, flip to the opposite side when there isn't room, then shift to stay
/// [margin] px inside the screen (and above the keyboard). Tapping outside both the anchor and the
/// panel, or pressing Escape inside the panel, calls [onDismiss].
///
/// Drive it with an [OverlayPortalController]: `controller.show()` / `hide()`.
class UiAnchoredOverlay extends StatefulWidget {
  const UiAnchoredOverlay({
    super.key,
    required this.controller,
    required this.child,
    required this.panelBuilder,
    this.placement = UiPlacement.bottomStart,
    this.gap = 4,
    this.margin = 8,
    this.matchAnchorWidth = false,
    this.minWidth = 0,
    this.onDismiss,
    this.dismissOnTapOutside = true,
  });

  final OverlayPortalController controller;

  /// The anchor.
  final Widget child;

  /// Builds the panel. [anchor] is the anchor's rect in overlay coordinates.
  final Widget Function(BuildContext context, Rect anchor) panelBuilder;
  final UiPlacement placement;

  /// Space between anchor and panel.
  final double gap;

  /// Minimum distance from the screen edges.
  final double margin;

  /// Make the panel exactly as wide as the anchor (dropdowns, comboboxes).
  final bool matchAnchorWidth;
  final double minWidth;
  final VoidCallback? onDismiss;
  final bool dismissOnTapOutside;

  @override
  State<UiAnchoredOverlay> createState() => _UiAnchoredOverlayState();
}

class _UiAnchoredOverlayState extends State<UiAnchoredOverlay> {
  final Object _group = Object();

  void _dismiss() => widget.onDismiss?.call();

  @override
  Widget build(BuildContext context) {
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: widget.controller,
      overlayChildBuilder: (context, info) {
        final anchor = MatrixUtils.transformRect(info.childPaintTransform, Offset.zero & info.childSize);
        final mq = MediaQuery.of(context);
        final safe = EdgeInsets.fromLTRB(
          mq.padding.left + widget.margin,
          mq.padding.top + widget.margin,
          mq.padding.right + widget.margin,
          math.max(mq.padding.bottom, mq.viewInsets.bottom) + widget.margin,
        );
        Widget panel = Actions(
          actions: {DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => _dismiss())},
          child: Shortcuts(
            shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
            child: widget.panelBuilder(context, anchor),
          ),
        );
        if (widget.dismissOnTapOutside) {
          panel = TapRegion(groupId: _group, onTapOutside: (_) => _dismiss(), child: panel);
        }
        return Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: UiAnchorLayout(
              anchor: anchor,
              placement: widget.placement,
              gap: widget.gap,
              safe: safe,
              matchWidth: widget.matchAnchorWidth,
              minWidth: widget.minWidth,
              textDirection: Directionality.of(context),
            ),
            child: panel,
          ),
        );
      },
      // Opaque, so a tap anywhere on the anchor (even a transparent gap) counts as inside.
      child: TapRegion(groupId: _group, behavior: HitTestBehavior.opaque, child: widget.child),
    );
  }
}

/// Positions a panel against an anchor rect: preferred side, flip, then clamp inside [safe].
/// Exposed so other overlays (tooltips, menus at a point) can reuse the same rules.
class UiAnchorLayout extends SingleChildLayoutDelegate {
  UiAnchorLayout({
    required this.anchor,
    required this.placement,
    required this.gap,
    required this.safe,
    this.matchWidth = false,
    this.minWidth = 0,
    this.textDirection = TextDirection.ltr,
  });

  final Rect anchor;
  final UiPlacement placement;
  final double gap;
  final EdgeInsets safe;
  final bool matchWidth;
  final double minWidth;
  final TextDirection textDirection;

  bool get _vertical => placement != UiPlacement.start && placement != UiPlacement.end;
  bool get _prefersTop => placement == UiPlacement.top || placement == UiPlacement.topStart || placement == UiPlacement.topEnd;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final area = safe.deflateRect(Offset.zero & constraints.biggest);
    if (!_vertical) {
      return BoxConstraints(maxWidth: math.max(0, area.width), maxHeight: math.max(0, area.height));
    }
    final below = area.bottom - anchor.bottom - gap;
    final above = anchor.top - area.top - gap;
    final maxH = math.max(0.0, math.max(below, above));
    if (matchWidth) {
      final w = math.min(math.max(anchor.width, minWidth), area.width);
      return BoxConstraints(minWidth: w, maxWidth: w, maxHeight: maxH);
    }
    return BoxConstraints(minWidth: math.min(minWidth, area.width), maxWidth: math.max(0, area.width), maxHeight: maxH);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final area = safe.deflateRect(Offset.zero & size);
    double x, y;
    if (_vertical) {
      final below = area.bottom - anchor.bottom - gap;
      final above = anchor.top - area.top - gap;
      // Flip when the preferred side is too small and the other side is bigger.
      var top = _prefersTop;
      if (top && childSize.height > above && below > above) top = false;
      if (!top && childSize.height > below && above > below) top = true;
      y = top ? anchor.top - gap - childSize.height : anchor.bottom + gap;
      final rtl = textDirection == TextDirection.rtl;
      final start = switch (placement) {
        UiPlacement.bottomStart || UiPlacement.topStart => true,
        UiPlacement.bottomEnd || UiPlacement.topEnd => false,
        _ => null,
      };
      if (start == null) {
        x = anchor.center.dx - childSize.width / 2;
      } else {
        // Line up with the anchor's start edge; if that runs off screen, try its end edge (the CDK
        // fallback positions) before shifting.
        final alignLeft = start != rtl;
        final left = anchor.left, right = anchor.right - childSize.width;
        x = alignLeft ? left : right;
        final fits = x >= area.left && x + childSize.width <= area.right;
        final other = alignLeft ? right : left;
        if (!fits && other >= area.left && other + childSize.width <= area.right) x = other;
      }
    } else {
      final rtl = textDirection == TextDirection.rtl;
      final afterSpace = area.right - anchor.right - gap;
      final beforeSpace = anchor.left - area.left - gap;
      var right = (placement == UiPlacement.end) != rtl;
      if (right && childSize.width > afterSpace && beforeSpace > afterSpace) right = false;
      if (!right && childSize.width > beforeSpace && afterSpace > beforeSpace) right = true;
      x = right ? anchor.right + gap : anchor.left - gap - childSize.width;
      y = anchor.center.dy - childSize.height / 2;
    }
    // Shift to stay inside the safe area.
    x = x.clamp(area.left, math.max(area.left, area.right - childSize.width));
    y = y.clamp(area.top, math.max(area.top, area.bottom - childSize.height));
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(UiAnchorLayout old) =>
      old.anchor != anchor || old.placement != placement || old.gap != gap || old.safe != safe || old.matchWidth != matchWidth || old.minWidth != minWidth;
}
