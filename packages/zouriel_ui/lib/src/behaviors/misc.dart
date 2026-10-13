import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// `uiCopyToClipboard`: copies [text] when the [builder]'s `copy` is called, and for 1.5 s after a
/// copy builds with `copied` true (to show "Copied"). The result is announced to screen readers,
/// including a hint to copy by hand when the clipboard refuses.
///
/// ```dart
/// UiCopyToClipboard(
///   text: code,
///   builder: (context, copied, copy) => UiButton(label: copied ? 'Copied' : 'Copy', onPressed: copy),
/// )
/// ```
class UiCopyToClipboard extends StatefulWidget {
  const UiCopyToClipboard({super.key, required this.text, required this.builder, this.onCopied, this.onCopyFailed});

  final String text;
  final Widget Function(BuildContext context, bool copied, VoidCallback copy) builder;
  final ValueChanged<String>? onCopied;
  final ValueChanged<Object>? onCopyFailed;

  /// How long `copied` stays true.
  static const Duration copiedFor = Duration(milliseconds: 1500);

  @override
  State<UiCopyToClipboard> createState() => _UiCopyToClipboardState();
}

class _UiCopyToClipboardState extends State<UiCopyToClipboard> {
  bool _copied = false;
  Timer? _reset;

  Future<void> _copy() async {
    final value = widget.text;
    final view = View.of(context);
    final dir = Directionality.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (!mounted) return;
      setState(() => _copied = true);
      unawaited(SemanticsService.sendAnnouncement(view, 'Copied to clipboard', dir));
      widget.onCopied?.call(value);
      _reset?.cancel();
      _reset = Timer(UiCopyToClipboard.copiedFor, () {
        if (mounted) setState(() => _copied = false);
      });
    } catch (err) {
      unawaited(SemanticsService.sendAnnouncement(view, 'Couldn’t copy. Select the text and copy it manually.', dir));
      widget.onCopyFailed?.call(err);
    }
  }

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _copied, _copy);
}

/// `uiResizeObserver`: calls [onResize] with [child]'s size once it is first laid out and whenever
/// it changes. (Inside one build, `LayoutBuilder` is usually simpler; this is for reporting a size
/// out to a parent.)
class UiResizeObserver extends SingleChildRenderObjectWidget {
  const UiResizeObserver({super.key, required this.onResize, super.child});

  final ValueChanged<Size> onResize;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderResizeObserver(onResize);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) => (renderObject as _RenderResizeObserver).onResize = onResize;
}

class _RenderResizeObserver extends RenderProxyBox {
  _RenderResizeObserver(this.onResize);

  ValueChanged<Size> onResize;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final s = size;
    if (s == _reported) return;
    _reported = s;
    // Reported after the frame: the listener may well call setState.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached && _reported == s) onResize(s);
    });
  }
}

/// `uiRipple`: an ink ripple that spreads from where [child] is pressed (finger, mouse or pen; a
/// keyboard press shows none). Clipped to [borderRadius]. Skipped under reduced motion: the
/// control's own pressed state is feedback enough.
class UiRipple extends StatefulWidget {
  const UiRipple({super.key, required this.child, this.color, this.enabled = true, this.borderRadius = BorderRadius.zero});

  final Widget child;

  /// Defaults to the surrounding text colour (the web `currentColor`).
  final Color? color;
  final bool enabled;
  final BorderRadius borderRadius;

  @override
  State<UiRipple> createState() => _UiRippleState();
}

class _Wave {
  _Wave(this.at, this.controller);
  final Offset at;
  final AnimationController controller;
}

class _UiRippleState extends State<UiRipple> with TickerProviderStateMixin {
  final List<_Wave> _waves = [];

  void _spawn(PointerDownEvent e) {
    if (!widget.enabled || !context.uiAnimate) return;
    final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    final wave = _Wave(e.localPosition, c);
    c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _waves.remove(wave));
        c.dispose();
      }
    });
    setState(() => _waves.add(wave));
    c.forward();
  }

  @override
  void dispose() {
    for (final w in _waves) {
      w.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? DefaultTextStyle.of(context).style.color ?? context.ui.text;
    final ease = context.ui.easeStandard;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _spawn,
      child: CustomPaint(
        foregroundPainter: _RipplePainter(_waves, color, widget.borderRadius, ease, Listenable.merge([for (final w in _waves) w.controller])),
        child: widget.child,
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.waves, this.color, this.radius, this.ease, Listenable repaint) : super(repaint: repaint);

  final List<_Wave> waves;
  final Color color;
  final BorderRadius radius;
  final Curve ease;

  @override
  void paint(Canvas canvas, Size size) {
    if (waves.isEmpty) return;
    canvas.save();
    canvas.clipRRect(radius.toRRect(Offset.zero & size));
    final base = math.max(size.width, size.height);
    for (final w in waves) {
      final v = w.controller.value;
      // Scale 0 → 2.2 over 480 ms; opacity .35 → 0 over 600 ms.
      final grow = ease.transform((v * 600 / 480).clamp(0.0, 1.0));
      canvas.drawCircle(w.at, base / 2 * 2.2 * grow, Paint()..color = color.withValues(alpha: 0.35 * (1 - v)));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RipplePainter old) => true;
}

/// A thin wrapper for moving something by hand: [child] is drawn at [offset] and dragging it (or,
/// once focused, the arrow keys: 8px, Shift 32px) reports the new offset through [onChanged],
/// clamped to [bounds] when given. Pair with [UiResizeHandle] for resizable panels.
class UiDraggable extends StatefulWidget {
  const UiDraggable({super.key, required this.child, required this.offset, required this.onChanged, this.bounds, this.label = 'Move', this.onDragEnd});

  final Widget child;
  final Offset offset;
  final ValueChanged<Offset> onChanged;

  /// The rectangle the offset is kept inside.
  final Rect? bounds;

  /// Accessible name for the move handle.
  final String label;
  final ValueChanged<Offset>? onDragEnd;

  @override
  State<UiDraggable> createState() => _UiDraggableState();
}

class _Move extends Intent {
  const _Move(this.by);
  final Offset by;
}

class _UiDraggableState extends State<UiDraggable> {
  late Offset _live = widget.offset;
  bool _focus = false;

  @override
  void didUpdateWidget(UiDraggable old) {
    super.didUpdateWidget(old);
    _live = widget.offset;
  }

  Offset _clamp(Offset o) {
    final b = widget.bounds;
    if (b == null) return o;
    return Offset(o.dx.clamp(b.left, math.max(b.left, b.right)), o.dy.clamp(b.top, math.max(b.top, b.bottom)));
  }

  void _move(Offset by) {
    _live = _clamp(_live + by);
    widget.onChanged(_live);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    Map<ShortcutActivator, Intent> keys(LogicalKeyboardKey k, Offset d) => {SingleActivator(k): _Move(d), SingleActivator(k, shift: true): _Move(d * 4)};
    return Transform.translate(
      offset: widget.offset,
      child: Semantics(
        label: widget.label,
        hint: 'Drag, or use the arrow keys',
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.move,
          onShowFocusHighlight: (v) => setState(() => _focus = v),
          shortcuts: {
            ...keys(LogicalKeyboardKey.arrowLeft, const Offset(-8, 0)),
            ...keys(LogicalKeyboardKey.arrowRight, const Offset(8, 0)),
            ...keys(LogicalKeyboardKey.arrowUp, const Offset(0, -8)),
            ...keys(LogicalKeyboardKey.arrowDown, const Offset(0, 8)),
          },
          actions: {_Move: CallbackAction<_Move>(onInvoke: (i) => _move(i.by))},
          child: GestureDetector(
            onPanStart: (_) => _live = widget.offset,
            onPanUpdate: (d) => _move(d.delta),
            onPanEnd: (_) => widget.onDragEnd?.call(_live),
            child: DecoratedBox(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(t.radius), boxShadow: _focus ? t.focusRing : const []),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
