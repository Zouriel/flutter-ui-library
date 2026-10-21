import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

/// The see-through glass of [UiBottomSheet.glass] and [UiFloatingPanel.glass] (0.41.2), the twin
/// of the web `--ui-glass-clear-*` and `--ui-glass-sheet-*` tokens: the theme's surface, a little of
/// it, over a blurred backdrop whose every channel is first squeezed into a per-theme floor..ceiling
/// range. How much of each is [UiGlassStrength]:
///
/// - [UiGlassStrength.clear] (the default, 0.41.3): for a map in the theme's own brightness (light
///   tiles under a light theme, dark under a dark one). [UiTokens.glassClearTint] (12%) over a light
///   blur, squeezed into [UiTokens.glassClearFloor]..[UiTokens.glassClearCeiling] only as far as
///   text, muted text, primary and status colours (4.5:1) and icons and warning (3:1) need over the
///   colours such a map is drawn in, then [UiTokens.glassClearSaturate] so water and parks stay
///   apart. Roads and the coastline plainly show through.
/// - [UiGlassStrength.frosted] (0.41.2's glass): [UiTokens.glassSheetTint] (60%) over a heavy blur
///   squeezed into [UiTokens.glassSheetFloor]..[UiTokens.glassSheetCeiling], which keeps those colours
///   AA over any backdrop, pure white and pure black included. For photos, or a map in the other
///   brightness.

/// How see-through a glass [UiBottomSheet] or [UiFloatingPanel] is (0.41.3); see above.
enum UiGlassStrength {
  /// A map in the theme's brightness plainly shows through; text AA over such a map.
  clear,

  /// Near-opaque; text AA over anything.
  frosted,
}

/// The colour matrix that maps each backdrop channel v (0-1) to floor + v * (ceiling - floor) (the
/// web's `contrast()` + `brightness()` pair) and, for [UiGlassStrength.clear], then saturates it as
/// CSS `saturate()` does. Offsets are in 0-255, as [ColorFilter.matrix] takes them. [strength]
/// defaults to frosted, as before 0.41.3; the widgets default to clear.
List<double> uiGlassSheetMatrix(UiTokens t, {UiGlassStrength strength = UiGlassStrength.frosted}) {
  final clear = strength == UiGlassStrength.clear;
  final floor = clear ? t.glassClearFloor : t.glassSheetFloor;
  final k = (clear ? t.glassClearCeiling : t.glassSheetCeiling) - floor;
  final o = floor * 255;
  final s = clear ? t.glassClearSaturate : 1.0;
  // CSS saturate(s), Filter Effects spec. Its rows sum to 1, so a grey offset passes through it unchanged.
  final m = <List<double>>[
    [0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s],
    [0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s],
    [0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s],
  ];
  return <double>[
    for (final row in m) ...[k * row[0], k * row[1], k * row[2], 0, o],
    0, 0, 0, 1, 0, //
  ];
}

/// Blur, then squeeze into the theme's backdrop range ([uiGlassSheetMatrix]), for a [BackdropFilter].
/// The web blur radius is a CSS length; Flutter's sigma is half of it, as for the other glass.
ImageFilter uiGlassSheetFilter(UiTokens t, {UiGlassStrength strength = UiGlassStrength.frosted}) {
  final blur = (strength == UiGlassStrength.clear ? t.glassClearBlur : t.glassSheetBlur) / 2;
  return ImageFilter.compose(
    outer: ColorFilter.matrix(uiGlassSheetMatrix(t, strength: strength)),
    inner: ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.clamp),
  );
}

/// The translucent surface tint drawn over the filtered backdrop ([UiTokens.glassClearBg] or
/// [UiTokens.glassSheetBg]).
Color uiGlassSheetTint(UiTokens t, {UiGlassStrength strength = UiGlassStrength.frosted}) =>
    strength == UiGlassStrength.clear ? t.glassClearBg : t.glassSheetBg;

/// Whether see-through glass should be drawn solid here. Flutter has no "reduce transparency"
/// setting (the web's `prefers-reduced-transparency`), so this follows the platform's high-contrast
/// setting (iOS Increase Contrast, Android high-contrast text), as the web also does for
/// `prefers-contrast: more`.
bool uiGlassSheetSolid(BuildContext context) => MediaQuery.maybeHighContrastOf(context) ?? false;

/// Paints [shadows] around a rounded box only outside it, as CSS `box-shadow` does, so a
/// see-through surface over it isn't darkened by its own shadow (a [BoxDecoration] shadow is drawn
/// under the whole box).
class UiOutsetShadow extends SingleChildRenderObjectWidget {
  const UiOutsetShadow({super.key, required this.shadows, required this.borderRadius, super.child});

  final List<BoxShadow> shadows;
  final BorderRadius borderRadius;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderOutsetShadow(shadows, borderRadius);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) => (renderObject as _RenderOutsetShadow)
    ..shadows = shadows
    ..borderRadius = borderRadius;
}

class _RenderOutsetShadow extends RenderProxyBox {
  _RenderOutsetShadow(this._shadows, this._borderRadius);

  List<BoxShadow> _shadows;
  set shadows(List<BoxShadow> v) {
    if (v == _shadows) return;
    _shadows = v;
    markNeedsPaint();
  }

  BorderRadius _borderRadius;
  set borderRadius(BorderRadius v) {
    if (v == _borderRadius) return;
    _borderRadius = v;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_shadows.isNotEmpty) {
      final canvas = context.canvas;
      final box = _borderRadius.toRRect(offset & size);
      canvas.save();
      canvas.clipPath(Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(box.outerRect.inflate(1e5))
        ..addRRect(box));
      for (final s in _shadows) {
        canvas.drawRRect(box.shift(s.offset).inflate(s.spreadRadius), s.toPaint());
      }
      canvas.restore();
    }
    super.paint(context, offset);
  }
}
