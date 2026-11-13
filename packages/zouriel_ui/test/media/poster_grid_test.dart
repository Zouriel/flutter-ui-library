import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
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

  group('UiPosterGrid with details', () {
    List<UiPoster> withDetails({ImageProvider? image}) => [
          UiPoster(label: 'Aisha and Ali', image: image, mark: const UiPosterMark(tone: UiStatus.primary, label: 'New'), details: const Align(alignment: AlignmentDirectional.centerStart, child: Text('Aisha and Ali'))),
          const UiPoster(label: 'Eid party', details: Text('Eid party')),
        ];

    testWidgets('draws each poster\'s details on its tile over a compact scrim; the words name the tile', (tester) async {
      final handle = tester.ensureSemantics();
      final picked = <int>[];
      await pumpUi(tester, SingleChildScrollView(child: SizedBox(width: 390, child: UiPosterGrid(posters: withDetails(), onSelect: picked.add))));
      final tiles = find.descendant(of: find.byType(UiPosterGrid), matching: find.byType(AspectRatio));
      expect(find.descendant(of: tiles.at(0), matching: find.byWidgetPredicate((w) => w is UiScrim && w.compact)), findsOneWidget);
      expect(find.descendant(of: tiles.at(0), matching: find.text('Aisha and Ali')), findsOneWidget);
      // The details sit at the bottom of their own tile.
      expect(tester.getRect(find.descendant(of: tiles.at(1), matching: find.byType(UiScrim))).bottom, closeTo(tester.getRect(tiles.at(1)).bottom, 0.5));
      final node = tester.getSemantics(find.descendant(of: tiles.at(0), matching: find.byType(UiInteractive)).first);
      final label = node.getSemanticsData().label;
      expect(label, contains('Aisha and Ali'));
      expect(label, contains('New'));
      await tester.tap(tiles.at(1));
      expect(picked, [1]);
      handle.dispose();
    });

    group('corner', () {
      const long = 'Coco Palm Dhuni Kolhu Maldives Resort and Spa, the long name';
      List<UiPoster> withCorner() => [
            const UiPoster(label: 'Aisha and Ali', details: Text('Aisha and Ali'), corner: UiAvatarTag(name: long, prefix: 'At', size: UiAvatarTagSize.xs)),
            const UiPoster(label: 'Eid party', details: Text('Eid party'), mark: UiPosterMark(tone: UiStatus.primary, label: 'New'), corner: UiAvatarTag(name: long, size: UiAvatarTagSize.xs)),
            const UiPoster(label: 'Birthday', details: Text('Birthday'), corner: UiAvatarTag(name: 'Bandos', size: UiAvatarTagSize.xs)),
          ];
      Finder tiles() => find.descendant(of: find.byType(UiPosterGrid), matching: find.byType(AspectRatio));

      for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
        testWidgets('sits inside the picture at its top-start corner, a long name ellipsized, at 360 wide ($dir)', (tester) async {
          await pumpUi(tester, Directionality(textDirection: dir, child: SingleChildScrollView(child: SizedBox(width: 360, child: UiPosterGrid(posters: withCorner(), onSelect: (_) {})))), size: const Size(360, 800));
          final t = tester.element(find.byType(UiPosterGrid)).ui;
          for (var i = 0; i < 3; i++) {
            final pic = tester.getRect(tiles().at(i));
            final tag = tester.getRect(find.descendant(of: tiles().at(i), matching: find.byType(UiAvatarTag)));
            expect(tag.top, closeTo(pic.top + t.space2, 0.5), reason: 'tile $i top');
            if (dir == TextDirection.ltr) {
              expect(tag.left, closeTo(pic.left + t.space2, 0.5), reason: 'tile $i start');
            } else {
              expect(tag.right, closeTo(pic.right - t.space2, 0.5), reason: 'tile $i start (rtl)');
            }
            expect(tag.left, greaterThanOrEqualTo(pic.left + t.space2 - 0.5));
            expect(tag.right, lessThanOrEqualTo(pic.right - t.space2 + 0.5));
            expect(tag.bottom, lessThan(pic.center.dy));
          }
          // A long name fills the room it has and no more; with a mark it stops short of the dot.
          final pic0 = tester.getRect(tiles().at(0));
          expect(tester.getRect(find.descendant(of: tiles().at(0), matching: find.byType(UiAvatarTag))).width, closeTo(pic0.width - 2 * t.space2, 0.5));
          final tag1 = tester.getRect(find.descendant(of: tiles().at(1), matching: find.byType(UiAvatarTag)));
          final dot = tester.getRect(find.descendant(of: tiles().at(1), matching: find.byType(UiPosterDot)));
          expect(tag1.overlaps(dot.inflate(2)), isFalse);
          // A short name keeps its own width.
          expect(tester.getRect(find.descendant(of: tiles().at(2), matching: find.byType(UiAvatarTag))).width, lessThan(pic0.width / 2));
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('paints above the picture and the details', (tester) async {
        await pumpUi(tester, SingleChildScrollView(child: SizedBox(width: 360, child: UiPosterGrid(posters: withCorner(), onSelect: (_) {}))), size: const Size(360, 800));
        final stack = tester.widget<Stack>(find.descendant(of: tiles().first, matching: find.byType(Stack)).first);
        expect((stack.children.last.key), const ValueKey('ui-poster-corner'));
      });

      testWidgets('golden: corner tags on light, dark and fallback posters', (tester) async {
        final light = await solid(tester, const Color(0xFFFFFFFF));
        final dark = await solid(tester, const Color(0xFF101418));
        await tester.runAsync(() async {
          await pumpUi(tester, const SizedBox());
          await precacheImage(light, tester.element(find.byType(UiApp)));
          await precacheImage(dark, tester.element(find.byType(UiApp)));
        });
        Widget title(BuildContext c, String a) => Text(a, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.uiText.label.copyWith(color: c.ui.mediaOnScrim));
        await expectThemedGolden(tester, 'poster_grid_corner', (c) => UiPosterGrid(onSelect: (_) {}, posters: [
              UiPoster(label: 'Aisha and Ali', image: light, mark: const UiPosterMark(tone: UiStatus.primary, label: 'New'), details: title(c, 'Aisha and Ali'),
                  corner: const UiAvatarTag(name: long, prefix: 'At', size: UiAvatarTagSize.xs)),
              UiPoster(label: 'Eid party', image: dark, details: title(c, 'Eid party'), corner: const UiAvatarTag(name: 'Bandos', size: UiAvatarTagSize.xs)),
              UiPoster(label: 'Birthday', details: title(c, 'Birthday'), corner: const UiAvatarTag(name: long, size: UiAvatarTagSize.xs)),
              UiPoster(label: 'Dinner', image: light, details: title(c, 'Dinner')),
            ]), width: 360, height: 560);
      });

      testWidgets('is absent when the poster has none', (tester) async {
        await pumpUi(tester, SingleChildScrollView(child: SizedBox(width: 360, child: UiPosterGrid(posters: withDetails(), onSelect: (_) {}))), size: const Size(360, 800));
        expect(find.byKey(const ValueKey('ui-poster-corner')), findsNothing);
        expect(find.byType(UiAvatarTag), findsNothing);
      });

      testWidgets('a tap on the corner still selects the tile, and the corner is read with it', (tester) async {
        final handle = tester.ensureSemantics();
        final picked = <int>[];
        await pumpUi(tester, SingleChildScrollView(child: SizedBox(width: 360, child: UiPosterGrid(posters: withCorner(), onSelect: picked.add))), size: const Size(360, 800));
        // The corner takes no pointer of its own (IgnorePointer): the tap lands on the tile under it.
        await tester.tapAt(tester.getCenter(find.descendant(of: tiles().at(2), matching: find.byType(UiAvatarTag))));
        await tester.tapAt(tester.getCenter(find.descendant(of: tiles().at(0), matching: find.byType(UiAvatarTag))));
        expect(picked, [2, 0]);
        final label = tester.getSemantics(find.descendant(of: tiles().at(0), matching: find.byType(UiInteractive)).first).getSemanticsData().label;
        expect(label, contains('At $long'));
        handle.dispose();
      });
    });

    group('action', () {
      const long = 'Coco Palm Dhuni Kolhu Maldives Resort and Spa, the long name';
      List<UiPoster> withAction(List<int> viewed) => [
            UiPoster(label: 'Aisha and Ali', details: const Text('Aisha and Ali'), mark: const UiPosterMark(tone: UiStatus.primary, label: 'New'),
                corner: const UiAvatarTag(name: long, size: UiAvatarTagSize.xs),
                action: UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedView), label: 'View Aisha and Ali', size: UiSize.sm, onPressed: () => viewed.add(0))),
            UiPoster(label: 'Eid party', details: const Text('Eid party'), corner: const UiAvatarTag(name: long, size: UiAvatarTagSize.xs),
                action: UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedView), label: 'View Eid party', size: UiSize.sm, onPressed: () => viewed.add(1))),
            const UiPoster(label: 'Birthday', details: Text('Birthday'), mark: UiPosterMark(tone: UiStatus.warning, label: 'Not finished')),
          ];
      Finder tiles() => find.descendant(of: find.byType(UiPosterGrid), matching: find.byType(AspectRatio));
      Finder tileTap(int i) => find.descendant(of: tiles().at(i), matching: find.byType(UiInteractive)).first;

      for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
        testWidgets('sits at the picture\'s top-end corner on a round scrim, the dot beside it, clear of the corner ($dir)', (tester) async {
          await pumpUi(tester, Directionality(textDirection: dir, child: SingleChildScrollView(child: SizedBox(width: 360, child: UiPosterGrid(posters: withAction([]), onSelect: (_) {})))), size: const Size(360, 800));
          final t = tester.element(find.byType(UiPosterGrid)).ui;
          for (var i = 0; i < 2; i++) {
            final pic = tester.getRect(tiles().at(i));
            final back = tester.getRect(find.descendant(of: tiles().at(i), matching: find.byKey(const ValueKey('ui-poster-action-backdrop'))));
            expect(back.top, closeTo(pic.top + t.space2, 0.5), reason: 'tile $i top');
            if (dir == TextDirection.ltr) {
              expect(back.right, closeTo(pic.right - t.space2, 0.5), reason: 'tile $i end');
            } else {
              expect(back.left, closeTo(pic.left + t.space2, 0.5), reason: 'tile $i end (rtl)');
            }
            // The corner keeps clear of the action (and the dot) on the other side.
            final tag = tester.getRect(find.descendant(of: tiles().at(i), matching: find.byType(UiAvatarTag)));
            expect(tag.overlaps(back), isFalse, reason: 'tile $i corner vs action');
          }
          // Tile 0 has a mark: its dot sits beside the action, before it, on the same row, never over it.
          final back0 = tester.getRect(find.descendant(of: tiles().at(0), matching: find.byKey(const ValueKey('ui-poster-action-backdrop'))));
          final dot = tester.getRect(find.descendant(of: tiles().at(0), matching: find.byType(UiPosterDot)));
          expect(dot.overlaps(back0.inflate(2)), isFalse);
          expect(dot.center.dy, closeTo(back0.center.dy, 0.5));
          expect(dir == TextDirection.ltr ? dot.right <= back0.left : dot.left >= back0.right, isTrue);
          expect(tester.getRect(find.descendant(of: tiles().at(0), matching: find.byType(UiAvatarTag))).overlaps(dot.inflate(2)), isFalse);
          // The backdrop hugs the sm button's visual (its 44 touch padding overflows, like the web's
          // hit-slop), and the ghost button inside draws in the on-scrim colour.
          expect(back0.size, Size(t.sizeSm, t.sizeSm));
          final visual = tester.getRect(find.descendant(of: tiles().at(0), matching: find.byType(AnimatedContainer)).last);
          expect(visual, back0);
          final icon = find.descendant(of: tiles().at(0), matching: find.byType(UiIcon));
          expect(IconTheme.of(tester.element(icon)).color, t.mediaOnScrim);
          // A poster without an action keeps its dot inside the tile at the top-end corner.
          final pic2 = tester.getRect(tiles().at(2));
          final dot2 = tester.getRect(find.descendant(of: tiles().at(2), matching: find.byType(UiPosterDot)));
          expect(dot2.top, closeTo(pic2.top + t.space2, 0.5));
          expect(find.descendant(of: tiles().at(2), matching: find.byKey(const ValueKey('ui-poster-action'))), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('is outside the tile\'s tap handling: tapping it never selects; the tile and the dot still do', (tester) async {
        final handle = tester.ensureSemantics();
        final picked = <int>[];
        final viewed = <int>[];
        await pumpUi(tester, SingleChildScrollView(child: SizedBox(width: 360, child: UiPosterGrid(posters: withAction(viewed), onSelect: picked.add))), size: const Size(360, 800));
        for (var i = 0; i < 2; i++) {
          final button = find.descendant(of: tiles().at(i), matching: find.byType(UiIconButton));
          expect(find.descendant(of: tileTap(i), matching: find.byType(UiIconButton)), findsNothing, reason: 'not inside the tile');
          expect(find.descendant(of: tileTap(i), matching: find.byType(UiPosterDot)), findsNothing, reason: 'the dot left the tile');
          await tester.tap(button);
        }
        await tester.pump();
        expect(viewed, [0, 1]);
        expect(picked, isEmpty);
        // The button's touch padding past the backdrop is still the action's, not the tile's.
        final back = tester.getRect(find.descendant(of: tiles().at(1), matching: find.byKey(const ValueKey('ui-poster-action-backdrop'))));
        await tester.tapAt(back.bottomLeft + const Offset(-4, 4));
        expect(viewed, [0, 1, 1]);
        expect(picked, isEmpty);
        // Elsewhere on the tile, and on the dot beside the action, the tile is the target.
        await tester.tapAt(tester.getCenter(tiles().at(1)));
        await tester.tapAt(tester.getCenter(find.descendant(of: tiles().at(0), matching: find.byType(UiPosterDot))));
        expect(picked, [1, 0]);
        expect(viewed, [0, 1, 1]);
        // Its own name, and the tile still reads its mark.
        expect(find.bySemanticsLabel('View Aisha and Ali'), findsOneWidget);
        expect(tester.getSemantics(tileTap(0)).getSemanticsData().label, contains('New'));
        handle.dispose();
      });

      testWidgets('is its own focus stop after its tile, and Enter on it never selects', (tester) async {
        final picked = <int>[];
        final viewed = <int>[];
        await pumpUi(tester, SingleChildScrollView(child: SizedBox(width: 360, child: UiPosterGrid(posters: withAction(viewed), onSelect: picked.add))), size: const Size(360, 800));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(viewed, [0]);
        expect(picked, isEmpty);
      });

      testWidgets('golden: actions with and without a dot on light, dark and fallback posters', (tester) async {
        final light = await solid(tester, const Color(0xFFFFFFFF));
        final dark = await solid(tester, const Color(0xFF101418));
        await tester.runAsync(() async {
          await pumpUi(tester, const SizedBox());
          await precacheImage(light, tester.element(find.byType(UiApp)));
          await precacheImage(dark, tester.element(find.byType(UiApp)));
        });
        Widget title(BuildContext c, String a) => Text(a, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.uiText.label.copyWith(color: c.ui.mediaOnScrim));
        Widget view(String l) => UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedView), label: 'View $l', size: UiSize.sm, onPressed: () {});
        await expectThemedGolden(tester, 'poster_grid_action', (c) => UiPosterGrid(onSelect: (_) {}, posters: [
              UiPoster(label: 'Aisha and Ali', image: light, mark: const UiPosterMark(tone: UiStatus.primary, label: 'New'), details: title(c, 'Aisha and Ali'),
                  corner: const UiAvatarTag(name: long, prefix: 'At', size: UiAvatarTagSize.xs), action: view('Aisha and Ali')),
              UiPoster(label: 'Eid party', image: dark, details: title(c, 'Eid party'), action: view('Eid party')),
              UiPoster(label: 'Birthday', details: title(c, 'Birthday'), mark: const UiPosterMark(tone: UiStatus.warning, label: 'Not finished'), action: view('Birthday')),
              UiPoster(label: 'Dinner', image: light, details: title(c, 'Dinner'), mark: const UiPosterMark(tone: UiStatus.neutral, label: 'Seen')),
            ]), width: 360, height: 560);
      });
    });

    testWidgets('a compact scrim reaches 60% at space8', (tester) async {
      await pumpUi(tester, const SizedBox(width: 200, child: UiScrim(compact: true, child: SizedBox(height: 40))));
      final p = tester.widget<CustomPaint>(find.descendant(of: find.byType(UiScrim), matching: find.byType(CustomPaint)).first).painter!;
      final size = tester.getSize(find.byType(UiScrim));
      final rec = ui.PictureRecorder();
      p.paint(Canvas(rec), size);
      late ByteData data;
      await tester.runAsync(() async {
        final img = await rec.endRecording().toImage(size.width.round(), size.height.round());
        data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      });
      int alphaAt(double y) => data.getUint8(((y.round().clamp(0, size.height.round() - 1)) * size.width.round() + 10) * 4 + 3);
      final t = tester.element(find.byType(UiScrim)).ui;
      expect(alphaAt(t.space8), closeTo(0.6 * 255, 6));
      expect(tester.getTopLeft(find.byType(SizedBox).last).dy - tester.getTopLeft(find.byType(UiScrim)).dy, t.space8);
    });

    testWidgets('tile details keep contrast over a white picture', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final white = await solid(tester, const Color(0xFFFFFFFF), w: 20, h: 20);
      await tester.runAsync(() async {
        await pumpUi(tester, const SizedBox());
        await precacheImage(white, tester.element(find.byType(UiApp)));
      });
      await pumpUi(tester, SizedBox(width: 390, child: UiPosterGrid(posters: withDetails(image: white).take(1).toList(), onSelect: (_) {})));
      await tester.pump();
      try {
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('golden: tiles with details', (tester) async {
      final pic = await solid(tester, const Color(0xFFF4E3C8));
      await tester.runAsync(() async {
        await pumpUi(tester, const SizedBox());
        await precacheImage(pic, tester.element(find.byType(UiApp)));
      });
      Widget details(BuildContext c, String a, String b) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(a, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.uiText.label.copyWith(color: c.ui.mediaOnScrim)),
            Text(b, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.uiText.caption.copyWith(color: c.ui.mediaOnScrim)),
          ]);
      await expectThemedGolden(tester, 'poster_grid_details', (c) => Padding(
            padding: const EdgeInsets.all(12),
            child: UiPosterGrid(onSelect: (_) {}, posters: [
              UiPoster(label: 'Aisha and Ali', image: pic, mark: const UiPosterMark(tone: UiStatus.primary, label: 'New'), details: details(c, 'Aisha and Ali', 'Sat 12 Dec 2026 · Going')),
              UiPoster(label: 'Eid get-together with the whole family', details: details(c, 'Eid get-together with the whole family', '20 Dec 2026 · 12 guests')),
            ]),
          ), height: 330);
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
