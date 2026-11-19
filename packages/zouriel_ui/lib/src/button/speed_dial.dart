import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../feedback/shutter_loader.dart';
import '../theme/theme.dart';
import 'fab.dart';

/// One action stacked above a [UiSpeedDial] trigger (the web `UiSpeedDialAction`).
@immutable
class UiSpeedDialAction {
  const UiSpeedDialAction({
    required this.id,
    required this.label,
    required this.icon,
    this.disabled = false,
  });

  final String id;
  final String label;
  final Widget icon;
  final bool disabled;
}

/// `ui-speed-dial`: a floating action button that expands into a stack of smaller round action FABs
/// above the trigger, each paired with a label pill to its inline-start side.
///
/// Place it inside [UiFabHost] (as `fab:`) or anywhere in a layout; the open action stack renders in
/// the nearest [Overlay] directly above the trigger.
///
/// - Without [icon], draws a `+` that rotates 45° into an `×` while open ([rotateIcon]).
/// - Pass a [UiShutterLoader] as [icon] and it automatically stays still at rest (without rotating)
///   and plays one burst cycle each time the dial opens or closes.
/// - Works uncontrolled (`open == null`) or controlled (`open` + `onOpenChanged`).
/// - Tapping either an action's round FAB or its label pill closes the dial and calls [onAction].
/// - Dismisses on an outside tap or Escape (restoring focus to the trigger), announces its expanded
///   state, and skips motion when `context.uiAnimate` is false.
class UiSpeedDial extends StatefulWidget {
  const UiSpeedDial({
    super.key,
    required this.actions,
    required this.label,
    this.closeLabel,
    this.actionsLabel,
    this.open,
    this.onOpenChanged,
    this.onAction,
    this.icon,
    this.rotateIcon,
    this.tone = UiFabTone.primary,
    this.size = UiFabSize.md,
    this.disabled = false,
    this.focusNode,
  });

  /// Actions stacked above the trigger (index 0 sits closest to the trigger).
  final List<UiSpeedDialAction> actions;

  /// Accessible name of the trigger while closed.
  final String label;

  /// Accessible name of the trigger while open; defaults to [label].
  final String? closeLabel;

  /// Accessible name of the open actions group; defaults to [label].
  final String? actionsLabel;

  /// Controlled open state; leave null to manage open/closed internally.
  final bool? open;

  /// Called when the dial opens or closes.
  final ValueChanged<bool>? onOpenChanged;

  /// Called with the chosen action's [UiSpeedDialAction.id] after closing the dial.
  final ValueChanged<String>? onAction;

  /// Custom trigger icon (e.g. a [UiShutterLoader]); defaults to a `+` icon.
  final Widget? icon;

  /// Whether the trigger icon rotates 45° when open; null rotates unless [icon] is a [UiShutterLoader].
  final bool? rotateIcon;

  /// Colour tone applied to both the trigger and action FABs.
  final UiFabTone tone;

  /// Trigger FAB diameter; action FABs are always [UiFabSize.sm].
  final UiFabSize size;

  /// Disables the trigger (and closes the dial if currently open).
  final bool disabled;

  /// Optional focus node for the trigger FAB.
  final FocusNode? focusNode;

  @override
  State<UiSpeedDial> createState() => _UiSpeedDialState();
}

class _UiSpeedDialState extends State<UiSpeedDial> with SingleTickerProviderStateMixin {
  final OverlayPortalController _overlay = OverlayPortalController();
  final UiShutterLoaderController _shutter = UiShutterLoaderController();
  FocusNode? _ownedFocus;
  late final AnimationController _anim;
  bool _internalOpen = false;
  late bool _wasOpen;
  bool _keyAttached = false;

  FocusNode get _triggerFocus => widget.focusNode ?? (_ownedFocus ??= FocusNode(debugLabel: 'speed dial trigger'));
  bool get _isOpen => !widget.disabled && (widget.open ?? _internalOpen);
  bool get _shouldRotate => widget.rotateIcon ?? (widget.icon is! UiShutterLoader);

  Duration _openDuration(UiTokens t) =>
      Duration(milliseconds: t.motionBase.inMilliseconds + math.max(0, widget.actions.length - 1) * 45);

  Duration _closeDuration(UiTokens t) =>
      Duration(milliseconds: t.motionFast.inMilliseconds + math.max(0, widget.actions.length - 1) * 30);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 200), reverseDuration: const Duration(milliseconds: 120));
    _anim.addStatusListener(_onAnimStatus);
    _wasOpen = _isOpen;
    if (_isOpen) {
      _anim.value = 1;
      _attachKey();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isOpen && !_overlay.isShowing) _overlay.show();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final t = context.ui;
    _anim.duration = _openDuration(t);
    _anim.reverseDuration = _closeDuration(t);
  }

  @override
  void didUpdateWidget(UiSpeedDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    final t = context.ui;
    _anim.duration = _openDuration(t);
    _anim.reverseDuration = _closeDuration(t);
    if (widget.disabled && _internalOpen) {
      _internalOpen = false;
    }
    final next = _isOpen;
    if (next != _wasOpen) {
      _applyOpenTransition(next);
    }
  }

  @override
  void dispose() {
    _detachKey();
    _anim.removeStatusListener(_onAnimStatus);
    _anim.dispose();
    _shutter.dispose();
    _ownedFocus?.dispose();
    super.dispose();
  }

  void _showOverlay() {
    if (_overlay.isShowing) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isOpen && !_overlay.isShowing) _overlay.show();
      });
    } else {
      _overlay.show();
    }
  }

  void _hideOverlay() {
    if (!_overlay.isShowing) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isOpen && _overlay.isShowing) _overlay.hide();
      });
    } else {
      _overlay.hide();
    }
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _overlay.isShowing && !_isOpen) {
      _hideOverlay();
    }
  }

  void _attachKey() {
    if (_keyAttached) return;
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _keyAttached = true;
  }

  void _detachKey() {
    if (!_keyAttached) return;
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _keyAttached = false;
  }

  bool _onHardwareKey(KeyEvent e) {
    if (!_isOpen) return false;
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
      _close(restoreFocus: true);
      return true;
    }
    return false;
  }

  void _applyOpenTransition(bool next) {
    _wasOpen = next;
    _shutter.play();
    final animate = context.uiAnimate;
    if (next) {
      _attachKey();
      _showOverlay();
      if (animate) {
        _anim.forward();
      } else {
        _anim.value = 1;
      }
    } else {
      _detachKey();
      if (animate) {
        _anim.reverse();
      } else {
        _anim.value = 0;
        _hideOverlay();
      }
    }
  }

  void _setOpen(bool next, {bool restoreFocus = false}) {
    if (widget.disabled && next) return;
    if (next == _isOpen) return;
    if (widget.open == null) {
      setState(() => _internalOpen = next);
      _applyOpenTransition(next);
      widget.onOpenChanged?.call(next);
    } else {
      widget.onOpenChanged?.call(next);
    }
    if (!next && restoreFocus) {
      _triggerFocus.requestFocus();
    }
  }

  void _toggle() => _setOpen(!_isOpen);

  void _close({bool restoreFocus = false}) => _setOpen(false, restoreFocus: restoreFocus);

  void _runAction(UiSpeedDialAction item) {
    if (item.disabled || !_isOpen) return;
    // The action leaves the focus tree as the overlay closes. Restore the trigger first; a surface
    // opened by onAction can then take focus from a valid node.
    _close(restoreFocus: true);
    widget.onAction?.call(item.id);
  }

  Widget _buildOverlay(BuildContext context, OverlayChildLayoutInfo info) {
    final t = context.ui;
    final anchor = MatrixUtils.transformRect(info.childPaintTransform, Offset.zero & info.childSize);
    final mq = MediaQuery.of(context);
    final dir = Directionality.of(context);
    final area = EdgeInsets.fromLTRB(
      mq.padding.left + 8,
      mq.padding.top + 8,
      mq.padding.right + 8,
      math.max(mq.padding.bottom, mq.viewInsets.bottom) + 8,
    ).deflateRect(Offset.zero & info.overlaySize);
    final rtl = dir == TextDirection.rtl;
    final spaceStart = rtl ? area.right - anchor.right : anchor.left - area.left;
    final spaceEnd = rtl ? anchor.left - area.left : area.right - anchor.right;
    // Label pills sit to the inline-start side by default; flip only when pinned against the start edge.
    final flip = spaceStart < 120 && spaceEnd > spaceStart;
    final animate = context.uiAnimate;
    final n = widget.actions.length;
    final openTotal = math.max(1, t.motionBase.inMilliseconds + math.max(0, n - 1) * 45);

    return Stack(
      children: [
        if (_isOpen)
          Positioned.fill(
            child: ExcludeSemantics(
              child: _ExcludeRect(
                rect: anchor,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _close(restoreFocus: false),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_isOpen,
            child: CustomSingleChildLayout(
              delegate: _SpeedDialStackLayout(
                anchor: anchor,
                gap: t.space3,
                area: area,
                textDirection: dir,
                flip: flip,
              ),
              child: Semantics(
                container: true,
                label: widget.actionsLabel ?? widget.label,
                explicitChildNodes: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: flip ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  spacing: t.space3,
                  children: [
                    for (var i = n - 1; i >= 0; i--)
                      _buildActionRow(context, t, widget.actions[i], i, openTotal, anchor.width, flip, animate),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow(
    BuildContext context,
    UiTokens t,
    UiSpeedDialAction item,
    int index,
    int openTotal,
    double slotWidth,
    bool flip,
    bool animate,
  ) {
    final start = (index * 45) / openTotal;
    final end = ((index * 45 + t.motionBase.inMilliseconds) / openTotal).clamp(0.0, 1.0);
    final pill = _SpeedDialPill(
      label: item.label,
      disabled: item.disabled,
      onTap: () => _runAction(item),
    );
    final slot = SizedBox(
      width: slotWidth,
      child: Center(
        child: UiFab(
          size: UiFabSize.sm,
          tone: widget.tone,
          label: item.label,
          icon: item.icon,
          onPressed: item.disabled ? null : () => _runAction(item),
        ),
      ),
    );
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: t.space2,
      children: flip ? [slot, pill] : [pill, slot],
    );
    if (!animate) return row;
    final motionCurve = Interval(start, end, curve: t.easeSpring);
    final reverseMotionCurve = Interval(start, end, curve: t.easeStandard);
    final opacityCurve = Interval(start, end, curve: t.easeDecelerate);
    final reverseOpacityCurve = Interval(start, end, curve: t.easeStandard);
    return AnimatedBuilder(
      animation: _anim,
      child: row,
      builder: (context, child) {
        final reversing = _anim.status == AnimationStatus.reverse;
        final m = (reversing ? reverseMotionCurve : motionCurve).transform(_anim.value);
        final o = (reversing ? reverseOpacityCurve : opacityCurve).transform(_anim.value).clamp(0.0, 1.0);
        return Opacity(
          opacity: o,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - m)),
            child: Transform.scale(
              scale: 0.95 + 0.05 * m,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final animate = context.uiAnimate;
    final triggerIcon = widget.icon ?? const UiIcon(HugeIcons.strokeRoundedAdd01);
    final rotatedIcon = AnimatedRotation(
      turns: _shouldRotate && _isOpen ? 0.125 : 0.0,
      duration: animate ? t.motionFast : Duration.zero,
      curve: t.easeStandard,
      child: UiShutterScope(controller: _shutter, child: triggerIcon),
    );
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _overlay,
      overlayChildBuilder: _buildOverlay,
      child: UiFab(
        focusNode: _triggerFocus,
        size: widget.size,
        tone: widget.tone,
        label: _isOpen ? (widget.closeLabel ?? widget.label) : widget.label,
        expanded: _isOpen,
        icon: rotatedIcon,
        onPressed: widget.disabled ? null : _toggle,
      ),
    );
  }
}

class _SpeedDialPill extends StatefulWidget {
  const _SpeedDialPill({required this.label, required this.disabled, required this.onTap});

  final String label;
  final bool disabled;
  final VoidCallback onTap;

  @override
  State<_SpeedDialPill> createState() => _SpeedDialPillState();
}

class _SpeedDialPillState extends State<_SpeedDialPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final animate = context.uiAnimate;
    return MouseRegion(
      cursor: widget.disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: widget.disabled ? null : widget.onTap,
        child: ExcludeSemantics(
          child: AnimatedOpacity(
            opacity: widget.disabled ? 0.5 : 1,
            duration: animate ? t.motionFast : Duration.zero,
            child: AnimatedContainer(
              duration: animate ? t.motionFast : Duration.zero,
              curve: t.easeStandard,
              constraints: BoxConstraints(minHeight: t.sizeSm),
              padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space1),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hovered && !widget.disabled ? t.elevatedHover : t.surfaceRaised,
                border: Border.all(color: t.border),
                borderRadius: BorderRadius.circular(t.radiusPill),
                boxShadow: t.shadow2,
              ),
              child: Text(
                widget.label,
                maxLines: 1,
                softWrap: false,
                style: context.uiText.body.copyWith(
                  fontSize: t.fontSizeSm,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  color: t.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Positions the speed dial's action stack directly above [anchor], lining up the action FAB slot
/// with [anchor]'s edge so the smaller round FABs sit centred over the trigger.
class _SpeedDialStackLayout extends SingleChildLayoutDelegate {
  _SpeedDialStackLayout({
    required this.anchor,
    required this.gap,
    required this.area,
    required this.textDirection,
    required this.flip,
  });

  final Rect anchor;
  final double gap;
  final Rect area;
  final TextDirection textDirection;
  final bool flip;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints(
        maxWidth: math.max(0, area.width),
        maxHeight: math.max(0, anchor.top - gap - area.top),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final rtl = textDirection == TextDirection.rtl;
    final alignRight = flip ? rtl : !rtl;
    var x = alignRight ? anchor.right - childSize.width : anchor.left;
    var y = anchor.top - gap - childSize.height;
    x = x.clamp(area.left, math.max(area.left, area.right - childSize.width));
    y = y.clamp(area.top, math.max(area.top, area.bottom - childSize.height));
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_SpeedDialStackLayout old) =>
      old.anchor != anchor || old.gap != gap || old.area != area || old.textDirection != textDirection || old.flip != flip;
}

/// Passes pointer hit tests inside [rect] through to widgets underneath (the trigger FAB) while
/// catching taps everywhere else on screen to dismiss the speed dial.
class _ExcludeRect extends SingleChildRenderObjectWidget {
  const _ExcludeRect({required this.rect, required super.child});
  final Rect rect;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderExcludeRect(rect);

  @override
  void updateRenderObject(BuildContext context, _RenderExcludeRect renderObject) => renderObject.rect = rect;
}

class _RenderExcludeRect extends RenderProxyBox {
  _RenderExcludeRect(this._rect);
  Rect _rect;
  set rect(Rect v) {
    if (v == _rect) return;
    _rect = v;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_rect.contains(position)) return false;
    return super.hitTest(result, position: position);
  }
}
