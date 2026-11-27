import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui/src/card/glass_backdrop.dart'
    show UiGlassBackdropSlice, uiGlassBackdropDebugBuildCount;

import '../helpers.dart';

void main() {
  testWidgets('glass cards use one cached slice and no live filter', (
    tester,
  ) async {
    final image = (await tester.runAsync(
      () => createTestImage(width: 80, height: 80),
    ))!;
    final provider = _TestImage(image);
    final before = uiGlassBackdropDebugBuildCount;
    await pumpUi(
      tester,
      SizedBox(
        width: 260,
        height: 180,
        child: UiGlassBackdrop(
          image: provider,
          dim: 0.1,
          child: UiCard(
            glass: true,
            glassStrength: UiCardGlassStrength.liquid,
            child: const UiText('Static glass'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UiGlassBackdropSlice), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    final ready = uiGlassBackdropDebugBuildCount;
    expect(ready, greaterThan(before));
    await tester.pump(const Duration(seconds: 1));
    expect(
      uiGlassBackdropDebugBuildCount,
      ready,
      reason: 'an idle backdrop must not blur every frame',
    );
    image.dispose();
  });

  testWidgets('cards with no image keep tint and rim but have no blur layer', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const SizedBox(
        width: 260,
        height: 180,
        child: UiGlassBackdrop(
          child: UiCard(glass: true, child: UiText('Tint only')),
        ),
      ),
    );

    expect(find.byType(UiGlassBackdropSlice), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('cards outside a backdrop retain the live filter', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const UiCard(glass: true, child: UiText('Live glass')),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(UiGlassBackdropSlice), findsNothing);
  });

  // The backdrop is red on its left half and blue on its right half, so a card shows which part
  // of the blurred copy it paints: red on the left, blue on the right. A slice painted from the
  // card's own origin, or one fixed at paint time while a repaint boundary scrolls, shows the
  // wrong colour.
  testWidgets('a relayout moves the slice source with the card', (tester) async {
    final image = (await tester.runAsync(_halves))!;
    var left = 20.0;
    late StateSetter move;
    final shot = GlobalKey();
    await pumpUi(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: shot,
          child: StatefulBuilder(
            builder: (context, setState) {
              move = setState;
              return SizedBox(
                width: 400,
                height: 200,
                child: UiGlassBackdrop(
                  image: _TestImage(image),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        left: left,
                        top: 40,
                        duration: const Duration(milliseconds: 100),
                        child: _swatch(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(await _hue(tester, shot, const Offset(70, 90)), 'red');
    move(() => left = 280);
    await tester.pumpAndSettle();
    expect(await _hue(tester, shot, const Offset(330, 90)), 'blue');
    image.dispose();
  });

  testWidgets(
    'a scrolling repaint boundary gets a new source offset without a new blur',
    (tester) async {
      final image = (await tester.runAsync(_halves))!;
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final shot = GlobalKey();
      await pumpUi(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: shot,
            child: SizedBox(
              width: 400,
              height: 200,
              child: UiGlassBackdrop(
                image: _TestImage(image),
                child: SingleChildScrollView(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 280, height: 200),
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: RepaintBoundary(child: _swatch()),
                      ),
                      const SizedBox(width: 700, height: 200),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(await _hue(tester, shot, const Offset(330, 90)), 'blue');
      final builds = uiGlassBackdropDebugBuildCount;
      controller.jumpTo(260);
      await tester.pump();
      expect(await _hue(tester, shot, const Offset(70, 90)), 'red');
      expect(
        uiGlassBackdropDebugBuildCount,
        builds,
        reason: 'scrolling moves the slice, not the cached blur',
      );
      image.dispose();
    },
  );
}

Widget _swatch() => const SizedBox(
  width: 100,
  height: 100,
  child: UiCard(glass: true, glassStrength: UiCardGlassStrength.liquid, child: SizedBox(height: 60)),
);

Future<ui.Image> _halves() {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 200, 200), Paint()..color = const Color(0xffff0000));
  canvas.drawRect(const Rect.fromLTWH(200, 0, 200, 200), Paint()..color = const Color(0xff0000ff));
  return recorder.endRecording().toImage(400, 200);
}

/// 'red' or 'blue' for the pixel at [at] in the captured boundary, whichever channel wins clearly.
Future<String> _hue(WidgetTester tester, GlobalKey key, Offset at) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final data = (await tester.runAsync(() async {
    final img = await boundary.toImage();
    final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = img.width;
    img.dispose();
    final i = ((at.dy.round() * w) + at.dx.round()) * 4;
    return [bytes!.getUint8(i), bytes.getUint8(i + 2)];
  }))!;
  final r = data[0], b = data[1];
  if (r > b + 20) return 'red';
  if (b > r + 20) return 'blue';
  return 'unclear r=$r b=$b';
}

class _TestImage extends ImageProvider<_TestImage> {
  const _TestImage(this.image);
  final ui.Image image;

  @override
  Future<_TestImage> obtainKey(ImageConfiguration configuration) =>
      Future.value(this);

  @override
  ImageStreamCompleter loadImage(_TestImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
        Future.value(ImageInfo(image: image.clone())),
      );

  @override
  bool operator ==(Object other) =>
      other is _TestImage && identical(other.image, image);

  @override
  int get hashCode => identityHashCode(image);
}
