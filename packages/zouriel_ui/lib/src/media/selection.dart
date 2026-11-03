import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../button/button.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../overlay/tooltip.dart';
import '../theme/theme.dart';

/// How much a selected tile shrinks inside its cell, like a phone gallery.
const double uiSelectableScale = 0.9;

/// `ui-selectable`: wraps one grid tile (a photo) for long-press multi-select, like a phone gallery.
///
/// A tap calls [onTap] (the app decides: open the tile, or toggle it while [selecting]); a long press
/// calls [onLongPress] with a light haptic. The long press only fires for a finger that stays put, so
/// it works inside a scroll view: a finger that scrolls never selects.
///
/// While [selecting] a round mark sits in the top-start corner: an empty ring over a small scrim, or
/// filled with the primary colour and a check when [selected], readable on white and black pictures
/// alike. A selected child shrinks a little (animated; instant when animations are off) and gets a
/// primary outline and tint. When not selecting there is no mark and the child is untouched.
///
/// Screen readers hear [semanticLabel] and the selected state; while selecting it reads as checked or
/// not checked. The long press is offered to them as an action too.
class UiSelectable extends StatelessWidget {
  const UiSelectable({
    super.key,
    required this.child,
    required this.selected,
    required this.selecting,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.borderRadius,
  });

  final Widget child;
  final bool selected;

  /// Whether the grid is in selection mode (the marks show).
  final bool selecting;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// The tile's name (a picture has no text of its own).
  final String? semanticLabel;

  /// The tile's corners; the theme's radius when null.
  final BorderRadius? borderRadius;

  void _longPress() {
    unawaited(HapticFeedback.selectionClick());
    onLongPress!();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final animate = context.uiAnimate;
    final r = borderRadius ?? BorderRadius.circular(context.uiTheme.radius());
    final on = selecting && selected;
    final duration = animate ? t.motionBase : Duration.zero;
    return UiInteractive(
      onTap: onTap,
      onLongPress: onLongPress == null ? null : _longPress,
      padTouchTarget: false,
      pressScale: false,
      button: !selecting,
      semanticLabel: semanticLabel,
      selected: selected,
      checked: selecting ? selected : null,
      excludeChildSemantics: semanticLabel != null,
      builder: (context, s) => Stack(
        fit: StackFit.passthrough,
        children: [
          AnimatedScale(
            scale: on ? uiSelectableScale : 1,
            duration: duration,
            curve: t.easeStandard,
            child: AnimatedContainer(
              duration: duration,
              curve: t.easeStandard,
              foregroundDecoration: BoxDecoration(
                borderRadius: r,
                color: on ? t.primary.withValues(alpha: 0.18) : const Color(0x00000000),
                border: Border.all(color: on ? t.primary : const Color(0x00000000), width: 3),
              ),
              decoration: BoxDecoration(borderRadius: r, boxShadow: s.focused ? t.focusRing : null),
              child: ClipRRect(borderRadius: r, child: child),
            ),
          ),
          if (selecting)
            PositionedDirectional(
              top: t.space2,
              start: t.space2,
              child: UiSelectionMark(selected: selected),
            ),
        ],
      ),
    );
  }
}

/// The round mark of a [UiSelectable] (exported for tests): a 24px ring in the on-scrim colour over
/// a small scrim, or the primary colour with a check when [selected]. Decorative: the tile's
/// semantics say it.
class UiSelectionMark extends StatelessWidget {
  const UiSelectionMark({super.key, required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final duration = context.uiAnimate ? t.motionFast : Duration.zero;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: duration,
        curve: t.easeStandard,
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? t.primary : t.mediaScrim.withValues(alpha: 0.35),
          // The light ring shows on dark pictures, the dark halo around it on white ones.
          border: Border.all(color: t.mediaOnScrim, width: 2),
          boxShadow: [BoxShadow(color: t.mediaScrim.withValues(alpha: 0.4), blurRadius: 3)],
        ),
        alignment: Alignment.center,
        child: selected ? UiIcon(HugeIcons.strokeRoundedTick02, size: 14, color: t.primaryContrast, strokeWidth: 2.5) : null,
      ),
    );
  }
}

/// One action at the end of a [UiSelectionBar] (Share, Save, Delete).
@immutable
class UiSelectionAction {
  const UiSelectionAction({required this.id, required this.label, this.icon, this.danger = false, this.enabled = true});

  /// What [UiSelectionBar.onAction] is called with.
  final String id;
  final String label;

  /// A `UiIcon(HugeIcons.…)`. Needed for the action to shrink to an icon on a narrow bar; an action
  /// without one keeps its label.
  final Widget? icon;

  /// Drawn in the danger style (delete).
  final bool danger;

  /// Off greys it out; every action is also off while nothing is selected.
  final bool enabled;
}

double _textWidth(BuildContext context, String s, TextStyle style) {
  final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr, textScaler: MediaQuery.textScalerOf(context), maxLines: 1)..layout();
  final w = tp.width;
  tp.dispose();
  return w;
}

/// `ui-selection-bar`: the bar shown while selecting. Cancel (an X) at the start, "N selected", a
/// Select all toggle that turns into Clear once everything is selected, then [actions].
///
/// The toggle calls [onSelectAll] or [onClear]; each side is hidden when its callback is null, and
/// without a [total] it never turns into Clear. Actions are disabled while [count] is 0 or their
/// [UiSelectionAction.enabled] is false. When the labels don't all fit (a 360px phone with three
/// actions), the toggle and the actions with an icon shrink to icon buttons that keep their label for
/// screen readers and as a tooltip; then, if "12 selected" still doesn't fit, it shows the number
/// alone (read out in full), so nothing overflows even at 320. Count changes are announced politely.
class UiSelectionBar extends StatelessWidget {
  const UiSelectionBar({
    super.key,
    required this.count,
    this.total,
    this.onSelectAll,
    this.onClear,
    required this.onCancel,
    this.actions = const [],
    this.onAction,
  });

  final int count;

  /// Everything there is to select; when [count] reaches it the toggle reads Clear.
  final int? total;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClear;
  final VoidCallback onCancel;
  final List<UiSelectionAction> actions;

  /// Called with the [UiSelectionAction.id] of the action pressed.
  final ValueChanged<String>? onAction;

  /// Whether everything is selected (the toggle reads Clear).
  bool get allSelected => total != null && total! > 0 && count >= total!;

  /// The width the bar needs to show every label (button paddings from [UiButton] at [UiSize.sm]).
  static double labelledWidth(BuildContext context, {required String countText, required String? toggle, required List<UiSelectionAction> actions}) {
    final t = context.ui;
    final theme = context.uiTheme;
    final scaler = MediaQuery.textScalerOf(context);
    double text(String s, double size, FontWeight w) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: theme.typography.body.copyWith(fontSize: size, fontWeight: w, letterSpacing: t.trackingTight * size, height: 1.2)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w0 = tp.width;
      tp.dispose();
      return w0;
    }

    double button(String label, {bool icon = false}) => t.space3 * 2 + 2 + (icon ? 14 + t.space2 : 0) + text(label, 13, FontWeight.w500);
    final iconBox = uiTouchPlatform(context) ? uiMinTouchTarget : t.sizeSm;
    var w = t.space1 * 2 + iconBox + text(countText, t.fontSizeSm, FontWeight.w600);
    if (toggle != null) w += t.space1 + button(toggle);
    for (final a in actions) {
      w += t.space1 + button(a.label, icon: a.icon != null);
    }
    // The gap between cancel and the count.
    return w + t.space1;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final strings = context.uiStrings;
    final countText = uiFormatString(strings.selectionCount, {'n': count});
    final all = allSelected;
    final VoidCallback? toggleAction = all ? onClear : onSelectAll;
    final String? toggleLabel = toggleAction == null ? null : (all ? strings.clearSelection : strings.selectAll);
    return LayoutBuilder(builder: (context, box) {
      final compact = box.maxWidth.isFinite && labelledWidth(context, countText: countText, toggle: toggleLabel, actions: actions) > box.maxWidth;
      Widget labelled(String label, Widget? icon, VoidCallback? onPressed, UiButtonVariant variant) {
        if (compact && icon != null) {
          return UiTooltip(
            message: label,
            child: UiIconButton(icon: icon, label: label, size: UiSize.sm, variant: variant, onPressed: onPressed),
          );
        }
        return UiButton(label: label, icon: icon, size: UiSize.sm, variant: variant, onPressed: onPressed);
      }

      return Semantics(
        container: true,
        explicitChildNodes: true,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: t.space1, vertical: t.space1),
          constraints: BoxConstraints(minHeight: uiTouchPlatform(context) ? uiMinTouchTarget + t.space2 : t.sizeMd + t.space2),
          child: Row(
            spacing: t.space1,
            children: [
              UiIconButton(
                icon: const UiIcon(HugeIcons.strokeRoundedCancel01),
                label: strings.cancelSelection,
                size: UiSize.sm,
                onPressed: onCancel,
              ),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  label: countText,
                  excludeSemantics: true,
                  child: LayoutBuilder(builder: (context, room) {
                    final style = context.uiText.body.copyWith(fontSize: t.fontSizeSm, fontWeight: FontWeight.w600, color: t.text, fontFeatures: const [FontFeature.tabularFigures()]);
                    // Too narrow for "12 selected": the number alone (screen readers still hear it all).
                    final fits = _textWidth(context, countText, style) <= room.maxWidth;
                    return Text(fits ? countText : '$count', maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
                  }),
                ),
              ),
              if (toggleLabel != null)
                labelled(
                  toggleLabel,
                  compact ? UiIcon(all ? HugeIcons.strokeRoundedRemoveSquare : HugeIcons.strokeRoundedCheckmarkSquare02) : null,
                  toggleAction,
                  UiButtonVariant.ghost,
                ),
              for (final a in actions)
                labelled(
                  a.label,
                  a.icon,
                  count > 0 && a.enabled && onAction != null ? () => onAction!(a.id) : null,
                  a.danger ? UiButtonVariant.destructive : UiButtonVariant.ghost,
                ),
            ],
          ),
        ),
      );
    });
  }
}
