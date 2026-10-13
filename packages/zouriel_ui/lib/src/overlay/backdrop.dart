import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// `ui-backdrop`: the dimmed layer behind an overlay of your own. Fills its parent (put it in a
/// `Stack` or an overlay), fades in when it appears, and reports taps through [onTap] so you can
/// close what it sits behind. It does nothing else: focus, Escape/back and scroll are up to you
/// (the dialogs in this library use routes, which handle those).
///
/// With [blur] it also blurs what is behind it. Hidden from screen readers unless [semanticLabel]
/// is set, in which case it is announced as a control that dismisses (e.g. "Close").
class UiBackdrop extends StatelessWidget {
  const UiBackdrop({super.key, this.onTap, this.blur = false, this.semanticLabel, this.opacity});

  final VoidCallback? onTap;
  final bool blur;
  final String? semanticLabel;

  /// Drive the fade yourself (e.g. with a route animation). By default it fades in once on mount.
  final Animation<double>? opacity;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    Widget layer = ColoredBox(color: t.overlay, child: const SizedBox.expand());
    if (blur) {
      layer = ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3), child: layer));
    }
    final a = opacity;
    if (a != null) {
      layer = FadeTransition(opacity: a, child: layer);
    } else if (context.uiAnimate) {
      layer = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: t.motionBase,
        curve: t.easeStandard,
        builder: (context, v, child) => Opacity(opacity: v, child: child),
        child: layer,
      );
    }
    final label = semanticLabel;
    return Semantics(
      excludeSemantics: true,
      label: label,
      onTap: label != null ? onTap : null,
      onDismiss: label != null ? onTap : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: layer,
      ),
    );
  }
}
