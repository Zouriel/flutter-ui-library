import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

Future<MemoryImage> _solid(WidgetTester tester) async {
  late Uint8List bytes;
  await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 30, 40), Paint()..color = const Color(0xFF3B6EA8));
    final img = await rec.endRecording().toImage(30, 40);
    bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  });
  return MemoryImage(bytes);
}

/// A provider whose stream has already failed: the error replays synchronously on listen.
class _Failed extends ImageProvider<_Failed> {
  const _Failed();
  @override
  Future<_Failed> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);
  @override
  // ignore: invalid_override_of_non_virtual_member
  ImageStream resolve(ImageConfiguration configuration) {
    final completer = _FailedCompleter();
    completer.addListener(ImageStreamListener((_, _) {}, onError: (_, _) {})); // so the error counts as handled
    completer.reportError(exception: StateError('gone'), silent: true);
    return ImageStream()..setCompleter(completer);
  }
  @override
  bool operator ==(Object other) => other is _Failed;
  @override
  int get hashCode => 7;
}

class _FailedCompleter extends ImageStreamCompleter {}

List<Alignment> _alignments(WidgetTester tester) => tester.widgetList<Image>(find.byType(Image)).map((i) => i.alignment as Alignment).toList();

Matcher _at(double x, double y) => predicate<Alignment>((a) => (a.x - x).abs() < 1e-9 && (a.y - y).abs() < 1e-9, 'alignment ($x, $y)');

void main() {
  test('UiRepositionPosition.alignment maps percent to the Image alignment', () {
    expect(const UiRepositionPosition().alignment, Alignment.center);
    expect(const UiRepositionPosition(x: 0, y: 100).alignment, Alignment.bottomLeft);
    expect(const UiRepositionPosition(x: 20, y: 80).alignment, _at(-0.6, 0.6));
  });

  testWidgets('poster: position sets the picture alignment, default keeps focus', (tester) async {
    final img = await _solid(tester);
    await pumpUi(tester, SizedBox(width: 300, height: 400, child: UiPosterGrid(
      onSelect: (_) {},
      posters: [
        UiPoster(label: 'A', image: img, position: const UiRepositionPosition(x: 20, y: 80)),
        UiPoster(label: 'B', image: img),
      ],
    )));
    final a = _alignments(tester);
    expect(a[0], _at(-0.6, 0.6));
    expect(a[1], Alignment.center);
  });

  testWidgets('carousel: slide position sets the alignment, default centre', (tester) async {
    final img = await _solid(tester);
    await pumpUi(tester, SizedBox(width: 300, child: UiCarousel(slides: [
      UiCarouselSlide(image: img, position: const UiRepositionPosition(x: 10, y: 30)),
      UiCarouselSlide(image: img),
    ])));
    expect(_alignments(tester).first, _at(-0.8, -0.4));
    expect(_alignments(tester).last, Alignment.center);
  });

  testWidgets('file upload: previewPosition sets the preview alignment, default centre', (tester) async {
    final img = await _solid(tester);
    await pumpUi(tester, SizedBox(width: 300, child: UiFileUpload(picker: ({required multiple, required accept}) async => null, preview: img, previewPosition: const UiRepositionPosition(x: 100, y: 0))));
    expect(_alignments(tester).single, Alignment.topRight);
    await pumpUi(tester, SizedBox(width: 300, child: UiFileUpload(picker: ({required multiple, required accept}) async => null, preview: img)));
    expect(_alignments(tester).single, Alignment.center);
  });

  testWidgets('UiReposition: changing to an already-failed image reports the error after the frame, no setState during build', (tester) async {
    final good = await _solid(tester);
    var errors = 0;
    late StateSetter set;
    ImageProvider image = good;
    await pumpUi(tester, StatefulBuilder(builder: (context, setState) {
      set = setState;
      return SizedBox(width: 100, height: 100, child: UiReposition(image: image, onImageError: () => setState(() => errors++)));
    }));
    set(() => image = const _Failed());
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(errors, 1);
  });

  group('UiSwipe and drag-and-drop', () {
    Future<List<String>> pumpSwipeGrid(WidgetTester tester) async {
      final got = <String>[];
      tester.view.gestureSettings = ui.GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
      addTearDown(tester.view.resetGestureSettings);
      await pumpUi(tester, UiSwipe(
        onSwipeLeft: () => got.add('left'),
        onSwipeRight: () => got.add('right'),
        child: SizedBox(width: 390, height: 600, child: UiPosterGrid(
          onSelect: (_) {},
          onTileDrop: (_) {},
          posters: const [
            UiPoster(label: 'A', draggable: true),
            UiPoster(label: 'B', draggable: true),
            UiPoster(label: 'C', draggable: true),
          ],
        )),
      ));
      return got;
    }

    Finder tile(int i) => find.descendant(of: find.byType(UiPosterGrid), matching: find.byType(AspectRatio)).at(i);

    testWidgets('a long-press tile drag sideways does not fire the swipe', (tester) async {
      final got = await pumpSwipeGrid(tester);
      final g = await tester.startGesture(tester.getCenter(tile(0)), kind: ui.PointerDeviceKind.touch);
      await tester.pump(uiLongPressDuration + const Duration(milliseconds: 50));
      for (var i = 0; i < 6; i++) {
        await g.moveBy(const Offset(25, 0), timeStamp: Duration(milliseconds: 700 + 50 * i));
        await tester.pump();
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(got, isEmpty);
    });

    testWidgets('a normal sideways swipe on the same grid still fires', (tester) async {
      final got = await pumpSwipeGrid(tester);
      final g = await tester.startGesture(const Offset(300, 300), kind: ui.PointerDeviceKind.touch);
      for (var i = 0; i < 6; i++) {
        await g.moveBy(const Offset(-25, 0), timeStamp: Duration(milliseconds: 20 * (i + 1)));
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(got, ['left']);
    });
  });
}
