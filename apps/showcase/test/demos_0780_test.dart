import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/sortable_page.dart';

/// 0.78.0 showcase: the Sortable page (section list, reorder grid, handle field, theme swatch) lays
/// out at phone widths and its demos answer.

void main() {
  for (final width in [360.0, 390.0]) {
    testWidgets('Sortable page at $width wide', (tester) async {
      tester.view.physicalSize = Size(width, 3000) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const UiApp(home: SortablePage()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(UiSectionList), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Edit Weddings'));
      await tester.pump();
      expect(find.text('Edit weddings'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Remove Contact'));
      await tester.pump();
      expect(find.bySemanticsLabel('Remove Contact'), findsNothing);
      expect(find.byType(UiReorderGrid), findsOneWidget);
      expect(find.byType(UiThemeSwatch), findsNWidgets(3));
      await tester.enterText(find.byType(EditableText), 'studio');
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('@studio is taken'), findsOneWidget);
    });
  }
}
