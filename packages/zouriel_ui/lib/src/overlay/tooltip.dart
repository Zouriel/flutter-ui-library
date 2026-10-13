import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Which side of its anchor a tooltip prefers, the web `UiTooltipPosition`.
enum UiTooltipPosition { top, bottom, left, right }

/// `uiTooltip`: a short description shown next to [child].
///
/// On devices with a pointer it shows on hover and on keyboard focus, and hides on exit, blur and
/// Escape (the web behaviour). On touch screens it shows on long-press and hides [touchDuration]
/// after the finger lifts. It opens on [position]; when there is no room there it flips to the
/// opposite side, then tries the other two, and it never covers its anchor (it only shifts along
/// the side it sits on to stay 8px inside the screen).
///
/// Screen readers get the text as the anchor's tooltip (the web `aria-describedby`), so the panel
/// itself is hidden from them. The anchor's semantics are merged into one node for that, so wrap a
/// single control, not a group of them. An empty [message] shows nothing.
class UiTooltip extends StatefulWidget {
  const UiTooltip({
    super.key,
    required this.message,
    required this.child,
    this.position = UiTooltipPosition.top,
    this.touchDuration = const Duration(milliseconds: 1500),
  });

  final String message;
  final Widget child;
  final UiTooltipPosition position;

  /// How long it stays after a long-press ends.
  final Duration touchDuration;

  @override
  State<UiTooltip> createState() => _UiTooltipState();
}

class _UiTooltipState extends State<UiTooltip> {
  final OverlayPortalController _portal = OverlayPortalController();
  Timer? _hideTimer;
  bool _hovered = false, _focused = false, _pressed = false;

  bool get _visible => _portal.isShowing;

  void _sync() {
    final want = widget.message.isNotEmpty && (_hovered || _focused || _pressed);
    if (want) {
      _hideTimer?.cancel();
      _hideTimer = null;
      if (!_visible) setState(_portal.show);
    } else if (_visible) {
      setState(_portal.hide);
    }
  }

  void _hideNow() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _hovered = _focused = _pressed = false;
    if (_visible) setState(_portal.hide);
  }

  @override
  void didUpdateWidget(UiTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.isEmpty && _visible) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _hideNow() : null);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Merged so the text lands on the anchor's own node (its control), not on a parent.
    final child = MergeSemantics(
      child: Semantics(
      tooltip: widget.message.isEmpty ? null : widget.message,
      child: CallbackShortcuts(
        bindings: {if (_visible) const SingleActivator(LogicalKeyboardKey.escape): _hideNow},
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          // Keyboard focus only: a tap that happens to focus something should not pop a tooltip.
          onFocusChange: (f) {
            _focused = f && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
            _sync();
          },
          child: MouseRegion(
            onEnter: (e) {
              if (e.kind != PointerDeviceKind.mouse) return;
              _hovered = true;
              _sync();
            },
            onExit: (_) {
              _hovered = false;
              _sync();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              excludeFromSemantics: true,
              onLongPressStart: (_) {
                HapticFeedback.selectionClick();
                _pressed = true;
                _sync();
              },
              onLongPressEnd: (_) {
                _hideTimer?.cancel();
                _hideTimer = Timer(widget.touchDuration, () {
                  _pressed = false;
                  if (mounted) _sync();
                });
              },
              child: widget.child,
            ),
          ),
        ),
      ),
      ),
    );

    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      child: child,
      overlayChildBuilder: (context, info) {
        final anchor = MatrixUtils.transformRect(info.childPaintTransform, Offset.zero & info.childSize);
        final mq = MediaQuery.of(context);
        final safe = EdgeInsets.fromLTRB(
          mq.padding.left + 8,
          mq.padding.top + 8,
          mq.padding.right + 8,
          math.max(mq.padding.bottom, mq.viewInsets.bottom) + 8,
        );
        return Positioned.fill(
          child: IgnorePointer(
            child: CustomSingleChildLayout(
              delegate: UiTooltipLayout(anchor: anchor, position: widget.position, safe: safe),
              child: UiTooltipPanel(message: widget.message),
            ),
          ),
        );
      },
    );
  }
}

/// The tooltip bubble (the web `ui-tooltip-panel`): raised surface, small radius, shadow 1, small
/// text, at most 240px wide. Fades in. Hidden from screen readers (the anchor carries the text).
class UiTooltipPanel extends StatelessWidget {
  const UiTooltipPanel({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    Widget panel = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(theme.radius(t.radiusXs)),
          boxShadow: t.shadow1,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: t.space1),
          child: Text(message, style: theme.typography.body.copyWith(fontSize: t.fontSizeSm, height: 1.35)),
        ),
      ),
    );
    if (context.uiAnimate) {
      panel = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: t.motionFast,
        curve: t.easeStandard,
        builder: (context, v, child) => Opacity(opacity: v, child: child),
        child: panel,
      );
    }
    return ExcludeSemantics(child: panel);
  }
}

/// Places a tooltip beside its anchor without ever covering it: the preferred side, else the
/// opposite one, else whichever of the other two fits (else the roomiest side). It shifts only
/// along that side to stay inside [safe].
class UiTooltipLayout extends SingleChildLayoutDelegate {
  UiTooltipLayout({required this.anchor, required this.position, required this.safe, this.gap = 4});

  final Rect anchor;
  final UiTooltipPosition position;
  final EdgeInsets safe;
  final double gap;

  static const _opposite = {
    UiTooltipPosition.top: UiTooltipPosition.bottom,
    UiTooltipPosition.bottom: UiTooltipPosition.top,
    UiTooltipPosition.left: UiTooltipPosition.right,
    UiTooltipPosition.right: UiTooltipPosition.left,
  };

  double _room(Rect area, UiTooltipPosition p) => switch (p) {
        UiTooltipPosition.top => anchor.top - gap - area.top,
        UiTooltipPosition.bottom => area.bottom - anchor.bottom - gap,
        UiTooltipPosition.left => anchor.left - gap - area.left,
        UiTooltipPosition.right => area.right - anchor.right - gap,
      };

  bool _fits(Rect area, UiTooltipPosition p, Size s) {
    final vertical = p == UiTooltipPosition.top || p == UiTooltipPosition.bottom;
    return _room(area, p) >= (vertical ? s.height : s.width);
  }

  /// The side the tooltip ends up on for a child of [childSize] in a screen of [size].
  UiTooltipPosition resolve(Size size, Size childSize) {
    final area = safe.deflateRect(Offset.zero & size);
    final vertical = position == UiTooltipPosition.top || position == UiTooltipPosition.bottom;
    final order = [
      position,
      _opposite[position]!,
      ...(vertical ? const [UiTooltipPosition.right, UiTooltipPosition.left] : const [UiTooltipPosition.top, UiTooltipPosition.bottom]),
    ];
    for (final p in order) {
      if (_fits(area, p, childSize)) return p;
    }
    return order.reduce((a, b) => _room(area, b) > _room(area, a) ? b : a);
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final area = safe.deflateRect(Offset.zero & constraints.biggest);
    return BoxConstraints(maxWidth: math.max(0, area.width), maxHeight: math.max(0, area.height));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final area = safe.deflateRect(Offset.zero & size);
    final p = resolve(size, childSize);
    double x, y;
    switch (p) {
      case UiTooltipPosition.top:
      case UiTooltipPosition.bottom:
        y = p == UiTooltipPosition.top ? anchor.top - gap - childSize.height : anchor.bottom + gap;
        x = (anchor.center.dx - childSize.width / 2).clamp(area.left, math.max(area.left, area.right - childSize.width));
      case UiTooltipPosition.left:
      case UiTooltipPosition.right:
        x = p == UiTooltipPosition.left ? anchor.left - gap - childSize.width : anchor.right + gap;
        y = (anchor.center.dy - childSize.height / 2).clamp(area.top, math.max(area.top, area.bottom - childSize.height));
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(UiTooltipLayout old) => old.anchor != anchor || old.position != position || old.safe != safe || old.gap != gap;
}
