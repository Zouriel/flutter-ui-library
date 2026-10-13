import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Outcomes for [UiResult], the web `UiResultStatus` ('404' and '500' become [notFound] and
/// [serverError]).
enum UiResultStatus { success, error, info, warning, notFound, serverError }

/// `ui-result`: a full-page outcome (success, error, not found, server error...): a tinted glyph in a
/// circle, a [title], an optional [subtitle] and [actions]. The title is announced as a heading.
class UiResult extends StatelessWidget {
  const UiResult({super.key, this.status = UiResultStatus.info, required this.title, this.subtitle, this.actions = const []});

  final UiResultStatus status;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final ty = context.uiText;
    final c = switch (status) {
      UiResultStatus.success => t.success,
      UiResultStatus.error || UiResultStatus.serverError => t.danger,
      UiResultStatus.warning => t.warning,
      UiResultStatus.info || UiResultStatus.notFound => t.info,
    };
    return Padding(
      padding: EdgeInsets.all(t.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: t.surfaceRaised, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: CustomPaint(size: const Size.square(28), painter: _GlyphPainter(status, c)),
            ),
          ),
          SizedBox(height: t.space4),
          Semantics(
            header: true,
            child: Text(title, textAlign: TextAlign.center, style: ty.body.copyWith(fontSize: t.fontSizeLg, fontWeight: FontWeight.w600, height: 1.35)),
          ),
          if (subtitle != null)
            Padding(
              padding: EdgeInsets.only(top: t.space2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(subtitle!, textAlign: TextAlign.center, style: ty.caption.copyWith(height: 1.35)),
              ),
            ),
          if (actions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: t.space3 + t.space2),
              child: Wrap(alignment: WrapAlignment.center, spacing: t.space2, runSpacing: t.space2, children: actions),
            ),
        ],
      ),
    );
  }
}

/// The web result glyphs, drawn from the same 24-unit paths: a check, a cross, "!", "i" and "?".
class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.status, this.color);
  final UiResultStatus status;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    void dot(double x, double y) => canvas.drawCircle(Offset(x, y), 1.1, Paint()..color = color);
    switch (status) {
      case UiResultStatus.success:
        path..moveTo(5, 12.5)..lineTo(9.5, 17)..lineTo(19, 7);
      case UiResultStatus.error:
        path..moveTo(6, 6)..lineTo(18, 18)..moveTo(18, 6)..lineTo(6, 18);
      case UiResultStatus.warning || UiResultStatus.serverError:
        path..moveTo(12, 4)..lineTo(12, 14);
        dot(12, 19);
      case UiResultStatus.info:
        path..moveTo(12, 10)..lineTo(12, 19);
        dot(12, 5);
      case UiResultStatus.notFound:
        // M9 9 a3 3 0 1 1 4.5 2.6 c-.9.5-1.5 1.3-1.5 2.4 v.5
        path
          ..moveTo(9, 9)
          ..arcToPoint(const Offset(13.5, 11.6), radius: const Radius.circular(3), largeArc: true)
          ..cubicTo(12.6, 12.1, 12, 12.9, 12, 14)
          ..lineTo(12, 14.5);
        dot(12, 19);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.status != status || old.color != color;
}
