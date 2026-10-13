import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../overlay/screens.dart';

const _commands = [
  UiCommand(label: 'New file', value: 'new', group: 'File', icon: UiIcon(HugeIcons.strokeRoundedFileAdd), shortcut: 'Ctrl+N'),
  UiCommand(label: 'Open recent', value: 'recent', group: 'File', icon: UiIcon(HugeIcons.strokeRoundedClock01)),
  UiCommand(label: 'Toggle theme', value: 'theme', group: 'View', keywords: 'dark light mode', icon: UiIcon(HugeIcons.strokeRoundedMoon02)),
  UiCommand(label: 'Settings', value: 'settings', icon: Text('S'), shortcut: 'Ctrl+,'),
];

class _Opened {
  UiCommand? result;
  bool done = false;
  final runs = <String>[];
}

Future<_Opened> _open(WidgetTester tester, {Size size = const Size(390, 844), FocusNode? pageNode, List<UiCommand> commands = _commands}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final o = _Opened();
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(UiApp(
    home: Builder(builder: (context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          UiButton(label: 'Page', focusNode: pageNode, onPressed: () {}),
          UiButton(
            label: 'Search',
            onPressed: () async {
              o.result = await showUiCommandPalette(context: context, commands: commands, onRun: (c) => o.runs.add(c.value));
              o.done = true;
            },
          ),
        ]))),
  ));
  await tester.tap(find.text('Search'));
  await tester.pumpAndSettle();
  return o;
}

Rect _row(WidgetTester tester, String label) => tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(AnimatedContainer)).first);

bool _isActive(WidgetTester tester, String label) =>
    tester.widget<UiInteractive>(find.ancestor(of: find.text(label), matching: find.byType(UiInteractive)).first).selected ?? false;

void main() {
  testWidgets('typing filters over label, group and keywords, case-insensitively', (tester) async {
    await _open(tester);
    expect(find.text('New file'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'FILE');
    await tester.pump();
    expect(find.text('New file'), findsOneWidget);
    expect(find.text('Open recent'), findsOneWidget, reason: 'matches its group');
    expect(find.text('Settings'), findsNothing);
    await tester.enterText(find.byType(EditableText), 'dark');
    await tester.pump();
    expect(find.text('Toggle theme'), findsOneWidget, reason: 'matches a keyword');
    expect(find.text('New file'), findsNothing);
    await tester.enterText(find.byType(EditableText), 'zzz');
    await tester.pump();
    expect(find.text('No results'), findsOneWidget);
  });

  testWidgets('arrows move the highlight while the field keeps focus; Enter runs it and closes', (tester) async {
    final o = await _open(tester);
    final field = tester.widget<EditableText>(find.byType(EditableText)).focusNode;
    expect(field.hasPrimaryFocus, isTrue, reason: 'the field takes focus, so the keyboard comes up');
    expect(_isActive(tester, 'New file'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_isActive(tester, 'Toggle theme'), isTrue);
    expect(field.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(_isActive(tester, 'Open recent'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(o.done, isTrue);
    expect(o.result?.value, 'recent');
    expect(o.runs, ['recent']);
    expect(find.byType(UiCommandPalette), findsNothing);
  });

  testWidgets('the arrows stop at the ends; typing resets the highlight to the first match', (tester) async {
    await _open(tester);
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.pump();
    expect(_isActive(tester, 'Settings'), isTrue);
    await tester.enterText(find.byType(EditableText), 'e');
    await tester.pump();
    expect(_isActive(tester, 'New file'), isTrue);
  });

  testWidgets('the keyboard search key runs the highlighted command', (tester) async {
    final o = await _open(tester);
    await tester.enterText(find.byType(EditableText), 'sett');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(o.result?.value, 'settings');
  });

  testWidgets('a tap runs a command', (tester) async {
    final o = await _open(tester);
    await tester.tap(find.text('Toggle theme'));
    await tester.pumpAndSettle();
    expect(o.result?.value, 'theme');
  });

  testWidgets('Escape, the back button and the back arrow close it with null; focus returns', (tester) async {
    final page = FocusNode();
    addTearDown(page.dispose);
    var o = await _open(tester, pageNode: page);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(o.done, isTrue);
    expect(o.result, isNull);

    o = await _open(tester, pageNode: page);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(o.done, isTrue);

    page.requestFocus();
    await tester.pump();
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(page.hasFocus, isFalse);
    await tester.tap(find.byType(UiIconButton));
    await tester.pumpAndSettle();
    expect(find.byType(UiCommandPalette), findsNothing);
    expect(page.hasPrimaryFocus, isTrue);
  });

  testWidgets('on a phone it fills the screen; on a tablet it is a 560px dialog near the top', (tester) async {
    await _open(tester);
    expect(tester.getRect(find.byType(UiDialogScope)), const Rect.fromLTWH(0, 0, 390, 844));
    expect(_row(tester, 'New file').height, 48);
    await _open(tester, size: const Size(1024, 768));
    final r = tester.getRect(find.byType(UiDialogScope));
    expect(r.width, 560);
    expect(r.top, closeTo(768 * 0.12, 0.5));
    expect(r.center.dx, 512);
    await tester.tapAt(const Offset(20, 700));
    await tester.pumpAndSettle();
    expect(find.byType(UiCommandPalette), findsNothing, reason: 'a backdrop tap closes it');
  });

  testWidgets('keeps the highlighted row in view in a long list', (tester) async {
    await _open(tester, size: const Size(1024, 768), commands: [for (var i = 0; i < 30; i++) UiCommand(label: 'Command $i', value: '$i')]);
    for (var i = 0; i < 15; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.pump();
    expect(_isActive(tester, 'Command 15'), isTrue);
    expect(find.text('Command 15').hitTestable(), findsOneWidget);
  });

  testWidgets('is a dialog named "Command palette"; meets the guidelines', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final handle = tester.ensureSemantics();
    await _open(tester);
    expect(find.semantics.byLabel('Command palette'), findsOne);
    expect(find.semantics.byLabel('Page'), findsNothing);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('golden: full-screen search on a phone', (tester) async {
    await pumpScreens(tester, (context) => Center(child: UiButton(label: 'Search', onPressed: () => showUiCommandPalette(context: context, commands: _commands, useRootNavigator: false))), padding: const EdgeInsets.only(top: 24));
    await tester.tap(find.text('Search').at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search').at(1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).at(1), 'file');
    await tester.pumpAndSettle();
    await expectScreensGolden(tester, 'palette_phone');
  });

  testWidgets('golden: dialog on a tablet', (tester) async {
    debugDisableShadows = false;
    await pumpScreens(
      tester,
      (context) => Center(child: UiButton(label: 'Search', onPressed: () => showUiCommandPalette(context: context, commands: _commands, useRootNavigator: false))),
      screen: const Size(640, 480),
    );
    await tester.tap(find.text('Search').at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search').at(1));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await expectScreensGolden(tester, 'palette_tablet');
    debugDisableShadows = true;
  });
}
