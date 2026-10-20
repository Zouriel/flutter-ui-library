import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

class _Host {
  bool open = false;
  final reasons = <UiHintCloseReason>[];
  late StateSetter set;
}

Future<_Host> _pump(WidgetTester tester, {UiHintPlacement placement = UiHintPlacement.top, Duration duration = const Duration(milliseconds: 6000), bool dismissible = false, TextDirection dir = TextDirection.ltr, Alignment at = Alignment.center, UiThemeName theme = UiThemeName.dark}) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final h = _Host();
  await tester.pumpWidget(UiApp(
    theme: theme,
    home: Directionality(
      textDirection: dir,
      child: StatefulBuilder(builder: (context, set) {
        h.set = set;
        return Stack(children: [
          const Positioned(left: 16, top: 16, width: 200, child: UiInput(key: Key('other'), semanticLabel: 'Other')),
          Align(
            alignment: at,
            child: UiHint(
              message: 'Hold to record',
              open: h.open,
              placement: placement,
              duration: duration,
              dismissible: dismissible,
              onOpenChanged: (v) => set(() => h.open = v),
              onClosed: h.reasons.add,
              child: UiIconButton(key: const Key('mic'), label: 'Record', onPressed: () {}, icon: const SizedBox(width: 16, height: 16)),
            ),
          ),
        ]);
      }),
    ),
  ));
  await tester.pump();
  return h;
}

Future<void> _open(WidgetTester tester, _Host h) async {
  h.set(() => h.open = true);
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
  await tester.pump(const Duration(milliseconds: 300));
}

Finder get _bubble => find.byType(UiHintBubble);

void main() {
  testWidgets('opens from code as a polite live region, announcing its text after it appears', (tester) async {
    final handle = tester.ensureSemantics();
    final h = await _pump(tester);
    expect(_bubble, findsNothing);
    h.set(() => h.open = true);
    await tester.pump();
    await tester.pump();
    expect(_bubble, findsOneWidget);
    expect(tester.widget<UiHintBubble>(_bubble).message, '', reason: 'empty first');
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('Hold to record'), findsOneWidget);
    final node = tester.getSemantics(find.descendant(of: _bubble, matching: find.byType(GestureDetector)).first);
    var live = false;
    var labelled = false;
    for (SemanticsNode? n = node; n != null; n = n.parent) {
      final d = n.getSemanticsData();
      if (d.flagsCollection.isLiveRegion) live = true;
      if (d.label == 'Hold to record') labelled = true;
    }
    expect(live && labelled, isTrue);
    expect(find.bySemanticsLabel('Hold to record'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    handle.dispose();
  });

  testWidgets('never takes focus, and typing elsewhere goes on', (tester) async {
    final h = await _pump(tester);
    await tester.tap(find.byKey(const Key('other')));
    await tester.pump();
    final other = tester.widget<EditableText>(find.byType(EditableText)).focusNode;
    expect(other.hasFocus, isTrue);
    await _open(tester, h);
    expect(other.hasFocus, isTrue);
    await tester.enterText(find.byType(EditableText), 'still typing');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(_bubble, findsOneWidget);
    expect(other.hasFocus, isTrue);
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('touches outside it reach the page', (tester) async {
    final h = await _pump(tester);
    await _open(tester, h);
    await tester.tap(find.byKey(const Key('other')));
    await tester.pump();
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('closes after its duration with reason timeout; zero keeps it', (tester) async {
    var h = await _pump(tester);
    await _open(tester, h);
    await tester.pump(const Duration(milliseconds: 5000));
    expect(_bubble, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    expect(_bubble, findsNothing);
    expect(h.open, isFalse);
    expect(h.reasons, [UiHintCloseReason.timeout]);
    await tester.pumpWidget(const SizedBox());
    h = await _pump(tester, duration: Duration.zero);
    await _open(tester, h);
    await tester.pump(const Duration(minutes: 1));
    expect(_bubble, findsOneWidget);
  });

  testWidgets('closes on Escape, a tap on it, and a tap on its anchor, with the reason', (tester) async {
    final h = await _pump(tester, duration: Duration.zero);
    await _open(tester, h);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_bubble, findsNothing);
    await _open(tester, h);
    await tester.tap(find.text('Hold to record'));
    await tester.pump();
    expect(_bubble, findsNothing);
    await _open(tester, h);
    await tester.tap(find.byKey(const Key('mic')));
    await tester.pump();
    expect(_bubble, findsNothing);
    expect(h.reasons, [UiHintCloseReason.escape, UiHintCloseReason.tap, UiHintCloseReason.tap]);
  });

  testWidgets('a × only when dismissible, named Dismiss, closing with tap', (tester) async {
    final handle = tester.ensureSemantics();
    var h = await _pump(tester, duration: Duration.zero);
    await _open(tester, h);
    expect(find.bySemanticsLabel('Dismiss'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    h = await _pump(tester, duration: Duration.zero, dismissible: true);
    await _open(tester, h);
    expect(find.bySemanticsLabel('Dismiss'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Dismiss'));
    await tester.pump();
    expect(_bubble, findsNothing);
    expect(h.reasons, [UiHintCloseReason.tap]);
    handle.dispose();
  });

  testWidgets('the app closing it is not reported', (tester) async {
    final h = await _pump(tester, duration: Duration.zero);
    await _open(tester, h);
    h.set(() => h.open = false);
    await tester.pump();
    await tester.pump();
    expect(_bubble, findsNothing);
    expect(h.reasons, isEmpty);
  });

  testWidgets('sits on the preferred side, flips at the screen edge, and start/end follow the direction', (tester) async {
    Future<(Rect, Rect)> rects({required UiHintPlacement placement, TextDirection dir = TextDirection.ltr, Alignment at = Alignment.center}) async {
      await tester.pumpWidget(const SizedBox());
      final h = await _pump(tester, placement: placement, dir: dir, at: at, duration: Duration.zero);
      await _open(tester, h);
      return (tester.getRect(_bubble), tester.getRect(find.byKey(const Key('mic'))));
    }

    var (b, a) = await rects(placement: UiHintPlacement.top);
    expect(b.bottom, lessThanOrEqualTo(a.top));
    (b, a) = await rects(placement: UiHintPlacement.top, at: Alignment.topCenter);
    expect(b.top, greaterThanOrEqualTo(a.bottom), reason: 'no room above: flips below');
    (b, a) = await rects(placement: UiHintPlacement.start);
    expect(b.right, lessThanOrEqualTo(a.left));
    (b, a) = await rects(placement: UiHintPlacement.start, dir: TextDirection.rtl);
    expect(b.left, greaterThanOrEqualTo(a.right), reason: 'start is the right side in RTL');
    (b, a) = await rects(placement: UiHintPlacement.end, dir: TextDirection.rtl);
    expect(b.right, lessThanOrEqualTo(a.left));
    expect(b.left, greaterThanOrEqualTo(8));
  });

  testWidgets('uses the theme: primary fill and its contrast text, in maldives and maldives-dark', (tester) async {
    for (final theme in [UiThemeName.maldives, UiThemeName.maldivesDark]) {
      await tester.pumpWidget(const SizedBox());
      final h = await _pump(tester, theme: theme, duration: Duration.zero);
      await _open(tester, h);
      final t = uiThemeTokens[theme]!;
      final box = tester.widget<DecoratedBox>(find.descendant(of: _bubble, matching: find.byType(DecoratedBox)).first);
      expect((box.decoration as BoxDecoration).color, t.primary);
      expect(tester.widget<Text>(find.text('Hold to record')).style!.color, t.primaryContrast);
    }
  });

  testWidgets('golden: a hint above and one beside its anchor, with a ×', (tester) async {
    for (final theme in [UiThemeName.maldives, UiThemeName.maldivesDark]) {
      debugDisableShadows = false;
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(390, 260) * 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(
        theme: theme,
        home: Stack(children: [
          Positioned(
            left: 40,
            top: 120,
            child: UiHint(message: 'Hold to record a voice note', open: true, duration: Duration.zero, child: UiIconButton(label: 'Record', variant: UiButtonVariant.outline, onPressed: () {}, icon: UiIcon(HugeIcons.strokeRoundedMic01))),
          ),
          Positioned(
            left: 40,
            top: 200,
            child: UiHint(message: 'Attach a photo', open: true, dismissible: true, placement: UiHintPlacement.end, duration: Duration.zero, child: UiIconButton(label: 'Attach', variant: UiButtonVariant.outline, onPressed: () {}, icon: UiIcon(HugeIcons.strokeRoundedAttachment01))),
          ),
        ]),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 400));
      try {
        await expectLater(find.byType(UiApp), matchesGoldenFile('goldens/hint_${theme.name}.png'));
      } finally {
        debugDisableShadows = true;
      }
    }
  });

  testWidgets('near the left edge it stays above and slides along, with the arrow on the anchor', (tester) async {
    final h = await _pump(tester, at: Alignment.centerLeft, duration: Duration.zero);
    await _open(tester, h);
    final b = tester.getRect(_bubble), a = tester.getRect(find.byKey(const Key('mic')));
    expect(b.bottom, lessThanOrEqualTo(a.top), reason: 'still above, not beside');
    expect(b.left, greaterThanOrEqualTo(8));
    expect(b.left, lessThan(a.center.dx));
  });

  testWidgets('never moves beside the anchor when above and below are both short of room', (tester) async {
    tester.view.physicalSize = const Size(390, 120) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    var open = false;
    late StateSetter set;
    await tester.pumpWidget(UiApp(home: StatefulBuilder(builder: (context, s) {
      set = s;
      return Center(
        child: UiHint(
          message: 'A long hint that wraps over a few lines because the screen is short and narrow anyway',
          open: open,
          duration: Duration.zero,
          child: UiIconButton(key: const Key('mic'), label: 'Record', onPressed: () {}, icon: const SizedBox(width: 16, height: 16)),
        ),
      );
    })));
    set(() => open = true);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final b = tester.getRect(_bubble), a = tester.getRect(find.byKey(const Key('mic')));
    final beside = b.right <= a.left || b.left >= a.right;
    expect(beside, isFalse);
  });

  testWidgets('follows its anchor when it moves, even when only layout changes (a slot icon swapping sides)', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    final gap = ValueNotifier(20.0);
    addTearDown(gap.dispose);
    // The hint widget itself is built once; only a sibling's width changes, moving the anchor.
    final hint = UiHint(
      message: 'Hold to record',
      open: true,
      duration: Duration.zero,
      child: UiIconButton(key: const Key('mic'), label: 'Record', onPressed: () {}, icon: const SizedBox(width: 16, height: 16)),
    );
    await tester.pumpWidget(UiApp(
      home: Padding(
        padding: const EdgeInsets.only(top: 400),
        child: Align(
          alignment: Alignment.topLeft,
          child: Row(mainAxisSize: MainAxisSize.min, children: [ValueListenableBuilder<double>(valueListenable: gap, builder: (_, w, _) => SizedBox(width: w)), hint]),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final first = tester.getRect(_bubble);
    gap.value = 200;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final a = tester.getRect(find.byKey(const Key('mic')));
    final b = tester.getRect(_bubble);
    expect(a.left, greaterThan(190));
    expect(b.center.dx, closeTo(a.center.dx, 1), reason: 'centred on the anchor where it is now (it was at ${first.center.dx})');
    expect(b.bottom, lessThanOrEqualTo(a.top));
  });
}
