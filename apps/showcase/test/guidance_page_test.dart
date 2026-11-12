import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/guidance_page.dart';
import 'package:zouriel_ui_showcase/pages/registry.dart';

/// The Guidance page (0.75.0): registered, renders at phone and desktop widths, its tour runs to
/// the end, the checklist ticks, and the controller demo refuses a second offer.
Future<void> _steps(WidgetTester tester, [int n = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  test('is in the side menu', () {
    expect(showcasePageById('guidance')?.label, 'Guidance');
  });

  for (final size in const [Size(390, 5200), Size(1440, 4200)]) {
    testWidgets('renders at ${size.width.toInt()}px', (tester) async {
      tester.view.physicalSize = size * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const UiApp(home: GuidancePage()));
      await _steps(tester, 6);
      expect(tester.takeException(), isNull);
      expect(find.byType(UiOfferCard), findsNWidgets(2));
      expect(find.byType(UiChecklist), findsOneWidget);
      expect(find.byType(UiStarterCard), findsNWidgets(4));
      final starters = [for (var i = 0; i < 3; i++) tester.getRect(find.byType(UiStarterCard).at(i))];
      if (size.width < 600) {
        expect(starters[1].top, greaterThan(starters[0].bottom), reason: 'stacked on a phone');
      } else {
        expect(starters[0].top, starters[1].top, reason: 'side by side');
      }
    });
  }

  testWidgets('the tour walks the four tabs and finishes', (tester) async {
    tester.view.physicalSize = const Size(390, 5200) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const UiApp(home: GuidancePage()));
    await _steps(tester, 6);
    await tester.tap(find.text('Start the tour'));
    await _steps(tester);
    expect(find.text('1 of 4'), findsOneWidget);
    for (final n in [2, 3, 4]) {
      await tester.tap(find.text('Next'));
      await _steps(tester);
      expect(find.text('$n of 4'), findsOneWidget);
    }
    await tester.tap(find.text('Done'));
    await _steps(tester, 4);
    expect(find.text('Last tour: finished'), findsOneWidget);
    expect(UiTour.active, isNull);
  });

  testWidgets('the checklist ticks a tapped step; the controller allows one offer a session', (tester) async {
    tester.view.physicalSize = const Size(1440, 4200) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const UiApp(home: GuidancePage()));
    await _steps(tester, 6);
    expect(find.text('1 of 5'), findsOneWidget);
    final step = find.descendant(of: find.byType(UiChecklist), matching: find.text('Start an event'));
    await Scrollable.ensureVisible(tester.element(step), alignment: 0.5);
    await tester.pump();
    await tester.tap(find.ancestor(of: step, matching: find.byType(UiInteractive)).first);
    await tester.pump();
    expect(find.text('2 of 5'), findsOneWidget);

    final offer = find.text('Request an offer').first;
    await Scrollable.ensureVisible(tester.element(offer), alignment: 0.5);
    await tester.pump();
    await tester.tap(offer);
    await _steps(tester, 10);
    await tester.tap(offer);
    await _steps(tester, 10);
    expect(find.text('1. offer.welcome (offer): closed'), findsOneWidget);
    expect(find.text('2. offer.welcome (offer): refused'), findsOneWidget);
  });
}
