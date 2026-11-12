import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

// 0.75.1: `UiBottomNavItem.anchor` and `UiTab.anchor` let a tour point at one destination or one
// tab, which apps can't wrap themselves because the library builds those buttons.

final _ctx = GlobalKey();

Future<void> _pumpApp(WidgetTester tester, Widget body) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(390, 844) * 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(
    theme: UiThemeName.light,
    home: Builder(key: _ctx, builder: (_) => body),
  ));
  await tester.pump();
}

Future<void> _steps(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The rect of the interactive button that holds [label] (the item's tile / the tab's button).
Rect _buttonOf(WidgetTester tester, String label) =>
    tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(UiInteractive)).first);

Future<void> _endTour(WidgetTester tester) async {
  UiTour.stop();
  await _steps(tester, 4);
}

void main() {
  const navItems = [
    UiBottomNavItem(label: 'Feed', value: 'feed'),
    UiBottomNavItem(label: 'Inbox', value: 'inbox', anchor: 'nav.inbox'),
    UiBottomNavItem(label: 'Account', value: 'account'),
  ];

  Widget nav(List<UiBottomNavItem> items) => Align(
        alignment: Alignment.bottomCenter,
        child: UiBottomNav(items: items, active: 'feed', safeArea: false),
      );

  testWidgets('a bottom-nav item with an anchor is a tour target, the hole round its whole tile', (tester) async {
    await _pumpApp(tester, nav(navItems));
    expect(UiTour.hasAnchor('nav.inbox'), isTrue);
    final tile = _buttonOf(tester, 'Inbox');
    // The tile is a third of the bar (the Expanded stays outside the anchor).
    expect(tile.width, closeTo(390 / 3, 1));
    expect(tester.getRect(find.byType(UiTourAnchor)), tile);

    final done = UiTour.start(_ctx.currentContext!, const UiTourSpec('t', [UiTourStep('nav.inbox', 'Invitations land here.')]));
    await _steps(tester);
    expect(UiTour.active, 't');
    expect(UiTour.debugHole, tile.inflate(6));
    await _endTour(tester);
    expect(await done, UiTourOutcome.closed);
  });

  testWidgets('bottom-nav items without an anchor register nothing', (tester) async {
    await _pumpApp(tester, nav([for (final i in navItems) UiBottomNavItem(label: i.label, value: i.value)]));
    expect(find.byType(UiTourAnchor), findsNothing);
    expect(UiTour.hasAnchor('nav.inbox'), isFalse);
    expect(await UiTour.start(_ctx.currentContext!, const UiTourSpec('t', [UiTourStep('nav.inbox', 'x')])), UiTourOutcome.closed);
  });

  Widget tabs({bool anchored = true}) => Padding(
        padding: const EdgeInsets.all(16),
        child: UiTabs(tabs: [
          const UiTab(label: 'Received', child: Text('received panel')),
          UiTab(label: 'Hosting', anchor: anchored ? 'tabs.hosting' : null, child: const Text('hosting panel')),
          const UiTab(label: 'Drafts', child: Text('drafts panel')),
        ]),
      );

  testWidgets('a tab with an anchor is a tour target, the hole round its button', (tester) async {
    await _pumpApp(tester, tabs());
    expect(UiTour.hasAnchor('tabs.hosting'), isTrue);
    final button = _buttonOf(tester, 'Hosting');
    expect(tester.getRect(find.byType(UiTourAnchor)), button);

    final done = UiTour.start(_ctx.currentContext!, const UiTourSpec('t', [UiTourStep('tabs.hosting', 'Events you host.')]));
    await _steps(tester);
    expect(UiTour.debugHole, button.inflate(6));
    await _endTour(tester);
    expect(await done, UiTourOutcome.closed);
  });

  testWidgets('tabs without an anchor register nothing', (tester) async {
    await _pumpApp(tester, tabs(anchored: false));
    expect(find.byType(UiTourAnchor), findsNothing);
    expect(UiTour.hasAnchor('tabs.hosting'), isFalse);
    expect(await UiTour.start(_ctx.currentContext!, const UiTourSpec('t', [UiTourStep('tabs.hosting', 'x')])), UiTourOutcome.closed);
  });
}
