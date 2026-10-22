import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// 0.44.0 (visit UX L1, L2): the FAB's hold-to-activate and topOffset; badges on buttons.

Widget _sos(List<String> log, {Duration? hold = const Duration(seconds: 1)}) => UiFab(
      icon: const UiIcon(HugeIcons.strokeRoundedAlert02),
      label: 'Emergency SOS',
      text: 'SOS',
      tone: UiFabTone.danger,
      hold: hold,
      holdHint: 'Press and hold to call for help',
      confirmTitle: 'Send an SOS?',
      confirmLabel: 'Send SOS',
      destructive: true,
      onPressed: () => log.add('sos'),
    );

void main() {
  group('UiFab hold', () {
    testWidgets('held to the end it fires, with no dialog; the fill grows meanwhile', (tester) async {
      final log = <String>[];
      await pumpUi(tester, Center(child: _sos(log)));
      final g = await tester.startGesture(tester.getCenter(find.byType(UiFab)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(log, isEmpty);
      expect(tester.state<UiHoldActivatorState>(find.byType(UiHoldActivator)).progress, closeTo(0.5, 0.05));
      await tester.pump(const Duration(milliseconds: 600));
      expect(log, ['sos']);
      await g.up();
      await tester.pumpAndSettle();
      expect(log, ['sos']);
      expect(find.text('Send an SOS?'), findsNothing);
    });

    testWidgets('let go early: nothing; a tap opens the confirm dialog, which sends it', (tester) async {
      final log = <String>[];
      await pumpUi(tester, Center(child: _sos(log)));
      final g = await tester.startGesture(tester.getCenter(find.byType(UiFab)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await g.up();
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      expect(find.text('Send an SOS?'), findsNothing);
      await tester.tap(find.byType(UiFab));
      await tester.pumpAndSettle();
      expect(find.text('Send an SOS?'), findsOneWidget);
      await tester.tap(find.text('Send SOS'));
      await tester.pumpAndSettle();
      expect(log, ['sos']);
    });

    testWidgets('a screen reader activation opens the dialog; name and hold hint are read', (tester) async {
      final sem = tester.ensureSemantics();
      final log = <String>[];
      await pumpUi(tester, Center(child: _sos(log)));
      final node = tester.getSemantics(find.bySemanticsLabel('Emergency SOS'));
      expect(node.getSemanticsData().hint, 'Press and hold to call for help');
      tester.semantics.tap(find.semantics.byLabel('Emergency SOS'));
      await tester.pumpAndSettle();
      expect(find.text('Send an SOS?'), findsOneWidget);
      expect(log, isEmpty);
      sem.dispose();
    });

    testWidgets('keyboard: Space held fires; a quick Enter opens the dialog', (tester) async {
      final log = <String>[];
      await pumpUi(tester, Center(child: _sos(log)));
      final node = Focus.of(tester.element(find.descendant(of: find.byType(UiFab), matching: find.byType(AnimatedScale)).first));
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(log, ['sos']);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Send an SOS?'), findsOneWidget);
    });

    testWidgets('without hold a tap fires at once', (tester) async {
      final log = <String>[];
      await pumpUi(tester, Center(child: _sos(log, hold: null)));
      await tester.tap(find.byType(UiFab));
      await tester.pump();
      expect(log, ['sos']);
      expect(find.byType(UiHoldActivator), findsNothing);
    });
  });

  testWidgets('UiFabHost.topOffset puts a top button under the app bar', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    tester.view.padding = FakeViewPadding(top: 30 * tester.view.devicePixelRatio);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(
      home: UiFabHost(
        position: UiFabPosition.topEnd,
        topOffset: 56,
        fab: _sos(<String>[]),
        child: const SizedBox.expand(),
      ),
    ));
    await tester.pump();
    expect(tester.getRect(find.byType(UiFab)).top, 30 + 56 + 24);
  });

  group('badges', () {
    testWidgets('UiIconButton and UiButton: the bubble at the top-end corner, read after the name', (tester) async {
      final sem = tester.ensureSemantics();
      await pumpUi(
        tester,
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 24, children: [
            UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedMessage01), label: 'Chat', badge: '2', badgeLabel: '2 unread', onPressed: () {}),
            UiButton(label: 'Messages', badge: uiBadgeCount(12), onPressed: () {}),
          ]),
        ),
      );
      expect(find.bySemanticsLabel('Chat, 2 unread'), findsOneWidget);
      expect(find.bySemanticsLabel('Messages, 9+'), findsOneWidget);
      // The bubbles' own text isn't read separately.
      expect(find.bySemanticsLabel('2'), findsNothing);
      expect(find.bySemanticsLabel('9+'), findsNothing);
      // Its visible square, not the 48dp touch area around it.
      final icon = tester.getRect(find.descendant(of: find.byType(UiIconButton), matching: find.byType(AnimatedContainer)).first);
      final b1 = tester.getRect(find.byType(UiButtonBadge).first);
      expect(b1.top, closeTo(icon.top - 6, 0.5));
      expect(b1.right, closeTo(icon.right + 6, 0.5));
      expect(b1.height, 16);
      final t = UiTheme.of(tester.element(find.byType(UiButtonBadge).first)).tokens;
      final box = tester.widget<Container>(find.descendant(of: find.byType(UiButtonBadge).first, matching: find.byType(Container)));
      expect((box.decoration! as BoxDecoration).color, t.danger);
      sem.dispose();
    });

    testWidgets('RTL: the bubble moves to the top-left; primary tone; no badge, no bubble and the plain name', (tester) async {
      final sem = tester.ensureSemantics();
      await pumpUi(
        tester,
        Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(mainAxisSize: MainAxisSize.min, spacing: 24, children: [
              UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedMessage01), label: 'Chat', badge: '1', badgeTone: UiBadgeTone.primary, onPressed: () {}),
              UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedMessage01), label: 'Calls', onPressed: () {}),
            ]),
          ),
        ),
      );
      final icon = tester.getRect(find.descendant(of: find.byType(UiIconButton).first, matching: find.byType(AnimatedContainer)).first);
      final b = tester.getRect(find.byType(UiButtonBadge));
      expect(b.left, closeTo(icon.left - 6, 0.5));
      final t = UiTheme.of(tester.element(find.byType(UiButtonBadge))).tokens;
      final box = tester.widget<Container>(find.descendant(of: find.byType(UiButtonBadge), matching: find.byType(Container)));
      expect((box.decoration! as BoxDecoration).color, t.primary);
      expect(find.byType(UiButtonBadge), findsOneWidget);
      expect(find.bySemanticsLabel('Chat, 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Calls'), findsOneWidget);
      sem.dispose();
    });

    test('uiBadgeCount', () {
      expect(uiBadgeCount(0), isNull);
      expect(uiBadgeCount(-1), isNull);
      expect(uiBadgeCount(3), '3');
      expect(uiBadgeCount(9), '9');
      expect(uiBadgeCount(10), '9+');
      expect(uiBadgeCount(120, max: 99), '99+');
    });

    testWidgets('golden: badges on icon buttons and buttons', (tester) async {
      await expectThemedGolden(
        tester,
        'button_badges',
        (context) => Wrap(spacing: 24, runSpacing: 24, children: [
          UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedMessage01), label: 'Chat', badge: '2', variant: UiButtonVariant.outline, onPressed: () {}),
          UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedNotification01), label: 'Alerts', badge: '9+', onPressed: () {}),
          UiButton(label: 'Chat', icon: const UiIcon(HugeIcons.strokeRoundedMessage01), badge: '3', variant: UiButtonVariant.secondary, onPressed: () {}),
          UiButton(label: 'Updates', badge: '1', badgeTone: UiBadgeTone.primary, variant: UiButtonVariant.outline, onPressed: () {}),
        ]),
        height: 120,
      );
    });
  });

  testWidgets('semantics action list on a held fab has a tap', (tester) async {
    final sem = tester.ensureSemantics();
    await pumpUi(tester, Center(child: _sos(<String>[])));
    final d = tester.getSemantics(find.bySemanticsLabel('Emergency SOS')).getSemanticsData();
    expect(d.hasAction(SemanticsAction.tap), isTrue);
    sem.dispose();
  });
}
