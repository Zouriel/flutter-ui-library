import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'media_helpers.dart';

/// Decodes [images] for real (outside the fake clock), so they paint in goldens.
Future<void> warm(WidgetTester tester, List<ImageProvider> images) async {
  await tester.runAsync(() async {
    for (final i in images) {
      final ctx = tester.element(find.byType(UiApp).first);
      await precacheImage(i, ctx);
    }
  });
  await tester.pump();
}

void main() {
  group('UiCarousel', () {
    late List<UiCarouselSlide> slides;
    setUp(() => slides = [
          for (var i = 0; i < 4; i++) UiCarouselSlide(image: MemoryImage(Uint8List(0)), alt: 'Photo ${i + 1}', caption: i == 0 ? 'Sunrise over the lagoon' : null),
        ]);

    testWidgets('swipe turns the slide, stops at the ends with resistance', (tester) async {
      final seen = <int>[];
      await pumpUi(tester, SizedBox(width: 390, child: UiCarousel(slides: slides, onIndexChanged: seen.add)));
      await tester.drag(find.byType(UiCarousel), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(seen, [1]);
      // A short, slow drag springs back.
      final g = await tester.startGesture(const Offset(200, 100));
      await g.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(seconds: 1));
      await g.moveBy(const Offset(-10, 0));
      await tester.pump(const Duration(seconds: 1));
      await g.up();
      await tester.pumpAndSettle();
      expect(seen, [1]);
      // Right past the first slide: no wrap.
      await tester.drag(find.byType(UiCarousel), const Offset(150, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(UiCarousel), const Offset(150, 0));
      await tester.pumpAndSettle();
      expect(seen, [1, 0]);
    });

    testWidgets('dots go to a slide and are 48dp targets on Android; the swipe is the carousel\'s own', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final handle = tester.ensureSemantics();
      final seen = <int>[];
      final pageSwipes = <String>[];
      await pumpUi(tester, UiSwipe(
        onSwipeLeft: () => pageSwipes.add('left'),
        child: SizedBox(width: 390, child: UiCarousel(slides: slides, onIndexChanged: seen.add)),
      ));
      await tester.tap(find.bySemanticsLabel('Go to slide 3'));
      await tester.pumpAndSettle();
      expect(seen, [2]);
      expect(tester.getSize(find.ancestor(of: find.bySemanticsLabel('Go to slide 3'), matching: find.byType(UiInteractive)).first), const Size(48, 48));
      // Touch: no arrows.
      expect(find.bySemanticsLabel('Next slide'), findsNothing);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.drag(find.byType(UiCarousel), const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(pageSwipes, isEmpty);
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('arrows wrap around (mouse platforms); adjustable for screen readers', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final handle = tester.ensureSemantics();
      var index = 0;
      await pumpUi(tester, StatefulBuilder(builder: (context, set) => SizedBox(width: 390, child: UiCarousel(slides: slides, index: index, onIndexChanged: (i) => set(() => index = i)))));
      await tester.tap(find.bySemanticsLabel('Previous slide'));
      await tester.pumpAndSettle();
      expect(index, 3);
      final node = tester.getSemantics(find.bySemanticsLabel('Carousel'));
      expect(node.value, 'Slide 4 of 4');
      tester.semantics.decrease(find.semantics.byLabel('Carousel'));
      await tester.pumpAndSettle();
      expect(index, 2);
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('autoplay turns, pauses under reduced motion', (tester) async {
      final seen = <int>[];
      await pumpUi(tester, SizedBox(width: 390, child: UiCarousel(slides: slides, autoplay: const Duration(seconds: 3), onIndexChanged: seen.add)));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(seen, [1, 2]);
      await tester.pumpWidget(const SizedBox());

      seen.clear();
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: UiApp(home: SizedBox(width: 390, child: UiCarousel(slides: slides, autoplay: const Duration(seconds: 3), onIndexChanged: seen.add))),
      ));
      await tester.pump(const Duration(seconds: 10));
      expect(seen, isEmpty);
    });

    testWidgets('size: 16:9 of the width, capped at maxHeight', (tester) async {
      await pumpUi(tester, SizedBox(width: 320, child: UiCarousel(slides: slides)));
      expect(tester.getSize(find.byType(UiCarousel)), const Size(320, 180));
      await pumpUi(tester, SizedBox(width: 900, child: UiCarousel(slides: slides)), size: const Size(900, 800));
      expect(tester.getSize(find.byType(UiCarousel)).height, 360);
    });
  });

  testWidgets('UiDeviceFrame scales to fit and keeps true phone size inside', (tester) async {
    double? scale;
    Size? inner;
    await pumpUi(tester, SizedBox(width: 207, height: 434, child: UiDeviceFrame(
      onScale: (s) => scale = s,
      child: LayoutBuilder(builder: (context, box) {
        inner = box.biggest;
        return const SizedBox();
      }),
    )));
    await tester.pump();
    expect(inner, const Size(390, 844));
    // (390 + 24) * 0.5 = 207
    expect(scale, closeTo(0.5, 0.001));
    expect(UiDeviceFrame.fitScale(const Size(2000, 2000), const Size(414, 868), 1), 1, reason: 'never scales up past maxScale');
  });

  group('UiDeviceFrame zoom', () {
    Future<({List<double> scales, List<double> fits, ScrollController h, ScrollController v})> pumpFrame(WidgetTester tester, double zoom) async {
      final scales = <double>[], fits = <double>[];
      final h = ScrollController(), v = ScrollController();
      addTearDown(h.dispose);
      addTearDown(v.dispose);
      await pumpUi(tester, SizedBox(width: 207, height: 434, child: UiDeviceFrame(
        zoom: zoom,
        onScale: scales.add,
        onFitScale: fits.add,
        horizontalController: h,
        verticalController: v,
        child: const SizedBox(),
      )));
      await tester.pump();
      return (scales: scales, fits: fits, h: h, v: v);
    }

    Rect device(WidgetTester tester) => tester.getRect(find.byType(FittedBox));

    testWidgets('zoom 1 fits as before; fitScale is reported; nothing scrolls', (tester) async {
      final r = await pumpFrame(tester, 1);
      expect(r.scales.last, closeTo(0.5, 0.001));
      expect(r.fits.last, closeTo(0.5, 0.001));
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(device(tester).size, const Size(207, 434));
    });

    testWidgets('zoom multiplies the fitted scale, beyond maxScale, and scrolls to every edge', (tester) async {
      final r = await pumpFrame(tester, 6);
      expect(r.fits.last, closeTo(0.5, 0.001));
      expect(r.scales.last, closeTo(3, 0.001), reason: 'maxScale 1 caps the fit only');
      expect(device(tester).size, const Size(414 * 3, 868 * 3));
      expect(r.h.position.maxScrollExtent, closeTo(414 * 3 - 207, 0.01));
      expect(r.v.position.maxScrollExtent, closeTo(868 * 3 - 434, 0.01));
      // Top-left edge in view at offset 0, bottom-right at the end.
      expect(device(tester).topLeft, Offset.zero);
      r.h.jumpTo(r.h.position.maxScrollExtent);
      r.v.jumpTo(r.v.position.maxScrollExtent);
      await tester.pump();
      expect(device(tester).bottomRight.dx, closeTo(207, 0.01));
      expect(device(tester).bottomRight.dy, closeTo(434, 0.01));
    });

    testWidgets('zoomed in on one axis only: the other stays centred', (tester) async {
      // fit 0.5, zoom 1.2: 248 wide in 207 (scrolls), 521 tall in 434 (scrolls). Use a wide box instead.
      final scales = <double>[];
      await pumpUi(tester, SizedBox(width: 380, height: 434, child: UiDeviceFrame(zoom: 1.5, onScale: scales.add, child: const SizedBox())));
      await tester.pump();
      expect(scales.last, closeTo(0.75, 0.001));
      final rect = device(tester);
      expect(rect.width, closeTo(414 * 0.75, 0.01));
      expect(rect.left, closeTo((380 - 414 * 0.75) / 2, 0.01), reason: 'narrower than the space: centred');
      expect(rect.top, 0);
    });

    testWidgets('zoom is kept within 0.25–8', (tester) async {
      expect(UiDeviceFrame.clampZoom(100), 8);
      expect(UiDeviceFrame.clampZoom(0.01), 0.25);
      expect(UiDeviceFrame.clampZoom(double.nan), 1);
      final r = await pumpFrame(tester, 0.1);
      expect(r.scales.last, closeTo(0.125, 0.001));
    });

    test('anchoredOffset keeps the point under the cursor', () {
      // 414 wide, viewport 207, scale 1 -> 2, offset 100, cursor at 50: the point is 150 into the frame.
      expect(UiDeviceFrame.anchoredOffset(offset: 100, focal: 50, viewport: 207, extent: 414, oldScale: 1, newScale: 2), 250);
      // From centred (scale 0.25: 103.5 wide, padded 51.75) to scrolling.
      final o = UiDeviceFrame.anchoredOffset(offset: 0, focal: 103.5, viewport: 207, extent: 414, oldScale: 0.25, newScale: 1);
      expect(o, closeTo((103.5 - 51.75) / 0.25 - 103.5, 0.001));
      // Clamped to the scroll range.
      expect(UiDeviceFrame.anchoredOffset(offset: 0, focal: 0, viewport: 207, extent: 414, oldScale: 1, newScale: 0.25), 0);
      expect(UiDeviceFrame.anchoredOffset(offset: 207, focal: 207, viewport: 207, extent: 414, oldScale: 1, newScale: 8), 414 * 8 - 207);
    });
  });

  group('UiImagePicker', () {
    List<UiImagePickerItem> items(int n, {bool disabledFirst = false}) => [
          for (var i = 0; i < n; i++)
            UiImagePickerItem(id: 'i$i', image: MemoryImage(Uint8List(0)), label: 'Art $i', disabled: disabledFirst && i == 0, badge: i == 1 ? 'Moves' : null),
        ];

    testWidgets('tap picks; busy disables the rest; broken images show the label', (tester) async {
      final handle = tester.ensureSemantics();
      final picked = <String>[];
      await pumpUi(tester, SizedBox(width: 390, child: UiImagePicker(items: items(3, disabledFirst: true), onPick: (i) => picked.add(i.id))));
      await tester.pumpAndSettle();
      // Bytes that are not an image: the label stands in.
      expect(find.text('Art 2'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Art 2'));
      await tester.tap(find.bySemanticsLabel('Art 0'));
      expect(picked, ['i2']);
      await pumpUiFrames(tester, SizedBox(width: 390, child: UiImagePicker(items: items(3), busyId: 'i1', onPick: (i) => picked.add(i.id))));
      await tester.tap(find.bySemanticsLabel('Art 2'));
      expect(picked, ['i2']);
      expect(find.bySemanticsLabel('Adding Art 1'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('asks for more near the end, and again after a page if still in view', (tester) async {
      var more = 0;
      Widget picker(int n, {bool loading = false}) => SizedBox(width: 390, child: UiImagePicker(items: items(n), hasMore: true, loading: loading, onMore: () => more++));
      await pumpUi(tester, picker(6));
      await tester.pump();
      expect(more, 1);
      await pumpUiFrames(tester, picker(6, loading: true));
      expect(more, 1);
      await pumpUi(tester, picker(12));
      await tester.pump();
      expect(more, 2);
    });

    testWidgets('empty text, columns and guidelines', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const SizedBox(width: 390, child: UiImagePicker(items: [], emptyText: 'Nothing found')));
      expect(find.text('Nothing found'), findsOneWidget);
      await pumpUi(tester, SizedBox(width: 358, child: UiImagePicker(items: items(5), onPick: (_) {})));
      // (358 + 8) / (96 + 8) = 3.5 → 3 columns of (358 - 16) / 3 = 114.
      expect(tester.getSize(find.byType(UiInteractive).first), const Size(114, 114));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  testWidgets('UiGallery opens the lightbox at the tapped picture; Escape returns focus', (tester) async {
    final imgs = [for (var i = 0; i < 3; i++) UiGalleryImage(image: MemoryImage(Uint8List(0)), alt: 'Pic $i')];
    final handle = tester.ensureSemantics();
    await pumpUi(tester, SizedBox(width: 390, child: UiGallery(images: imgs)));
    expect(tester.getSize(find.byType(UiInteractive).first).width, closeTo((390 - 16) / 3, 0.01));
    await tester.tap(find.bySemanticsLabel('Pic 1'));
    await tester.pumpAndSettle();
    expect(find.byType(UiMediaLightbox), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('3 of 3'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(UiMediaLightbox), findsNothing);
    handle.dispose();
  });

  testWidgets('golden: carousel, image picker, gallery, device frame', (tester) async {
    final a = await testImage(tester, w: 320, h: 180, seed: 0);
    final b = await testImage(tester, w: 120, h: 120, seed: 1);
    final c = await testImage(tester, w: 120, h: 90, seed: 2);
    await expectThemedGoldenAfter(tester, 'media', height: 700, (context) {
      final t = context.ui;
      return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: [
          UiCarousel(slides: [UiCarouselSlide(image: a, caption: 'Sunrise over the lagoon'), UiCarouselSlide(image: b), UiCarouselSlide(image: c)]),
          UiImagePicker(
            minThumb: 80,
            busyId: 'b',
            captions: true,
            items: [
              UiImagePickerItem(id: 'a', image: b, label: 'Palm', badge: 'Moves'),
              UiImagePickerItem(id: 'b', image: c, label: 'Wave'),
              UiImagePickerItem(id: 'c', image: MemoryImage(Uint8List(0)), label: 'Broken file'),
              UiImagePickerItem(id: 'd', image: a, label: 'Lagoon'),
            ],
          ),
          UiGallery(minThumb: 70, images: [UiGalleryImage(image: a, alt: 'A'), UiGalleryImage(image: b, alt: 'B'), UiGalleryImage(image: c, alt: 'C')]),
          SizedBox(height: 150, child: UiDeviceFrame(child: ColoredBox(color: t.surface, child: const Center(child: UiText('Phone', variant: UiTextVariant.h1))))),
        ]),
      );
    }, before: (tester) async {
      await tester.runAsync(() async {
        for (final i in [a, b, c]) {
          await precacheImage(i, tester.element(find.byType(UiCarousel).first));
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}
