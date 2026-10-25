import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../overlay/screens.dart';

/// A page with an opener button (and a focusable "Page" button before it), at phone size.
Future<void> _page(WidgetTester tester, void Function(BuildContext context) open, {Size size = const Size(390, 844), FocusNode? pageNode, ScrollController? scroll}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(
    home: Builder(builder: (context) => ListView(controller: scroll, padding: const EdgeInsets.all(16), children: [
          UiButton(label: 'Page', focusNode: pageNode, onPressed: () {}),
          UiButton(label: 'Open', onPressed: () => open(context)),
          const SizedBox(height: 2000),
        ])),
  ));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  group('UiModal', () {
    testWidgets('opens with its title, body and footer; completes with the popped value', (tester) async {
      Object? result = 'unset';
      await _page(tester, (context) async {
        result = await showUiModal<String>(
          context: context,
          title: 'Rename',
          builder: (context) => const Text('Body text'),
          footerBuilder: (context) => UiButton(label: 'Save', onPressed: () => Navigator.pop(context, 'saved')),
        );
      });
      await _open(tester);
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Body text'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsNothing);
      expect(result, 'saved');
    });

    testWidgets('the close button, the backdrop, Escape and the back button each close it', (tester) async {
      var closes = 0;
      await _page(tester, (context) async {
        await showUiModal<void>(context: context, title: 'Hello', builder: (context) => const Text('Body'));
        closes++;
      });
      await _open(tester);
      await tester.tap(find.bySemanticsLabel('Close').last);
      await tester.pumpAndSettle();
      expect(closes, 1);

      await _open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(closes, 2);

      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(closes, 3);

      await _open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(closes, 4);
    });

    testWidgets('closeOnBackdrop and closeOnEscape false keep it open', (tester) async {
      await _page(tester, (context) => showUiModal<void>(context: context, title: 'Stay', closeOnBackdrop: false, closeOnEscape: false, builder: (context) => const Text('Body')));
      await _open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Stay'), findsOneWidget);
      // Escape is still swallowed when only the backdrop may close it.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Stay'), findsNothing);
    });

    testWidgets('Escape stays off even when the backdrop may close it', (tester) async {
      await _page(tester, (context) => showUiModal<void>(context: context, title: 'Stay', closeOnEscape: false, builder: (context) => const Text('Body')));
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Stay'), findsOneWidget);
    });

    testWidgets('traps Tab inside and gives focus back to the page on close', (tester) async {
      final pageNode = FocusNode();
      addTearDown(pageNode.dispose);
      final a = FocusNode(), b = FocusNode();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      late BuildContext ctx;
      await _page(tester, (context) => ctx = context, pageNode: pageNode);
      await tester.tap(find.text('Open'));
      pageNode.requestFocus();
      await tester.pump();
      showUiModal<void>(
        context: ctx,
        title: 'Trap',
        builder: (context) => Column(children: [UiButton(label: 'A', focusNode: a, onPressed: () {}), UiButton(label: 'B', focusNode: b, onPressed: () {})]),
      );
      await tester.pumpAndSettle();
      expect(pageNode.hasFocus, isFalse);
      final seen = <String>{};
      for (var i = 0; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(pageNode.hasFocus, isFalse, reason: 'Tab never leaves the dialog');
        if (a.hasPrimaryFocus) seen.add('a');
        if (b.hasPrimaryFocus) seen.add('b');
      }
      expect(seen, {'a', 'b'});
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(pageNode.hasPrimaryFocus, isTrue);
    });

    testWidgets('is a dialog named by its title and hides the page from screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await _page(tester, (context) => showUiModal<void>(context: context, title: 'Settings', builder: (context) => const Text('Body')));
      expect(find.semantics.byLabel('Page'), findsOne);
      await _open(tester);
      final node = tester.getSemantics(find.byType(UiDialogScope));
      expect(node.label, 'Settings');
      expect(node.getSemanticsData().flagsCollection.namesRoute, isTrue);
      expect(find.semantics.byLabel('Page'), findsNothing);
      handle.dispose();
    });

    testWidgets('the page under it does not scroll', (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await _page(tester, (context) => showUiModal<void>(context: context, title: 'Lock', builder: (context) => const Text('Body')), scroll: scroll);
      await _open(tester);
      await tester.dragFrom(const Offset(20, 800), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
    });

    testWidgets('sizes: 360 / 480 / 720 wide on a tablet, 16px inset on a phone, full fills the screen', (tester) async {
      late BuildContext ctx;
      await _page(tester, (context) => ctx = context, size: const Size(1000, 800));
      await tester.tap(find.text('Open'));
      for (final (size, w) in [(UiModalSize.sm, 360.0), (UiModalSize.md, 480.0), (UiModalSize.lg, 720.0), (UiModalSize.full, 1000.0)]) {
        showUiModal<void>(context: ctx, title: 'Size', size: size, builder: (context) => const Text('Body'));
        await tester.pumpAndSettle();
        final r = tester.getRect(find.byType(UiDialogScope));
        expect(r.width, w, reason: '$size');
        if (size == UiModalSize.full) expect(r.height, 800);
        Navigator.pop(ctx);
        await tester.pumpAndSettle();
      }
      await _page(tester, (context) => ctx = context);
      await tester.tap(find.text('Open'));
      showUiModal<void>(context: ctx, title: 'Phone', builder: (context) => const Text('Body'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(UiDialogScope)).width, 390 - 32);
    });

    testWidgets('long content scrolls in the body while the header and footer stay put', (tester) async {
      await _page(tester, (context) => showUiModal<void>(
            context: context,
            title: 'Long',
            builder: (context) => Column(children: [for (var i = 0; i < 60; i++) Text('Line $i')]),
            footerBuilder: (context) => UiButton(label: 'Done', onPressed: () {}),
          ));
      await _open(tester);
      final panel = tester.getRect(find.byType(UiDialogScope));
      expect(panel.height, lessThanOrEqualTo(844 * 0.85 + 0.01));
      expect(tester.getRect(find.text('Done')).bottom, lessThan(panel.bottom));
      await tester.drag(find.text('Line 5'), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('Long').hitTestable(), findsOneWidget);
      expect(find.text('Done').hitTestable(), findsOneWidget);
    });

    testWidgets('meets the tap-target, label and contrast guidelines', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final handle = tester.ensureSemantics();
      await _page(tester, (context) => showUiModal<void>(
            context: context,
            title: 'Check',
            builder: (context) => const Text('Body text'),
            footerBuilder: (context) => UiButton(label: 'OK', onPressed: () {}),
          ));
      await _open(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('UiDrawer', () {
    testWidgets('slides in from each side at its size', (tester) async {
      late BuildContext ctx;
      await _page(tester, (context) => ctx = context);
      await tester.tap(find.text('Open'));
      for (final side in UiDrawerSide.values) {
        showUiDrawer<void>(context: ctx, side: side, title: 'Drawer', builder: (context) => const Text('Body'));
        await tester.pumpAndSettle();
        final r = tester.getRect(find.byType(UiDialogScope));
        switch (side) {
          // Left to right here: start is the left, end the right.
          case UiDrawerSide.left || UiDrawerSide.start:
            expect(r, const Rect.fromLTWH(0, 0, 351, 844));
          case UiDrawerSide.right || UiDrawerSide.end:
            expect(r, const Rect.fromLTWH(390 - 351, 0, 351, 844));
          case UiDrawerSide.top:
            expect(r, const Rect.fromLTWH(0, 0, 390, 320));
          case UiDrawerSide.bottom:
            expect(r, const Rect.fromLTWH(0, 844 - 320, 390, 320));
        }
        Navigator.pop(ctx);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('follows the finger; a short drag settles back, a fling closes it', (tester) async {
      await _page(tester, (context) => showUiDrawer<void>(context: context, title: 'Swipe', builder: (context) => const SizedBox(height: 400, child: Text('Body'))));
      await _open(tester);
      final start = tester.getRect(find.byType(UiDialogScope));
      await tester.drag(find.text('Body'), const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(UiDialogScope)), start);
      final gesture = await tester.startGesture(tester.getCenter(find.text('Body')));
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      expect(tester.getRect(find.byType(UiDialogScope)).left, closeTo(start.left + 120, 1), reason: 'follows the finger');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(UiDialogScope)), start, reason: 'let go early and slowly: settles back');
      await tester.fling(find.text('Body'), const Offset(120, 0), 1200);
      await tester.pumpAndSettle();
      expect(find.text('Swipe'), findsNothing, reason: 'a fling toward the edge closes it');
    });

    testWidgets('a slow drag past half way closes it; Escape and back close it', (tester) async {
      await _page(tester, (context) => showUiDrawer<void>(context: context, side: UiDrawerSide.left, title: 'Left', builder: (context) => const SizedBox(height: 400, child: Text('Body'))));
      await _open(tester);
      await tester.timedDrag(find.text('Body'), const Offset(-250, 0), const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Left'), findsNothing);
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Left'), findsNothing);
      await _open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Left'), findsNothing);
    });
  });

  group('UiConfirmDialog', () {
    testWidgets('completes true for confirm, false for cancel, null when dismissed', (tester) async {
      final results = <bool?>[];
      await _page(tester, (context) async => results.add(await showUiConfirm(context: context, message: 'Really?')));
      await _open(tester);
      expect(find.text('Are you sure?'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      await _open(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(results, [true, false, null]);
    });

    testWidgets('normal: both buttons on the right; destructive: Cancel far left, action far right', (tester) async {
      late BuildContext ctx;
      await _page(tester, (context) => ctx = context);
      await tester.tap(find.text('Open'));
      showUiConfirm(context: ctx, message: 'x');
      await tester.pumpAndSettle();
      final panel = tester.getRect(find.byType(UiDialogScope));
      final cancel = tester.getRect(find.ancestor(of: find.text('Cancel'), matching: find.byType(AnimatedContainer)).first);
      final ok = tester.getRect(find.ancestor(of: find.text('Confirm'), matching: find.byType(AnimatedContainer)).first);
      expect(ok.right, closeTo(panel.right - 16 - 1, 1));
      expect(ok.left - cancel.right, closeTo(8, 0.5));
      Navigator.pop(ctx);
      await tester.pumpAndSettle();
      showUiConfirm(context: ctx, message: 'x', confirmLabel: 'Delete', destructive: true);
      await tester.pumpAndSettle();
      final c2 = tester.getRect(find.ancestor(of: find.text('Cancel'), matching: find.byType(AnimatedContainer)).first);
      final d = tester.getRect(find.ancestor(of: find.text('Delete'), matching: find.byType(AnimatedContainer)).first);
      expect(c2.left, closeTo(panel.left + 16 + 1, 1));
      expect(d.right, closeTo(panel.right - 16 - 1, 1));
    });
  });

  testWidgets('golden: modal with footer, destructive confirm', (tester) async {
    debugDisableShadows = false;
    await pumpScreens(tester, (context) => Center(child: UiButton(label: 'Open', onPressed: () {
          showUiModal<void>(
            context: context,
            useRootNavigator: false,
            title: 'Rename project',
            builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
              UiText('The new name shows everywhere the project is linked.', variant: UiTextVariant.caption),
              UiText('Body text sits on the surface colour, 16px from the edges.'),
            ]),
            footerBuilder: (context) => Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: [
              UiButton(label: 'Cancel', variant: UiButtonVariant.outline, size: UiSize.sm, onPressed: () {}),
              UiButton(label: 'Save', size: UiSize.sm, onPressed: () {}),
            ]),
          );
        })));
    await tester.tap(find.text('Open').at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open').at(1));
    await tester.pumpAndSettle();
    await expectScreensGolden(tester, 'modal');
    debugDisableShadows = true;
  });

  testWidgets('golden: destructive confirm and drawers', (tester) async {
    debugDisableShadows = false;
    await pumpScreens(tester, (context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          UiButton(label: 'Confirm', onPressed: () => showUiConfirm(context: context, useRootNavigator: false, title: 'Delete item?', message: 'This cannot be undone.', confirmLabel: 'Delete', destructive: true)),
          UiButton(label: 'Drawer', onPressed: () => showUiDrawer<void>(context: context, useRootNavigator: false, title: 'Filters', builder: (context) => UiText('A right-anchored panel. Swipe right to close it.'))),
        ])), padding: const EdgeInsets.only(top: 24, bottom: 16));
    await tester.tap(find.text('Confirm').at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drawer').at(1));
    await tester.pumpAndSettle();
    await expectScreensGolden(tester, 'confirm_drawer');
    debugDisableShadows = true;
  });
}
