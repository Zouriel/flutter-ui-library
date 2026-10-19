import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// Fixes from the controls audit, mirrored from the web library.
void main() {
  testWidgets('a disabled multi-select keeps its chips but drops their remove buttons; it draws a chevron', (tester) async {
    Widget field(bool enabled) => SizedBox(
          width: 320,
          child: UiMultiSelect(
            options: const [UiComboboxOption(label: 'Design', value: 'design'), UiComboboxOption(label: 'Sales', value: 'sales')],
            value: const ['design', 'sales'],
            label: 'Teams',
            enabled: enabled,
            onChanged: (_) {},
          ),
        );
    await pumpUi(tester, field(true));
    expect(find.bySemanticsLabel('Remove Design'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is UiIcon && w.icon == HugeIcons.strokeRoundedArrowDown01), findsOneWidget);
    await pumpUi(tester, field(false));
    expect(find.text('Design'), findsOneWidget);
    expect(find.bySemanticsLabel('Remove Design'), findsNothing);
    expect(find.bySemanticsLabel('Remove Sales'), findsNothing);
  });

  testWidgets('a checkbox list fills only the active row; ticks mark the chosen ones', (tester) async {
    await pumpUi(
      tester,
      SizedBox(
        width: 300,
        child: UiListboxPanel(
          activeIndex: 1,
          checkboxes: true,
          multiselect: true,
          onPick: (_) {},
          items: const [UiListboxItem(label: 'Chosen', selected: true), UiListboxItem(label: 'Active'), UiListboxItem(label: 'Plain')],
        ),
      ),
    );
    Color? fillOf(String label) {
      final box = tester.widget<Container>(find.ancestor(of: find.text(label), matching: find.byType(Container)).first);
      return (box.decoration as BoxDecoration?)?.color;
    }

    final t = tester.element(find.text('Chosen')).ui;
    expect(fillOf('Chosen'), isNull);
    expect(fillOf('Active'), t.elevatedHover);
    expect(fillOf('Plain'), isNull);
    // 4px panel + 8px row padding: text starts 12px (+1 border) in, under a field's text.
    final panel = tester.getTopLeft(find.byType(UiListboxPanel));
    expect(tester.getTopLeft(find.text('Plain')).dx - panel.dx, 13 + 16 + t.space2); // checkbox 16 + gap 8
  });

  testWidgets('the bottom sheet pads its body like a dialog, so content lines up with the title', (tester) async {
    await pumpUi(
      tester,
      const SizedBox(
        width: 390,
        height: 844,
        child: UiBottomSheet(snaps: [0, 0.5], snap: 1, title: 'Layers', child: Text('Layer 1')),
      ),
    );
    final title = tester.getTopLeft(find.text('Layers'));
    final content = tester.getTopLeft(find.text('Layer 1'));
    expect(content.dx, title.dx);
    expect(content.dx, 16);
  });

  testWidgets('the dialog close button lines up with the 16px inset of the body and footer', (tester) async {
    await pumpUi(
      tester,
      SizedBox(
        width: 390,
        height: 500,
        child: UiModal(title: 'Edit', onClose: () {}, footer: UiButton(onPressed: () {}, child: const Text('Save')), child: const Text('Body')),
      ),
    );
    final t = tester.element(find.text('Body')).ui;
    final panel = tester.getRect(find.byType(UiDialogScope));
    // The visible 26px box, centred in its touch target (tests run as a touch platform).
    final close = tester.getCenter(find.byType(UiIconButton).first).dx + t.sizeSm / 2;
    final save = tester.getRect(find.byType(UiButton).last);
    expect(close, closeTo(save.right, 0.5));
    expect(panel.right - close, closeTo(t.space4, 0.5));
  });

  testWidgets('a bottom toast stack moves up above a snackbar that would cover it', (tester) async {
    final snacks = UiSnackbarController();
    final toasts = UiToastController();
    addTearDown(snacks.dispose);
    addTearDown(toasts.dispose);
    await pumpUi(
      tester,
      SizedBox(
        width: 390,
        height: 844,
        child: UiSnackbarHost(controller: snacks, child: UiToastHost(controller: toasts, child: const SizedBox.expand())),
      ),
    );
    toasts.show('Layer deleted', duration: Duration.zero);
    await tester.pumpAndSettle();
    final before = tester.getRect(find.text('Layer deleted'));
    snacks.show('Deleted “Title”', action: UiSnackbarAction(label: 'Undo', run: () {}), duration: Duration.zero);
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byType(UiSnackbar));
    final toast = tester.getRect(find.ancestor(of: find.text('Layer deleted'), matching: find.byType(DecoratedBox)).first);
    expect(toast.bottom, lessThanOrEqualTo(bar.top - 8 + 0.5));
    expect(tester.getRect(find.text('Layer deleted')).top, lessThan(before.top));
    snacks.dismiss();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Layer deleted')).top, closeTo(before.top, 0.5));
  });

  testWidgets('glass in a theme island without its own background uses the panel recipe', (tester) async {
    late UiTokens island, painted;
    await pumpUi(
      tester,
      Column(children: [
        UiThemeScope(theme: UiThemeName.dark, paintBackground: false, child: Builder(builder: (c) => Text('a', key: Key('${island = c.ui}')))),
        UiThemeScope(theme: UiThemeName.dark, child: Builder(builder: (c) => Text('b', key: Key('${painted = c.ui}')))),
      ]),
      theme: UiThemeName.light,
    );
    expect(island.glassBg, island.glassPanelBg);
    expect(painted.glassBg, uiThemeTokens[UiThemeName.dark]!.glassBg);
    expect(island.glassPanelBg.a, greaterThanOrEqualTo(0.85));
  });

  testWidgets('a menu opened with the mouse rings no item; a key press brings the ring back', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await pumpUi(
      tester,
      UiMenu(
        items: const [UiMenuItem(label: 'Edit', value: 'edit'), UiMenuItem(label: 'Share', value: 'share')],
        onSelect: (_) {},
        builder: (context, toggle, open) => UiButton(label: 'Actions', onPressed: toggle),
      ),
    );
    bool ringed(String label) {
      final box = tester.widget<AnimatedContainer>(find.ancestor(of: find.text(label), matching: find.byType(AnimatedContainer)).first);
      final border = (box.decoration as BoxDecoration).border as Border?;
      return border != null && border.top.color.a > 0;
    }

    await tester.tap(find.text('Actions'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(ringed('Edit'), isFalse, reason: 'focused, but opened with the mouse');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(ringed('Share'), isTrue);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final theme in [UiThemeName.dark, UiThemeName.light]) {
    testWidgets('golden: focus rings on a ghost button and a calendar day, ${theme.name} (2px gap, then the ring)', (tester) async {
      debugDisableShadows = false;
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(300, 400) * 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(
        theme: theme,
        // On the page colour: the ring is an outline, so whatever is under the control shows inside it.
        home: ColoredBox(
          color: uiThemeTokens[theme]!.bg,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 16, children: [
              UiButton(label: 'Ghost', variant: UiButtonVariant.ghost, onPressed: () {}),
              UiCalendar(value: '2026-10-19', onChanged: (_) {}),
            ]),
          ),
        ),
      ));
      Future<void> tab(int n) async {
        for (var i = 0; i < n; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 400));
      }

      try {
        // First Tab: the ghost button. Five more (prev, month, year, next, days): the chosen day.
        await tab(1);
        await expectLater(find.byType(Column).first, matchesGoldenFile('goldens/focus_ring_ghost_${theme.name}.png'));
        await tab(5);
        await expectLater(find.byType(Column).first, matchesGoldenFile('goldens/focus_ring_day_${theme.name}.png'));
      } finally {
        debugDisableShadows = true;
      }
    });
  }

  test('the neutral progress tone is its own grey, not the muted (blue) text', () {
    for (final name in [UiThemeName.dark, UiThemeName.light]) {
      final t = uiThemeTokens[name]!;
      expect(t.progressNeutral, isNot(t.textMuted));
      expect(t.progressNeutral, isNot(t.primary));
    }
  });
}
