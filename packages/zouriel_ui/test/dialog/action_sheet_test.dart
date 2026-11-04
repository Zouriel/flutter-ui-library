import 'dart:ui' show GestureSettings;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../overlay/screens.dart';

/// 0.61.0, from the owner on invites.blog's guest list: "when i press the three dots its opens a very
/// slacked off full screen model". A compact action sheet (handle, content height, danger last) and
/// the drawer options it is built from (handle, fit: content).

const _actions = [
  UiActionSheetAction(label: 'Remove', value: 'remove', icon: HugeIcons.strokeRoundedDelete02, danger: true),
  UiActionSheetAction(label: 'Edit', value: 'edit', icon: HugeIcons.strokeRoundedEdit02),
  UiActionSheetAction(label: 'Resend', value: 'resend', icon: HugeIcons.strokeRoundedSent),
];

/// Opens an action sheet from a page button; [result] gets what it completed with.
Future<List<Object?>> _sheet(
  WidgetTester tester, {
  List<UiActionSheetAction<String>> actions = _actions,
  String? message,
  String? cancelLabel,
  EdgeInsets safe = EdgeInsets.zero,
  Size size = const Size(390, 844),
}) async {
  final dpr = tester.view.devicePixelRatio;
  tester.view.physicalSize = size * dpr;
  tester.view.padding = FakeViewPadding(bottom: safe.bottom * dpr, top: safe.top * dpr);
  tester.view.gestureSettings = GestureSettings(physicalTouchSlop: 8 * dpr);
  addTearDown(tester.view.reset);
  final results = <Object?>[];
  await tester.pumpWidget(UiApp(
    theme: UiThemeName.light,
    home: Builder(
      builder: (context) => Center(
        child: UiButton(
          label: 'Open',
          onPressed: () async => results.add(await showUiActionSheet<String>(context: context, title: 'Aminath Hassan', message: message, actions: actions, cancelLabel: cancelLabel)),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return results;
}

Rect _panel(WidgetTester tester) => tester.getRect(find.byType(UiDialogScope));

Color? _color(WidgetTester tester, String label) =>
    tester.widget<DefaultTextStyle>(find.ancestor(of: find.text(label), matching: find.byType(DefaultTextStyle)).first).style.color;

void main() {
  testWidgets('tapping an action closes the sheet with its value', (tester) async {
    final results = await _sheet(tester);
    await tester.tap(find.text('Resend'));
    await tester.pumpAndSettle();
    expect(results, ['resend']);
    expect(find.byType(UiActionSheet<String>), findsNothing);
  });

  testWidgets('backdrop, Escape, back, swipe down and Cancel close it with null', (tester) async {
    var results = await _sheet(tester);
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    expect(results, [null], reason: 'backdrop');

    results = await _sheet(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(results, [null], reason: 'Escape');

    results = await _sheet(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(results, [null], reason: 'back');

    results = await _sheet(tester);
    final handle = tester.getCenter(find.byKey(UiDrawer.handleKey));
    await tester.flingFrom(handle, const Offset(0, 300), 1500);
    await tester.pumpAndSettle();
    expect(results, [null], reason: 'swipe down from the handle');

    results = await _sheet(tester, cancelLabel: '');
    expect(find.text('Cancel'), findsOneWidget, reason: "'' takes the built-in label");
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(results, [null], reason: 'Cancel');
  });

  testWidgets('danger rows come after the others and are drawn in the danger colour, icon too', (tester) async {
    await _sheet(tester);
    final t = tester.element(find.byType(UiActionSheet<String>)).ui;
    final ys = {for (final l in ['Remove', 'Edit', 'Resend']) l: tester.getCenter(find.text(l)).dy};
    expect(ys['Edit']!, lessThan(ys['Resend']!), reason: 'non-danger rows keep their order');
    expect(ys['Resend']!, lessThan(ys['Remove']!), reason: 'the danger row moved to the end');
    expect(_color(tester, 'Remove'), t.danger);
    expect(_color(tester, 'Edit'), t.text);
    final removeIcon = find.descendant(of: find.ancestor(of: find.text('Remove'), matching: find.byType(Row)).first, matching: find.byType(UiIcon));
    final iconColor = IconTheme.of(tester.element(removeIcon)).color;
    expect(iconColor, t.danger);
    expect(tester.getSize(removeIcon).width, 20);
  });

  testWidgets('rows are full width and at least 48 tall; icon and label space3 apart', (tester) async {
    await _sheet(tester);
    final t = tester.element(find.byType(UiActionSheet<String>)).ui;
    final row = find.ancestor(of: find.text('Edit'), matching: find.byType(AnimatedContainer)).first;
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(row).width, _panel(tester).width, reason: 'edge to edge');
    final icon = find.descendant(of: row, matching: find.byType(UiIcon));
    expect(tester.getTopLeft(find.text('Edit')).dx - tester.getTopRight(icon).dx, closeTo(t.space3, 0.5));
  });

  testWidgets('the sheet is as tall as its content, with a handle', (tester) async {
    await _sheet(tester, actions: _actions.sublist(1));
    expect(find.byKey(UiDrawer.handleKey), findsOneWidget);
    final h = _panel(tester).height;
    expect(h, lessThan(320), reason: 'two actions take less than the fixed drawer height');
    // Title, two 48px rows: the rows end near the panel's bottom (body padding only).
    final lastRow = find.ancestor(of: find.text('Resend'), matching: find.byType(AnimatedContainer)).first;
    expect(_panel(tester).bottom - tester.getRect(lastRow).bottom, closeTo(tester.element(find.byType(UiActionSheet<String>)).ui.space2, 1.5));
    final handle = tester.getRect(find.byKey(UiDrawer.handleKey));
    expect(handle.size, const Size(36, 4));
    expect(handle.center.dx, closeTo(_panel(tester).center.dx, 0.5));
    expect(handle.top - _panel(tester).top, closeTo(8, 0.5), reason: '8px from the top');
  });

  testWidgets('many actions: capped at 90% of the room and the rows scroll', (tester) async {
    await _sheet(tester, actions: [for (var i = 0; i < 30; i++) UiActionSheetAction(label: 'Action $i', value: '$i')]);
    expect(_panel(tester).height, closeTo(844 * 0.9, 0.5));
    expect(_panel(tester).bottom, 844);
    await tester.scrollUntilVisible(find.text('Action 29'), 200, scrollable: find.byType(Scrollable).last);
    expect(tester.getRect(find.text('Action 29')).bottom, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps clear of the gesture bar', (tester) async {
    await _sheet(tester, safe: const EdgeInsets.only(top: 40, bottom: 34));
    expect(_panel(tester).bottom, 844, reason: 'the surface reaches the screen edge');
    final lastRow = find.ancestor(of: find.text('Remove'), matching: find.byType(AnimatedContainer)).first;
    expect(tester.getRect(lastRow).bottom, lessThanOrEqualTo(844 - 34));
  });

  testWidgets('focus starts on the first action; arrows move between rows, skipping disabled ones', (tester) async {
    await _sheet(tester, actions: const [
      UiActionSheetAction(label: 'Edit', value: 'edit'),
      UiActionSheetAction(label: 'Resend', value: 'resend', disabled: true),
      UiActionSheetAction(label: 'Remove', value: 'remove', danger: true),
    ]);
    await tester.pump();
    String? focused() => FocusManager.instance.primaryFocus?.debugLabel;
    expect(focused(), 'UiActionSheet row 0');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(), 'UiActionSheet row 2', reason: 'Resend is disabled');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(), 'UiActionSheet row 0', reason: 'wraps');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(focused(), 'UiActionSheet row 2');
  });

  testWidgets('semantics: named by the title, rows are buttons, the handle is hidden', (tester) async {
    final handle = tester.ensureSemantics();
    await _sheet(tester, message: 'Invited by you');
    expect(find.text('Invited by you'), findsOneWidget);
    expect(tester.getSemantics(find.text('Edit')), isSemantics(label: 'Edit', isButton: true));
    expect(find.bySemanticsLabel('Aminath Hassan'), findsWidgets);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  group('UiDrawer handle and fit', () {
    Future<void> drawer(WidgetTester tester, {bool handle = false, UiDrawerFit fit = UiDrawerFit.fixed}) async {
      tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(
        home: Builder(
          builder: (context) => Center(
            child: UiButton(
              label: 'Open',
              onPressed: () => showUiDrawer<void>(
                context: context,
                side: UiDrawerSide.bottom,
                title: 'Edit guest',
                handle: handle,
                fit: fit,
                builder: (_) => const UiFormField(label: 'Name', child: UiInput(value: '', semanticLabel: 'Name')),
                footerBuilder: (_) => UiButton(label: 'Save', onPressed: () {}),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('no handle unless asked; fixed height by default', (tester) async {
      await drawer(tester);
      expect(find.byKey(UiDrawer.handleKey), findsNothing);
      expect(_panel(tester).height, 320);
    });

    testWidgets('fit content: the footer ends at the bottom and the height hugs the form', (tester) async {
      await drawer(tester, handle: true, fit: UiDrawerFit.content);
      expect(find.byKey(UiDrawer.handleKey), findsOneWidget);
      final p = _panel(tester);
      expect(p.height, lessThan(320));
      expect(p.bottom, 844);
      // Title bar, then the body and footer with nothing stretched between them.
      final field = tester.getRect(find.byType(UiFormField));
      final save = tester.getRect(find.text('Save'));
      expect(save.top - field.bottom, lessThan(60));
    });
  });

  testWidgets('golden: action sheet', (tester) async {
    debugDisableShadows = false;
    await pumpScreens(tester, (context) => Center(
          child: UiButton(
            label: 'Open',
            onPressed: () => showUiActionSheet<String>(context: context, useRootNavigator: false, title: 'Aminath Hassan', message: 'Invited 3 Nov', actions: _actions, cancelLabel: ''),
          ),
        ), padding: const EdgeInsets.only(top: 24, bottom: 16));
    await tester.tap(find.text('Open').at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open').at(1));
    await tester.pumpAndSettle();
    await expectScreensGolden(tester, 'action_sheet');
    debugDisableShadows = true;
  });
}
