import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/*
 * 0.88.0: the blob toast, a pill that grows a card as one shape, with update() to change a showing
 * toast and promise() to follow a future from a loading pill to a success or error card.
 */

const _base = UiBlobGeometry(width: 340, pillWidth: 160, pillHeight: 38, bodyHeight: 100);

UiBlobGeometry _g({double progress = 1, UiBlobSide side = UiBlobSide.center, double pillWidth = 160, double bodyHeight = 100}) =>
    UiBlobGeometry(width: 340, pillWidth: pillWidth, pillHeight: 38, bodyHeight: bodyHeight, side: side, progress: progress);

Future<UiToastController> _host(WidgetTester tester, {UiToastPosition position = UiToastPosition.topCenter}) async {
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

/// How far open the blob is: the height of its box beyond the pill.
double _cardHeight(WidgetTester tester) => tester.getSize(find.descendant(of: find.byType(UiBlobToast), matching: find.byType(CustomPaint)).first).height - 38;

void main() {
  group('blob toast shape (the web blob-shape.spec)', () {
    test('is the pill alone when closed, or when there is no card to grow', () {
      for (final g in [_g(progress: 0), _g(bodyHeight: 0)]) {
        expect(uiBlobPieces(g), [const UiBlobPiece.rrect(Rect.fromLTRB(90, 0, 250, 38), 19)]);
      }
    });

    test('open and centred: the pill as a tab on the full card, with a concave join on each shoulder', () {
      final pieces = uiBlobPieces(_base);
      expect(pieces[0], const UiBlobPiece.rrect(Rect.fromLTRB(90, 0, 250, 38), 19));
      expect(pieces[1], const UiBlobPiece.rrect(Rect.fromLTRB(0, 38, 340, 138), 20));
      expect(pieces.where((p) => !p.isFillet && p.radius == 0), [
        const UiBlobPiece.rect(Rect.fromLTRB(90, 19, 170, 38)),
        const UiBlobPiece.rect(Rect.fromLTRB(170, 19, 250, 38)),
      ]);
      expect(pieces.where((p) => p.isFillet), [UiBlobPiece.fillet(90, 38, 14, -1), UiBlobPiece.fillet(250, 38, 14, 1)]);
    });

    test('pill on a side: that side runs straight into the card, and only the other shoulder has a join', () {
      final left = uiBlobPieces(_g(side: UiBlobSide.left));
      expect(left.where((p) => p.isFillet), [UiBlobPiece.fillet(160, 38, 14, 1)]);
      expect(left, contains(const UiBlobPiece.rect(Rect.fromLTRB(0, 19, 80, 58))));
      final right = uiBlobPieces(_g(side: UiBlobSide.right));
      expect(right.where((p) => p.isFillet), [UiBlobPiece.fillet(180, 38, 14, -1)]);
      expect(right, contains(const UiBlobPiece.rect(Rect.fromLTRB(260, 19, 340, 58))));
    });

    test('grows out of the pill: the card starts inside the pill and never leaves the box sideways', () {
      for (var p = 0.02; p <= 1.3; p += 0.02) {
        for (final side in UiBlobSide.values) {
          final pieces = uiBlobPieces(_g(progress: p, side: side));
          final card = pieces[1];
          expect(card.rect.left, greaterThanOrEqualTo(0));
          expect(card.rect.right, lessThanOrEqualTo(340));
          expect(card.rect.top, inInclusiveRange(19, 38));
          expect(card.radius, lessThanOrEqualTo(card.rect.height / 2 + 1e-9));
          for (final f in pieces.where((x) => x.isFillet)) {
            expect(f.radius, lessThanOrEqualTo(14));
          }
          final bounds = uiBlobPath(_g(progress: p, side: side)).getBounds();
          expect(bounds.left.isFinite && bounds.bottom.isFinite, isTrue);
          expect(bounds.left, greaterThanOrEqualTo(-0.001));
          expect(bounds.right, lessThanOrEqualTo(340.001));
        }
      }
      final early = uiBlobPieces(_g(progress: 0.001))[1];
      expect(early.rect.left, greaterThan(90 + 18));
      expect(early.rect.right, lessThan(250 - 18));
    });

    test('past fully open (a spring overshooting) only the bottom edge moves', () {
      final at = uiBlobPieces(_base)[1].rect;
      final over = uiBlobPieces(_g(progress: 1.1))[1].rect;
      expect(over.left, at.left);
      expect(over.top, at.top);
      expect(over.right, at.right);
      expect(over.bottom, closeTo(148, 1e-9));
    });

    test('a pill wider than the box is held to the box; the path covers pill and card', () {
      expect(uiBlobPieces(_g(pillWidth: 500, progress: 0))[0].rect, const Rect.fromLTRB(0, 0, 340, 38));
      final path = uiBlobPath(_base);
      expect(path.getBounds(), const Rect.fromLTRB(0, 0, 340, 138));
      expect(path.contains(const Offset(170, 10)), isTrue, reason: 'the tab');
      expect(path.contains(const Offset(10, 80)), isTrue, reason: 'the card');
      expect(path.contains(const Offset(60, 20)), isFalse, reason: 'beside the tab, above the shoulder');
      expect(path.contains(const Offset(88, 36)), isTrue, reason: 'the concave join fills the inside corner');
      expect(path.contains(const Offset(80, 28)), isFalse, reason: 'but only up to its arc');
    });

    test('tone: keeps the hue and reads on the inverted surface, and on the action tint, in every theme', () {
      for (final theme in UiThemeName.values) {
        final t = UiThemeData(name: theme).tokens;
        for (final c in [t.info, t.success, t.warning, t.danger]) {
          final tone = uiBlobTone(c, t.bg);
          expect(_contrast(tone, t.text), greaterThanOrEqualTo(4.5), reason: '$theme $c on the surface');
          expect(_contrast(tone, Color.lerp(t.text, tone, 0.16)!), greaterThanOrEqualTo(4.5), reason: '$theme $c on the action');
        }
        // The muted text of the card.
        expect(_contrast(Color.lerp(t.text, t.bg, 0.7)!, t.text), greaterThanOrEqualTo(4.5), reason: '$theme muted');
      }
      final t = UiThemeData(name: UiThemeName.light).tokens;
      final green = HSLColor.fromColor(uiBlobTone(t.success, t.bg));
      expect((green.hue - HSLColor.fromColor(t.success).hue).abs(), lessThan(25));
      expect(green.saturation, greaterThan(0.25), reason: 'still a colour, not grey');
    });
  });

  group('UiToastController: blob, update, promise', () {
    testWidgets('blob() queues a blob toast; show() still defaults to a card', (tester) async {
      final c = await _host(tester);
      final id = c.blob('Changes Saved', tone: UiToastTone.success, message: 'Saved to the database.', duration: Duration.zero);
      c.show('Plain', duration: Duration.zero);
      expect(c.toasts[0].id, id);
      expect(c.toasts[0].variant, UiToastVariant.blob);
      expect(c.toasts[0].title, 'Changes Saved');
      expect(c.toasts[0].loading, isFalse);
      expect(c.toasts[1].variant, UiToastVariant.card);
      await tester.pumpAndSettle();
      expect(find.byType(UiBlobToast), findsOneWidget);
      expect(find.byType(UiToastView), findsOneWidget);
    });

    testWidgets('a loading toast stays until it is updated; then the countdown starts', (tester) async {
      final c = await _host(tester);
      final id = c.blob('Uploading', loading: true);
      expect(c.toasts.single.duration, Duration.zero);
      await tester.pump(const Duration(seconds: 60));
      expect(c.toasts.length, 1);
      c.update(id, loading: false, tone: UiToastTone.success, title: 'File Uploaded', message: 'report.pdf is in your files.');
      expect(c.toasts.single.duration, const Duration(seconds: 4));
      expect(c.toasts.single.variant, UiToastVariant.blob);
      await tester.pump(const Duration(milliseconds: 3800));
      expect(c.toasts.length, 1);
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.toasts, isEmpty);
      await tester.pumpAndSettle();
    });

    testWidgets('update() restarts the countdown, keeps what it is not given, and clears on request', (tester) async {
      final c = await _host(tester);
      final id = c.blob('Draft', message: 'Body', action: UiToastAction(label: 'Open', run: () {}), duration: const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 900));
      c.update(id, title: 'Sent', clearAction: true);
      final t = c.toasts.single;
      expect(t.title, 'Sent');
      expect(t.message, 'Body');
      expect(t.action, isNull);
      expect(t.tone, UiToastTone.info);
      await tester.pump(const Duration(milliseconds: 800));
      expect(c.toasts.length, 1);
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.toasts, isEmpty);
      c.update(999, title: 'x');
      await tester.pumpAndSettle();
    });

    testWidgets('promise(): a loading pill that becomes the success toast, and returns the same future', (tester) async {
      final c = await _host(tester);
      final done = Completer<String>();
      final returned = c.promise<String>(
        done.future,
        loading: const UiToastState('Booking Flight'),
        success: (code) => UiToastState('Booking Confirmed', message: 'Flight $code', duration: Duration.zero),
        error: (e) => const UiToastState('Something Went Wrong'),
      );
      expect(identical(returned, done.future), isTrue);
      expect(c.toasts.single.loading, isTrue);
      expect(c.toasts.single.title, 'Booking Flight');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(UiSpinner), findsOneWidget);
      done.complete('Q2 204');
      await tester.pumpAndSettle();
      expect(c.toasts.single.loading, isFalse);
      expect(c.toasts.single.tone, UiToastTone.success);
      expect(find.text('Booking Confirmed'), findsOneWidget);
      expect(find.text('Flight Q2 204'), findsOneWidget);
      expect(find.byType(UiSpinner), findsNothing);
    });

    testWidgets('promise(): a failure becomes the error toast', (tester) async {
      final c = await _host(tester);
      final done = Completer<void>();
      unawaited(c.promise<void>(
        done.future,
        loading: const UiToastState('Saving', message: 'One moment'),
        success: (_) => const UiToastState('Saved'),
        error: (e) => UiToastState('Something Went Wrong', message: '$e', duration: Duration.zero),
      ).catchError((Object _) {}));
      done.completeError('offline');
      await tester.pumpAndSettle();
      expect(c.toasts.single.tone, UiToastTone.danger);
      expect(c.toasts.single.loading, isFalse);
      expect(find.text('Something Went Wrong'), findsOneWidget);
      expect(find.text('offline'), findsOneWidget);
    });
  });

  group('UiBlobToast in the host', () {
    testWidgets('the pill shows first, then the card grows to fit the message and action', (tester) async {
      final c = await _host(tester);
      var shared = 0;
      c.blob('New Update Available', message: 'Version 2.4 is ready.', action: UiToastAction(label: 'Share Now', run: () => shared++), duration: Duration.zero);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('New Update Available'), findsOneWidget);
      expect(_cardHeight(tester), 0, reason: 'still a pill');
      // The action cannot be reached while closed.
      await tester.tap(find.text('Share Now'), warnIfMissed: false);
      expect(shared, 0);
      await tester.pumpAndSettle();
      expect(_cardHeight(tester), greaterThan(80));
      final box = tester.getRect(find.byType(UiBlobToast));
      expect(box.width, 340);
      expect((box.center.dx - 195).abs(), lessThan(0.5), reason: 'centred in a centred stack');
      await tester.tap(find.text('Share Now'));
      await tester.pumpAndSettle();
      expect(shared, 1);
      expect(c.toasts, isEmpty);
    });

    testWidgets('with only a title it stays a pill; tapping the pill dismisses', (tester) async {
      final c = await _host(tester);
      c.blob('Link Copied', tone: UiToastTone.success, duration: Duration.zero);
      await tester.pumpAndSettle();
      expect(_cardHeight(tester), 0);
      expect(uiBlobToastHasBody(c.toasts.single), isFalse);
      expect(uiBlobToastHasBody(const UiToast(id: 1, title: 'T', message: 'M')), isTrue);
      expect(uiBlobToastHasBody(const UiToast(id: 1, message: 'Saved')), isFalse, reason: 'a message with no title is the pill text');
      await tester.tap(find.text('Link Copied'));
      await tester.pumpAndSettle();
      expect(c.toasts, isEmpty);
      expect(find.byType(UiBlobToast), findsNothing);
    });

    testWidgets('update() on an open toast closes it to the pill before the new title shows', (tester) async {
      final c = await _host(tester);
      final id = c.blob('Changes Saved', tone: UiToastTone.success, message: 'Saved.', duration: Duration.zero);
      await tester.pumpAndSettle();
      final open = _cardHeight(tester);
      expect(open, greaterThan(30));
      c.update(id, tone: UiToastTone.danger, title: 'Something Went Wrong', message: 'Not saved. Check your connection and try again in a moment.');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Changes Saved'), findsOneWidget, reason: 'the old title while it closes');
      expect(find.text('Something Went Wrong'), findsNothing);
      expect(_cardHeight(tester), lessThan(open));
      await tester.pumpAndSettle();
      expect(find.text('Something Went Wrong'), findsOneWidget);
      expect(find.text('Changes Saved'), findsNothing);
      expect(_cardHeight(tester), greaterThan(open), reason: 'reopened to fit the longer message');
    });

    testWidgets('auto: a lone blob toast opens by itself; with more than one they stay pills until hovered', (tester) async {
      final c = await _host(tester);
      double card(int i) => tester.getSize(find.descendant(of: find.byType(UiBlobToast).at(i), matching: find.byType(CustomPaint)).first).height - 38;
      final a = c.blob('Changes Saved', tone: UiToastTone.success, message: 'Saved.', duration: Duration.zero);
      await tester.pumpAndSettle();
      expect(card(0), greaterThan(30));
      // A second one arrives: the first closes and the new one never opens by itself.
      final b = c.blob('File Uploaded', message: 'report.pdf', duration: Duration.zero);
      await tester.pumpAndSettle();
      expect(card(0), 0);
      expect(card(1), 0);
      // A card toast does not count.
      final plain = c.show('Plain', duration: Duration.zero);
      await tester.pumpAndSettle();
      expect(card(0), 0);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('File Uploaded')));
      await tester.pumpAndSettle();
      expect(card(1), greaterThan(30));
      expect(card(0), 0);
      // Onto the card that grew under the pill: still open.
      await mouse.moveTo(tester.getCenter(find.text('report.pdf')));
      await tester.pumpAndSettle();
      expect(card(1), greaterThan(30));
      await mouse.moveTo(const Offset(195, 800));
      await tester.pumpAndSettle();
      expect(card(1), 0);
      // Back to one: it opens again.
      c.dismiss(b);
      c.dismiss(plain);
      await tester.pumpAndSettle();
      expect(card(0), greaterThan(30));
      c.dismiss(a);
      await tester.pumpAndSettle();
    });

    testWidgets('a closed pill opens on a tap and dismisses on the next', (tester) async {
      final c = await _host(tester);
      c.blob('One', message: 'First.', duration: Duration.zero);
      c.blob('Two', message: 'Second.', duration: Duration.zero);
      await tester.pumpAndSettle();
      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      expect(c.toasts.length, 2);
      expect(tester.getSize(find.descendant(of: find.byType(UiBlobToast).first, matching: find.byType(CustomPaint)).first).height, greaterThan(38 + 30));
      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      expect(c.toasts.map((t) => t.title), ['Two']);
    });

    testWidgets('blobExpand: always opens every one; hover never opens one by itself', (tester) async {
      for (final (mode, count, open) in [(UiBlobExpand.always, 2, true), (UiBlobExpand.hover, 1, false)]) {
        final c = UiToastController();
        await tester.pumpWidget(UiApp(
          builder: (context, child) => UiToastHost(controller: c, blobExpand: mode, position: UiToastPosition.topCenter, child: child!),
          home: const SizedBox.expand(),
        ));
        for (var i = 0; i < count; i++) {
          c.blob('T$i', message: 'Body', duration: Duration.zero);
        }
        await tester.pumpAndSettle();
        for (var i = 0; i < count; i++) {
          final h = tester.getSize(find.descendant(of: find.byType(UiBlobToast).at(i), matching: find.byType(CustomPaint)).first).height - 38;
          expect(h > 30, open, reason: '$mode toast $i');
        }
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      }
    });

    testWidgets('custom content is drawn in the card and can read the tone', (tester) async {
      final c = await _host(tester);
      Color? seen;
      c.blob('Booking Confirmed', tone: UiToastTone.success, duration: Duration.zero, content: Builder(builder: (context) {
        seen = UiBlobToast.toneOf(context);
        return const Text('MLE to GAN');
      }));
      await tester.pumpAndSettle();
      expect(find.text('MLE to GAN'), findsOneWidget);
      final t = UiThemeData(name: UiThemeName.dark).tokens;
      expect(seen, isNotNull);
      expect(seen, isNot(t.success));
      expect(_cardHeight(tester), greaterThan(30));
    });

    testWidgets('keeps to the host side', (tester) async {
      for (final (p, check) in [
        (UiToastPosition.bottomRight, (Rect r) => (r.right - (390 - 16)).abs() < 0.5),
        (UiToastPosition.topLeft, (Rect r) => (r.left - 16).abs() < 0.5),
        (UiToastPosition.topCenter, (Rect r) => (r.center.dx - 195).abs() < 0.5),
      ]) {
        final c = await _host(tester, position: p);
        c.blob('Saved', duration: Duration.zero);
        await tester.pumpAndSettle();
        // The pill itself: its text sits on that side of the 340 box.
        final box = tester.getRect(find.byType(UiBlobToast));
        expect(check(box), isTrue, reason: '$p $box');
        final text = tester.getRect(find.text('Saved'));
        if (p == UiToastPosition.topLeft) expect(text.left - box.left, lessThan(60));
        if (p == UiToastPosition.bottomRight) expect(box.right - text.right, lessThan(40));
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('is a live region, and meets the tap-target, label and contrast guidelines', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final handle = tester.ensureSemantics();
      final c = await _host(tester);
      c.blob('Storage Almost Full', tone: UiToastTone.warning, message: 'You have used 92% of your storage.', action: UiToastAction(label: 'View Details', run: () {}), duration: Duration.zero);
      await tester.pumpAndSettle();
      final data = tester.getSemantics(find.byType(UiBlobToast)).getSemanticsData();
      expect(data.flagsCollection.isLiveRegion, isTrue);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a card toast that is loading shows a spinner for its icon and stays', (tester) async {
      final c = await _host(tester);
      final id = c.show('Working', loading: true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.descendant(of: find.byType(UiToastView), matching: find.byType(UiSpinner)), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(c.toasts.length, 1);
      c.dismiss(id);
      await tester.pumpAndSettle();
    });
  });

  testWidgets('golden: pill, loading, tones, action, pill on a side', (tester) async {
    debugDisableShadows = false;
    await expectThemedGolden(tester, 'blob_toasts', height: 760, (context) => MediaQuery(
          // No motion, so every toast is already open when the picture is taken.
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: Column(spacing: 14, children: [
            const UiBlobToast(toast: UiToast(id: 1, title: 'Link Copied', tone: UiToastTone.success, variant: UiToastVariant.blob)),
            const UiBlobToast(toast: UiToast(id: 2, title: 'Booking Flight', loading: true, variant: UiToastVariant.blob)),
            const UiBlobToast(toast: UiToast(id: 3, title: 'Changes Saved', message: 'Changes saved successfully to the database. Please refresh the page to see the changes.', tone: UiToastTone.success, variant: UiToastVariant.blob)),
            const UiBlobToast(toast: UiToast(id: 4, title: 'Something Went Wrong', message: 'We could not reach the server.', tone: UiToastTone.danger, variant: UiToastVariant.blob)),
            const UiBlobToast(side: UiBlobSide.left, toast: UiToast(id: 5, title: 'Storage Almost Full', message: 'You have used 92% of your storage.', tone: UiToastTone.warning, variant: UiToastVariant.blob)),
            UiBlobToast(
              side: UiBlobSide.right,
              toast: UiToast(id: 6, title: 'New Update Available', message: 'Version 2.4 is ready.', action: UiToastAction(label: 'Share Now', run: () {}), variant: UiToastVariant.blob),
              onAction: () {},
            ),
          ]),
        ));
    debugDisableShadows = true;
  });
}

double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
