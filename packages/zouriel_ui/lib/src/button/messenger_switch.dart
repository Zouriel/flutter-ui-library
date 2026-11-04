import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../theme/theme.dart';
import 'messenger_button.dart';

/// Moves the selection by [delta] places (wrapping).
class _StepIntent extends Intent {
  const _StepIntent(this.delta);
  final int delta;
}

/// Moves the selection to the first or last app.
class _EdgeIntent extends Intent {
  const _EdgeIntent({required this.last});
  final bool last;
}

/// `ui-messenger-switch`: a "Send next on WhatsApp" button that is also a channel switch. The main
/// pill (the brand's fill, its logo, [label] and [sublabel]) emits [onPressed] with the current app;
/// chevrons on each side, a swipe across the pill (finger left = next, right = previous; mirrored in
/// RTL), the arrow keys (Right/Down next, Left/Up previous, Home/End first/last) and a row of logo dots
/// under it change the channel through [onChanged]. Controlled: pass the new [value] back.
///
/// The label wraps to two lines when it must (the pill grows from its 52 minimum); the sublabel keeps
/// to one line. Centred in its parent, as wide as it allows up to 360. [disabled] only stops the pill pressing:
/// it can still be focused and the channel can still be changed. Changing channel slides the content
/// in from the side it comes from and cross-fades the fill (no motion when `context.uiAnimate` is
/// false). Twin of Angular's `ui-messenger-switch`.
class UiMessengerSwitch extends StatefulWidget {
  const UiMessengerSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.apps = UiMessengerApp.values,
    this.label,
    this.sublabel,
    this.disabled = false,
    this.onPressed,
    this.focusNode,
  }) : assert(apps.length > 0, 'Give the switch at least one app.');

  /// The current app; should be one of [apps].
  final UiMessengerApp value;
  final ValueChanged<UiMessengerApp>? onChanged;

  /// The channels, in order (default all three).
  final List<UiMessengerApp> apps;

  /// The pill's words; default [UiStrings.messengerSendNext] with the app's name.
  final String? label;

  /// A second line, e.g. "Next: Aisha".
  final String? sublabel;

  /// The pill doesn't press (half opacity); switching still works.
  final bool disabled;

  /// The pill was pressed: the current app.
  final ValueChanged<UiMessengerApp>? onPressed;

  /// The pill's focus node.
  final FocusNode? focusNode;

  /// The largest width the control takes.
  static const double maxWidth = 360;

  /// The pill's minimum height.
  static const double pillHeight = 52;

  /// A swipe needs this much sideways travel (or a fling of [flingVelocity]).
  static const double swipeDistance = 40;
  static const double flingVelocity = 300;

  /// The pill's logo box: 24, Telegram 30.
  static double logoSize(UiMessengerApp app) => app == UiMessengerApp.telegram ? 30 : 24;

  /// A dot's logo: 16 on a 20px disc of the brand fill; Telegram's own disc logo at 20.
  static double dotLogoSize(UiMessengerApp app) => app == UiMessengerApp.telegram ? 20 : 16;

  @override
  State<UiMessengerSwitch> createState() => _UiMessengerSwitchState();
}

class _UiMessengerSwitchState extends State<UiMessengerSwitch> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(vsync: this, value: 1);
  late UiMessengerApp _from = widget.value;
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'messenger switch'));
  final Map<UiMessengerApp, FocusNode> _dotFocus = {};

  /// +1 when the new app came from the end side (next), -1 from the start side (previous).
  int _dir = 1;
  bool _hovered = false, _focused = false, _pressed = false;
  Offset? _dragStart, _dragLast;

  @override
  void didUpdateWidget(UiMessengerSwitch old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = old.value;
      final a = widget.apps.indexOf(old.value), b = widget.apps.indexOf(widget.value);
      if (a >= 0 && b >= 0) {
        final n = widget.apps.length;
        // The shorter way round decides the side (a wrap from last to first is a step forward).
        _dir = ((b - a) % n + n) % n <= n ~/ 2 ? 1 : -1;
      }
      _fade.duration = context.uiAnimate ? context.ui.motionBase : Duration.zero;
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    _ownFocus?.dispose();
    for (final f in _dotFocus.values) {
      f.dispose();
    }
    super.dispose();
  }

  int get _index => widget.apps.indexOf(widget.value).clamp(0, widget.apps.length - 1);

  void _select(UiMessengerApp app, {bool focusDot = false}) {
    if (focusDot) _dotFocus[app]?.requestFocus();
    if (app != widget.value) widget.onChanged?.call(app);
  }

  void _step(int delta, {bool focusDot = false}) {
    final n = widget.apps.length;
    if (n < 2) return;
    _select(widget.apps[((_index + delta) % n + n) % n], focusDot: focusDot);
  }

  void _press() {
    if (!widget.disabled) widget.onPressed?.call(widget.value);
  }

  /// Arrow keys as steps: Right/Down next, Left/Up previous, Left and Right swapped in RTL.
  Map<ShortcutActivator, Intent> _keys(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return {
      SingleActivator(LogicalKeyboardKey.arrowRight): _StepIntent(rtl ? -1 : 1),
      SingleActivator(LogicalKeyboardKey.arrowLeft): _StepIntent(rtl ? 1 : -1),
      const SingleActivator(LogicalKeyboardKey.arrowDown): const _StepIntent(1),
      const SingleActivator(LogicalKeyboardKey.arrowUp): const _StepIntent(-1),
      const SingleActivator(LogicalKeyboardKey.home): const _EdgeIntent(last: false),
      const SingleActivator(LogicalKeyboardKey.end): const _EdgeIntent(last: true),
    };
  }

  Map<Type, Action<Intent>> _keyActions({bool focusDot = false}) => {
        _StepIntent: CallbackAction<_StepIntent>(onInvoke: (i) {
          _step(i.delta, focusDot: focusDot);
          return null;
        }),
        _EdgeIntent: CallbackAction<_EdgeIntent>(onInvoke: (i) {
          _select(i.last ? widget.apps.last : widget.apps.first, focusDot: focusDot);
          return null;
        }),
      };

  void _dragEnd(DragEndDetails d) {
    final start = _dragStart, last = _dragLast;
    _dragStart = _dragLast = null;
    if (start == null || last == null) return;
    final dx = last.dx - start.dx, dy = last.dy - start.dy;
    final v = d.primaryVelocity ?? 0;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    int? toward; // -1: the finger went left, +1: right
    if (dx.abs() >= UiMessengerSwitch.swipeDistance && dx.abs() > dy.abs()) {
      toward = dx < 0 ? -1 : 1;
    } else if (v.abs() >= UiMessengerSwitch.flingVelocity && dx.abs() > dy.abs() && dx.sign == v.sign) {
      toward = v < 0 ? -1 : 1;
    }
    if (toward == null) return;
    // Finger left = next (in RTL, finger right = next).
    _step(rtl ? toward : -toward);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final s = context.uiStrings;
    final app = widget.value;
    final name = UiMessengerBrand.name(app);
    final label = (widget.label ?? '').isNotEmpty ? widget.label! : uiFormatString(s.messengerSendNext, {'app': name});
    final sub = (widget.sublabel ?? '').isNotEmpty ? widget.sublabel : null;
    final ink = UiMessengerBrand.ink(app);
    final animate = context.uiAnimate;
    final canSwitch = widget.apps.length > 1;

    final labelStyle = context.uiText.body.copyWith(fontSize: t.fontSizeMd, fontWeight: FontWeight.w600, height: 20 / t.fontSizeMd, color: ink, decoration: TextDecoration.none);
    final subStyle = context.uiText.body.copyWith(fontSize: t.fontSizeSm, fontWeight: FontWeight.w500, height: 16 / t.fontSizeSm, color: ink, decoration: TextDecoration.none);

    final content = Row(
      key: ValueKey(app),
      mainAxisSize: MainAxisSize.min,
      children: [
        UiMessengerLogo(app, key: const ValueKey('ui-mswitch-logo'), size: UiMessengerSwitch.logoSize(app)),
        SizedBox(width: t.space2),
        Flexible(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // The words may take two lines on a narrow screen (the pill grows); the sublabel keeps to one.
            Text(label, key: const ValueKey('ui-mswitch-label'), style: labelStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (sub != null) Text(sub, key: const ValueKey('ui-mswitch-sublabel'), style: subStyle, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false),
          ]),
        ),
      ],
    );

    final switcher = AnimatedSwitcher(
      duration: animate ? t.motionBase : Duration.zero,
      switchInCurve: t.easeDecelerate,
      switchOutCurve: t.easeAccelerate,
      transitionBuilder: (child, anim) {
        // The new content slides 16px in from the side it comes from; the old one fades.
        final incoming = child.key == ValueKey(app);
        final side = (Directionality.of(context) == TextDirection.rtl ? -1 : 1) * _dir;
        return FadeTransition(
          opacity: anim,
          child: incoming
              ? AnimatedBuilder(
                  animation: anim,
                  builder: (context, c) => Transform.translate(offset: Offset(16 * (1 - anim.value) * side, 0), child: c),
                  child: child,
                )
              : child,
        );
      },
      child: content,
    );

    final veil = _pressed && !widget.disabled ? 0.18 : _hovered && !widget.disabled ? 0.10 : 0.0;
    Widget pill = AnimatedBuilder(
      animation: _fade,
      builder: (context, child) => CustomPaint(
        key: const ValueKey('ui-mswitch-fill'),
        painter: _PillFill(from: _from, to: app, t: _fade.value, veil: veil),
        child: child,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: UiMessengerSwitch.pillHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space1),
          child: Center(widthFactor: 1, child: switcher),
        ),
      ),
    );
    pill = DecoratedBox(
      decoration: ShapeDecoration(shape: const StadiumBorder(), shadows: _focused ? t.focusRing : null),
      child: pill,
    );
    pill = Opacity(opacity: widget.disabled ? 0.5 : 1, child: pill);

    pill = FocusableActionDetector(
      focusNode: widget.focusNode ?? _focus,
      mouseCursor: widget.disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.space): const ActivateIntent(),
        ..._keys(context),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          _press();
          return null;
        }),
        ..._keyActions(),
      },
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v && uiShowFocusRing),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: _press,
        onHorizontalDragStart: canSwitch
            ? (d) {
                _dragStart = d.globalPosition;
                _dragLast = d.globalPosition;
              }
            : null,
        onHorizontalDragUpdate: canSwitch ? (d) => _dragLast = d.globalPosition : null,
        onHorizontalDragEnd: canSwitch ? _dragEnd : null,
        onHorizontalDragCancel: canSwitch ? () => _dragStart = _dragLast = null : null,
        child: pill,
      ),
    );
    pill = Semantics(
      key: const ValueKey('ui-mswitch-pill'),
      container: true,
      button: true,
      enabled: !widget.disabled,
      focusable: true,
      label: sub == null ? label : '$label, $sub',
      hint: s.messengerSwitchHint,
      onTap: widget.disabled ? null : _press,
      onIncrease: canSwitch ? () => _step(1) : null,
      onDecrease: canSwitch ? () => _step(-1) : null,
      excludeSemantics: true,
      child: pill,
    );

    Widget chevron(bool next) => _Chevron(
          key: ValueKey(next ? 'ui-mswitch-next' : 'ui-mswitch-prev'),
          next: next,
          label: next ? s.messengerNextChannel : s.messengerPrevChannel,
          onTap: canSwitch ? () => _step(next ? 1 : -1) : null,
        );

    final dots = Semantics(
      key: const ValueKey('ui-mswitch-dots'),
      container: true,
      explicitChildNodes: true,
      label: s.messengerChannel,
      child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
        for (final a in widget.apps)
          _Dot(
            key: ValueKey('ui-mswitch-dot-${a.name}'),
            app: a,
            selected: a == app,
            focusNode: _dotFocus.putIfAbsent(a, () => FocusNode(debugLabel: 'messenger dot ${a.name}')),
            onTap: () => _select(a),
            shortcuts: _keys(context),
            actions: _keyActions(focusDot: true),
          ),
      ]),
    );

    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        key: const ValueKey('ui-mswitch'),
        constraints: const BoxConstraints(maxWidth: UiMessengerSwitch.maxWidth),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(spacing: t.space1, children: [chevron(false), Expanded(child: pill), chevron(true)]),
          SizedBox(height: t.space2),
          dots,
        ]),
      ),
    );
  }
}

/// Paints the pill: the previous app's fill under the current one fading in, as a stadium, with the
/// white hover/press veil. Telegram's gradient band is the pill's logo box.
class _PillFill extends CustomPainter {
  const _PillFill({required this.from, required this.to, required this.t, required this.veil});

  final UiMessengerApp from, to;
  final double t, veil;

  Paint _paint(UiMessengerApp app, Rect r, double opacity) {
    final g = UiMessengerBrand.fillGradient(app, height: r.height, logo: UiMessengerSwitch.logoSize(app)) as LinearGradient;
    final colors = g.colors.length == 1 ? [g.colors.first, g.colors.first] : g.colors;
    return Paint()
      ..shader = LinearGradient(
        begin: g.begin,
        end: g.end,
        stops: g.stops,
        colors: [for (final c in colors) c.withValues(alpha: c.a * opacity)],
      ).createShader(r);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(size.height / 2));
    if (t < 1 && from != to) canvas.drawRRect(rr, _paint(from, r, 1));
    canvas.drawRRect(rr, _paint(to, r, from == to ? 1 : t));
    if (veil > 0) canvas.drawRRect(rr, Paint()..color = UiMessengerBrand.logoWhite.withValues(alpha: veil));
  }

  @override
  bool shouldRepaint(_PillFill old) => old.from != from || old.to != to || old.t != t || old.veil != veil;
}

/// A 44x44 ghost chevron button.
class _Chevron extends StatelessWidget {
  const _Chevron({super.key, required this.next, required this.label, required this.onTap});

  final bool next;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final theme = context.uiTheme;
    return UiInteractive(
      onTap: onTap,
      enabled: onTap != null,
      semanticLabel: label,
      excludeChildSemantics: true,
      builder: (context, s) => Opacity(
        opacity: s.disabled ? 0.5 : 1,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.hovered || s.pressed ? t.surfaceHover : null,
            borderRadius: BorderRadius.circular(theme.radius()),
            boxShadow: s.focused ? t.focusRing : null,
          ),
          child: UiIcon(next ? HugeIcons.strokeRoundedArrowRight01 : HugeIcons.strokeRoundedArrowLeft01, size: 20, color: t.textMuted, matchTextDirection: true),
        ),
      ),
    );
  }
}

/// One channel dot: the app's logo on a 20px disc of its fill (Telegram: its own disc), in a 28px
/// target; the chosen one at full opacity with a 2px ring in the text colour 2px out, the others at
/// 0.45. A radio in a mutually exclusive group.
class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.app, required this.selected, required this.focusNode, required this.onTap, required this.shortcuts, required this.actions});

  final UiMessengerApp app;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final Map<ShortcutActivator, Intent> shortcuts;
  final Map<Type, Action<Intent>> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final fill = UiMessengerBrand.fill(app);
    return UiInteractive(
      onTap: onTap,
      focusNode: focusNode,
      button: false,
      checked: selected,
      semanticLabel: UiMessengerBrand.name(app),
      padTouchTarget: false,
      pressScale: false,
      shortcuts: shortcuts,
      actions: actions,
      builder: (context, s) => Semantics(
        inMutuallyExclusiveGroup: true,
        child: ExcludeSemantics(
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: selected ? Border.all(color: t.text, width: 2) : null,
              boxShadow: s.focused ? t.focusRing : null,
            ),
            child: Opacity(
              opacity: selected ? 1 : 0.45,
              child: app == UiMessengerApp.telegram
                  ? UiMessengerLogo(app, size: UiMessengerSwitch.dotLogoSize(app))
                  : Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: fill.first, shape: BoxShape.circle),
                      child: UiMessengerLogo(app, size: UiMessengerSwitch.dotLogoSize(app)),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
