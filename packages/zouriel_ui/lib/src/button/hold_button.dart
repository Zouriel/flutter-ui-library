import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/types.dart';
import '../dialog/confirm.dart';
import '../theme/theme.dart';
import 'button.dart';

/// A press shorter than this is a tap, not an attempt to hold.
const Duration _kTap = Duration(milliseconds: 300);

/// `ui-hold-button`: press and hold to confirm, for an action that shouldn't happen on a stray tap
/// (start a visit, mark as arrived). A fill grows across the button while it is held, [hold] long;
/// letting go early cancels it. With a keyboard, Space or Enter held does the same. A light haptic
/// marks the start and a heavy one the confirmation.
///
/// Holding is not accessible to everyone, so a tap (shorter than 300ms), a screen reader's
/// double-tap or a quick Enter opens a confirm dialog instead, which confirms the same way. The
/// button is announced with [holdHint] ("Press and hold to confirm").
class UiHoldButton extends StatefulWidget {
  const UiHoldButton({
    super.key,
    this.label,
    this.child,
    required this.onConfirmed,
    this.hold = const Duration(seconds: 2),
    this.variant = UiButtonVariant.primary,
    this.size = UiSize.md,
    this.block = false,
    this.icon,
    this.semanticLabel,
    this.holdHint,
    this.confirmTitle,
    this.confirmMessage = '',
    this.confirmLabel,
    this.destructive = false,
  }) : assert(label != null || child != null, 'Give the hold button a label or a child.');

  final String? label;
  final Widget? child;

  /// Held to the end, or confirmed in the dialog. Null disables the button.
  final VoidCallback? onConfirmed;
  final Duration hold;
  final UiButtonVariant variant;
  final UiSize size;
  final bool block;
  final Widget? icon;
  final String? semanticLabel;

  /// What holding does, read with the button; defaults to [UiStrings.holdHint].
  final String? holdHint;

  /// The tap fallback dialog; titles default to [UiStrings.confirmTitle] and [UiStrings.confirm].
  final String? confirmTitle;
  final String confirmMessage;
  final String? confirmLabel;

  /// The dialog's confirm button is destructive.
  final bool destructive;

  @override
  State<UiHoldButton> createState() => UiHoldButtonState();
}

class UiHoldButtonState extends State<UiHoldButton> with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(vsync: this, duration: widget.hold)..addStatusListener(_status);
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);
  bool _holding = false;
  bool _done = false;
  bool _pressed = false;
  Duration _pressLength = Duration.zero;

  bool get _enabled => widget.onConfirmed != null;

  @override
  void didUpdateWidget(UiHoldButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fill.duration = widget.hold;
  }

  @override
  void dispose() {
    _fill.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _status(AnimationStatus s) {
    if (s != AnimationStatus.completed || !_pressed) return;
    _done = true;
    HapticFeedback.heavyImpact();
    widget.onConfirmed?.call();
    // Let the full fill show for a moment, then empty it.
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _fill.animateBack(0, duration: const Duration(milliseconds: 160));
    });
  }

  void _start() {
    if (!_enabled) return;
    _done = false;
    _pressed = true;
    _holding = true;
    HapticFeedback.selectionClick();
    _fill.duration = widget.hold;
    _fill.forward(from: 0);
  }

  /// Ends a press; returns whether it was a tap (short, not completed). The fill runs linearly from
  /// the press, so how far it got is how long the press lasted.
  bool _end() {
    if (!_holding) return false;
    _holding = false;
    _pressLength = widget.hold * _fill.value;
    _pressed = false;
    if (_done) return false;
    _fill.animateBack(0, duration: const Duration(milliseconds: 160));
    return _pressLength < _kTap;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final key = e.logicalKey;
    if (key != LogicalKeyboardKey.space && key != LogicalKeyboardKey.enter && key != LogicalKeyboardKey.numpadEnter) return KeyEventResult.ignored;
    if (e is KeyDownEvent) {
      if (!_holding) _start();
    } else if (e is KeyUpEvent) {
      final wasDone = _done;
      final tap = _end();
      if (wasDone) _done = false;
      if (tap) _confirmDialog();
    }
    // Ours: the button's own activation would open the dialog at once.
    return KeyEventResult.handled;
  }

  /// The button's activation: a tap, or a screen reader's double-tap (no press before it).
  void _activated() {
    if (_done) {
      _done = false;
      return;
    }
    // A press that lasted was an attempt to hold that was let go: it only cancels.
    if (_pressLength >= _kTap) {
      _pressLength = Duration.zero;
      return;
    }
    _pressLength = Duration.zero;
    _confirmDialog();
  }

  Future<void> _confirmDialog() async {
    final s = context.uiStrings;
    final ok = await showUiConfirm(
      context: context,
      title: widget.confirmTitle ?? s.confirmTitle,
      message: widget.confirmMessage,
      confirmLabel: widget.confirmLabel ?? s.confirm,
      cancelLabel: s.cancel,
      destructive: widget.destructive,
    );
    if (ok == true && mounted) widget.onConfirmed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final rounded = theme.config.radius;
    final r = !rounded ? 0.0 : widget.variant == UiButtonVariant.brand ? t.radiusPill : widget.size == UiSize.xl ? t.radiusLg : t.radius;
    final fg = switch (widget.variant) {
      UiButtonVariant.primary || UiButtonVariant.brand => t.primaryContrast,
      UiButtonVariant.secondary => t.secondaryContrast,
      UiButtonVariant.destructive => t.dangerContrast,
      UiButtonVariant.accent => t.accentContrast,
      _ => t.text,
    };
    final button = UiButton(
      label: widget.label,
      icon: widget.icon,
      variant: widget.variant,
      size: widget.size,
      block: widget.block,
      focusNode: _focus,
      semanticLabel: widget.semanticLabel,
      semanticHint: widget.holdHint ?? context.uiStrings.holdHint,
      onPressed: _enabled ? _activated : null,
      child: widget.child,
    );
    return Listener(
        onPointerDown: (e) {
          if (e.buttons == kPrimaryButton) _start();
        },
        onPointerUp: (_) => _end(),
        onPointerCancel: (_) => _end(),
        child: Stack(children: [
          button,
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(r),
                child: AnimatedBuilder(
                  animation: _fill,
                  builder: (context, _) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(widthFactor: _fill.value, heightFactor: 1, child: ColoredBox(color: fg.withValues(alpha: 0.22))),
                  ),
                ),
              ),
            ),
          ),
        ]),
    );
  }
}
