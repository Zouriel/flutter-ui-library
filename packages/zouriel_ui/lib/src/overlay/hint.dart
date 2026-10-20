import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../fx/motion.dart';
import '../theme/theme.dart';
import 'tooltip.dart';

/// Which side of its anchor a hint opens on (the web `UiHintPlacement`). [start] and [end] follow
/// the text direction.
enum UiHintPlacement { top, bottom, start, end }

/// Why a hint closed (the web `UiHintCloseReason`): its time ran out, a tap on it (or its ×, or
/// its anchor), or Escape.
enum UiHintCloseReason { timeout, tap, escape }

/// Anchor to bubble: the arrow (7px) plus a 3px breath, as on the web.
const double _kGap = 10;
const double _kArrow = 7;

/// `uiHint`: a coachmark, a small callout pointed at [child], opened from code.
///
/// Set [open] to show it; it reports closing through [onOpenChanged] (false) and [onClosed] with
/// the reason (the web `[(uiHintOpen)]` and `(uiHintClosed)`). Not a dialog: it is a polite live
/// region, never takes focus and never blocks typing or touches outside itself. It closes on a tap
/// on it or on its anchor, Escape, or after [duration] ([Duration.zero] keeps it until dismissed).
/// It prefers [placement]; above or below, it slides along that side to stay on screen and flips
/// to the opposite side only when there is no room (never beside the anchor unless placed there).
/// It follows the anchor when it moves, and its arrow points at it. Primary colours from the theme; it only fades under
/// reduced motion, and appears at once with the library's animations off.
class UiHint extends StatefulWidget {
  const UiHint({
    super.key,
    required this.message,
    required this.child,
    this.open = false,
    this.onOpenChanged,
    this.placement = UiHintPlacement.top,
    this.duration = const Duration(milliseconds: 6000),
    this.dismissible = false,
    this.onClosed,
  });

  final String message;

  /// The anchor.
  final Widget child;

  /// Whether it is showing. It hides itself when it closes and calls [onOpenChanged] with false.
  final bool open;
  final ValueChanged<bool>? onOpenChanged;
  final UiHintPlacement placement;

  /// How long it stays; [Duration.zero] keeps it until it is tapped or Escape is pressed.
  final Duration duration;

  /// Show a small × ("Dismiss"); it closes with [UiHintCloseReason.tap].
  final bool dismissible;

  /// It closed by itself or by the person, with the reason. Not called when [open] turns false.
  final ValueChanged<UiHintCloseReason>? onClosed;

  @override
  State<UiHint> createState() => _UiHintState();
}

class _UiHintState extends State<UiHint> {
  final OverlayPortalController _portal = OverlayPortalController();
  Timer? _timer, _announce;

  /// The text is put in a beat after the bubble appears: a live region announces a change.
  bool _announced = false;

  @override
  void initState() {
    super.initState();
    if (widget.open) WidgetsBinding.instance.addPostFrameCallback((_) => mounted && widget.open ? _show() : null);
  }

  @override
  void didUpdateWidget(UiHint old) {
    super.didUpdateWidget(old);
    if (widget.open != old.open) {
      // show()/hide() may not run during a build; the next frame is soon enough.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.open ? _show() : _hide();
      });
    } else if (_portal.isShowing && (widget.duration != old.duration || widget.message != old.message)) {
      _arm();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _announce?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  void _show() {
    if (_portal.isShowing || widget.message.isEmpty) return;
    _announced = false;
    setState(_portal.show);
    _announce = Timer(const Duration(milliseconds: 30), () {
      if (mounted) setState(() => _announced = true);
    });
    _arm();
    // Escape anywhere closes it; the key still reaches whatever has focus (typing is never blocked).
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  void _arm() {
    _timer?.cancel();
    _timer = widget.duration > Duration.zero ? Timer(widget.duration, () => _close(UiHintCloseReason.timeout)) : null;
  }

  void _hide() {
    _timer?.cancel();
    _announce?.cancel();
    _timer = _announce = null;
    HardwareKeyboard.instance.removeHandler(_onKey);
    if (_portal.isShowing) setState(_portal.hide);
  }

  void _close(UiHintCloseReason reason) {
    if (!mounted || !_portal.isShowing) return;
    _hide();
    widget.onOpenChanged?.call(false);
    widget.onClosed?.call(reason);
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) _close(UiHintCloseReason.escape);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      // A tap on the anchor closes it; the anchor still gets the tap (a Listener is not in the arena).
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: (_) => _close(UiHintCloseReason.tap),
        child: widget.child,
      ),
      overlayChildBuilder: (context, info) {
        final anchor = MatrixUtils.transformRect(info.childPaintTransform, Offset.zero & info.childSize);
        final mq = MediaQuery.of(context);
        final safe = EdgeInsets.fromLTRB(
          mq.padding.left + 8,
          mq.padding.top + 8,
          mq.padding.right + 8,
          math.max(mq.padding.bottom, mq.viewInsets.bottom) + 8,
        );
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final side = switch (widget.placement) {
          UiHintPlacement.top => UiTooltipPosition.top,
          UiHintPlacement.bottom => UiTooltipPosition.bottom,
          UiHintPlacement.start => rtl ? UiTooltipPosition.right : UiTooltipPosition.left,
          UiHintPlacement.end => rtl ? UiTooltipPosition.left : UiTooltipPosition.right,
        };
        final geometry = _HintGeometry();
        // Only the bubble takes touches: the rest of the overlay lets them through to the page.
        return Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _HintLayout(anchor: anchor, position: side, safe: safe, geometry: geometry),
            child: UiHintBubble(
              message: _announced ? widget.message : '',
              geometry: geometry,
              dismissible: widget.dismissible,
              onTap: () => _close(UiHintCloseReason.tap),
            ),
          ),
        );
      },
    );
  }
}

/// Where the arrow goes: the side the bubble ended up on and the anchor centre's offset along it.
/// Written during layout, read when painting (which comes after).
class _HintGeometry extends ChangeNotifier {
  UiTooltipPosition side = UiTooltipPosition.top;
  double offset = 0;

  void set(UiTooltipPosition s, double o) {
    if (s == side && o == offset) return;
    side = s;
    offset = o;
    notifyListeners();
  }
}

class _HintLayout extends UiTooltipLayout {
  _HintLayout({required super.anchor, required super.position, required super.safe, required this.geometry}) : super(gap: _kGap);

  final _HintGeometry geometry;

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

  /// Above or below: that side, else the opposite one, else the roomier of the two; it slides along
  /// the side to stay on screen and never moves beside the anchor, where it would cover what sits
  /// next to it. Beside (start/end): that side, the opposite one, then above or below.
  @override
  UiTooltipPosition resolve(Size size, Size childSize) {
    final area = safe.deflateRect(Offset.zero & size);
    final vertical = position == UiTooltipPosition.top || position == UiTooltipPosition.bottom;
    final order = [
      position,
      _opposite[position]!,
      if (!vertical) ...const [UiTooltipPosition.top, UiTooltipPosition.bottom],
    ];
    bool fits(UiTooltipPosition p) {
      final v = p == UiTooltipPosition.top || p == UiTooltipPosition.bottom;
      return _room(area, p) >= (v ? childSize.height : childSize.width);
    }

    for (final p in order) {
      if (fits(p)) return p;
    }
    return order.reduce((a, b) => _room(area, b) > _room(area, a) ? b : a);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final at = super.getPositionForChild(size, childSize);
    final p = resolve(size, childSize);
    final vertical = p == UiTooltipPosition.top || p == UiTooltipPosition.bottom;
    final along = vertical ? anchor.center.dx - at.dx : anchor.center.dy - at.dy;
    final extent = vertical ? childSize.width : childSize.height;
    // Keep clear of the rounded corners.
    geometry.set(p, along.clamp(16.0, math.max(16.0, extent - 16)));
    return at;
  }

  @override
  bool shouldRelayout(UiTooltipLayout old) => true;
}

/// The hint's callout (the web `ui-hint-panel`): primary fill, small text, at most 280px wide, an
/// arrow on the side facing the anchor, and an optional ×. A polite live region.
class UiHintBubble extends StatelessWidget {
  const UiHintBubble({super.key, required this.message, this.dismissible = false, this.onTap, this.geometry});

  final String message;
  final bool dismissible;
  final VoidCallback? onTap;
  final Listenable? geometry;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final fg = t.primaryContrast;
    final r = theme.radius(t.radius);
    final text = theme.typography.body.copyWith(fontSize: t.fontSizeSm, height: 1.4, color: fg);
    Widget bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: CustomPaint(
        foregroundPainter: geometry is _HintGeometry ? _ArrowPainter(geometry! as _HintGeometry, t.primary) : null,
        child: DecoratedBox(
          decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(r), boxShadow: t.shadow2),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
            child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Flexible(child: ExcludeSemantics(child: Text(message, style: text))),
              if (dismissible) ...[
                SizedBox(width: t.space2),
                UiInteractive(
                  onTap: onTap,
                  semanticLabel: 'Dismiss',
                  excludeChildSemantics: true,
                  // The whole bubble is a tap target that dismisses, so the × stays small.
                  padTouchTarget: false,
                  builder: (context, s) => Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: s.hovered || s.pressed ? fg.withValues(alpha: 0.14) : null,
                      borderRadius: BorderRadius.circular(theme.radius(t.radiusXs)),
                    ),
                    child: Center(child: UiIcon(HugeIcons.strokeRoundedCancel01, size: 14, color: fg)),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
    final motion = uiFxMotion(context);
    if (motion != UiFxMotion.none) {
      final calm = motion == UiFxMotion.calm;
      bubble = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: t.motionBase,
        curve: t.easeDecelerate,
        builder: (context, v, child) => Opacity(
          opacity: v,
          child: calm ? child : Transform.scale(scale: 0.96 + 0.04 * v, child: child),
        ),
        child: bubble,
      );
    }
    return Semantics(
      container: true,
      liveRegion: true,
      label: message.isEmpty ? null : message,
      child: GestureDetector(behavior: HitTestBehavior.opaque, excludeFromSemantics: true, onTap: onTap, child: bubble),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.geometry, this.color) : super(repaint: geometry);

  final _HintGeometry geometry;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final o = geometry.offset;
    final path = Path();
    switch (geometry.side) {
      // The bubble is above the anchor: the arrow hangs below it, and so on.
      case UiTooltipPosition.top:
        path..moveTo(o - _kArrow, size.height)..lineTo(o, size.height + _kArrow)..lineTo(o + _kArrow, size.height);
      case UiTooltipPosition.bottom:
        path..moveTo(o - _kArrow, 0)..lineTo(o, -_kArrow)..lineTo(o + _kArrow, 0);
      case UiTooltipPosition.left:
        path..moveTo(size.width, o - _kArrow)..lineTo(size.width + _kArrow, o)..lineTo(size.width, o + _kArrow);
      case UiTooltipPosition.right:
        path..moveTo(0, o - _kArrow)..lineTo(-_kArrow, o)..lineTo(0, o + _kArrow);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color || old.geometry != geometry;
}
