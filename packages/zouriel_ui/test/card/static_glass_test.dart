import 'dart:ui' as ui;

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

  testWidgets('a relayout moves the slice source with the card', (
    tester,
  ) async {
    final image = (await tester.runAsync(
      () => createTestImage(width: 80, height: 80),
    ))!;
    var left = 8.0;
    late StateSetter move;
    await pumpUi(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          move = setState;
          return SizedBox(
            width: 260,
            height: 180,
            child: UiGlassBackdrop(
              image: _TestImage(image),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    left: left,
                    top: 20,
                    duration: const Duration(milliseconds: 100),
                    child: const SizedBox(
                      width: 180,
                      child: UiCard(glass: true, child: UiText('Moves')),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    move(() => left = 92);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(CompositedTransformFollower), findsOneWidget);
    image.dispose();
  });

  testWidgets(
    'a scrolling repaint boundary gets a new source offset without a new blur',
    (tester) async {
      final image = (await tester.runAsync(
        () => createTestImage(width: 80, height: 160),
      ))!;
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpUi(
        tester,
        SizedBox(
          width: 260,
          height: 100,
          child: UiGlassBackdrop(
            image: _TestImage(image),
            child: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  const SizedBox(height: 70),
                  RepaintBoundary(
                    child: UiCard(glass: true, child: const UiText('Scrolls')),
                  ),
                  const SizedBox(height: 130),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final builds = uiGlassBackdropDebugBuildCount;
      controller.jumpTo(30);
      await tester.pump();
      expect(find.byType(CompositedTransformFollower), findsOneWidget);
      expect(
        uiGlassBackdropDebugBuildCount,
        builds,
        reason: 'scrolling repaints the slice, not the cached blur',
      );
      image.dispose();
    },
  );
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
