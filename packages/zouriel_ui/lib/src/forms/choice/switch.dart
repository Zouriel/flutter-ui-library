import 'package:flutter/widgets.dart';

import '../../core/interactive.dart';
import '../../theme/theme.dart';
import 'marks.dart';

/// `ui-switch`: an on/off toggle, announced as a switch (toggled). The thumb springs across; the
/// label (optional) sits beside the track and is part of the touch target.
class UiSwitch extends StatelessWidget {
  const UiSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.child,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  });

  final bool value;

  /// Null disables it.
  final ValueChanged<bool>? onChanged;
  final String? label;
  final Widget? child;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Accessible name when there is no visible label.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final enabled = onChanged != null;
    final animate = context.uiAnimate;
    return UiInteractive(
      onTap: enabled ? () => onChanged!(!value) : null,
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
      button: false,
      toggled: value,
      semanticLabel: semanticLabel,
      pressScale: false,
      builder: (context, s) => UiMarkRow(
        disabled: !enabled,
        center: true,
        label: label,
        mark: AnimatedContainer(
          duration: animate ? t.motionBase : Duration.zero,
          curve: t.easeStandard,
          width: 38,
          height: 22,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? t.switchTrackChecked : t.switchTrack,
            borderRadius: BorderRadius.circular(t.radiusPill),
            boxShadow: s.focused ? t.focusRing : const [],
          ),
          child: AnimatedAlign(
            alignment: value ? AlignmentDirectional.centerEnd.resolve(Directionality.of(context)) : AlignmentDirectional.centerStart.resolve(Directionality.of(context)),
            duration: animate ? t.motionBase : Duration.zero,
            curve: t.easeSpring,
            child: AnimatedContainer(
              duration: animate ? t.motionBase : Duration.zero,
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: value ? t.switchThumbChecked : t.switchThumb,
                shape: BoxShape.circle,
                boxShadow: t.shadow1,
              ),
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}
