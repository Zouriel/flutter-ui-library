import 'dart:ui' show GestureSettings;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// A tile in a scroll view (as in an album), with double tap on.
Widget _tile(List<String> log, {bool selecting = false}) => SizedBox(
      width: 390,
      height: 600,
      child: SingleChildScrollView(
        child: Column(children: [
          SizedBox(
            width: 200,
            height: 200,
            child: UiSelectable(
              key: const Key('tile'),
              selected: false,
              selecting: selecting,
              semanticLabel: 'Beach',
              onTap: () => log.add('tap'),
              onLongPress: () => log.add('long'),
              onDoubleTap: (p) => log.add('double ${p.dx.round()},${p.dy.round()}'),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 1200),
        ]),
      ),
    );

void main() {
  setUp(() {});

  testWidgets('two taps close together are one double tap, and the single tap never fires', (tester) async {
    tester.view.gestureSettings = GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetGestureSettings);
    final log = <String>[];
    await pumpUi(tester, _tile(log));
    final box = tester.getTopLeft(find.byKey(const Key('tile')));
    await tester.tapAt(box + const Offset(40, 50));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(box + const Offset(44, 52));
    await tester.pump(uiDoubleTapWindow * 2);
    expect(log, ['double 44,52']);
  });

  testWidgets('a single tap still fires once the window has passed; a long press cancels a waiting tap', (tester) async {
    final log = <String>[];
    await pumpUi(tester, _tile(log));
    await tester.tap(find.byKey(const Key('tile')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(log, isEmpty);
    await tester.pump(uiDoubleTapWindow);
    expect(log, ['tap']);

    await tester.tap(find.byKey(const Key('tile')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.longPress(find.byKey(const Key('tile')));
    await tester.pump(uiDoubleTapWindow * 2);
    expect(log, ['tap', 'long']);
  });

  testWidgets('taps far apart are two taps; selecting never waits; a drag is neither', (tester) async {
    final log = <String>[];
    await pumpUi(tester, _tile(log));
    final box = tester.getTopLeft(find.byKey(const Key('tile')));
    await tester.tapAt(box + const Offset(20, 20));
    await tester.tapAt(box + const Offset(160, 160));
    await tester.pump(uiDoubleTapWindow * 2);
    expect(log, ['tap', 'tap']);

    await tester.drag(find.byKey(const Key('tile')), const Offset(0, -120));
    await tester.pump(uiDoubleTapWindow * 2);
    expect(log, ['tap', 'tap']);

    log.clear();
    await pumpUi(tester, _tile(log, selecting: true));
    await tester.tap(find.byKey(const Key('tile')));
    await tester.pump();
    expect(log, ['tap']);
  });

  test('counts are shortened without rounding up', () {
    expect([0, 7, 999, 1000, 1234, 15400, 999499, 1250000].map(uiCompactCount), ['0', '7', '999', '1k', '1.2k', '15k', '999k', '1.2m']);
  });

  testWidgets('the count badge is hidden at 0, shows the number, and reads liked', (tester) async {
    await pumpUi(tester, const Center(child: UiLikeCount(count: 0)));
    expect(find.byType(Text), findsNothing);
    expect(find.bySemanticsLabel(RegExp('like')), findsNothing);

    await pumpUi(tester, const Center(child: UiLikeCount(count: 1234)));
    expect(find.text('1.2k'), findsOneWidget);
    expect(find.bySemanticsLabel('1234 likes'), findsOneWidget);
    expect(tester.widget<CustomPaint>(find.descendant(of: find.byType(UiLikeCount), matching: find.byType(CustomPaint))).painter,
        isA<UiHeartPainter>().having((p) => p.filled, 'filled', false));

    await pumpUi(tester, const Center(child: UiLikeCount(count: 3, liked: true)));
    expect(find.bySemanticsLabel('Liked, 3 likes'), findsOneWidget);
    expect(tester.widget<CustomPaint>(find.descendant(of: find.byType(UiLikeCount), matching: find.byType(CustomPaint))).painter,
        isA<UiHeartPainter>().having((p) => p.filled, 'filled', true));
  });

  testWidgets('the like button toggles and announces its state', (tester) async {
    final changes = <bool>[];
    await pumpUi(tester, Center(child: UiLikeButton(liked: false, count: 0, onChanged: changes.add)));
    expect(tester.getSemantics(find.byType(UiLikeButton)), matchesSemantics(isButton: true, hasToggledState: true, isToggled: false, hasEnabledState: true, isEnabled: true, hasTapAction: true, label: 'Like, 0 likes'));
    await tester.tap(find.byType(UiLikeButton));
    await pumpUi(tester, Center(child: UiLikeButton(liked: true, count: 1, onChanged: changes.add)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byType(UiLikeButton));
    expect(changes, [true, false]);
  });

  testWidgets('a burst plays where asked, takes no pointer, and clears itself', (tester) async {
    final key = GlobalKey<UiHeartBurstState>();
    var taps = 0;
    await pumpUi(
      tester,
      Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: Stack(children: [
            Positioned.fill(child: GestureDetector(onTap: () => taps++, child: const ColoredBox(color: Color(0xFF000000)))),
            Positioned.fill(child: UiHeartBurst(key: key)),
          ]),
        ),
      ),
    );
    key.currentState!.play(const Offset(40, 60));
    await tester.pump(const Duration(milliseconds: 150));
    final paint = find.descendant(of: find.byKey(key), matching: find.byType(CustomPaint));
    expect(paint, findsOneWidget);
    final topLeft = tester.getTopLeft(find.byKey(key));
    expect(tester.getCenter(paint).dx - topLeft.dx, closeTo(40, 1));
    await tester.tapAt(topLeft + const Offset(40, 60));
    expect(taps, 1);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.descendant(of: find.byKey(key), matching: find.byType(CustomPaint)), findsNothing);
  });
}
