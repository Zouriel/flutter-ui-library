import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

// The pacing rules, the same as the web guidance.spec.ts.

Future<UiTourOutcome> _closed() async => UiTourOutcome.closed;

void main() {
  late UiMemoryGuidanceStore store;
  late DateTime now;
  late UiGuidance g;

  setUp(() {
    store = UiMemoryGuidanceStore();
    now = DateTime(2026, 11, 13, 10);
    g = UiGuidance(store, now: () => now);
  });

  test('shows an unseen id once, marks it seen on any outcome, and never again', () async {
    var shown = 0;
    expect(await g.requestTip('tip.a', () async {
      shown++;
      return UiTourOutcome.closed;
    }), UiTourOutcome.closed);
    expect(store.ids, {'tip.a'});
    expect(await g.requestTip('tip.a', () async {
      shown++;
      return UiTourOutcome.closed;
    }), isNull);
    expect(shown, 1);
  });

  test('refuses an id the store already has as seen', () async {
    store.ids.add('tip.seen');
    var shown = false;
    expect(await g.canShow('tip.seen'), isFalse);
    expect(await g.requestTip('tip.seen', () async {
      shown = true;
      return UiTourOutcome.closed;
    }), isNull);
    expect(shown, isFalse);
  });

  test('tips off: nothing shows', () async {
    store.on = false;
    expect(await g.canShow('tip.a'), isFalse);
    expect(await g.requestTip('tip.a', _closed), isNull);
    expect(store.ids, isEmpty);
  });

  test('skipWhen: not shown, marked seen silently; canShow changes nothing', () async {
    expect(await g.canShow('tip.a', skipWhen: true), isFalse);
    expect(store.ids, isEmpty);
    var shown = false;
    expect(await g.requestTip('tip.a', () async {
      shown = true;
      return UiTourOutcome.closed;
    }, skipWhen: true), isNull);
    expect(shown, isFalse);
    expect(store.ids, {'tip.a'});
  });

  test('one thing on screen at a time: a second request is refused while the first shows', () async {
    final first = Completer<UiTourOutcome>();
    final a = g.requestTip('tour.a', () => first.future, kind: UiGuidanceKind.tour);
    await Future<void>.delayed(Duration.zero);
    expect(g.active, 'tour.a');
    expect(await g.canShow('tip.b'), isFalse);
    expect(await g.requestTip('tip.b', _closed), isNull);
    first.complete(UiTourOutcome.finished);
    expect(await a, UiTourOutcome.finished);
    expect(g.active, isNull);
    // b was refused, not marked: it can show later.
    expect(store.ids, {'tour.a'});
    expect(await g.requestTip('tip.b', _closed), UiTourOutcome.closed);
  });

  test('two requests in the same turn: only the first passes', () async {
    final results = await Future.wait([g.requestTip('tip.a', _closed), g.requestTip('tip.b', _closed)]);
    expect(results, [UiTourOutcome.closed, null]);
  });

  test('at most one offer per session; tours and tips are not offers', () async {
    expect(await g.requestTip('offer.a', _closed, kind: UiGuidanceKind.offer), UiTourOutcome.closed);
    expect(await g.canShow('offer.b', kind: UiGuidanceKind.offer), isFalse);
    expect(await g.requestTip('offer.b', _closed, kind: UiGuidanceKind.offer), isNull);
    expect(await g.requestTip('tour.a', _closed, kind: UiGuidanceKind.tour), UiTourOutcome.closed);
    // A new session (controller) may show one again.
    final next = UiGuidance(store, now: () => now);
    expect(await next.requestTip('offer.b', _closed, kind: UiGuidanceKind.offer), UiTourOutcome.closed);
  });

  test('at most 3 new tips a day (configurable); tours and offers do not count; a new day starts again', () async {
    for (final id in ['t1', 't2', 't3']) {
      expect(await g.requestTip(id, _closed), UiTourOutcome.closed);
    }
    expect(await g.requestTip('t4', _closed), isNull);
    expect(await g.requestTip('tour.x', _closed, kind: UiGuidanceKind.tour), UiTourOutcome.closed);
    expect(store.days['2026-11-13'], 3);
    now = DateTime(2026, 11, 14, 9);
    expect(await g.requestTip('t4', _closed), UiTourOutcome.closed);

    final two = UiGuidance(UiMemoryGuidanceStore(), maxTipsPerDay: 1, now: () => now);
    expect(await two.requestTip('a', _closed), UiTourOutcome.closed);
    expect(await two.requestTip('b', _closed), isNull);
  });

  test('the day count is read from the store when it keeps one (another device session)', () async {
    store.days['2026-11-13'] = 3;
    expect(await g.requestTip('t1', _closed), isNull);
  });

  test('a store without a day count keeps it in memory', () async {
    final s = _BareStore();
    final b = UiGuidance(s, maxTipsPerDay: 2, now: () => now);
    expect(await b.requestTip('a', _closed), UiTourOutcome.closed);
    expect(await b.requestTip('b', _closed), UiTourOutcome.closed);
    expect(await b.requestTip('c', _closed), isNull);
    expect(s.seenIds, ['a', 'b']);
  });

  test('turnedOff turns tips off; reset brings everything back', () async {
    expect(await g.requestTip('tour.a', () async => UiTourOutcome.turnedOff, kind: UiGuidanceKind.tour), UiTourOutcome.turnedOff);
    expect(store.on, isFalse);
    expect(await g.tipsOn(), isFalse);
    expect(await g.requestTip('tip.b', _closed), isNull);
    await g.reset();
    expect(store.on, isTrue);
    expect(store.ids, isEmpty);
    expect(await g.requestTip('tour.a', _closed, kind: UiGuidanceKind.tour), UiTourOutcome.closed);
  });

  test('a show that throws counts as closed and is still marked seen', () async {
    expect(await g.requestTip('tip.a', () async => throw StateError('gone')), UiTourOutcome.closed);
    expect(store.ids, {'tip.a'});
    expect(g.active, isNull);
  });

  test('markSeen writes only new ids; active notifies listeners', () async {
    final s = _BareStore();
    final b = UiGuidance(s);
    await b.markSeen(['a', 'b']);
    await b.markSeen(['b', 'c']);
    expect(s.seenIds, ['a', 'b', 'c']);
    expect(await b.isSeen('c'), isTrue);
    final seen = <String?>[];
    b.addListener(() => seen.add(b.active));
    await b.requestTip('x', _closed);
    expect(seen, ['x', null]);
  });

  test('works with an async store', () async {
    final s = _AsyncStore();
    final b = UiGuidance(s, now: () => now);
    expect(await b.requestTip('a', _closed), UiTourOutcome.closed);
    expect(await b.requestTip('a', _closed), isNull);
    expect(s.ids, {'a'});
  });
}

/// A store with only the required methods (no day count).
class _BareStore extends UiGuidanceStore {
  final List<String> seenIds = [];
  @override
  bool tipsOn() => true;
  @override
  bool seen(String id) => seenIds.contains(id);
  @override
  void markSeen(List<String> ids) => seenIds.addAll(ids);
  @override
  void setTipsOn(bool on) {}
  @override
  void reset() => seenIds.clear();
}

class _AsyncStore extends UiGuidanceStore {
  final Set<String> ids = {};
  @override
  Future<bool> tipsOn() async => true;
  @override
  Future<bool> seen(String id) async => ids.contains(id);
  @override
  Future<void> markSeen(List<String> ids) async => this.ids.addAll(ids);
  @override
  Future<void> setTipsOn(bool on) async {}
  @override
  Future<void> reset() async => ids.clear();
  @override
  Future<int?> readDayCount(String day) async => null;
}
