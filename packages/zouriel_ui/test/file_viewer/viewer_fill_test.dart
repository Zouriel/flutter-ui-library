import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import '../media/media_helpers.dart';

/// `fill`: a viewer that is the whole page (a payment slip opened from a list) rather than a box on
/// it. The page here is a phone (390x844): a 100 px title, then the viewer in an Expanded, with a
/// 34 px home-indicator inset where a test asks for one.
Widget page(Widget viewer, {double safeBottom = 0}) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: EdgeInsets.only(bottom: safeBottom)),
        child: SizedBox(
          width: 390,
          height: 844,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 100, child: Text('Payment slip')),
            Expanded(child: viewer),
          ]),
        ),
      ),
    );

/// A PDF with pages of the given sizes, standing in for PDFium (which does not load under test).
class _FakeDoc implements PdfDocument {
  _FakeDoc(List<Size> sizes) {
    pages = [for (var i = 0; i < sizes.length; i++) _FakePage(this, i + 1, sizes[i])];
  }
  @override
  late final List<PdfPage> pages;
  @override
  String get sourceName => 'fake.pdf';
  @override
  Stream<PdfDocumentEvent> get events => const Stream.empty();
  @override
  Future<void> dispose() async {}
  // All pages are here from the start, so there is nothing to load progressively.
  @override
  dynamic noSuchMethod(Invocation invocation) => invocation.memberName == #loadPagesProgressively ? Future<void>.value() : super.noSuchMethod(invocation);
}

class _FakeToken implements PdfPageRenderCancellationToken {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakePage implements PdfPage {
  _FakePage(this.document, this.pageNumber, this.size);
  final Size size;
  @override
  final PdfDocument document;
  @override
  final int pageNumber;
  @override
  double get width => size.width;
  @override
  double get height => size.height;
  @override
  PdfPageRotation get rotation => PdfPageRotation.none;
  @override
  PdfPageRenderCancellationToken createCancellationToken() => _FakeToken();
  // render() draws nothing: PdfPageView then shows the page's background, at the size we check.
  @override
  dynamic noSuchMethod(Invocation invocation) => invocation.memberName == #render ? Future<PdfImage?>.value() : super.noSuchMethod(invocation);
}

var _docs = 0;
PdfDocumentRef fakePdf(List<Size> sizes) => PdfDocumentRefByLoader((_) async => _FakeDoc(sizes), key: PdfDocumentRefKey('fake-${_docs++}'));

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('UiImageViewer fill', () {
    testWidgets('takes the whole parent; without fill it stays capped at 70% of the screen', (tester) async {
      final img = await testImage(tester, w: 90, h: 150);
      await pumpUi(tester, page(UiImageViewer(image: img, alt: 'Slip', fill: true)));
      expect(tester.getSize(find.byType(UiImageViewer)), const Size(390, 744));
      // The stage is the whole area: the controls float over it rather than taking a band of their own.
      expect(tester.getRect(find.bySemanticsLabel('Slip')), const Rect.fromLTWH(0, 100, 390, 744));

      // A parent that allows up to 744 without insisting: fill takes all of it, the plain viewer its
      // 70% cap.
      Widget loose(Widget v) => SizedBox(width: 390, height: 844, child: Align(alignment: Alignment.topLeft, child: ConstrainedBox(constraints: BoxConstraints.loose(const Size(390, 744)), child: v)));
      await pumpUi(tester, loose(UiImageViewer(image: img, alt: 'Slip', fill: true)));
      expect(tester.getSize(find.byType(UiImageViewer)), const Size(390, 744));
      await pumpUi(tester, loose(UiImageViewer(image: img, alt: 'Slip')));
      expect(tester.getSize(find.byType(UiImageViewer)).height, closeTo(844 * 0.7, 0.01));

      // Without fill: the bar takes a band of its own under the stage, and in a parent that gives no
      // height (a scroll view) the viewer is 70% of the screen.
      await pumpUi(tester, page(UiImageViewer(image: img, alt: 'Slip')));
      expect(tester.getSize(find.bySemanticsLabel('Slip')).height, lessThan(744 - 30));
      await pumpUi(tester, SizedBox(width: 390, height: 844, child: SingleChildScrollView(child: UiImageViewer(image: img, alt: 'Slip'))));
      expect(tester.getSize(find.byType(UiImageViewer)).height, closeTo(844 * 0.7, 0.01));
    });

    testWidgets('the picture is fitted into the area, contained and centred, however small it is', (tester) async {
      for (final (w, h) in [(4, 4), (900, 1500)]) {
        final img = await testImage(tester, w: w, h: h);
        await pumpUi(tester, page(UiImageViewer(image: img, alt: 'Slip', fill: true)));
        await tester.runAsync(() => precacheImage(img, tester.element(find.byType(UiImageViewer))));
        await tester.pumpAndSettle();
        final raw = tester.widget<RawImage>(find.byType(RawImage));
        expect(raw.fit, BoxFit.contain);
        expect(raw.alignment, Alignment.center);
        // The image box is the stage, so contain draws the picture as large as it fits, centred.
        expect(tester.getRect(find.byType(RawImage)), const Rect.fromLTWH(0, 100, 390, 744), reason: '${w}x$h');
      }
    });

    testWidgets('the controls float at the bottom, inside the area and clear of the home indicator', (tester) async {
      final img = await testImage(tester);
      await pumpUi(tester, page(UiImageViewer(image: img, alt: 'Slip', fill: true), safeBottom: 34));
      final viewer = tester.getRect(find.byType(UiImageViewer));
      final zoomIn = tester.getRect(find.bySemanticsLabel('Zoom in'));
      expect(viewer.contains(zoomIn.center), isTrue);
      expect(zoomIn.bottom, lessThanOrEqualTo(viewer.bottom - 34 - 12));
      expect(zoomIn.bottom, greaterThan(viewer.bottom - 34 - 12 - 24), reason: 'at the bottom, not floating mid-page');
      // Centred, compact (a pill, not a full-width bar).
      final pill = tester.getRect(find.ancestor(of: find.bySemanticsLabel('Zoom in'), matching: find.byType(BackdropFilter)).first);
      expect(pill.center.dx, closeTo(viewer.center.dx, 0.5));
      expect(pill.width, lessThan(viewer.width - 24));
    });

    testWidgets('the floating controls work; so do + - 0 from the keyboard and a pinch', (tester) async {
      final img = await testImage(tester, w: 900, h: 1500);
      await pumpUi(tester, page(UiImageViewer(image: img, alt: 'Slip', fill: true)));
      await tester.tap(find.bySemanticsLabel('Zoom in'));
      await tester.pump();
      expect(find.text('125%'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Reset view'));
      await tester.pump();
      expect(find.text('100%'), findsOneWidget);

      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pump();
      expect(find.text('125%'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.pump();
      expect(find.text('100%'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pump();
      expect(find.text('100%'), findsOneWidget);
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;

      final c = tester.getCenter(find.bySemanticsLabel('Slip'));
      final a = await tester.startGesture(c - const Offset(40, 0));
      final b = await tester.startGesture(c + const Offset(40, 0), pointer: 2);
      await tester.pump();
      for (var i = 1; i <= 5; i++) {
        await a.moveTo(c - Offset(40.0 + i * 16, 0));
        await b.moveTo(c + Offset(40.0 + i * 16, 0));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      final pct = int.parse(tester.widgetList<Text>(find.textContaining('%')).first.data!.replaceAll('%', ''));
      expect(pct, greaterThan(150), reason: 'spreading two fingers zooms in');
    });

    testWidgets('meets the touch and label guidelines', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final handle = tester.ensureSemantics();
      final img = await testImage(tester);
      await pumpUi(tester, page(UiImageViewer(image: img, alt: 'Slip', fill: true, hasNext: true, onNext: () {})));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(find.bySemanticsLabel('Previous image'), findsOneWidget);
      expect(find.bySemanticsLabel('Next image'), findsOneWidget);
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('UiPdfViewer fill', () {
    testWidgets('takes the whole parent, with no frame and the controls floating at the bottom', (tester) async {
      final gate = Completer<PdfDocument>();
      final ref = PdfDocumentRefByLoader((_) => gate.future, key: PdfDocumentRefKey('pending'));
      await pumpUiFrames(tester, page(UiPdfViewer(documentRef: ref, fill: true), safeBottom: 34));
      final viewer = tester.getRect(find.byType(UiPdfViewer));
      expect(viewer, const Rect.fromLTWH(0, 100, 390, 744));
      final clip = tester.widget<ClipRRect>(find.descendant(of: find.byType(UiPdfViewer), matching: find.byType(ClipRRect)).first);
      expect(clip.borderRadius, BorderRadius.zero);
      final zoomIn = tester.getRect(find.bySemanticsLabel('Zoom in'));
      expect(zoomIn.bottom, lessThanOrEqualTo(viewer.bottom - 34 - 12));
      expect(zoomIn.bottom, greaterThan(viewer.bottom - 34 - 12 - 24));
      expect(find.bySemanticsLabel('Fit page'), findsOneWidget);

      await pumpUiFrames(tester, page(UiPdfViewer(documentRef: ref)));
      expect(find.bySemanticsLabel('Fit page'), findsNothing, reason: 'the plain viewer is unchanged');
      expect(tester.getRect(find.bySemanticsLabel('Zoom in')).top, lessThan(viewer.top + 60), reason: 'its bar stays on top');
    });

    testWidgets('fits each page whole into the area and centres it, landscape or portrait', (tester) async {
      await pumpUiFrames(tester, page(UiPdfViewer(documentRef: fakePdf(const [Size(420, 297), Size(300, 900)]), fill: true)));
      await settle(tester);
      final viewer = tester.getRect(find.byType(UiPdfViewer));
      Rect pageRect() => tester.getRect(find.byKey(const ValueKey('ui-pdf-page')));
      // Landscape: as wide as the area allows (390 less 12 each side).
      expect(pageRect().width, closeTo(366, 0.01));
      expect(pageRect().height, closeTo(366 * 297 / 420, 0.01));
      expect(pageRect().center.dx, closeTo(viewer.center.dx, 0.5));
      // A tall receipt: as tall as the area allows above the floating controls, so its foot is never
      // under them.
      await tester.tap(find.bySemanticsLabel('Next page'));
      await settle(tester);
      final bar = tester.getRect(find.ancestor(of: find.bySemanticsLabel('Zoom in'), matching: find.byType(BackdropFilter)).first);
      expect(pageRect().bottom, lessThanOrEqualTo(bar.top));
      expect(pageRect().width / pageRect().height, closeTo(300 / 900, 0.001));
      expect(pageRect().top, closeTo(viewer.top + 12, 0.01));
      expect(pageRect().center.dx, closeTo(viewer.center.dx, 0.5));
    });

    testWidgets('zoom buttons, Fit, and the page label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUiFrames(tester, page(UiPdfViewer(documentRef: fakePdf(const [Size(420, 297), Size(420, 297)]), fill: true)));
      await settle(tester);
      expect(find.text('100%'), findsOneWidget);
      expect(find.bySemanticsLabel('Page 1 of 2'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Zoom in'));
      await tester.pump();
      expect(find.text('120%'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Fit page'));
      await tester.pump();
      expect(find.text('100%'), findsOneWidget);
      handle.dispose();
    });
  });

  test('uiFitContain fits whole, either way round', () {
    expect(uiFitContain(const Size(4, 4), const Size(390, 744)), const Size(390, 390));
    expect(uiFitContain(const Size(900, 1500), const Size(390, 744)), const Size(390, 650));
    final s = uiFitContain(const Size(420, 297), const Size(366, 600));
    expect(s.width, closeTo(366, 1e-9));
    expect(s.height, closeTo(366 * 297 / 420, 1e-9));
  });
}
