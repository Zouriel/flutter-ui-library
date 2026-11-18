import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../core/svg_path.dart';
import '../feedback/spinner.dart';
import '../forms/text/text_dir.dart';
import '../theme/theme.dart';
import 'blob_shape.dart';
import 'toast.dart';

/// The pill shows alone for this long before the card grows out of it.
const Duration _openDelay = Duration(milliseconds: 360);

/// After a change of state: the pill shows its new title and colour for this long, then reopens.
const Duration _reopenDelay = Duration(milliseconds: 180);

/// Whether a blob toast has anything to put in the card under its pill (the web `uiBlobToastHasBody`).
bool uiBlobToastHasBody(UiToast t) => (t.title != null && t.title!.isNotEmpty && t.message.isNotEmpty) || t.action != null || t.content != null;

/// `ui-blob-toast`: one toast drawn as a blob ([UiToastVariant.blob]): a pill with the tone's icon
/// and the title, which grows a card beneath it for the message, custom content and the action, as
/// one shape. [UiToastHost] builds it; apps go through [UiToastController] (`blob`, `update`,
/// `promise`), or place one themselves.
///
/// A different [toast] closes the card back to the pill, swaps the title and colour there, and
/// opens it again. With [expanded] false the card stays closed until the pointer is on the toast or
/// its pill is tapped; [UiToastHost] does this when several blob toasts are showing. Tapping the pill
/// of an open toast, or of one with no card, calls [onDismiss]. It sits on the inverted surface the snackbar
/// uses (the theme's text colour) and is at most 340 wide.
class UiBlobToast extends StatefulWidget {
  const UiBlobToast({super.key, required this.toast, this.side = UiBlobSide.center, this.expanded = true, this.onAction, this.onDismiss, this.textStyle});

  final UiToast toast;

  /// Where the pill sits over the card.
  final UiBlobSide side;

  /// Whether the card opens by itself. When false it opens under the pointer or on a tap of the pill.
  final bool expanded;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  /// Merged over the title, message and action label (see [UiToastHost.textStyle]).
  final TextStyle? textStyle;

  /// The tone's colour as the toast draws it, for accents in custom content (the web
  /// `--ui-toast-tone`). Null outside a blob toast.
  static Color? toneOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_BlobTone>()?.color;

  @override
  State<UiBlobToast> createState() => _UiBlobToastState();
}

class _BlobTone extends InheritedWidget {
  const _BlobTone({required this.color, required super.child});
  final Color color;

  @override
  bool updateShouldNotify(_BlobTone oldWidget) => oldWidget.color != color;
}

class _UiBlobToastState extends State<UiBlobToast> with TickerProviderStateMixin {
  static const SpringDescription _spring = SpringDescription(mass: 1, stiffness: 260, damping: 24);

  late UiToast _shown = widget.toast;
  UiToast? _pending;

  /// Bumped on each swap, so the icon and title fade in again.
  int _rev = 0;
  bool _open = false;
  double _target = 0;
  bool _hovered = false;

  /// Opened by a tap on the pill; holds until the toast changes.
  bool _pinned = false;

  /// The first wait is over, so hover and [UiBlobToast.expanded] may move the card.
  bool _started = false;

  bool get _wantsOpen => uiBlobToastHasBody(_shown) && (widget.expanded || _hovered || _pinned);

  /// Follows hover, a tap or [UiBlobToast.expanded], outside the first wait and a swap (those end in
  /// [_reopen], which reads them then).
  void _follow() {
    if (!_started || _pending != null || _delay.isAnimating) return;
    if ((_wantsOpen ? 1.0 : 0.0) != _target) _reopen();
  }

  void _hover(bool on) {
    if (_hovered == on) return;
    _hovered = on;
    _follow();
  }

  void _pillTap() {
    if (uiBlobToastHasBody(_shown) && !_open) {
      _pinned = true;
      _follow();
    } else {
      widget.onDismiss?.call();
    }
  }

  /// 0 is the pill, 1 the open card; a little past 1 while the spring overshoots.
  late final AnimationController _progress = AnimationController.unbounded(vsync: this)..addListener(_stopAtPill);
  late final AnimationController _pillAnim = AnimationController(vsync: this, value: 1);
  late final AnimationController _delay = AnimationController(vsync: this);
  double _pillFrom = 0;
  double _pillTo = 0;
  double _bodyHeight = 0;

  bool get _animate => context.uiAnimate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _later(_openDelay, () { _started = true; _reopen(); }) : null);
  }

  @override
  void didUpdateWidget(UiBlobToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    final t = widget.toast;
    if (oldWidget.expanded != widget.expanded) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _follow() : null);
    if (identical(t, oldWidget.toast) || identical(t, _pending ?? _shown)) return;
    _pending = t;
    if (_target > 0 || _progress.value > 0) {
      // Close to the pill first; the swap happens when it gets there.
      _target = 0;
      _open = false;
      _run();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _swap() : null);
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _pillAnim.dispose();
    _delay.dispose();
    super.dispose();
  }

  void _later(Duration d, VoidCallback fn) {
    _delay.stop();
    if (!_animate) return fn();
    _delay.duration = d;
    _delay.forward(from: 0).whenComplete(() => mounted ? fn() : null);
  }

  void _swap() {
    final t = _pending;
    if (t == null) return;
    setState(() {
      _pending = null;
      _pinned = false;
      _shown = t;
      _rev++;
    });
    _later(_reopenDelay, _reopen);
  }

  void _reopen() {
    if (_pending != null) return;
    setState(() {
      _target = _wantsOpen ? 1 : 0;
      _open = _target > 0;
    });
    _run();
  }

  void _run() {
    if (!_animate) {
      _progress.value = _target;
      _arrived();
      return;
    }
    _progress.animateWith(SpringSimulation(_spring, _progress.value, _target, _progress.velocity)).whenCompleteOrCancel(_arrived);
  }

  /// Closing never bounces: the spring stops when it reaches the pill.
  void _stopAtPill() {
    if (_target == 0 && _progress.isAnimating && _progress.value <= 0) {
      _progress.stop();
      _progress.value = 0;
    }
  }

  void _arrived() {
    if (mounted && _pending != null && _target == 0 && _progress.value <= 0.0005 && !_progress.isAnimating) _swap();
  }

  void _pillSized(Size s) {
    if (s.width == _pillTo) return;
    final t = context.ui;
    setState(() {
      if (_pillTo == 0 || !_animate) {
        _pillFrom = _pillTo = s.width;
        return;
      }
      _pillFrom = _pillFrom + (_pillTo - _pillFrom) * t.easeStandard.transform(_pillAnim.value);
      _pillTo = s.width;
      _pillAnim
        ..duration = t.motionBase
        ..forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final toast = _shown;
    // The inverted surface the snackbar uses: near-black on a light theme, near-white on a dark one.
    final surface = t.text;
    final muted = Color.lerp(t.text, t.bg, 0.7)!;
    final hue = switch (toast.tone) { UiToastTone.info => t.info, UiToastTone.success => t.success, UiToastTone.warning => t.warning, UiToastTone.danger => t.danger };
    final tone = toast.loading ? muted : uiBlobTone(hue, t.bg);
    final base = theme.typography.body.copyWith(fontSize: t.fontSizeSm, height: 1.45);
    TextStyle font(TextStyle s) => widget.textStyle == null ? s : uiMergeFieldStyle(s, widget.textStyle).copyWith(inherit: false);
    final ph = t.sizeLg;
    final title = toast.title != null && toast.title!.isNotEmpty ? toast.title! : toast.message;
    final hasMessage = toast.title != null && toast.title!.isNotEmpty && toast.message.isNotEmpty;

    final pill = _Measure(
      onChange: _pillSized,
      child: MouseRegion(
        cursor: widget.onDismiss == null && widget.expanded ? MouseCursor.defer : SystemMouseCursors.click,
        // Entering the pill opens it; the whole box then holds the pointer (see below).
        onEnter: (_) => _hover(true),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // The swipe on the host and its dismiss action are the accessible ways out.
          excludeFromSemantics: true,
          onTap: _pillTap,
          child: SizedBox(
            height: ph,
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: t.space2, end: t.space4),
              child: TweenAnimationBuilder<double>(
                key: ValueKey(_rev),
                tween: Tween(begin: _animate ? 0 : 1, end: 1),
                duration: t.motionSlow,
                curve: t.easeDecelerate,
                builder: (context, v, child) => Opacity(opacity: v.clamp(0.0, 1.0), child: child),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: t.space2,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Color.lerp(surface, tone, 0.2)),
                      child: toast.loading
                          ? UiSpinner(size: 14, strokeWidth: 2, color: tone, decorative: true)
                          : CustomPaint(size: const Size.square(12), painter: _GlyphPainter(toast.tone, tone)),
                    ),
                    Flexible(
                      child: AnimatedDefaultTextStyle(
                        duration: _animate ? t.motionBase : Duration.zero,
                        style: font(base.copyWith(fontWeight: FontWeight.w600, color: tone)),
                        child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final body = _Measure(
      onChange: (s) => s.height == _bodyHeight ? null : setState(() => _bodyHeight = s.height),
      child: !uiBlobToastHasBody(toast)
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: EdgeInsets.all(t.space4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: t.space3,
                children: [
                  if (hasMessage) Text(toast.message, style: font(base.copyWith(color: muted))),
                  if (toast.content != null)
                    DefaultTextStyle(
                      style: font(base.copyWith(color: muted)),
                      child: IconTheme.merge(data: IconThemeData(color: muted), child: toast.content!),
                    ),
                  if (toast.action != null)
                    UiInteractive(
                      onTap: widget.onAction,
                      semanticLabel: toast.action!.label,
                      excludeChildSemantics: true,
                      builder: (context, states) => Container(
                        height: ph,
                        alignment: Alignment.center,
                        padding: EdgeInsets.symmetric(horizontal: t.space4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(t.radiusPill),
                          color: Color.lerp(surface, tone, states.hovered || states.pressed ? 0.26 : 0.16),
                          boxShadow: states.focused ? t.focusRing : null,
                        ),
                        child: Text(toast.action!.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: font(base.copyWith(fontWeight: FontWeight.w600, color: tone))),
                      ),
                    ),
                ],
              ),
            ),
    );

    return Semantics(
      container: true,
      liveRegion: true,
      child: _BlobTone(
        color: tone,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = math.min(340.0, constraints.maxWidth);
            return AnimatedBuilder(
              animation: Listenable.merge([_progress, _pillAnim]),
              builder: (context, _) {
                final p = math.max(0.0, _progress.value);
                final pc = math.min(1.0, p);
                final pillWidth = _pillFrom + (_pillTo - _pillFrom) * t.easeStandard.transform(_pillAnim.value);
                final g = UiBlobGeometry(width: w, pillWidth: pillWidth, pillHeight: ph, bodyHeight: _bodyHeight, side: widget.side, progress: p);
                // Soft while it moves, sharp at rest: the shape and text blur in the middle of a transition.
                final blur = 3.5 * math.sin(math.pi * pc);
                // Leaving the box, not the pill, closes a hovered toast: the card grows under the pointer.
                return MouseRegion(
                  opaque: false,
                  onExit: (_) => _hover(false),
                  child: SizedBox(
                  width: w,
                  height: ph + _bodyHeight * pc,
                  child: CustomPaint(
                    painter: pillWidth > 0 ? _BlobPainter(g, surface, t.shadow2, blur) : null,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          width: w,
                          child: IgnorePointer(
                            ignoring: !_open,
                            child: ExcludeFocus(
                              excluding: !_open,
                              child: ClipPath(
                                clipper: _BlobClipper(g),
                                child: Opacity(
                                  opacity: ((pc - 0.45) / 0.55).clamp(0.0, 1.0),
                                  child: ImageFiltered(
                                    enabled: blur > 0.05,
                                    imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                                    child: Padding(padding: EdgeInsets.only(top: ph), child: body),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          width: w,
                          child: Align(
                            alignment: switch (widget.side) { UiBlobSide.left => Alignment.topLeft, UiBlobSide.right => Alignment.topRight, UiBlobSide.center => Alignment.topCenter },
                            child: ConstrainedBox(constraints: BoxConstraints(maxWidth: math.max(0, w - 72)), child: pill),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  const _BlobPainter(this.geometry, this.color, this.shadows, this.blur);

  final UiBlobGeometry geometry;
  final Color color;
  final List<BoxShadow> shadows;
  final double blur;

  @override
  void paint(Canvas canvas, Size size) {
    final path = uiBlobPath(geometry);
    for (final s in shadows) {
      canvas.drawPath(path.shift(s.offset), Paint()..color = s.color..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blurSigma));
    }
    final fill = Paint()..color = color;
    if (blur > 0.05) fill.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.geometry != geometry || old.color != color || old.blur != blur || old.shadows != shadows;
}

class _BlobClipper extends CustomClipper<Path> {
  const _BlobClipper(this.geometry);
  final UiBlobGeometry geometry;

  @override
  Path getClip(Size size) => uiBlobPath(geometry);

  @override
  bool shouldReclip(_BlobClipper old) => old.geometry != geometry;
}

/// The tone's mark in the badge: the same strokes as the web, on a 24 grid.
class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.tone, this.color);
  final UiToastTone tone;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final d = switch (tone) {
      UiToastTone.success => 'M5 12.5l4.5 4.5L19 7.5',
      UiToastTone.danger => 'M6.5 6.5l11 11M17.5 6.5l-11 11',
      UiToastTone.warning => 'M12 5v8.5M12 18.5v.01',
      UiToastTone.info => 'M12 10.5V19M12 5.5v.01',
    };
    canvas.scale(size.width / 24);
    canvas.drawPath(
      uiParseSvgPath(d),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.tone != tone || old.color != color;
}

/// Reports its child's size after layout, whenever it changes.
class _Measure extends SingleChildRenderObjectWidget {
  const _Measure({required this.onChange, required super.child});
  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasure(onChange);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasure renderObject) => renderObject.onChange = onChange;
}

class _RenderMeasure extends RenderProxyBox {
  _RenderMeasure(this.onChange);
  ValueChanged<Size> onChange;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _reported) return;
    _reported = size;
    final s = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => attached ? onChange(s) : null);
  }
}
