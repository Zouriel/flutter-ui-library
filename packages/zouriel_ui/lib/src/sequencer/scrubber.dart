import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';

/// A labelled section along a [UiScrubber], running from [at] to the next marker.
@immutable
class UiScrubberMarker {
  const UiScrubberMarker({required this.at, required this.label});
  final double at;
  final String label;
}

/// A layer drawn as a thin line along a [UiScrubber]: where it starts and ends.
@immutable
class UiScrubberLane {
  const UiScrubberLane({required this.start, required this.end, this.selected = false, this.muted = false});
  final double start;
  final double end;
  final bool selected;
  final bool muted;
}

/// A point of interest on a [UiScrubber], such as a keyframe.
@immutable
class UiScrubberTick {
  const UiScrubberTick({required this.at, this.active = false});
  final double at;

  /// Drawn filled, e.g. the keyframe under the playhead.
  final bool active;
}

/// Where [uiPackScrubberLanes] put each lane: [top] and the shared [height], both in percent of the
/// strip's inner height.
@immutable
class UiScrubberLaneRows {
  const UiScrubberLaneRows({required this.height, required this.tops});
  final double height;

  /// One per lane, in the order given.
  final List<double> tops;
}

/// Rows of lanes a scrubber draws before it starts reusing them.
const int _maxLaneRows = 6;

/// Packs lanes into as few rows as they need, the way a video editor stacks clips: a lane that
/// doesn't overlap another shares its row. At most six rows fit the strip readably; past that, rows
/// are reused in turn.
UiScrubberLaneRows uiPackScrubberLanes(List<UiScrubberLane> lanes) {
  final ends = <double>[];
  final rows = <int>[];
  for (final l in lanes) {
    var row = ends.indexWhere((end) => end <= l.start);
    if (row < 0) {
      row = ends.length;
      ends.add(l.end);
    } else {
      ends[row] = l.end;
    }
    rows.add(row);
  }
  final count = math.min(_maxLaneRows, math.max(1, ends.length));
  final height = math.min(30.0, 100 / count - (count > 1 ? 4 : 0));
  final gap = count > 1 ? (100 - height * count) / (count - 1) : 0.0;
  double top(int row) => count == 1 ? 50 - height / 2 : (row % count) * (height + gap);
  return UiScrubberLaneRows(height: height, tops: [for (final r in rows) top(r)]);
}

/// Below this speed (px per ms) a released drag stops instead of gliding.
const double _glideMin = 0.05;

/// How much speed a glide keeps per 16ms frame.
const double _glideDecay = 0.94;

/// A finger held this long without moving is a long press, not a scrub.
const Duration _longPress = Duration(milliseconds: 450);
const double _pressSlop = 8;

/// `ui-scrubber`: a strip that slides under a playhead fixed at its centre, the way mobile video
/// editors do it: the finger moves the content, never a tiny handle. Sections ([markers]) run along
/// it as labelled segments, [lanes] draw layers as thin stacked lines (a flattened timeline), and
/// [ticks] mark points of interest such as keyframes. Past [end], the strip is shaded.
///
/// Drag sideways to scrub; a flick glides and slows. Pinch with two fingers to zoom ([zoom] is
/// pixels per unit). With a mouse, drag or use the wheel. Holding still emits [onLongPress] (for
/// opening the full timeline) and puts the playhead back. As a slider it takes the arrow keys
/// (Shift for bigger steps), Page Up/Down and Home/End.
class UiScrubber extends StatefulWidget {
  const UiScrubber({
    super.key,
    required this.value,
    this.onChanged,
    this.length = 100,
    this.markers = const [],
    this.ticks = const [],
    this.lanes = const [],
    this.end,
    this.label = 'Position',
    this.valueText = '',
    this.zoom = 0.25,
    this.onZoomChanged,
    this.minZoom = 0.02,
    this.maxZoom = 4,
    this.onSettle,
    this.onLongPress,
  });

  /// Position under the playhead, 0 … [length].
  final double value;
  final ValueChanged<double>? onChanged;
  final double length;
  final List<UiScrubberMarker> markers;
  final List<UiScrubberTick> ticks;
  final List<UiScrubberLane> lanes;

  /// Where the content ends, when the strip runs on past it.
  final double? end;

  /// Accessible name of the slider.
  final String label;

  /// Spoken value; the rounded number when empty.
  final String valueText;

  /// Pixels per unit.
  final double zoom;
  final ValueChanged<double>? onZoomChanged;
  final double minZoom;
  final double maxZoom;

  /// Once, when a drag, glide, wheel or key change comes to rest.
  final ValueChanged<double>? onSettle;

  /// Held still (finger or mouse). The value is put back where it was.
  final VoidCallback? onLongPress;

  @override
  State<UiScrubber> createState() => _UiScrubberState();
}

class _UiScrubberState extends State<UiScrubber> with SingleTickerProviderStateMixin {
  late double _value = widget.value;
  late double _zoom = widget.zoom;
  bool _dragging = false;
  bool _pressing = false;
  bool _focused = false;

  // The gesture in progress.
  final Map<int, Offset> _down = {};
  double _origin = 0;
  bool _far = false;
  bool _pressFired = false;
  Timer? _pressTimer;
  Timer? _wheelTimer;

  // Scale callbacks: the baseline the current pointer count started from.
  int _pointers = 0;
  int _maxPointers = 0;
  double _startValue = 0;
  double _startZoom = 1;
  double _startFocalX = 0;
  double _baseScale = 1;

  late final Ticker _glide = createTicker(_glideTick);
  double _velocity = 0;
  Duration _lastTick = Duration.zero;

  @override
  void didUpdateWidget(UiScrubber old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) _value = widget.value;
    if (widget.zoom != old.zoom) _zoom = widget.zoom;
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    _wheelTimer?.cancel();
    _glide.dispose();
    super.dispose();
  }

  void _set(double v) {
    final next = v.clamp(0.0, widget.length).toDouble();
    if (next == _value) return;
    setState(() => _value = next);
    widget.onChanged?.call(next);
  }

  void _setZoom(double z) {
    final next = z.clamp(widget.minZoom, widget.maxZoom).toDouble();
    if (next == _zoom) return;
    setState(() => _zoom = next);
    widget.onZoomChanged?.call(next);
  }

  void _settle() {
    if (_dragging) setState(() => _dragging = false);
    widget.onSettle?.call(_value);
  }

  void _stopGlide() {
    if (_glide.isActive) _glide.stop();
  }

  void _clearPress() {
    _pressTimer?.cancel();
    _pressTimer = null;
    if (_pressing) setState(() => _pressing = false);
  }

  // ----- Raw pointers: the long press and the slop ------------------------------------------------

  void _onPointerDown(PointerDownEvent e) {
    _stopGlide();
    _down[e.pointer] = e.position;
    if (_down.length == 1) {
      _origin = _value;
      _far = false;
      _pressFired = false;
      setState(() {
        _dragging = true;
        _pressing = true;
      });
      _pressTimer?.cancel();
      _pressTimer = Timer(_longPress, _firePress);
    } else {
      _clearPress();
    }
  }

  void _firePress() {
    _pressTimer = null;
    if (!mounted) return;
    setState(() => _pressing = false);
    if (_far || _down.length != 1) return;
    _pressFired = true;
    _stopGlide();
    setState(() => _dragging = false);
    if (_value != _origin) {
      _value = _origin;
      widget.onChanged?.call(_origin);
    }
    widget.onLongPress?.call();
  }

  void _onPointerMove(PointerMoveEvent e) {
    final start = _down[e.pointer];
    if (start == null || _far) return;
    if ((e.position - start).distance > _pressSlop) {
      _far = true;
      _clearPress();
    }
  }

  void _onPointerUp(PointerEvent e) {
    _down.remove(e.pointer);
    if (_down.isEmpty) {
      _clearPress();
      // A tap or a long press: no scale gesture ran, so nothing else will settle it.
      if (_pointers == 0 && _dragging) _settle();
    }
  }

  // ----- Scale gesture: one finger scrubs, two pinch ----------------------------------------------

  void _rebase(int pointers, double focalX, double scale) {
    _pointers = pointers;
    _startValue = _value;
    _startZoom = _zoom;
    _startFocalX = focalX;
    _baseScale = scale == 0 ? 1 : scale;
  }

  void _onScaleStart(ScaleStartDetails d) {
    if (_pressFired) return;
    _rebase(d.pointerCount, d.focalPoint.dx, 1);
    _maxPointers = d.pointerCount;
    if (!_dragging) setState(() => _dragging = true);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_pressFired) return;
    if (d.pointerCount != _pointers) _rebase(d.pointerCount, d.focalPoint.dx, d.scale);
    _maxPointers = math.max(_maxPointers, d.pointerCount);
    if (d.pointerCount >= 2) {
      _setZoom(_startZoom * d.scale / _baseScale);
    } else {
      // Content follows the finger: dragging left moves forward.
      _set(_startValue - (d.focalPoint.dx - _startFocalX) / _zoom);
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    final wasPinch = _maxPointers >= 2;
    _pointers = 0;
    if (_pressFired) return;
    if (wasPinch) {
      _settle();
      return;
    }
    _release(d.velocity.pixelsPerSecond.dx / 1000);
  }

  /// A fast release glides on and slows; a slow one stops where it is.
  void _release(double velocity) {
    if (velocity.abs() < _glideMin || !context.uiAnimate) {
      _settle();
      return;
    }
    _velocity = velocity;
    _lastTick = Duration.zero;
    _glide.start();
  }

  void _glideTick(Duration elapsed) {
    final dt = math.min(48.0, (elapsed - _lastTick).inMicroseconds / 1000);
    _lastTick = elapsed;
    _set(_value - (_velocity * dt) / _zoom);
    _velocity *= math.pow(_glideDecay, dt / 16).toDouble();
    final atEdge = _value <= 0 || _value >= widget.length;
    if (_velocity.abs() < _glideMin || atEdge) {
      _glide.stop();
      _settle();
    }
  }

  // ----- Wheel and keys ---------------------------------------------------------------------------

  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      final s = event as PointerScrollEvent;
      final delta = s.scrollDelta.dx.abs() > s.scrollDelta.dy.abs() ? s.scrollDelta.dx : s.scrollDelta.dy;
      _set(_value + delta / _zoom);
      _wheelTimer?.cancel();
      _wheelTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted) widget.onSettle?.call(_value);
      });
    });
  }

  void _key(_ScrubKey k) {
    final small = widget.length / 100;
    final big = widget.length / 10;
    final next = switch (k) {
      _ScrubKey.up => _value + small,
      _ScrubKey.down => _value - small,
      _ScrubKey.bigUp => _value + big,
      _ScrubKey.bigDown => _value - big,
      _ScrubKey.home => 0.0,
      _ScrubKey.end => widget.length,
    };
    _set(next);
    widget.onSettle?.call(_value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final height = uiTouchPlatform(context) ? uiMinTouchTarget : 44.0;
    final r = BorderRadius.circular(theme.radius());
    final labelStyle = context.uiText.code.copyWith(fontSize: 11, fontWeight: FontWeight.w500, color: t.textSecondary);
    final sorted = [...widget.markers]..sort((a, b) => a.at.compareTo(b.at));

    final small = widget.length / 100;
    String spoken(double v) => v.round().toString();

    Widget strip = LayoutBuilder(builder: (context, c) {
      return CustomPaint(
        size: Size(c.maxWidth, height),
        painter: _ScrubberPainter(
          tokens: t,
          value: _value,
          zoom: _zoom,
          length: widget.length,
          markers: sorted,
          ticks: widget.ticks,
          lanes: widget.lanes,
          packing: uiPackScrubberLanes(widget.lanes),
          end: widget.end,
          labelStyle: labelStyle,
          pressing: _pressing,
          direction: Directionality.of(context),
        ),
      );
    });

    strip = Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      onPointerSignal: _onSignal,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: strip,
      ),
    );

    return Semantics(
      slider: true,
      label: widget.label,
      value: widget.valueText.isNotEmpty ? widget.valueText : spoken(_value),
      increasedValue: spoken(math.min(widget.length, _value + small)),
      decreasedValue: spoken(math.max(0, _value - small)),
      onIncrease: () => _key(_ScrubKey.up),
      onDecrease: () => _key(_ScrubKey.down),
      child: FocusableActionDetector(
        mouseCursor: _dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowRight): _ScrubIntent(_ScrubKey.up),
          SingleActivator(LogicalKeyboardKey.arrowUp): _ScrubIntent(_ScrubKey.up),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _ScrubIntent(_ScrubKey.down),
          SingleActivator(LogicalKeyboardKey.arrowDown): _ScrubIntent(_ScrubKey.down),
          SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): _ScrubIntent(_ScrubKey.bigUp),
          SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): _ScrubIntent(_ScrubKey.bigUp),
          SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): _ScrubIntent(_ScrubKey.bigDown),
          SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): _ScrubIntent(_ScrubKey.bigDown),
          SingleActivator(LogicalKeyboardKey.pageUp): _ScrubIntent(_ScrubKey.bigUp),
          SingleActivator(LogicalKeyboardKey.pageDown): _ScrubIntent(_ScrubKey.bigDown),
          SingleActivator(LogicalKeyboardKey.home): _ScrubIntent(_ScrubKey.home),
          SingleActivator(LogicalKeyboardKey.end): _ScrubIntent(_ScrubKey.end),
        },
        actions: {
          _ScrubIntent: CallbackAction<_ScrubIntent>(onInvoke: (i) {
            _key(i.key);
            return null;
          }),
        },
        child: ExcludeSemantics(
          child: Container(
            height: height,
            decoration: BoxDecoration(color: t.surfaceSubtle, borderRadius: r, boxShadow: _focused ? t.focusRing : null),
            child: ClipRRect(borderRadius: r, child: strip),
          ),
        ),
      ),
    );
  }
}

enum _ScrubKey { up, down, bigUp, bigDown, home, end }

class _ScrubIntent extends Intent {
  const _ScrubIntent(this.key);
  final _ScrubKey key;
}

class _ScrubberPainter extends CustomPainter {
  _ScrubberPainter({
    required this.tokens,
    required this.value,
    required this.zoom,
    required this.length,
    required this.markers,
    required this.ticks,
    required this.lanes,
    required this.packing,
    required this.end,
    required this.labelStyle,
    required this.pressing,
    required this.direction,
  });

  final UiTokens tokens;
  final double value, zoom, length;
  final List<UiScrubberMarker> markers;
  final List<UiScrubberTick> ticks;
  final List<UiScrubberLane> lanes;
  final UiScrubberLaneRows packing;
  final double? end;
  final TextStyle labelStyle;
  final bool pressing;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tokens;
    final offset = size.width / 2 - value * zoom;
    // The track sits 6px in from the top and bottom, like the web `.track`.
    const inset = 6.0;
    final top = inset, bottom = size.height - inset, trackH = bottom - top;
    double x(double units) => offset + units * zoom;

    if (pressing) canvas.saveLayer(Offset.zero & size, Paint()..color = t.text.withValues(alpha: 0.75));

    // Lanes: a flattened timeline, selected ones drawn last so they sit on top.
    final order = [for (var i = 0; i < lanes.length; i++) i]..sort((a, b) => (lanes[a].selected ? 1 : 0) - (lanes[b].selected ? 1 : 0));
    for (final i in order) {
      final l = lanes[i];
      final color = l.selected ? t.primary : uiMix(t.primary, 0.42, t.surface);
      final rect = Rect.fromLTWH(x(l.start), top + trackH * packing.tops[i] / 100, math.max(2, (l.end - l.start) * zoom), math.max(1.5, trackH * packing.height / 100));
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), Paint()..color = l.muted ? color.withValues(alpha: color.a * 0.35) : color);
    }

    // Beyond the end: hatched, with a dashed edge.
    final e = end;
    if (e != null && e < length) {
      final left = x(e);
      final right = x(length);
      final area = Rect.fromLTRB(left, 0, right, size.height);
      canvas.save();
      canvas.clipRect(area);
      final hatch = Paint()
        ..color = t.text.withValues(alpha: 0.06)
        ..strokeWidth = 3.5;
      for (var s = left - size.height; s < right; s += 10) {
        canvas.drawLine(Offset(s, size.height), Offset(s + size.height, 0), hatch);
      }
      canvas.restore();
      final dash = Paint()
        ..color = t.borderStrong
        ..strokeWidth = 1.5;
      for (var y = 0.0; y < size.height; y += 6) {
        canvas.drawLine(Offset(left + 0.75, y), Offset(left + 0.75, math.min(size.height, y + 3)), dash);
      }
    }

    // Sections.
    for (var i = 0; i < markers.length; i++) {
      final m = markers[i];
      final mEnd = i + 1 < markers.length ? markers[i + 1].at : length;
      if (mEnd <= m.at) continue;
      final rect = Rect.fromLTRB(x(m.at), top, x(mEnd), bottom);
      canvas.drawRect(rect, Paint()..color = uiMix(t.primary, i.isOdd ? 0.18 : 0.10, t.surface));
      canvas.drawRect(Rect.fromLTWH(rect.left, top, 1, trackH), Paint()..color = t.borderStrong);
      final maxW = rect.width - 10;
      if (maxW > 8) {
        final tp = TextPainter(
          text: TextSpan(text: m.label, style: labelStyle),
          textDirection: direction,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: maxW);
        // Labels ride the top half and ticks the bottom half, so a keyframe never sits on a section's name.
        tp.paint(canvas, Offset(rect.left + 6, top + 2));
        tp.dispose();
      }
    }

    // Ticks: small diamonds.
    for (final tick in ticks) {
      final c = Offset(x(tick.at), bottom - 7.5);
      final path = Path()
        ..moveTo(c.dx, c.dy - 6.4)
        ..lineTo(c.dx + 6.4, c.dy)
        ..lineTo(c.dx, c.dy + 6.4)
        ..lineTo(c.dx - 6.4, c.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = tick.active ? t.primary : t.surface);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = t.primary,
      );
    }

    if (pressing) canvas.restore();

    // Fades at both ends, so content slides out of view softly.
    const fade = 24.0;
    final clear = t.surfaceSubtle.withValues(alpha: 0);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, fade, size.height),
      Paint()..shader = LinearGradient(colors: [t.surfaceSubtle, clear]).createShader(Rect.fromLTWH(0, 0, fade, size.height)),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width - fade, 0, fade, size.height),
      Paint()..shader = LinearGradient(colors: [clear, t.surfaceSubtle]).createShader(Rect.fromLTWH(size.width - fade, 0, fade, size.height)),
    );

    // The playhead, fixed at the centre, with a halo so it reads over any section.
    final cx = size.width / 2;
    canvas.drawRect(Rect.fromLTWH(cx - 2, 0, 4, size.height), Paint()..color = t.surface.withValues(alpha: 0.7));
    canvas.drawRect(Rect.fromLTWH(cx - 1, 0, 2, size.height), Paint()..color = t.primary);
    canvas.drawPath(
      Path()
        ..moveTo(cx - 5, 0)
        ..lineTo(cx + 5, 0)
        ..lineTo(cx, 5)
        ..close(),
      Paint()..color = t.primary,
    );
  }

  @override
  bool shouldRepaint(_ScrubberPainter old) =>
      old.tokens != tokens ||
      old.value != value ||
      old.zoom != zoom ||
      old.length != length ||
      !listEquals(old.markers, markers) ||
      !listEquals(old.ticks, ticks) ||
      !listEquals(old.lanes, lanes) ||
      old.end != end ||
      old.pressing != pressing ||
      old.labelStyle != labelStyle;
}
