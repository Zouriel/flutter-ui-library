import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// The visual states of an interactive widget.
@immutable
class UiStates {
  const UiStates({this.hovered = false, this.pressed = false, this.focused = false, this.disabled = false});

  final bool hovered;

  /// Finger or mouse button down (the web `:active`).
  final bool pressed;

  /// Keyboard focus that should show a ring (the web `:focus-visible`), not focus from a tap.
  final bool focused;
  final bool disabled;

  bool get interactive => !disabled;
}

/// Whether controls should pad their hit area to the platform's minimum touch target.
bool uiTouchPlatform(BuildContext context) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return true;
    default:
      return false;
  }
}

/// Minimum touch target on phones and tablets (Android guideline: 48dp).
const double uiMinTouchTarget = 48;

/// Shared behaviour for every tappable component: hover, press, keyboard focus (with a visible
/// ring only for keyboard users), Enter/Space activation, disabled state, semantics, a mouse
/// cursor, and a touch target of at least [uiMinTouchTarget] on touch platforms without changing
/// the visual size.
///
/// [builder] paints the component from its [UiStates].
class UiInteractive extends StatefulWidget {
  const UiInteractive({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.semanticHint,
    this.button = true,
    this.toggled,
    this.selected,
    this.checked,
    this.excludeChildSemantics = false,
    this.cursor = SystemMouseCursors.click,
    this.padTouchTarget = true,
    this.pressScale = true,
    this.shortcuts,
    this.actions,
    this.onFocusChange,
  });

  final Widget Function(BuildContext context, UiStates states) builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;
  final String? semanticHint;

  /// Announce as a button (most controls); set false for rows, tiles and custom roles.
  final bool button;
  final bool? toggled;
  final bool? selected;
  final bool? checked;
  final bool excludeChildSemantics;
  final MouseCursor cursor;

  /// Grow the hit area (not the visual) to [uiMinTouchTarget] on touch platforms.
  final bool padTouchTarget;

  /// Shrink slightly while pressed (the web `--ui-scale-press`).
  final bool pressScale;
  final Map<ShortcutActivator, Intent>? shortcuts;
  final Map<Type, Action<Intent>>? actions;
  final ValueChanged<bool>? onFocusChange;

  @override
  State<UiInteractive> createState() => _UiInteractiveState();
}

class _UiInteractiveState extends State<UiInteractive> {
  bool _hovered = false, _pressed = false, _focused = false;

  bool get _enabled => widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _activate() {
    if (!_enabled) return;
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final states = UiStates(hovered: _hovered && _enabled, pressed: _pressed && _enabled, focused: _focused && _enabled, disabled: !_enabled);
    Widget visual = widget.builder(context, states);
    if (widget.pressScale && context.uiAnimate) {
      visual = AnimatedScale(
        scale: states.pressed ? t.scalePress : 1,
        duration: t.motionFast,
        curve: t.easeStandard,
        child: visual,
      );
    }

    Widget result = FocusableActionDetector(
      enabled: _enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: _enabled ? widget.cursor : SystemMouseCursors.forbidden,
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.space): const ActivateIntent(),
        ...?widget.shortcuts,
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          _activate();
          return null;
        }),
        ...?widget.actions,
      },
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      onFocusChange: widget.onFocusChange,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: _enabled && widget.onTap != null ? _activate : null,
        onLongPress: _enabled ? widget.onLongPress : null,
        excludeFromSemantics: true,
        child: widget.padTouchTarget && uiTouchPlatform(context) ? UiTouchTarget(child: visual) : visual,
      ),
    );

    // Merge the child's text into this node so the control is one labelled element
    // ("Save, button"), not a button with a separate text node beside it.
    return MergeSemantics(
      child: Semantics(
      container: true,
      button: widget.button,
      enabled: _enabled,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      toggled: widget.toggled,
      selected: widget.selected,
      checked: widget.checked,
      focusable: _enabled,
      onTap: _enabled && widget.onTap != null ? _activate : null,
      onLongPress: _enabled ? widget.onLongPress : null,
      excludeSemantics: widget.excludeChildSemantics,
      child: result,
      ),
    );
  }
}

/// Lays its child out at its own size but takes at least [minSize] in each direction, centring
/// the child, so the hit area meets the touch minimum while the visual stays compact (like the
/// web's invisible `::before` hit slop and Material's padded tap targets).
class UiTouchTarget extends SingleChildRenderObjectWidget {
  const UiTouchTarget({super.key, this.minSize = const Size(uiMinTouchTarget, uiMinTouchTarget), super.child});

  final Size minSize;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderUiTouchTarget(minSize);

  @override
  void updateRenderObject(BuildContext context, RenderUiTouchTarget renderObject) => renderObject.minSize = minSize;
}

class RenderUiTouchTarget extends RenderShiftedBox {
  RenderUiTouchTarget(this._minSize) : super(null);

  Size _minSize;
  set minSize(Size v) {
    if (v == _minSize) return;
    _minSize = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final c = child!;
    c.layout(constraints.loosen(), parentUsesSize: true);
    final w = c.size.width < _minSize.width ? _minSize.width : c.size.width;
    final h = c.size.height < _minSize.height ? _minSize.height : c.size.height;
    size = constraints.constrain(Size(w, h));
    (c.parentData! as BoxParentData).offset = Alignment.center.alongOffset(size - c.size as Offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    // Anywhere in the padded area counts as a hit on the child.
    final c = child!;
    return c.hitTest(result, position: c.size.center(Offset.zero)) || super.hitTest(result, position: position);
  }

  @override
  double computeMinIntrinsicWidth(double h) => (child?.getMinIntrinsicWidth(h) ?? 0).clamp(_minSize.width, double.infinity);
  @override
  double computeMaxIntrinsicWidth(double h) => (child?.getMaxIntrinsicWidth(h) ?? 0).clamp(_minSize.width, double.infinity);
  @override
  double computeMinIntrinsicHeight(double w) => (child?.getMinIntrinsicHeight(w) ?? 0).clamp(_minSize.height, double.infinity);
  @override
  double computeMaxIntrinsicHeight(double w) => (child?.getMaxIntrinsicHeight(w) ?? 0).clamp(_minSize.height, double.infinity);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final s = child?.getDryLayout(constraints.loosen()) ?? Size.zero;
    return constraints.constrain(Size(s.width < _minSize.width ? _minSize.width : s.width, s.height < _minSize.height ? _minSize.height : s.height));
  }
}

/// The library focus ring: the web `--ui-focus-ring` (a 2px gap in the background colour, then a
/// 2px ring in the focus colour), drawn as box shadows that follow the shape's corners.
List<BoxShadow> uiFocusRing(UiTokens t, {bool show = true}) => show ? t.focusRing : const [];
