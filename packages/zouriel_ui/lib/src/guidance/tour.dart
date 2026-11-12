import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';
import 'guidance.dart';

/// Which side of its anchor a tour step's bubble prefers (the web `UiTourPlacement`); [auto] is
/// below, else above. [start] and [end] follow the text direction.
enum UiTourPlacement { auto, top, bottom, start, end }

/// One step of a tour (the web `UiTourStep`).
@immutable
class UiTourStep {
  const UiTourStep(this.anchor, this.text, {this.title, this.placement = UiTourPlacement.auto});

  /// The [UiTourAnchor.id] of the widget this step points at.
  final String anchor;

  /// Short text (about 20 words at most).
  final String text;

  /// Optional, about 6 words at most.
  final String? title;
  final UiTourPlacement placement;
}

/// Words for one tour, over the built-in strings ([UiStrings.tourNext], …). [step] takes `{n}` and
/// `{total}`.
@immutable
class UiTourLabels {
  const UiTourLabels({this.back, this.next, this.done, this.skip, this.turnOff, this.step});
  final String? back, next, done, skip, turnOff, step;
}

/// A tour (the web `UiTourSpec`): 1 to 5 [steps] (more are cut to 5 with a debug warning).
@immutable
class UiTourSpec {
  const UiTourSpec(this.id, this.steps, {this.labels, this.turnOff = true});
  final String id;
  final List<UiTourStep> steps;
  final UiTourLabels? labels;

  /// Show "Turn off tips".
  final bool turnOff;
}

/// At most this many steps in a tour (NN/g: longer tours aren't read).
const int uiTourMaxSteps = 5;

/// Room between the anchor and the cut-out's edge.
const double _kPad = 6;

/// Cut-out to bubble (the arrow plus a breath).
const double _kGap = 12;

/// The bubble keeps this far from the screen's edges.
const double _kMargin = 12;

/// How far the arrow (a 12px square turned 45 degrees, half outside) sticks out.
const double _kArrow = 8.5;

/// `uiTourAnchor`: marks [child] as a tour step's target by a shared [id]. Several widgets may
/// share an id; the first one laid out with a size wins.
class UiTourAnchor extends StatefulWidget {
  const UiTourAnchor({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<UiTourAnchor> createState() => _UiTourAnchorState();
}

final Map<String, Set<_UiTourAnchorState>> _anchors = {};

class _UiTourAnchorState extends State<UiTourAnchor> {
  @override
  void initState() {
    super.initState();
    (_anchors[widget.id] ??= {}).add(this);
  }

  @override
  void didUpdateWidget(UiTourAnchor old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      _remove(old.id);
      (_anchors[widget.id] ??= {}).add(this);
    }
  }

  void _remove(String id) {
    final set = _anchors[id];
    set?.remove(this);
    if (set != null && set.isEmpty) _anchors.remove(id);
  }

  @override
  void dispose() {
    _remove(widget.id);
    super.dispose();
  }

  RenderBox? get box {
    if (!mounted) return null;
    final r = context.findRenderObject();
    if (r is! RenderBox || !r.attached || !r.hasSize || r.size.isEmpty) return null;
    return r;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

_UiTourAnchorState? _findAnchor(String id) {
  for (final a in _anchors[id] ?? const <_UiTourAnchorState>{}) {
    if (a.box != null) return a;
  }
  return null;
}

/// Starts tours (the web `UiTourService`). [start] dims the screen, cuts a rounded hole around each
/// step's anchor and shows a coach-mark bubble beside it, and completes with how it ended.
abstract final class UiTour {
  static _UiTourViewState? _view;
  static String? _active;
  static void Function(UiTourOutcome)? _stopCurrent;

  /// The id of the tour on screen, or null.
  static String? get active => _active;

  /// Whether a widget with this anchor id is laid out with a size.
  static bool hasAnchor(String id) => _findAnchor(id) != null;

  /// The cut-out as drawn now, in the overlay's coordinates (tests).
  @visibleForTesting
  static Rect? get debugHole => _view?._shown;

  /// Runs a tour. Steps whose anchor isn't laid out are left out (the count says "1 of 3" when one
  /// of four is missing); with none left it completes [UiTourOutcome.closed] at once. A tour
  /// already running ends with [UiTourOutcome.closed] first.
  static Future<UiTourOutcome> start(BuildContext context, UiTourSpec spec) {
    _stopCurrent?.call(UiTourOutcome.closed);
    var steps = spec.steps;
    if (steps.length > uiTourMaxSteps) {
      debugPrint('UiTour "${spec.id}": ${steps.length} steps; a tour has at most $uiTourMaxSteps, the rest are left out.');
      steps = steps.sublist(0, uiTourMaxSteps);
    }
    steps = [for (final s in steps) if (_findAnchor(s.anchor) != null) s];
    if (steps.isEmpty) return Future.value(UiTourOutcome.closed);

    final overlay = Overlay.of(context, rootOverlay: true);
    final completer = Completer<UiTourOutcome>();
    final restore = FocusManager.instance.primaryFocus;
    late final OverlayEntry entry;
    var done = false;
    void end(UiTourOutcome outcome) {
      if (done) return;
      done = true;
      entry.remove();
      entry.dispose();
      _active = null;
      _stopCurrent = null;
      if (restore != null && restore.context != null && restore.canRequestFocus) restore.requestFocus();
      completer.complete(outcome);
    }

    entry = OverlayEntry(builder: (_) => _UiTourView(spec: spec, steps: steps, onEnd: end));
    _stopCurrent = end;
    _active = spec.id;
    overlay.insert(entry);
    return completer.future;
  }

  /// Ends the running tour with [UiTourOutcome.closed] (e.g. the page is leaving).
  static void stop() => _stopCurrent?.call(UiTourOutcome.closed);
}

class _UiTourView extends StatefulWidget {
  const _UiTourView({required this.spec, required this.steps, required this.onEnd});

  final UiTourSpec spec;
  final List<UiTourStep> steps;
  final void Function(UiTourOutcome) onEnd;

  @override
  State<_UiTourView> createState() => _UiTourViewState();
}

class _UiTourViewState extends State<_UiTourView> with TickerProviderStateMixin {
  int _index = 0;
  bool _ready = false;
  _UiTourAnchorState? _anchor;

  /// Where the anchor's cut-out belongs now, and where it is drawn (they differ while it moves).
  Rect? _target;
  Rect? _shown;
  Rect? _from;
  late final AnimationController _move = AnimationController(vsync: this);
  late final AnimationController _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  final FocusNode _next = FocusNode(debugLabel: 'UiTour next');
  final _BubbleGeometry _geometry = _BubbleGeometry();
  Timer? _settle;
  bool _calm = false;

  @override
  void initState() {
    super.initState();
    UiTour._view = this;
    HardwareKeyboard.instance.addHandler(_onKey);
    _move.addListener(_layout);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _watch();
      _show(0, 1);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = !context.uiAnimate;
    _move.duration = context.ui.motionSlow;
    if (_calm) {
      _ring.stop();
      _ring.value = 0;
    } else if (!_ring.isAnimating) {
      _ring.repeat();
    }
  }

  @override
  void dispose() {
    if (UiTour._view == this) UiTour._view = null;
    HardwareKeyboard.instance.removeHandler(_onKey);
    _settle?.cancel();
    _move.dispose();
    _ring.dispose();
    _next.dispose();
    _geometry.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
      _finish(UiTourOutcome.closed);
      return true;
    }
    return false;
  }

  void _finish(UiTourOutcome o) => widget.onEnd(o);

  bool get _last => _index == widget.steps.length - 1;

  /// Back (-1) or Next/Done (1).
  void _go(int dir) {
    if (dir == 1 && _last) return _finish(UiTourOutcome.finished);
    _show(_index + dir, dir);
  }

  /// Shows step [i], or the next one along [dir] whose anchor is still laid out.
  void _show(int i, int dir) {
    final steps = widget.steps;
    while (i >= 0 && i < steps.length && _findAnchor(steps[i].anchor) == null) {
      i += dir;
    }
    if (i < 0) i = _index;
    // Past the last step still on the page: the tour was gone through to its end.
    if (i >= steps.length) return _finish(UiTourOutcome.finished);
    final anchor = _findAnchor(steps[i].anchor)!;
    final moving = _shown != null && !_calm;
    setState(() {
      _index = i;
      _anchor = anchor;
      _ready = false;
    });
    if (moving) {
      _from = _shown;
      _move.forward(from: 0);
    }
    final me = context.findRenderObject() as RenderBox?;
    final r = _anchorRect();
    final inView = me != null && r != null && (Offset.zero & me.size).contains(r.topLeft) && (Offset.zero & me.size).contains(r.bottomRight - const Offset(0.01, 0.01));
    if (!inView) {
      Scrollable.ensureVisible(
        anchor.context,
        alignment: 0.5,
        duration: _calm ? Duration.zero : context.ui.motionSlow,
        curve: context.ui.easeStandard,
      );
    }
    _layout();
    // Wait for the scroll to settle (the anchor's box stops moving), then show the bubble.
    String last = '';
    var still = 0;
    var waited = Duration.zero;
    void check() {
      final b = _anchorRect();
      final key = b == null ? '' : '${b.left.round()},${b.top.round()},${b.width.round()},${b.height.round()}';
      still = key == last ? still + 1 : 0;
      last = key;
      if (still >= 2 || waited > const Duration(milliseconds: 900)) {
        _settle = null;
        _reveal();
      } else {
        waited += const Duration(milliseconds: 50);
        _settle = Timer(const Duration(milliseconds: 50), check);
      }
    }

    _settle?.cancel();
    _settle = Timer(inView ? Duration.zero : const Duration(milliseconds: 50), check);
  }

  void _reveal() {
    if (!mounted) return;
    _layout();
    setState(() => _ready = true);
    final s = widget.steps[_index];
    final text = s.title != null ? '${s.title}. ${s.text}' : s.text;
    final strings = context.uiStrings;
    SemanticsService.sendAnnouncement(
      View.of(context),
      uiFormatString(strings.tourStepAnnounce, {'n': _index + 1, 'total': widget.steps.length, 'text': text}),
      Directionality.of(context),
    );
    // Focus the main button once it is drawn; the scope keeps Tab inside the bubble.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _next.requestFocus();
    });
  }

  Rect? _anchorRect() {
    final box = _anchor?.box;
    final me = mounted ? context.findRenderObject() : null;
    if (box == null || me is! RenderBox || !me.hasSize) return null;
    final tl = me.globalToLocal(box.localToGlobal(Offset.zero));
    return tl & box.size;
  }

  /// Follows the anchor after every frame (a scroll, a resize, the anchor moving), without asking
  /// for frames of its own while nothing moves.
  void _watch() {
    if (!mounted) return;
    _layout();
    WidgetsBinding.instance.addPostFrameCallback((_) => _watch());
  }

  /// Puts the cut-out on the anchor (the bubble is placed by its layout delegate).
  void _layout() {
    if (!mounted) return;
    final r = _anchorRect();
    if (r == null) return;
    final target = r.inflate(_kPad);
    final shown = _move.isAnimating && _from != null ? Rect.lerp(_from, target, context.ui.easeStandard.transform(_move.value))! : target;
    if (shown != _shown || target != _target) {
      setState(() {
        _target = target;
        _shown = shown;
      });
    }
  }

  String _label(String? own, String fallback) => own ?? fallback;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final strings = context.uiStrings;
    final labels = widget.spec.labels;
    final step = widget.steps[_index];
    final count = uiFormatString(labels?.step ?? strings.tourStep, {'n': _index + 1, 'total': widget.steps.length});
    final mq = MediaQuery.of(context);
    final safe = EdgeInsets.fromLTRB(
      mq.padding.left + _kMargin,
      mq.padding.top + _kMargin,
      mq.padding.right + _kMargin,
      mq.padding.bottom + _kMargin,
    );
    final hole = _shown;
    final target = _target;
    Widget bubble = _TourBubble(
      count: count,
      title: step.title,
      text: step.text,
      first: _index == 0,
      last: _last,
      turnOff: widget.spec.turnOff,
      labels: (
        back: _label(labels?.back, strings.tourBack),
        next: _label(labels?.next, strings.tourNext),
        done: _label(labels?.done, strings.tourDone),
        skip: _label(labels?.skip, strings.tourSkip),
        turnOff: _label(labels?.turnOff, strings.tipsOff),
      ),
      nextFocus: _next,
      geometry: _geometry,
      onBack: () => _go(-1),
      onNext: () => _go(1),
      onSkip: () => _finish(UiTourOutcome.skipped),
      onTurnOff: () => _finish(UiTourOutcome.turnedOff),
    );
    if (_ready && !_calm) {
      bubble = TweenAnimationBuilder<double>(
        key: ValueKey(_index),
        tween: Tween(begin: 0, end: 1),
        duration: t.motionBase,
        curve: t.easeDecelerate,
        builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 4 * (1 - v)), child: child)),
        child: bubble,
      );
    }
    if (!_ready) bubble = IgnorePointer(child: ExcludeSemantics(child: Opacity(opacity: 0, child: bubble)));
    return BlockSemantics(
      child: Stack(fit: StackFit.expand, children: [
        // Takes every touch: the page behind is not usable while a tour is on.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: () {},
          child: AnimatedBuilder(
            animation: _ring,
            builder: (context, _) => CustomPaint(
              painter: _ScrimPainter(
                hole: hole,
                radius: theme.radius(t.radiusLg),
                scrim: t.overlay,
                ring: t.primary,
                breath: _calm ? 0 : math.sin(_ring.value * math.pi),
              ),
            ),
          ),
        ),
        if (target != null)
          CustomSingleChildLayout(
            delegate: _BubbleLayout(
              hole: target,
              placement: step.placement,
              rtl: Directionality.of(context) == TextDirection.rtl,
              safe: safe,
              geometry: _geometry,
            ),
            child: FocusScope(
              autofocus: true,
              child: Semantics(scopesRoute: true, namesRoute: true, explicitChildNodes: true, label: count, child: bubble),
            ),
          ),
      ]),
    );
  }
}

/// The dimmed layer with a rounded hole, and a breathing ring round the hole.
class _ScrimPainter extends CustomPainter {
  _ScrimPainter({required this.hole, required this.radius, required this.scrim, required this.ring, required this.breath});

  final Rect? hole;
  final double radius;
  final Color scrim, ring;

  /// 0..1: the ring fades to 55% and grows 3% at 1.
  final double breath;

  @override
  void paint(Canvas canvas, Size size) {
    final h = hole;
    final path = Path()..fillType = PathFillType.evenOdd;
    path.addRect(Offset.zero & size);
    if (h != null) path.addRRect(RRect.fromRectAndRadius(h, Radius.circular(radius)));
    canvas.drawPath(path, Paint()..color = scrim);
    if (h == null) return;
    final grow = 1 + 0.03 * breath;
    final ringRect = Rect.fromCenter(center: h.center, width: (h.width + 2) * grow, height: (h.height + 2) * grow);
    canvas.drawRRect(
      RRect.fromRectAndRadius(ringRect, Radius.circular(radius + 1)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ring.withValues(alpha: ring.a * (1 - 0.45 * breath)),
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.hole != hole || old.radius != radius || old.scrim != scrim || old.ring != ring || old.breath != breath;
}

enum _Side { top, bottom, left, right, none }

/// The side the bubble ended up on and the anchor centre's offset along it, written during layout
/// and read when painting the arrow.
class _BubbleGeometry extends ChangeNotifier {
  _Side side = _Side.bottom;
  double arrow = 24;

  void set(_Side s, double a) {
    if (s == side && a == arrow) return;
    side = s;
    arrow = a;
    // Layout is running; repaint after it.
    SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }
}

/// Places the bubble beside the cut-out, inside the screen: the web tour's `layout()`.
class _BubbleLayout extends SingleChildLayoutDelegate {
  _BubbleLayout({required this.hole, required this.placement, required this.rtl, required this.safe, required this.geometry});

  final Rect hole;
  final UiTourPlacement placement;
  final bool rtl;
  final EdgeInsets safe;
  final _BubbleGeometry geometry;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final w = math.min(320.0, constraints.maxWidth - 24);
    return BoxConstraints(minWidth: w, maxWidth: w, maxHeight: math.max(0, constraints.maxHeight - safe.vertical));
  }

  @override
  Offset getPositionForChild(Size size, Size child) {
    final bw = child.width, bh = child.height;
    final area = safe.deflateRect(Offset.zero & size);
    final room = {
      _Side.top: hole.top - _kGap - area.top,
      _Side.bottom: area.bottom - hole.bottom - _kGap,
      _Side.left: hole.left - _kGap - area.left,
      _Side.right: area.right - hole.right - _kGap,
    };
    bool fits(_Side s) => room[s]! >= (s == _Side.top || s == _Side.bottom ? bh : bw);
    final start = rtl ? _Side.right : _Side.left;
    final end = rtl ? _Side.left : _Side.right;
    final order = switch (placement) {
      UiTourPlacement.top => [_Side.top, _Side.bottom],
      UiTourPlacement.start => [start, end, _Side.bottom, _Side.top],
      UiTourPlacement.end => [end, start, _Side.bottom, _Side.top],
      _ => [_Side.bottom, _Side.top],
    };
    final side = order.firstWhere(fits, orElse: () => _Side.none);
    double clamp(double v, double lo, double hi) => v.clamp(lo, math.max(lo, hi)).toDouble();
    final cx = hole.center.dx, cy = hole.center.dy;
    double x, y, arrow = 24;
    switch (side) {
      case _Side.top || _Side.bottom:
        x = clamp(cx - bw / 2, area.left, area.right - bw);
        y = side == _Side.bottom ? hole.bottom + _kGap : hole.top - _kGap - bh;
        arrow = clamp(cx - x, 18, bw - 18);
      case _Side.left || _Side.right:
        x = side == _Side.right ? hole.right + _kGap : hole.left - _kGap - bw;
        y = clamp(cy - bh / 2, area.top, area.bottom - bh);
        arrow = clamp(cy - y, 18, bh - 18);
      case _Side.none:
        // No side has room (a tall anchor on a phone): over the page, on the half away from it.
        x = clamp(cx - bw / 2, area.left, area.right - bw);
        y = cy > size.height / 2 ? area.top : area.bottom - bh;
    }
    x = clamp(x, area.left, area.right - bw);
    y = clamp(y, area.top, area.bottom - bh);
    geometry.set(side, arrow);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_BubbleLayout old) =>
      old.hole != hole || old.placement != placement || old.rtl != rtl || old.safe != safe;
}

typedef _TourWords = ({String back, String next, String done, String skip, String turnOff});

/// The coach-mark bubble: primary fill, contrast text, an arrow at the anchor.
class _TourBubble extends StatelessWidget {
  const _TourBubble({
    required this.count,
    required this.title,
    required this.text,
    required this.first,
    required this.last,
    required this.turnOff,
    required this.labels,
    required this.nextFocus,
    required this.geometry,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
    required this.onTurnOff,
  });

  final String count;
  final String? title;
  final String text;
  final bool first, last, turnOff;
  final _TourWords labels;
  final FocusNode nextFocus;
  final _BubbleGeometry geometry;
  final VoidCallback onBack, onNext, onSkip, onTurnOff;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final fg = t.primaryContrast;
    final base = theme.typography.body.copyWith(color: fg, height: 1.45);
    final small = base.copyWith(fontSize: t.fontSizeSm);
    final body = base.copyWith(fontSize: t.fontSizeMd);
    return CustomPaint(
      foregroundPainter: _ArrowPainter(geometry, t.primary),
      child: DecoratedBox(
        decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(theme.radius(t.radiusLg)), boxShadow: t.shadow3),
        child: Padding(
          padding: EdgeInsets.fromLTRB(t.space4, t.space3, t.space4, t.space3),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Text(count, style: small.copyWith(fontWeight: FontWeight.w600, letterSpacing: t.trackingWide, color: fg.withValues(alpha: 0.85), fontFeatures: const [FontFeature.tabularFigures()])),
                ),
              ),
              _TextAction(label: labels.skip, onTap: onSkip, style: small),
            ]),
            if (title != null) ...[
              SizedBox(height: t.space2),
              Text(title!, style: body.copyWith(fontWeight: FontWeight.w600, height: 1.3)),
            ],
            SizedBox(height: t.space2),
            Text(text, style: body),
            SizedBox(height: t.space2 + t.space1),
            Row(children: [
              if (turnOff) Flexible(child: _TextAction(label: labels.turnOff, onTap: onTurnOff, style: small, underline: true)),
              const Spacer(),
              if (!first) ...[
                _Pill(label: labels.back, onTap: onBack, filled: false),
                SizedBox(width: t.space2),
              ],
              _Pill(label: last ? labels.done : labels.next, onTap: onNext, filled: true, focusNode: nextFocus),
            ]),
          ]),
        ),
      ),
    );
  }
}

List<BoxShadow> _ring(UiTokens t, bool focused) =>
    focused ? [UiRingShadow(color: t.primaryContrast, spread: 4), UiRingShadow(color: t.primary, spread: 2)] : const [];

/// Skip / Turn off tips: plain words, never mistaken for the main button.
class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap, required this.style, this.underline = false});
  final String label;
  final VoidCallback onTap;
  final TextStyle style;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    return UiInteractive(
      onTap: onTap,
      semanticLabel: label,
      excludeChildSemantics: true,
      pressScale: false,
      builder: (context, s) => Container(
        padding: EdgeInsets.symmetric(horizontal: t.space1, vertical: t.space1),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(theme.radius(t.radiusXs)), boxShadow: _ring(t, s.focused)),
        child: Text(
          label,
          style: style.copyWith(
            color: style.color!.withValues(alpha: s.hovered ? 1 : 0.9),
            decoration: underline || s.hovered ? TextDecoration.underline : null,
            decorationColor: style.color,
          ),
        ),
      ),
    );
  }
}

/// Back (outlined) and Next/Done (filled with the contrast colour) pills.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap, required this.filled, this.focusNode});
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final fg = t.primaryContrast;
    final style = theme.typography.body.copyWith(fontSize: t.fontSizeSm, fontWeight: FontWeight.w600, color: filled ? t.primary : fg, height: 1.2);
    return UiInteractive(
      onTap: onTap,
      focusNode: focusNode,
      semanticLabel: label,
      excludeChildSemantics: true,
      builder: (context, s) => Container(
        constraints: BoxConstraints(minHeight: uiTouchPlatform(context) ? 36 : 32),
        padding: EdgeInsets.symmetric(horizontal: t.space3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? (s.hovered ? uiMix(fg, 0.88, t.primary) : fg)
              : (s.hovered ? fg.withValues(alpha: 0.14) : null),
          border: filled ? null : Border.all(color: fg.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.circular(t.radiusPill),
          boxShadow: _ring(t, s.focused),
        ),
        child: Text(label, style: style, maxLines: 1),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.geometry, this.color) : super(repaint: geometry);

  final _BubbleGeometry geometry;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final o = geometry.arrow;
    final path = Path();
    switch (geometry.side) {
      // The bubble is above the anchor: the arrow hangs below it, and so on.
      case _Side.top:
        path..moveTo(o - _kArrow, size.height)..lineTo(o, size.height + _kArrow)..lineTo(o + _kArrow, size.height);
      case _Side.bottom:
        path..moveTo(o - _kArrow, 0)..lineTo(o, -_kArrow)..lineTo(o + _kArrow, 0);
      case _Side.left:
        path..moveTo(size.width, o - _kArrow)..lineTo(size.width + _kArrow, o)..lineTo(size.width, o + _kArrow);
      case _Side.right:
        path..moveTo(0, o - _kArrow)..lineTo(-_kArrow, o)..lineTo(0, o + _kArrow);
      case _Side.none:
        return;
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color || old.geometry != geometry;
}
