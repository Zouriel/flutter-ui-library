import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

import '../core/icon.dart';
import '../theme/strings.dart';
import 'map.dart';

// 0.47.0: turn-by-turn navigation logic, pure and testable, the same as the web twin's
// `navigation.ts`. The app feeds the route (OSRM geometry and steps) and live positions; this works
// out where on the route the person is, the step they are on, the distance to the next maneuver,
// what is left, and when to announce, when they are off the route and when they arrived. The app
// speaks and reroutes.

/// A maneuver, as OSRM gives it (`step.maneuver`, the web `UiNavManeuver`): [type] and [modifier]
/// keep OSRM's words.
@immutable
class UiNavManeuver {
  const UiNavManeuver({required this.type, this.modifier, required this.location, this.bearingAfter, this.exit, this.drivingSide});

  /// 'depart', 'turn', 'continue', 'new name', 'merge', 'on ramp', 'off ramp', 'fork', 'end of road',
  /// 'roundabout', 'rotary', 'roundabout turn', 'exit roundabout', 'notification', 'arrive', ...
  /// (snake_case 'end_of_road' works too, 0.47.1)
  final String type;

  /// 'uturn', 'sharp right', 'right', 'slight right', 'straight', 'slight left', 'left', 'sharp left'
  /// (or 'sharp_right', 0.47.1).
  final String? modifier;

  /// Where it happens (OSRM's `location` is [lng, lat]: swap it).
  final UiLatLng location;

  /// The heading after it, degrees clockwise from north.
  final double? bearingAfter;

  /// The roundabout exit to take (OSRM `maneuver.exit`), shown on the icon.
  final int? exit;

  /// Which side traffic keeps to (OSRM `driving_side`, 'left' or 'right'): turns a U-turn's arrow
  /// the right way. 'right' when null.
  final String? drivingSide;
}

/// One step of the route (OSRM `route.legs[].steps[]`, the web `UiNavStep`), with the app's already
/// localized words.
@immutable
class UiNavStep {
  const UiNavStep({required this.maneuver, required this.distanceMeters, required this.durationSeconds, required this.instruction, this.streetName});
  final UiNavManeuver maneuver;

  /// From this maneuver to the next, in metres.
  final double distanceMeters;

  /// From this maneuver to the next, in seconds.
  final double durationSeconds;

  /// What to do at this maneuver, in the app's language: "Turn left onto Majeedhee Magu".
  final String instruction;

  /// The street after it, shown under the instruction.
  final String? streetName;
}

/// Where the person is, from the app's own geolocation (the web `UiNavPosition`).
@immutable
class UiNavPosition {
  const UiNavPosition(this.lat, this.lng, {this.heading, this.speed, this.accuracy, this.timestamp});
  final double lat;
  final double lng;

  /// Direction of travel, degrees clockwise from north.
  final double? heading;

  /// Metres per second.
  final double? speed;

  /// Metres.
  final double? accuracy;

  /// When it was measured, ms since the epoch; now when null.
  final int? timestamp;

  UiLatLng get latLng => UiLatLng(lat, lng);
}

/// Tuning for [UiNavTracker] (the web `UiNavOptions`).
@immutable
class UiNavOptions {
  const UiNavOptions({this.offRouteMeters = uiNavOffRouteMeters, this.offRouteSeconds = uiNavOffRouteSeconds, this.arriveMeters = uiNavArriveMeters, this.announceMeters = uiNavAnnounceMeters});

  /// Further than this from the route (or the position's accuracy, if bigger) counts as off it; 40 m.
  final double offRouteMeters;

  /// Off the route this long before an off-route event; 5 s.
  final double offRouteSeconds;

  /// This close to the end counts as arrived; 20 m.
  final double arriveMeters;

  /// Distances before a maneuver that each fire one announcement; [200, 30].
  final List<double> announceMeters;
}

const double uiNavOffRouteMeters = 40;
const double uiNavOffRouteSeconds = 5;
const double uiNavArriveMeters = 20;
const List<double> uiNavAnnounceMeters = [200, 30];

/// Why an announcement fires (the web `reason`).
enum UiNavAnnounceReason { step, distance }

/// Something the app may act on, from one [UiNavTracker.update] (the web `UiNavEvent`).
@immutable
sealed class UiNavEvent {
  const UiNavEvent();
}

/// Time to speak: [UiNavAnnounceReason.step] when a new maneuver becomes the next one (and at the
/// start), [UiNavAnnounceReason.distance] when it comes within one of the announce distances
/// ([threshold]). Each fires once per step.
class UiNavAnnounce extends UiNavEvent {
  const UiNavAnnounce({required this.reason, required this.stepIndex, required this.step, required this.distanceMeters, this.threshold});
  final UiNavAnnounceReason reason;
  final int stepIndex;
  final UiNavStep step;
  final double distanceMeters;
  final double? threshold;
}

/// Off the route for the off-route time: reroute. Fires again only after coming back to the route.
class UiNavOffRoute extends UiNavEvent {
  const UiNavOffRoute({required this.distanceMeters, required this.position});
  final double distanceMeters;
  final UiNavPosition position;
}

/// Within the arrival distance of the end. Once.
class UiNavArrived extends UiNavEvent {
  const UiNavArrived();
}

/// Where the person is on the route, after an update (the web `UiNavState`).
@immutable
class UiNavState {
  const UiNavState({
    required this.snapped,
    required this.display,
    required this.distanceFromRoute,
    required this.traveledMeters,
    required this.segmentIndex,
    required this.stepIndex,
    required this.next,
    required this.nextNext,
    required this.distanceToManeuver,
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.bearing,
    required this.offRoute,
    required this.arrived,
    required this.events,
  });

  /// The position put on the route (the nearest point of it).
  final UiLatLng snapped;

  /// Where to draw the person: on the route while on it, else where they are.
  final UiLatLng display;
  final double distanceFromRoute;

  /// Metres along the route from its start to [snapped].
  final double traveledMeters;
  final int segmentIndex;

  /// The step being driven (its maneuver is behind).
  final int stepIndex;

  /// The maneuver ahead, or null past the last one.
  final UiNavStep? next;

  /// The one after that, or null.
  final UiNavStep? nextNext;
  final double distanceToManeuver;
  final double remainingMeters;
  final double remainingSeconds;

  /// The way to point the map, degrees clockwise from north: the heading while moving, else the road's.
  final double bearing;
  final bool offRoute;
  final bool arrived;

  /// What happened in this update.
  final List<UiNavEvent> events;
}

const double _r = 6371000;
const double _rad = math.pi / 180;

/// Great-circle metres between two points (the web `uiNavDistance`).
double uiNavDistance(UiLatLng a, UiLatLng b) {
  final dLat = (b.lat - a.lat) * _rad;
  final dLng = (b.lng - a.lng) * _rad;
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(a.lat * _rad) * math.cos(b.lat * _rad) * math.pow(math.sin(dLng / 2), 2);
  return 2 * _r * math.asin(math.min(1, math.sqrt(h)));
}

/// The compass bearing from [a] to [b], degrees clockwise from north in 0..360 (the web `uiNavBearing`).
double uiNavBearing(UiLatLng a, UiLatLng b) {
  final y = math.sin((b.lng - a.lng) * _rad) * math.cos(b.lat * _rad);
  final x = math.cos(a.lat * _rad) * math.sin(b.lat * _rad) - math.sin(a.lat * _rad) * math.cos(b.lat * _rad) * math.cos((b.lng - a.lng) * _rad);
  return ((math.atan2(y, x) / _rad) % 360 + 360) % 360;
}

class _Snap {
  const _Snap(this.i, this.t, this.along, this.dist);
  final int i;
  final double t;
  final double along;
  final double dist;
}

/// Follows a person along a route (0.47.0, the web `UiNavTracker`). Make one per route (a reroute is
/// a new tracker) and call [update] with each position; it returns the state and the events of
/// that update. Pure: no timers, the clock is the positions' timestamp.
///
/// Positions snap to the nearest point of the route at or past the last one (less 50 m), so a road
/// that doubles back doesn't pull the person backwards; going back further is being off the route.
class UiNavTracker {
  UiNavTracker(List<UiLatLng> route, this.steps, {this.options = const UiNavOptions()}) : points = List.unmodifiable(route) {
    final o = points.isEmpty ? const UiLatLng(0, 0) : points.first;
    _o = o;
    _kx = math.cos(o.lat * _rad);
    _xy = [for (final p in points) _local(p)];
    _cum = [0];
    for (var i = 1; i < _xy.length; i++) {
      _cum.add(_cum[i - 1] + math.sqrt(math.pow(_xy[i].$1 - _xy[i - 1].$1, 2) + math.pow(_xy[i].$2 - _xy[i - 1].$2, 2)));
    }
    totalMeters = _cum.isEmpty ? 0 : _cum.last;
    _announce = [...options.announceMeters]..sort((a, b) => b.compareTo(a));
    var from = 0.0;
    for (final s in steps) {
      final snap = _snap(s.maneuver.location, from);
      stepAlong.add(snap?.along ?? from);
      if (snap != null) from = snap.along;
    }
    if (stepAlong.isNotEmpty) stepAlong[0] = 0;
  }

  final List<UiLatLng> points;
  final List<UiNavStep> steps;
  final UiNavOptions options;
  late final double totalMeters;

  /// Metres along the route at each step's maneuver.
  final List<double> stepAlong = [];
  late final UiLatLng _o;
  late final double _kx;
  late final List<(double, double)> _xy;
  late final List<double> _cum;
  late final List<double> _announce;
  UiNavState? _last;
  double _lastAlong = 0;
  int _announcedStep = -1;
  Set<double> _fired = {};
  int? _offSince;
  bool _offFired = false;
  bool _arrivedFired = false;

  /// The state after the last [update], or null before the first.
  UiNavState? get state => _last;

  (double, double) _local(UiLatLng p) => ((p.lng - _o.lng) * _rad * _r * _kx, (p.lat - _o.lat) * _rad * _r);

  _Snap? _snap(UiLatLng p, double fromAlong) {
    final n = _xy.length;
    if (n == 0) return null;
    final (px, py) = _local(p);
    if (n == 1) return _Snap(0, 0, 0, math.sqrt(math.pow(px - _xy[0].$1, 2) + math.pow(py - _xy[0].$2, 2)));
    _Snap? best;
    for (var i = 0; i < n - 1; i++) {
      if (_cum[i + 1] < fromAlong) continue;
      final (ax, ay) = _xy[i];
      final (bx, by) = _xy[i + 1];
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      var t = len2 > 0 ? ((px - ax) * dx + (py - ay) * dy) / len2 : 0.0;
      t = t.clamp(0.0, 1.0);
      final along = _cum[i] + t * (_cum[i + 1] - _cum[i]);
      if (along < fromAlong) t = _cum[i + 1] > _cum[i] ? (fromAlong - _cum[i]) / (_cum[i + 1] - _cum[i]) : 0;
      final qx = ax + t * dx, qy = ay + t * dy;
      final dist = math.sqrt(math.pow(px - qx, 2) + math.pow(py - qy, 2));
      // Strictly nearer wins, so the earliest of equally near points is kept.
      if (best == null || dist < best.dist - 1e-9) best = _Snap(i, t, math.max(along, fromAlong), dist);
    }
    return best;
  }

  /// The point [along] metres from the start, and the segment it is on.
  ({UiLatLng point, int segment}) pointAt(double along) {
    final n = points.length;
    if (n < 2) return (point: n == 0 ? const UiLatLng(0, 0) : points.first, segment: 0);
    final a = along.clamp(0.0, totalMeters);
    var i = 0;
    while (i < n - 2 && _cum[i + 1] < a) {
      i++;
    }
    final seg = _cum[i + 1] - _cum[i];
    final t = seg > 0 ? (a - _cum[i]) / seg : 0.0;
    final p = points[i], q = points[i + 1];
    return (point: UiLatLng(p.lat + (q.lat - p.lat) * t, p.lng + (q.lng - p.lng) * t), segment: i);
  }

  /// The route from its start to [along] metres (travelled) and from there to its end (to go).
  ({List<UiLatLng> traveled, List<UiLatLng> remaining}) split(double along) {
    final at = pointAt(along);
    return (traveled: [...points.take(at.segment + 1), at.point], remaining: [at.point, ...points.skip(at.segment + 1)]);
  }

  /// Takes a position: where it is on the route, what is next, and what happened.
  UiNavState update(UiNavPosition position) {
    final now = position.timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final o = options;
    final events = <UiNavEvent>[];
    final snap = _snap(position.latLng, math.max(0, _lastAlong - 50)) ?? const _Snap(0, 0, 0, 0);
    final limit = math.max(o.offRouteMeters, position.accuracy ?? 0);
    final on = snap.dist <= limit;
    // Progress only moves on while on the route; off it, the last place on it holds.
    final along = on ? math.max(snap.along, _lastAlong) : _lastAlong;
    if (on) _lastAlong = along;
    final at = pointAt(along);

    var stepIndex = 0;
    for (var k = 0; k < stepAlong.length; k++) {
      if (stepAlong[k] <= along + 1e-6) stepIndex = k;
    }
    // Past the arrive maneuver's place there is nothing ahead: stay on the step before it.
    if (steps.length > 1 && stepIndex == steps.length - 1) stepIndex = steps.length - 2;
    final next = stepIndex + 1 < steps.length ? steps[stepIndex + 1] : null;
    final nextNext = stepIndex + 2 < steps.length ? steps[stepIndex + 2] : null;
    final nextAlong = next != null ? stepAlong[stepIndex + 1] : totalMeters;
    final distanceToManeuver = math.max(0.0, nextAlong - along);
    final remainingMeters = math.max(0.0, totalMeters - along);
    var remainingSeconds = 0.0;
    if (steps.isNotEmpty) {
      final s = steps[stepIndex];
      final span = nextAlong - stepAlong[stepIndex];
      final left = span > 0 ? ((nextAlong - along) / span).clamp(0.0, 1.0) : 0.0;
      remainingSeconds = s.durationSeconds * left;
      for (var k = stepIndex + 1; k < steps.length; k++) {
        remainingSeconds += steps[k].durationSeconds;
      }
    }

    // Arrived: near the end, on the route or straight there.
    final end = points.isEmpty ? null : points.last;
    final arrivedNow = end != null && (uiNavDistance(position.latLng, end) <= o.arriveMeters || (on && remainingMeters <= o.arriveMeters));
    if (arrivedNow && !_arrivedFired) {
      _arrivedFired = true;
      events.add(const UiNavArrived());
    }

    // Announcements, for the maneuver ahead.
    if (next != null && !_arrivedFired) {
      if (_announcedStep != stepIndex + 1) {
        _announcedStep = stepIndex + 1;
        _fired = {for (final t in _announce) if (distanceToManeuver <= t) t};
        events.add(UiNavAnnounce(reason: UiNavAnnounceReason.step, stepIndex: stepIndex + 1, step: next, distanceMeters: distanceToManeuver));
      } else if (on) {
        for (final t in _announce) {
          if (distanceToManeuver <= t && !_fired.contains(t)) {
            _fired.addAll(_announce.where((u) => u >= t));
            events.add(UiNavAnnounce(reason: UiNavAnnounceReason.distance, stepIndex: stepIndex + 1, step: next, distanceMeters: distanceToManeuver, threshold: t));
          }
        }
      }
    }

    // Off the route for long enough: once, until back on it.
    if (on) {
      _offSince = null;
      _offFired = false;
    } else if (!_arrivedFired) {
      _offSince ??= now;
      if (!_offFired && now - _offSince! >= o.offRouteSeconds * 1000) {
        _offFired = true;
        events.add(UiNavOffRoute(distanceMeters: snap.dist, position: position));
      }
    }

    // Heading-up: the direction of travel while moving, else the road's.
    var bearing = _last?.bearing ?? 0.0;
    final h = position.heading;
    final moving = h != null && (position.speed == null || position.speed! >= 1);
    if (moving) {
      bearing = (h % 360 + 360) % 360;
    } else if (on && points.length > 1) {
      bearing = uiNavBearing(points[at.segment], points[math.min(points.length - 1, at.segment + 1)]);
    }

    final state = UiNavState(
      snapped: at.point,
      display: on ? at.point : position.latLng,
      distanceFromRoute: snap.dist,
      traveledMeters: along,
      segmentIndex: at.segment,
      stepIndex: stepIndex,
      next: next,
      nextNext: nextNext,
      distanceToManeuver: distanceToManeuver,
      remainingMeters: remainingMeters,
      remainingSeconds: remainingSeconds,
      bearing: bearing,
      offRoute: _offFired,
      arrived: _arrivedFired,
      events: List.unmodifiable(events),
    );
    _last = state;
    return state;
  }
}

String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// A distance to say or show (0.47.0, the web `uiNavFormatDistance`): under 100 m to the nearest
/// 10 m, under 1 km to the nearest 50 m, under 10 km in km with one decimal ("2.5 km", "2 km"), then
/// whole km. Units from [UiStrings.navMeters] / [UiStrings.navKilometers].
String uiNavFormatDistance(double m, [UiStrings strings = const UiStrings()]) {
  final v = math.max(0.0, m);
  if (v < 1000) {
    final r = v < 100 ? (v / 10).round() * 10 : (v / 50).round() * 50;
    if (r < 1000) return strings.navMeters.replaceAll('{n}', '$r');
  }
  final km = v < 9950 ? _num((v / 100).round() / 10) : '${(v / 1000).round()}';
  return strings.navKilometers.replaceAll('{n}', km);
}

/// A time left (0.47.0, the web `uiNavFormatDuration`): whole minutes rounded up ("1 min" for any
/// part of one, "0 min" at none), and from an hour "1 h 5 min" / "2 h".
String uiNavFormatDuration(double seconds, [UiStrings strings = const UiStrings()]) {
  final min = math.max(0, (seconds / 60 - 1e-9).ceil());
  if (min < 60) return strings.navMinutes.replaceAll('{min}', '$min');
  final h = min ~/ 60, m = min % 60;
  return m != 0 ? strings.navHoursMinutes.replaceAll('{h}', '$h').replaceAll('{min}', '$m') : strings.navHours.replaceAll('{h}', '$h');
}

/// A clock time, 24-hour "14:05" (0.47.0, the web `uiNavFormatClock`): the default arrival time format.
String uiNavFormatClock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// The drawings the maneuver icons come in (the web `UiNavIconKind`).
enum UiNavIconKind {
  depart('depart'),
  arrive('arrive'),
  straight('straight'),
  slightLeft('slight-left'),
  slightRight('slight-right'),
  left('left'),
  right('right'),
  sharpLeft('sharp-left'),
  sharpRight('sharp-right'),
  uturnLeft('uturn-left'),
  uturnRight('uturn-right'),
  roundaboutStraight('roundabout-straight'),
  roundaboutSlightLeft('roundabout-slight-left'),
  roundaboutSlightRight('roundabout-slight-right'),
  roundaboutLeft('roundabout-left'),
  roundaboutRight('roundabout-right'),
  roundaboutSharpLeft('roundabout-sharp-left'),
  roundaboutSharpRight('roundabout-sharp-right'),
  roundaboutUturn('roundabout-uturn'),
  forkLeft('fork-left'),
  forkRight('fork-right'),
  mergeLeft('merge-left'),
  mergeRight('merge-right');

  const UiNavIconKind(this.webName);

  /// The web twin's name for it ('slight-left').
  final String webName;

  bool get isRoundabout => name.startsWith('roundabout');

  static UiNavIconKind byWebName(String n) => values.firstWhere((k) => k.webName == n);
}

/// A maneuver word in OSRM's spaced form (0.47.1, the web `uiNavWord`): lower case, with underscores
/// and hyphens as spaces, so 'sharp_right', 'END_OF_ROAD', 'sharp-right' and 'sharp right' are the same.
String uiNavWord(String? word) => (word ?? '').toLowerCase().replaceAll(RegExp(r'[_-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

String _dirOf(String? modifier) => switch (uiNavWord(modifier)) {
      'uturn' || 'u turn' => 'uturn',
      'sharp right' => 'sharp-right',
      'right' => 'right',
      'slight right' => 'slight-right',
      'slight left' => 'slight-left',
      'left' => 'left',
      'sharp left' => 'sharp-left',
      _ => 'straight',
    };

/// Which drawing a maneuver gets (0.47.0, the web `uiNavIconKind`): roundabouts and rotaries by
/// their exit's direction, forks and merges by side, ramps as slight turns, depart and arrive their
/// own, everything else by its modifier. A U-turn bends left where traffic keeps right and right
/// where it keeps left. Never mirrored for right-to-left text: left means left. Type and modifier may
/// be OSRM's spaced words ('end of road', 'sharp right') or snake_case ('end_of_road', 'sharp_right'), 0.47.1.
UiNavIconKind uiNavIconKind(UiNavManeuver m) {
  final type = uiNavWord(m.type);
  final dir = _dirOf(m.modifier);
  final side = uiNavWord(m.modifier).contains('left') ? 'left' : 'right';
  final name = switch (type) {
    'depart' => 'depart',
    'arrive' => 'arrive',
    'roundabout' || 'rotary' || 'roundabout turn' || 'exit roundabout' || 'exit rotary' => 'roundabout-$dir',
    'fork' => 'fork-$side',
    'merge' => 'merge-$side',
    'on ramp' || 'off ramp' => dir == 'straight' ? 'straight' : 'slight-$side',
    _ => dir == 'uturn' ? (m.drivingSide == 'left' ? 'uturn-right' : 'uturn-left') : dir,
  };
  return UiNavIconKind.byWebName(name);
}

List<dynamic> _line(String d, [Map<String, dynamic> extra = const {}]) =>
    ['path', {'d': d, 'stroke': 'currentColor', 'strokeLinecap': 'round', 'strokeLinejoin': 'round', 'strokeWidth': '2', ...extra}];
List<dynamic> _ring(num cx, num cy, num r) => ['circle', {'cx': '$cx', 'cy': '$cy', 'r': '$r', 'stroke': 'currentColor', 'strokeWidth': '2'}];
const _faint = {'opacity': '0.4'};

/// The maneuver drawings (0.47.0), in hugeicons' format on a 24px grid, stroked in the current
/// colour: the same data as the web twin's `UI_NAV_ICONS`, drawn with [UiIcon]. Hugeicons has no
/// maneuver set (no roundabout exits, slight or sharp turns), so these are the library's own.
final Map<UiNavIconKind, UiIconData> uiNavIcons = {
  UiNavIconKind.depart: [_ring(12, 18.5, 2), _line('M12 16.5V4'), _line('M7 9L12 4L17 9')],
  UiNavIconKind.arrive: [_line('M12 21C12 21 19 15.5 19 10C19 6.13 15.87 3 12 3C8.13 3 5 6.13 5 10C5 15.5 12 21 12 21Z'), _ring(12, 10, 2.5)],
  UiNavIconKind.straight: [_line('M12 20V4'), _line('M7 9L12 4L17 9')],
  UiNavIconKind.right: [_line('M7 20V13C7 10.79 8.79 9 11 9H19'), _line('M15 5L19 9L15 13')],
  UiNavIconKind.left: [_line('M17 20V13C17 10.79 15.21 9 13 9H5'), _line('M9 5L5 9L9 13')],
  UiNavIconKind.slightRight: [_line('M9 20V14.83C9 13.77 9.42 12.75 10.17 12L17 5.17'), _line('M11.5 5H17V10.5')],
  UiNavIconKind.slightLeft: [_line('M15 20V14.83C15 13.77 14.58 12.75 13.83 12L7 5.17'), _line('M12.5 5H7V10.5')],
  UiNavIconKind.sharpRight: [_line('M8 20V7L17 16'), _line('M17 10.5V16H11.5')],
  UiNavIconKind.sharpLeft: [_line('M16 20V7L7 16'), _line('M7 10.5V16H12.5')],
  UiNavIconKind.uturnLeft: [_line('M16 20V10C16 7.79 14.21 6 12 6C9.79 6 8 7.79 8 10V17'), _line('M5 14L8 17L11 14')],
  UiNavIconKind.uturnRight: [_line('M8 20V10C8 7.79 9.79 6 12 6C14.21 6 16 7.79 16 10V17'), _line('M19 14L16 17L13 14')],
  UiNavIconKind.roundaboutStraight: [_ring(12, 11, 3.5), _line('M12 21V14.5'), _line('M12 7.5V3'), _line('M9 6L12 3L15 6')],
  UiNavIconKind.roundaboutRight: [_ring(12, 11, 3.5), _line('M12 21V14.5'), _line('M15.5 11H21'), _line('M18 8L21 11L18 14')],
  UiNavIconKind.roundaboutLeft: [_ring(12, 11, 3.5), _line('M12 21V14.5'), _line('M8.5 11H3'), _line('M6 8L3 11L6 14')],
  UiNavIconKind.roundaboutSlightRight: [_ring(12, 11, 3.5), _line('M12 21V14.5'), _line('M14.47 8.53L19 4'), _line('M14.5 4H19V8.5')],
  UiNavIconKind.roundaboutSlightLeft: [_ring(12, 11, 3.5), _line('M12 21V14.5'), _line('M9.53 8.53L5 4'), _line('M9.5 4H5V8.5')],
  UiNavIconKind.roundaboutSharpRight: [_ring(12, 11, 3.5), _line('M12 21V14.5'), _line('M14.47 13.47L19 18'), _line('M19 13.5V18H14.5')],
  UiNavIconKind.roundaboutSharpLeft: [_ring(12, 11, 3.5), _line('M12 21V14.5'), _line('M9.53 13.47L5 18'), _line('M5 13.5V18H9.5')],
  UiNavIconKind.roundaboutUturn: [_ring(12, 11, 3.5), _line('M12 21V14.5'), _line('M8.5 11V20'), _line('M5.5 17L8.5 20L11.5 17')],
  UiNavIconKind.forkLeft: [_line('M12 21V14'), _line('M12 14L7 7'), _line('M7 12V7H12'), _line('M12 14L17 7', _faint)],
  UiNavIconKind.forkRight: [_line('M12 21V14'), _line('M12 14L17 7'), _line('M12 7H17V12'), _line('M12 14L7 7', _faint)],
  UiNavIconKind.mergeLeft: [_line('M12 12V3'), _line('M9 6L12 3L15 6'), _line('M17 21V18C17 15.24 12 14.76 12 12'), _line('M7 21V18C7 15.24 12 14.76 12 12', _faint)],
  UiNavIconKind.mergeRight: [_line('M12 12V3'), _line('M9 6L12 3L15 6'), _line('M7 21V18C7 15.24 12 14.76 12 12'), _line('M17 21V18C17 15.24 12 14.76 12 12', _faint)],
};

/// The drawing for a maneuver (0.47.0, the web `uiNavIcon`).
UiIconData uiNavIcon(UiNavManeuver m) => uiNavIcons[uiNavIconKind(m)]!;
