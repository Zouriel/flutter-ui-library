import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/form_builder/editor/builder_dnd.dart';

/// Choosing where a dragged card lands; the same cases as the web's drop-index.spec.ts.
void main() {
  // A phone: three full-width cards, 80 tall with 10px gaps. The grip is at the left edge.
  final column = [const Rect.fromLTWH(0, 0, 360, 80), const Rect.fromLTWH(0, 90, 360, 80), const Rect.fromLTWH(0, 180, 360, 80)];

  test('a card alone on its row: the top half is before it, the bottom half after it, wherever x is', () {
    expect(fbDropIndex(column, const Offset(12, 100)), 1);
    expect(fbDropIndex(column, const Offset(12, 150)), 2);
    expect(fbDropIndex(column, const Offset(340, 150)), 2);
  });

  test('dragging the first card by its grip onto the lower half of the next moves it down one', () {
    expect(fbDropIndex(column, const Offset(12, 160)), 2);
  });

  test('gaps and the ends', () {
    expect(fbDropIndex(column, const Offset(12, -5)), 0);
    expect(fbDropIndex(column, const Offset(12, 85)), 1);
    expect(fbDropIndex(column, const Offset(12, 400)), 3);
  });

  test('cards sharing a row still split by their left and right halves', () {
    final grid = [const Rect.fromLTWH(0, 0, 175, 80), const Rect.fromLTWH(185, 0, 175, 80), const Rect.fromLTWH(0, 90, 360, 80)];
    expect(fbDropIndex(grid, const Offset(40, 60)), 0);
    expect(fbDropIndex(grid, const Offset(150, 60)), 1);
    expect(fbDropIndex(grid, const Offset(300, 10)), 2);
  });
}
