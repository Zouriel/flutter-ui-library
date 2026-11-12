import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/media_page.dart';

/// 0.73.0 showcase demo: the avatar tag on album tiles and a feed post, at phone widths.

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
      for (var i = 0; i < AvatarTagDemo.albums.length; i++) {
        final tile = tester.getRect(find.byKey(ValueKey('avatar-tag-tile-$i')));
        final tag = tester.getRect(find.descendant(of: find.byKey(ValueKey('avatar-tag-tile-$i')), matching: find.byType(UiAvatarTag)));
        expect(tile.width, lessThanOrEqualTo(180));
        expect(tag.left, greaterThanOrEqualTo(tile.left));
        expect(tag.right, lessThanOrEqualTo(tile.right));
      }
      final long = find.descendant(of: find.byKey(const ValueKey('avatar-tag-tile-1')), matching: find.byKey(const ValueKey('ui-avatar-tag-name')));
      expect(tester.renderObject<RenderParagraph>(long).didExceedMaxLines, isTrue);
      expect(find.descendant(of: find.byKey(const ValueKey('avatar-tag-tile-3')), matching: find.text('D')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('avatar-tag-tile-2')), matching: find.text('B')), findsOneWidget);
    });
  }
}
