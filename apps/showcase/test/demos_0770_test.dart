import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/media_page.dart';

/// 0.77.0 showcase demo: the poster grid's action (a "View" eye) at each tile's top-end corner.

void main() {
  for (final width in [360.0, 390.0]) {
    testWidgets('at $width wide the eye views its poster without picking it; the tile still picks', (tester) async {
      tester.view.physicalSize = Size(width, 1400) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const UiApp(home: SingleChildScrollView(padding: EdgeInsets.all(16), child: PosterDemo())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final tiles = find.descendant(of: find.byType(UiPosterGrid), matching: find.byType(AspectRatio));
      final eyes = find.descendant(of: find.byType(UiPosterGrid), matching: find.byType(UiIconButton));
      expect(eyes, findsNWidgets(6));
      // Each eye inside its own tile's top-end corner.
      for (var i = 0; i < 6; i++) {
        final tile = tester.getRect(tiles.at(i));
        final eye = tester.getRect(find.descendant(of: tiles.at(i), matching: find.byType(UiIconButton)));
        expect(tile.contains(eye.center), isTrue);
        expect(eye.center.dx, greaterThan(tile.center.dx));
        expect(eye.center.dy, lessThan(tile.center.dy));
      }
      await tester.tap(find.descendant(of: tiles.at(3), matching: find.byType(UiIconButton)));
      await tester.pump();
      expect(find.text('Last picked: Aisha and Ali · Last viewed: Graduation'), findsOneWidget);
      await tester.tapAt(tester.getCenter(tiles.at(1)));
      await tester.pump();
      expect(find.text('Last picked: Eid get-together · Last viewed: Graduation'), findsOneWidget);
    });
  }
}
