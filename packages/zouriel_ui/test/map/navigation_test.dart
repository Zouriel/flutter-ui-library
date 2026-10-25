import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// 0.47.0: the navigation logic, on the web spec's made-up drive in Male: 500 m north, right, 300 m
/// east, left, 200 m north to the end. The same route and numbers as navigation.spec.ts.

const _o = UiLatLng(4.17, 73.51);
const _mLat = 111194.93;
UiLatLng at(double north, double east) => UiLatLng(_o.lat + north / _mLat, _o.lng + east / (_mLat * math.cos(_o.lat * math.pi / 180)));
final route = [at(0, 0), at(250, 0), at(500, 0), at(500, 300), at(700, 300)];
UiNavStep step(String type, String? modifier, UiLatLng loc, double d, double s, String instruction, [String? street]) =>
    UiNavStep(maneuver: UiNavManeuver(type: type, modifier: modifier, location: loc), distanceMeters: d, durationSeconds: s, instruction: instruction, streetName: street);
final steps = [
  step('depart', null, at(0, 0), 500, 60, 'Head north on Majeedhee Magu', 'Majeedhee Magu'),
  step('turn', 'right', at(500, 0), 300, 40, 'Turn right onto Orchid Magu', 'Orchid Magu'),
  step('turn', 'left', at(500, 300), 200, 30, 'Turn left onto Chaandhanee Magu', 'Chaandhanee Magu'),
  step('arrive', null, at(700, 300), 0, 0, 'You have arrived'),
];

/// The point [d] m along the route, [side] m to the right of it.
UiLatLng along(double d, [double side = 0]) {
  if (d <= 500) return at(d, side);
  if (d <= 800) return at(500 - side, d - 500);
  return at(500 + (d - 800), 300 + side);
}

List<({double d, UiNavState state})> drive(UiNavTracker t, {double to = 1000, double every = 10}) {
  final out = <({double d, UiNavState state})>[];
  var i = 0;
  for (var d = 0.0; d <= to; d += every, i++) {
    final p = along(d, ((i % 3) - 1).toDouble());
    out.add((d: d, state: t.update(UiNavPosition(p.lat, p.lng, timestamp: i * 1000, speed: 10))));
  }
  return out;
}

UiNavPosition pos(UiLatLng p, {int t = 0, double? heading, double? speed, double? accuracy}) => UiNavPosition(p.lat, p.lng, timestamp: t, heading: heading, speed: speed, accuracy: accuracy);

void main() {
  group('UiNavTracker (0.47.0)', () {
    test('measures the route and puts each maneuver on it', () {
      final t = UiNavTracker(route, steps);
      expect(t.totalMeters, closeTo(1000, 0.5));
      expect(t.stepAlong.map((x) => x.round()), [0, 500, 800, 1000]);
      expect(uiNavDistance(at(0, 0), at(500, 0)), closeTo(500, 0.5));
      expect(uiNavBearing(at(0, 0), at(10, 0)).round(), 0);
      expect(uiNavBearing(at(0, 0), at(0, 10)).round(), 90);
    });

    test('steps along a drive: the step, the maneuver ahead and the one after, distance to it, what is left', () {
      final states = drive(UiNavTracker(route, steps));
      final byD = {for (final s in states) s.d: s.state};
      final s100 = byD[100]!;
      expect([s100.stepIndex, s100.next?.instruction, s100.nextNext?.instruction], [0, 'Turn right onto Orchid Magu', 'Turn left onto Chaandhanee Magu']);
      expect(s100.distanceToManeuver, closeTo(400, 0.5));
      expect(s100.remainingMeters, closeTo(900, 0.5));
      expect(s100.remainingSeconds, closeTo(60 * 0.8 + 70, 0.5));
      final s600 = byD[600]!;
      expect([s600.stepIndex, s600.next?.maneuver.type, s600.nextNext?.maneuver.type], [1, 'turn', 'arrive']);
      expect(s600.distanceToManeuver, closeTo(200, 0.5));
      final s900 = byD[900]!;
      expect([s900.stepIndex, s900.next?.maneuver.type, s900.nextNext], [2, 'arrive', null]);
      expect(s900.distanceToManeuver, closeTo(100, 0.5));
      final idx = [for (final s in states) s.state.stepIndex];
      for (var i = 1; i < idx.length; i++) {
        expect(idx[i], greaterThanOrEqualTo(idx[i - 1]));
      }
      expect(states.firstWhere((s) => s.state.stepIndex == 1).d, 500);
      expect(states.firstWhere((s) => s.state.stepIndex == 2).d, 800);
      expect(states.map((s) => s.state.distanceFromRoute).reduce(math.max), lessThan(1.5));
      expect(uiNavDistance(s100.display, along(100)), lessThan(0.5));
    });

    test('announces each maneuver once on becoming the next one, and once at 200 m and at 30 m before it', () {
      final states = drive(UiNavTracker(route, steps), every: 5);
      final summary = [
        for (final s in states)
          for (final e in s.state.events.whereType<UiNavAnnounce>()) '${e.stepIndex}:${e.reason.name}${e.threshold?.round() ?? ''}@${s.d.round()}',
      ];
      expect(summary, [
        '1:step@0', '1:distance200@300', '1:distance30@470',
        '2:step@500', '2:distance200@600', '2:distance30@770',
        '3:step@800', '3:distance30@970',
      ]);
      final second = states.expand((s) => s.state.events.whereType<UiNavAnnounce>()).elementAt(1);
      expect(second.step.instruction, 'Turn right onto Orchid Magu');
      expect(second.distanceMeters, lessThanOrEqualTo(200));
    });

    test('a short step: thresholds already passed on becoming the next one are not announced again', () {
      final s2 = [steps[0], step('turn', 'right', at(500, 0), 20, 5, 'Turn right'), step('turn', 'left', at(500, 20), 980, 60, 'Turn left'), step('arrive', null, at(700, 20), 0, 0, 'Arrive')];
      final t = UiNavTracker([at(0, 0), at(500, 0), at(500, 20), at(700, 20)], s2);
      final pts = [for (var i = 0; i <= 50; i++) at(i * 10.0, 0), at(500, 5), at(500, 12), at(500, 18)];
      final ann = [
        for (var i = 0; i < pts.length; i++) ...t.update(pos(pts[i], t: i * 1000)).events.whereType<UiNavAnnounce>(),
      ];
      expect([for (final e in ann.where((e) => e.stepIndex == 2)) '${e.reason.name}${e.threshold?.round() ?? ''}'], ['step']);
    });

    test('off the route for 5 s fires offRoute once, again only after coming back', () {
      final t = UiNavTracker(route, steps);
      t.update(pos(along(100)));
      UiNavState off(double s) => t.update(pos(along(110, 60), t: (s * 1000).round()));
      expect([for (final s in <double>[1, 2, 3, 4, 5.5, 6, 9]) off(s).events.whereType<UiNavOffRoute>().length], [0, 0, 0, 0, 0, 1, 0]);
      expect(off(10).offRoute, isTrue);
      expect(off(11).traveledMeters, closeTo(100, 0.5));
      expect(t.update(pos(along(120), t: 12000)).offRoute, isFalse);
      expect([for (final s in <double>[13, 15, 17.5, 18, 19]) off(s).events.whereType<UiNavOffRoute>().length], [0, 0, 0, 1, 0]);
      final t2 = UiNavTracker(route, steps, options: const UiNavOptions(offRouteSeconds: 0));
      final e = t2.update(pos(along(100, 80))).events.whereType<UiNavOffRoute>().single;
      expect(e.distanceMeters, closeTo(80, 0.5));
    });

    test('a poor fix (accuracy over the threshold) widens what counts as on the route', () {
      final t = UiNavTracker(route, steps, options: const UiNavOptions(offRouteSeconds: 0));
      expect(t.update(pos(along(100, 60), accuracy: 80)).events.whereType<UiNavOffRoute>(), isEmpty);
      expect(t.update(pos(along(100, 60), accuracy: 10, t: 1000)).events.whereType<UiNavOffRoute>(), hasLength(1));
    });

    test('fires arrived once within 20 m of the end, and nothing after it', () {
      final states = drive(UiNavTracker(route, steps), every: 5);
      expect([for (final s in states) if (s.state.events.whereType<UiNavArrived>().isNotEmpty) s.d], [980]);
      expect(states.where((s) => s.d > 980).expand((s) => s.state.events), isEmpty);
      expect(states.last.state.arrived, isTrue);
      expect(states.last.state.remainingSeconds, 0);
    });

    test('does not slide back along a road that doubles back on itself', () {
      final t = UiNavTracker(
        [at(0, 0), at(300, 0), at(300, 100), at(0, 100)],
        [step('depart', null, at(0, 0), 300, 30, 'North'), step('turn', 'uturn', at(300, 0), 400, 30, 'U-turn'), step('arrive', null, at(0, 100), 0, 0, 'Arrive')],
        options: const UiNavOptions(offRouteSeconds: 0),
      );
      for (var d = 0; d <= 250; d += 10) {
        t.update(pos(at(d.toDouble(), 0), t: d * 100));
      }
      expect(t.update(pos(at(100, 100), t: 30000)).traveledMeters, closeTo(600, 0.5));
      final behind = t.update(pos(at(100, 0), t: 31000));
      expect(behind.traveledMeters, closeTo(600, 0.5));
      expect(behind.events.whereType<UiNavOffRoute>(), hasLength(1));
    });

    test('points the map: the heading while moving, else the road', () {
      final t = UiNavTracker(route, steps);
      expect(t.update(pos(along(100), heading: 5, speed: 8)).bearing, 5);
      expect(t.update(pos(along(600), t: 1000)).bearing.round(), 90);
      expect(t.update(pos(along(600), heading: 270, speed: 0.2, t: 2000)).bearing.round(), 90);
      expect(t.update(pos(along(600), heading: -10, t: 3000)).bearing, 350);
    });

    test('splits the route at the person: the way behind and the way ahead meet there', () {
      final t = UiNavTracker(route, steps);
      final sp = t.split(600);
      expect(sp.traveled.take(3), route.take(3));
      expect(uiNavDistance(sp.traveled.last, along(600)), lessThan(0.5));
      expect(sp.remaining.first, sp.traveled.last);
      expect(sp.remaining.skip(1), route.skip(3));
    });
  });

  group('navigation formatting (0.47.0)', () {
    test('distances: 10 m steps under 100 m, 50 m under 1 km, then km', () {
      expect([for (final m in <double>[0, 4, 84, 96, 130, 180, 980, 994, 1000, 2449, 2000, 12400]) uiNavFormatDistance(m)],
          ['0 m', '0 m', '80 m', '100 m', '150 m', '200 m', '1 km', '1 km', '1 km', '2.4 km', '2 km', '12 km']);
      expect(uiNavFormatDistance(80, UiStrings.dv), '80 މީޓަރު');
      expect(uiNavFormatDistance(2500, UiStrings.dv), '2.5 ކިލޯމީޓަރު');
    });

    test('times: minutes rounded up, hours from 60', () {
      expect([for (final s in <double>[0, 1, 60, 61, 59 * 60, 3600, 3900, 7200]) uiNavFormatDuration(s)], ['0 min', '1 min', '1 min', '2 min', '59 min', '1 h', '1 h 5 min', '2 h']);
      expect(uiNavFormatDuration(300, UiStrings.dv), '5 މިނެޓު');
      expect(uiNavFormatClock(DateTime(2026, 10, 25, 9, 5)), '09:05');
      expect(const UiStrings().navIn.replaceAll('{distance}', '80 m'), 'in 80 m');
    });
  });

  group('maneuver icons (0.47.0)', () {
    String k(String type, [String? modifier, String? side]) => uiNavIconKind(UiNavManeuver(type: type, modifier: modifier, location: _o, drivingSide: side)).webName;

    test('picks a drawing for every OSRM type and modifier (the web names)', () {
      expect([k('depart'), k('arrive', 'left'), k('turn', 'left'), k('turn', 'right'), k('turn', 'slight left'), k('turn', 'sharp right'), k('continue'), k('new name', 'straight')],
          ['depart', 'arrive', 'left', 'right', 'slight-left', 'sharp-right', 'straight', 'straight']);
      expect([k('roundabout', 'right'), k('rotary', 'slight left'), k('roundabout turn', 'straight'), k('exit roundabout', 'sharp left'), k('roundabout', 'uturn')],
          ['roundabout-right', 'roundabout-slight-left', 'roundabout-straight', 'roundabout-sharp-left', 'roundabout-uturn']);
      expect([k('fork', 'slight left'), k('fork', 'right'), k('merge', 'slight left'), k('merge', 'slight right'), k('on ramp', 'left'), k('off ramp', 'slight right'), k('off ramp')],
          ['fork-left', 'fork-right', 'merge-left', 'merge-right', 'slight-left', 'slight-right', 'straight']);
      expect([k('turn', 'uturn'), k('turn', 'uturn', 'left'), k('end of road', 'left'), k('notification', 'right'), k('something new')], ['uturn-left', 'uturn-right', 'left', 'right', 'straight']);
    });

    test('every drawing is stroked in the current colour on the 24 grid; one per kind', () {
      expect(uiNavIcons.keys.toSet(), UiNavIconKind.values.toSet());
      for (final MapEntry(:key, :value) in uiNavIcons.entries) {
        expect(value, isNotEmpty, reason: key.webName);
        for (final el in value) {
          final attrs = el[1] as Map<String, dynamic>;
          expect(attrs['stroke'], 'currentColor', reason: key.webName);
          for (final n in RegExp(r'-?\d+(\.\d+)?').allMatches('${attrs['d'] ?? ''}')) {
            expect(double.parse(n.group(0)!).abs(), lessThanOrEqualTo(24), reason: key.webName);
          }
        }
      }
    });
  });

  group('maneuver words: OSRM spaced and snake_case (0.47.1)', () {
    test('uiNavWord puts every spelling in OSRM\'s spaced form', () {
      expect(['sharp_right', 'SHARP_RIGHT', 'sharp-right', 'sharp right', ' sharp  right ', 'sharp__right'].map(uiNavWord), List.filled(6, 'sharp right'));
      expect([uiNavWord('end_of_road'), uiNavWord('exit_roundabout'), uiNavWord(null), uiNavWord('u_turn')], ['end of road', 'exit roundabout', '', 'u turn']);
    });

    test('every type and modifier picks the same drawing in either form', () {
      const types = ['depart', 'arrive', 'turn', 'continue', 'new name', 'merge', 'on ramp', 'off ramp', 'fork', 'end of road', 'roundabout', 'rotary', 'roundabout turn', 'exit roundabout', 'exit rotary', 'notification'];
      const mods = <String?>[null, 'uturn', 'sharp right', 'right', 'slight right', 'straight', 'slight left', 'left', 'sharp left'];
      String? snake(String? w) => w?.replaceAll(' ', '_');
      var checked = 0;
      for (final type in types) {
        for (final modifier in mods) {
          for (final side in ['left', 'right']) {
            final spaced = uiNavIconKind(UiNavManeuver(type: type, modifier: modifier, location: at(0, 0), drivingSide: side));
            expect(uiNavIconKind(UiNavManeuver(type: snake(type)!, modifier: snake(modifier), location: at(0, 0), drivingSide: side)), spaced, reason: '$type/$modifier');
            expect(uiNavIconKind(UiNavManeuver(type: snake(type)!.toUpperCase(), modifier: snake(modifier)?.toUpperCase(), location: at(0, 0), drivingSide: side)), spaced,
                reason: '$type/$modifier upper');
            checked++;
          }
        }
      }
      expect(checked, types.length * mods.length * 2);
      String k(String type, [String? modifier]) => uiNavIconKind(UiNavManeuver(type: type, modifier: modifier, location: at(0, 0))).webName;
      expect([k('turn', 'sharp_right'), k('turn', 'slight_left'), k('end_of_road', 'left'), k('roundabout', 'sharp_left'), k('exit_roundabout', 'slight_right'),
        k('on_ramp', 'slight_right'), k('off_ramp', 'left'), k('roundabout_turn', 'right'), k('fork', 'slight_left'), k('turn', 'u_turn')],
          ['sharp-right', 'slight-left', 'left', 'roundabout-sharp-left', 'roundabout-slight-right', 'slight-right', 'slight-left', 'roundabout-right', 'fork-left', 'uturn-left']);
    });

    test('the tracker gives the same drive with snake_case steps', () {
      UiNavStep with_(UiNavStep x, String type, String? modifier) => UiNavStep(
          maneuver: UiNavManeuver(type: type, modifier: modifier, location: x.maneuver.location), distanceMeters: x.distanceMeters, durationSeconds: x.durationSeconds, instruction: x.instruction, streetName: x.streetName);
      final spaced = [for (final (i, x) in steps.indexed) i == 1 ? with_(x, 'end of road', 'sharp right') : x];
      final snake = [for (final x in spaced) with_(x, x.maneuver.type.replaceAll(' ', '_'), x.maneuver.modifier?.replaceAll(' ', '_'))];
      final a = drive(UiNavTracker(route, spaced)), b = drive(UiNavTracker(route, snake));
      String sig(UiNavState s) => '${s.stepIndex} ${s.distanceToManeuver.toStringAsFixed(3)} ${s.remainingSeconds.toStringAsFixed(3)} ${s.next?.instruction} ${s.events.map((e) => e.runtimeType).join(',')}';
      expect(b.map((r) => sig(r.state)), a.map((r) => sig(r.state)));
      expect(uiNavIconKind(b.first.state.next!.maneuver), UiNavIconKind.sharpRight);
    });
  });

  group('uiNavFitWords (0.47.2)', () {
    // Greedy word wrap: whole words, a word longer than the line takes lines of its own.
    bool Function(String) lines(int perLine, [int max = 2]) => (s) {
          var n = 1, used = 0;
          for (final w in s.split(' ')) {
            final need = used > 0 ? used + 1 + w.length : w.length;
            if (need <= perLine) {
              used = need;
            } else {
              n += used > 0 ? 1 : 0;
              used = w.length;
              n += math.max(0, (w.length / perLine).ceil() - 1);
            }
          }
          return n <= max;
        };
    test('the whole text when it fits; else whole words and an ellipsis, the most that fit', () {
      expect(uiNavFitWords('Rerouting…', lines(20)), 'Rerouting…');
      expect(uiNavFitWords('  Rerouting   now ', lines(20)), 'Rerouting now');
      final out = uiNavFitWords('Rerouting around the closed road near the harbour', lines(20));
      expect(out, 'Rerouting around the closed road near…');
      expect(lines(20)(out), isTrue);
    });
    test('drops a comma or colon before the ellipsis; Thaana words cut the same way', () {
      expect(uiNavFitWords('Rerouting, closed road, harbour ahead, please wait for it', lines(12)), 'Rerouting, closed road…');
      const dv = 'އަލުން މަގު ހޯދަނީ، ބަނދަރު ކައިރީގައި މަގު ބަންދުކޮށްފައި';
      final cut = uiNavFitWords(dv, lines(16));
      expect(cut.endsWith('…'), isTrue);
      expect(dv.startsWith(cut.substring(0, cut.length - 1)), isTrue);
      expect(cut.substring(cut.length - 2, cut.length - 1), isNot('،'));
      expect(' ،'.contains(dv[cut.length - 1]), isTrue);
    });
    test('a first word longer than the space: the text as it is (the pill\'s own ellipsis cuts it)', () {
      expect(uiNavFitWords('Supercalifragilisticexpialidocious', (_) => false), 'Supercalifragilisticexpialidocious');
      expect(uiNavFitWords('', (_) => false), '');
    });
  });
}
