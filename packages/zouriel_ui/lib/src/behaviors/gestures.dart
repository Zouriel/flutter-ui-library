import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The arithmetic behind a swipe, shared by [UiSwipe], the image viewer and the lightbox so a swipe
/// means the same distance and the same flick everywhere (the web `gestures.ts`).
abstract final class UiGestures {
  /// How far a drag must travel (a share of the width, floored and capped) to count as a swipe.
  static const double swipeFraction = 0.2;
  static const double swipeMin = 32;
  static const double swipeMax = 72;

  /// A short, fast drag counts even when it falls short of the distance above.
  static const double flickDistance = 24;

  /// px per ms.
  static const double flickSpeed = 0.4;

  /// How much of a drag survives when there is nothing to swipe to in that direction.
  static const double rubberBand = 0.25;

  /// Whether a drag of ([dx], [dy]) over [ms] milliseconds was a swipe across something [width]
  /// wide. A drag that went further down than across never is.
  static bool isSwipe(double dx, double dy, double ms, double width) {
    if (dx.abs() <= dy.abs()) return false;
    final far = dx.abs() >= math.min(swipeMax, math.max(swipeMin, width * swipeFraction));
    final flick = dx.abs() >= flickDistance && dx.abs() / math.max(1, ms) >= flickSpeed;
    return far || flick;
  }

  /// How far the content moves for a drag of [dx]: with the finger toward a neighbour, a little
  /// and back toward nothing ([blocked]). Capped at [width] either way.
  static double resist(double dx, double width, {required bool blocked}) {
    final capped = width > 0 ? dx.clamp(-width, width).toDouble() : dx;
    return blocked ? capped * rubberBand : capped;
  }

  /// Keeps a zoomed picture reachable: the offset that keeps [content] scaled by [zoom] covering as
  /// much of [stage] as it can.
  static Offset clampOffset(Offset offset, Size content, Size stage, double zoom) {
    final maxX = math.max(0.0, (content.width * zoom - stage.width) / 2);
    final maxY = math.max(0.0, (content.height * zoom - stage.height) / 2);
    return Offset(offset.dx.clamp(-maxX, maxX), offset.dy.clamp(-maxY, maxY));
  }
}
