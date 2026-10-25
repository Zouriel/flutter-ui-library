import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../theme/theme.dart';
import 'window_manager.dart';

/// How much of the title bar (horizontally) a drag always leaves on screen.
const double _grabMargin = 48;

/// How close (px) to a viewport edge the pointer must be for a drag to snap.
const double _snapBand = 24;
const double _minWidth = 220;
const double _minHeight = 120;

/// `ui-window`: a floating, draggable, resizable window ("a window inside the window") that hosts
/// any [child]. It renders into the nearest [Overlay], whose area is its viewport (the web's
/// `position: fixed`), so it can be placed anywhere in the tree.
///
/// Drag the title bar to move it; release with the pointer within 24px of the top edge to maximize,
/// the left or right edge for that half, or the bottom edge for the bottom half. A drag keeps at
/// least 48px of the title bar on screen and never takes it above the top or below the bottom, so
/// it can always be grabbed again. Double-tap the title bar to maximize or restore. Resize from any
/// edge or corner (at least 220 x 120). Minimize, Maximize/Restore and Close buttons; a press
/// anywhere on the window brings it to the front ([UiWindowManager]).
///
/// [open] with [onOpenChanged] is two-way: Close reports `false` (and calls [onClosed]), and a closed
/// window leaves the screen and the manager until it is opened again. Without [onOpenChanged] the
/// window closes itself.
///
/// When the viewport is narrower than [sheetBreakpoint] (a phone) the window opens as a full-screen
/// sheet instead: it fills the viewport below the status bar, slides up, and keeps only Close.
///
/// Reach the methods ([UiWindowState.dock], [UiWindowState.restore], [UiWindowState.setBounds],
/// [UiWindowState.minimize]) through a `GlobalKey<UiWindowState>`. Screen readers meet it as a
/// named route scope (the web `role="dialog"` with `aria-label`), named by [title].
class UiWindow extends StatefulWidget {
  const UiWindow({
    super.key,
    required this.child,
    this.open = true,
    this.onOpenChanged,
    this.onClosed,
    this.title = 'Window',
    this.draggable = true,
    this.resizable = true,
    this.glass,
    this.radius,
    this.initialX = 80,
    this.initialY = 80,
    this.initialWidth = 440,
    this.initialHeight = 300,
    this.scrollable = true,
    this.sheetBreakpoint = 600,
  });

  final Widget child;
  final bool open;
  final ValueChanged<bool>? onOpenChanged;
  final VoidCallback? onClosed;
  final String title;
  final bool draggable;
  final bool resizable;

  /// Frosted surface; defaults to [UiConfig.glass].
  final bool? glass;

  /// Rounded corners; defaults to [UiConfig.radius].
  final bool? radius;
  final double initialX;
  final double initialY;
  final double initialWidth;
  final double initialHeight;

  /// Scroll the body when [child] is taller than the window (the web `overflow: auto`). Turn off
  /// for content that fills the window and scrolls itself.
  final bool scrollable;

  /// Viewports narrower than this show the window as a full-screen sheet.
  final double sheetBreakpoint;

  @override
  State<UiWindow> createState() => UiWindowState();
}

enum _Edge {
  n(0, -1), s(0, 1), e(1, 0), w(-1, 0), ne(1, -1), nw(-1, -1), se(1, 1), sw(-1, 1);

  const _Edge(this.sx, this.sy);
  final int sx;
  final int sy;

  MouseCursor get cursor => switch (this) {
        _Edge.n || _Edge.s => SystemMouseCursors.resizeUpDown,
        _Edge.e || _Edge.w => SystemMouseCursors.resizeLeftRight,
        _Edge.ne || _Edge.sw => SystemMouseCursors.resizeUpRightDownLeft,
        _Edge.nw || _Edge.se => SystemMouseCursors.resizeUpLeftDownRight,
      };
}

/// The state of a [UiWindow]: its bounds and the imperative methods of the web component.
class UiWindowState extends State<UiWindow> with SingleTickerProviderStateMixin implements UiWindowHandle {
  UiWindowManager? _mgr;
  String? _id;
  late bool _open = widget.open;
  late bool _visible = widget.open;
  int _session = 0;
  OverlayPortalController _portal = OverlayPortalController();
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  final GlobalKey _stageKey = GlobalKey();

  double _x = 0, _y = 0, _w = 0, _h = 0;
  bool _placed = false;
  bool _maximized = false;
  bool _minimized = false;
  UiDockSide? _snap;
  Rect? _prev;
  Size? _viewport;
  bool _sheet = false;
  double _safeTop = 0;

  Offset _dragStart = Offset.zero;
  Offset _dragFrom = Offset.zero;
  bool _dragging = false;
  Offset _rzStart = Offset.zero;
  Rect _rzFrom = Rect.zero;

  @override
  String get id => _id ??= (_mgr ?? UiWindowScope.read(context)).nextId();

  @override
  Size? get viewport => _viewport;

  /// The window's bounds in its viewport (before it is first shown: the requested ones).
  Rect get bounds => _placed ? Rect.fromLTWH(_x, _y, _w, _h) : Rect.fromLTWH(widget.initialX, widget.initialY, widget.initialWidth, widget.initialHeight);
  bool get isMaximized => _maximized;
  bool get isMinimized => _minimized;

  /// Whether it is showing as a full-screen sheet (narrow viewport).
  bool get isSheet => _sheet;

  @override
  void initState() {
    super.initState();
    if (_open) _portal.show();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _anim.duration = context.ui.motionBase;
    final mgr = UiWindowScope.read(context);
    if (!identical(mgr, _mgr)) {
      if (_mgr != null && _id != null) _mgr!.unregister(_id!);
      final first = _mgr == null;
      _mgr = mgr;
      if (_open) {
        mgr.register(this);
        if (first) _enter();
      }
    }
  }

  @override
  void didUpdateWidget(UiWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open && widget.open != _open) _setOpen(widget.open);
  }

  @override
  void dispose() {
    if (_id != null) _mgr?.unregister(_id!);
    _anim.dispose();
    super.dispose();
  }

  void _enter() {
    if (context.uiAnimate) {
      _anim.forward(from: 0);
    } else {
      _anim.value = 1;
    }
  }

  void _setOpen(bool open) {
    _open = open;
    if (open) {
      _session++;
      _portal = OverlayPortalController()..show();
      _visible = true;
      _mgr?.register(this);
      _enter();
    } else {
      if (_id != null) _mgr?.unregister(_id!);
      _snap = null;
      if (context.uiAnimate && _visible) {
        _anim.reverse().whenCompleteOrCancel(() {
          if (mounted && !_open) setState(() => _visible = false);
        });
      } else {
        _visible = false;
      }
    }
  }

  void _close() {
    setState(() => _setOpen(false));
    widget.onOpenChanged?.call(false);
    widget.onClosed?.call();
  }

  // ----- UiWindowHandle -----

  @override
  void focus() {
    if (!_open) return;
    _mgr?.bringToFront(id);
    void raise() {
      if (mounted && _open) _portal.show();
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => raise());
    } else {
      raise();
    }
  }

  @override
  void minimize() => setState(() => _minimized = true);

  /// Back from minimized, to the size it had (maximized stays maximized).
  void unminimize() => setState(() => _minimized = false);

  /// Un-minimizes and un-maximizes, returning to the bounds it had before it was docked.
  @override
  void restore() => setState(_restore);

  void _restore() {
    _maximized = false;
    _minimized = false;
    if (_prev != null) {
      _apply(_prev!);
      _prev = null;
    }
  }

  /// Docks to a half of the viewport or fills it; `null` restores. [UiDockSide.top] is only
  /// reachable this way: a drag to the top edge maximizes.
  @override
  void dock(UiDockSide? side) {
    if (side == null) return restore();
    final vp = _viewport;
    if (vp == null) return;
    setState(() {
      _prev ??= Rect.fromLTWH(_x, _y, _w, _h);
      _apply(uiDockBounds(side, vp));
      _maximized = side == UiDockSide.maximize;
      _minimized = false;
    });
  }

  @override
  void setBounds(Rect b) => setState(() {
        _prev = null;
        _maximized = false;
        _minimized = false;
        _apply(b);
      });

  void _apply(Rect b) {
    _placed = true;
    _x = b.left;
    _y = b.top;
    _w = b.width;
    _h = b.height;
  }

  void _toggleMax() => _maximized ? restore() : dock(UiDockSide.maximize);

  // ----- dragging -----

  Offset _toStage(Offset global) {
    final box = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? global : box.globalToLocal(global);
  }

  // On touch the bar holds 48dp buttons above its 1px bottom border.
  double _barHeight(BuildContext context) => uiTouchPlatform(context) ? uiMinTouchTarget + 1 : context.ui.sizeSm + context.ui.space2;

  void _dragBegin(DragStartDetails d) {
    focus();
    setState(() {
      if (_maximized) {
        // Come back to the old size under the pointer, where it was grabbed along the bar.
        final at = _toStage(d.globalPosition);
        final frac = _w > 0 ? ((at.dx - _x) / _w).clamp(0.0, 1.0) : 0.5;
        _restore();
        _x = at.dx - frac * _w;
        _y = 0;
      }
      _dragging = true;
      _dragStart = d.globalPosition;
      _dragFrom = Offset(_x, _y);
    });
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    final next = _dragFrom + (d.globalPosition - _dragStart);
    final side = _detectSnap(_toStage(d.globalPosition));
    setState(() {
      final p = _clamp(next);
      _x = p.dx;
      _y = p.dy;
      _snap = side;
    });
  }

  void _dragEnd() {
    if (!_dragging) return;
    final side = _snap;
    setState(() {
      _dragging = false;
      _snap = null;
    });
    if (side != null) dock(side);
  }

  /// Keeps at least 48px of the title bar on screen horizontally, never above the top edge and
  /// never below the bottom one.
  Offset _clamp(Offset p) {
    final vp = _viewport;
    if (vp == null) return Offset(p.dx, math.max(0, p.dy));
    final keep = math.min(_grabMargin, _w);
    final bar = _barHeight(context);
    return Offset(
      math.min(math.max(p.dx, keep - _w), vp.width - keep),
      math.max(0, math.min(p.dy, vp.height - bar)),
    );
  }

  UiDockSide? _detectSnap(Offset p) {
    final vp = _viewport;
    if (vp == null) return null;
    if (p.dy <= _snapBand) return UiDockSide.maximize;
    if (p.dx <= _snapBand) return UiDockSide.left;
    if (p.dx >= vp.width - _snapBand) return UiDockSide.right;
    if (p.dy >= vp.height - _snapBand) return UiDockSide.bottom;
    return null;
  }

  DateTime? _lastBarTap;
  Offset? _lastBarTapAt;

  void _barTapUp(TapUpDetails d) {
    final now = DateTime.now();
    final last = _lastBarTap, at = _lastBarTapAt;
    if (last != null && at != null && now.difference(last) < kDoubleTapTimeout && (d.globalPosition - at).distance < kDoubleTapSlop) {
      _lastBarTap = null;
      _toggleMax();
    } else {
      _lastBarTap = now;
      _lastBarTapAt = d.globalPosition;
    }
  }

  // ----- resizing -----

  void _resizeBegin(DragStartDetails d) {
    focus();
    _rzStart = d.globalPosition;
    _rzFrom = Rect.fromLTWH(_x, _y, _w, _h);
  }

  void _resizeUpdate(_Edge edge, DragUpdateDetails d) {
    final delta = d.globalPosition - _rzStart;
    final s = _rzFrom;
    var x = s.left, y = s.top, w = s.width, h = s.height;
    if (edge.sx > 0) w = math.max(_minWidth, s.width + delta.dx);
    if (edge.sy > 0) h = math.max(_minHeight, s.height + delta.dy);
    if (edge.sx < 0) {
      w = math.max(_minWidth, s.width - delta.dx);
      x = s.left + (s.width - w);
    }
    if (edge.sy < 0) {
      h = math.max(_minHeight, s.height - delta.dy);
      y = s.top + (s.height - h);
    }
    setState(() => _apply(Rect.fromLTWH(x, y, w, h)));
  }

  // ----- build -----

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    // Read here: the overlay child sees the Overlay's MediaQuery, not the one around the window.
    _safeTop = MediaQuery.paddingOf(context).top;
    return OverlayPortal(
      key: ValueKey(_session),
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final vp = constraints.biggest;
      _viewport = vp;
      _sheet = vp.width < widget.sheetBreakpoint;
      if (!_placed) {
        final w = math.min(widget.initialWidth, vp.width), h = math.min(widget.initialHeight, vp.height);
        _apply(Rect.fromLTWH(
          math.max(0, math.min(widget.initialX, vp.width - w)),
          math.max(0, math.min(widget.initialY, vp.height - h)),
          w,
          h,
        ));
      }
      final t = context.ui;
      final r = (widget.radius ?? context.uiTheme.config.radius) ? t.radiusLg : 0.0;
      return Stack(key: _stageKey, clipBehavior: Clip.none, children: [
        if (_snap != null && !_sheet)
          AnimatedPositioned.fromRect(
            rect: uiDockBounds(_snap!, vp),
            duration: context.uiAnimate ? t.motionFast : Duration.zero,
            curve: t.easeStandard,
            child: IgnorePointer(
              child: DecoratedBox(
                key: const Key('ui-window-snap-preview'),
                decoration: BoxDecoration(
                  color: t.primary.withValues(alpha: 0.22),
                  border: Border.all(color: t.primary, width: 2),
                  borderRadius: BorderRadius.circular(r),
                ),
              ),
            ),
          ),
        _sheet ? _buildSheet(context, vp, r) : _buildFloating(context, r),
      ]);
    });
  }

  Widget _buildSheet(BuildContext context, Size vp, double r) {
    final top = math.max(_safeTop, MediaQuery.paddingOf(context).top);
    final frame = _frame(context, BorderRadius.vertical(top: Radius.circular(r)), sheet: true);
    final animated = context.uiAnimate
        ? SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: _anim, curve: context.ui.easeDecelerate, reverseCurve: context.ui.easeAccelerate)),
            child: frame,
          )
        : frame;
    return Positioned(left: 0, top: top, width: vp.width, height: vp.height - top, child: IgnorePointer(ignoring: !_open, child: animated));
  }

  Widget _buildFloating(BuildContext context, double r) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    final barH = _barHeight(context);
    final canResize = widget.resizable && !_maximized && !_minimized;
    // Resize zones straddle the border: half outside the window, half inside.
    final edge = touch ? 16.0 : 7.0;
    final corner = touch ? 24.0 : 12.0;
    final m = canResize ? edge / 2 : 0.0;
    final h = _minimized ? barH + 2 : _h;

    Widget frame = _frame(context, BorderRadius.circular(r), sheet: false);
    if (context.uiAnimate) {
      final curve = CurvedAnimation(parent: _anim, curve: t.easeDecelerate, reverseCurve: t.easeAccelerate);
      frame = FadeTransition(opacity: curve, child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curve), child: frame));
    }

    Widget zone(_Edge e, {double? left, double? top, double? right, double? bottom, double? width, double? height}) => Positioned(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
          width: width,
          height: height,
          child: MouseRegion(
            cursor: e.cursor,
            child: GestureDetector(
              key: Key('ui-window-resize-${e.name}'),
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              dragStartBehavior: DragStartBehavior.down,
              onPanStart: _resizeBegin,
              onPanUpdate: (d) => _resizeUpdate(e, d),
            ),
          ),
        );

    return Positioned(
      left: _x - m,
      top: _y - m,
      width: _w + 2 * m,
      height: h + 2 * m,
      child: IgnorePointer(
        ignoring: !_open,
        child: Listener(
          onPointerDown: (_) {
            if (_mgr?.focusedId != id || _mgr?.order.last != id) focus();
          },
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(left: m, top: m, right: m, bottom: m, child: frame),
            if (canResize) ...[
              zone(_Edge.n, top: 0, left: corner, right: corner, height: edge),
              zone(_Edge.s, bottom: 0, left: corner, right: corner, height: edge),
              zone(_Edge.e, right: 0, top: corner, bottom: corner, width: edge),
              zone(_Edge.w, left: 0, top: corner, bottom: corner, width: edge),
              zone(_Edge.nw, left: 0, top: 0, width: corner, height: corner),
              zone(_Edge.ne, right: 0, top: 0, width: corner, height: corner),
              zone(_Edge.sw, left: 0, bottom: 0, width: corner, height: corner),
              zone(_Edge.se, right: 0, bottom: 0, width: corner, height: corner),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _frame(BuildContext context, BorderRadius radius, {required bool sheet}) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final glass = widget.glass ?? theme.config.glass;
    Widget body = Padding(padding: EdgeInsets.all(t.space4), child: widget.child);
    if (widget.scrollable) body = SingleChildScrollView(child: body);

    Widget frame = DecoratedBox(
      decoration: BoxDecoration(
        color: glass ? t.glassBg : t.surface,
        borderRadius: radius,
        border: Border.all(color: glass ? t.glassBorder : t.border),
        boxShadow: t.shadow3,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _titleBar(context, sheet: sheet),
          if (!_minimized || sheet) Expanded(child: DefaultTextStyle.merge(style: context.uiText.body, child: body)),
        ]),
      ),
    );
    if (glass) {
      frame = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: t.glassBlur / 2, sigmaY: t.glassBlur / 2), child: frame),
      );
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      scopesRoute: true,
      namesRoute: true,
      label: widget.title,
      child: FocusTraversalGroup(child: frame),
    );
  }

  Widget _titleBar(BuildContext context, {required bool sheet}) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    final canDrag = widget.draggable && !sheet;
    final collapsed = _minimized && !sheet;
    Widget bar = Container(
      height: _barHeight(context),
      padding: EdgeInsets.only(left: t.space3, right: t.space1),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        border: collapsed ? null : Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(spacing: t.space3, children: [
        Expanded(
          child: ExcludeSemantics(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.label.copyWith(color: t.text),
            ),
          ),
        ),
        Row(mainAxisSize: MainAxisSize.min, spacing: touch ? 0 : 2, children: [
          if (!sheet) ...[
            // Minimized, the first control brings the window back (it keeps a maximized size).
            _ChromeButton(
              icon: _minimized ? HugeIcons.strokeRoundedBrowser : HugeIcons.strokeRoundedMinusSign,
              label: _minimized ? 'Restore' : 'Minimize',
              onTap: _minimized ? unminimize : minimize,
            ),
            _ChromeButton(
              icon: _maximized ? HugeIcons.strokeRoundedCopy01 : HugeIcons.strokeRoundedSquare,
              label: _maximized ? 'Restore' : 'Maximize',
              onTap: _toggleMax,
            ),
          ],
          _ChromeButton(icon: HugeIcons.strokeRoundedCancel01, label: context.uiStrings.close, danger: true, onTap: _close),
        ]),
      ]),
    );
    if (sheet) return bar;
    bar = GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      dragStartBehavior: DragStartBehavior.down,
      onPanStart: canDrag ? _dragBegin : null,
      onPanUpdate: canDrag ? _dragUpdate : null,
      onPanEnd: canDrag ? (_) => _dragEnd() : null,
      onPanCancel: canDrag ? _dragEnd : null,
      // Double-tap by hand: a double-tap recognizer would hold every tap on the chrome buttons
      // until its timeout.
      onTapUp: _barTapUp,
      child: bar,
    );
    return canDrag ? MouseRegion(cursor: _dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab, child: bar) : bar;
  }
}

/// A title-bar control: a small square that fills on hover (red for Close), with a 48dp target on
/// touch screens.
class _ChromeButton extends StatelessWidget {
  const _ChromeButton({required this.icon, required this.label, required this.onTap, this.danger = false});

  final UiIconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      semanticLabel: label,
      excludeChildSemantics: true,
      builder: (context, s) {
        final hot = s.hovered || s.pressed;
        return AnimatedContainer(
          duration: context.uiAnimate ? t.motionFast : Duration.zero,
          curve: t.easeStandard,
          width: t.sizeSm,
          height: t.sizeSm,
          decoration: BoxDecoration(
            color: hot ? (danger ? t.danger : t.elevatedHover) : null,
            borderRadius: BorderRadius.circular(context.uiTheme.radius(t.radiusXs)),
            boxShadow: s.focused ? t.focusRing : const [],
          ),
          child: Center(child: UiIcon(icon, size: 16, color: hot ? (danger ? t.dangerContrast : t.text) : t.textMuted)),
        );
      },
    );
  }
}

