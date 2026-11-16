import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/buttons_page.dart';
import 'package:zouriel_ui_showcase/pages/data_page.dart';
import 'package:zouriel_ui_showcase/pages/forms_page.dart';
import 'package:zouriel_ui_showcase/pages/navigation_page.dart';

/// 0.87.0 showcase: the activatable table, link buttons and links through UiLinkScope, the skip link and
/// the date-time picker lay out at phone widths and answer.

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  // The Data page at 390 only: at 360 two older demos (an avatar row, the kbd row) overflow.
  testWidgets('Data page: activatable rows and links through the scope at 390 wide', (tester) async {
    tester.view.physicalSize = const Size(390, 4000) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const UiApp(home: DataPage()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final row = find.text('Building permit, Feydhoo');
    await _show(tester, row);
    await tester.tap(row);
    await tester.pump();
    expect(find.text('Opened: Building permit, Feydhoo'), findsOneWidget);
    await _show(tester, find.text('Assign').first);
    await tester.tap(find.text('Assign').first);
    await tester.pump();
    expect(find.text('Opened: Assign (not opened): Land lease renewal, Hithadhoo'), findsOneWidget);

    final news = find.widgetWithText(UiLink, 'News');
    await _show(tester, news);
    expect(find.text('Route: /media'), findsOneWidget);
    await tester.tap(news);
    await tester.pump();
    expect(find.text('Route: /news'), findsOneWidget);
  });

  for (final width in [360.0, 390.0]) {
    testWidgets('Buttons page: link buttons navigate and show the current page at $width wide', (tester) async {
      tester.view.physicalSize = Size(width, 4000) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const UiApp(home: ButtonsPage()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final payments = find.widgetWithText(UiButton, 'Payments');
      await _show(tester, payments);
      expect(find.text('Route: /cases'), findsOneWidget);
      await tester.tap(payments);
      await tester.pump();
      expect(find.text('Route: /payments'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Settings').last);
      await tester.pump();
      expect(find.text('Route: /settings'), findsOneWidget);
    });

    testWidgets('Navigation page: the skip link at $width wide', (tester) async {
      tester.view.physicalSize = Size(width, 6000) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const UiApp(home: NavigationPage()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final skip = find.byType(UiSkipLink);
      await _show(tester, skip);
      expect(find.text('Skip to content'), findsNothing);
      Focus.of(tester.element(find.descendant(of: skip, matching: find.byType(SizedBox)).first)).requestFocus();
      await tester.pumpAndSettle();
      expect(find.text('Skip to content'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Focus is on the main content.'), findsOneWidget);
      expect(find.text('Skip to content'), findsNothing);
    });

    testWidgets('Forms page: the date-time picker at $width wide', (tester) async {
      tester.view.physicalSize = Size(width, 12000) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const UiApp(home: FormsPage()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final picker = find.byType(UiDateTimePicker);
      await _show(tester, picker);
      expect(find.text('Date-time: 2026-12-03T14:30'), findsOneWidget);
      // In a 280px box the parts stack.
      await _show(tester, find.text('In a 280px box'));
      await tester.tap(find.text('In a 280px box'));
      await tester.pumpAndSettle();
      final date = tester.getRect(find.descendant(of: picker, matching: find.byType(UiDatePicker)));
      final time = tester.getRect(find.descendant(of: picker, matching: find.byType(UiTimePicker)));
      expect(time.top, greaterThan(date.bottom));
      await tester.tap(find.widgetWithText(UiButton, 'Clear'));
      await tester.pump();
      expect(find.text('Date-time: null'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
