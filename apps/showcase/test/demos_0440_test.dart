import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/buttons_page.dart';
import 'package:zouriel_ui_showcase/pages/layout_page.dart';
import 'package:zouriel_ui_showcase/pages/map_page.dart';

/// 0.44.0 showcase demos: SOS FAB positions, the swipe screens and the search area.

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(home: page));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('buttons page: the SOS button sits at the chosen place in its frame, above the sheet', (tester) async {
    await _pump(tester, const ButtonsPage());
    final sos = find.widgetWithText(UiFab, 'SOS');
    await tester.ensureVisible(sos);
    await tester.pump(const Duration(milliseconds: 300));
    final host = tester.getRect(find.ancestor(of: sos, matching: find.byType(UiFabHost)));
    var r = tester.getRect(sos);
    expect(r.center.dx, closeTo(host.center.dx, 0.5));
    // Under the demo's 40px app bar (topOffset).
    expect(r.top, closeTo(host.top + 40 + 24, 0.5));
    Future<void> choose(String label) async {
      final option = find.descendant(of: find.byType(UiSegmented<UiFabPosition>), matching: find.text(label));
      await tester.ensureVisible(option);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(option);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(sos);
      await tester.pump(const Duration(milliseconds: 300));
    }

    await choose('Top end');
    final host2 = tester.getRect(find.ancestor(of: sos, matching: find.byType(UiFabHost)));
    r = tester.getRect(sos);
    expect(r.right, closeTo(host2.right - 24, 0.5));
    await choose('Bottom centre');
    final host3 = tester.getRect(find.ancestor(of: sos, matching: find.byType(UiFabHost)));
    r = tester.getRect(sos);
    expect(r.bottom, closeTo(host3.bottom - 24, 0.5));
    // Over the open sheet, the tap still reaches the button.
    expect(tester.getRect(find.byType(UiBottomSheet).last).contains(r.center), isTrue);
    // It is held to send; a tap asks first.
    await tester.tapAt(r.center);
    await tester.pumpAndSettle();
    expect(find.text('Send an SOS?'), findsOneWidget);
    await tester.tap(find.text('Send SOS'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Last action: SOS'), findsWidgets);
  });

  testWidgets('layout page: the segmented control and a swipe move between the chat and the map', (tester) async {
    await _pump(tester, const LayoutPage());
    final screens = find.byType(UiSwipeScreens);
    await tester.ensureVisible(screens);
    await tester.pump(const Duration(milliseconds: 300));
    UiSwipeScreensState state() => tester.state<UiSwipeScreensState>(screens);
    expect(state().index, 0);
    final option = find.descendant(of: find.byType(UiSegmented<int>), matching: find.text('Map'));
    await tester.ensureVisible(option);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(option);
    await tester.pump(const Duration(milliseconds: 600));
    expect(state().index, 1);
    await tester.ensureVisible(screens);
    await tester.pump(const Duration(milliseconds: 300));
    // Back from the map's leading edge.
    final box = tester.getRect(screens);
    await tester.timedDragFrom(Offset(box.left + 8, box.center.dy), const Offset(260, 0), const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 600));
    expect(state().index, 0);
  });

  testWidgets('map page: the search area demo reports the radius and fits the area', (tester) async {
    await _pump(tester, const MapPage());
    final button = find.text('Show the whole area');
    await tester.ensureVisible(button);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Radius: 2 km'), findsOneWidget);
    expect(find.byType(UiMapAreaHandle), findsOneWidget);
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Editable'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(UiMapAreaHandle), findsNothing);
  });
}
