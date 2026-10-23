import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../theme/theme.dart';
import 'hold_button.dart';

/// Where a [UiFab] sits in a [UiFabHost]: a corner, or the middle of the top or bottom edge
/// (topCenter / bottomCenter, 0.44.0).
enum UiFabPosition { bottomEnd, bottomStart, topEnd, topStart, topCenter, bottomCenter }

/// A [UiFab]'s colour (0.44.0): [primary], or [danger] for an emergency action such as SOS, drawn
/// for high visibility (the danger fill, a ring in the raised surface colour and a soft danger halo).
enum UiFabTone { primary, danger }

/// FAB diameters: 40 (sm, grown to 48 on phones) or 52 (md).
enum UiFabSize { sm, md }

/// `ui-fab`: the floating action button, a round primary button with a shadow. [label] is required:
/// it is the accessible name. Grows a little on hover, shrinks when pressed.
///
/// On its own it is just the button; [UiFabHost] pins it to a corner over your content, offset by the
/// safe area (the web version is `position: fixed`).
///
/// [tone] (0.44.0): [UiFabTone.danger] for SOS. [text] (0.44.0): an extended pill with the text after
/// the icon ("SOS"); the accessible name is still [label].
///
/// [hold] (0.44.0): press and hold that long to activate, as [UiHoldButton]: a fill grows across
/// the button while it is held, and [onPressed] is called at the end. A tap, a quick Enter / Space
/// or a screen reader's activation opens the confirm dialog ([confirmTitle], [confirmMessage],
/// [confirmLabel], [destructive]) instead; the button is announced with [holdHint]. For an SOS that
/// mustn't go off from a stray touch.
class UiFab extends StatelessWidget {
  const UiFab({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = UiFabSize.md,
    this.focusNode,
    this.tone = UiFabTone.primary,
    this.text,
    this.hold,
    this.holdHint,
    this.confirmTitle,
    this.confirmMessage = '',
    this.confirmLabel,
    this.destructive = false,
  });

  /// Press and hold this long to activate (0.44.0); null: an ordinary press.
  final Duration? hold;

  /// What holding does, read with the button; null: [UiStrings.holdHint].
  final String? holdHint;

  /// The tap fallback dialog (as [UiHoldButton]); titles default to [UiStrings.confirmTitle] and [UiStrings.confirm].
  final String? confirmTitle;
  final String confirmMessage;
  final String? confirmLabel;

  /// The dialog's confirm button is destructive.
  final bool destructive;

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final UiFabSize size;
  final FocusNode? focusNode;
  final UiFabTone tone;

  /// Shown after the icon in an extended pill; null for the round button.
  final String? text;

  @override
  Widget build(BuildContext context) {
    final hold = this.hold;
    if (hold == null) return _button(context, focusNode, onPressed, null);
    final t = context.ui;
    final danger = tone == UiFabTone.danger;
    return UiHoldActivator(
      onConfirmed: onPressed,
      hold: hold,
      confirmTitle: confirmTitle,
      confirmMessage: confirmMessage,
      confirmLabel: confirmLabel,
      destructive: destructive,
      fillColor: (danger ? t.dangerContrast : t.primaryContrast).withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(100),
      builder: (context, node, activate) => _button(context, node, activate, holdHint ?? context.uiStrings.holdHint),
    );
  }

  Widget _button(BuildContext context, FocusNode? focusNode, VoidCallback? onPressed, String? hint) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    final dim = size == UiFabSize.md ? 52.0 : (touch ? uiMinTouchTarget : 40.0);
    final animate = context.uiAnimate;
    final danger = tone == UiFabTone.danger;
    final fill = danger ? t.danger : t.primary;
    final hover = danger ? t.dangerHover : t.primaryHover;
    final ink = danger ? t.dangerContrast : t.primaryContrast;
    final iconSize = size == UiFabSize.md ? 22.0 : 18.0;
    final text = this.text;
    return UiInteractive(
      onTap: onPressed,
      enabled: onPressed != null,
      focusNode: focusNode,
      semanticLabel: label,
      semanticHint: hint,
      excludeChildSemantics: true,
      builder: (context, s) => AnimatedScale(
        scale: s.hovered && !s.pressed && animate ? 1.05 : 1,
        duration: t.motionFast,
        curve: t.easeSpring,
        child: AnimatedOpacity(
          opacity: s.disabled ? 0.5 : 1,
          duration: t.motionBase,
          child: AnimatedContainer(
            duration: animate ? t.motionBase : Duration.zero,
            curve: t.easeStandard,
            width: text == null ? dim : null,
            height: dim,
            padding: text == null ? null : EdgeInsetsDirectional.only(start: t.space4, end: t.space4 + 2),
            decoration: BoxDecoration(
              color: s.hovered || s.pressed ? hover : fill,
              borderRadius: BorderRadius.circular(dim / 2),
              boxShadow: [
                ...t.shadow2,
                // Danger: a soft halo in its colour and a ring of the raised surface, so it stands
                // out on any page, map or photo.
                if (danger) BoxShadow(color: t.danger.withValues(alpha: 0.30), spreadRadius: 9),
                if (danger) BoxShadow(color: t.surfaceRaised, spreadRadius: 3),
                if (s.focused) ...t.focusRing,
              ],
            ),
            // The round one centres its icon; the pill hugs its row (an alignment would stretch it).
            alignment: text == null ? Alignment.center : null,
            child: IconTheme.merge(
              data: IconThemeData(color: ink, size: iconSize),
              child: text == null
                  ? icon
                  : Row(mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
                      icon,
                      Text(text, maxLines: 1, style: context.uiText.label.copyWith(color: ink, fontSize: (size == UiFabSize.md ? 16 : 14) * context.ui.fontScale, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays [child] out full size and pins [fab] to a corner (or the middle of the top or bottom edge),
/// [UiTokens.space6] from the edges plus the device safe area (notches, the status bar, the gesture
/// bar), so a top button never covers the status bar.
///
/// The button is drawn above [child], so it stays above anything inside it: a [UiBottomSheet]
/// placed in the page's Stack, [UiSidebarLayout]'s drawer. To keep it above routes too (dialogs,
/// [showUiDrawer]), put the host in [UiApp.builder] around the navigator.
///
/// [topOffset] (0.44.0) moves a top button down by that many px, for an app bar over the page, so
/// it sits just under the bar instead of on it.
class UiFabHost extends StatelessWidget {
  const UiFabHost({super.key, required this.child, required this.fab, this.position = UiFabPosition.bottomEnd, this.topOffset = 0});

  final Widget child;
  final Widget fab;
  final UiFabPosition position;

  /// Px added above a top button (0.44.0): the app bar's height.
  final double topOffset;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final pad = MediaQuery.paddingOf(context);
    final top = position == UiFabPosition.topEnd || position == UiFabPosition.topStart || position == UiFabPosition.topCenter;
    final center = position == UiFabPosition.topCenter || position == UiFabPosition.bottomCenter;
    final end = position == UiFabPosition.bottomEnd || position == UiFabPosition.topEnd;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final startInset = rtl ? pad.right : pad.left, endInset = rtl ? pad.left : pad.right;
    return Stack(
      children: [
        Positioned.fill(child: child),
        PositionedDirectional(
          top: top ? t.space6 + pad.top + topOffset : null,
          bottom: top ? null : t.space6 + pad.bottom,
          end: center ? t.space6 + endInset : (end ? t.space6 + endInset : null),
          start: center ? t.space6 + startInset : (end ? null : t.space6 + startInset),
          child: center ? Center(widthFactor: 1, heightFactor: 1, child: fab) : fab,
        ),
      ],
    );
  }
}
