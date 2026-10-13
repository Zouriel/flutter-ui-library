import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../theme/theme.dart';

/// Which corner a [UiFab] sits in.
enum UiFabPosition { bottomEnd, bottomStart, topEnd, topStart }

/// FAB diameters: 40 (sm, grown to 48 on phones) or 52 (md).
enum UiFabSize { sm, md }

/// `ui-fab`: the floating action button, a round primary button with a shadow. [label] is required:
/// it is the accessible name. Grows a little on hover, shrinks when pressed.
///
/// On its own it is just the button; [UiFabHost] pins it to a corner over your content, offset by the
/// safe area (the web version is `position: fixed`).
class UiFab extends StatelessWidget {
  const UiFab({super.key, required this.icon, required this.label, required this.onPressed, this.size = UiFabSize.md, this.focusNode});

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final UiFabSize size;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    final dim = size == UiFabSize.md ? 52.0 : (touch ? uiMinTouchTarget : 40.0);
    final animate = context.uiAnimate;
    return UiInteractive(
      onTap: onPressed,
      enabled: onPressed != null,
      focusNode: focusNode,
      semanticLabel: label,
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
            width: dim,
            height: dim,
            decoration: BoxDecoration(
              color: s.hovered || s.pressed ? t.primaryHover : t.primary,
              shape: BoxShape.circle,
              boxShadow: [...t.shadow2, if (s.focused) ...t.focusRing],
            ),
            alignment: Alignment.center,
            child: IconTheme.merge(data: IconThemeData(color: t.primaryContrast, size: size == UiFabSize.md ? 22 : 18), child: icon),
          ),
        ),
      ),
    );
  }
}

/// Lays [child] out full size and pins [fab] to a corner, [UiTokens.space6] from the edges plus the
/// device safe area (notches, gesture bar).
class UiFabHost extends StatelessWidget {
  const UiFabHost({super.key, required this.child, required this.fab, this.position = UiFabPosition.bottomEnd});

  final Widget child;
  final Widget fab;
  final UiFabPosition position;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final pad = MediaQuery.paddingOf(context);
    final top = position == UiFabPosition.topEnd || position == UiFabPosition.topStart;
    final end = position == UiFabPosition.bottomEnd || position == UiFabPosition.topEnd;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final startInset = rtl ? pad.right : pad.left, endInset = rtl ? pad.left : pad.right;
    return Stack(
      children: [
        Positioned.fill(child: child),
        PositionedDirectional(
          top: top ? t.space6 + pad.top : null,
          bottom: top ? null : t.space6 + pad.bottom,
          end: end ? t.space6 + endInset : null,
          start: end ? null : t.space6 + startInset,
          child: fab,
        ),
      ],
    );
  }
}
