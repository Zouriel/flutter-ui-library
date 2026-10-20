import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// The web 0.32 drawer flashed its full overlay back for a frame or two on close: its backdrop's
/// short fade ended, the class holding it at 0 dropped, and the layer stayed until the longer panel
/// slide ended. Here the dim layer of every dialog must only ever fade out during a close.

/// The barrier's current opacity: a route's ModalBarrier colour alpha, or a UiBackdrop's opacity.
double _dim(WidgetTester tester) {
  final barrier = find.byType(AnimatedModalBarrier);
  if (barrier.evaluate().isNotEmpty) {
    final w = tester.widget<AnimatedModalBarrier>(barrier.last);
    return (w.color.value?.a ?? 0);
  }
  final backdrop = find.byType(UiBackdrop);
  if (backdrop.evaluate().isEmpty) return 0;
  var o = 1.0;
  // AnimatedOpacity paints through a FadeTransition; its animation is what is on screen.
  for (final f in tester.widgetList<FadeTransition>(find.ancestor(of: backdrop, matching: find.byType(FadeTransition)))) {
    o *= f.opacity.value;
  }
  return o;
}

Future<List<double>> _sample(WidgetTester tester) async {
  final seen = <double>[];
  for (var i = 0; i < 40; i++) {
    seen.add(_dim(tester));
    await tester.pump(const Duration(milliseconds: 16));
  }
  return seen;
}

void _expectFalling(List<double> seen) {
  for (var i = 1; i < seen.length; i++) {
    expect(seen[i], lessThanOrEqualTo(seen[i - 1] + 1e-9), reason: 'frame $i: ${seen[i - 1]} -> ${seen[i]} in $seen');
  }
  expect(seen.first, greaterThan(0));
  expect(seen.last, 0);
}

Future<BuildContext> _app(WidgetTester tester, {Widget? overlay}) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  late BuildContext ctx;
  await tester.pumpWidget(UiApp(home: Builder(builder: (context) {
    ctx = context;
    return Stack(children: [const SizedBox.expand(), ?overlay]);
  })));
  return ctx;
}

void main() {
  testWidgets('drawer: the barrier only fades during a close', (tester) async {
    final ctx = await _app(tester);
    showUiDrawer<void>(context: ctx, title: 'Panel', builder: (_) => const Text('Body'));
    await tester.pumpAndSettle();
    Navigator.of(ctx).pop();
    _expectFalling(await _sample(tester));
  });

  testWidgets('modal: the barrier only fades during a close', (tester) async {
    final ctx = await _app(tester);
    showUiModal<void>(context: ctx, title: 'Hello', builder: (_) => const Text('Body'));
    await tester.pumpAndSettle();
    Navigator.of(ctx).pop();
    _expectFalling(await _sample(tester));
  });

  testWidgets('bottom sheet with a backdrop: it fades out, never back up', (tester) async {
    var snap = 1;
    late StateSetter set;
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(home: StatefulBuilder(builder: (context, s) {
      set = s;
      return Stack(children: [
        const SizedBox.expand(),
        UiBottomSheet(snaps: const [0, 0.4, 0.9], snap: snap, title: 'Layers', backdrop: true, onSnapChanged: (i) => s(() => snap = i), child: const Text('Body')),
      ]);
    })));
    await tester.pumpAndSettle();
    set(() => snap = 0);
    _expectFalling(await _sample(tester));
  });
}
