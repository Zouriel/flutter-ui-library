import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'motion.dart';

/// Fades [child]'s left and right edges to nothing (the web `mask-image` edge fade).
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.child, this.enabled = true, this.share = 0.08});
  final Widget child;
  final bool enabled;
  final double share;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    // Any opaque colour works as a mask; only its alpha matters.
    final solid = context.ui.text;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => LinearGradient(
        colors: [solid.withValues(alpha: 0), solid, solid, solid.withValues(alpha: 0)],
        stops: [0, share, 1 - share, 1],
      ).createShader(r),
      child: child,
    );
  }
}

/// The default [UiMarquee] separator: a small four-pointed sparkle in the primary colour (the web
/// `✦`), drawn rather than typed so it never depends on a font having the glyph.
class UiSparkle extends StatelessWidget {
  const UiSparkle({super.key, this.size = 12, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(size: Size.square(size), painter: _SparklePainter(color ?? context.ui.primary)),
      );
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final w = r * 0.28;
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + w * 0.4, c.dy - w * 0.4, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + w * 0.4, c.dy + w * 0.4, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - w * 0.4, c.dy + w * 0.4, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - w * 0.4, c.dy - w * 0.4, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}

/// `ui-marquee`: an endless sideways scroll of text [items] with faded edges. Alternate items step
/// back in colour (not opacity, so they keep their contrast). It pauses while hovered or pressed and
/// stands still under reduced motion. Screen readers read the items once; the separator and the
/// copy that makes the loop seamless are hidden from them.
class UiMarquee extends StatefulWidget {
  const UiMarquee({
    super.key,
    required this.items,
    this.duration = const Duration(seconds: 38),
    this.gap = 48,
    this.reverse = false,
    this.separator,
    this.style,
  });

  final List<String> items;

  /// One full loop.
  final Duration duration;
  final double gap;

  /// Scroll to the right instead.
  final bool reverse;

  /// Between items; defaults to a [UiSparkle].
  final Widget? separator;
  final TextStyle? style;

  @override
  State<UiMarquee> createState() => _UiMarqueeState();
}

class _UiMarqueeState extends State<UiMarquee> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  bool _held = false;

  void _sync() {
    final run = uiFxMotion(context) == UiFxMotion.full && !_held && widget.items.isNotEmpty;
    if (run && !_c.isAnimating) {
      _c.repeat();
    } else if (!run && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(UiMarquee old) {
    super.didUpdateWidget(old);
    if (old.duration != widget.duration) {
      _c.duration = widget.duration;
      if (_c.isAnimating) _c.repeat();
    }
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _hold(bool v) {
    _held = v;
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final width = MediaQuery.sizeOf(context).width;
    // clamp(1.1rem, 2.4vw, 1.9rem)
    final size = (width * 0.024).clamp(17.6, 30.4).toDouble();
    final base = context.uiText.h1.copyWith(fontSize: size, fontWeight: FontWeight.w500, height: 1.35, letterSpacing: 0).merge(widget.style);
    final sep = widget.separator ?? UiSparkle(size: size * 0.55);

    Widget track({required bool copy}) => Padding(
          padding: EdgeInsets.only(right: widget.gap),
          child: Row(mainAxisSize: MainAxisSize.min, spacing: widget.gap, children: [
            for (var i = 0; i < widget.items.length; i++)
              Row(mainAxisSize: MainAxisSize.min, spacing: t.space3, children: [
                Text(widget.items[i], style: base.copyWith(color: i.isOdd ? t.textMuted : t.text), maxLines: 1, softWrap: false),
                ExcludeSemantics(child: sep),
              ]),
          ]),
        );

    final row = Row(mainAxisSize: MainAxisSize.min, children: [track(copy: false), ExcludeSemantics(child: track(copy: true))]);

    return MouseRegion(
      onEnter: (_) => _hold(true),
      onExit: (_) => _hold(false),
      child: Listener(
        onPointerDown: (_) => _hold(true),
        onPointerUp: (_) => _hold(false),
        onPointerCancel: (_) => _hold(false),
        child: _EdgeFade(
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: double.infinity,
              fit: OverflowBoxFit.deferToChild,
              child: AnimatedBuilder(
                animation: _c,
                // Two identical tracks; sliding by half the row is one track, so the loop is seamless.
                builder: (context, child) => FractionalTranslation(
                  translation: Offset((widget.reverse ? _c.value - 1 : -_c.value) * 0.5, 0),
                  child: child,
                ),
                child: row,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Which way a [UiDriftRow] starts drifting.
enum UiDriftDirection { auto, left, right }

/// `ui-drift-row`: a horizontal rail that drifts on its own (to a random side by default,
/// ping-ponging at the ends) and stays scrollable and swipeable. It pauses while hovered, while
/// focus is inside (so a keyboard user's item never drifts away) and after any touch or scroll,
/// resuming [resumeDelay] after the last one. Under reduced motion it does not drift but still
/// scrolls. With [interactive] off it is a passive display: it drifts but ignores touches.
class UiDriftRow extends StatefulWidget {
  const UiDriftRow({
    super.key,
    required this.children,
    this.speed = 26,
    this.direction = UiDriftDirection.auto,
    this.gap = 24,
    this.pauseOnHover = true,
    this.resumeDelay = const Duration(milliseconds: 1800),
    this.fade = true,
    this.interactive = true,
  });

  final List<Widget> children;

  /// Logical pixels per second.
  final double speed;
  final UiDriftDirection direction;
  final double gap;
  final bool pauseOnHover;
  final Duration resumeDelay;

  /// Fade the edges when the rail overflows.
  final bool fade;
  final bool interactive;

  @override
  State<UiDriftRow> createState() => _UiDriftRowState();
}

class _UiDriftRowState extends State<UiDriftRow> with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late final Ticker _ticker = createTicker(_tick);
  late double _dir = switch (widget.direction) {
    UiDriftDirection.left => -1,
    UiDriftDirection.right => 1,
    UiDriftDirection.auto => math.Random().nextBool() ? 1 : -1,
  };
  Duration _last = Duration.zero;

  /// Float position: sub-pixel drift would otherwise round to nothing.
  double _pos = 0;
  bool _hovering = false;
  bool _focused = false;
  bool _touching = false;

  /// When the user last touched or scrolled it. Compared inside the tick rather than restarted as a
  /// timer, so a drift that is paused by polling can always resume.
  DateTime? _lastTouch;
  bool _overflowing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final drift = uiFxMotion(context) == UiFxMotion.full;
    if (drift && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!drift && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _paused {
    if (_touching || _focused || (widget.pauseOnHover && _hovering)) return true;
    final at = _lastTouch;
    return at != null && DateTime.now().difference(at) < widget.resumeDelay;
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero ? 0.0 : math.min(0.05, (now - _last).inMicroseconds / 1e6);
    _last = now;
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final max = p.maxScrollExtent;
    final over = max > 1;
    if (over != _overflowing) setState(() => _overflowing = over);
    if (!over) return;
    // While paused, follow wherever the user left it, so the drift picks up from there.
    if (_paused) {
      _pos = p.pixels;
      return;
    }
    _pos += _dir * widget.speed * dt;
    if (_pos <= 0) {
      _pos = 0;
      _dir = 1;
    } else if (_pos >= max) {
      _pos = max;
      _dir = -1;
    }
    p.jumpTo(_pos);
  }

  @override
  Widget build(BuildContext context) {
    // No scrollbar (as on the web): on desktop it would sit over the cards' bottom edges.
    Widget rail = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        physics: widget.interactive ? null : const NeverScrollableScrollPhysics(),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: widget.gap, children: widget.children),
      ),
    );
    rail = NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // A scroll the user drove (not our own jumps) pauses the drift.
        if (n is ScrollUpdateNotification && n.dragDetails != null) _lastTouch = DateTime.now();
        return false;
      },
      child: rail,
    );
    if (!widget.interactive) {
      rail = IgnorePointer(child: rail);
    } else {
      rail = MouseRegion(
        onEnter: (_) => _hovering = true,
        onExit: (_) => _hovering = false,
        child: Listener(
          onPointerDown: (_) {
            _touching = true;
            _lastTouch = DateTime.now();
          },
          onPointerUp: (_) {
            _touching = false;
            _lastTouch = DateTime.now();
          },
          onPointerCancel: (_) => _touching = false,
          onPointerSignal: (_) => _lastTouch = DateTime.now(),
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onFocusChange: (f) => _focused = f,
            child: rail,
          ),
        ),
      );
    }
    return _EdgeFade(enabled: widget.fade && _overflowing, share: 0.06, child: rail);
  }
}

