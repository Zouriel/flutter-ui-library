import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../overlay/screens.dart';

class _Harness {
  int snap;
  final log = <int>[];
  final heights = <double>[];
  final covers = <double>[];
  _Harness(this.snap);
}

Future<_Harness> _sheet(
  WidgetTester tester, {
  int snap = 0,
  bool backdrop = false,
  double offset = 0,
  Widget? child,
  FocusNode? pageNode,
  ScrollController? pageScroll,
}) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final h = _Harness(snap);
  await tester.pumpWidget(UiApp(
    home: StatefulBuilder(builder: (context, set) => Stack(children: [
          ListView(controller: pageScroll, padding: const EdgeInsets.all(16), children: [
            UiButton(label: 'Page', focusNode: pageNode, onPressed: () {}),
            UiButton(label: 'Open', onPressed: () => set(() => h.snap = 1)),
            const SizedBox(height: 2000),
          ]),
          UiBottomSheet(
            snaps: const [0, 0.4, 0.9],
            snap: h.snap,
            title: 'Layers',
            backdrop: backdrop,
            offset: offset,
            onSnapChanged: (i) => set(() {
              h.snap = i;
              h.log.add(i);
            }),
            onHeightChanged: h.heights.add,
            onCoverChanged: h.covers.add,
            child: child ?? Column(children: [for (var i = 0; i < 40; i++) SizedBox(height: 40, child: Text('Row $i'))]),
          ),
        ])),
  ));
  await tester.pumpAndSettle();
  return h;
}

double _top(WidgetTester tester) => tester.getTopLeft(find.byType(UiDialogCloseButton)).dy;
FocusNode _handleNode(WidgetTester tester) => tester.widget<UiInteractive>(find.byWidgetPredicate((w) => w is UiInteractive && (w.semanticLabel?.startsWith('Make') ?? false))).focusNode!;
Finder get _title => find.text('Layers').hitTestable();

void main() {
  testWidgets('closed at snap 0; opens to its snap height from the snap value', (tester) async {
    await _sheet(tester);
    expect(_title, findsNothing);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(_title, findsOneWidget);
    final sheetTop = tester.getTopLeft(find.byType(FocusScope).last).dy;
    expect(sheetTop, closeTo(844 - 844 * 0.4, 1));
  });

  testWidgets('the handle steps through the snaps and wraps to the first open one', (tester) async {
    final h = await _sheet(tester, snap: 1);
    await tester.tap(find.bySemanticsLabel('Make larger'));
    await tester.pumpAndSettle();
    expect(h.snap, 2);
    await tester.tap(find.bySemanticsLabel('Make smaller'));
    await tester.pumpAndSettle();
    expect(h.snap, 1);
    expect(h.log, [2, 1]);
  });

  testWidgets('ArrowUp/Down on the handle move one snap', (tester) async {
    final h = await _sheet(tester, snap: 1);
    _handleNode(tester).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(h.snap, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(h.snap, 0);
  });

  testWidgets('dragging the header follows the finger and rests at the nearest snap', (tester) async {
    final h = await _sheet(tester, snap: 1);
    final start = _top(tester);
    final g = await tester.startGesture(tester.getCenter(_title));
    await g.moveBy(const Offset(0, -30));
    await g.moveBy(const Offset(0, -100));
    await tester.pump();
    expect(_top(tester), closeTo(start - 130, 1));
    // Most of the way to 0.9 (from 0.4 that's 422px), slowly: nearest is 0.9.
    for (var i = 0; i < 20; i++) {
      await g.moveBy(const Offset(0, -10));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await g.up();
    await tester.pumpAndSettle();
    expect(h.snap, 2);
  });

  testWidgets('a flick on the header moves one snap that way though it travels only 80px', (tester) async {
    final h = await _sheet(tester, snap: 1);
    await tester.fling(_title, const Offset(0, -80), 1500);
    await tester.pumpAndSettle();
    expect(h.snap, 2);
    await tester.fling(_title, const Offset(0, 80), 1500);
    await tester.pumpAndSettle();
    expect(h.snap, 1);
  });

  testWidgets('pulling the body down at its top moves the sheet down', (tester) async {
    final h = await _sheet(tester, snap: 1);
    await tester.fling(find.text('Row 1'), const Offset(0, 200), 1500);
    await tester.pumpAndSettle();
    expect(h.snap, 0);
  });

  testWidgets('pushing the body up grows the sheet before the content scrolls', (tester) async {
    final h = await _sheet(tester, snap: 1);
    await tester.timedDrag(find.text('Row 1'), const Offset(0, -300), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(h.snap, 2);
    expect(find.text('Row 0').hitTestable(), findsOneWidget, reason: 'the content did not scroll');
  });

  testWidgets('Escape (focus inside), the close button and the back button close it', (tester) async {
    final h = await _sheet(tester, snap: 1);
    _handleNode(tester).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(h.snap, 0);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(UiDialogCloseButton));
    await tester.pumpAndSettle();
    expect(h.snap, 0);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(h.snap, 0);
  });

  testWidgets('non-modal: opening does not move focus and the page stays usable', (tester) async {
    final page = FocusNode();
    addTearDown(page.dispose);
    await _sheet(tester, pageNode: page);
    page.requestFocus();
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(page.hasPrimaryFocus, isTrue);
    expect(find.text('Page').hitTestable(), findsOneWidget);
  });

  testWidgets('modal: backdrop, focus moves in and stays, page hidden; a backdrop tap closes and focus returns', (tester) async {
    final handle = tester.ensureSemantics();
    final page = FocusNode();
    addTearDown(page.dispose);
    final h = await _sheet(tester, backdrop: true, pageNode: page);
    page.requestFocus();
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(UiBackdrop), findsOneWidget);
    expect(page.hasFocus, isFalse);
    expect(find.semantics.byLabel('Page'), findsNothing);
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(page.hasFocus, isFalse, reason: 'Tab stays inside');
    }
    await tester.tapAt(const Offset(195, 100));
    await tester.pumpAndSettle();
    expect(h.snap, 0);
    // Faded out (it stays mounted at 0 so it never brightens again mid-close) and out of the way.
    expect(find.byType(UiBackdrop).hitTestable(), findsNothing);
    expect(tester.widget<AnimatedOpacity>(find.ancestor(of: find.byType(UiBackdrop), matching: find.byType(AnimatedOpacity))).opacity, 0);
    expect(find.semantics.byLabel('Close'), findsNothing);
    expect(page.hasPrimaryFocus, isTrue);
    handle.dispose();
  });

  testWidgets('a text field inside raises it to the top snap on a phone', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final c = TextEditingController();
    final f = FocusNode();
    final h = await _sheet(tester, snap: 1, child: EditableText(
      controller: c,
      focusNode: f,
      style: const TextStyle(fontSize: 14),
      cursorColor: const Color(0x00000000),
      backgroundCursorColor: const Color(0x00000000),
    ));
    f.requestFocus();
    await tester.pumpAndSettle();
    expect(h.snap, 2);
    f.unfocus();
    await tester.pumpAndSettle();
    c.dispose();
    f.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('reports its settled height and how much of the screen it covers', (tester) async {
    final h = await _sheet(tester, snap: 1, offset: 56);
    final room = 844 - 56.0;
    expect(h.heights.last, closeTo(room * 0.4, 0.5));
    expect(h.covers.last, closeTo(room * 0.4 + 56, 0.5));
    await tester.tap(find.byType(UiDialogCloseButton));
    await tester.pumpAndSettle();
    expect(h.covers.last, 0);
  });

  testWidgets('meets the tap-target, label and contrast guidelines', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final handle = tester.ensureSemantics();
    // Padded: text flush against the panel's 1px border makes the guideline compare the border.
    await _sheet(tester, snap: 1, child: const Padding(padding: EdgeInsets.all(16), child: Text('Content')));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('golden: non-modal with actions, and modal with backdrop', (tester) async {
    debugDisableShadows = false;
    var i = 0;
    await pumpScreens(tester, (context) {
      final modal = i++ == 1;
      return Stack(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
            UiText('Editor', variant: UiTextVariant.h3),
            UiText('The page stays usable above a non-modal sheet.', variant: UiTextVariant.caption),
          ]),
        ),
        UiBottomSheet(
          snaps: const [0, 0.45, 0.9],
          snap: 1,
          title: modal ? 'Share' : 'Layers',
          backdrop: modal,
          actions: modal ? null : UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedAdd01), label: 'Add layer', size: UiSize.sm, onPressed: () {}),
          // The sheet pads its body (16px sides), so the content brings no padding of its own.
          child: Padding(
            padding: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [
              for (final n in ['Background', 'Title', 'Photo', 'Caption']) UiText(n),
            ]),
          ),
        ),
      ]);
    });
    await expectScreensGolden(tester, 'bottom_sheet');
    debugDisableShadows = true;
  });
}
