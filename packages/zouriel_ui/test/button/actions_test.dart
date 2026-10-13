import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../choice/host.dart';
import '../helpers.dart';


const _align = [
  UiSegmentedOption(value: 'left', label: 'Left'),
  UiSegmentedOption(value: 'center', label: 'Center', disabled: true),
  UiSegmentedOption(value: 'right', label: 'Right'),
];

const _items = [
  UiDropdownItem(label: 'Edit', value: 'edit'),
  UiDropdownItem(label: 'Archive', value: 'archive', disabled: true),
  UiDropdownItem(label: 'Share', value: 'share'),
  UiDropdownItem(label: 'Delete', value: 'delete', danger: true),
];

void main() {
  group('UiSegmented', () {
    testWidgets('tap chooses; arrows wrap and skip disabled; one tab stop', (tester) async {
      String? last;
      await pumpUi(tester, Column(children: [
        Host<String?>(initial: 'left', builder: (v, set) => UiSegmented<String>(options: _align, value: v, onChanged: (n) { last = n; set(n); })),
        UiButton(label: 'After', onPressed: () {}),
      ]));
      await tester.tap(find.text('Right'));
      await tester.pump();
      expect(last, 'right');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'roving 2');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(last, 'left', reason: 'wraps');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(last, 'right', reason: 'skips the disabled option');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, isNot(startsWith('roving')));
    });

    testWidgets('semantics: named radio group; glyph options keep the label as their name', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, UiSegmented<String>(
        label: 'Alignment',
        options: const [UiSegmentedOption(value: 'l', label: 'Align left', glyph: 'L'), UiSegmentedOption(value: 'r', label: 'Align right', icon: UiIcon(HugeIcons.strokeRoundedTextAlignRight))],
        value: 'l',
        onChanged: (_) {},
      ));
      expect(tester.getSemantics(find.bySemanticsLabel('Alignment')).getSemanticsData().role, SemanticsRole.radioGroup);
      expect(tester.getSemantics(find.bySemanticsLabel('Align left')), containsSemantics(isChecked: true, isInMutuallyExclusiveGroup: true));
      expect(tester.getSemantics(find.bySemanticsLabel('Align right')), containsSemantics(isChecked: false, isInMutuallyExclusiveGroup: true));
      expect(find.text('L'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('scrolls sideways instead of overflowing a narrow parent', (tester) async {
      await pumpUi(tester, SizedBox(width: 160, child: UiSegmented<int>(
        options: [for (var i = 0; i < 8; i++) UiSegmentedOption(value: i, label: 'Option $i')], value: 0, onChanged: (_) {})));
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('UiToggleButton', () {
    testWidgets('toggles and reports its state', (tester) async {
      final handle = tester.ensureSemantics();
      bool? last;
      await pumpUi(tester, Host<bool>(initial: false, builder: (v, set) => UiToggleButton(pressed: v, label: 'Bold', onChanged: (n) { last = n; set(n); })));
      await tester.tap(find.text('Bold'));
      await tester.pumpAndSettle();
      expect(last, isTrue);
      expect(tester.getSemantics(find.text('Bold')), containsSemantics(isButton: true, hasToggledState: true, isToggled: true));
      await tester.tap(find.text('Bold'));
      expect(last, isFalse);
      handle.dispose();
    });

    testWidgets('disabled ignores taps', (tester) async {
      await pumpUi(tester, const UiToggleButton(pressed: false, label: 'Off', onChanged: null));
      await tester.tap(find.text('Off'));
      expect(tester.takeException(), isNull);
    });
  });

  group('UiButtonGroup', () {
    testWidgets('joins buttons: 1px overlap, square inner corners, named group', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, UiButtonGroup(label: 'View', children: [
        UiButton(label: 'Day', variant: UiButtonVariant.outline, onPressed: () {}),
        UiButton(label: 'Week', variant: UiButtonVariant.outline, onPressed: () {}),
        UiButton(label: 'Month', variant: UiButtonVariant.outline, onPressed: () {}),
      ]));
      final a = tester.getRect(find.widgetWithText(UiButton, 'Day'));
      final b = tester.getRect(find.widgetWithText(UiButton, 'Week'));
      expect(b.left, a.right - 1);
      BorderRadiusGeometry? radiusOf(String text) => (tester.widget<AnimatedContainer>(find.descendant(of: find.widgetWithText(UiButton, text), matching: find.byType(AnimatedContainer))).decoration! as BoxDecoration).borderRadius;
      final r = uiThemeTokens[UiThemeName.dark]!.radius;
      expect(radiusOf('Day')!.resolve(TextDirection.ltr), BorderRadius.horizontal(left: Radius.circular(r)));
      expect(radiusOf('Week')!.resolve(TextDirection.ltr), BorderRadius.zero);
      expect(radiusOf('Month')!.resolve(TextDirection.ltr), BorderRadius.horizontal(right: Radius.circular(r)));
      expect(find.bySemanticsLabel('View'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('taps reach each button', (tester) async {
      final taps = <String>[];
      await pumpUi(tester, UiButtonGroup(children: [
        UiButton(label: 'A', onPressed: () => taps.add('A')),
        UiButton(label: 'B', onPressed: () => taps.add('B')),
      ]));
      await tester.tap(find.text('B'));
      await tester.tap(find.text('A'));
      expect(taps, ['B', 'A']);
    });
  });

  group('UiSplitButton', () {
    testWidgets('main and caret fire separately; the caret is named', (tester) async {
      final handle = tester.ensureSemantics();
      var main = 0, menu = 0;
      await pumpUi(tester, UiSplitButton<String>(label: 'Save', onPressed: () => main++, onMenu: () => menu++));
      await tester.tap(find.text('Save'));
      await tester.tap(find.bySemanticsLabel('More actions'));
      expect((main, menu), (1, 1));
      handle.dispose();
    });

    testWidgets('with items, the caret opens the built-in menu', (tester) async {
      final handle = tester.ensureSemantics();
      String? chosen;
      await pumpUi(tester, UiSplitButton<String>(label: 'Save', onPressed: () {}, items: _items, onSelected: (i) => chosen = i.value));
      await tester.tap(find.bySemanticsLabel('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(chosen, 'share');
      expect(find.text('Share'), findsNothing);
      handle.dispose();
    });
  });

  group('UiDropdownButton', () {
    testWidgets('opens below, focuses the first item, arrows wrap, Enter chooses and refocuses the trigger', (tester) async {
      String? chosen;
      await pumpUi(tester, Padding(
        padding: const EdgeInsets.all(20),
        child: UiDropdownButton<String>(label: 'Actions', items: _items, onSelected: (i) => chosen = i.value),
      ));
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Edit')).top, greaterThan(tester.getRect(find.text('Actions')).bottom));
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'menu item 0');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'menu item 2', reason: 'skips the disabled item');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'menu item 3', reason: 'wraps to the end');
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'menu item 0');
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chosen, 'delete');
      expect(find.text('Edit'), findsNothing);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'dropdown trigger');
    });

    testWidgets('Escape closes and returns focus; a tap outside closes; disabled items do nothing', (tester) async {
      String? chosen;
      await pumpUi(tester, UiDropdownButton<String>(label: 'Actions', items: _items, onSelected: (i) => chosen = i.value));
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pump();
      expect(chosen, isNull);
      expect(find.text('Archive'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsNothing);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'dropdown trigger');
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(380, 800));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('Tab closes the menu', (tester) async {
      await pumpUi(tester, UiDropdownButton<String>(label: 'Actions', items: _items, onSelected: (_) {}));
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('semantics: expanded trigger, a menu of menu items', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, UiDropdownButton<String>(label: 'Actions', items: _items, onSelected: (_) {}));
      expect(tester.getSemantics(find.text('Actions')), containsSemantics(isButton: true, hasExpandedState: true, isExpanded: false));
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.text('Actions')), containsSemantics(hasExpandedState: true, isExpanded: true));
      expect(tester.getSemantics(find.text('Share')).getSemanticsData().role, SemanticsRole.menuItem);
      handle.dispose();
    });

    testWidgets('null onSelected disables the trigger', (tester) async {
      await pumpUi(tester, const UiDropdownButton<String>(label: 'Actions', items: _items, onSelected: null));
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsNothing);
    });
  });

  group('UiFab', () {
    testWidgets('named by its label, tappable, pinned to the corner by UiFabHost', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(home: UiFabHost(
        fab: UiFab(icon: const UiIcon(HugeIcons.strokeRoundedAdd01), label: 'New note', onPressed: () => taps++),
        child: const SizedBox.expand(),
      )));
      await tester.tap(find.bySemanticsLabel('New note'));
      expect(taps, 1);
      final r = tester.getRect(find.byType(UiFab));
      expect(r.right, 390 - 24);
      expect(r.bottom, 844 - 24);
      expect(r.size, const Size(52, 52));
      handle.dispose();
    });

    testWidgets('sm grows to 48 on phones', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await pumpUi(tester, UiFab(icon: const UiIcon(HugeIcons.strokeRoundedAdd01), label: 'Add', size: UiFabSize.sm, onPressed: () {}));
      expect(tester.getSize(find.byType(UiFab)), const Size(48, 48));
      debugDefaultTargetPlatformOverride = null;
    });
  });

  testWidgets('meets the Android tap-target, labelled-target and contrast guidelines', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final handle = tester.ensureSemantics();
    await pumpUi(tester, Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        // Enabled options only: the contrast guideline can't see UiInteractive's disabled flag
        // (it sits one node below the merge boundary), and dimmed text is exempt anyway.
        UiSegmented<String>(options: [_align[0], _align[2]], value: 'left', onChanged: (_) {}),
        UiSegmented<String>(options: [_align[0], _align[2]], value: 'left', size: UiSize.sm, onChanged: (_) {}),
        UiToggleButton(pressed: true, label: 'Bold', onChanged: (_) {}),
        UiButtonGroup(children: [UiButton(label: 'One', variant: UiButtonVariant.outline, onPressed: () {}), UiButton(label: 'Two', variant: UiButtonVariant.outline, onPressed: () {})]),
        UiSplitButton<String>(label: 'Save', onPressed: () {}, onMenu: () {}),
        UiDropdownButton<String>(label: 'Actions', items: _items.where((i) => !i.disabled).toList(), onSelected: (_) {}),
        UiFab(icon: const UiIcon(HugeIcons.strokeRoundedAdd01), label: 'Add', size: UiFabSize.sm, onPressed: () {}),
      ]),
    ));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('golden: segmented, toggles, groups, split, dropdown, fab', (tester) async {
    await expectThemedGolden(tester, 'actions', height: 520, (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        UiSegmented<String>(options: _align, value: 'left', onChanged: (_) {}),
        Row(spacing: 8, children: [
          UiSegmented<String>(size: UiSize.sm, options: const [UiSegmentedOption(value: 'a', label: 'Day'), UiSegmentedOption(value: 'b', label: 'Week')], value: 'b', onChanged: (_) {}),
          UiSegmented<String>(size: UiSize.lg, options: const [
            UiSegmentedOption(value: 'l', label: 'Left', icon: UiIcon(HugeIcons.strokeRoundedTextAlignLeft)),
            UiSegmentedOption(value: 'c', label: 'Centre', icon: UiIcon(HugeIcons.strokeRoundedTextAlignCenter)),
          ], value: 'c', onChanged: (_) {}),
        ]),
        Wrap(spacing: 8, children: [
          UiToggleButton(pressed: true, label: 'Bold', icon: const UiIcon(HugeIcons.strokeRoundedTextBold), onChanged: (_) {}),
          UiToggleButton(pressed: false, label: 'Italic', onChanged: (_) {}),
          UiToggleButton(pressed: false, icon: const UiIcon(HugeIcons.strokeRoundedTextItalic), semanticLabel: 'Italic', onChanged: (_) {}),
          const UiToggleButton(pressed: true, label: 'Off', onChanged: null),
        ]),
        UiButtonGroup(children: [
          for (final l in ['Day', 'Week', 'Month']) UiButton(label: l, variant: UiButtonVariant.outline, onPressed: () {}),
        ]),
        Wrap(spacing: 8, children: [
          UiSplitButton<String>(label: 'Save', onPressed: () {}, onMenu: () {}),
          UiSplitButton<String>(label: 'Publish', variant: UiButtonVariant.outline, onPressed: () {}, onMenu: () {}),
          UiSplitButton<String>(label: 'Delete', variant: UiButtonVariant.destructive, size: UiSize.sm, onPressed: () {}, onMenu: () {}),
        ]),
        Wrap(spacing: 8, children: [
          UiDropdownButton<String>(label: 'Actions', items: _items, onSelected: (_) {}),
          UiDropdownButton<String>(label: 'Primary', variant: UiButtonVariant.primary, items: _items, onSelected: (_) {}),
          UiFab(icon: const UiIcon(HugeIcons.strokeRoundedAdd01), label: 'Add', onPressed: () {}),
          UiFab(icon: const UiIcon(HugeIcons.strokeRoundedEdit02), label: 'Edit', size: UiFabSize.sm, onPressed: () {}),
        ]),
      ],
    ));
  });

  testWidgets('golden: the open dropdown menu', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390, 300) * 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(theme: UiThemeName.light, home: Padding(
      padding: const EdgeInsets.all(16),
      child: Align(alignment: Alignment.topLeft, child: UiDropdownButton<String>(label: 'Actions', items: [
        ..._items.take(3),
        const UiDropdownItem(label: 'Delete forever', value: 'd', danger: true, icon: UiIcon(HugeIcons.strokeRoundedDelete02)),
      ], onSelected: (_) {})),
    )));
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(UiApp), matchesGoldenFile('goldens/dropdown_open.png'));
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });
}
