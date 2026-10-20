import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// An app whose home pushes the next page with [transition], in [dir], with motion as asked.
Future<NavigatorState> _app(WidgetTester tester, {TextDirection dir = TextDirection.ltr, bool reduced = false, bool animations = true}) async {
  tester.view.physicalSize = const Size(400, 800) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final key = GlobalKey<NavigatorState>();
  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData(size: const Size(400, 800), disableAnimations: reduced),
    child: UiApp(
      navigatorKey: key,
      config: UiConfig(animations: animations),
      builder: (context, child) => Directionality(textDirection: dir, child: child!),
      home: const Center(child: Text('Home')),
    ),
  ));
  return key.currentState!;
}

void _push(NavigatorState nav, UiPageTransition transition) =>
    nav.push(UiPageRoute<void>(transition: transition, builder: (_) => const SizedBox.expand(key: Key('next'), child: Center(child: Text('Next')))));

/// The next page's left edge part way through its entrance.
Future<double> _midLeft(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
  return tester.getTopLeft(find.byKey(const Key('next'))).dx;
}

void main() {
  testWidgets('slideFromStart enters from the left in LTR and the right in RTL; slideFromEnd the other way', (tester) async {
    for (final (dir, transition, fromLeft) in [
      (TextDirection.ltr, UiPageTransition.slideFromStart, true),
      (TextDirection.rtl, UiPageTransition.slideFromStart, false),
      (TextDirection.ltr, UiPageTransition.slideFromEnd, false),
      (TextDirection.rtl, UiPageTransition.slideFromEnd, true),
    ]) {
      await tester.pumpWidget(const SizedBox());
      final nav = await _app(tester, dir: dir);
      _push(nav, transition);
      final x = await _midLeft(tester);
      expect(fromLeft ? x < -10 : x > 10, isTrue, reason: '$dir $transition: left edge at $x');
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(const Key('next'))).dx, 0);
      // And it leaves the same way it came.
      nav.pop();
      final out = await _midLeft(tester);
      expect(fromLeft ? out < -10 : out > 10, isTrue, reason: '$dir $transition pop: $out');
      await tester.pumpAndSettle();
    }
  });

  testWidgets('under reduced motion it only fades; with animations off it changes at once', (tester) async {
    var nav = await _app(tester, reduced: true);
    _push(nav, UiPageTransition.slideFromStart);
    expect(await _midLeft(tester), 0);
    final fade = tester.widget<FadeTransition>(find.ancestor(of: find.byKey(const Key('next')), matching: find.byType(FadeTransition)).first);
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    nav = await _app(tester, animations: false);
    _push(nav, UiPageTransition.slideFromEnd);
    await tester.pump();
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const Key('next'))).dx, 0);
    expect(find.ancestor(of: find.byKey(const Key('next')), matching: find.byType(FadeTransition)), findsNothing);
  });

  testWidgets('the default stays the short fade with a rise', (tester) async {
    final nav = await _app(tester);
    _push(nav, UiPageTransition.fade);
    expect(await _midLeft(tester), 0);
    await tester.pumpAndSettle();
  });

  testWidgets('on iOS a slide route follows the swipe back from the edge it slid away from', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      // slideFromEnd in LTR came from the right: swipe from the left edge toward the right.
      var nav = await _app(tester);
      _push(nav, UiPageTransition.slideFromEnd);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(5, 400));
      await gesture.moveBy(const Offset(40, 0));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      final x = tester.getTopLeft(find.byKey(const Key('next'))).dx;
      expect(x, closeTo(100, 45), reason: 'follows the finger');
      await gesture.moveBy(const Offset(120, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('next')), findsNothing, reason: 'past half way: popped');
      expect(find.text('Home'), findsOneWidget);

      // A short drag settles back.
      _push(nav, UiPageTransition.slideFromEnd);
      await tester.pumpAndSettle();
      final short = await tester.startGesture(const Offset(5, 400));
      await short.moveBy(const Offset(30, 0));
      await short.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 500));
      await short.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(const Key('next'))).dx, 0);

      // slideFromStart in RTL also came from the right: the same swipe closes it.
      await tester.pumpWidget(const SizedBox());
      nav = await _app(tester, dir: TextDirection.rtl);
      _push(nav, UiPageTransition.slideFromStart);
      await tester.pumpAndSettle();
      final g = await tester.startGesture(const Offset(5, 400));
      await g.moveBy(const Offset(40, 0));
      await g.moveBy(const Offset(200, 0));
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(const Key('next'))).dx, greaterThan(100), reason: 'RTL: follows the finger rightwards');
      await g.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('next')), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('on Android there is no edge swipe (the system back gesture pops instead)', (tester) async {
    final nav = await _app(tester);
    _push(nav, UiPageTransition.slideFromEnd);
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(5, 400), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('next')), findsOneWidget);
  });
}
