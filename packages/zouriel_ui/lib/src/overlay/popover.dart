import 'dart:ui' show SemanticsRole;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'anchored.dart';
import 'menu.dart';
import 'panel.dart';

/// Where a popover opens, the web `UiPopoverPlacement`.
enum UiPopoverPlacement { bottom, top, bottomStart, bottomEnd }

/// `ui-popover`: a floating panel that a trigger toggles.
///
/// [builder] draws the trigger and gets a `toggle` callback for it; [content] is the panel body.
/// A tap outside or Escape closes it. Focus is not moved into the panel (Tab reaches it after the
/// trigger); if focus is inside when Escape closes it, it goes back to the trigger. The panel is
/// a dialog named by [label]: give one, since Flutter can't borrow the trigger's text the way the
/// web's `aria-labelledby` does. It opens on [placement], flips above (or below) when there is no
/// room, and shifts sideways to stay on screen. 180 to 320px wide.
///
/// Uncontrolled by default; pass [open] and [onOpenChanged] to control it.
class UiPopover extends StatefulWidget {
  const UiPopover({
    super.key,
    required this.builder,
    required this.content,
    this.label,
    this.placement = UiPopoverPlacement.bottomStart,
    this.open,
    this.onOpenChanged,
    this.glass,
    this.radius,
  });

  final UiOverlayTriggerBuilder builder;
  final Widget content;
  final String? label;
  final UiPopoverPlacement placement;
  final bool? open;
  final ValueChanged<bool>? onOpenChanged;
  final bool? glass;
  final bool? radius;

  @override
  State<UiPopover> createState() => _UiPopoverState();
}

class _UiPopoverState extends State<UiPopover> {
  final OverlayPortalController _portal = OverlayPortalController();
  bool _open = false;
  FocusNode? _trigger;
  final FocusNode _panel = FocusNode(debugLabel: 'UiPopover panel', canRequestFocus: false, skipTraversal: true);

  bool get _isOpen => widget.open ?? _open;

  void _set(bool v) {
    if (v == _isOpen) return;
    if (v) _trigger = FocusManager.instance.primaryFocus;
    if (widget.open == null) setState(() => _open = v);
    widget.onOpenChanged?.call(v);
  }

  @override
  void dispose() {
    _panel.dispose();
    super.dispose();
  }

  /// Escape from inside the panel: close and put focus back on the trigger.
  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
      final back = _trigger;
      _set(false);
      if (back != null && back.context != null && back.canRequestFocus) back.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isOpen && !_portal.isShowing) _portal.show();
      if (!_isOpen && _portal.isShowing) _portal.hide();
    });
    final t = context.ui;
    final placement = switch (widget.placement) {
      UiPopoverPlacement.bottom => UiPlacement.bottom,
      UiPopoverPlacement.top => UiPlacement.top,
      UiPopoverPlacement.bottomStart => UiPlacement.bottomStart,
      UiPopoverPlacement.bottomEnd => UiPlacement.bottomEnd,
    };
    final origin = switch (widget.placement) {
      UiPopoverPlacement.bottom => Alignment.topCenter,
      UiPopoverPlacement.top => Alignment.bottomCenter,
      UiPopoverPlacement.bottomStart => AlignmentDirectional.topStart.resolve(Directionality.of(context)),
      UiPopoverPlacement.bottomEnd => AlignmentDirectional.topEnd.resolve(Directionality.of(context)),
    };
    return UiAnchoredOverlay(
      controller: _portal,
      placement: placement,
      onDismiss: () => _set(false),
      panelBuilder: (context, anchor) => Semantics(
        container: true,
        explicitChildNodes: true,
        role: SemanticsRole.dialog,
        label: widget.label,
        child: Focus(
          focusNode: _panel,
          onKeyEvent: _onKey,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 320),
            child: UiOverlayPanel(
              glass: widget.glass,
              radius: widget.radius,
              origin: origin,
              padding: EdgeInsets.all(t.space3),
              child: DefaultTextStyle.merge(style: const TextStyle(height: 1.35), child: widget.content),
            ),
          ),
        ),
      ),
      child: widget.builder(context, () => _set(!_isOpen), _isOpen),
    );
  }
}
