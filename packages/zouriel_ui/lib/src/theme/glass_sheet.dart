import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

/// The see-through glass of [UiBottomSheet.glass] and [UiFloatingPanel.glass] (0.41.2), the twin
/// of the web `--ui-glass-sheet-*` tokens: the theme's surface at [UiTokens.glassSheetTint] over a
/// blurred backdrop whose every channel is first squeezed into
/// [UiTokens.glassSheetFloor]..[UiTokens.glassSheetCeiling]. Those two are set per theme so text,
/// muted text, primary and status colours keep WCAG AA over any backdrop, pure white and pure black
/// included.

/// The colour matrix that maps each backdrop channel v (0-1) to floor + v * (ceiling - floor): the
/// web's `contrast()` + `brightness()` pair. Offsets are in 0-255, as [ColorFilter.matrix] takes them.
List<double> uiGlassSheetMatrix(UiTokens t) {
  final k = t.glassSheetCeiling - t.glassSheetFloor;
  final o = t.glassSheetFloor * 255;
  return <double>[
    k, 0, 0, 0, o, //
    0, k, 0, 0, o, //
    0, 0, k, 0, o, //
    0, 0, 0, 1, 0, //
  ];
}

/// Blur, then squeeze into the theme's backdrop range ([uiGlassSheetMatrix]), for a [BackdropFilter].
/// The web blur radius is a CSS length; Flutter's sigma is half of it, as for the other glass.
ImageFilter uiGlassSheetFilter(UiTokens t) => ImageFilter.compose(
      outer: ColorFilter.matrix(uiGlassSheetMatrix(t)),
      inner: ImageFilter.blur(sigmaX: t.glassSheetBlur / 2, sigmaY: t.glassSheetBlur / 2, tileMode: TileMode.clamp),
    );

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
