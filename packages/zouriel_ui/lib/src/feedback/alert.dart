import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';

import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';

/// Alert tones, the web `UiAlertTone`.
enum UiAlertTone { info, success, warning, danger }

/// `ui-alert`: an inline message with a tone icon, optional heading and an optional dismiss button.
/// Danger and warning alerts are announced immediately (the web `role="alert"`); info and success
/// politely (`role="status"`).
class UiAlert extends StatelessWidget {
  const UiAlert({super.key, this.heading, this.message, this.child, this.tone = UiAlertTone.info, this.onDismiss, this.radius})
      : assert(message != null || child != null || heading != null);

  final String? heading;
  final String? message;
  final Widget? child;
  final UiAlertTone tone;

  /// Shows a dismiss button when set. The alert only emits; hide it yourself.
  final VoidCallback? onDismiss;
  final bool? radius;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final c = switch (tone) { UiAlertTone.info => t.info, UiAlertTone.success => t.success, UiAlertTone.warning => t.warning, UiAlertTone.danger => t.danger };
    final icon = switch (tone) {
      UiAlertTone.info => HugeIcons.strokeRoundedInformationCircle,
      UiAlertTone.success => HugeIcons.strokeRoundedCheckmarkCircle02,
      UiAlertTone.warning => HugeIcons.strokeRoundedAlert02,
      UiAlertTone.danger => HugeIcons.strokeRoundedCancelCircle,
    };
    final body = theme.typography.body.copyWith(height: 1.35);
    final r = (radius ?? theme.config.radius) ? t.radius : 0.0;
    return Semantics(
      liveRegion: true,
      container: true,
      // Flutter can't paint a rounded border with sides of different colours, so the box is
      // clipped to the radius and the tone edge drawn as a plain 3px left border inside it.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          // The tone edge is on the start side: the right in RTL.
          border: BorderDirectional(
            start: BorderSide(color: c, width: 3),
            top: BorderSide(color: t.border),
            end: BorderSide(color: t.border),
            bottom: BorderSide(color: t.border),
          ),
        ),
        padding: EdgeInsets.symmetric(vertical: t.space2, horizontal: t.space3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: t.space2,
          children: [
            // One line tall, so the icon centres on the first line of text.
            SizedBox(height: body.fontSize! * 1.35, child: Center(child: UiIcon(icon, size: 16, color: c, strokeWidth: 2))),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (heading != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(heading!, style: body.copyWith(fontWeight: FontWeight.w700, letterSpacing: t.trackingTight * body.fontSize!)),
                    ),
                  DefaultTextStyle(style: body.copyWith(color: t.textMuted), child: child ?? Text(message ?? '')),
                ],
              ),
            ),
            if (onDismiss != null)
              Transform.translate(
                offset: Offset(t.space1, -t.space1),
                child: UiInteractive(
                  onTap: onDismiss,
                  semanticLabel: context.uiStrings.dismiss,
                  excludeChildSemantics: true,
                  builder: (context, s) => AnimatedContainer(
                    duration: t.motionFast,
                    width: t.sizeSm,
                    height: t.sizeSm,
                    decoration: BoxDecoration(
                      color: s.hovered || s.pressed ? t.surfaceHover : null,
                      borderRadius: BorderRadius.circular(t.radiusXs),
                      boxShadow: s.focused ? t.focusRing : const [],
                    ),
                    child: Center(child: UiIcon(HugeIcons.strokeRoundedCancel01, size: 16, color: s.hovered ? t.text : t.textMuted, strokeWidth: 2)),
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

/// `ui-progress-bar`: determinate when [value] (0–100) is set, otherwise indeterminate.
class UiProgressBar extends StatefulWidget {
  const UiProgressBar({super.key, this.value, this.tone = UiStatus.primary, this.label});

  final double? value;

  /// Fill colour. Neutral uses the muted text colour, which keeps 3:1 against the track.
  final UiStatus tone;

  /// The name read out; [UiStrings.progress] when null.
  final String? label;

  @override
  State<UiProgressBar> createState() => _UiProgressBarState();
}

class _UiProgressBarState extends State<UiProgressBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(UiProgressBar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    _c.duration = Duration(milliseconds: context.uiAnimate ? 1200 : 2400);
    if (widget.value == null) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    // Neutral is a grey (--ui-progress-neutral), so it never reads as the primary fill.
    final fill = widget.tone == UiStatus.neutral ? t.progressNeutral : widget.tone.color(t);
    final v = widget.value?.clamp(0, 100).toDouble();
    return Semantics(
      label: widget.label ?? context.uiStrings.progress,
      value: v == null ? null : '${v.round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(t.radiusPill),
        child: SizedBox(
          height: 6,
          child: ColoredBox(
            color: t.track,
            child: LayoutBuilder(builder: (context, box) {
              if (v != null) {
                return Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AnimatedContainer(
                    duration: t.motionBase,
                    curve: t.easeStandard,
                    width: box.maxWidth * v / 100,
                    decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(t.radiusPill)),
                  ),
                );
              }
              // A 40% bar sweeping from fully left to fully right.
              return AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final x = t.easeStandard.transform(_c.value);
                  return Transform.translate(
                    offset: Offset((-0.4 + x * 1.4) * box.maxWidth, 0),
                    child: Container(
                      width: box.maxWidth * 0.4,
                      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(t.radiusPill)),
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}
