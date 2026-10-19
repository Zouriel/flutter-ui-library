import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/interactive.dart';
import '../../theme/theme.dart';
import 'roving.dart';

/// `ui-rating`: a star rating from 0 (none) to [max]. A radio group: one tab stop, the arrow keys
/// (and Home/End) move the rating, a tap sets it, and tapping the current star again clears it to 0.
/// Null [onChanged] disables it.
///
/// Stars are 20px in 24px cells with a mouse, 28px in 48dp cells on phones.
class UiRating extends StatefulWidget {
  const UiRating({super.key, required this.value, required this.onChanged, this.max = 5, this.label = 'Rating'});

  final int value;
  final ValueChanged<int>? onChanged;
  final int max;

  /// The group's accessible name.
  final String label;

  @override
  State<UiRating> createState() => _UiRatingState();
}

class _UiRatingState extends State<UiRating> with UiRovingFocus<UiRating> {
  int _hover = 0;

  bool get _enabled => widget.onChanged != null;

  void _tap(int i) => widget.onChanged!(widget.value == i ? 0 : i);

  bool _onKey(LogicalKeyboardKey key, int at) {
    final star = at + 1;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    int next;
    if (key == LogicalKeyboardKey.arrowUp || key == (rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight)) {
      next = (star + 1).clamp(1, widget.max);
    } else if (key == LogicalKeyboardKey.arrowDown || key == (rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft)) {
      next = (star - 1).clamp(1, widget.max);
    } else if (key == LogicalKeyboardKey.home) {
      next = 1;
    } else if (key == LogicalKeyboardKey.end) {
      next = widget.max;
    } else {
      return false;
    }
    if (next != widget.value) widget.onChanged!(next);
    rovingFocus(next - 1);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    final cell = touch ? uiMinTouchTarget : 24.0;
    final starSize = touch ? 28.0 : 20.0;
    final tabStop = _enabled ? (widget.value > 0 ? widget.value : 1) - 1 : null;
    syncRoving(widget.max, tabStop);
    final shownUpTo = _hover > 0 ? _hover : widget.value;
    return Semantics(
      container: true,
      role: SemanticsRole.radioGroup,
      label: widget.label,
      explicitChildNodes: true,
      child: rovingKeys(
        onKey: _onKey,
        child: MouseRegion(
          onExit: (_) => setState(() => _hover = 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= widget.max; i++)
                MouseRegion(
                  onEnter: _enabled ? (_) => setState(() => _hover = i) : null,
                  child: UiInteractive(
                    focusNode: rovingNode(i - 1),
                    enabled: _enabled,
                    onTap: _enabled ? () => _tap(i) : null,
                    button: false,
                    checked: i == widget.value,
                    semanticLabel: '$i of ${widget.max}',
                    padTouchTarget: false,
                    pressScale: false,
                    builder: (context, s) => Semantics(
                      inMutuallyExclusiveGroup: true,
                      child: AnimatedOpacity(
                        opacity: s.disabled ? 0.5 : 1,
                        duration: t.motionBase,
                        child: Container(
                          width: cell,
                          height: cell,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(t.radiusXs),
                            boxShadow: s.focused ? t.focusRing : const [],
                          ),
                          child: TweenAnimationBuilder<Color?>(
                            tween: ColorTween(end: i <= shownUpTo ? t.ratingFill : t.textMuted),
                            duration: context.uiAnimate ? t.motionFast : Duration.zero,
                            builder: (context, c, _) => CustomPaint(
                              size: Size.square(starSize),
                              painter: UiStarPainter(color: c ?? t.textMuted, filled: i <= shownUpTo),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The rating star (the web's own path, so it matches): an outline, or filled.
class UiStarPainter extends CustomPainter {
  UiStarPainter({required this.color, required this.filled});
  final Color color;
  final bool filled;

  static Path star(double size) {
    final s = size / 24;
    const pts = [
      Offset(12, 2.8), Offset(14.85, 8.58), Offset(21.23, 9.51), Offset(16.61, 14.01), Offset(17.70, 20.36),
      Offset(12, 17.36), Offset(6.3, 20.36), Offset(7.39, 14.01), Offset(2.77, 9.51), Offset(9.15, 8.58),
    ];
    final p = Path()..moveTo(pts[0].dx * s, pts[0].dy * s);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx * s, o.dy * s);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = star(size.width);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * size.width / 24
      ..strokeJoin = StrokeJoin.round;
    if (filled) canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(UiStarPainter old) => old.color != color || old.filled != filled;
}
