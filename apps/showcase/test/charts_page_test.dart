import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/charts_page.dart';
import 'package:zouriel_ui_showcase/pages/registry.dart';

/// The Charts page: registered, renders at phone and desktop widths without overflow, the daily
/// chart scrolls inside itself on a phone, and a tap chooses a day.
void main() {
  test('is in the side menu', () {
    expect(showcasePageById('charts')?.label, 'Charts');
  });

  ScrollPosition plotOf(WidgetTester tester, String key) => tester
      .state<ScrollableState>(find.descendant(of: find.descendant(of: find.byKey(ValueKey(key)), matching: find.byKey(const ValueKey('ui-bar-chart-scroller'))), matching: find.byType(Scrollable)))
      .position;

  for (final size in const [Size(390, 5000), Size(1440, 4000)]) {
    testWidgets('renders at ${size.width.toInt()}px', (tester) async {
      tester.view.physicalSize = size * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const UiApp(home: ChartsPage()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.byType(UiBarChart), findsNWidgets(4));
      for (final chart in find.byType(UiBarChart).evaluate()) {
        final r = tester.getRect(find.byWidget(chart.widget));
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(size.width), reason: 'a chart never sticks out of the page');
      }
      final daily = plotOf(tester, 'charts-daily');
      final grouped = plotOf(tester, 'charts-grouped');
      if (size.width < 600) {
        expect(daily.maxScrollExtent, greaterThan(0), reason: '30 days of 14 need more than a phone');
        expect(grouped.maxScrollExtent, greaterThan(0));
      } else {
        expect(daily.maxScrollExtent, 0);
        expect(grouped.maxScrollExtent, 0);
      }
      expect(find.text('Income'), findsOneWidget, reason: 'a legend for two series');
      expect(find.text('Sign-ups'), findsNothing, reason: 'none for one');
      expect(find.text('No data yet'), findsOneWidget);
      expect(find.text('27'), findsOneWidget, reason: 'a value label');
    });
  }

  testWidgets('a tap on a day chooses it', (tester) async {
    tester.view.physicalSize = const Size(1440, 4000) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const UiApp(home: ChartsPage()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Choose a day.'), findsOneWidget);
    final plot = find.descendant(of: find.byKey(const ValueKey('charts-daily')), matching: find.byKey(const ValueKey('ui-bar-chart-plot')));
    final r = tester.getRect(plot);
    // The last of 30 bands.
    await tester.tapAt(Offset(r.right - r.width / 60, r.top + 10));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Nov 13: 36 sign-ups'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('charts-daily')), matching: find.byKey(const ValueKey('ui-bar-chart-selected-rule'))), findsOneWidget);
  });
}
