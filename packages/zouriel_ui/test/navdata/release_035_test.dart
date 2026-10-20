import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

void main() {
  testWidgets('xl: a 56px button and icon button; other sizes unchanged', (tester) async {
    await pumpUi(tester, Column(mainAxisSize: MainAxisSize.min, children: [
      UiButton(key: const Key('xl'), label: 'Start visit', size: UiSize.xl, onPressed: () {}),
      UiIconButton(key: const Key('ixl'), label: 'Call', size: UiSize.xl, onPressed: () {}, icon: const SizedBox()),
      UiButton(key: const Key('md'), label: 'Save', onPressed: () {}),
    ]));
    double visual(Key k) => tester.getSize(find.descendant(of: find.byKey(k), matching: find.byType(AnimatedContainer)).first).height;
    expect(visual(const Key('xl')), 56);
    expect(visual(const Key('ixl')), 56);
    expect(visual(const Key('md')), 30);
    expect(UiSize.xl.height(uiThemeTokens[UiThemeName.dark]!), 56);
  });

  testWidgets('avatar: xl and any dimension, initials scaled', (tester) async {
    await pumpUi(tester, const Row(mainAxisSize: MainAxisSize.min, children: [
      UiAvatar(key: Key('xl'), name: 'Aminath Hassan', size: UiSize.xl),
      UiAvatar(key: Key('d'), name: 'Aminath Hassan', dimension: 96),
    ]));
    expect(tester.getSize(find.byKey(const Key('xl'))), const Size(56, 56));
    expect(tester.getSize(find.byKey(const Key('d'))), const Size(96, 96));
    final p = tester.renderObject<RenderParagraph>(find.descendant(of: find.byKey(const Key('d')), matching: find.text('AH')));
    expect(p.text.style!.fontSize, 36);
  });

  testWidgets('progress circle: a child in the middle instead of the percentage', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const UiProgressCircle(value: 40, size: 96, label: 'Seconds left', showValue: true, child: Text('12')));
    expect(find.text('12'), findsOneWidget);
    expect(find.text('40%'), findsNothing);
    expect(tester.getSemantics(find.byType(UiProgressCircle)).getSemanticsData().value, '40%');
    handle.dispose();
  });

  testWidgets('chat bubble: yours at the end in primary, theirs at the start; mirrored in RTL; meta below', (tester) async {
    Widget chat() => const SizedBox(
          width: 360,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            UiChatBubble(key: Key('them'), meta: '09:40', child: Text('On my way')),
            UiChatBubble(key: Key('me'), mine: true, meta: '09:41 · Read', child: Text('Thanks')),
          ]),
        );
    await pumpUi(tester, chat());
    Rect box(Key k) => tester.getRect(find.descendant(of: find.byKey(k), matching: find.byType(Container)).first);
    expect(box(const Key('me')).right, closeTo(360, 0.5));
    expect(box(const Key('them')).left, closeTo(0, 0.5));
    final t = uiThemeTokens[UiThemeName.dark]!;
    final deco = tester.widget<Container>(find.descendant(of: find.byKey(const Key('me')), matching: find.byType(Container)).first).decoration as BoxDecoration;
    expect(deco.color, t.primary);
    expect(find.text('09:41 · Read'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pumpUi(tester, Directionality(textDirection: TextDirection.rtl, child: chat()));
    expect(box(const Key('me')).left, closeTo(0, 0.5));
  });

  group('hold button', () {
    Future<List<String>> pump(WidgetTester tester) async {
      final log = <String>[];
      await pumpUi(tester, Center(child: UiHoldButton(label: "I've arrived", hold: const Duration(seconds: 1), onConfirmed: () => log.add('ok'))));
      return log;
    }

    testWidgets('confirms when held to the end, with no dialog', (tester) async {
      final log = await pump(tester);
      final g = await tester.startGesture(tester.getCenter(find.byType(UiHoldButton)));
      await tester.pump(); // the fill's first frame
      await tester.pump(const Duration(milliseconds: 500));
      expect(log, isEmpty);
      await tester.pump(const Duration(milliseconds: 600));
      expect(log, ['ok']);
      await g.up();
      await tester.pumpAndSettle();
      expect(log, ['ok']);
      expect(find.text('Are you sure?'), findsNothing);
    });

    testWidgets('let go early: cancelled, nothing opens', (tester) async {
      final log = await pump(tester);
      final g = await tester.startGesture(tester.getCenter(find.byType(UiHoldButton)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await g.up();
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      expect(find.text('Are you sure?'), findsNothing);
    });

    testWidgets('a tap opens the confirm dialog, which confirms', (tester) async {
      final log = await pump(tester);
      await tester.tap(find.byType(UiHoldButton));
      await tester.pumpAndSettle();
      expect(find.text('Are you sure?'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(log, ['ok']);
    });

    testWidgets('a screen reader double-tap opens the dialog; the hint is read', (tester) async {
      final handle = tester.ensureSemantics();
      final log = await pump(tester);
      final node = tester.getSemantics(find.byType(UiButton));
      expect(node.getSemanticsData().hint, contains('Press and hold to confirm'));
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.text('Are you sure?'), findsOneWidget);
      expect(log, isEmpty);
      handle.dispose();
    });

    testWidgets('keyboard: Space held confirms; a quick Enter opens the dialog', (tester) async {
      final log = await pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(log, ['ok']);
      expect(find.text('Are you sure?'), findsNothing);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Are you sure?'), findsOneWidget);
    });
  });

  testWidgets('golden: xl and hold buttons, avatars, progress centre, chat', (tester) async {
    await expectThemedGolden(tester, 'release_035', height: 420, themes: const [UiThemeName.maldives, UiThemeName.maldivesDark], (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            UiButton(label: 'Start visit', size: UiSize.xl, block: true, onPressed: () {}),
            UiHoldButton(label: "I've arrived", block: true, onConfirmed: () {}),
            const Row(spacing: 12, children: [
              UiAvatar(name: 'Aminath Hassan', size: UiSize.xl),
              UiAvatar(name: 'Aminath Hassan', dimension: 72),
              UiProgressCircle(value: 40, size: 72, strokeWidth: 6, label: 'Seconds left', child: Text('12')),
            ]),
            const UiChatBubble(meta: '09:40', child: Text("Hello, I'm on my way to you.")),
            const UiChatBubble(mine: true, meta: '09:41 · Read', child: Text('Thank you! The gate code is 2468.')),
          ],
        ));
  });
}
