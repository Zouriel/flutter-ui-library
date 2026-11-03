import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// A real PNG of one colour, so pictures decode and paint.
Future<MemoryImage> solid(WidgetTester tester, Color c, {int w = 30, int h = 40}) async {
  late Uint8List bytes;
  await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    Canvas(rec).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = c);
    final img = await rec.endRecording().toImage(w, h);
    bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  });
  return MemoryImage(bytes);
}

List<UiPoster> posters({ImageProvider? first}) => [
      UiPoster(label: 'Aisha and Ali', image: first),
      const UiPoster(label: 'Eid party', colors: [Color(0xFF112233), Color(0xFF445566)], mark: UiPosterMark(tone: UiStatus.warning, label: 'Not finished')),
      const UiPoster(label: 'Birthday', mark: UiPosterMark(tone: UiStatus.primary, label: 'New')),
      const UiPoster(label: 'Graduation'),
      const UiPoster(label: 'Dinner'),
      const UiPoster(label: 'Housewarming'),
    ];

void main() {
  group('UiPosterGrid', () {
    testWidgets('draws pictures only: no Text in any tile; the name and mark are the semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      final picked = <int>[];
      await pumpUi(tester, SingleChildScrollView(child: SizedBox(width: 390, child: UiPosterGrid(posters: posters(), onSelect: picked.add))));
      expect(find.descendant(of: find.byType(UiPosterGrid), matching: find.byType(Text)), findsNothing);
      expect(find.descendant(of: find.byType(UiPosterGrid), matching: find.byType(RichText)), findsNothing);
      expect(find.bySemanticsLabel('Aisha and Ali'), findsOneWidget);
      expect(find.bySemanticsLabel('Eid party, Not finished'), findsOneWidget);
      expect(find.bySemanticsLabel('Birthday, New'), findsOneWidget);
      expect(find.byType(UiPosterDot), findsNWidgets(2));
      // Ringed in the light on-scrim colour, so the dot shows on dark posters.
      final dot = tester.widget<Container>(find.descendant(of: find.byType(UiPosterDot).first, matching: find.byType(Container)));
      final shadows = (dot.decoration! as BoxDecoration).boxShadow!;
      expect(shadows.any((s) => s.color == tester.element(find.byType(UiPosterGrid)).ui.mediaOnScrim && s.spreadRadius == 2), isTrue);
      await tester.tap(find.bySemanticsLabel('Birthday, New'));
      expect(picked, [2]);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('steps 2, 3, 4, 5 columns by its own width, every tile the same shape', (tester) async {
      for (final (width, columns) in [(390.0, 2), (600.0, 3), (1000.0, 4), (1300.0, 5)]) {
        await pumpUi(tester, SizedBox(width: width, child: UiPosterGrid(posters: posters(), ratio: 0.75, onSelect: (_) {})), size: Size(width, 2000));
        final tiles = find.descendant(of: find.byType(UiPosterGrid), matching: find.byType(AspectRatio));
        final tops = <double>{};
        final first = tester.getSize(tiles.first);
        for (var i = 0; i < 6; i++) {
          final r = tester.getRect(tiles.at(i));
          if (r.top == tester.getRect(tiles.first).top) tops.add(r.left);
          expect(r.size.width, closeTo(first.width, 0.01));
          expect(r.size.width / r.size.height, closeTo(0.75, 0.01));
        }
        expect(tops.length, columns, reason: 'at $width wide');
        expect(UiPosterGrid.columnsFor(width), columns);
      }
    });

    testWidgets('shows the gradient when there is no picture or it fails to load', (tester) async {
      await pumpUi(tester, SingleChildScrollView(child: SizedBox(width: 390, child: UiPosterGrid(posters: posters(first: MemoryImage(Uint8List(0))), onSelect: (_) {}))));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      final gradients = tester.widgetList<DecoratedBox>(find.descendant(of: find.byType(UiPosterGrid), matching: find.byType(DecoratedBox)))
          .where((d) => (d.decoration as BoxDecoration).gradient != null);
      // All six: five without a picture and the one whose bytes don't decode.
      expect(gradients.length, 6);
    });

    testWidgets('golden: phone grid with dots and fallbacks', (tester) async {
      final pic = await solid(tester, const Color(0xFF3D5AFE));
      await tester.runAsync(() async {
        await pumpUi(tester, const SizedBox());
        await precacheImage(pic, tester.element(find.byType(UiApp)));
      });
      await expectThemedGolden(tester, 'poster_grid', (_) => Padding(
            padding: const EdgeInsets.all(12),
            child: UiPosterGrid(posters: posters(first: pic).take(4).toList(), onSelect: (_) {}),
          ), height: 560);
    });
  });

  group('UiPosterView', () {
    testWidgets('opens over everything with the details on a scrim; Escape and the close button close it', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, Builder(builder: (context) => UiButton(
            label: 'Open',
            onPressed: () => UiPosterView.show<void>(context, label: 'Aisha and Ali', builder: (context) => Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Sat 12 Dec'),
                  UiButton(label: 'Open invitation', onPressed: () => Navigator.of(context).pop()),
                ])),
          )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(UiPosterView), findsOneWidget);
      expect(find.descendant(of: find.byType(UiScrim), matching: find.text('Sat 12 Dec')), findsOneWidget);
      // The details sit at the bottom of the screen.
      expect(tester.getRect(find.byType(UiScrim)).bottom, tester.getSize(find.byType(UiPosterView)).height);
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(UiPosterView), findsNothing);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(UiPosterView), findsNothing);

      // A button in the details can close it too.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open invitation'));
      await tester.pumpAndSettle();
      expect(find.byType(UiPosterView), findsNothing);
      handle.dispose();
    });

    testWidgets('scrim text keeps contrast over a white picture', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final white = await solid(tester, const Color(0xFFFFFFFF), w: 20, h: 20);
      await tester.runAsync(() async {
        await pumpUi(tester, const SizedBox());
        await precacheImage(white, tester.element(find.byType(UiApp)));
      });
      await pumpUi(tester, UiPosterView(
        label: 'Aisha and Ali',
        image: white,
        onClose: () {},
        // Sized to the text: the guideline samples the node's whole box, and a full-width box over a
        // gradient is mostly background, which it then mistakes for the text colour.
        child: const Align(alignment: AlignmentDirectional.centerStart, child: Text('Saturday 12 December, 7 pm')),
      ));
      await tester.pump();
      try {
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('in every theme, on-scrim text over the 60% point of the fade beats 4.5:1 on white', (tester) async {
      double lum(Color c) => c.computeLuminance();
      for (final theme in UiThemeName.values) {
        await pumpUi(tester, const SizedBox(), theme: theme);
        final t = tester.element(find.byType(SizedBox).last).ui;
        final white = const Color(0xFFFFFFFF);
        final under = Color.alphaBlend(t.mediaScrim.withValues(alpha: 0.6), white);
        final a = lum(t.mediaOnScrim), b = lum(under);
        final ratio = (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: '$theme: $ratio');
      }
    });

    testWidgets('the scrim fades clear to 60% at space12 and 88% at the bottom', (tester) async {
      await pumpUi(tester, const SizedBox(width: 300, child: UiScrim(child: SizedBox(height: 100))));
      final paint = tester.widget<CustomPaint>(find.descendant(of: find.byType(UiScrim), matching: find.byType(CustomPaint)).first);
      final p = paint.painter!;
      final rec = ui.PictureRecorder();
      // Paint into a canvas and read back via a known-size image.
      final size = tester.getSize(find.byType(UiScrim));
      p.paint(Canvas(rec), size);
      late ByteData data;
      await tester.runAsync(() async {
        final img = await rec.endRecording().toImage(size.width.round(), size.height.round());
        data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      });
      int alphaAt(double y) => data.getUint8(((y.round().clamp(0, size.height.round() - 1)) * size.width.round() + 10) * 4 + 3);
      final t = tester.element(find.byType(UiScrim)).ui;
      expect(alphaAt(0), lessThan(10));
      expect(alphaAt(t.space12), closeTo(0.6 * 255, 6));
      expect(alphaAt(size.height - 1), closeTo(0.88 * 255, 6));
    });

    testWidgets('golden: details over a picture and over the fallback', (tester) async {
      final pic = await solid(tester, const Color(0xFFF4E3C8), w: 30, h: 40);
      await tester.runAsync(() async {
        await pumpUi(tester, const SizedBox());
        await precacheImage(pic, tester.element(find.byType(UiApp)));
      });
      await expectThemedGolden(tester, 'poster_view', (context) => UiPosterView(
            label: 'Aisha and Ali',
            image: context.uiTheme.brightness == Brightness.dark ? null : pic,
            onClose: () {},
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Aisha and Ali', style: context.uiText.h3.copyWith(color: context.ui.mediaOnScrim)),
              const Text('Saturday 12 December, 7 pm · Malé'),
              SizedBox(height: context.ui.space2),
              UiButton(label: 'Open invitation', onPressed: () {}),
            ]),
          ), height: 640);
    });
  });
}
