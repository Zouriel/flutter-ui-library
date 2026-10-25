import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// The showcase's simulated drive (0.47.0): a real road route across Male (OSRM, 1.3 km, the Routes
/// demo's) with steps made from its turns, as an app would get them from OSRM, in English or
/// Dhivehi. The same route and steps as the web showcase's nav-demo.ts.
const navDemoRoute = [
  UiLatLng(4.17682, 73.5121), UiLatLng(4.17678, 73.51237), UiLatLng(4.17708, 73.51244), UiLatLng(4.17709, 73.51223), UiLatLng(4.17716, 73.51216),
  UiLatLng(4.17773, 73.51224), UiLatLng(4.17785, 73.51146), UiLatLng(4.1769, 73.51136), UiLatLng(4.1771, 73.50974), UiLatLng(4.17284, 73.50825),
  UiLatLng(4.17311, 73.50751), UiLatLng(4.1732, 73.50755), UiLatLng(4.17344, 73.50696), UiLatLng(4.17388, 73.50715), UiLatLng(4.17387, 73.50721),
];

const _streets = ['Majeedhee Magu', 'Orchid Magu', 'Chaandhanee Magu', 'Fareedhee Magu', 'Boduthakurufaanu Magu', 'Ameenee Magu', 'Sosun Magu'];
const _streetsDv = ['މަޖީދީ މަގު', 'އޯކިޑް މަގު', 'ޗާނދަނީ މަގު', 'ފަރީދީ މަގު', 'ބޮޑުތަކުރުފާނު މަގު', 'އަމީނީ މަގު', 'ސޮސަން މަގު'];
const _words = {
  'slight right': ('Keep slightly right onto {s}', 'ކުޑަކޮށް ކަނާތަށް، {s}'),
  'slight left': ('Keep slightly left onto {s}', 'ކުޑަކޮށް ވާތަށް، {s}'),
  'right': ('Turn right onto {s}', 'ކަނާތަށް އެނބުރި {s}'),
  'left': ('Turn left onto {s}', 'ވާތަށް އެނބުރި {s}'),
  'sharp right': ('Turn sharp right onto {s}', 'ވަރަށް ކަނާތަށް އެނބުރި {s}'),
  'sharp left': ('Turn sharp left onto {s}', 'ވަރަށް ވާތަށް އެނބުރި {s}'),
};

String? _modifier(double turn) {
  final a = turn.abs();
  if (a < 30) return null;
  final side = turn > 0 ? 'right' : 'left';
  return a < 60 ? 'slight $side' : a < 135 ? side : 'sharp $side';
}

/// Steps for [points]: depart, one per turn of 30 degrees or more (vertices under 12 m apart merged), arrive.
List<UiNavStep> navDemoSteps(List<UiLatLng> points, {required bool dv}) {
  final cum = [0.0];
  for (var i = 1; i < points.length; i++) {
    cum.add(cum[i - 1] + uiNavDistance(points[i - 1], points[i]));
  }
  final turns = <({int i, String mod, double bearing})>[];
  for (var i = 1; i < points.length - 1; i++) {
    final before = uiNavBearing(points[i - 1], points[i]);
    final after = uiNavBearing(points[i], points[i + 1]);
    final turn = ((after - before + 540) % 360) - 180;
    final mod = _modifier(turn);
    if (mod == null) continue;
    if (turns.isNotEmpty && cum[i] - cum[turns.last.i] < 12) continue;
    turns.add((i: i, mod: mod, bearing: after));
  }
  String street(int k) => (dv ? _streetsDv : _streets)[k % _streets.length];
  final marks = [0, ...turns.map((x) => x.i), points.length - 1];
  return [
    for (var k = 0; k < marks.length; k++)
      () {
        final i = marks[k];
        final dist = k < marks.length - 1 ? cum[marks[k + 1]] - cum[i] : 0.0;
        final secs = dist / 6; // about 22 km/h through town
        if (k == 0) {
          return UiNavStep(
            maneuver: UiNavManeuver(type: 'depart', location: points.first, bearingAfter: uiNavBearing(points[0], points[1])),
            distanceMeters: dist,
            durationSeconds: secs,
            instruction: dv ? '${street(0)} ގައި ފަށާ' : 'Head out on ${street(0)}',
            streetName: street(0),
          );
        }
        if (k == marks.length - 1) {
          return UiNavStep(maneuver: UiNavManeuver(type: 'arrive', location: points[i]), distanceMeters: 0, durationSeconds: 0, instruction: dv ? 'މަންޒިލަށް ވާސިލުވެއްޖެ' : 'You have arrived');
        }
        final t = turns[k - 1];
        final w = _words[t.mod]!;
        return UiNavStep(
          maneuver: UiNavManeuver(type: 'turn', modifier: t.mod, location: points[i], bearingAfter: t.bearing),
          distanceMeters: dist,
          durationSeconds: secs,
          instruction: (dv ? w.$2 : w.$1).replaceAll('{s}', street(k)),
          streetName: street(k),
        );
      }(),
  ];
}

/// The simulated drive: play / pause, speed, restart, wander off the road, glass, and the events.
class NavDriveDemo extends StatefulWidget {
  const NavDriveDemo({super.key, this.tileUrl, this.tileUrlDark, this.tileProvider, this.autoplay = false});
  final String? tileUrl, tileUrlDark;

  /// Tests and screenshots pass their own tiles.
  final TileProvider? tileProvider;

  /// Starts driving at once (screenshots).
  final bool autoplay;

  @override
  State<NavDriveDemo> createState() => NavDriveDemoState();
}

class NavDriveDemoState extends State<NavDriveDemo> {
  final _geo = UiNavTracker(navDemoRoute, const []);
  List<UiLatLng> _route = navDemoRoute;
  UiNavPosition? _pos;
  Timer? _timer;
  int _speed = 2;
  bool _glass = false;
  // 0.47.1: the app's buttons, the status and an app bar (insets).
  bool _muted = false, _appBar = false;
  String? _status;
  double _along = 0, _off = 0;
  int _clock = DateTime.now().millisecondsSinceEpoch;
  final _events = <String>[];
  // The steps, kept per language: a new list on every build would start a new tracker each frame
  // (the view treats a new steps list as a reroute), repeating the announcements and never going off route.
  List<UiNavStep>? _steps;
  bool? _stepsDv;
  List<UiNavStep> _stepsFor(bool dv) {
    if (_steps == null || _stepsDv != dv) {
      _steps = navDemoSteps(navDemoRoute, dv: dv);
      _stepsDv = dv;
    }
    return _steps!;
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoplay) WidgetsBinding.instance.addPostFrameCallback((_) => play());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Moves the drive on by [seconds] of simulated time: 8 m/s times the speed.
  void advance(double seconds) {
    _along = math.min(_geo.totalMeters, _along + 8 * seconds * _speed);
    _clock += (seconds * 1000 * _speed).round();
    final at = _geo.pointAt(_along);
    final pts = _geo.points;
    final heading = uiNavBearing(pts[at.segment], pts[math.min(pts.length - 1, at.segment + 1)]);
    final off = _off == 0 ? 0.0 : _off / (111195 * math.cos(at.point.lat * math.pi / 180));
    setState(() => _pos = UiNavPosition(at.point.lat, at.point.lng + off, heading: heading, speed: 8.0 * _speed, accuracy: 12, timestamp: _clock));
    if (_along >= _geo.totalMeters) stop();
  }

  void play() {
    if (_timer != null) return;
    if (_along >= _geo.totalMeters) restart();
    advance(0.25);
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => advance(0.25));
    setState(() {});
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() {});
  }

  void restart() {
    setState(() {
      _along = 0;
      _off = 0;
      _events.clear();
      _status = null;
      // A new list: a new tracker (as after a reroute).
      _route = List.of(navDemoRoute);
      _pos = null;
    });
  }

  void _log(String e) => setState(() {
        _events.insert(0, e);
        if (_events.length > 6) _events.removeLast();
      });

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final dv = context.uiStrings.locale == 'dv';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SizedBox(
            height: 680,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.uiTheme.radius(t.radius)),
              child: Stack(children: [
                Positioned.fill(child: UiMapNavigation(
                route: _route,
                steps: _stepsFor(dv),
                position: _pos,
                glass: _glass,
                destinationLabel: 'Lily Magu',
                tileUrl: widget.tileUrl ?? uiMapOsmTiles,
                tileUrlDark: widget.tileUrlDark,
                tileProvider: widget.tileProvider,
                userAgentPackageName: 'com.zouriel.ui.showcase',
                onAnnounce: (e) => _log('announce (${e.reason.name}${e.threshold != null ? ' ${e.threshold!.round()} m' : ''}): ${e.step.instruction}'),
                onOffRoute: (e) {
                  _log('offRoute, ${e.distanceMeters.round()} m off');
                  setState(() => _status = dv ? 'އަލުން މަގު ހޯދަނީ…' : 'Rerouting…');
                },
                // Back on the route: the Rerouting… status goes (the demo has no real reroute).
                onProgress: (s) {
                  if (_status != null && !s.offRoute && s.distanceFromRoute < 40) setState(() => _status = null);
                },
                status: _status,
                insets: EdgeInsetsDirectional.only(top: _appBar ? 48 : 0),
                actions: [
                  UiNavAction(
                    icon: _muted ? HugeIcons.strokeRoundedVolumeOff : HugeIcons.strokeRoundedVolumeHigh,
                    label: _muted ? 'Unmute' : 'Mute',
                    pressed: _muted,
                    onPressed: () => setState(() => _muted = !_muted),
                  ),
                  UiNavAction(icon: HugeIcons.strokeRoundedAlert02, label: 'SOS', tone: UiNavActionTone.danger, onPressed: () => _log('SOS pressed')),
                ],
                onArrived: () => _log('arrived'),
                onEnd: () {
                  stop();
                  _log('end');
                },
              )),
                if (_appBar)
                  Positioned(
                    key: const ValueKey('nav-demo-appbar'),
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 48,
                    child: ExcludeSemantics(
                      child: Container(
                        alignment: AlignmentDirectional.centerStart,
                        padding: EdgeInsets.symmetric(horizontal: t.space4),
                        decoration: BoxDecoration(color: t.surfaceRaised, border: Border(bottom: BorderSide(color: t.border))),
                        child: Text('App bar (insets.top 48)', style: context.uiText.label.copyWith(color: t.text)),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
      Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
        UiButton(label: _timer != null ? 'Pause' : 'Play', size: UiSize.sm, onPressed: () => _timer != null ? stop() : play()),
        UiSegmented<int>(
          label: 'Speed (demo)',
          size: UiSize.sm,
          options: const [UiSegmentedOption(value: 1, label: '1x'), UiSegmentedOption(value: 2, label: '2x'), UiSegmentedOption(value: 4, label: '4x'), UiSegmentedOption(value: 8, label: '8x')],
          value: _speed,
          onChanged: (v) => setState(() => _speed = v),
        ),
        UiButton(label: 'Restart', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: restart),
        UiButton(label: 'Wander off', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() => _off = _off == 0 ? 80 : 0)),
        UiSegmented<bool>(
          label: 'Glass (demo)',
          size: UiSize.sm,
          options: const [UiSegmentedOption(value: true, label: 'On'), UiSegmentedOption(value: false, label: 'Off')],
          value: _glass,
          onChanged: (v) => setState(() => _glass = v),
        ),
        UiSegmented<bool>(
          label: 'App bar (demo)',
          size: UiSize.sm,
          options: const [UiSegmentedOption(value: true, label: 'On'), UiSegmentedOption(value: false, label: 'Off')],
          value: _appBar,
          onChanged: (v) => setState(() => _appBar = v),
        ),
      ]),
      for (final e in _events) Text(e, style: context.uiText.caption),
    ]);
  }
}

/// Every maneuver drawing, named.
class NavIconGallery extends StatelessWidget {
  const NavIconGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Wrap(spacing: t.space2, runSpacing: t.space2, children: [
      for (final k in UiNavIconKind.values)
        Container(
          width: 112,
          padding: EdgeInsets.all(t.space3),
          decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(context.uiTheme.radius(t.radius))),
          child: Column(spacing: t.space2, children: [
            UiIcon(uiNavIcons[k]!, size: 36, strokeWidth: 2, color: t.text),
            Text(k.webName, textAlign: TextAlign.center, style: context.uiText.caption),
          ]),
        ),
    ]);
  }
}
