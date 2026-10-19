import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

part 'sea_shapes.g.dart';

/// A sea shape part's colour role (the web `UiSeaTone`).
enum UiSeaTone { lagoon, coral, sand, oceanDeep }

/// The colour of [tone] in the current theme: the maldives brand colour, or a theme role elsewhere
/// (the web `UI_SEA_TONES`).
Color uiSeaTone(UiTokens t, UiSeaTone tone) => switch (tone) {
      UiSeaTone.lagoon => t.lagoon ?? t.secondary,
      UiSeaTone.coral => t.coral ?? t.accent,
      UiSeaTone.sand => t.sand ?? t.surfaceRaised,
      UiSeaTone.oceanDeep => t.oceanDeep ?? t.primary,
    };

/// One path of a sea shape, filled, or stroked with round caps when [stroke] is set.
@immutable
class UiSeaShapePart {
  const UiSeaShapePart({required this.tone, required this.ops, this.stroke, this.opacity});

  final UiSeaTone tone;

  /// Stroke width in shape units; null fills the path.
  final double? stroke;
  final double? opacity;

  /// The path as opcodes and their points: 0 = move x y, 1 = line x y, 2 = cubic x1 y1 x2 y2 x y, 3 = close.
  final List<double> ops;

  /// The path in shape units.
  Path toPath() {
    final p = Path();
    var i = 0;
    while (i < ops.length) {
      switch (ops[i].toInt()) {
        case 0:
          p.moveTo(ops[i + 1], ops[i + 2]);
          i += 3;
        case 1:
          p.lineTo(ops[i + 1], ops[i + 2]);
          i += 3;
        case 2:
          p.cubicTo(ops[i + 1], ops[i + 2], ops[i + 3], ops[i + 4], ops[i + 5], ops[i + 6]);
          i += 7;
        default:
          p.close();
          i += 1;
      }
    }
    return p;
  }
}

/// A silhouette from the shared SVG sources: its viewBox [size] and its parts, back to front.
@immutable
class UiSeaShape {
  const UiSeaShape({required this.size, required this.parts});

  final Size size;
  final List<UiSeaShapePart> parts;
}

/// The shared sea shapes by name (the web `UI_SEA_SHAPES`).
const Map<String, UiSeaShape> uiSeaShapes = {
  'wave1': _wave1,
  'wave2': _wave2,
  'wave3': _wave3,
  'coral': _coral,
  'palm': _palm,
};
