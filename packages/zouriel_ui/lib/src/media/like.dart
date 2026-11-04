import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../theme/theme.dart';

/// 1234 -> "1.2k", 15400 -> "15k", 1250000 -> "1.2m". Truncated, never rounded up into the next unit.
String uiCompactCount(int n) {
  final v = math.max(0, n);
  if (v < 1000) return '$v';
  final (d, s) = v < 1000000 ? (1000, 'k') : (1000000, 'm');
  final x = v / d;
  if (x < 10) {
    final one = (x * 10).floor() / 10;
    return '${one == one.truncateToDouble() ? one.toInt() : one}$s';
  }
  return '${x.floor()}$s';
}

/// A heart, outlined or filled, drawn to match the hugeicons line weight.
class UiHeartPainter extends CustomPainter {
  const UiHeartPainter({required this.color, this.filled = false, this.strokeWidth = 1.9});
  final Color color;
  final bool filled;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final dx = (size.width - s) / 2, dy = (size.height - s) / 2;
    // A 24-unit heart, the shape of hugeicons' Favourite.
    Offset p(double x, double y) => Offset(dx + x * s / 24, dy + y * s / 24);
    final path = Path()
      ..moveTo(p(12, 20.5).dx, p(12, 20.5).dy)
      ..cubicTo(p(9, 18.6).dx, p(9, 18.6).dy, p(2.5, 14.4).dx, p(2.5, 14.4).dy, p(2.5, 9).dx, p(2.5, 9).dy)
      ..cubicTo(p(2.5, 5.9).dx, p(2.5, 5.9).dy, p(4.8, 3.75).dx, p(4.8, 3.75).dy, p(7.5, 3.75).dx, p(7.5, 3.75).dy)
      ..cubicTo(p(9.4, 3.75).dx, p(9.4, 3.75).dy, p(11, 4.8).dx, p(11, 4.8).dy, p(12, 6.4).dx, p(12, 6.4).dy)
      ..cubicTo(p(13, 4.8).dx, p(13, 4.8).dy, p(14.6, 3.75).dx, p(14.6, 3.75).dy, p(16.5, 3.75).dx, p(16.5, 3.75).dy)
      ..cubicTo(p(19.2, 3.75).dx, p(19.2, 3.75).dy, p(21.5, 5.9).dx, p(21.5, 5.9).dy, p(21.5, 9).dx, p(21.5, 9).dy)
      ..cubicTo(p(21.5, 14.4).dx, p(21.5, 14.4).dy, p(15, 18.6).dx, p(15, 18.6).dy, p(12, 20.5).dx, p(12, 20.5).dy)
      ..close();
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = strokeWidth * s / 24
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
    if (filled) canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(UiHeartPainter old) => old.color != color || old.filled != filled || old.strokeWidth != strokeWidth;
}

/// The small heart and number for a corner of a photo tile (`ui-like-count` on the web): a dark
/// see-through pill readable on any picture. Nothing at all at 0 unless [liked]; the heart is filled
/// when [liked]. Never takes a tap: liking is a double tap on the tile or [UiLikeButton] in a viewer.
class UiLikeCount extends StatelessWidget {
  const UiLikeCount({super.key, required this.count, this.liked = false, this.size = UiLikeCountSize.sm});
  final int count;
  final bool liked;
  final UiLikeCountSize size;

  @override
  Widget build(BuildContext context) {
    if (count <= 0 && !liked) return const SizedBox.shrink();
    final t = context.ui;
    final md = size == UiLikeCountSize.md;
    final likes = '$count ${count == 1 ? 'like' : 'likes'}';
    return IgnorePointer(
      child: Semantics(
        label: liked ? 'Liked, $likes' : likes,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(color: t.mediaScrim.withValues(alpha: 0.62), borderRadius: BorderRadius.circular(999)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: md ? t.space1 : 2),
            child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
              CustomPaint(
                size: Size.square(md ? 16 : 13),
                painter: UiHeartPainter(color: t.mediaOnScrim, filled: liked, strokeWidth: 2),
              ),
              if (count > 0)
                Text(uiCompactCount(count),
                    style: context.uiText.caption.copyWith(
                        color: t.mediaOnScrim, fontWeight: FontWeight.w600, height: 1.2, fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
          ),
        ),
      ),
    );
  }
}

enum UiLikeCountSize { sm, md }

/// The heart that pops where a photo was double-tapped (`ui-heart-burst` on the web). Put it in a
/// Stack over the media (it fills it and never takes a pointer) and call
/// `key.currentState!.play(offset)` with a point inside it, or `play()` for the centre. Several can
/// overlap. With animations off (reduced motion) it fades in and out only.
class UiHeartBurst extends StatefulWidget {
  const UiHeartBurst({super.key, this.size = 88});
  final double size;

  @override
  State<UiHeartBurst> createState() => UiHeartBurstState();
}

class UiHeartBurstState extends State<UiHeartBurst> with TickerProviderStateMixin {
  final _bursts = <(AnimationController, Offset?)>[];

  /// Pops a heart at [at] inside this box, or in its centre.
  void play([Offset? at]) {
    final full = context.uiAnimate;
    final c = AnimationController(vsync: this, duration: Duration(milliseconds: full ? 720 : 400));
    final entry = (c, at);
    setState(() => _bursts.add(entry));
    c.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _bursts.remove(entry));
      c.dispose();
    });
  }

  @override
  void dispose() {
    for (final b in _bursts) {
      b.$1.dispose();
    }
    super.dispose();
  }

  static double _scale(double v) {
    if (v < 0.18) return Curves.easeOut.transform(v / 0.18) * 1.18;
    if (v < 0.32) return 1.18 - (v - 0.18) / 0.14 * 0.24;
    if (v < 0.45) return 0.94 + (v - 0.32) / 0.13 * 0.06;
    if (v < 0.78) return 1;
    return 1 - (v - 0.78) / 0.22 * 0.1;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final full = context.uiAnimate;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(builder: (context, box) {
          final centre = Offset(box.maxWidth / 2, box.maxHeight / 2);
          return Stack(clipBehavior: Clip.hardEdge, children: [
            for (final (c, at) in _bursts)
              AnimatedBuilder(
                animation: c,
                builder: (context, _) {
                  final v = c.value;
                  final p = at ?? centre;
                  final opacity = full
                      ? (v < 0.18 ? v / 0.18 : (v < 0.78 ? 1.0 : 1 - (v - 0.78) / 0.22))
                      : (v < 0.3 ? v / 0.3 : (v < 0.7 ? 1.0 : 1 - (v - 0.7) / 0.3));
                  final rise = full && v > 0.45 ? (v - 0.45) / 0.55 * widget.size * 0.3 : 0.0;
                  return Positioned(
                    left: p.dx - widget.size / 2,
                    top: p.dy - widget.size / 2 - rise,
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: full ? _scale(v) : 1,
                        child: CustomPaint(
                          size: Size.square(widget.size),
                          painter: UiHeartPainter(color: t.mediaOnScrim, filled: true, strokeWidth: 1.5),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ]);
        }),
      ),
    );
  }
}

/// The viewer's heart toggle with its count beside it (`ui-like-button` on the web). White over
/// media; [UiLikeButtonTone.surface] on an ordinary background. Calls [onChanged] with the new
/// state (the count is the caller's to update) and pops a little when liked.
class UiLikeButton extends StatefulWidget {
  const UiLikeButton({super.key, required this.liked, required this.count, this.onChanged, this.tone = UiLikeButtonTone.media});
  final bool liked;
  final int count;
  final ValueChanged<bool>? onChanged;
  final UiLikeButtonTone tone;

  @override
  State<UiLikeButton> createState() => _UiLikeButtonState();
}

enum UiLikeButtonTone { media, surface }

class _UiLikeButtonState extends State<UiLikeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _toggle() {
    final next = !widget.liked;
    if (next && context.uiAnimate) _pop.forward(from: 0);
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final ink = widget.tone == UiLikeButtonTone.media ? t.mediaOnScrim : t.text;
    final enabled = widget.onChanged != null;
    return Semantics(
      button: true,
      toggled: widget.liked,
      enabled: enabled,
      label: 'Like, ${widget.count} ${widget.count == 1 ? 'like' : 'likes'}',
      excludeSemantics: true,
      onTap: enabled ? _toggle : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _toggle : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space2),
              child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, spacing: t.space1, children: [
                AnimatedBuilder(
                  animation: _pop,
                  builder: (context, child) {
                    final v = _pop.value;
                    final s = v == 0 ? 1.0 : (v < 0.4 ? 1 + v / 0.4 * 0.3 : 1.3 - (v - 0.4) / 0.6 * 0.3);
                    return Transform.scale(scale: s, child: child);
                  },
                  child: CustomPaint(
                    size: const Size.square(22),
                    painter: UiHeartPainter(color: widget.liked ? t.danger : ink, filled: widget.liked),
                  ),
                ),
                if (widget.count > 0)
                  Text(uiCompactCount(widget.count),
                      style: context.uiText.label.copyWith(color: ink, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
