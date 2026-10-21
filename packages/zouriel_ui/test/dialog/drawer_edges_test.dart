import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/layout/pinned_edges.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// 0.41: a drawer's fixed header and footer around the scrolling body (the web `[drawer-header]` /
/// `[drawer-footer]`). Dhirumi: "My nurse visits" and the profile must stay in the viewport, not
/// sit at the end of a long chats list.

const _rows = 60;

Widget _rowsBody(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (var i = 1; i <= _rows; i++) SizedBox(height: 40, child: Text('Chat $i'))],
    );

Widget _header(BuildContext context) => UiButton(label: 'New chat', onPressed: () {});
Widget _footer(BuildContext context) => Row(spacing: 8, children: [
      UiButton(label: 'My nurse visits', onPressed: () {}),
      UiButton(label: 'Profile', onPressed: () {}),
    ]);

/// Opens a left drawer at phone size, with [padding] / [insets] as the device's safe area and keyboard.
Future<void> _openDrawer(
  WidgetTester tester, {
  WidgetBuilder? builder = _rowsBody,
  UiScrollBodyBuilder? bodyBuilder,
  bool parts = true,
  FakeViewPadding padding = FakeViewPadding.zero,
  FakeViewPadding insets = FakeViewPadding.zero,
}) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  tester.view.padding = padding;
  tester.view.viewInsets = insets;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(
    home: Builder(
      builder: (context) => Center(
        child: UiButton(
          label: 'Open',
          onPressed: () => showUiDrawer<void>(
            context: context,
            side: UiDrawerSide.left,
            title: 'Chats',
            builder: bodyBuilder == null ? builder : null,
            bodyBuilder: bodyBuilder,
            headerBuilder: parts ? _header : null,
            footerBuilder: parts ? _footer : null,
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

/// The colour of the 1px border a fixed part keeps (shown as the hairline).
Color _hairline(WidgetTester tester, String label, {required bool top}) {
  final box = tester.widget<AnimatedContainer>(find.byKey(top ? UiPinnedEdges.footerKey : UiPinnedEdges.headerKey));
  expect(find.descendant(of: find.byWidget(box), matching: find.text(label)), findsOneWidget);
  final border = (box.decoration! as BoxDecoration).border! as Border;
  return (top ? border.top : border.bottom).color;
}

bool _shown(Color c) => c.a > 0;

void main() {
  testWidgets('the footer stays at the bottom and the header at the top while 60 rows scroll', (tester) async {
    await _openDrawer(tester);
    final panel = tester.getRect(find.byType(UiDialogScope));
    final header = tester.getRect(find.text('New chat'));
    final footer = tester.getRect(find.text('My nurse visits'));
    expect(footer.bottom, lessThanOrEqualTo(panel.bottom - 12), reason: 'in the viewport, space3 above the bottom edge');
    expect(footer.bottom, greaterThan(panel.bottom - 12 - 48), reason: 'at the bottom, not after the list');
    expect(header.top, lessThan(120), reason: 'right under the title bar');
    expect(find.text('Chat $_rows'), findsOneWidget);
    expect(tester.getRect(find.text('Chat $_rows')).top, greaterThan(panel.bottom), reason: 'the last row is out of sight below');

    await tester.drag(find.text('Chat 5'), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Chat 5')).top, lessThan(header.top), reason: 'the body scrolled');
    expect(tester.getRect(find.text('New chat')), header, reason: 'the header did not move');
    expect(tester.getRect(find.text('My nurse visits')), footer, reason: 'the footer did not move');
  });

  testWidgets('the body is the only scrollable; the header and footer sit outside it', (tester) async {
    await _openDrawer(tester);
    final inDrawer = find.descendant(of: find.byType(UiDrawer), matching: find.byType(Scrollable));
    expect(inDrawer, findsOneWidget);
    for (final fixed in ['New chat', 'My nurse visits', 'Profile']) {
      expect(find.ancestor(of: find.text(fixed), matching: find.byType(Scrollable)), findsNothing, reason: fixed);
    }
    expect(find.ancestor(of: find.text('Chat 1'), matching: find.byType(Scrollable)), findsOneWidget);
  });

  testWidgets('hairlines: over the footer while rows are below, under the header once scrolled', (tester) async {
    await _openDrawer(tester);
    expect(_shown(_hairline(tester, 'My nurse visits', top: true)), isTrue);
    expect(_shown(_hairline(tester, 'New chat', top: false)), isFalse);
    await tester.drag(find.text('Chat 5'), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(_shown(_hairline(tester, 'New chat', top: false)), isTrue);
    expect(_shown(_hairline(tester, 'My nurse visits', top: true)), isTrue);
    await tester.fling(find.text('Chat 30'), const Offset(0, -3000), 3000);
    await tester.pumpAndSettle();
    expect(_shown(_hairline(tester, 'My nurse visits', top: true)), isFalse, reason: 'scrolled to the end');
  });

  testWidgets('no hairlines while everything fits', (tester) async {
    await _openDrawer(tester, builder: (context) => const Text('Short body'));
    expect(_shown(_hairline(tester, 'My nurse visits', top: true)), isFalse);
    expect(_shown(_hairline(tester, 'New chat', top: false)), isFalse);
  });

  testWidgets('the footer keeps clear of the home indicator and, full height, of the keyboard', (tester) async {
    final dpr = tester.view.devicePixelRatio;
    await _openDrawer(tester, padding: FakeViewPadding(bottom: 34 * dpr));
    expect(tester.getRect(find.byType(UiDialogScope)).bottom, 844);
    final f = find.byKey(UiPinnedEdges.footerKey);
    expect(tester.getRect(f).bottom, 844 - 34, reason: 'the footer ends above the inset');

    await tester.pumpWidget(const SizedBox());
    await _openDrawer(tester, insets: FakeViewPadding(bottom: 300 * dpr));
    final f2 = find.byKey(UiPinnedEdges.footerKey);
    expect(tester.getRect(f2).bottom, 844 - 300, reason: 'above the keyboard');
  });

  testWidgets('bodyBuilder: a paging ListView on the drawer controller is the scrolling body', (tester) async {
    var count = 30;
    ScrollController? got;
    late StateSetter setList;
    await _openDrawer(
      tester,
      bodyBuilder: (context, controller) {
        got = controller;
        return StatefulBuilder(builder: (context, set) {
          setList = set;
          return NotificationListener<ScrollEndNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 200) set(() => count += 30);
              return false;
            },
            child: ListView.builder(
              controller: controller,
              padding: UiDrawer.bodyPadding(context),
              itemCount: count,
              itemBuilder: (context, i) => SizedBox(height: 40, child: Text('Item ${i + 1}')),
            ),
          );
        });
      },
    );
    expect(got, isNotNull);
    expect(got!.hasClients, isTrue);
    final footer = tester.getRect(find.text('My nurse visits'));
    got!.jumpTo(got!.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.drag(find.text('Item 25'), const Offset(0, -50));
    await tester.pumpAndSettle();
    expect(count, 60, reason: 'reaching the end loaded the next page');
    setList(() {});
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('My nurse visits')), footer);
    expect(find.descendant(of: find.byType(UiDrawer), matching: find.byType(Scrollable)), findsOneWidget);
  });

  testWidgets('without header and footer the drawer is as before', (tester) async {
    await _openDrawer(tester, parts: false);
    expect(find.text('New chat'), findsNothing);
    expect(find.descendant(of: find.byType(UiDrawer), matching: find.byType(SingleChildScrollView)), findsOneWidget);
    // The body starts right under the title bar, padded by space3 / space4 as in 0.40.
    final title = tester.getRect(find.byType(UiDialogHeader));
    expect(tester.getTopLeft(find.text('Chat 1')), Offset(16, title.bottom + 12));
  });

  testWidgets('focus moves header, body, footer; screen readers read them in that order; labelled', (tester) async {
    final handle = tester.ensureSemantics();
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    await _openDrawer(
      tester,
      builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        UiButton(label: 'Row A', onPressed: () {}),
        UiButton(label: 'Row B', onPressed: () {}),
        for (var i = 0; i < 30; i++) const SizedBox(height: 40),
        UiButton(label: 'Row Z', onPressed: () {}),
      ]),
    );
    final seen = <String>[];
    for (var i = 0; i < 7; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final ctx = FocusManager.instance.primaryFocus?.context;
      final label = ctx == null ? null : find.ancestor(of: find.byWidget(ctx.widget), matching: find.byType(UiButton)).evaluate().map((e) => (e.widget as UiButton).label).firstOrNull;
      final close = ctx != null && find.ancestor(of: find.byWidget(ctx.widget), matching: find.byType(UiDialogCloseButton)).evaluate().isNotEmpty;
      seen.add(close ? 'Close' : (label ?? '?'));
    }
    expect(seen, ['Close', 'New chat', 'Row A', 'Row B', 'Row Z', 'My nurse visits', 'Profile']);

    final dialog = tester.getSemantics(find.byType(UiDialogScope));
    expect(dialog.label, 'Chats');
    expect(dialog.role, SemanticsRole.dialog);
    final order = tester.semantics.simulatedAccessibilityTraversal().map((n) => n.getSemanticsData().label).where((l) => l.isNotEmpty).toList();
    final at = order.indexOf;
    expect(at('New chat'), greaterThan(-1));
    expect(at('New chat'), lessThan(at('Row A')));
    expect(at('Row B'), lessThan(at('My nurse visits')));
    expect(at('My nurse visits'), lessThan(at('Profile')));
    handle.dispose();
  });

  testWidgets('right to left: the parts keep their order and their content starts on the right', (tester) async {
    await pumpUi(
      tester,
      Directionality(
        textDirection: TextDirection.rtl,
        child: UiDrawer(
          side: UiDrawerSide.right,
          title: 'ޗެޓް',
          header: const Text('NEW'),
          footer: const Text('VISITS'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 1; i <= _rows; i++) SizedBox(height: 40, child: Text('Chat $i'))]),
        ),
      ),
    );
    final panel = tester.getRect(find.byType(UiDialogScope));
    expect(tester.getTopRight(find.text('NEW')).dx, panel.right - 16);
    expect(tester.getTopRight(find.text('VISITS')).dx, panel.right - 16);
    expect(tester.getRect(find.text('NEW')).top, lessThan(tester.getRect(find.text('Chat 1')).top));
    expect(tester.getRect(find.text('VISITS')).bottom, panel.bottom - 12);
  });

  testWidgets('guidelines with a header and footer', (tester) async {
    final handle = tester.ensureSemantics();
    // A body that fits: the contrast check misreads a row the viewport cuts in half.
    await _openDrawer(tester, builder: (context) => const Text('Short body'));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('golden: drawer with a fixed header and footer', (tester) async {
    await expectThemedGolden(
      tester,
      'drawer_edges',
      (context) => SizedBox(
        height: 480,
        child: UiDrawer(
          side: UiDrawerSide.left,
          title: 'Chats',
          header: UiButton(label: 'New chat', block: true, onPressed: () {}),
          footer: Row(spacing: 8, children: [UiButton(label: 'My nurse visits', variant: UiButtonVariant.ghost, onPressed: () {}), UiButton(label: 'Profile', variant: UiButtonVariant.ghost, onPressed: () {})]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 1; i <= 20; i++) SizedBox(height: 36, child: UiText('Conversation $i'))]),
        ),
      ),
      height: 520,
    );
  });
}
