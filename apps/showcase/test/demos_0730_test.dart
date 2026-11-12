import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/media_page.dart';

/// 0.73.0 showcase demo: the avatar tag on album tiles and a feed post, at phone widths. Since 0.74.0
/// the album tiles are a UiPosterGrid with the tag in each poster's corner.

Future<void> _pump(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 1400) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const UiApp(home: SingleChildScrollView(padding: EdgeInsets.all(16), child: AvatarTagDemo())));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [360.0, 390.0]) {
    testWidgets('at $width wide every tag stays inside its tile, the long name ellipsises, the broken picture falls back', (tester) async {
      await _pump(tester, width);
      expect(tester.takeException(), isNull);
      Finder tag(int i) => find.byKey(ValueKey('avatar-tag-corner-$i'));
      final tiles = find.descendant(of: find.byType(UiPosterGrid), matching: find.byType(AspectRatio));
      expect(tiles, findsNWidgets(AvatarTagDemo.albums.length));
      for (var i = 0; i < AvatarTagDemo.albums.length; i++) {
        final tile = tester.getRect(tiles.at(i));
        final r = tester.getRect(tag(i));
        expect(find.descendant(of: tiles.at(i), matching: tag(i)), findsOneWidget);
        expect(tile.width, lessThanOrEqualTo(180));
        // At the picture's top-left corner, inside it.
        expect(r.left, greaterThan(tile.left));
        expect(r.top, greaterThan(tile.top));
        expect(r.right, lessThanOrEqualTo(tile.right));
        expect(r.bottom, lessThan(tile.center.dy));
      }
      final long = find.descendant(of: tag(1), matching: find.byKey(const ValueKey('ui-avatar-tag-name')));
      expect(tester.renderObject<RenderParagraph>(long).didExceedMaxLines, isTrue);
      expect(find.descendant(of: tag(3), matching: find.text('D')), findsOneWidget);
      expect(find.descendant(of: tag(2), matching: find.text('B')), findsOneWidget);
    });
  }
}
