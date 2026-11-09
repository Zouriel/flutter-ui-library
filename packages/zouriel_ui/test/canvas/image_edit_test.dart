import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

UiImageRaster _blank(int w, int h) => UiImageRaster(w, h, Uint8List(w * h * 4)..fillRange(0, w * h * 4, 255));

/// The same cases and numbers as the web library's `image-edit.spec.ts`, so both land on the same pixels.
void main() {
  test('brushFalloff: full inside, none outside, smooth in between when soft', () {
    expect(brushFalloff(0, 10, 0), 1);
    expect(brushFalloff(9, 10, 0), 1);
    expect(brushFalloff(10, 10, 0), 0.5);
    expect(brushFalloff(11, 10, 0), 0);
    expect(brushFalloff(0, 10, 1), 1);
    expect(brushFalloff(5, 10, 1), closeTo(0.5, 1e-6));
    expect(brushFalloff(10, 10, 1), 0);
    expect(brushFalloff(5, 10, 0.5), 1);
    expect(brushFalloff(7.5, 10, 0.5), closeTo(0.5, 1e-6));
  });

  test('run-length encoding round-trips, and is small for a plain mask', () {
    final bytes = Uint8List(4096)..fillRange(0, 4096, 255);
    bytes.fillRange(100, 900, 0);
    bytes[2000] = 17;
    final rle = rleEncode(bytes);
    expect(rle.length, lessThan(100));
    expect(rleDecode(rle, Uint8List(4096)), bytes);
  });

  test('clampCrop keeps a crop whole-pixel, inside and at least 8 px', () {
    expect(clampCrop(-5.4, 3.6, 300, 2, 200, 100), const UiImageCrop(0, 4, 200, 8));
  });

  test('fitAspect finds the largest frame of a shape, centred', () {
    expect(fitAspect(const UiImageCrop(0, 0, 200, 100), 1, 200, 100), const UiImageCrop(50, 0, 100, 100));
    expect(fitAspect(const UiImageCrop(0, 0, 200, 100), 4, 200, 100), const UiImageCrop(0, 25, 200, 50));
  });

  test('dragCrop with an aspect keeps the opposite corner still and fits in the picture', () {
    const start = UiImageCrop(50, 0, 100, 100);
    final c = dragCrop(start, UiCropHandle.nw, 30, 10, 200, 100, 1);
    expect(c.x + c.width, 150);
    expect(c.y + c.height, 100);
    expect(c.width, c.height);
    expect(dragCrop(start, UiCropHandle.se, 500, 500, 200, 100, 1), start);
    final top = dragCrop(const UiImageCrop(50, 20, 60, 60), UiCropHandle.n, 0, -15, 200, 100, 1);
    expect(top.width, top.height);
    expect(top.y + top.height, 80);
    // Same rounding as the web: x 42.5 rounds up to 43.
    expect(top, const UiImageCrop(43, 5, 75, 75));
  });

  test('uiWorkingSize keeps a picture under 4096 px on its long side', () {
    expect(uiWorkingSize(1200, 800), (1200, 800));
    expect(uiWorkingSize(8192, 2048), (4096, 1024));
    expect(uiWorkingSize(3000, 9000), (1365, 4096));
  });

  test('cancelStroke puts the mask back', () {
    final e = UiImageEdit(_blank(100, 100));
    e.beginStroke(UiImageEditorMode.erase, 50, 50, 20, 0);
    e.strokeTo(80, 50);
    expect(e.maskAt(50, 50), 0);
    e.cancelStroke();
    expect(e.maskAt(50, 50), 255);
    expect(e.canUndo, isFalse);
    expect(e.dirty, isFalse);
  });

  test('history keeps 100 steps, and stays small for strokes over a big picture', () {
    final e = UiImageEdit(_blank(2000, 2000));
    for (var i = 0; i < 120; i++) {
      e.beginStroke(i.isOdd ? UiImageEditorMode.restore : UiImageEditorMode.erase, 0, (i * 16) % 2000, 300, 0.3);
      e.strokeTo(2000, ((i * 16) % 2000).toDouble());
      e.endStroke();
    }
    expect(e.stepCount, 100);
    expect(e.historyBytes, lessThan(8 * 1024 * 1024));
  });
}
