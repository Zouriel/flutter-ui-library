import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../../helpers.dart';

List<UiTab> _tabs({bool disabledSecond = false}) => [
      const UiTab(label: 'Overview', child: Text('Overview panel')),
      UiTab(label: 'Activity', disabled: disabledSecond, child: const Text('Activity panel')),
      const UiTab(label: 'Audit log', child: _Counter()),
      const UiTab(label: 'Settings', child: Text('Settings panel')),
    ];

/// A panel with state, to prove inactive panels keep it.
class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: () => setState(() => n++), child: Text('Count $n'));
}

Widget _controlled(List<UiTab> tabs, {int start = 0, ValueChanged<int>? spy}) {
  var sel = start;
  return StatefulBuilder(builder: (context, set) => SizedBox(
        width: 390,
        child: UiTabs(tabs: tabs, selectedIndex: sel, onChanged: (i) {
          spy?.call(i);
          set(() => sel = i);
        }),
      ));
}

FocusNode? get _focused => FocusManager.instance.primaryFocus;

void main() {
  group('UiTabs', () {
    testWidgets('shows only the selected panel; others keep their state', (tester) async {
      await pumpUi(tester, _controlled(_tabs()));
      expect(find.text('Overview panel'), findsOneWidget);
      expect(find.text('Activity panel'), findsNothing);
      await tester.tap(find.text('Audit log'));
      await tester.pump();
      await tester.tap(find.text('Count 0'));
      await tester.pump();
      await tester.tap(find.text('Overview'));
      await tester.pump();
      expect(find.text('Count 1', skipOffstage: false), findsOneWidget);
      await tester.tap(find.text('Audit log'));
      await tester.pump();
      expect(find.text('Count 1'), findsOneWidget);
    });

    testWidgets('roles: a tab bar of selected/unselected tabs and a tab panel', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, _controlled(_tabs(), start: 2));
      final tab = tester.getSemantics(find.text('Audit log')).getSemanticsData();
      expect(tab.role, SemanticsRole.tab);
      expect(tab.flagsCollection.isSelected, Tristate.isTrue);
      expect(tester.getSemantics(find.text('Overview')).getSemanticsData().flagsCollection.isSelected, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('keyboard: arrows select with wrap and skip disabled; Home/End; one tab stop', (tester) async {
      final picked = <int>[];
      await pumpUi(tester, Column(children: [_controlled(_tabs(disabledSecond: true), spy: picked.add), const Focus(child: SizedBox(width: 10, height: 10))]));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focused?.debugLabel, 'tab 0');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight); // skips disabled Activity
      await tester.pump();
      expect(picked.last, 2);
      expect(_focused?.debugLabel, 'tab 2');
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(picked.last, 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight); // wraps
      await tester.pump();
      expect(picked.last, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(picked.last, 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(picked.last, 0);
      // Tab leaves the strip instead of walking through every tab.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focused?.debugLabel, isNot(startsWith('tab ')));
    });

    testWidgets('the strip scrolls and keeps the selected tab in view', (tester) async {
      final tabs = [for (var i = 0; i < 10; i++) UiTab(label: 'Section number $i', child: Text('Panel $i'))];
      var sel = 0;
      late StateSetter set;
      await pumpUi(tester, StatefulBuilder(builder: (context, s) {
        set = s;
        return SizedBox(width: 390, child: UiTabs(tabs: tabs, selectedIndex: sel, onChanged: (i) => s(() => sel = i)));
      }));
      expect(tester.takeException(), isNull);
      set(() => sel = 8);
      await tester.pumpAndSettle();
      final r = tester.getRect(find.text('Section number 8'));
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(390));
      // Labels never wrap.
      expect(r.height, lessThan(20));
    });

    testWidgets('icon-only tabs share the width and are named by their label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, SizedBox(width: 300, child: UiTabs(selectedIndex: 0, onChanged: (_) {}, tabs: const [
        UiTab(label: 'Home', icon: HugeIcons.strokeRoundedHome01, iconOnly: true, child: SizedBox()),
        UiTab(label: 'Search', icon: HugeIcons.strokeRoundedSearch01, iconOnly: true, child: SizedBox()),
        UiTab(label: 'Settings', icon: HugeIcons.strokeRoundedSettings01, iconOnly: true, child: SizedBox()),
      ])));
      expect(find.bySemanticsLabel('Search'), findsOneWidget);
      final widths = [for (final e in find.byType(UiInteractive).evaluate()) (e.renderObject! as RenderBox).size.width];
      expect(widths.toSet().length, 1);
      expect(widths.first, closeTo((300 - 8) / 3, 0.01));
      handle.dispose();
    });

    testWidgets('align: center centres fitting tabs along a full-width rule in LTR and RTL', (tester) async {
      for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
        await pumpUi(
          tester,
          Directionality(
            textDirection: dir,
            child: SizedBox(
              width: 390,
              child: UiTabs(
                align: UiTabsAlignment.center,
                selectedIndex: 0,
                onChanged: (_) {},
                tabs: const [UiTab(label: 'One'), UiTab(label: 'Two')],
              ),
            ),
          ),
        );
        final stripRect = tester.getRect(find.byType(UiTabs));
        final oneRect = tester.getRect(find.text('One'));
        final twoRect = tester.getRect(find.text('Two'));
        final groupCenter = (oneRect.left < twoRect.left ? (oneRect.left + twoRect.right) : (twoRect.left + oneRect.right)) / 2;
        expect(stripRect.width, 390);
        expect(groupCenter, closeTo(stripRect.center.dx, 1.5));
      }
    });

    testWidgets('align: center still starts at tab 0 and scrolls when tabs overflow in LTR and RTL', (tester) async {
      final tabs = [for (var i = 0; i < 10; i++) UiTab(label: 'Album number $i')];
      for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
        await pumpUi(tester, Directionality(
          textDirection: dir,
          child: SizedBox(width: 320, child: UiTabs(align: UiTabsAlignment.center, tabs: tabs, selectedIndex: 0, onChanged: (_) {})),
        ));
        final first = tester.getRect(find.text('Album number 0'));
        expect(first.left, greaterThanOrEqualTo(0));
        expect(first.right, lessThanOrEqualTo(320));
      }
    });

    testWidgets('strip-only tabs omit child, panel gap and tabPanel semantics', (tester) async {
      final handle = tester.ensureSemantics();
      var sel = 0;
      await pumpUi(tester, StatefulBuilder(builder: (context, set) => SizedBox(
        width: 390,
        child: UiTabs(
          align: UiTabsAlignment.center,
          selectedIndex: sel,
          onChanged: (i) => set(() => sel = i),
          tabs: const [UiTab(label: 'Ceremony'), UiTab(label: 'Reception'), UiTab(label: 'Portraits')],
        ),
      )));
      final stripSize = tester.getSize(find.byType(UiTabs));
      final btnSize = tester.getSize(find.byType(UiInteractive).first);
      // No t.space4 (16px) panel gap beneath the strip.
      expect(stripSize.height, closeTo(btnSize.height, 1.0));
      await tester.tap(find.text('Reception'));
      await tester.pump();
      expect(sel, 1);
      handle.dispose();
    });

    testWidgets('golden: centered and strip-only tabs', (tester) async {
      await expectThemedGolden(tester, 'tabs_centered_strip', height: 220, (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          UiTabs(
            align: UiTabsAlignment.center,
            selectedIndex: 1,
            onChanged: (_) {},
            tabs: const [UiTab(label: 'Ceremony'), UiTab(label: 'Reception'), UiTab(label: 'Portraits')],
          ),
          UiTabs(
            align: UiTabsAlignment.center,
            selectedIndex: 0,
            onChanged: (_) {},
            tabs: const [
              UiTab(label: 'Photos', child: UiText('Centered tabs with a panel below.')),
              UiTab(label: 'Videos', child: UiText('Videos panel.')),
            ],
          ),
        ],
      ));
    });

    testWidgets('appearance: glow omits underline and rule, places glow under selected only, and moves it on selection', (tester) async {
      var sel = 0;
      var appearance = UiTabsAppearance.line;
      late StateSetter set;
      await pumpUi(tester, StatefulBuilder(builder: (context, s) {
        set = s;
        return SizedBox(
          width: 390,
          child: UiTabs(
            appearance: appearance,
            align: UiTabsAlignment.fill,
            selectedIndex: sel,
            onChanged: (i) => s(() => sel = i),
            tabs: const [UiTab(label: 'Ceremony'), UiTab(label: 'Reception'), UiTab(label: 'Portraits')],
          ),
        );
      }));

      // Default line appearance: 1px rule ColoredBox present, no glow, selected tab has 2px non-transparent bottom border.
      expect(find.byKey(const ValueKey('ui-tab-glow')), findsNothing);
      expect(find.descendant(of: find.byType(UiTabs), matching: find.byType(ColoredBox)), findsOneWidget);
      BoxDecoration selectedLineDeco() =>
          (tester.widget<AnimatedContainer>(find.descendant(of: find.byType(UiInteractive).at(sel), matching: find.byType(AnimatedContainer))).decoration! as BoxDecoration);
      expect((selectedLineDeco().border! as Border).bottom.color.a, greaterThan(0));

      // Switch to glow appearance: no 1px rule ColoredBox, selected tab bottom border is transparent, one glow positioned under tab 0.
      set(() => appearance = UiTabsAppearance.glow);
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(UiTabs), matching: find.byType(ColoredBox)), findsNothing);
      expect((selectedLineDeco().border! as Border).bottom.color.a, 0);
      expect(find.byKey(const ValueKey('ui-tab-glow')), findsOneWidget);

      final tab0Rect = tester.getRect(find.byType(UiInteractive).at(0));
      final tab1Rect = tester.getRect(find.byType(UiInteractive).at(1));
      var glowPos = tester.widget<AnimatedPositioned>(find.byKey(const ValueKey('ui-tab-glow')));
      expect(glowPos.left, closeTo(0, 0.5));
      expect(glowPos.width, closeTo(tab0Rect.width, 0.5));

      // Select tab 1: the single glow moves to tab 1.
      await tester.tap(find.text('Reception'));
      await tester.pumpAndSettle();
      expect(sel, 1);
      expect(find.byKey(const ValueKey('ui-tab-glow')), findsOneWidget);
      glowPos = tester.widget<AnimatedPositioned>(find.byKey(const ValueKey('ui-tab-glow')));
      expect(glowPos.left, closeTo(tab1Rect.left - tab0Rect.left, 0.5));
      expect(glowPos.width, closeTo(tab1Rect.width, 0.5));
    });

    testWidgets('align: fill gives equal widths, centres labels, and truncates long labels with ellipsis', (tester) async {
      await pumpUi(
        tester,
        SizedBox(
          width: 300,
          child: UiTabs(
            align: UiTabsAlignment.fill,
            appearance: UiTabsAppearance.glow,
            selectedIndex: 0,
            onChanged: (_) {},
            tabs: const [
              UiTab(label: 'One'),
              UiTab(label: 'Two'),
              UiTab(label: 'A very long portraits album label that cannot fit'),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final interactives = find.byType(UiInteractive).evaluate().toList();
      final widths = [for (final e in interactives) (e.renderObject! as RenderBox).size.width];
      expect(widths.length, 3);
      expect(widths[0], closeTo((300 - 8) / 3, 0.01));
      expect(widths[1], closeTo(widths[0], 0.01));
      expect(widths[2], closeTo(widths[0], 0.01));

      // Short label is centred inside its tab share.
      final tab0Rect = tester.getRect(find.byType(UiInteractive).at(0));
      final text0Rect = tester.getRect(find.text('One'));
      expect(text0Rect.center.dx, closeTo(tab0Rect.center.dx, 1.0));

      // Long label uses TextOverflow.ellipsis and stays within its tab share.
      final longText = tester.widget<Text>(find.text('A very long portraits album label that cannot fit'));
      expect(longText.overflow, TextOverflow.ellipsis);
    });

    testWidgets('golden: glow and fill tabs', (tester) async {
      await expectThemedGolden(tester, 'tabs_glow_fill', height: 220, (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          UiTabs(
            appearance: UiTabsAppearance.glow,
            align: UiTabsAlignment.fill,
            selectedIndex: 0,
            onChanged: (_) {},
            tabs: const [UiTab(label: 'Ceremony'), UiTab(label: 'Reception'), UiTab(label: 'Portraits')],
          ),
          UiTabs(
            appearance: UiTabsAppearance.glow,
            align: UiTabsAlignment.fill,
            selectedIndex: 1,
            onChanged: (_) {},
            tabs: const [
              UiTab(label: 'Ceremony'),
              UiTab(label: 'Reception & dinner party'),
              UiTab(label: 'Portraits'),
            ],
          ),
        ],
      ));
    });
  });

  group('UiAccordion', () {
    const items = [
      UiAccordionItem(title: 'Shipping', child: Text('Ships in 2 days')),
      UiAccordionItem(title: 'Returns', child: Text('30 days')),
      UiAccordionItem(title: 'Warranty', child: Text('Two years')),
    ];

    testWidgets('single: opening one closes the other; closed panels are hidden', (tester) async {
      final handle = tester.ensureSemantics();
      Set<int>? last;
      await pumpUi(tester, SizedBox(width: 390, child: UiAccordion(onChanged: (s) => last = s, children: items)));
      expect(find.text('Ships in 2 days'), findsNothing);
      await tester.tap(find.text('Shipping'));
      await tester.pumpAndSettle();
      expect(find.text('Ships in 2 days'), findsOneWidget);
      final head = tester.getSemantics(find.text('Shipping')).getSemanticsData();
      expect(head.flagsCollection.isExpanded, Tristate.isTrue);
      expect(head.flagsCollection.isHeader, isTrue);
      await tester.tap(find.text('Returns'));
      await tester.pumpAndSettle();
      expect(last, {1});
      expect(find.text('Ships in 2 days'), findsNothing);
      expect(find.text('30 days'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('multiple keeps several open; a lone item toggles itself', (tester) async {
      await pumpUi(tester, SizedBox(width: 390, child: Column(children: [
        const UiAccordion(multiple: true, initiallyOpen: {0}, children: items),
        const UiAccordionItem(title: 'Alone', child: Text('Lone body')),
      ])));
      expect(find.text('Ships in 2 days'), findsOneWidget);
      await tester.tap(find.text('Warranty'));
      await tester.pumpAndSettle();
      expect(find.text('Ships in 2 days'), findsOneWidget);
      expect(find.text('Two years'), findsOneWidget);
      await tester.tap(find.text('Alone'));
      await tester.pumpAndSettle();
      expect(find.text('Lone body'), findsOneWidget);
      await tester.tap(find.text('Alone'));
      await tester.pumpAndSettle();
      expect(find.text('Lone body'), findsNothing);
    });

    testWidgets('Enter toggles a focused header; rows are 48dp on touch', (tester) async {
      await pumpUi(tester, const SizedBox(width: 390, child: UiAccordion(children: items)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Ships in 2 days'), findsOneWidget);
      final row = find.ancestor(of: find.text('Returns'), matching: find.byType(AnimatedContainer)).first;
      expect(tester.getSize(row), const Size(390, 48));
    });
  });

  group('UiList', () {
    testWidgets('is a list of items; interactive rows tap, select and disable', (tester) async {
      final handle = tester.ensureSemantics();
      final taps = <String>[];
      await pumpUi(tester, SizedBox(width: 390, child: UiList(bordered: true, children: [
        UiListItem(onTap: () => taps.add('a'), selected: true, child: const Text('Alpha')),
        UiListItem(onTap: () => taps.add('b'), enabled: false, child: const Text('Beta')),
        const UiListItem(trailing: Text('3'), child: Text('Gamma')),
      ])));
      await tester.tap(find.text('Alpha'));
      await tester.tap(find.text('Beta'));
      expect(taps, ['a']);
      expect(tester.getSemantics(find.byType(UiList)).getSemanticsData().role, SemanticsRole.list);
      final alpha = tester.getSemantics(find.text('Alpha')).getSemanticsData();
      expect(alpha.flagsCollection.isSelected, Tristate.isTrue);
      expect(tester.getSize(find.ancestor(of: find.text('Alpha'), matching: find.byType(AnimatedContainer)).first).height, 48);
      expect(tester.getSize(find.ancestor(of: find.text('Gamma'), matching: find.byType(AnimatedContainer)).first).height, lessThan(48));
      handle.dispose();
    });

    testWidgets('title and hint render medium title with muted single-line ellipsized hint', (tester) async {
      var tapped = 0;
      await pumpUi(tester, SizedBox(
        width: 220,
        child: UiList(bordered: true, children: [
          UiListItem(
            title: 'Feed photos',
            hint: 'A very long muted description that should clip to one line with an ellipsis',
            leading: const UiIcon(HugeIcons.strokeRoundedImage01),
            trailing: const UiIcon(HugeIcons.strokeRoundedArrowRight01),
            onTap: () => tapped++,
          ),
        ]),
      ));
      final t = tester.element(find.byType(UiListItem)).ui;
      final titleWidget = tester.widget<Text>(find.text('Feed photos'));
      expect(titleWidget.style!.fontWeight, FontWeight.w500);
      final hintWidget = tester.widget<Text>(find.text('A very long muted description that should clip to one line with an ellipsis'));
      expect(hintWidget.maxLines, 1);
      expect(hintWidget.overflow, TextOverflow.ellipsis);
      expect(hintWidget.style!.color, t.textMuted);
      await tester.tap(find.text('Feed photos'));
      expect(tapped, 1);
    });

    testWidgets('golden: list item title and hint', (tester) async {
      await expectThemedGolden(tester, 'list_title_hint', height: 180, (context) => UiList(bordered: true, children: [
        UiListItem(
          title: 'Feed photos',
          hint: '3 of 6 selected for the album feed',
          leading: const UiIcon(HugeIcons.strokeRoundedImage01),
          trailing: const UiIcon(HugeIcons.strokeRoundedArrowRight01),
          onTap: () {},
        ),
        UiListItem(
          title: 'Colours',
          hint: 'Reply pages & QR table card — a very long hint that ellipsizes cleanly',
          leading: const UiIcon(HugeIcons.strokeRoundedPaintBoard),
          trailing: const UiIcon(HugeIcons.strokeRoundedArrowRight01),
          onTap: () {},
        ),
      ]));
    });
  });

  testWidgets('guidelines: tap targets, labels and contrast', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final handle = tester.ensureSemantics();
    try {
      await pumpUi(tester, Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: [
          UiTabs(tabs: _tabs(), selectedIndex: 0, onChanged: (_) {}),
          const UiAccordion(initiallyOpen: {0}, children: [
            UiAccordionItem(title: 'Shipping', child: Text('Ships in 2 days')),
            UiAccordionItem(title: 'Returns', child: Text('30 days')),
          ]),
          UiList(bordered: true, children: [
            UiListItem(onTap: () {}, child: const Text('Profile')),
            UiListItem(onTap: () {}, selected: true, child: const Text('Billing')),
          ]),
        ]),
      ));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('golden: tabs, accordion, list', (tester) async {
    await expectThemedGolden(tester, 'tabs_accordion_list', height: 720, (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        UiTabs(tabs: _tabs(disabledSecond: true), selectedIndex: 2, onChanged: (_) {}),
        UiTabs(selectedIndex: 1, onChanged: (_) {}, tabs: const [
          UiTab(label: 'Home', icon: HugeIcons.strokeRoundedHome01, iconOnly: true, child: SizedBox()),
          UiTab(label: 'Search', icon: HugeIcons.strokeRoundedSearch01, iconOnly: true, child: SizedBox()),
          UiTab(label: 'Settings', icon: HugeIcons.strokeRoundedSettings01, iconOnly: true, child: SizedBox()),
        ]),
        const UiAccordion(initiallyOpen: {0}, children: [
          UiAccordionItem(title: 'What ships with the library?', child: Text('Components, themes and the form engine.')),
          UiAccordionItem(title: 'Can I use my own fonts?', child: Text('Yes.')),
        ]),
        UiList(bordered: true, children: [
          UiListItem(leading: const UiIcon(HugeIcons.strokeRoundedUserCircle), trailing: const Text('Owner'), onTap: () {}, child: const Text('Aminath Shareef')),
          UiListItem(leading: const UiIcon(HugeIcons.strokeRoundedUserCircle), trailing: const Text('Editor'), selected: true, onTap: () {}, child: const Text('Ali Zahir')),
          UiListItem(leading: const UiIcon(HugeIcons.strokeRoundedUserCircle), trailing: const Text('Viewer'), enabled: false, onTap: () {}, child: const Text('Hawwa Nashidha')),
        ]),
      ],
    ));
  });
}
