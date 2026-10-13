import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../theme/theme.dart';
import 'sources.dart';

/// The scrubber the media players share: what has loaded, what has played and a knob, over a hit
/// area tall enough for a thumb. Drag or tap to seek. For screen readers and keyboards it is a
/// slider ("1:23 of 4:56") that steps by [step].
class UiSeekBar extends StatefulWidget {
  const UiSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.buffered = Duration.zero,
    this.onSeekStart,
    this.onSeekEnd,
    this.step = const Duration(seconds: 5),
    this.trackColor,
    this.bufferColor,
    this.fillColor,
    this.label = 'Seek',
  });

  final Duration position;
  final Duration duration;
  final Duration buffered;
  final ValueChanged<Duration> onSeek;
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;
  final Duration step;

  /// Colours; the defaults are the themed track and primary fill.
  final Color? trackColor, bufferColor, fillColor;
  final String label;

  @override
  State<UiSeekBar> createState() => _UiSeekBarState();
}

class _Step extends Intent {
  const _Step(this.by);
  final int by;
}

class _UiSeekBarState extends State<UiSeekBar> {
  bool _hover = false, _focus = false, _dragging = false;

  double get _ms => widget.duration.inMilliseconds.toDouble();

  Duration _at(double x, double width) {
    if (_ms <= 0 || width <= 0) return Duration.zero;
    return Duration(milliseconds: (x / width * _ms).clamp(0, _ms).round());
  }

  void _stepBy(int dir) {
    if (_ms <= 0) return;
    final next = widget.position + widget.step * dir;
    widget.onSeek(next < Duration.zero ? Duration.zero : next > widget.duration ? widget.duration : next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final track = widget.trackColor ?? t.track;
    final fill = widget.fillColor ?? t.primary;
    final buffer = widget.bufferColor ?? fill.withValues(alpha: 0.35);
    final played = _ms <= 0 ? 0.0 : (widget.position.inMilliseconds / _ms).clamp(0.0, 1.0);
    final loaded = _ms <= 0 ? 0.0 : (widget.buffered.inMilliseconds / _ms).clamp(0.0, 1.0);
    final big = _hover || _focus || _dragging;
    final height = uiTouchPlatform(context) ? uiMinTouchTarget : 26.0;
    final total = uiFormatMediaTime(widget.duration);

    return Semantics(
      slider: true,
      label: widget.label,
      value: '${uiFormatMediaTime(widget.position)} of $total',
      increasedValue: '${uiFormatMediaTime(widget.position + widget.step > widget.duration ? widget.duration : widget.position + widget.step)} of $total',
      decreasedValue: '${uiFormatMediaTime(widget.position - widget.step < Duration.zero ? Duration.zero : widget.position - widget.step)} of $total',
      onIncrease: () => _stepBy(1),
      onDecrease: () => _stepBy(-1),
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        mouseCursor: SystemMouseCursors.click,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowRight): _Step(1),
          SingleActivator(LogicalKeyboardKey.arrowUp): _Step(1),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _Step(-1),
          SingleActivator(LogicalKeyboardKey.arrowDown): _Step(-1),
        },
        actions: {_Step: CallbackAction<_Step>(onInvoke: (i) => _stepBy(i.by))},
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onTapUp: (d) => widget.onSeek(_at(d.localPosition.dx, w)),
            onHorizontalDragStart: (d) {
              setState(() => _dragging = true);
              widget.onSeekStart?.call();
              widget.onSeek(_at(d.localPosition.dx, w));
            },
            onHorizontalDragUpdate: (d) => widget.onSeek(_at(d.localPosition.dx, w)),
            onHorizontalDragEnd: (_) {
              setState(() => _dragging = false);
              widget.onSeekEnd?.call();
            },
            child: SizedBox(
              height: height,
              child: CustomPaint(
                painter: _SeekPainter(
                  played: played,
                  loaded: loaded,
                  track: track,
                  buffer: buffer,
                  fill: fill,
                  thick: big ? 6 : 4,
                  knob: big ? 12 : 10,
                  ring: _focus ? t.borderFocus : null,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SeekPainter extends CustomPainter {
  _SeekPainter({required this.played, required this.loaded, required this.track, required this.buffer, required this.fill, required this.thick, required this.knob, this.ring});
  final double played, loaded, thick, knob;
  final Color track, buffer, fill;
  final Color? ring;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = knob / 2;
    final w = size.width - inset * 2;
    final cy = size.height / 2;
    RRect bar(double share) => RRect.fromRectAndRadius(Rect.fromLTWH(inset, cy - thick / 2, w * share, thick), Radius.circular(thick));
    canvas.drawRRect(bar(1), Paint()..color = track);
    if (loaded > 0) canvas.drawRRect(bar(loaded), Paint()..color = buffer);
    if (played > 0) canvas.drawRRect(bar(played), Paint()..color = fill);
    final c = Offset(inset + w * played, cy);
    if (ring != null) canvas.drawCircle(c, knob / 2 + 3, Paint()..color = ring!..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(c, knob / 2, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_SeekPainter o) =>
      o.played != played || o.loaded != loaded || o.thick != thick || o.knob != knob || o.track != track || o.fill != fill || o.buffer != buffer || o.ring != ring;
}
