import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

Future<UiToastController> _host(WidgetTester tester, {UiToastPosition position = UiToastPosition.bottomRight}) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final c = UiToastController();
  addTearDown(c.dispose);
  await tester.pumpWidget(UiApp(
    builder: (context, child) => UiToastHost(controller: c, position: position, child: child!),
    home: const SizedBox.expand(),
  ));
  return c;
}

Finder get _toast => find.byType(UiToastView);

void main() {
  group('UiToastController', () {
    testWidgets('shows, auto-dismisses after its duration; zero keeps it', (tester) async {
      final c = await _host(tester);
      c.success('Saved', title: 'Done');
      c.show('Sticky', duration: Duration.zero);
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 3800));
      expect(find.text('Saved'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
      expect(find.text('Sticky'), findsOneWidget);
      expect(c.toasts.length, 1);
    });

    testWidgets('pause holds it; resume continues with at least one second', (tester) async {
      final c = await _host(tester);
      final id = c.info('Hold');
      await tester.pump(const Duration(milliseconds: 3700));
      c.pause(id);
      await tester.pump(const Duration(seconds: 10));
      expect(c.toasts.length, 1);
      c.resume(id);
      await tester.pump(const Duration(milliseconds: 900));
      expect(c.toasts.length, 1, reason: '300ms were left, but resuming gives at least a second');
      await tester.pump(const Duration(milliseconds: 200));
      expect(c.toasts, isEmpty);
      await tester.pumpAndSettle();
    });

    testWidgets('the action runs and dismisses; the dismiss button dismisses', (tester) async {
      final c = await _host(tester);
      var undone = 0;
      c.show('Moved to trash', action: UiToastAction(label: 'Undo', run: () => undone++), duration: Duration.zero);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(_toast, findsNothing);
      c.warning('Careful');
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Dismiss'));
      await tester.pumpAndSettle();
      expect(_toast, findsNothing);
    });

    testWidgets('a finger resting on it holds it; hovering does too', (tester) async {
      final c = await _host(tester);
      c.info('Read me');
      await tester.pumpAndSettle();
      final g = await tester.startGesture(tester.getCenter(find.text('Read me')));
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Read me'), findsOneWidget);
      await g.up();
      // It resumes with the ~4s it had left when the finger came down.
      await tester.pump(const Duration(milliseconds: 3000));
      expect(find.text('Read me'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
      expect(find.text('Read me'), findsNothing);

      c.info('Hover me');
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Hover me')));
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Hover me'), findsOneWidget);
      await mouse.moveTo(Offset.zero);
      await mouse.removePointer();
      await tester.pump(const Duration(milliseconds: 4100));
      await tester.pumpAndSettle();
      expect(find.text('Hover me'), findsNothing);
    });

    testWidgets('a sideways swipe dismisses it at once', (tester) async {
      final c = await _host(tester);
      c.info('Swipe me', duration: Duration.zero);
      await tester.pumpAndSettle();
      await tester.fling(find.text('Swipe me'), const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(c.toasts, isEmpty);
      expect(_toast, findsNothing);
    });

    testWidgets('UiToastController.of finds the host from below it', (tester) async {
      final c = await _host(tester);
      final ctx = tester.element(find.byType(SizedBox).last);
      expect(UiToastController.of(ctx), same(c));
    });
  });

  group('UiToastHost', () {
    testWidgets('positions: corners and centred edges, 16px in, newest last', (tester) async {
      for (final p in UiToastPosition.values) {
        final c = await _host(tester, position: p);
        c.info('First', duration: Duration.zero);
        c.info('Second', duration: Duration.zero);
        await tester.pumpAndSettle();
        final r = tester.getRect(_toast.last);
        expect(r.width, 380 - 32);
        switch (p) {
          // Left to right here: start is the left, end the right.
          case UiToastPosition.topRight || UiToastPosition.bottomRight || UiToastPosition.topEnd || UiToastPosition.bottomEnd:
            expect(r.right, 390 - 16);
          case UiToastPosition.topLeft || UiToastPosition.bottomLeft || UiToastPosition.topStart || UiToastPosition.bottomStart:
            expect(r.left, 16);
          case UiToastPosition.topCenter || UiToastPosition.bottomCenter:
            expect(r.center.dx, 195);
        }
        final top = p.name.startsWith('top');
        if (top) {
          expect(tester.getRect(_toast.first).top, 16);
        } else {
          expect(r.bottom, 844 - 16);
        }
        expect(tester.getRect(_toast.first).top, lessThan(r.top), reason: 'newest last');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('slides in from its own edge', (tester) async {
      for (final (p, check) in [
        (UiToastPosition.bottomRight, (Rect start, Rect end) => start.left > end.left),
        (UiToastPosition.topLeft, (Rect start, Rect end) => start.left < end.left),
        (UiToastPosition.topCenter, (Rect start, Rect end) => start.top < end.top),
        (UiToastPosition.bottomCenter, (Rect start, Rect end) => start.top > end.top),
      ]) {
        final c = await _host(tester, position: p);
        c.info('Hello', duration: Duration.zero);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        final start = tester.getRect(find.text('Hello'));
        await tester.pumpAndSettle();
        final end = tester.getRect(find.text('Hello'));
        expect(check(start, end), isTrue, reason: '$p');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('each toast is a live region', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await _host(tester);
      c.info('Info toast');
      c.danger('Danger toast');
      await tester.pumpAndSettle();
      final info = tester.getSemantics(find.byType(UiToastView).first).getSemanticsData();
      final danger = tester.getSemantics(find.byType(UiToastView).last).getSemanticsData();
      expect(info.flagsCollection.isLiveRegion, isTrue);
      expect(danger.flagsCollection.isLiveRegion, isTrue);
      expect(info.label, contains('Info toast'));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('meets the tap-target, label and contrast guidelines', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final handle = tester.ensureSemantics();
      final c = await _host(tester);
      c.show('Moved to trash', title: 'Deleted', action: UiToastAction(label: 'Undo', run: () {}), duration: Duration.zero);
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  testWidgets('golden: tones, title, action', (tester) async {
    debugDisableShadows = false;
    await expectThemedGolden(tester, 'toasts', height: 420, (context) => Column(spacing: 8, children: [
          const UiToastView(toast: UiToast(id: 1, message: 'A new version is ready.', tone: UiToastTone.info)),
          const UiToastView(toast: UiToast(id: 2, title: 'Saved', message: 'Your changes are live.', tone: UiToastTone.success)),
          const UiToastView(toast: UiToast(id: 3, message: 'Storage is almost full.', tone: UiToastTone.warning)),
          const UiToastView(toast: UiToast(id: 4, title: 'Upload failed', message: 'The file is larger than 20 MB.', tone: UiToastTone.danger)),
          UiToastView(toast: UiToast(id: 5, message: 'Moved to trash', action: UiToastAction(label: 'Undo', run: () {})), onAction: () {}, onDismiss: () {}),
          UiToastView(toast: const UiToast(id: 6, title: 'Dismissible', message: 'With a close button.'), onDismiss: () {}),
        ]));
    debugDisableShadows = true;
  });
}
