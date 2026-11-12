import 'dart:async';

import 'package:flutter/widgets.dart';

/// How a tour, tip or offer ended (the web `UiTourOutcome`). [turnedOff]: the person pressed
/// "Turn off tips".
enum UiTourOutcome { finished, skipped, turnedOff, closed }

/// What a piece of guidance is, for pacing (the web `UiGuidanceKind`): [tip] (a one-off hint,
/// counts toward the daily cap), [offer] (a card asking "want a tour?", at most one per session)
/// or [tour] (neither cap).
enum UiGuidanceKind { tip, offer, tour }

/// Where seen ids and the tips switch live (the web `UiGuidanceStore`). The app decides: its
/// server (so web and phone agree), the device, or both. Every method may return a value or a
/// future of one.
abstract class UiGuidanceStore {
  /// Whether tips are on at all (the Settings switch).
  FutureOr<bool> tipsOn();

  /// Whether this id was already seen (shown and dismissed, finished, skipped or done).
  FutureOr<bool> seen(String id);

  /// Remembers these ids as seen, for good.
  FutureOr<void> markSeen(List<String> ids);

  /// The Settings switch, and "Turn off tips" in a tip.
  FutureOr<void> setTipsOn(bool on);

  /// "Show tips again": nothing seen, tips on.
  FutureOr<void> reset();

  /// Optional: how many one-off tips this device has shown on [day] (local `YYYY-MM-DD`). Null (the
  /// default) keeps the count in memory, so a restart starts the day again.
  FutureOr<int?> readDayCount(String day) => null;

  /// Optional: stores that count. Does nothing by default.
  FutureOr<void> writeDayCount(String day, int count) {}
}

/// A store that keeps everything in memory (the web `UiMemoryGuidanceStore`): for tests, demos and
/// signed-out visitors' first run.
class UiMemoryGuidanceStore extends UiGuidanceStore {
  UiMemoryGuidanceStore({Iterable<String> seen = const [], bool tipsOn = true}) : on = tipsOn {
    ids.addAll(seen);
  }

  final Set<String> ids = {};
  bool on;
  final Map<String, int> days = {};

  @override
  bool tipsOn() => on;
  @override
  bool seen(String id) => ids.contains(id);
  @override
  void markSeen(List<String> ids) => this.ids.addAll(ids);
  @override
  void setTipsOn(bool on) => this.on = on;
  @override
  void reset() {
    ids.clear();
    on = true;
  }

  @override
  int readDayCount(String day) => days[day] ?? 0;
  @override
  void writeDayCount(String day, int count) => days[day] = count;
}

/// Pacing and memory for tips, tours and offers (the web `UiGuidance`). Give it the app's store;
/// ask it before showing anything. The rules, the same on web and Flutter:
///
/// - tips off: nothing shows; a seen id never shows again;
/// - `skipWhen`: not shown, and [requestTip] marks it seen silently;
/// - one thing on screen at a time: while one is showing, every other request is refused (no queue);
/// - at most one [UiGuidanceKind.offer] per session (the life of this controller);
/// - at most [maxTipsPerDay] (3) new [UiGuidanceKind.tip]s a day;
/// - whatever the outcome, the id is marked seen; [UiTourOutcome.turnedOff] also turns tips off.
///
/// Listen to it for [active].
class UiGuidance extends ChangeNotifier {
  UiGuidance(this.store, {this.maxTipsPerDay = 3, DateTime Function()? now}) : _now = now ?? DateTime.now;

  final UiGuidanceStore store;

  /// At most this many new one-off tips ([UiGuidanceKind.tip]) a day.
  final int maxTipsPerDay;
  final DateTime Function() _now;
  final Set<String> _seenHere = {};
  bool _offerShown = false;
  final Map<String, int> _dayCounts = {};
  bool _tipsOffHere = false;
  String? _active;

  /// The id on screen (or being checked to go on screen), or null.
  String? get active => _active;

  void _setActive(String? id) {
    if (_active == id) return;
    _active = id;
    notifyListeners();
  }

  /// Whether [id] may show now, without showing it or changing anything.
  Future<bool> canShow(String id, {bool skipWhen = false, UiGuidanceKind kind = UiGuidanceKind.tip}) async {
    if (_active != null) return false;
    return await _refusal(id, skipWhen, kind) == null;
  }

  /// Shows [id] through [show] if the rules allow, and returns its outcome, or null when it was
  /// refused. [show] puts the thing on screen and completes when it ends (a tour's
  /// [UiTour.start], a hint that completes when closed, an offer card that completes on its
  /// buttons).
  Future<UiTourOutcome?> requestTip(
    String id,
    Future<UiTourOutcome> Function() show, {
    bool skipWhen = false,
    UiGuidanceKind kind = UiGuidanceKind.tip,
  }) async {
    // Claimed before the first await, so two requests in the same turn can't both pass.
    if (_active != null) return null;
    _setActive(id);
    try {
      final why = await _refusal(id, skipWhen, kind);
      if (why == _Refusal.skip) await markSeen([id]);
      if (why != null) return null;
      if (kind == UiGuidanceKind.offer) _offerShown = true;
      if (kind == UiGuidanceKind.tip) await _countTip();
      UiTourOutcome outcome;
      try {
        outcome = await show();
      } catch (_) {
        outcome = UiTourOutcome.closed;
      }
      await markSeen([id]);
      if (outcome == UiTourOutcome.turnedOff) await setTipsOn(false);
      return outcome;
    } finally {
      _setActive(null);
    }
  }

  /// Marks ids seen (an offer's action done elsewhere, a checklist closed).
  Future<void> markSeen(List<String> ids) async {
    final fresh = [for (final id in ids) if (!_seenHere.contains(id)) id];
    _seenHere.addAll(fresh);
    if (fresh.isNotEmpty) await store.markSeen(fresh);
  }

  /// Whether [id] is seen (the store, or marked during this session).
  Future<bool> isSeen(String id) async => _seenHere.contains(id) || await store.seen(id);

  /// Whether tips are on.
  Future<bool> tipsOn() async => !_tipsOffHere && await store.tipsOn();

  Future<void> setTipsOn(bool on) async {
    _tipsOffHere = !on;
    await store.setTipsOn(on);
  }

  /// "Show tips again": clears what this session remembers too (the session's offer; the day's
  /// count stays).
  Future<void> reset() async {
    _seenHere.clear();
    _tipsOffHere = false;
    _offerShown = false;
    await store.reset();
  }

  Future<_Refusal?> _refusal(String id, bool skipWhen, UiGuidanceKind kind) async {
    if (!await tipsOn()) return _Refusal.off;
    if (await isSeen(id)) return _Refusal.seen;
    if (skipWhen) return _Refusal.skip;
    if (kind == UiGuidanceKind.offer && _offerShown) return _Refusal.offer;
    if (kind == UiGuidanceKind.tip && await _readDay() >= maxTipsPerDay) return _Refusal.day;
    return null;
  }

  String _day() {
    final d = _now();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${pad(d.month)}-${pad(d.day)}';
  }

  Future<int> _readDay() async {
    final day = _day();
    final stored = await store.readDayCount(day) ?? 0;
    final here = _dayCounts[day] ?? 0;
    return stored > here ? stored : here;
  }

  Future<void> _countTip() async {
    final day = _day();
    final n = await _readDay() + 1;
    _dayCounts[day] = n;
    await store.writeDayCount(day, n);
  }
}

enum _Refusal { off, seen, skip, offer, day }

/// Gives the subtree one [UiGuidance] (the web `provideUiGuidance`), for [UiHintOnce] and the
/// app's own code. Rebuilds dependents when [UiGuidance.active] changes.
class UiGuidanceScope extends InheritedNotifier<UiGuidance> {
  const UiGuidanceScope({super.key, required UiGuidance guidance, required super.child}) : super(notifier: guidance);

  /// The nearest guidance controller, or null.
  static UiGuidance? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<UiGuidanceScope>()?.notifier;
}
