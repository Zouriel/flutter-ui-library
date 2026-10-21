import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/layout/pinned_edges.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// 0.41: `UiSidebarLayout.sidebarHeader` / `sidebarFooter`, fixed around the scrolling sidebar, docked
/// and in the drawer (the web `[sidebar-header]` / `[sidebar-footer]`).

Widget _list() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (var i = 1; i <= 80; i++) SizedBox(height: 40, child: Text('Chat $i'))],
    );

Widget _shell({
  double width = 1000,
  EdgeInsets safe = EdgeInsets.zero,
  TextDirection dir = TextDirection.ltr,
  bool parts = true,
  bool? scrollSidebar,
  Widget? sidebar,
  bool fill = true,
}) =>
    MediaQuery(
      key: ValueKey('$width$safe$dir$parts$fill'),
      data: MediaQueryData(size: Size(width, 600), padding: safe),
      child: Directionality(
        textDirection: dir,
        child: SizedBox(
          width: width,
          height: 600,
          child: UiSidebarLayout(
            bar: false,
            fill: fill,
            scrollSidebar: scrollSidebar,
            sidebarHeader: parts ? UiButton(label: 'New chat', onPressed: () {}) : null,
            sidebarFooter: parts
                ? Row(children: [UiButton(label: 'My nurse visits', onPressed: () {}), UiButton(label: 'Profile', onPressed: () {})])
                : null,
            sidebar: sidebar ?? _list(),
            body: Builder(
              builder: (context) => Center(
                child: UiButton(label: 'Menu', onPressed: () => UiSidebarLayout.of(context).toggle()),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.text('Menu'));
  await tester.pumpAndSettle();
}

Color _hairline(WidgetTester tester, {required bool footer}) {
  final box = tester.widget<AnimatedContainer>(find.byKey(footer ? UiPinnedEdges.footerKey : UiPinnedEdges.headerKey));
  final b = (box.decoration! as BoxDecoration).border! as Border;
  return (footer ? b.top : b.bottom).color;
}

void main() {
  for (final mode in ['docked', 'drawer']) {
    testWidgets('$mode: the footer stays at the bottom and the header at the top while 80 rows scroll', (tester) async {
      final width = mode == 'docked' ? 1000.0 : 390.0;
      await pumpUi(tester, _shell(width: width), size: Size(width, 600));
      if (mode == 'drawer') await _openDrawer(tester);
      final header = tester.getRect(find.text('New chat'));
      final footer = tester.getRect(find.byKey(UiPinnedEdges.footerKey));
      expect(footer.bottom, 600, reason: 'the footer ends at the bottom of the screen');
      expect(header.top, lessThan(30), reason: 'the header is at the top');
      expect(tester.getRect(find.text('Chat 80')).top, greaterThan(600));
      expect(find.descendant(of: find.byType(UiSidebarLayout), matching: find.byType(Scrollable)), findsOneWidget, reason: 'only the list scrolls');
      for (final fixed in ['New chat', 'My nurse visits', 'Profile']) {
        expect(find.ancestor(of: find.text(fixed), matching: find.byType(Scrollable)), findsNothing, reason: fixed);
      }
      expect(_hairline(tester, footer: true).a, greaterThan(0));
      expect(_hairline(tester, footer: false).a, 0);

      await tester.drag(find.text('Chat 5'), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Chat 5')).top, lessThan(header.top));
      expect(tester.getRect(find.text('New chat')), header);
      expect(tester.getRect(find.byKey(UiPinnedEdges.footerKey)), footer);
      expect(_hairline(tester, footer: false).a, greaterThan(0), reason: 'scrolled away from the top');
    });
  }

  testWidgets('fill keeps the header below the notch and the footer above the home indicator', (tester) async {
    await pumpUi(tester, _shell(safe: const EdgeInsets.only(top: 30, bottom: 34, left: 10)), size: const Size(1000, 600));
    expect(tester.getTopLeft(find.byKey(UiPinnedEdges.headerKey)).dy, 0);
    final newChat = find.widgetWithText(UiButton, 'New chat');
    expect(tester.getTopLeft(newChat).dy, 30 + 12, reason: 'space3 under the notch');
    expect(tester.getBottomLeft(find.byKey(UiPinnedEdges.footerKey)).dy, 600);
    expect(tester.getBottomLeft(find.widgetWithText(UiButton, 'My nurse visits')).dy, 600 - 34 - 12, reason: 'clear of the home indicator');
    expect(tester.getTopLeft(newChat).dx, 10 + 12, reason: 'start inset');
    // The list in between pads only by space3: the insets went to the outer parts.
    final header = tester.getRect(find.byKey(UiPinnedEdges.headerKey));
    expect(tester.getTopLeft(find.text('Chat 1')).dy, header.bottom + 12);
  });

  testWidgets('scrollSidebar false: the app\'s own paging ListView is the scrolling body', (tester) async {
    var count = 40;
    await pumpUi(
      tester,
      _shell(
        scrollSidebar: false,
        sidebar: StatefulBuilder(
          builder: (context, set) => NotificationListener<ScrollEndNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 100) set(() => count += 40);
              return false;
            },
            child: ListView.builder(
              itemCount: count,
              itemBuilder: (context, i) => SizedBox(height: 40, child: Text('Row ${i + 1}')),
            ),
          ),
        ),
      ),
      size: const Size(1000, 600),
    );
    final footer = tester.getRect(find.byKey(UiPinnedEdges.footerKey));
    expect(footer.bottom, 600);
    expect(find.descendant(of: find.byType(UiSidebarLayout), matching: find.byType(Scrollable)), findsOneWidget);
    expect(_hairline(tester, footer: true).a, greaterThan(0), reason: 'the app list drives the hairline too');
    await tester.fling(find.text('Row 3'), const Offset(0, -3000), 4000);
    await tester.pumpAndSettle();
    expect(count, 80, reason: 'the list paged');
    expect(tester.getRect(find.byKey(UiPinnedEdges.footerKey)), footer);
  });

  testWidgets('without header and footer the sidebar is as before', (tester) async {
    await pumpUi(tester, _shell(parts: false, safe: const EdgeInsets.only(top: 30, left: 10)), size: const Size(1000, 600));
    expect(find.byKey(UiPinnedEdges.headerKey), findsNothing);
    expect(find.byType(UiPinnedEdges), findsNothing);
    expect(tester.getTopLeft(find.text('Chat 1')), const Offset(10 + 12, 30 + 12));
  });

  testWidgets('right to left: the parts stay top and bottom, their content starts on the right', (tester) async {
    await pumpUi(tester, _shell(dir: TextDirection.rtl), size: const Size(1000, 600));
    final side = tester.getRect(find.byType(UiPinnedEdges));
    expect(side.right, 1000, reason: 'the sidebar is on the right');
    expect(tester.getTopRight(find.byKey(UiPinnedEdges.headerKey)).dx, 1000);
    expect(tester.getTopRight(find.text('Chat 1')).dx, 1000 - 12);
    expect(tester.getBottomLeft(find.byKey(UiPinnedEdges.footerKey)).dy, 600);
  });

  testWidgets('drawer: focus moves header, list, footer; the drawer is labelled; screen-reader order matches', (tester) async {
    final handle = tester.ensureSemantics();
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    await pumpUi(
      tester,
      _shell(
        width: 390,
        sidebar: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          UiButton(label: 'Row A', onPressed: () {}),
          for (var i = 0; i < 30; i++) const SizedBox(height: 40),
          UiButton(label: 'Row Z', onPressed: () {}),
        ]),
      ),
      size: const Size(390, 600),
    );
    await _openDrawer(tester);
    final seen = <String?>[];
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final ctx = FocusManager.instance.primaryFocus?.context;
      seen.add(ctx == null ? null : find.ancestor(of: find.byWidget(ctx.widget), matching: find.byType(UiButton)).evaluate().map((e) => (e.widget as UiButton).label).firstOrNull);
    }
    expect(seen, ['New chat', 'Row A', 'Row Z', 'My nurse visits', 'Profile']);
    expect(find.semantics.byLabel('Navigation'), findsOneWidget);
    final order = tester.semantics.simulatedAccessibilityTraversal().map((n) => n.getSemanticsData().label).where((l) => l.isNotEmpty).toList();
    expect(order.indexOf('New chat'), greaterThan(-1));
    expect(order.indexOf('New chat'), lessThan(order.indexOf('Row A')));
    expect(order.indexOf('Row A'), lessThan(order.indexOf('My nurse visits')));
    handle.dispose();
  });

  testWidgets('guidelines with a fixed header and footer in the drawer', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, _shell(width: 390, sidebar: const Text('Short list')), size: const Size(390, 600));
    await _openDrawer(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('golden: sidebar with a fixed header and footer', (tester) async {
    await expectThemedGolden(
      tester,
      'sidebar_edges',
      (context) => SizedBox(
        height: 440,
        child: UiSidebarLayout(
          bar: false,
          fill: true,
          breakpoint: 0,
          sidebarWidth: 220,
          sidebarHeader: UiButton(label: 'New chat', block: true, onPressed: () {}),
          sidebarFooter: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            UiButton(label: 'My nurse visits', variant: UiButtonVariant.ghost, onPressed: () {}),
            UiButton(label: 'Profile', variant: UiButtonVariant.ghost, onPressed: () {}),
          ]),
          sidebar: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 1; i <= 20; i++) SizedBox(height: 36, child: UiText('Conversation $i'))]),
          body: const Center(child: UiText('Chat')),
        ),
      ),
      height: 472,
    );
  });
}
