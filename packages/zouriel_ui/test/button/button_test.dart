import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

void main() {
  testWidgets('tapping calls onPressed; null onPressed disables it', (tester) async {
    var taps = 0;
    await pumpUi(tester, Column(children: [
      UiButton(label: 'Save', onPressed: () => taps++),
      const UiButton(label: 'Off', onPressed: null),
    ]));
    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Off'));
    expect(taps, 1);
  });

  testWidgets('Enter and Space activate a focused button', (tester) async {
    var taps = 0;
    final node = FocusNode();
    addTearDown(node.dispose);
    await pumpUi(tester, UiButton(label: 'Go', focusNode: node, onPressed: () => taps++));
    node.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, 2);
  });

  testWidgets('loading shows a spinner, ignores taps and is announced as busy', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(UiApp(home: Center(child: UiButton(label: 'Pay', loading: true, onPressed: () => taps++))));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(UiSpinner), findsOneWidget);
    await tester.tap(find.text('Pay'));
    expect(taps, 0);
    expect(find.bySemanticsLabel(RegExp('busy')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('keyboard focus shows the focus ring; a tap does not', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await pumpUi(tester, UiButton(label: 'Ring', focusNode: node, onPressed: () {}));
    BoxDecoration deco() => tester.widget<AnimatedContainer>(find.descendant(of: find.byType(UiButton), matching: find.byType(AnimatedContainer))).decoration! as BoxDecoration;
    expect(deco().boxShadow, isEmpty);
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    node.requestFocus();
    await tester.pumpAndSettle();
    expect(deco().boxShadow, uiThemeTokens[UiThemeName.dark]!.focusRing);
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  testWidgets('icon buttons are named by their label', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedDelete02), label: 'Delete', onPressed: () {}));
    expect(find.bySemanticsLabel('Delete'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('meets the Android tap-target, labelled-target and contrast guidelines', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final handle = tester.ensureSemantics();
    await pumpUi(tester, Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final v in UiButtonVariant.values) UiButton(label: v.name, variant: v, onPressed: () {}),
        UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedAdd01), label: 'Add', onPressed: () {}),
      ]),
    ));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('golden: variants, sizes and states', (tester) async {
    await expectThemedGolden(tester, 'button_variants', height: 440, (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in UiButtonVariant.values) UiButton(label: v.name[0].toUpperCase() + v.name.substring(1), variant: v, onPressed: () {}),
        ]),
        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          UiButton(label: 'Small', size: UiSize.sm, onPressed: () {}),
          UiButton(label: 'Medium', onPressed: () {}),
          UiButton(label: 'Large', size: UiSize.lg, onPressed: () {}),
        ]),
        Wrap(spacing: 8, children: [
          UiButton(label: 'With icon', icon: const UiIcon(HugeIcons.strokeRoundedAdd01), variant: UiButtonVariant.outline, onPressed: () {}),
          const UiButton(label: 'Disabled', onPressed: null),
          UiButton(label: 'Loading', loading: true, onPressed: () {}),
        ]),
        Wrap(spacing: 8, children: [
          for (final v in [UiButtonVariant.primary, UiButtonVariant.outline, UiButtonVariant.ghost, UiButtonVariant.destructive])
            UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedSettings01), label: 'Settings', variant: v, onPressed: () {}),
        ]),
        UiButton(label: 'Full width', block: true, onPressed: () {}),
      ],
    ));
  });
}
