import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/types.dart';
import '../theme/theme.dart';

/// `ui-device-frame`: a phone-shaped frame whose screen is exactly [width] × [height] logical px,
/// scaled down to fit the space it is given. [child] lays out at true phone size (a 390-wide page
/// lays out as on a phone) and is only scaled visually. [onScale] reports the scale, for overlays
/// that must line up with the screen.
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

  static const double _rim = 12;

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

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final UiDeviceFrame(:width, :height, :bezel, :island, :maxScale, :onScale, :child) = widget;
    final rim = bezel ? UiDeviceFrame._rim : 0.0;
    final outer = Size(width + rim * 2, height + rim * 2);
    return LayoutBuilder(builder: (context, box) {
      final scale = UiDeviceFrame.fitScale(box.biggest, outer, maxScale);
      if (onScale != null && scale != _reported) {
        _reported = scale;
        WidgetsBinding.instance.addPostFrameCallback((_) => onScale(scale));
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
                child: Container(width: 110, height: 32, decoration: BoxDecoration(color: t.mediaBg, borderRadius: BorderRadius.circular(20))),
              ),
            ),
        ]),
      );
      return Center(
        child: SizedBox(
          width: outer.width * scale,
          height: outer.height * scale,
          child: FittedBox(fit: BoxFit.fill, alignment: Alignment.topLeft, child: device),
        ),
      );
    });
  }
}
