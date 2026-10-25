import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/semantics.dart' show SemanticsService;
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

class UiHoldButtonState extends State<UiHoldButton> {
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
    return UiHoldActivator(
      onConfirmed: widget.onConfirmed,
      hold: widget.hold,
      confirmTitle: widget.confirmTitle,
      confirmMessage: widget.confirmMessage,
      confirmLabel: widget.confirmLabel,
      destructive: widget.destructive,
      fillColor: fg.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(r),
      builder: (context, focusNode, onActivate) => UiButton(
        label: widget.label,
        icon: widget.icon,
        variant: widget.variant,
        size: widget.size,
        block: widget.block,
        focusNode: focusNode,
        semanticLabel: widget.semanticLabel,
        semanticHint: widget.holdHint ?? context.uiStrings.holdHint,
        onPressed: onActivate,
        child: widget.child,
      ),
    );
  }
}

/// Press-and-hold for any button (0.44.0; what [UiHoldButton] and a [UiFab] with `hold` are built
/// on). [builder] gets the focus node and the activation callback to give the button (null when
/// disabled); a fill of [fillColor] grows across it from the inline start while it is held, clipped
/// to [borderRadius]. Held [hold] long (pointer, or Space / Enter), it calls [onConfirmed]; a tap, a
/// quick key press or a screen reader's activation opens the confirm dialog instead.
///
/// 0.47.2 (for a holding [UiNavAction], all off by default): [onTap] is called for a tap instead of
/// the dialog; [cancelOnMoveOff] cancels a hold when the pointer slides off the button; [ringBuilder]
/// draws the progress (0 to 1, and whether a hold is under way) instead of the fill; [announceProgress]
/// reads the progress out at each quarter ([UiStrings.holdProgress]) and a hold let go early
/// ([UiStrings.holdCancelled]).
class UiHoldActivator extends StatefulWidget {
  const UiHoldActivator({
    super.key,
    required this.builder,
    required this.onConfirmed,
    this.hold = const Duration(seconds: 2),
    this.confirmTitle,
    this.confirmMessage = '',
    this.confirmLabel,
    this.destructive = false,
    required this.fillColor,
    this.borderRadius = BorderRadius.zero,
    this.onTap,
    this.cancelOnMoveOff = false,
    this.ringBuilder,
    this.announceProgress = false,
  });

  final Widget Function(BuildContext context, FocusNode focusNode, VoidCallback? onActivate) builder;
  final VoidCallback? onConfirmed;
  final Duration hold;
  final String? confirmTitle;
  final String confirmMessage;
  final String? confirmLabel;
  final bool destructive;
  final Color fillColor;
  final BorderRadiusGeometry borderRadius;

  /// A tap, a quick key press or a screen reader's activation: called instead of the confirm dialog.
  final VoidCallback? onTap;

  /// Sliding the pointer off the button cancels the hold.
  final bool cancelOnMoveOff;

  /// Draws the hold's progress over the button instead of the fill: `progress` 0 to 1, `holding`
  /// while a hold is under way (or just completed).
  final Widget Function(BuildContext context, double progress, bool holding)? ringBuilder;

  /// Reads the hold's progress out at 25, 50 and 75%, and "Hold cancelled" when let go early.
  final bool announceProgress;

  @override
  State<UiHoldActivator> createState() => UiHoldActivatorState();
}

class UiHoldActivatorState extends State<UiHoldActivator> with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(vsync: this, duration: widget.hold)
    ..addStatusListener(_status)
    ..addListener(_tick);
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);
  bool _holding = false;
  bool _done = false;
  bool _pressed = false;
  Duration _pressLength = Duration.zero;

  /// The last quarter read out (0: none yet this hold).
  int _said = 0;

  /// How far the hold has got, 0 to 1 (for tests).
  double get progress => _fill.value;

  bool get _enabled => widget.onConfirmed != null;

  @override
  void didUpdateWidget(UiHoldActivator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fill.duration = widget.hold;
  }

  @override
  void dispose() {
    _fill.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Whether a hold is under way, or just completed and showing full.
  bool get holding => _holding || (_done && _fill.value > 0);

  void _announce(String message) {
    if (!widget.announceProgress || !mounted) return;
    SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
  }

  void _tick() {
    if (!_holding || !widget.announceProgress) return;
    final q = math.min(3, (_fill.value * 4).floor());
    if (q <= _said) return;
    _said = q;
    _announce(context.uiStrings.holdProgress.replaceAll('{percent}', '${q * 25}'));
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
    _said = 0;
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
    final tap = _pressLength < _kTap;
    // Let go before the end after a real try (not a tap, which opens the fallback instead).
    if (!tap) _announce(context.uiStrings.holdCancelled);
    return tap;
  }

  /// The pointer slid off: the hold is cancelled, and the release after it is no tap.
  void _cancelHold() {
    if (!_holding || _done) return;
    _end();
    // Long enough not to count as a tap when the button's own tap arrives.
    _pressLength = _kTap;
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
    final tap = widget.onTap;
    if (tap != null) {
      tap();
      return;
    }
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
    return Listener(
      onPointerDown: (e) {
        if (e.buttons == kPrimaryButton) _start();
      },
      onPointerUp: (_) => _end(),
      onPointerCancel: (_) => _end(),
      onPointerMove: widget.cancelOnMoveOff
          ? (e) {
              final box = context.findRenderObject();
              if (box is RenderBox && !(Offset.zero & box.size).contains(e.localPosition)) setState(_cancelHold);
            }
          : null,
      child: Stack(children: [
        widget.builder(context, _focus, _enabled ? _activated : null),
        if (widget.ringBuilder case final ring?)
          Positioned.fill(
            child: IgnorePointer(child: AnimatedBuilder(animation: _fill, builder: (context, _) => ring(context, _fill.value, holding))),
          )
        else
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: AnimatedBuilder(
                animation: _fill,
                builder: (context, _) => Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(widthFactor: _fill.value, heightFactor: 1, child: ColoredBox(color: widget.fillColor)),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
