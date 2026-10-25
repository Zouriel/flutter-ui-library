import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// `ui-meter`: a measurement against a budget, e.g. file size against a limit. Unlike a progress bar
/// it isn't a task finishing: it turns warning past [warnAt] and danger past [dangerAt] (default
/// [max]), and says so in its text, so colour is never the only signal.
class UiMeter extends StatelessWidget {
  const UiMeter({
    super.key,
    required this.value,
    this.max = 100,
    this.warnAt,
    this.dangerAt,
    this.label,
    this.valueText,
    this.warnText,
    this.dangerText,
  });

  final double value;
  final double max;
  final double? warnAt;
  final double? dangerAt;
  final String? label;

  /// How the value is written, e.g. "212 KB of 800 KB". Defaults to "value / max".
  final String? valueText;
  /// [UiStrings.meterWarn] / [UiStrings.meterDanger] when null.
  final String? warnText;
  final String? dangerText;

  /// The current level: success, warning or danger.
  UiMeterLevel get level {
    if (value > (dangerAt ?? max)) return UiMeterLevel.danger;
    if (warnAt != null && value > warnAt!) return UiMeterLevel.warning;
    return UiMeterLevel.ok;
  }

  static String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final ty = context.uiText;
    final lvl = level;
    final tone = switch (lvl) { UiMeterLevel.ok => t.success, UiMeterLevel.warning => t.warning, UiMeterLevel.danger => t.danger };
    final status = switch (lvl) { UiMeterLevel.ok => null, UiMeterLevel.warning => warnText ?? context.uiStrings.meterWarn, UiMeterLevel.danger => dangerText ?? context.uiStrings.meterDanger };
    final shown = valueText ?? '${_num(value)} / ${_num(max)}';
    final m = max <= 0 ? 1 : max;
    final pct = (value / m).clamp(0.0, 1.0);
    final small = ty.body.copyWith(fontSize: t.fontSizeSm, height: 1.35);
    final valueColor = lvl == UiMeterLevel.ok ? t.textSecondary : tone;

    return Semantics(
      container: true,
      label: label ?? context.uiStrings.meter,
      value: status == null ? shown : '$shown, $status',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: t.space2,
                children: [
                  Expanded(
                    child: label == null ? const SizedBox.shrink() : Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis, style: small.copyWith(color: t.textMuted)),
                  ),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: shown, style: ty.code.copyWith(fontSize: t.fontSizeSm, color: valueColor, fontFeatures: const [FontFeature.tabularFigures()])),
                      if (status != null) TextSpan(text: ' · $status', style: small.copyWith(color: valueColor)),
                    ]),
                    maxLines: 1,
                  ),
                ],
              ),
              SizedBox(height: t.space1),
              ClipRRect(
                borderRadius: BorderRadius.circular(t.radiusPill),
                child: SizedBox(
                  height: 6,
                  child: ColoredBox(
                    color: t.track,
                    child: LayoutBuilder(builder: (context, box) {
                      return Stack(children: [
                        AnimatedContainer(
                          duration: context.uiAnimate ? t.motionBase : Duration.zero,
                          curve: t.easeStandard,
                          width: box.maxWidth * pct,
                          decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(t.radiusPill)),
                        ),
                        if (warnAt != null)
                          PositionedDirectional(
                            start: (box.maxWidth * (warnAt! / m).clamp(0.0, 1.0) - 1).clamp(0.0, box.maxWidth - 2),
                            top: 0,
                            bottom: 0,
                            width: 2,
                            child: ColoredBox(color: t.surface.withValues(alpha: 0.8)),
                          ),
                      ]);
                    }),
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

/// Where a [UiMeter] sits against its thresholds.
enum UiMeterLevel { ok, warning, danger }
