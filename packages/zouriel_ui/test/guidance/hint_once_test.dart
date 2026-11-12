import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

Widget _app(UiGuidance g, Widget child) => UiApp(
      theme: UiThemeName.light,
      home: UiGuidanceScope(guidance: g, child: Center(child: child)),
    );

Widget _tip({String id = 'tip.me.settings', bool skipWhen = false, bool when = true, ValueChanged<UiTourOutcome?>? onDone, Key? key}) => UiHintOnce(
      key: key,
      id: id,
      message: 'Your plan, sign-in and tips live here.',
      skipWhen: skipWhen,
      when: when,
      dismissible: true,
      duration: Duration.zero,
      onDone: onDone,
      child: const SizedBox(width: 48, height: 48, child: Text('Settings')),
    );

const _text = 'Your plan, sign-in and tips live here.';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('shows once through the controller, is marked seen when closed, and never shows again', (tester) async {
    final store = UiMemoryGuidanceStore();
    final g = UiGuidance(store);
    final done = <UiTourOutcome?>[];
    await tester.pumpWidget(_app(g, _tip(onDone: done.add)));
    await _settle(tester);
    expect(find.text(_text), findsOneWidget);
    expect(g.active, 'tip.me.settings');
    await tester.tap(find.bySemanticsLabel('Dismiss'));
    await _settle(tester);
    expect(find.text(_text), findsNothing);
    expect(done, [UiTourOutcome.closed]);
    expect(store.ids, {'tip.me.settings'});
    expect(g.active, isNull);

    // A later visit (a new widget): not again.
    await tester.pumpWidget(_app(g, const SizedBox()));
    await tester.pumpWidget(_app(g, _tip(onDone: done.add)));
    await _settle(tester);
    expect(find.text(_text), findsNothing);
    expect(done, [UiTourOutcome.closed, null]);
  });

  testWidgets('waits for when; skipWhen marks it seen without showing', (tester) async {
    final store = UiMemoryGuidanceStore();
    final g = UiGuidance(store);
    await tester.pumpWidget(_app(g, _tip(when: false)));
    await _settle(tester);
    expect(find.text(_text), findsNothing);
    await tester.pumpWidget(_app(g, _tip()));
    await _settle(tester);
    expect(find.text(_text), findsOneWidget);

    final s2 = UiMemoryGuidanceStore();
    await tester.pumpWidget(_app(UiGuidance(s2), _tip(id: 'tip.feed.templates', skipWhen: true, key: const ValueKey(2))));
    await _settle(tester);
    expect(find.text(_text), findsNothing);
    expect(s2.ids, {'tip.feed.templates'});
  });

  testWidgets('refused while another tip or tour is on screen', (tester) async {
    final store = UiMemoryGuidanceStore();
    final g = UiGuidance(store);
    final other = Completer<UiTourOutcome>();
    unawaited(g.requestTip('tour.welcome', () => other.future, kind: UiGuidanceKind.tour));
    final done = <UiTourOutcome?>[];
    await tester.pumpWidget(_app(g, _tip(onDone: done.add)));
    await _settle(tester);
    expect(find.text(_text), findsNothing);
    expect(done, [null]);
    expect(store.ids, isEmpty);
    other.complete(UiTourOutcome.finished);
    await _settle(tester);
  });

  testWidgets('leaving the page while it shows ends it (closed) and frees the screen', (tester) async {
    final store = UiMemoryGuidanceStore();
    final g = UiGuidance(store);
    await tester.pumpWidget(_app(g, _tip()));
    await _settle(tester);
    expect(find.text(_text), findsOneWidget);
    await tester.pumpWidget(_app(g, const SizedBox()));
    await _settle(tester);
    expect(g.active, isNull);
    expect(store.ids, {'tip.me.settings'});
  });

  testWidgets('without a controller it never shows', (tester) async {
    await tester.pumpWidget(UiApp(home: Center(child: _tip())));
    await _settle(tester);
    expect(find.text(_text), findsNothing);
  });
}
