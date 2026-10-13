import 'dart:ui' show Tristate;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../../helpers.dart';

const _groups = [
  UiSideNavGroup(label: 'Workspace', items: [
    UiSideNavItem(label: 'Inbox', value: 'inbox', icon: HugeIcons.strokeRoundedInbox, badge: '12'),
    UiSideNavItem(label: 'Calendar', value: 'cal', icon: HugeIcons.strokeRoundedCalendar01),
    UiSideNavItem(label: 'Archived', value: 'arch', icon: HugeIcons.strokeRoundedFolder01, disabled: true),
  ]),
  UiSideNavGroup(label: 'Account', items: [
    UiSideNavItem(label: 'Settings', value: 'settings', icon: HugeIcons.strokeRoundedSettings01),
  ]),
];

const _bottom = [
  UiBottomNavItem(label: 'Home', value: 'home', icon: HugeIcons.strokeRoundedHome01),
  UiBottomNavItem(label: 'Search', value: 'search', icon: HugeIcons.strokeRoundedSearch01),
  UiBottomNavItem(label: 'Alerts', value: 'alerts', icon: HugeIcons.strokeRoundedNotification01, badge: '3'),
  UiBottomNavItem(label: 'Profile', value: 'me', icon: HugeIcons.strokeRoundedUserCircle),
];

const _crumbs = [
  UiBreadcrumb(label: 'Home', value: '/'),
  UiBreadcrumb(label: 'Projects', value: '/projects'),
  UiBreadcrumb(label: 'Website redesign', value: '/projects/web'),
  UiBreadcrumb(label: 'Design system', value: '/projects/web/ds'),
  UiBreadcrumb(label: 'Buttons'),
];

const _menus = [
  UiMenubarMenu(label: 'File', items: [
    UiMenubarItem(label: 'New', value: 'new'),
    UiMenubarItem(label: 'Open…', value: 'open'),
    UiMenubarItem(label: 'Save', value: 'save', disabled: true),
    UiMenubarItem(label: 'Export', value: 'export'),
  ]),
  UiMenubarMenu(label: 'Edit', items: [
    UiMenubarItem(label: 'Undo', value: 'undo'),
    UiMenubarItem(label: 'Redo', value: 'redo'),
  ]),
  UiMenubarMenu(label: 'View', items: [UiMenubarItem(label: 'Zoom in', value: 'zoom')]),
];

Future<void> _key(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pump();
}

FocusNode? get _focused => FocusManager.instance.primaryFocus;

void main() {
  group('UiNavbar', () {
    testWidgets('is one 52px row when wide and wraps the links under the brand when narrow', (tester) async {
      Widget bar(double w) => SizedBox(
            width: w,
            child: UiNavbar(
              label: 'Main',
              brand: const Text('Acme'),
              links: [for (final l in ['Docs', 'Pricing', 'Blog']) UiButton(label: l, variant: UiButtonVariant.ghost, size: UiSize.sm, onPressed: () {})],
              actions: [UiButton(label: 'Sign in', size: UiSize.sm, onPressed: () {})],
            ),
          );
      await pumpUi(tester, bar(900), size: const Size(1000, 600));
      expect(tester.getSize(find.byType(UiNavbar)).height, 52 + 2);
      expect(tester.getCenter(find.text('Docs')).dy, closeTo(tester.getCenter(find.text('Acme')).dy, 1));

      await pumpUi(tester, bar(390));
      expect(tester.getTopLeft(find.text('Docs')).dy, greaterThan(tester.getBottomLeft(find.text('Acme')).dy));
      expect(tester.getCenter(find.text('Sign in')).dy, closeTo(tester.getCenter(find.text('Acme')).dy, 1));
    });

    testWidgets('is a labelled navigation landmark', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const UiNavbar(label: 'Main', brand: Text('Acme')));
      final d = tester.getSemantics(find.byType(UiNavbar)).getSemanticsData();
      expect(d.role, SemanticsRole.navigation);
      expect(d.label, 'Main');
      handle.dispose();
    });
  });

  group('UiSideNav', () {
    testWidgets('a tap reports the item and value; disabled items do nothing', (tester) async {
      final values = <String>[];
      final items = <UiSideNavItem>[];
      await pumpUi(tester, SizedBox(width: 260, child: UiSideNav(groups: _groups, active: 'inbox', onChanged: values.add, onNavigate: items.add)));
      await tester.tap(find.text('Calendar'));
      await tester.tap(find.text('Archived'));
      expect(values, ['cal']);
      expect(items.single.label, 'Calendar');
    });

    testWidgets('the active item is selected for screen readers; rows are 48dp on touch', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const SizedBox(width: 260, child: UiSideNav(groups: _groups, active: 'inbox')));
      expect(tester.getSemantics(find.text('Inbox')).getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
      expect(tester.getSemantics(find.text('Calendar')).getSemanticsData().flagsCollection.isSelected, Tristate.isFalse);
      final nav = tester.getSemantics(find.byType(UiSideNav)).getSemanticsData();
      expect(nav.role, SemanticsRole.navigation);
      expect(nav.label, 'Sidebar');
      final row = find.ancestor(of: find.text('Calendar'), matching: find.byType(AnimatedContainer)).first;
      expect(tester.getSize(row).height, 48);
      expect(tester.getSize(row).width, 260);
      handle.dispose();
    });
  });

  group('UiBottomNav', () {
    testWidgets('switches on tap, marks the active item selected and reads badges', (tester) async {
      final handle = tester.ensureSemantics();
      String? active = 'home';
      await pumpUi(tester, StatefulBuilder(builder: (context, set) => SizedBox(
            width: 390,
            child: UiBottomNav(items: _bottom, active: active, label: 'Main', onChanged: (v) => set(() => active = v)),
          )));
      expect(tester.getSize(find.byType(UiBottomNav)).height, 56 + 2);
      await tester.tap(find.text('Search'));
      await tester.pump();
      expect(active, 'search');
      expect(tester.getSemantics(find.text('Search')).getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
      expect(find.bySemanticsLabel('Alerts, 3'), findsOneWidget);
      // Equal widths.
      expect(tester.getSize(find.ancestor(of: find.text('Home'), matching: find.byType(AnimatedContainer)).first).width, closeTo((390 - 2) / 4, 0.01));
      handle.dispose();
    });

    testWidgets('adds the bottom safe area under the row', (tester) async {
      await tester.pumpWidget(UiApp(home: MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(bottom: 20)),
        child: Align(alignment: Alignment.bottomCenter, child: UiBottomNav(items: _bottom, active: 'home', onChanged: (_) {})),
      )));
      expect(tester.getSize(find.byType(UiBottomNav)).height, 56 + 20 + 2);
    });
  });

  group('UiBreadcrumbs', () {
    testWidgets('earlier crumbs navigate; the last is the current page', (tester) async {
      final handle = tester.ensureSemantics();
      final hits = <UiBreadcrumb>[];
      await pumpUi(tester, SizedBox(width: 1000, child: UiBreadcrumbs(items: _crumbs, onNavigate: hits.add)), size: const Size(1100, 400));
      await tester.tap(find.text('Projects'));
      await tester.tap(find.text('Buttons'));
      expect(hits.map((c) => c.value), ['/projects']);
      expect(tester.getSemantics(find.text('Buttons')).getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
      expect(tester.getSemantics(find.text('Projects')).getSemanticsData().flagsCollection.isLink, isTrue);
      expect(find.bySemanticsLabel(RegExp('Show')), findsNothing);
      handle.dispose();
    });

    testWidgets('collapses the middle when narrow and expands on tap', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const SizedBox(width: 300, child: UiBreadcrumbs(items: _crumbs)));
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Buttons'), findsOneWidget);
      expect(find.text('Projects'), findsNothing);
      expect(tester.getSize(find.byType(UiBreadcrumbs)).height, 48); // one line
      final more = find.bySemanticsLabel(RegExp(r'^Show \d more$'));
      expect(more, findsOneWidget);
      await tester.tap(more);
      await tester.pump();
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Website redesign'), findsOneWidget);
      handle.dispose();
    });
  });

  group('UiPagination', () {
    test('truncates like the web', () {
      expect(uiPaginationItems(1, 1, 1), [1]);
      expect(uiPaginationItems(1, 5, 1), [1, 2, -1, 5]);
      expect(uiPaginationItems(5, 10, 1), [1, -1, 4, 5, 6, -1, 10]);
      expect(uiPaginationItems(3, 5, 1), [1, 2, 3, 4, 5]);
      expect(uiPaginationItems(10, 10, 2), [1, -1, 8, 9, 10]);
    });

    testWidgets('prev/next are disabled at the ends; pages report clamped values', (tester) async {
      final handle = tester.ensureSemantics();
      final got = <int>[];
      await pumpUi(tester, SizedBox(width: 1000, child: UiPagination(page: 1, total: 10, onChanged: got.add)), size: const Size(1100, 400));
      await tester.tap(find.bySemanticsLabel('Previous page'));
      await tester.tap(find.bySemanticsLabel('Next page'));
      await tester.tap(find.bySemanticsLabel('Page 10'));
      await tester.tap(find.bySemanticsLabel('Page 1'));
      expect(got, [2, 10]);
      final prev = tester.getSemantics(find.bySemanticsLabel('Previous page')).getSemanticsData();
      expect(prev.flagsCollection.isEnabled, Tristate.isFalse);
      expect(tester.getSemantics(find.bySemanticsLabel('Page 1')).getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
      handle.dispose();
    });

    testWidgets('fits a phone by dropping siblings, then by going compact', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, SizedBox(width: 358, child: UiPagination(page: 5, total: 10, onChanged: (_) {})));
      expect(find.bySemanticsLabel('Page 4'), findsNothing); // siblings dropped to 0
      expect(find.bySemanticsLabel('Page 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await pumpUi(tester, SizedBox(width: 200, child: UiPagination(page: 5, total: 10, onChanged: (_) {})));
      expect(find.text('Page 5 of 10'), findsOneWidget);
      handle.dispose();
    });
  });

  group('UiStepper', () {
    const steps = [UiStep(label: 'Account'), UiStep(label: 'Shipping', description: 'Where to'), UiStep(label: 'Payment'), UiStep(label: 'Review')];

    testWidgets('reads each step with its position and state', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const SizedBox(width: 700, child: UiStepper(steps: steps, active: 1)), size: const Size(800, 400));
      expect(find.bySemanticsLabel('Step 1 of 4, Account, completed'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 2 of 4, Shipping, Where to, current'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 4 of 4, Review, not started'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('horizontal when the labels fit, vertical on a phone', (tester) async {
      await pumpUi(tester, const SizedBox(width: 700, child: UiStepper(steps: steps, active: 1)), size: const Size(800, 400));
      expect(tester.getCenter(find.text('Account')).dy, closeTo(tester.getCenter(find.text('Review')).dy, 1));
      await pumpUi(tester, const SizedBox(width: 300, child: UiStepper(steps: steps, active: 1)));
      expect(tester.getTopLeft(find.text('Review')).dy, greaterThan(tester.getTopLeft(find.text('Account')).dy + 3 * 24));
      expect(tester.getTopLeft(find.text('Review')).dx, tester.getTopLeft(find.text('Account')).dx);
      expect(tester.takeException(), isNull);
    });
  });

  group('UiAnchorNav', () {
    testWidgets('follows the scroll and scrolls to a section when tapped', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final keys = [for (var i = 0; i < 4; i++) GlobalKey()];
      final items = [for (var i = 0; i < 4; i++) UiAnchorItem(key: keys[i], label: 'Section ${i + 1}')];
      await pumpUi(tester, SizedBox(
        width: 390,
        height: 800,
        child: Column(children: [
          UiAnchorNav(items: items, controller: controller, axis: Axis.horizontal),
          Expanded(
            child: SingleChildScrollView(
              controller: controller,
              child: Column(children: [for (var i = 0; i < 4; i++) SizedBox(key: keys[i], height: 600, child: Text('Body ${i + 1}'))]),
            ),
          ),
        ]),
      ));
      bool selected(String l) => tester.widget<UiInteractive>(find.ancestor(of: find.text(l), matching: find.byType(UiInteractive))).selected!;
      expect(selected('Section 1'), isTrue);
      controller.jumpTo(1300); // section 3 starts at 1200
      await tester.pumpAndSettle();
      expect(selected('Section 3'), isTrue);
      expect(selected('Section 1'), isFalse);
      await tester.tap(find.text('Section 2'));
      await tester.pumpAndSettle();
      expect(controller.offset, 600);
      expect(selected('Section 2'), isTrue);
    });
  });

  group('UiMenubar', () {
    testWidgets('opens on tap, chooses an item, closes; disabled items do nothing', (tester) async {
      final chosen = <String>[];
      await pumpUi(tester, UiMenubar(menus: _menus, onSelect: (i) => chosen.add(i.value)), size: const Size(800, 600));
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      expect(find.text('Export'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(chosen, isEmpty);
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(chosen, ['export']);
      expect(find.text('Export'), findsNothing);
    });

    testWidgets('keyboard: Down opens and focuses the first item, arrows/Home/End move, skipping disabled; Escape returns to the top item', (tester) async {
      final chosen = <String>[];
      await pumpUi(tester, UiMenubar(menus: _menus, onSelect: (i) => chosen.add(i.value)), size: const Size(800, 600));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focused?.debugLabel, 'menubar top 0');
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_focused?.debugLabel, 'menubar top 1');
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(_focused?.debugLabel, 'menu New');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.arrowDown); // skips the disabled Save
      expect(_focused?.debugLabel, 'menu Export');
      await _key(tester, LogicalKeyboardKey.home);
      expect(_focused?.debugLabel, 'menu New');
      await _key(tester, LogicalKeyboardKey.end);
      expect(_focused?.debugLabel, 'menu Export');
      await _key(tester, LogicalKeyboardKey.arrowRight); // next menu, opened
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsOneWidget);
      expect(_focused?.debugLabel, 'menu Undo');
      await _key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsNothing);
      expect(_focused?.debugLabel, 'menubar top 1');
      await _key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_focused?.debugLabel, 'menu Undo');
      await _key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chosen, ['undo']);
    });

    testWidgets('in an app bar row (unbounded width) it follows the screen width', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, Row(mainAxisSize: MainAxisSize.min, children: [UiMenubar(menus: _menus, onSelect: (_) {})]));
      expect(find.text('File'), findsNothing);
      expect(find.bySemanticsLabel('Menu'), findsOneWidget);
      await pumpUi(tester, Row(mainAxisSize: MainAxisSize.min, children: [UiMenubar(menus: _menus, onSelect: (_) {})]), size: const Size(900, 600));
      expect(find.text('File'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('on a phone it is one overflow button with every menu as a group', (tester) async {
      final handle = tester.ensureSemantics();
      final chosen = <String>[];
      await pumpUi(tester, UiMenubar(menus: _menus, onSelect: (i) => chosen.add(i.value)));
      expect(find.text('File'), findsNothing);
      final trigger = find.bySemanticsLabel('Menu');
      expect(tester.getSemantics(trigger).getSemanticsData().flagsCollection.isExpanded, Tristate.isFalse);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(find.text('FILE'), findsOneWidget);
      expect(find.text('EDIT'), findsOneWidget);
      expect(tester.getSemantics(find.text('FILE')).getSemanticsData().flagsCollection.isHeader, isTrue);
      await tester.tap(find.text('Redo'));
      await tester.pumpAndSettle();
      expect(chosen, ['redo']);
      expect(find.text('FILE'), findsNothing);
      handle.dispose();
    });
  });

  testWidgets('guidelines: tap targets, labels and contrast', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final handle = tester.ensureSemantics();
    try {
      await pumpUi(tester, SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: [
            UiNavbar(label: 'Main', brand: const Text('Acme'), actions: [UiButton(label: 'Sign in', size: UiSize.sm, onPressed: () {})]),
            UiBreadcrumbs(items: _crumbs, onNavigate: (_) {}),
            UiPagination(page: 3, total: 9, onChanged: (_) {}),
            const UiStepper(steps: [UiStep(label: 'One'), UiStep(label: 'Two'), UiStep(label: 'Three')], active: 1),
            UiMenubar(menus: _menus, onSelect: (_) {}),
          ]),
        ),
      ), size: const Size(390, 1400));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      // The side nav and bottom nav use 11px labels, too thin for the pixel-sampling contrast check
      // (it reads antialiased edge pixels as the text colour), and a disabled item is faded on
      // purpose (WCAG exempts it). Targets are checked on screen; their colours on the tokens.
      await pumpUi(tester, Column(spacing: 16, children: [
        UiSideNav(groups: _groups, active: 'inbox', onChanged: (_) {}),
        UiBottomNav(items: _bottom, active: 'home', label: 'Tabs', onChanged: (_) {}),
      ]));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      for (final th in UiThemeName.values) {
        final t = uiThemeTokens[th]!;
        double ratio(Color a, Color b) {
          final la = a.computeLuminance(), lb = b.computeLuminance();
          return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
        }
        expect(ratio(t.textMuted, t.surface), greaterThanOrEqualTo(4.5), reason: '$th muted label');
        expect(ratio(t.primary, t.surface), greaterThanOrEqualTo(4.5), reason: '$th active bottom item');
        expect(ratio(t.dangerContrast, t.danger), greaterThanOrEqualTo(4.5), reason: '$th badge');
        expect(ratio(t.textMuted, t.surfaceRaised), greaterThanOrEqualTo(4.5), reason: '$th side-nav badge');
      }
    } finally {
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('golden: navbar, side nav, bottom nav', (tester) async {
    await expectThemedGolden(tester, 'nav_bars', height: 560, (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        UiNavbar(
          brand: const Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: [UiIcon(HugeIcons.strokeRoundedChartLineData01), Text('Acme')]),
          links: [for (final l in ['Docs', 'Pricing', 'Blog', 'Changelog']) UiButton(label: l, variant: UiButtonVariant.ghost, size: UiSize.sm, onPressed: () {})],
          actions: [UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedSearch01), label: 'Search', size: UiSize.sm, onPressed: () {})],
        ),
        const UiSideNav(groups: _groups, active: 'inbox'),
        UiBottomNav(items: _bottom, active: 'search', onChanged: (_) {}),
      ],
    ));
  });

  testWidgets('golden: breadcrumbs, pagination, stepper, anchor nav', (tester) async {
    final controllers = <ScrollController>[];
    addTearDown(() {
      for (final c in controllers) {
        c.dispose();
      }
    });
    await expectThemedGolden(tester, 'nav_trail', height: 760, (context) {
      final controller = ScrollController();
      controllers.add(controller);
      return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        const UiBreadcrumbs(items: _crumbs),
        const UiBreadcrumbs(items: [UiBreadcrumb(label: 'Home'), UiBreadcrumb(label: 'Settings')]),
        UiPagination(page: 4, total: 12, onChanged: (_) {}),
        UiPagination(page: 4, total: 12, onChanged: (_) {}, siblings: 0),
        const UiStepper(steps: [UiStep(label: 'Cart'), UiStep(label: 'Pay'), UiStep(label: 'Done')], active: 1),
        const UiStepper(steps: [UiStep(label: 'Account', description: 'Email and password'), UiStep(label: 'Shipping', description: 'Where it goes'), UiStep(label: 'Payment'), UiStep(label: 'Review')], active: 2),
        SizedBox(
          height: 1,
          child: SingleChildScrollView(controller: controller, child: const SizedBox(height: 10)),
        ),
        UiAnchorNav(
          controller: controller,
          items: [for (final l in ['Overview', 'Install', 'Usage']) UiAnchorItem(key: GlobalKey(), label: l)],
        ),
      ],
    );
    });
  });

  for (final theme in [UiThemeName.dark, UiThemeName.light]) {
    testWidgets('golden: menubar open, wide and on a phone (${theme.name})', (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(700, 420) * 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(
        theme: theme,
        home: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 400, child: Align(alignment: Alignment.topLeft, child: UiMenubar(menus: _menus, breakpoint: 300, onSelect: (_) {}))),
            const SizedBox(width: 60),
            SizedBox(width: 200, child: Align(alignment: Alignment.topRight, child: UiMenubar(menus: _menus, onSelect: (_) {}))),
          ]),
        ),
      ));
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await expectLater(find.byType(UiApp), matchesGoldenFile('goldens/menubar_wide_${theme.name}.png'));
      await tester.tapAt(const Offset(300, 280)); // outside: closes
      await tester.pumpAndSettle();
      await tester.tap(find.byType(UiMenubar).last);
      await tester.pumpAndSettle();
      await expectLater(find.byType(UiApp), matchesGoldenFile('goldens/menubar_phone_${theme.name}.png'));
    });
  }
}
