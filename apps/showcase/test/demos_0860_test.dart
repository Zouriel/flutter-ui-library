import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/layout_page.dart';

/// 0.86.0 showcase: the Sidebar account demos on the Layout page lay out at phone widths and answer:
/// the footer button counts presses, the rail shows only the avatar, and the menu trigger opens its menu.

void main() {
  for (final width in [360.0, 390.0]) {
    testWidgets('Sidebar account demos at $width wide', (tester) async {
      tester.view.physicalSize = Size(width, 9000) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const UiApp(home: LayoutPage()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final footer = find.widgetWithText(UiSidebarAccount, 'Aishath Mohamed Ibrahim Didi');
      await tester.ensureVisible(footer);
      await tester.pumpAndSettle();
      expect(find.descendant(of: footer, matching: find.text('Read-only')), findsOneWidget);
      await tester.tap(footer);
      await tester.pump();
      expect(find.text('Pressed 1 time: an app opens its account switcher here.'), findsOneWidget);

      await tester.tap(find.text('Rail'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Aishath Mohamed Ibrahim Didi'), findsNothing);
      expect(find.byWidgetPredicate((w) => w is UiSidebarAccount && w.collapsed), findsOneWidget);

      final trigger = find.widgetWithText(UiSidebarAccount, 'Ali Hassan');
      await tester.ensureVisible(trigger);
      await tester.pumpAndSettle();
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Last chosen: Sign out'), findsOneWidget);
    });
  }
}
