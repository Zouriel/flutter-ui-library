import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'host.dart';


void main() {
  group('UiCheckbox', () {
    testWidgets('tapping the label toggles; null onChanged disables', (tester) async {
      final seen = <bool>[];
      await pumpUi(tester, Column(children: [
        Host<bool>(initial: false, builder: (v, set) => UiCheckbox(value: v, label: 'Terms', onChanged: (n) { seen.add(n); set(n); })),
        const UiCheckbox(value: false, label: 'Off', onChanged: null),
      ]));
      await tester.tap(find.text('Terms'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terms'));
      await tester.tap(find.text('Off'));
      expect(seen, [true, false]);
    });

    testWidgets('Space toggles a focused checkbox', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      var v = false;
      await pumpUi(tester, UiCheckbox(value: v, focusNode: node, label: 'A', onChanged: (n) => v = n));
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(v, isTrue);
    });

    testWidgets('semantics: checked, unchecked and mixed, named by the label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, Column(children: [
        UiCheckbox(value: true, label: 'On', onChanged: (_) {}),
        UiCheckbox(value: false, label: 'Off', onChanged: (_) {}),
        UiCheckbox(value: null, label: 'Some', onChanged: (_) {}),
      ]));
      expect(tester.getSemantics(find.text('On')), isSemantics(label: 'On', hasCheckedState: true, isChecked: true, isFocusable: true, hasTapAction: true));
      expect(tester.getSemantics(find.text('Off')), isSemantics(label: 'Off', hasCheckedState: true, isChecked: false));
      expect(tester.getSemantics(find.text('Some')), isSemantics(label: 'Some', isCheckStateMixed: true));
      handle.dispose();
    });

    testWidgets('a long label wraps beside the box instead of overflowing', (tester) async {
      await pumpUi(tester, SizedBox(width: 200, child: UiCheckbox(value: false, label: 'A very long label that certainly needs to wrap onto more lines', onChanged: (_) {})));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(UiCheckbox)).width, lessThanOrEqualTo(200));
      expect(tester.getSize(find.text('A very long label that certainly needs to wrap onto more lines')).height, greaterThan(30));
    });
  });

  group('UiCheckboxGroup', () {
    const opts = [
      UiCheckboxOption(label: 'Email', value: 'email'),
      UiCheckboxOption(label: 'SMS', value: 'sms'),
      UiCheckboxOption(label: 'Fax', value: 'fax', disabled: true),
    ];

    testWidgets('toggles values in the order chosen', (tester) async {
      List<String>? last;
      await pumpUi(tester, Host<List<String>>(initial: const [], builder: (v, set) => UiCheckboxGroup<String>(
        options: opts, value: v, onChanged: (n) { last = n; set(n); })));
      await tester.tap(find.text('SMS'));
      await tester.pump();
      await tester.tap(find.text('Email'));
      await tester.pump();
      expect(last, ['sms', 'email']);
      await tester.tap(find.text('Fax'));
      expect(last, ['sms', 'email']);
    });

    testWidgets('select all ticks and clears enabled options only, and shows mixed', (tester) async {
      final handle = tester.ensureSemantics();
      List<String>? last;
      await pumpUi(tester, Host<List<String>>(initial: const ['fax'], builder: (v, set) => UiCheckboxGroup<String>(
        options: opts, value: v, selectAll: true, label: 'Channels', onChanged: (n) { last = n; set(n); })));
      await tester.tap(find.text('Email'));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.text('Select all')), isSemantics(isCheckStateMixed: true));
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      expect(last, unorderedEquals(['fax', 'email', 'sms']));
      expect(tester.getSemantics(find.text('Select all')), isSemantics(isChecked: true));
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      expect(last, ['fax'], reason: 'the disabled option keeps its state');
      expect(find.bySemanticsLabel('Channels'), findsOneWidget);
      handle.dispose();
    });
  });

  group('UiRadioGroup', () {
    const opts = [
      UiRadioOption(label: 'Small', value: 's'),
      UiRadioOption(label: 'Medium', value: 'm', disabled: true),
      UiRadioOption(label: 'Large', value: 'l'),
    ];

    testWidgets('tap chooses; arrow keys move the choice skipping disabled and wrapping', (tester) async {
      String? last;
      await pumpUi(tester, Host<String?>(initial: 's', builder: (v, set) => UiRadioGroup<String>(
        options: opts, value: v, label: 'Size', onChanged: (n) { last = n; set(n); })));
      await tester.tap(find.text('Large'));
      await tester.pump();
      expect(last, 'l');
      // Tab lands on the chosen option (the group is one tab stop).
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(last, 's', reason: 'wraps past the end');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(last, 'l', reason: 'skips the disabled option');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(last, 's');
    });

    testWidgets('only the chosen option is in the tab order', (tester) async {
      await pumpUi(tester, Column(children: [
        UiRadioGroup<String>(options: opts, value: 'l', onChanged: (_) {}),
        UiButton(label: 'After', onPressed: () {}),
      ]));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'roving 2');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, isNot(startsWith('roving')));
    });

    testWidgets('semantics: a named radio group of exclusive, checked options', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, UiRadioGroup<String>(options: opts, value: 'l', label: 'Size', onChanged: (_) {}));
      expect(find.bySemanticsLabel('Size'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Size')).getSemanticsData().role, SemanticsRole.radioGroup);
      expect(tester.getSemantics(find.text('Large')), isSemantics(isInMutuallyExclusiveGroup: true, isChecked: true));
      expect(tester.getSemantics(find.text('Small')), isSemantics(isInMutuallyExclusiveGroup: true, isChecked: false));
      expect(tester.getSemantics(find.text('Medium')), isSemantics(isEnabled: false));
      handle.dispose();
    });
  });

  group('UiSwitch', () {
    testWidgets('toggles and is announced as toggled', (tester) async {
      final handle = tester.ensureSemantics();
      bool? last;
      await pumpUi(tester, Host<bool>(initial: false, builder: (v, set) => UiSwitch(value: v, label: 'Wi-Fi', onChanged: (n) { last = n; set(n); })));
      await tester.tap(find.text('Wi-Fi'));
      await tester.pumpAndSettle();
      expect(last, isTrue);
      expect(tester.getSemantics(find.text('Wi-Fi')), isSemantics(hasToggledState: true, isToggled: true, label: 'Wi-Fi'));
      handle.dispose();
    });

    testWidgets('the thumb sits at the end when on', (tester) async {
      await pumpUi(tester, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        UiSwitch(key: const Key('off'), value: false, onChanged: (_) {}, semanticLabel: 'a'),
        UiSwitch(key: const Key('on'), value: true, onChanged: (_) {}, semanticLabel: 'b'),
      ]));
      final off = tester.getRect(find.descendant(of: find.byKey(const Key('off')), matching: find.byType(AnimatedContainer)).last);
      final on = tester.getRect(find.descendant(of: find.byKey(const Key('on')), matching: find.byType(AnimatedContainer)).last);
      expect(on.left - off.left, 16, reason: 'the thumb travels 16px like the web');
    });
  });

  group('UiSlider', () {
    testWidgets('keys step, page and jump to the ends; values snap to step', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      double? last;
      await pumpUi(tester, SizedBox(width: 300, child: Host<double>(initial: 50, builder: (v, set) => UiSlider(
        value: v, step: 5, focusNode: node, onChanged: (n) { last = n; set(n); }))));
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(last, 55);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(last, 45);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(last, 100);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(last, 0);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('tap and drag on the track set the value', (tester) async {
      double? last;
      await pumpUi(tester, SizedBox(width: 316, child: Host<double>(initial: 0, builder: (v, set) => UiSlider(
        value: v, showValue: false, onChanged: (n) { last = n; set(n); }))));
      final r = tester.getRect(find.byType(UiSlider));
      // Thumb travel is 8px..308px: 300px for 0..100.
      await tester.tapAt(Offset(r.left + 8 + 150, r.center.dy));
      expect(last, 50);
      await tester.dragFrom(Offset(r.left + 8 + 150, r.center.dy), const Offset(60, 0));
      await tester.pump();
      expect(last, 70);
    });

    testWidgets('semantics: slider with value and increase/decrease actions; disabled ignores input', (tester) async {
      final handle = tester.ensureSemantics();
      var v = 10.0;
      await pumpUi(tester, SizedBox(width: 300, child: UiSlider(value: v, label: 'Volume', onChanged: (n) => v = n)));
      final node = tester.getSemantics(find.bySemanticsLabel('Volume'));
      expect(node, isSemantics(isSlider: true, value: '10', increasedValue: '11', decreasedValue: '9', hasIncreaseAction: true, hasDecreaseAction: true));
      tester.semantics.performAction(find.semantics.byLabel('Volume'), SemanticsAction.increase);
      expect(v, 11);
      handle.dispose();

      var changed = false;
      await pumpUi(tester, SizedBox(width: 300, child: UiSlider(value: 10, onChanged: null, key: const Key('d'))));
      await tester.tap(find.byKey(const Key('d')));
      expect(changed, isFalse);
    });
  });

  group('UiRating', () {
    testWidgets('tap sets, tapping the current star clears; arrows and Home/End move', (tester) async {
      final handle = tester.ensureSemantics();
      int? last;
      await pumpUi(tester, Host<int>(initial: 0, builder: (v, set) => UiRating(value: v, onChanged: (n) { last = n; set(n); })));
      await tester.tap(find.bySemanticsLabel('3 of 5'));
      await tester.pump();
      expect(last, 3);
      await tester.tap(find.bySemanticsLabel('3 of 5'));
      await tester.pump();
      expect(last, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(last, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(last, 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(last, 5);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(last, 1);
      expect(tester.getSemantics(find.bySemanticsLabel('1 of 5')), isSemantics(isChecked: true, isInMutuallyExclusiveGroup: true, isFocused: true));
      handle.dispose();
    });

    testWidgets('one tab stop: Tab leaves the stars after one press', (tester) async {
      await pumpUi(tester, Column(children: [
        UiRating(value: 4, onChanged: (_) {}),
        UiButton(label: 'After', onPressed: () {}),
      ]));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'roving 3');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, isNot(startsWith('roving')));
    });
  });

  testWidgets('meets the Android tap-target, labelled-target and contrast guidelines', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final handle = tester.ensureSemantics();
    await pumpUi(tester, Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        UiCheckbox(value: true, label: 'Checkbox', onChanged: (_) {}),
        UiCheckboxGroup<String>(options: const [UiCheckboxOption(label: 'One', value: '1'), UiCheckboxOption(label: 'Two', value: '2')], value: const ['1'], selectAll: true, onChanged: (_) {}),
        UiRadioGroup<String>(options: const [UiRadioOption(label: 'Red', value: 'r'), UiRadioOption(label: 'Blue', value: 'b')], value: 'r', direction: Axis.horizontal, onChanged: (_) {}),
        UiSwitch(value: true, label: 'Switch', onChanged: (_) {}),
        SizedBox(width: 300, child: UiSlider(value: 30, onChanged: (_) {})),
        UiRating(value: 3, onChanged: (_) {}),
      ]),
    ));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('golden: checkbox, radio, switch, slider, rating', (tester) async {
    await expectThemedGolden(tester, 'toggles', height: 560, (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 16, children: [
          UiCheckbox(value: true, label: 'Checked', onChanged: (_) {}),
          UiCheckbox(value: false, label: 'Empty', onChanged: (_) {}),
          UiCheckbox(value: null, label: 'Mixed', onChanged: (_) {}),
          UiCheckbox(value: false, label: 'Invalid', invalid: true, onChanged: (_) {}),
          const UiCheckbox(value: true, label: 'Disabled', onChanged: null),
        ]),
        UiCheckboxGroup<String>(
          options: const [UiCheckboxOption(label: 'Email', value: 'e'), UiCheckboxOption(label: 'SMS', value: 's'), UiCheckboxOption(label: 'Fax', value: 'f', disabled: true)],
          value: const ['e'], selectAll: true, direction: Axis.horizontal, onChanged: (_) {}),
        UiRadioGroup<String>(
          options: const [UiRadioOption(label: 'Small', value: 's'), UiRadioOption(label: 'Medium', value: 'm'), UiRadioOption(label: 'Large', value: 'l', disabled: true)],
          value: 'm', direction: Axis.horizontal, onChanged: (_) {}),
        Wrap(spacing: 16, children: [
          UiSwitch(value: true, label: 'On', onChanged: (_) {}),
          UiSwitch(value: false, label: 'Off', onChanged: (_) {}),
          const UiSwitch(value: true, label: 'Disabled', onChanged: null),
        ]),
        UiSlider(value: 35, onChanged: (_) {}),
        UiSlider(value: 0.4, max: 1, step: 0.1, onChanged: null),
        UiRating(value: 3, onChanged: (_) {}),
      ],
    ));
  });
}
