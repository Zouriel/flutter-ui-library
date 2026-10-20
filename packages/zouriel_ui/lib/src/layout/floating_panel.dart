import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Which edge of its Stack a [UiFloatingPanel] floats over.
enum UiFloatingPanelPlacement { bottom, top }

/// `ui-floating-panel`: a raised surface floating over the bottom (or top) of a [Stack]: the
/// details card over a map. Put it in the Stack directly (it is a [Positioned]).
///
/// Non-modal: it takes no focus and only its own box takes touches, so what's around it stays
/// usable and draggable. It sits 16px in from the edges plus the device's safe-area insets (the
/// MediaQuery padding), up to [maxWidth] wide and centred, so it fits a 390px phone with a 16px
/// gutter. With [semanticLabel] it is a named container for screen readers.
class UiFloatingPanel extends StatelessWidget {
  const UiFloatingPanel({
    super.key,
    required this.child,
    this.placement = UiFloatingPanelPlacement.bottom,
    this.semanticLabel,
    this.maxWidth = 480,
    this.glass,
    this.radius,
  });

  final Widget child;
  final UiFloatingPanelPlacement placement;
  final String? semanticLabel;
  final double maxWidth;
  final bool? glass;
  final bool? radius;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final pad = MediaQuery.paddingOf(context);
    final gutter = t.space4;
    final isGlass = glass ?? theme.config.glass;
    final r = (radius ?? theme.config.radius) ? t.radiusLg : 0.0;
    final top = placement == UiFloatingPanelPlacement.top;
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: isGlass ? t.glassBg : t.surfaceRaised,
        border: Border.all(color: isGlass ? t.glassBorder : t.border),
        borderRadius: BorderRadius.circular(r),
        boxShadow: t.shadow3,
      ),
      child: Padding(
        padding: EdgeInsets.all(t.space4),
        child: DefaultTextStyle.merge(style: TextStyle(color: t.text), child: child),
      ),
    );
    if (isGlass) {
      surface = ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: t.glassBlur / 2, sigmaY: t.glassBlur / 2), child: surface),
      );
    }
    Widget panel = Semantics(container: true, explicitChildNodes: true, label: semanticLabel, child: surface);
    if (context.uiAnimate) {
      panel = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: t.motionBase,
        curve: t.easeDecelerate,
        builder: (context, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, (top ? -8 : 8) * (1 - v)), child: child),
        ),
        child: panel,
      );
    }
    return Positioned(
      left: gutter + pad.left,
      right: gutter + pad.right,
      top: top ? gutter + pad.top : null,
      bottom: top ? null : gutter + pad.bottom,
      child: Align(
        alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
        heightFactor: 1,
        // As wide as there is room for, up to maxWidth.
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: math.max(0, maxWidth)), child: SizedBox(width: double.infinity, child: panel)),
      ),
    );
  }
}
