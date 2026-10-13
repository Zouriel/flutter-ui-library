import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

void main() {
  Future<OverlayPortalController> open(WidgetTester tester, Alignment where, {UiPlacement placement = UiPlacement.bottomStart, VoidCallback? onDismiss, bool focusPanel = false}) async {
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    final c = OverlayPortalController();
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(UiApp(home: Align(
      alignment: where,
      child: UiAnchoredOverlay(
        controller: c,
        placement: placement,
        onDismiss: onDismiss ?? c.hide,
        panelBuilder: (context, anchor) => Focus(focusNode: node, child: const SizedBox(key: Key('panel'), width: 200, height: 150)),
        child: const SizedBox(key: Key('anchor'), width: 80, height: 30),
      ),
    )));
    c.show();
    await tester.pump();
    if (focusPanel) {
      node.requestFocus();
      await tester.pump();
    }
    return c;
  }

  Rect r(WidgetTester tester, String key) => tester.getRect(find.byKey(Key(key)));

  testWidgets('opens below the anchor, start-aligned, with the gap', (tester) async {
    await open(tester, Alignment.topLeft);
    expect(r(tester, 'panel').top, r(tester, 'anchor').bottom + 4);
    expect(r(tester, 'panel').left, 8); // anchor is at 0, but the panel keeps the 8px margin
  });

  testWidgets('flips above when there is no room below', (tester) async {
    await open(tester, Alignment.bottomCenter);
    expect(r(tester, 'panel').bottom, r(tester, 'anchor').top - 4);
  });

  testWidgets('shifts to stay 8px inside the right edge', (tester) async {
    await open(tester, Alignment.topRight);
    expect(r(tester, 'panel').right, 390 - 8);
  });

  testWidgets('a tap outside and Escape both dismiss', (tester) async {
    var dismissed = 0;
    await open(tester, Alignment.center, onDismiss: () => dismissed++, focusPanel: true);
    await tester.tapAt(const Offset(10, 800));
    expect(dismissed, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(dismissed, 2);
    // Tapping the anchor itself is not "outside".
    await tester.tap(find.byKey(const Key('anchor')));
    expect(dismissed, 2);
  });
}
