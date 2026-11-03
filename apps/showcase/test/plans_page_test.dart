import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/plans_page.dart';
import 'package:zouriel_ui_showcase/pages/registry.dart';

/// The Plans page: registered, renders at phone and desktop widths without overflow, the cards
/// stack on a phone and sit side by side on a desktop, and its buttons work.
void main() {
  test('is in the side menu', () {
    expect(showcasePageById('plans')?.label, 'Plans');
  });

  for (final size in const [Size(390, 4000), Size(1440, 3000)]) {
    testWidgets('renders at ${size.width.toInt()}px', (tester) async {
      tester.view.physicalSize = size * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const UiApp(home: PlansPage()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      final cards = [for (var i = 0; i < 3; i++) tester.getRect(find.byType(UiPlanCard).at(i))];
      if (size.width < 600) {
        expect(cards[1].top, greaterThan(cards[0].bottom), reason: 'stacked');
        expect(cards[0].width, cards[1].width);
      } else {
        // The doc column is 820px at most, so two across (three from 912px).
        expect(cards[0].top, cards[1].top, reason: 'side by side');
        expect(cards[0].height, cards[1].height, reason: 'equal heights');
        expect(cards[2].top, greaterThan(cards[0].bottom));
      }
      expect(find.byType(UiPlanCompare), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is UiButton && w.tier != null), findsWidgets);
    });
  }

  testWidgets('a tier button picks the plan', (tester) async {
    tester.view.physicalSize = const Size(1440, 3000) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const UiApp(home: PlansPage()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Get Gold').first);
    await tester.pump();
    expect(find.text('Picked: Gold pass'), findsOneWidget);
  });
}
