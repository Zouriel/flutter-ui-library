import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart' show TileProvider;
import 'package:hugeicons/hugeicons.dart';

import '../button/button.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';
import 'map.dart';
import 'navigation.dart';

/// Where the person sits in the visible part while followed: this far down it (0.47.0, the web
/// `UI_NAV_FOLLOW_AT`).
const double uiNavFollowAt = 0.68;

/// The zoom a navigation view follows at, and goes back to on Recenter (the web `UI_NAV_ZOOM`).
const double uiNavZoom = 17;

/// Where a followed person's dot goes (0.47.0, the web `uiNavFollowInsets`): the top inset that puts
/// the middle of the part between it and [bottom] at [uiNavFollowAt] of the way down from [top]
/// (the banner) to the bottom bar, so there is more road ahead than behind.
EdgeInsetsDirectional uiNavFollowInsets(double height, double top, double bottom) {
  final free = math.max(0.0, height - top - bottom);
  final at = top + free * uiNavFollowAt;
  return EdgeInsetsDirectional.only(top: math.max(0.0, 2 * at - height + bottom), bottom: bottom);
}

/// A [UiNavAction]'s colour (0.47.1, the web `UiNavActionTone`): [neutral], or [danger] for SOS.
enum UiNavActionTone { neutral, danger }

/// One of the app's own buttons on a [UiMapNavigation] (0.47.1, the web `button[uiNavAction]`): mute,
/// SOS. Pass them in [UiMapNavigation.actions]; they stack at the end side under the banner. A 48dp
/// opaque circle with the icon; [label] is its accessible name. [tone] danger is the prominent SOS
/// style (the danger fill inside a raised-surface ring). [pressed] makes it a toggle (announced as
/// toggled), drawn in the primary fill while on (muted).
class UiNavAction extends StatelessWidget {
  const UiNavAction({super.key, required this.icon, required this.label, required this.onPressed, this.tone = UiNavActionTone.neutral, this.pressed});

  /// The icon (a hugeicons icon).
  final UiIconData icon;

  /// The accessible name: "Mute", "SOS".
  final String label;
  final VoidCallback? onPressed;

  /// [UiNavActionTone.danger]: the prominent SOS style.
  final UiNavActionTone tone;

  /// A toggle's state, drawn in the primary fill while true; null: not a toggle.
  final bool? pressed;

  /// Its diameter: 48dp everywhere (a touch target on its own).
  static const double size = 48;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final danger = tone == UiNavActionTone.danger;
    final on = pressed ?? false;
    return UiInteractive(
      onTap: onPressed,
      enabled: onPressed != null,
      semanticLabel: label,
      toggled: pressed,
      excludeChildSemantics: true,
      builder: (context, st) {
        final hot = st.hovered || st.pressed;
        final fill = danger
            ? (hot ? t.dangerHover : t.danger)
            : on
                ? (hot ? t.primaryHover : t.primary)
                : (hot ? t.surfaceHover : t.surfaceRaised);
        final ink = danger ? t.dangerContrast : (on ? t.primaryContrast : (st.disabled ? t.textMuted : t.text));
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: danger || on ? null : Border.all(color: t.border),
            boxShadow: [
              // Danger: a ring of the raised surface, so it stands out on any map.
              if (danger) BoxShadow(color: t.surfaceRaised, spreadRadius: 3),
              ...t.shadow2,
              if (st.focused) ...t.focusRing,
            ],
          ),
          child: UiIcon(icon, size: 22, strokeWidth: 1.8, color: ink),
        );
      },
    );
  }
}

/// `ui-map-navigation` for Flutter (0.47.0): a turn-by-turn view, like a car's navigation. A flat
/// map that follows the person and turns heading-up, the route ahead in the primary tone and the
/// part behind dimmed, an arrow for the person, a banner with the next maneuver (its arrow, "in 80 m",
/// the instruction and street) and the one after it small, and a bar with the time and distance
/// left, the arrival time and End.
///
/// - The app gives [route], [steps] (OSRM steps with its own localized instructions) and the live
///   [position]; the view reads no GPS itself. A new route or steps list (a reroute) starts a new
///   [UiNavTracker].
/// - [onAnnounce] at the start, on each new maneuver ahead and at 200 m and 30 m before it (each
///   once): speak `event.step.instruction`. [onOffRoute] after 5 s more than 40 m off the route:
///   reroute. [onArrived] within 20 m of the end. [onProgress] every update. [onEnd] when End is
///   pressed. Tune with [options]. They are called after the frame that takes the position.
/// - A drag, pinch, double tap or two-finger turn stops the following (the map keeps its turn) and
///   shows Recenter, which follows again heading-up at [zoom]; the compass shows meanwhile. With animations off (reduced motion) the map turns at once.
/// - In right-to-left text the banner and bar are mirrored; the maneuver arrows are not (left is left).
/// - [glass] (the config's by default) puts the banner and bar on glass.
/// - [actions] (0.47.1): the app's [UiNavAction]s stack as 48dp round buttons at the end side under
///   the banner, clear of the compass (inline start) and Recenter (bottom start). [status]
///   ("Rerouting…") shows as a pill under the banner, a live region.
/// - [insets] (0.47.1): what the app covers along each edge (an app bar with the status bar under it,
///   a bottom navigation); the banner, actions, Recenter and bar stay inside them. The device safe
///   area (MediaQuery padding: status bar, notch, gesture bar) is used wherever it is bigger.
class UiMapNavigation extends StatefulWidget {
  const UiMapNavigation({
    super.key,
    required this.route,
    required this.steps,
    this.position,
    this.options = const UiNavOptions(),
    this.zoom = uiNavZoom,
    this.destinationLabel,
    this.formatTime = uiNavFormatClock,
    this.glass,
    this.semanticLabel,
    this.mapLabel,
    this.tileUrl = uiMapOsmTiles,
    this.tileUrlDark,
    this.tileSize = 256,
    this.zoomOffset = 0,
    this.attribution = '© OpenStreetMap contributors',
    this.tileProvider,
    this.tileHeaders,
    this.userAgentPackageName = 'com.zouriel.ui',
    this.onAnnounce,
    this.onOffRoute,
    this.onArrived,
    this.onProgress,
    this.onEnd,
    this.actions = const [],
    this.status,
    this.insets = EdgeInsetsDirectional.zero,
  });

  /// The app's own buttons (0.47.1), usually [UiNavAction]s: a stack at the end side under the banner.
  final List<Widget> actions;

  /// A short state under the banner, as a pill ("Rerouting…"), a live region; null for none (0.47.1).
  final String? status;

  /// What the app covers along each edge (0.47.1): an app bar (with the status bar under it) at the
  /// top, a bottom navigation, a side rail. The device safe area counts wherever it is bigger.
  final EdgeInsetsDirectional insets;

  /// The route's geometry (OSRM's GeoJSON is [lng, lat]: swap it).
  final List<UiLatLng> route;

  /// The route's steps, with the app's localized instructions.
  final List<UiNavStep> steps;

  /// The person's live position, from the app; null before the first fix.
  final UiNavPosition? position;
  final UiNavOptions options;

  /// The zoom it follows at, and goes back to on Recenter; 17.
  final double zoom;

  /// The destination marker's label; none by default.
  final String? destinationLabel;

  /// The arrival time's format: 24-hour "14:05" by default.
  final String Function(DateTime time) formatTime;

  /// The banner and bar on glass; null: the theme config's.
  final bool? glass;

  /// The view's name; null: [UiStrings.navLabel] ("Navigation").
  final String? semanticLabel;

  /// The map's name; null: [UiStrings.mapLabel].
  final String? mapLabel;
  final String tileUrl;
  final String? tileUrlDark;
  final int tileSize;
  final double zoomOffset;
  final String attribution;
  final TileProvider? tileProvider;
  final Map<String, String>? tileHeaders;
  final String userAgentPackageName;

  /// Time to speak (at the start, each new maneuver ahead, and at 200 m and 30 m before it).
  final ValueChanged<UiNavAnnounce>? onAnnounce;

  /// Off the route for a while: reroute (give a new route and steps).
  final ValueChanged<UiNavOffRoute>? onOffRoute;

  /// At the destination.
  final VoidCallback? onArrived;

  /// Every position's result.
  final ValueChanged<UiNavState>? onProgress;

  /// End was pressed.
  final VoidCallback? onEnd;

  @override
  State<UiMapNavigation> createState() => UiMapNavigationState();
}

class UiMapNavigationState extends State<UiMapNavigation> {
  final _map = GlobalKey<UiMapState>();
  final _top = GlobalKey();
  final _bar = GlobalKey();
  late UiNavTracker _tracker;
  UiNavState? _state;
  bool _following = true;
  double _heldBearing = 0;
  double _topHeight = 0, _barHeight = 0;

  /// Where the map opens (the first fix, else the route's start); the map is moved by following, not by this.
  UiLatLng? _startCenter;

  /// The tracker for the current route.
  UiNavTracker get tracker => _tracker;

  /// The latest state, or null before the first position.
  UiNavState? get state => _state;

  /// Whether the map follows the person (until they move it).
  bool get following => _following;

  @override
  void initState() {
    super.initState();
    _tracker = UiNavTracker(widget.route, widget.steps, options: widget.options);
    if (widget.position != null) _take(widget.position!);
  }

  @override
  void didUpdateWidget(UiMapNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (!identical(old.route, widget.route) || !identical(old.steps, widget.steps) || old.options != widget.options) {
      _tracker = UiNavTracker(widget.route, widget.steps, options: widget.options);
      if (widget.position == null) _state = null;
    }
    final p = widget.position;
    if (p == null) {
      _state = null;
    } else if (p != old.position || !identical(old.route, widget.route) || !identical(old.steps, widget.steps)) {
      _take(p);
    }
  }

  void _take(UiNavPosition p) {
    final s = _tracker.update(p);
    _state = s;
    if (_following) _heldBearing = s.bearing;
    // After the frame: callbacks may set state up the tree, and the map moves once it is laid out.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final e in s.events) {
        switch (e) {
          case UiNavAnnounce():
            widget.onAnnounce?.call(e);
          case UiNavOffRoute():
            widget.onOffRoute?.call(e);
          case UiNavArrived():
            widget.onArrived?.call();
        }
      }
      widget.onProgress?.call(s);
      if (_following) _map.currentState?.flyTo(s.display);
    });
  }

  /// Follows the person again at [UiMapNavigation.zoom], heading-up.
  void recenter() {
    setState(() {
      _following = true;
      if (_state != null) _heldBearing = _state!.bearing;
    });
    final s = _state;
    if (s != null) {
      _map.currentState?.flyTo(s.display, zoom: widget.zoom);
      // Heading-up again, even when the person turned the map (the bearing may not have changed).
      _map.currentState?.rotateTo(s.bearing);
    }
  }

  void _measure() {
    final top = _top.currentContext?.findRenderObject() as RenderBox?;
    final bar = _bar.currentContext?.findRenderObject() as RenderBox?;
    if (top == null || bar == null || !top.hasSize || !bar.hasSize) return;
    final parent = context.findRenderObject() as RenderBox?;
    final offset = parent == null ? 0.0 : top.localToGlobal(Offset.zero, ancestor: parent).dy;
    // The bar's top from the bottom: its height plus the app's bottom inset (0.47.1).
    final barTop = parent == null ? null : bar.localToGlobal(Offset.zero, ancestor: parent).dy;
    final th = top.size.height + offset;
    final bh = parent == null || !parent.hasSize || barTop == null ? bar.size.height : math.max(bar.size.height, parent.size.height - barTop);
    if (th != _topHeight || bh != _barHeight) {
      setState(() {
        _topHeight = th;
        _barHeight = bh;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final strings = context.uiStrings;
    final glass = widget.glass ?? context.uiTheme.config.glass;
    final s = _state;
    final points = _tracker.points;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });

    final split = _tracker.split(s?.traveledMeters ?? 0);
    final lines = points.length < 2
        ? const <UiMapRoute>[]
        : [
            // The way behind dimmed (the muted tone at 60% opacity on its casing), the way ahead in the
            // primary tone; never drawn in (they change on every fix).
            UiMapRoute(id: 'nav-traveled', points: split.traveled, tone: UiMapRouteTone.muted, opacity: 0.6, animate: false),
            UiMapRoute(id: 'nav-remaining', points: split.remaining, animate: false),
          ];
    final p = widget.position;
    final puck = s == null || p == null ? null : UiMapUserLocation(s.display.lat, s.display.lng, accuracy: p.accuracy, heading: p.heading ?? s.bearing);
    final end = points.isEmpty ? null : points.last;
    final ahead = s?.next ?? (widget.steps.length > 1 ? widget.steps[1] : null);
    final kind = ahead == null ? UiNavIconKind.straight : uiNavIconKind(ahead.maneuver);
    final exit = ahead != null && kind.isRoundabout ? ahead.maneuver.exit : null;
    final toManeuver = s?.distanceToManeuver ?? (widget.steps.isNotEmpty ? widget.steps.first.distanceMeters : 0);
    final inText = strings.navIn.replaceAll('{distance}', uiNavFormatDistance(toManeuver, strings));
    final instruction = (ahead?.instruction.isNotEmpty ?? false) ? ahead!.instruction : strings.navArrive;
    final street = ahead?.streetName;
    final secondsLeft = s?.remainingSeconds ?? widget.steps.fold<double>(0, (a, x) => a + x.durationSeconds);
    final metersLeft = s?.remainingMeters ?? _tracker.totalMeters;
    final at = p?.timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final timeLeft = uiNavFormatDuration(secondsLeft, strings);
    final distanceLeft = uiNavFormatDistance(metersLeft, strings);
    final clock = widget.formatTime(DateTime.fromMillisecondsSinceEpoch(at + (secondsLeft * 1000).round()));
    final summary = strings.navSummary.replaceAll('{time}', timeLeft).replaceAll('{distance}', distanceLeft).replaceAll('{clock}', clock);
    final size = MediaQuery.sizeOf(context);
    // 0.47.1: the edges the overlays keep to: the app's insets, or the device's safe area where that is
    // bigger. The side safe area is the larger of the two, so either direction keeps clear of a notch.
    final pad = MediaQuery.paddingOf(context);
    final ins = widget.insets;
    final safeX = math.max(pad.left, pad.right);
    final edgeTop = math.max(ins.top, pad.top), edgeStart = math.max(ins.start, safeX), edgeEnd = math.max(ins.end, safeX);

    Widget frosted(Widget child, BorderRadius radius) => glass
        ? ClipRRect(borderRadius: radius, child: BackdropFilter(filter: ImageFilter.blur(sigmaX: t.glassBlur / 2, sigmaY: t.glassBlur / 2), child: child))
        : child;

    final onBanner = glass ? t.text : t.primaryContrast;
    final bannerRadius = BorderRadius.circular(t.radiusLg);
    final banner = frosted(
      Container(
        key: const ValueKey('ui-nav-banner'),
        padding: EdgeInsetsDirectional.symmetric(horizontal: t.space4, vertical: t.space3),
        decoration: BoxDecoration(
          color: glass ? t.glassBg : t.primary,
          borderRadius: bannerRadius,
          border: glass ? Border.all(color: t.glassBorder) : null,
          boxShadow: t.shadow3,
        ),
        child: Semantics(
          container: true,
          label: [inText, instruction, ?street].join(', '),
          child: ExcludeSemantics(
            child: Row(children: [
              SizedBox.square(
                key: const ValueKey('ui-nav-maneuver'),
                dimension: t.sizeXl,
                child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                  if (glass) Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(t.radius)))),
                  // Never mirrored: left is left in any language.
                  UiIcon(uiNavIcons[kind]!, key: ValueKey('ui-nav-icon-${kind.webName}'), size: 40, strokeWidth: 2.2, color: glass ? t.primaryContrast : onBanner),
                  if (exit != null)
                    PositionedDirectional(
                      end: -t.space1,
                      bottom: -t.space1,
                      child: Container(
                        key: const ValueKey('ui-nav-exit'),
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        padding: EdgeInsets.symmetric(horizontal: t.space1),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: t.primaryContrast, borderRadius: BorderRadius.circular(999)),
                        child: Text('$exit', style: context.uiText.label.copyWith(fontSize: 12, height: 1, color: t.primary, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ]),
              ),
              SizedBox(width: t.space3),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(inText, key: const ValueKey('ui-nav-distance'), style: context.uiText.h3.copyWith(color: onBanner, fontWeight: FontWeight.w700, height: 1.2)),
                  Text(instruction,
                      key: const ValueKey('ui-nav-instruction'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.body.copyWith(color: onBanner, fontSize: t.fontSizeLg, fontWeight: FontWeight.w600, height: 1.35)),
                  if (street != null)
                    Text(street,
                        key: const ValueKey('ui-nav-street'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.body.copyWith(color: glass ? t.textMuted : Color.lerp(t.primaryContrast, t.primary, 0.12), height: 1.35)),
                ]),
              ),
            ]),
          ),
        ),
      ),
      bannerRadius,
    );
    final nn = s?.nextNext;
    final then = nn == null
        ? null
        : Padding(
            padding: EdgeInsetsDirectional.only(start: t.space4, end: t.space4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                key: const ValueKey('ui-nav-then'),
                padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space1),
                decoration: BoxDecoration(
                  color: t.primaryActive,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(t.radius)),
                  boxShadow: t.shadow2,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(strings.navThen, style: context.uiText.label.copyWith(color: t.primaryContrast, height: 1.35)),
                  SizedBox(width: t.space2),
                  UiIcon(uiNavIcon(nn.maneuver), size: 20, strokeWidth: 2, color: t.primaryContrast),
                  SizedBox(width: t.space2),
                  Flexible(
                    child: Text(nn.instruction.isEmpty ? strings.navArrive : nn.instruction,
                        key: const ValueKey('ui-nav-then-text'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.caption.copyWith(color: t.primaryContrast, height: 1.35)),
                  ),
                ]),
              ),
            ),
          );

    final barRadius = BorderRadius.vertical(top: Radius.circular(t.radiusLg));
    final bar = frosted(
      Container(
        // The safe area pads it only where the app's insets don't already cover it (0.47.1).
        padding: EdgeInsetsDirectional.fromSTEB(t.space4 + math.max(0.0, safeX - ins.start), t.space3, t.space4 + math.max(0.0, safeX - ins.end),
            t.space3 + math.max(0.0, pad.bottom - ins.bottom)),
        decoration: BoxDecoration(
          color: glass ? t.glassBg : t.surfaceRaised,
          borderRadius: barRadius,
          border: glass ? Border.all(color: t.glassBorder) : null,
          boxShadow: t.shadow3,
        ),
        child: Row(children: [
          Expanded(
            child: Semantics(
              container: true,
              label: summary,
              child: ExcludeSemantics(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(timeLeft, key: const ValueKey('ui-nav-time'), style: context.uiText.h3.copyWith(color: t.text, fontWeight: FontWeight.w700, height: 1.2)),
                  Wrap(spacing: t.space1, children: [
                    Text(distanceLeft, key: const ValueKey('ui-nav-distance-left'), style: context.uiText.body.copyWith(color: t.textMuted, height: 1.35)),
                    Text('·', style: context.uiText.body.copyWith(color: t.textMuted, height: 1.35)),
                    Text(clock, key: const ValueKey('ui-nav-clock'), textDirection: TextDirection.ltr, style: context.uiText.body.copyWith(color: t.textMuted, height: 1.35)),
                  ]),
                ]),
              ),
            ),
          ),
          SizedBox(width: t.space3),
          UiButton(key: const ValueKey('ui-nav-end'), label: strings.navEnd, variant: UiButtonVariant.destructive, onPressed: widget.onEnd ?? () {}),
        ]),
      ),
      barRadius,
    );

    final recenterButton = UiInteractive(
      key: const ValueKey('ui-nav-recenter'),
      onTap: recenter,
      semanticLabel: strings.navRecenter,
      builder: (context, st) => Container(
        constraints: BoxConstraints(minHeight: t.sizeTouch),
        padding: EdgeInsets.symmetric(horizontal: t.space4),
        decoration: BoxDecoration(
          color: st.hovered || st.pressed ? t.surfaceHover : t.surfaceRaised,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: t.border),
          boxShadow: st.focused ? [...t.shadow2, ...t.focusRing] : t.shadow2,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          UiIcon(HugeIcons.strokeRoundedNavigation03, size: 18, color: t.primary),
          SizedBox(width: t.space2),
          ExcludeSemantics(child: Text(strings.navRecenter, style: context.uiText.label.copyWith(color: t.primary, fontSize: t.fontSizeMd))),
        ]),
      ),
    );

    final status = widget.status;
    final statusPill = status == null || status.isEmpty
        ? null
        : Semantics(
            container: true,
            liveRegion: true,
            label: status,
            child: ExcludeSemantics(
              child: Container(
                key: const ValueKey('ui-nav-status'),
                constraints: const BoxConstraints(minHeight: 32),
                padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space1),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.surfaceRaised,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: t.border),
                  boxShadow: t.shadow2,
                ),
                child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(color: t.text, fontSize: t.fontSizeMd, fontWeight: FontWeight.w600, height: 1.35)),
              ),
            ),
          );
    // 0.47.1: under the banner, three columns: the inline start kept free for the map's compass, the
    // status pill in the middle, the app's buttons in a stack at the inline end. Mirrored in RTL.
    final under = Row(key: const ValueKey('ui-nav-under'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(width: UiNavAction.size),
      SizedBox(width: t.space3),
      Expanded(child: Align(alignment: Alignment.topCenter, child: statusPill)),
      SizedBox(width: t.space3),
      SizedBox(
        width: UiNavAction.size,
        child: Column(key: const ValueKey('ui-nav-actions'), mainAxisSize: MainAxisSize.min, spacing: t.space3, children: widget.actions),
      ),
    ]);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel ?? strings.navLabel,
      child: LayoutBuilder(builder: (context, box) {
        final height = box.maxHeight.isFinite ? box.maxHeight : size.height;
        final insets = _topHeight > 0 ? uiNavFollowInsets(height, _topHeight, _barHeight) : EdgeInsetsDirectional.zero;
        return Stack(children: [
          Positioned.fill(
            child: UiMap(
              key: _map,
              fill: true,
              center: _startCenter ??= s?.display ?? (p != null ? p.latLng : (points.isNotEmpty ? points.first : const UiLatLng(4.1755, 73.5093))),
              zoom: widget.zoom,
              routes: lines,
              userLocation: puck,
              markers: [if (end != null) UiMapMarker(id: 'nav-destination', lat: end.lat, lng: end.lng, tone: UiStatus.danger, label: widget.destinationLabel)],
              bearing: _following && s != null ? s.bearing : _heldBearing,
              // The follow point's top and bottom, and the app's sides (the compass keeps clear of a side rail).
              viewInsets: insets.copyWith(start: ins.start, end: ins.end),
              zoomButtons: false,
              // North up is a tap away only while not following (heading-up is the point otherwise).
              compass: !_following,
              semanticLabel: widget.mapLabel,
              tileUrl: widget.tileUrl,
              tileUrlDark: widget.tileUrlDark,
              tileSize: widget.tileSize,
              zoomOffset: widget.zoomOffset,
              attribution: widget.attribution,
              tileProvider: widget.tileProvider,
              tileHeaders: widget.tileHeaders,
              userAgentPackageName: widget.userAgentPackageName,
              onUserMove: () {
                if (_following) setState(() => _following = false);
              },
            ),
          ),
          PositionedDirectional(
            top: edgeTop + t.space3,
            start: edgeStart + t.space3,
            end: edgeEnd + t.space3,
            child: Column(key: _top, mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [banner, ?then]),
          ),
          if (_topHeight > 0 && (statusPill != null || widget.actions.isNotEmpty))
            PositionedDirectional(top: _topHeight + t.space2, start: edgeStart + t.space3, end: edgeEnd + t.space3, child: under),
          if (!_following) PositionedDirectional(start: edgeStart + t.space3, bottom: _barHeight + t.space3, child: recenterButton),
          PositionedDirectional(start: ins.start, end: ins.end, bottom: ins.bottom, child: KeyedSubtree(key: _bar, child: bar)),
        ]);
      }),
    );
  }
}
