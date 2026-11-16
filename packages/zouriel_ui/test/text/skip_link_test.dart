import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

// 0.87.0: UiSkipLink, "Skip to content".

/// A page: the skip link, a navigation button, then the main content (a focusable box far down).
Widget _page(FocusNode main, {String? label, List<String>? log}) => SizedBox(
      width: 390,
      height: 600,
      child: Column(children: [
        UiSkipLink(target: main, label: label),
        UiButton(label: 'Menu', onPressed: () => log?.add('menu')),
        Expanded(
          child: SingleChildScrollView(
            child: Column(children: [
              const SizedBox(height: 1500),
              Focus(focusNode: main, child: const Text('Main content')),
            ]),
          ),
        ),
      ]),
    );

Finder get _pill => find.text('Skip to content');

void main() {
  testWidgets('takes no room and shows nothing until it has focus', (tester) async {
    final main = FocusNode();
    addTearDown(main.dispose);
    await pumpUi(tester, _page(main));
    expect(tester.getSize(find.byType(UiSkipLink)), Size.zero);
    expect(_pill, findsNothing);
    expect(tester.getTopLeft(find.text('Menu')).dy, lessThan(48), reason: 'the menu button is at the top of the page');
  });

  testWidgets('the first Tab focuses it and shows the pill at the top-start corner; Tab on hides it', (tester) async {
    final main = FocusNode();
    addTearDown(main.dispose);
    await pumpUi(tester, _page(main));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(_pill, findsOneWidget);
    final t = tester.element(_pill).ui;
    final pill = tester.getRect(find.ancestor(of: _pill, matching: find.byType(Container)).first);
    expect(pill.topLeft, Offset(t.space2, t.space2));
    expect(tester.getSize(find.byType(UiSkipLink)), Size.zero, reason: 'shown in the overlay, the page does not move');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(_pill, findsNothing);
  });

  testWidgets('right to left: the pill sits at the top right', (tester) async {
    final main = FocusNode();
    addTearDown(main.dispose);
    await pumpUi(tester, Directionality(textDirection: TextDirection.rtl, child: _page(main)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final t = tester.element(_pill).ui;
    final pill = tester.getRect(find.ancestor(of: _pill, matching: find.byType(Container)).first);
    expect(pill.right, tester.view.physicalSize.width / tester.view.devicePixelRatio - t.space2);
  });

  testWidgets('Enter moves focus to the target and scrolls it into view', (tester) async {
    final main = FocusNode();
    addTearDown(main.dispose);
    final log = <String>[];
    await pumpUi(tester, _page(main, log: log));
    expect(tester.getTopLeft(find.text('Main content')).dy, greaterThan(844));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(main.hasPrimaryFocus, isTrue);
    expect(tester.getTopLeft(find.text('Main content')).dy, lessThan(600), reason: 'scrolled into view');
    expect(_pill, findsNothing);
    expect(log, isEmpty);
  });

  testWidgets('a tap on the shown pill skips too', (tester) async {
    final main = FocusNode();
    addTearDown(main.dispose);
    await pumpUi(tester, _page(main));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.tap(_pill);
    await tester.pumpAndSettle();
    expect(main.hasPrimaryFocus, isTrue);
  });

  testWidgets('label: the strings by default (English, Dhivehi), or its own', (tester) async {
    final main = FocusNode();
    addTearDown(main.dispose);
    for (final (strings, text) in [(const UiStrings(), 'Skip to content'), (UiStrings.dv, 'ކޮންޓެންޓަށް ދާން')]) {
      await tester.pumpWidget(UiApp(key: UniqueKey(), textDirection: TextDirection.ltr, config: UiConfig(strings: strings), home: Align(alignment: Alignment.topLeft, child: _page(main))));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text(text), findsOneWidget);
    }
    await pumpUi(tester, _page(main, label: 'Go to the form'));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text('Go to the form'), findsOneWidget);
  });

  testWidgets('semantics: a focusable link named by its words, that activates', (tester) async {
    final handle = tester.ensureSemantics();
    final main = FocusNode();
    addTearDown(main.dispose);
    await pumpUi(tester, _page(main));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final data = tester.getSemantics(find.byType(UiSkipLink)).getSemanticsData();
    expect(data.label, 'Skip to content');
    expect(data.flagsCollection.isLink, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.flagsCollection.isFocused, isNot(Tristate.none), reason: 'focusable');
    handle.dispose();
  });

  for (final theme in [UiThemeName.dark, UiThemeName.light]) {
    testWidgets('golden: the shown pill, ${theme.name}', (tester) async {
      final main = FocusNode();
      addTearDown(main.dispose);
      debugDisableShadows = false;
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(390, 120) * 2;
      addTearDown(tester.view.reset);
      try {
        await tester.pumpWidget(UiApp(theme: theme, home: _page(main)));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await expectLater(find.byType(Overlay).first, matchesGoldenFile('goldens/skip_link_${theme.name}.png'));
      } finally {
        debugDisableShadows = true;
      }
    });
  }
}
