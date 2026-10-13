import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../behaviors/intersect.dart';
import '../theme/theme.dart';

/// The "dramatic" ease the FX use: a fast start that settles slowly (`cubic-bezier(.16,1,.3,1)`).
const Curve uiEaseDramatic = Cubic(0.16, 1, 0.3, 1);

/// How an effect should move right now.
enum UiFxMotion {
  /// Full motion.
  full,

  /// The OS asks for reduced motion: entrance effects still play, softened.
  calm,

  /// The library config turned animations off: show the end state at once.
  none,
}

/// Full, calm (OS reduced motion) or none (library animations off).
UiFxMotion uiFxMotion(BuildContext context) {
  if (!context.uiTheme.config.animations) return UiFxMotion.none;
  return (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? UiFxMotion.calm : UiFxMotion.full;
}

/// Entrance styles for [UiReveal], the web `UiRevealMode`.
enum UiRevealMode { up, down, left, right, blur, scale }

/// `uiReveal`: fades [child] in as it scrolls into view. [threshold] of it must be on screen (the
/// bottom 8% of the screen does not count, so it reveals a little after it peeks in). With [once]
/// off it hides again on leaving.
///
/// Under reduced motion it still fades in, but only from a 6px lift (no slide, scale or blur); with
/// the library's animations off it simply shows.
class UiReveal extends StatefulWidget {
  const UiReveal({
    super.key,
    required this.child,
    this.mode = UiRevealMode.up,
    this.delay = Duration.zero,
    this.threshold = 0.18,
    this.once = true,
    this.duration = const Duration(milliseconds: 900),
  });

  final Widget child;
  final UiRevealMode mode;
  final Duration delay;
  final double threshold;
  final bool once;
  final Duration duration;

  @override
  State<UiReveal> createState() => _UiRevealState();
}

class _UiRevealState extends State<UiReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  bool _shown = false;

  Future<void> _show(bool visible) async {
    if (!mounted) return;
    if (uiFxMotion(context) == UiFxMotion.none) {
      _c.value = visible || (widget.once && _shown) ? 1 : 0;
      _shown |= visible;
      return;
    }
    if (visible) {
      _shown = true;
      if (widget.delay > Duration.zero) await Future<void>.delayed(widget.delay);
      if (mounted) _c.forward();
    } else if (!widget.once) {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calm = uiFxMotion(context) == UiFxMotion.calm;
    return UiIntersect(
      threshold: widget.threshold,
      once: widget.once,
      rootMargin: EdgeInsets.only(bottom: -MediaQuery.sizeOf(context).height * 0.08),
      onChange: _show,
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final v = uiEaseDramatic.transform(_c.value);
          final rest = 1 - v;
          Offset shift;
          var scale = 1.0;
          var blur = 0.0;
          if (calm) {
            shift = Offset(0, 6 * rest);
          } else {
            switch (widget.mode) {
              case UiRevealMode.up:
                shift = Offset(0, 28 * rest);
              case UiRevealMode.down:
                shift = Offset(0, -28 * rest);
              case UiRevealMode.left:
                shift = Offset(-40 * rest, 0);
              case UiRevealMode.right:
                shift = Offset(40 * rest, 0);
              case UiRevealMode.blur:
                shift = Offset(0, 20 * rest);
                blur = 18 * rest;
              case UiRevealMode.scale:
                shift = Offset.zero;
                scale = 0.94 + 0.06 * v;
            }
          }
          Widget out = Transform.translate(offset: shift, child: Transform.scale(scale: scale, child: child));
          // CSS blur(18px) is a radius; a Gaussian sigma of about half looks the same.
          if (blur > 0.1) out = ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: blur / 2, sigmaY: blur / 2), child: out);
          return Opacity(opacity: v.clamp(0.0, 1.0), child: out);
        },
      ),
    );
  }
}

/// `uiSplitText`: [text] whose letters rise in one after another, for a headline. Words never
/// break, so it still wraps between words. Screen readers hear the whole text once.
///
/// Under reduced motion it still plays, as a fade with a small lift and no rotation; with the
/// library's animations off it shows at once.
class UiSplitText extends StatefulWidget {
  const UiSplitText(
    this.text, {
    super.key,
    this.style,
    this.stagger = const Duration(milliseconds: 35),
    this.base = const Duration(milliseconds: 120),
    this.duration = const Duration(milliseconds: 900),
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle? style;

  /// Delay between letters.
  final Duration stagger;

  /// Delay before the first letter.
  final Duration base;

  /// Each letter's own animation.
  final Duration duration;
  final TextAlign textAlign;

  @override
  State<UiSplitText> createState() => _UiSplitTextState();
}

class _UiSplitTextState extends State<UiSplitText> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late List<String> _words;
  int _letters = 0;

  Duration get _total => widget.base + widget.stagger * math.max(0, _letters - 1) + widget.duration;

  void _split() {
    _words = widget.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    _letters = _words.fold(0, (n, w) => n + w.characters.length);
  }

  @override
  void initState() {
    super.initState();
    _split();
    _c = AnimationController(vsync: this, duration: _total);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (uiFxMotion(context) == UiFxMotion.none) {
      _c.value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void didUpdateWidget(UiSplitText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _split();
      _c.duration = _total;
      if (uiFxMotion(context) == UiFxMotion.none) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final calm = uiFxMotion(context) == UiFxMotion.calm;
    final em = style.fontSize ?? 14;
    final totalMs = math.max(1, _total.inMicroseconds);
    var i = 0;
    final words = <Widget>[];
    for (final w in _words) {
      final letters = <Widget>[];
      for (final ch in w.characters) {
        final start = (widget.base + widget.stagger * i).inMicroseconds / totalMs;
        final end = math.min(1.0, start + widget.duration.inMicroseconds / totalMs);
        final a = CurvedAnimation(parent: _c, curve: Interval(start, end, curve: uiEaseDramatic));
        letters.add(AnimatedBuilder(
          animation: a,
          builder: (context, child) {
            final rest = 1 - a.value;
            return Opacity(
              opacity: a.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (calm ? 0.2 : 0.9) * em * rest),
                child: Transform.rotate(angle: calm ? 0 : 8 * math.pi / 180 * rest, child: child),
              ),
            );
          },
          child: Text(ch, style: style),
        ));
        i++;
      }
      words.add(Row(mainAxisSize: MainAxisSize.min, children: letters));
    }
    final space = (TextPainter(text: TextSpan(text: ' ', style: style), textDirection: TextDirection.ltr)..layout()).width;
    return Semantics(
      label: widget.text.trim(),
      child: ExcludeSemantics(
        child: Wrap(
          spacing: space,
          alignment: switch (widget.textAlign) {
            TextAlign.center => WrapAlignment.center,
            TextAlign.end || TextAlign.right => WrapAlignment.end,
            _ => WrapAlignment.start,
          },
          children: words,
        ),
      ),
    );
  }
}

/// `uiMagnetic`, for touch: [child] tilts toward the finger while pressed and springs back on
/// release (on a phone there is no cursor to pull toward). With a mouse it drifts toward the
/// pointer while hovered, like the web. [strength] is how far it follows (0–1). Off under reduced
/// motion. Taps still reach the child.
class UiMagnetic extends StatefulWidget {
  const UiMagnetic({super.key, required this.child, this.strength = 0.35, this.maxTilt = 10});

  final Widget child;
  final double strength;

  /// The steepest tilt at full [strength], in degrees.
  final double maxTilt;

  @override
  State<UiMagnetic> createState() => _UiMagneticState();
}

class _UiMagneticState extends State<UiMagnetic> {
  Offset _pull = Offset.zero;

  /// -1..1 across each axis from the centre, while pressed.
  Offset _tilt = Offset.zero;
  bool _active = false;

  Offset _rel(Offset local) {
    final s = context.size ?? Size.zero;
    if (s.isEmpty) return Offset.zero;
    return Offset((local.dx / s.width * 2 - 1).clamp(-1.0, 1.0), (local.dy / s.height * 2 - 1).clamp(-1.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final on = uiFxMotion(context) == UiFxMotion.full;
    if (!on) return widget.child;
    final deg = widget.maxTilt * widget.strength * math.pi / 180;
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0015)
      ..translateByDouble(_pull.dx, _pull.dy, 0, 1)
      // Pressing a side pushes it away from you, as on a physical card.
      ..rotateX(_tilt.dy * deg)
      ..rotateY(-_tilt.dx * deg);
    return MouseRegion(
      onHover: (e) {
        if (e.kind != PointerDeviceKind.mouse) return;
        final s = context.size ?? Size.zero;
        setState(() {
          _active = true;
          _pull = (e.localPosition - s.center(Offset.zero)) * widget.strength;
        });
      },
      onExit: (_) => setState(() {
        _active = false;
        _pull = Offset.zero;
      }),
      child: Listener(
        onPointerDown: (e) {
          if (e.kind == PointerDeviceKind.mouse) return;
          setState(() {
            _active = true;
            _tilt = _rel(e.localPosition);
          });
        },
        onPointerMove: (e) {
          if (e.kind == PointerDeviceKind.mouse) return;
          setState(() => _tilt = _rel(e.localPosition));
        },
        onPointerUp: (_) => setState(() {
          _active = false;
          _tilt = Offset.zero;
        }),
        onPointerCancel: (_) => setState(() {
          _active = false;
          _tilt = Offset.zero;
        }),
        child: AnimatedContainer(
          // Follows the finger quickly; springs back over 350 ms.
          duration: Duration(milliseconds: _active ? 120 : 350),
          curve: uiEaseDramatic,
          transform: m,
          transformAlignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}
