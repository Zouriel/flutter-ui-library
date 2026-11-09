import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/types.dart';
import '../theme/theme.dart';

/// `ui-device-frame`: a phone-shaped frame whose screen is exactly [width] × [height] logical px,
/// scaled down to fit the space it is given. [child] lays out at true phone size (a 390-wide page
/// lays out as on a phone) and is only scaled visually. [onScale] reports the scale actually drawn,
/// for overlays that must line up with the screen; [onFitScale] the scale at zoom 1, so the zoom can
/// be shown with 100% meaning "fits".
///
/// [zoom] multiplies the fitted scale (1 fits, 2 is twice that; kept within 0.25–8, not capped by
/// [maxScale]). Above 1 the frame scrolls both ways inside the space it was given, so every edge can
/// be reached; smaller, it stays centred. Pass [horizontalController] / [verticalController] to read
/// or move the scroll position, e.g. to zoom around a point (Ctrl+wheel, pinch): after the new zoom
/// has laid out, `jumpTo(UiDeviceFrame.anchoredOffset(...))` on each axis keeps the point under the
/// cursor still.
///
class UiDeviceFrame extends StatefulWidget {
  const UiDeviceFrame({
    super.key,
    required this.child,
    this.width = 390,
    this.height = 844,
    this.bezel = true,
    this.island = true,
    this.maxScale = 1,
    this.onScale,
    this.zoom = 1,
    this.onFitScale,
    this.horizontalController,
    this.verticalController,
  });

  final Widget child;
  final double width;
  final double height;

  /// The dark rim around the screen; off gives a plain rounded screen with a shadow.
  final bool bezel;

  /// The pill-shaped camera cut-out (only with [bezel]).
  final bool island;

  /// Never scale up past this.
  final double maxScale;
  final ValueChanged<double>? onScale;

  /// Multiplies the fitted scale; kept within 0.25–8.
  final double zoom;

  /// The scale at zoom 1 (fits the space, capped by [maxScale]).
  final ValueChanged<double>? onFitScale;

  /// Scroll positions while zoomed in (zoom above 1).
  final ScrollController? horizontalController;
  final ScrollController? verticalController;

  static const double _rim = 12;

  /// [zoom] as it is applied: within 0.25–8, and 1 when it isn't a number.
  static double clampZoom(double zoom) => zoom.isFinite ? zoom.clamp(0.25, 8).toDouble() : 1;

  /// The frame's size before scaling: the screen plus the bezel.
  Size get outerSize => Size(width + (bezel ? _rim * 2 : 0), height + (bezel ? _rim * 2 : 0));

  /// The scroll offset on one axis that keeps the point at [focal] (px from the visible area's start)
  /// still when the drawn scale changes from [oldScale] to [newScale]. [offset] is the offset before,
  /// [viewport] the visible size and [extent] the frame's unscaled size on that axis
  /// ([outerSize].width or .height). A frame smaller than the viewport is centred, so the point can
  /// only stay put where there is room to scroll; the result is clamped to the scroll range.
  static double anchoredOffset({
    required double offset,
    required double focal,
    required double viewport,
    required double extent,
    required double oldScale,
    required double newScale,
  }) {
    // A frame narrower than the viewport is centred: the padding before it shifts the point. After
    // the zoom there's either no such padding or no scroll range (the clamp gives 0), so only the
    // old padding matters.
    final pad = math.max(0.0, (viewport - extent * oldScale) / 2);
    final point = (offset + focal - pad) / oldScale;
    return (point * newScale - focal).clamp(0.0, math.max(0.0, extent * newScale - viewport)).toDouble();
  }

  /// The scale that fits a frame of [outer] size into [avail] (either side may be unbounded).
  static double fitScale(Size avail, Size outer, double maxScale) {
    final sx = avail.width.isFinite ? avail.width / outer.width : double.infinity;
    final sy = avail.height.isFinite ? avail.height / outer.height : double.infinity;
    final s = math.min(maxScale, math.min(sx, sy));
    return math.max(0.1, s);
  }

  @override
  State<UiDeviceFrame> createState() => _UiDeviceFrameState();
}

class _UiDeviceFrameState extends State<UiDeviceFrame> {
  double? _reported;
  double? _reportedFit;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final UiDeviceFrame(:width, :height, :bezel, :island, :maxScale, :onScale, :onFitScale, :child) = widget;
    final zoom = UiDeviceFrame.clampZoom(widget.zoom);
    final rim = bezel ? UiDeviceFrame._rim : 0.0;
    final outer = Size(width + rim * 2, height + rim * 2);
    return LayoutBuilder(builder: (context, box) {
      final fit = UiDeviceFrame.fitScale(box.biggest, outer, maxScale);
      final scale = fit * zoom;
      if (onScale != null && scale != _reported) {
        _reported = scale;
        WidgetsBinding.instance.addPostFrameCallback((_) => onScale(scale));
      }
      if (onFitScale != null && fit != _reportedFit) {
        _reportedFit = fit;
        WidgetsBinding.instance.addPostFrameCallback((_) => onFitScale(fit));
      }
      // Near-black whatever the theme, like a real handset.
      final body = uiMix(t.mediaOnScrim, 0.07, t.mediaBg);
      final screen = ClipRRect(
        borderRadius: BorderRadius.circular(bezel ? 42 : context.uiTheme.radius()),
        child: ColoredBox(
          color: t.bg,
          child: MediaQuery(
            // The content sees a phone, not the host screen.
            data: MediaQuery.of(context).copyWith(size: Size(width, height), padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
            child: SizedBox(width: width, height: height, child: child),
          ),
        ),
      );
      final device = Container(
        width: outer.width,
        height: outer.height,
        padding: EdgeInsets.all(rim),
        decoration: bezel
            ? BoxDecoration(
                color: body,
                borderRadius: BorderRadius.circular(54),
                boxShadow: t.shadow3,
              )
            : BoxDecoration(borderRadius: BorderRadius.circular(context.uiTheme.radius()), boxShadow: t.shadow2),
        // The rim's inner highlight, drawn on top so it doesn't eat into the screen's size.
        foregroundDecoration: bezel
            ? BoxDecoration(borderRadius: BorderRadius.circular(54), border: Border.all(color: t.mediaOnScrim.withValues(alpha: 0.12), width: 2))
            : null,
        child: Stack(children: [
          screen,
          if (bezel && island)
            Positioned(
              top: 11,
              left: (width - 110) / 2,
              child: IgnorePointer(
                // A faint rim, as the bezel has: on a dark screen a black island would vanish.
                child: Container(
                  width: 110,
                  height: 32,
                  decoration: BoxDecoration(color: t.mediaBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.mediaOnScrim.withValues(alpha: 0.12))),
                ),
              ),
            ),
        ]),
      );
      final drawn = SizedBox(
        width: outer.width * scale,
        height: outer.height * scale,
        child: FittedBox(fit: BoxFit.fill, alignment: Alignment.topLeft, child: device),
      );
      // At zoom 1 or less (or with no bounded space to scroll in) it fits: centred, as always.
      if (zoom <= 1 || !box.hasBoundedWidth || !box.hasBoundedHeight) return Center(child: drawn);
      // Zoomed in: scroll both ways. At least the viewport's size, so a frame narrower than the space
      // stays centred on that axis while the other one scrolls.
      return SingleChildScrollView(
        controller: widget.horizontalController,
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          controller: widget.verticalController,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: box.maxWidth, minHeight: box.maxHeight),
            child: Center(child: drawn),
          ),
        ),
      );
    });
  }
}
