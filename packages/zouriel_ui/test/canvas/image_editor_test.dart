import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

const int _w = 200;
const int _h = 100;

/// A picture whose red channel is x and green is y, so an exported pixel says where it came from.
UiImageRaster _picture([int width = _w, int height = _h]) {
  final data = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      data[i] = x & 255;
      data[i + 1] = y & 255;
      data[i + 2] = 7;
      data[i + 3] = 255;
    }
  }
  return UiImageRaster(width, height, data);
}

final _raster = _picture();

/// The editor fills 400 x 300 and leaves 24 px around what it frames. Crop mode frames the whole
/// picture; erase and restore frame the crop. Call [_frame] after anything that refits the view
/// (loading, switching between crop and erase).
class _View {
  _View(this.center, this.px);
  final Offset center;
  final double px;
  Offset at(double x, double y) => Offset(200 + (x - center.dx) * px, 150 + (y - center.dy) * px);
}

double _fitScale(double w, double h) => math.min((400 - 48) / w, (300 - 48) / h);

_View _frame(UiImageEditorController c) {
  final whole = UiImageCrop(0, 0, _w, _h);
  final f = c.mode == UiImageEditorMode.crop ? whole : c.crop!;
  final base = _fitScale(_w.toDouble(), _h.toDouble());
  final zoom = (_fitScale(f.width.toDouble(), f.height.toDouble()) / base).clamp(0.5, 64.0);
  return _View(f.rect.center, base * zoom);
}

class _Host extends StatelessWidget {
  const _Host({required this.controller, this.onChanged, this.fingerDraws});
  final UiImageEditorController controller;
  final VoidCallback? onChanged;
  final bool? fingerDraws;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 400,
        height: 300,
        child: UiImageEditor(controller: controller, raster: _raster, onChanged: onChanged, fingerDraws: fingerDraws),
      );
}

/// A phone's touch slop (Flutter tests default to 18 px; a real device reports about 8 dp).
void _phoneSlop(WidgetTester tester) {
  tester.view.gestureSettings = ui.GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
}

Future<void> _drag(WidgetTester tester, _View v, List<(double, double)> path, {PointerDeviceKind kind = PointerDeviceKind.mouse, int pointer = 1}) async {
  final g = await tester.startGesture(v.at(path.first.$1, path.first.$2), kind: kind, pointer: pointer);
  for (final p in path.skip(1)) {
    await g.moveTo(v.at(p.$1, p.$2));
  }
  await g.up();
  await tester.pump();
}

int _alpha(UiImageRaster r, int x, int y) => r.data[(y * r.width + x) * 4 + 3];
List<int> _px(UiImageRaster r, int x, int y) => r.data.sublist((y * r.width + x) * 4, (y * r.width + x) * 4 + 4);

void main() {
  late UiImageEditorController c;
  late int changes;

  Future<_View> pump(WidgetTester tester, {UiImageEditorMode mode = UiImageEditorMode.erase, double size = 20, double softness = 0, bool? fingerDraws}) async {
    c = UiImageEditorController(mode: mode, brushSize: size, brushSoftness: softness);
    changes = 0;
    await pumpUi(tester, _Host(controller: c, onChanged: () => changes++, fingerDraws: fingerDraws), size: const Size(800, 600));
    return _frame(c);
  }

  Future<_View> setMode(WidgetTester tester, UiImageEditorMode mode) async {
    c.mode = mode;
    await tester.pump();
    return _frame(c);
  }

  testWidgets('loads the picture with the whole picture as the crop', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    expect(c.loaded, isTrue);
    expect(c.naturalSize, const Size(200, 100));
    expect(c.crop, const UiImageCrop(0, 0, 200, 100));
    expect(c.dirty, isFalse);
    expect(c.canUndo, isFalse);
    final data = tester.getSemantics(find.bySemanticsLabel('Picture editor')).getSemanticsData();
    expect(data.label, 'Picture editor');
    expect(data.value, contains('erase mode'));
    handle.dispose();
  });

  group('erase and restore', () {
    testWidgets('erasing makes the pixels it passes over transparent, and nothing else', (tester) async {
      final v = await pump(tester);
      await _drag(tester, v, [(20, 50), (60, 50), (100, 50), (140, 50), (180, 50)]);
      expect(changes, 1);
      expect(c.dirty, isTrue);
      final r = c.toRgba();
      expect((r.width, r.height), (200, 100));
      for (final x in [20, 50, 100, 150, 180]) {
        expect(_alpha(r, x, 50), 0, reason: 'x $x');
      }
      expect(_alpha(r, 100, 30), 255);
      expect(_alpha(r, 100, 70), 255);
      expect(_alpha(r, 5, 50), 255);
      expect(_alpha(r, 195, 50), 255);
      expect(_px(r, 100, 10), [100, 10, 7, 255]);
    });

    testWidgets('restore paints the original back', (tester) async {
      var v = await pump(tester);
      await _drag(tester, v, [(20, 50), (180, 50)]);
      v = await setMode(tester, UiImageEditorMode.restore);
      await _drag(tester, v, [(90, 50), (110, 50)]);
      final r = c.toRgba();
      expect(_alpha(r, 100, 50), 255);
      expect(_px(r, 100, 50), [100, 50, 7, 255]);
      expect(_alpha(r, 50, 50), 0);
      expect(_alpha(r, 150, 50), 0);
    });

    testWidgets('a soft brush leaves partial alpha towards its edge; a hard one does not', (tester) async {
      final v = await pump(tester, size: 40, softness: 1);
      await _drag(tester, v, [(100, 50), (100, 50)]);
      var r = c.toRgba();
      expect(_alpha(r, 100, 50), lessThan(10));
      expect(_alpha(r, 110, 50), inInclusiveRange(61, 199));
      expect(_alpha(r, 125, 50), 255);
      c.undo();
      c.brushSoftness = 0;
      await _drag(tester, v, [(100, 50), (100, 50)]);
      r = c.toRgba();
      expect(_alpha(r, 100, 50), 0);
      expect(_alpha(r, 110, 50), 0);
      expect(_alpha(r, 125, 50), 255);
    });

    testWidgets('two fingers navigate and leave no paint, even after the first started a stroke', (tester) async {
      _phoneSlop(tester);
      final v = await pump(tester);
      final a = await tester.startGesture(v.at(50, 50), kind: PointerDeviceKind.touch, pointer: 1);
      await a.moveTo(v.at(60, 50));
      await tester.pump();
      final b = await tester.startGesture(v.at(120, 50), kind: PointerDeviceKind.touch, pointer: 2);
      await a.moveTo(v.at(40, 50));
      await b.moveTo(v.at(140, 50));
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pump();
      expect(c.canUndo, isFalse);
      expect(c.dirty, isFalse);
      expect(changes, 0);
      final r = c.toRgba();
      expect(_alpha(r, 50, 50), 255);
      expect(_alpha(r, 60, 50), 255);
    });

    testWidgets('one finger paints inside a scroll view without scrolling it', (tester) async {
      _phoneSlop(tester);
      c = UiImageEditorController(brushSize: 20, brushSoftness: 0);
      final scroll = ScrollController();
      await pumpUi(
        tester,
        SizedBox(
          width: 400,
          height: 600,
          child: SingleChildScrollView(
            controller: scroll,
            child: Column(children: [_Host(controller: c), const SizedBox(height: 2000)]),
          ),
        ),
        size: const Size(400, 600),
      );
      final v = _frame(c);
      // Upward and mostly vertical, the way a page scroll starts (a scroll view at 0 can't go further down).
      await _drag(tester, v, [(102, 80), (102, 76), (101, 60), (100, 20)], kind: PointerDeviceKind.touch);
      expect(scroll.offset, 0);
      expect(c.canUndo, isTrue);
      expect(_alpha(c.toRgba(), 101, 50), 0);
    });

    testWidgets('one finger paints until a pen is used; then fingers only move the view', (tester) async {
      _phoneSlop(tester);
      final v = await pump(tester);
      await _drag(tester, v, [(30, 50), (40, 50)], kind: PointerDeviceKind.touch);
      expect(c.canUndo, isTrue);
      await _drag(tester, v, [(100, 20), (110, 20)], kind: PointerDeviceKind.stylus, pointer: 3);
      c.undo();
      c.undo();
      await _drag(tester, v, [(150, 50), (170, 50)], kind: PointerDeviceKind.touch, pointer: 4);
      expect(c.canUndo, isFalse);
      expect(_alpha(c.toRgba(), 160, 50), 255);
    });

    testWidgets('Space + drag pans instead of painting', (tester) async {
      final v = await pump(tester);
      await tester.tap(find.byType(UiImageEditor));
      c.undo();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      final g = await tester.startGesture(v.at(50, 50), kind: PointerDeviceKind.mouse);
      await g.moveTo(v.at(90, 50));
      await g.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(_alpha(c.toRgba(), 70, 50), 255);
    });
  });

  group('crop', () {
    testWidgets('handles resize the crop and the export is exactly that region', (tester) async {
      final v = await pump(tester, mode: UiImageEditorMode.crop);
      await _drag(tester, v, [(0, 0), (15, 10), (30, 20)]);
      await _drag(tester, v, [(200, 100), (175, 95), (150, 90)]);
      expect(c.crop, const UiImageCrop(30, 20, 120, 70));
      expect(changes, 2);
      final r = c.toRgba();
      expect((r.width, r.height), (120, 70));
      expect(_px(r, 0, 0), [30, 20, 7, 255]);
      expect(_px(r, 119, 69), [149, 89, 7, 255]);
    });

    testWidgets('dragging inside moves it, and it never leaves the picture', (tester) async {
      final v = await pump(tester, mode: UiImageEditorMode.crop);
      await _drag(tester, v, [(0, 0), (20, 15), (40, 30)]);
      await _drag(tester, v, [(100, 60), (200, 150), (400, 300)]);
      expect(c.crop, const UiImageCrop(40, 30, 160, 70));
      await _drag(tester, v, [(150, 60), (0, 0), (-400, -300)]);
      expect(c.crop, const UiImageCrop(0, 0, 160, 70));
    });

    testWidgets('stays at least 8 px', (tester) async {
      final v = await pump(tester, mode: UiImageEditorMode.crop);
      await _drag(tester, v, [(200, 100), (0, 0), (-300, -300)]);
      expect(c.crop, const UiImageCrop(0, 0, 8, 8));
    });

    testWidgets('keeps the aspect while a corner or an edge is dragged', (tester) async {
      final v = await pump(tester, mode: UiImageEditorMode.crop);
      c.aspect = 1;
      await tester.pump();
      expect(c.crop, const UiImageCrop(50, 0, 100, 100));
      expect(changes, 1);
      await _drag(tester, v, [(150, 100), (130, 98), (110, 95)]);
      var r = c.crop!;
      expect(r.width, r.height);
      expect((r.x, r.y), (50, 0));
      expect(r.width, lessThan(100));
      await _drag(tester, v, [(r.x + r.width + 0.0, r.y + r.height / 2), (r.x + r.width - 10.0, r.y + r.height / 2), (r.x + r.width - 20.0, r.y + r.height / 2)]);
      r = c.crop!;
      expect(r.width, r.height);
      c.aspect = 16 / 9;
      await tester.pump();
      r = c.crop!;
      expect((r.width / r.height - 16 / 9).abs(), lessThan(0.05));
      await _drag(tester, v, [(r.x.toDouble(), r.y.toDouble()), (r.x - 50.0, r.y - 50.0), (r.x - 500.0, r.y - 500.0)]);
      r = c.crop!;
      expect((r.width / r.height - 16 / 9).abs(), lessThan(0.05));
      expect(r.x, greaterThanOrEqualTo(0));
      expect(r.y, greaterThanOrEqualTo(0));
      expect(r.x + r.width, lessThanOrEqualTo(_w));
      expect(r.y + r.height, lessThanOrEqualTo(_h));
    });

    testWidgets('one finger drags a handle with a phone touch slop', (tester) async {
      _phoneSlop(tester);
      final v = await pump(tester, mode: UiImageEditorMode.crop);
      await _drag(tester, v, [(200, 100), (195, 98), (180, 90)], kind: PointerDeviceKind.touch);
      expect(c.crop, const UiImageCrop(0, 0, 180, 90));
    });

    testWidgets('resetCrop goes back to the whole picture as an undo step', (tester) async {
      final v = await pump(tester, mode: UiImageEditorMode.crop);
      await _drag(tester, v, [(0, 0), (15, 10), (30, 20)]);
      c.resetCrop();
      expect(c.crop, const UiImageCrop(0, 0, 200, 100));
      c.undo();
      expect(c.crop, const UiImageCrop(30, 20, 170, 80));
    });
  });

  group('history', () {
    testWidgets('undo and redo step through strokes and crops in order', (tester) async {
      var v = await pump(tester);
      await _drag(tester, v, [(20, 50), (60, 50)]);
      v = await setMode(tester, UiImageEditorMode.crop);
      await _drag(tester, v, [(0, 0), (5, 5), (10, 10)]);
      v = await setMode(tester, UiImageEditorMode.erase);
      await _drag(tester, v, [(150, 50), (180, 50)]);
      expect(changes, 3);

      c.undo();
      expect(c.crop, const UiImageCrop(10, 10, 190, 90));
      expect(_alpha(c.toRgba(), 165 - 10, 40), 255);
      c.undo();
      expect(c.crop, const UiImageCrop(0, 0, 200, 100));
      expect(_alpha(c.toRgba(), 40, 50), 0);
      c.undo();
      expect(c.canUndo, isFalse);
      expect(c.dirty, isFalse);
      expect(_alpha(c.toRgba(), 40, 50), 255);

      c
        ..redo()
        ..redo()
        ..redo();
      expect(c.canRedo, isFalse);
      expect(c.crop, const UiImageCrop(10, 10, 190, 90));
      final r = c.toRgba();
      expect(_alpha(r, 30, 40), 0);
      expect(_alpha(r, 165 - 10, 40), 0);
      expect(changes, 9);
    });

    testWidgets('a new edit clears redo', (tester) async {
      final v = await pump(tester);
      await _drag(tester, v, [(20, 50), (60, 50)]);
      c.undo();
      expect(c.canRedo, isTrue);
      await _drag(tester, v, [(100, 50), (120, 50)]);
      expect(c.canRedo, isFalse);
    });

    testWidgets('keeps at least 30 steps', (tester) async {
      final v = await pump(tester);
      for (var i = 0; i < 40; i++) {
        await _drag(tester, v, [(5 + i * 4.0, 10 + (i % 8) * 10.0), (6 + i * 4.0, 12 + (i % 8) * 10.0)]);
      }
      var n = 0;
      while (c.canUndo) {
        c.undo();
        n++;
      }
      expect(n, 40);
    });

    testWidgets('Ctrl+Z undoes and Shift+Ctrl+Z redoes; [ and ] change the brush', (tester) async {
      final v = await pump(tester);
      await _drag(tester, v, [(20, 50), (60, 50)]);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      expect(c.canUndo, isFalse);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(c.canUndo, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(c.canUndo, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      expect(c.brushSize, 24);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      expect(c.brushSize, 17);
      expect(uiStepBrush(3, -1), 2);
      expect(uiStepBrush(1, -1), 1);
    });

    testWidgets('reset goes back to the original, and can be undone', (tester) async {
      var v = await pump(tester);
      await _drag(tester, v, [(20, 50), (180, 50)]);
      v = await setMode(tester, UiImageEditorMode.crop);
      await _drag(tester, v, [(0, 0), (15, 10), (30, 20)]);
      c.reset();
      expect(c.dirty, isFalse);
      expect(c.crop, const UiImageCrop(0, 0, 200, 100));
      expect(_alpha(c.toRgba(), 100, 50), 255);
      c.undo();
      expect(c.dirty, isTrue);
      expect(c.crop, const UiImageCrop(30, 20, 170, 80));
      expect(_alpha(c.toRgba(), 70, 30), 0);
    });
  });

  group('Shift-click straight lines', () {
    Future<void> tap(WidgetTester tester, _View v, double x, double y, {PointerDeviceKind kind = PointerDeviceKind.mouse}) => _drag(tester, v, [(x, y)], kind: kind);
    Future<void> shiftTap(WidgetTester tester, _View v, double x, double y) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tap(tester, v, x, y);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    }

    /// Whether everything along a-b (every 4 px) is erased.
    bool lineGone(UiImageRaster r, (double, double) a, (double, double) b) {
      final n = (math.sqrt(math.pow(b.$1 - a.$1, 2) + math.pow(b.$2 - a.$2, 2)) / 4).ceil();
      for (var i = 0; i <= n; i++) {
        final x = (a.$1 + (b.$1 - a.$1) * i / n).round(), y = (a.$2 + (b.$2 - a.$2) * i / n).round();
        if (_alpha(r, math.min(_w - 1, x), math.min(_h - 1, y)) != 0) return false;
      }
      return true;
    }

    testWidgets('a Shift-click erases straight from where the last stroke ended, as one undo step', (tester) async {
      final v = await pump(tester);
      await tap(tester, v, 20, 20);
      await shiftTap(tester, v, 180, 80);
      expect(changes, 2);
      var r = c.toRgba();
      expect(lineGone(r, (20, 20), (180, 80)), isTrue);
      // Off the line (brush 20: 10 px either side) nothing changes.
      for (final (x, y) in const [(180, 20), (20, 80), (100, 25), (100, 75), (5, 5), (195, 95)]) {
        expect(_alpha(r, x, y), 255, reason: '($x, $y)');
      }
      c.undo();
      r = c.toRgba();
      expect(_alpha(r, 100, 50), 255);
      expect(_alpha(r, 180, 80), 255);
      // The dot before it stays.
      expect(_alpha(r, 20, 20), 0);
    });

    testWidgets('Shift-clicks chain from point to point', (tester) async {
      final v = await pump(tester);
      await tap(tester, v, 20, 20);
      await shiftTap(tester, v, 100, 20);
      await shiftTap(tester, v, 100, 80);
      expect(changes, 3);
      var r = c.toRgba();
      expect(lineGone(r, (20, 20), (100, 20)), isTrue);
      expect(lineGone(r, (100, 20), (100, 80)), isTrue);
      expect(_alpha(r, 60, 60), 255);
      c.undo();
      r = c.toRgba();
      expect(_alpha(r, 100, 60), 255);
      expect(lineGone(r, (20, 20), (100, 20)), isTrue);
    });

    testWidgets('restore paints the original back along the line', (tester) async {
      var v = await pump(tester);
      for (final y in const [35.0, 45.0, 55.0, 65.0]) {
        await _drag(tester, v, [(0, y), (100, y), (199, y)]);
      }
      v = await setMode(tester, UiImageEditorMode.restore);
      c.brushSize = 6;
      await tap(tester, v, 30, 50);
      await shiftTap(tester, v, 170, 50);
      final r = c.toRgba();
      for (final x in const [30, 60, 100, 140, 170]) {
        expect(_alpha(r, x, 50), 255, reason: '$x');
      }
      expect(_alpha(r, 100, 40), 0);
      expect(_alpha(r, 100, 60), 0);
    });

    testWidgets('with no point remembered (fresh, after undo, another mode or reset), a Shift-click is a plain dot', (tester) async {
      var v = await pump(tester);
      Future<void> dotOnly(double x, double y, (int, int) far) async {
        await shiftTap(tester, v, x, y);
        final r = c.toRgba();
        expect(_alpha(r, x.round(), y.round()), 0);
        expect(_alpha(r, far.$1, far.$2), 255);
      }

      await dotOnly(100, 50, (60, 50));
      c.undo();
      await dotOnly(180, 80, (140, 65));
      await setMode(tester, UiImageEditorMode.restore);
      v = await setMode(tester, UiImageEditorMode.erase);
      await dotOnly(20, 80, (100, 80));
      c.reset();
      await tester.pump();
      await dotOnly(20, 20, (60, 20));
    });

    testWidgets('Shift + drag goes straight to where the drag starts, then on freehand: one undo step', (tester) async {
      final v = await pump(tester);
      await tap(tester, v, 20, 50);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _drag(tester, v, [(100, 20), (100, 40), (100, 60), (100, 80)]);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(changes, 2);
      var r = c.toRgba();
      expect(lineGone(r, (20, 50), (100, 20)), isTrue);
      expect(lineGone(r, (100, 20), (100, 80)), isTrue);
      c.undo();
      r = c.toRgba();
      expect(_alpha(r, 60, 35), 255);
      expect(_alpha(r, 100, 70), 255);
      expect(_alpha(r, 20, 50), 0);
    });

    testWidgets('shows a faint line to the pointer while Shift is held, and drops it on release', (tester) async {
      final v = await pump(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: v.at(150, 70));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await mouse.moveTo(v.at(150, 72));
      await tester.pump();
      expect(c.linePreview, isNull); // nothing remembered yet
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tap(tester, v, 20, 20);
      await mouse.moveTo(v.at(150, 70));
      await tester.pump();
      expect(c.linePreview, isNull); // no Shift
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      final line = c.linePreview!;
      expect(line.$1.dx, closeTo(v.at(20, 20).dx, 1e-6));
      expect(line.$1.dy, closeTo(v.at(20, 20).dy, 1e-6));
      expect(line.$2, v.at(150, 70));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(c.linePreview, isNull);
      await mouse.removePointer();
    });

    testWidgets('straightLine connects every press after the first, without Shift', (tester) async {
      final v = await pump(tester);
      c.straightLine = true;
      await tap(tester, v, 20, 20, kind: PointerDeviceKind.touch);
      await tap(tester, v, 180, 80, kind: PointerDeviceKind.touch);
      await tap(tester, v, 180, 20, kind: PointerDeviceKind.touch);
      expect(changes, 3);
      final r = c.toRgba();
      expect(lineGone(r, (20, 20), (180, 80)), isTrue);
      expect(lineGone(r, (180, 80), (180, 20)), isTrue);
      expect(_alpha(r, 100, 25), 255);
    });
  });

  testWidgets('a plain wheel scrolls the page; Ctrl + wheel zooms the editor', (tester) async {
    c = UiImageEditorController();
    final scroll = ScrollController();
    await pumpUi(
      tester,
      SizedBox(
        width: 400,
        height: 600,
        child: SingleChildScrollView(controller: scroll, child: Column(children: [_Host(controller: c), const SizedBox(height: 2000)])),
      ),
      size: const Size(400, 600),
    );
    final at = tester.getCenter(find.byType(UiImageEditor));
    tester.binding.handlePointerEvent(PointerScrollEvent(position: at, scrollDelta: const Offset(0, 100)));
    await tester.pump();
    expect(scroll.offset, greaterThan(0));
    scroll.jumpTo(0);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    tester.binding.handlePointerEvent(PointerScrollEvent(position: at, scrollDelta: const Offset(0, 100)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(scroll.offset, 0);
  });

  testWidgets('toPng gives the crop with erased pixels transparent', (tester) async {
    final v = await pump(tester, mode: UiImageEditorMode.crop, softness: 0.6);
    await _drag(tester, v, [(200, 100), (180, 90), (160, 75)]);
    final v2 = await setMode(tester, UiImageEditorMode.erase);
    await _drag(tester, v2, [(10, 37), (150, 37)]);
    final decoded = await tester.runAsync(() async {
      final png = await c.toPng();
      expect(png.sublist(1, 4), 'PNG'.codeUnits);
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      return (frame.image.width, frame.image.height, data!.buffer.asUint8List());
    });
    final (w, h, bytes) = decoded!;
    expect((w, h), (160, 75));
    // A part-erased pixel at the stroke's edge keeps its colour (the PNG holds straight alpha).
    final straight = c.toRgba();
    var checked = 0;
    for (var i = 0; i < straight.data.length && checked < 5; i += 4) {
      final a = straight.data[i + 3];
      if (a < 60 || a > 200) continue;
      expect(bytes[i + 3], a);
      for (var k = 0; k < 3; k++) {
        expect((bytes[i + k] - straight.data[i + k]).abs(), lessThanOrEqualTo(4), reason: 'channel $k at ${i ~/ 4}');
      }
      checked++;
    }
    expect(checked, 5);
    expect(bytes[(37 * w + 80) * 4 + 3], 0);
    expect(bytes[(5 * w + 80) * 4 + 3], 255);
    expect(bytes.sublist((5 * w + 80) * 4, (5 * w + 80) * 4 + 3), [80, 5, 7]);
  });

  testWidgets('loads encoded bytes', (tester) async {
    final png = await tester.runAsync(() async {
      final img = await (() {
        final r = _picture(30, 12);
        final done = Completer<ui.Image>();
        ui.decodeImageFromPixels(r.data, 30, 12, ui.PixelFormat.rgba8888, done.complete);
        return done.future;
      })();
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    c = UiImageEditorController();
    await tester.pumpWidget(UiApp(theme: UiThemeName.dark, home: Center(child: SizedBox(width: 400, height: 300, child: UiImageEditor(controller: c, bytes: png)))));
    await tester.runAsync(() async {
      for (var i = 0; i < 50 && !c.loaded; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
    expect(c.naturalSize, const Size(30, 12));
    expect(_px(c.toRgba(), 7, 3), [7, 3, 7, 255]);
  });

  testWidgets('golden: crop and erase', (tester) async {
    debugDisableShadows = false;
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(780, 300) * 2;
    addTearDown(tester.view.reset);
    final dark = UiImageEditorController(mode: UiImageEditorMode.crop);
    final light = UiImageEditorController(mode: UiImageEditorMode.crop);
    final scene = _scene();
    Widget side(UiThemeName th, UiImageEditorController ctl) => SizedBox(
          width: 390,
          child: UiThemeScope(
            theme: th,
            child: Padding(padding: const EdgeInsets.all(16), child: UiImageEditor(controller: ctl, raster: scene)),
          ),
        );
    await tester.pumpWidget(UiApp(
      theme: UiThemeName.dark,
      home: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [side(UiThemeName.dark, dark), side(UiThemeName.light, light)]),
    ));
    for (final ctl in [dark, light]) {
      ctl.edit!
        ..beginStroke(UiImageEditorMode.erase, 40, 90, 30, 0.4)
        ..strokeTo(120, 70)
        ..strokeTo(200, 100)
        ..endStroke();
      ctl.edit!.setCrop(const UiImageCrop(30, 20, 180, 110));
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    try {
      await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/image_editor.png'));
    } finally {
      debugDisableShadows = true;
    }
  });
}

/// A small made-up photo for the golden: sky gradient, a sun and a hill.
UiImageRaster _scene() {
  const w = 240, h = 160;
  final data = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final sun = math.sqrt(math.pow(x - 170, 2) + math.pow(y - 60, 2)) < 22;
      final hill = y > 110 + 15 * math.sin(x / 30);
      data[i] = hill ? 60 : (sun ? 255 : 60 + y);
      data[i + 1] = hill ? 40 : (sun ? 210 : 50 + y ~/ 2);
      data[i + 2] = hill ? 80 : (sun ? 140 : 150 - y ~/ 3);
      data[i + 3] = 255;
    }
  }
  return UiImageRaster(w, h, data);
}
