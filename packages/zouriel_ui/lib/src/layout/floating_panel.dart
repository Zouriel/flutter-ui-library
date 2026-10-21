import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../theme/glass_sheet.dart';
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
///
/// [onCoverChanged] reports how much of the Stack's edge it covers, in px (its gutter, the safe
/// area and its height), whenever that changes: feed it to a map's `viewInsets` so the map centres
/// below a status card at the top.
///
/// [glass] (0.41.2) is the same see-through surface as [UiBottomSheet.glass]: the theme's surface at
/// 60% over a blurred backdrop squeezed into the theme's range, so text stays AA over any map (see
/// [uiGlassSheetFilter]); solid under the platform's high-contrast setting ([uiGlassSheetSolid]).
class UiFloatingPanel extends StatelessWidget {
  const UiFloatingPanel({
    super.key,
    required this.child,
    this.placement = UiFloatingPanelPlacement.bottom,
    this.semanticLabel,
    this.maxWidth = 480,
    this.glass,
    this.radius,
    this.onCoverChanged,
  });

  /// Px of the Stack's edge (top or bottom, per [placement]) it covers: gutter, safe area and height.
  final ValueChanged<double>? onCoverChanged;

  final Widget child;
  final UiFloatingPanelPlacement placement;
  final String? semanticLabel;
  final double maxWidth;

  /// See-through frosted surface over a map, as [UiBottomSheet.glass]. Defaults to [UiConfig.glass].
  final bool? glass;
  final bool? radius;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final pad = MediaQuery.paddingOf(context);
    final gutter = t.space4;
    final isGlass = (glass ?? theme.config.glass) && !uiGlassSheetSolid(context);
    final r = (radius ?? theme.config.radius) ? t.radiusLg : 0.0;
    final top = placement == UiFloatingPanelPlacement.top;
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: isGlass ? t.glassSheetBg : t.surfaceRaised,
        border: Border.all(color: isGlass ? t.glassBorder : t.border),
        borderRadius: BorderRadius.circular(r),
        // Glass: the shadow goes around it (UiOutsetShadow below), not under the see-through fill.
        boxShadow: isGlass ? null : t.shadow3,
      ),
      child: Padding(
        padding: EdgeInsets.all(t.space4),
        child: DefaultTextStyle.merge(style: TextStyle(color: t.text), child: child),
      ),
    );
    if (isGlass) {
      surface = UiOutsetShadow(
        shadows: t.shadow3,
        borderRadius: BorderRadius.circular(r),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: BackdropFilter(filter: uiGlassSheetFilter(t), child: surface),
        ),
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
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: math.max(0, maxWidth)),
          child: SizedBox(
            width: double.infinity,
            child: onCoverChanged == null
                ? panel
                : _HeightReporter(onHeight: (h) => onCoverChanged!(h + gutter + (top ? pad.top : pad.bottom)), child: panel),
          ),
        ),
      ),
    );
  }
}

/// Reports its child's laid-out height after the frame, whenever it changes (the entry slide is a
/// paint transform, so it doesn't count).
class _HeightReporter extends SingleChildRenderObjectWidget {
  const _HeightReporter({required this.onHeight, super.child});
  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHeightReporter(onHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderHeightReporter renderObject) => renderObject.onHeight = onHeight;
}

class _RenderHeightReporter extends RenderProxyBox {
  _RenderHeightReporter(this.onHeight);
  ValueChanged<double> onHeight;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final h = size.height;
    if (h == _last) return;
    _last = h;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached && _last == h) onHeight(h);
    });
  }
}
