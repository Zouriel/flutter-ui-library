import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../button/button.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/app.dart';
import '../theme/theme.dart';
import 'drawer.dart';
import 'route.dart';

/// One row of a [UiActionSheet], the web `UiActionSheetAction` (0.61.0).
@immutable
class UiActionSheetAction<T> {
  const UiActionSheetAction({required this.label, required this.value, this.icon, this.danger = false, this.disabled = false});

  final String label;

  /// What [showUiActionSheet] completes with when this row is tapped.
  final T value;

  /// A 20px leading icon.
  final UiIconData? icon;

  /// Destructive (Remove, Delete): drawn in the danger colour, icon too, and placed after the
  /// other rows whatever its position in the list.
  final bool danger;

  /// Shown dimmed, can't be chosen, and skipped by the arrow keys.
  final bool disabled;
}

/// Opens a [UiActionSheet] (0.61.0): a compact bottom drawer with a handle, sized to its content,
/// listing [actions]. Completes with the tapped action's value, or null when closed another way
/// (the backdrop, a swipe down, Escape, the back button, or the Cancel button).
Future<T?> showUiActionSheet<T>({
  required BuildContext context,
  String? title,
  String? message,
  required List<UiActionSheetAction<T>> actions,
  String? cancelLabel,
  bool useRootNavigator = true,
}) {
  final t = context.ui;
  return uiNavigatorOf(context, rootNavigator: useRootNavigator).push<T>(
    UiDialogRoute<T>.themed(
      context,
      duration: t.motionSlow,
      reverse: t.motionBase,
      transitions: (context, animation, child) => uiSheetTransition(context, animation, child, UiDrawerSide.bottom),
      builder: (context) => UiActionSheet<T>(
        title: title,
        message: message,
        actions: actions,
        cancelLabel: cancelLabel,
        onSelected: (v) => Navigator.pop(context, v),
      ),
    ),
  );
}

/// `ui-action-sheet`: a short list of actions in a bottom drawer with a drag handle, sized to its
/// content (up to 90% of the room, then the rows scroll). An optional [title] (a guest's name, say)
/// and a muted [message] sit above full-width rows (48px tall, a 20px icon and the label). Danger
/// rows are red, icon included, and always come after the others, in their given order. With
/// [cancelLabel] a Cancel button closes it at the end ('' for the built-in [UiStrings.cancel]).
/// Focus starts on the first action and the arrow keys (Home, End) move between rows.
/// Open it with [showUiActionSheet], which gives it the route, backdrop and back-button closing.
class UiActionSheet<T> extends StatefulWidget {
  const UiActionSheet({super.key, this.title, this.message, required this.actions, this.cancelLabel, required this.onSelected, this.onCancel});

  final String? title;
  final String? message;
  final List<UiActionSheetAction<T>> actions;

  /// The Cancel button's label; null: no Cancel button; '': the built-in [UiStrings.cancel].
  final String? cancelLabel;

  /// A row was tapped.
  final ValueChanged<T> onSelected;

  /// Cancel was pressed; null: pops the route (completing with null).
  final VoidCallback? onCancel;

  /// [actions] in the order shown: the non-danger rows, then the danger ones, each keeping its order.
  static List<UiActionSheetAction<T>> ordered<T>(List<UiActionSheetAction<T>> actions) => [
        ...actions.where((a) => !a.danger),
        ...actions.where((a) => a.danger),
      ];

  @override
  State<UiActionSheet<T>> createState() => _UiActionSheetState<T>();
}

class _UiActionSheetState<T> extends State<UiActionSheet<T>> {
  final List<FocusNode> _nodes = [];
  late List<UiActionSheetAction<T>> _rows;

  void _sync() {
    _rows = UiActionSheet.ordered(widget.actions);
    while (_nodes.length < _rows.length) {
      _nodes.add(FocusNode(debugLabel: 'UiActionSheet row ${_nodes.length}'));
    }
    while (_nodes.length > _rows.length) {
      _nodes.removeLast().dispose();
    }
  }

  List<int> get _enabled => [for (var i = 0; i < _rows.length; i++) if (!_rows[i].disabled) i];

  @override
  void initState() {
    super.initState();
    _sync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final e = _enabled;
      if (mounted && e.isNotEmpty) _nodes[e.first].requestFocus();
    });
  }

  @override
  void didUpdateWidget(UiActionSheet<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final en = _enabled;
    if (en.isEmpty) return KeyEventResult.ignored;
    final cur = en.indexWhere((i) => _nodes[i].hasPrimaryFocus);
    int? next;
    if (k == LogicalKeyboardKey.arrowDown) {
      next = (cur + 1) % en.length;
    } else if (k == LogicalKeyboardKey.arrowUp) {
      next = cur < 0 ? en.length - 1 : (cur - 1 + en.length) % en.length;
    } else if (k == LogicalKeyboardKey.home) {
      next = 0;
    } else if (k == LogicalKeyboardKey.end) {
      next = en.length - 1;
    }
    if (next == null) return KeyEventResult.ignored;
    _nodes[en[next]].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final title = widget.title, message = widget.message;
    final hasHeader = (title != null && title.isNotEmpty) || (message != null && message.isNotEmpty);
    final cancel = widget.cancelLabel == null ? null : (widget.cancelLabel!.isEmpty ? context.uiStrings.cancel : widget.cancelLabel!);
    return UiDrawer(
      side: UiDrawerSide.bottom,
      handle: true,
      fit: UiDrawerFit.content,
      semanticLabel: title,
      header: !hasHeader
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: t.space1,
              children: [
                if (title != null && title.isNotEmpty)
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, fontSize: t.fontSizeMd, letterSpacing: t.trackingTight * t.fontSizeMd, height: 1.35, color: t.text),
                    ),
                  ),
                if (message != null && message.isNotEmpty)
                  Text(message, style: theme.typography.body.copyWith(fontSize: t.fontSizeSm, height: 1.35, color: t.textMuted)),
              ],
            ),
      footer: cancel == null
          ? null
          : UiButton(label: cancel, variant: UiButtonVariant.outline, block: true, onPressed: widget.onCancel ?? () => Navigator.maybePop(context)),
      bodyBuilder: (context, controller) => SingleChildScrollView(
        controller: controller,
        padding: EdgeInsets.symmetric(vertical: t.space2),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _onKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _rows.length; i++)
                _ActionRow<T>(action: _rows[i], focusNode: _nodes[i], onTap: () => widget.onSelected(_rows[i].value)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow<T> extends StatelessWidget {
  const _ActionRow({super.key, required this.action, required this.focusNode, required this.onTap});

  final UiActionSheetAction<T> action;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    return UiInteractive(
      onTap: onTap,
      enabled: !action.disabled,
      focusNode: focusNode,
      padTouchTarget: false,
      pressScale: false,
      semanticLabel: action.label,
      excludeChildSemantics: true,
      builder: (context, s) {
        final fg = action.danger ? t.danger : t.text;
        final lit = s.hovered || s.focused || s.pressed;
        final fill = !lit ? null : action.danger ? uiMix(t.danger, 0.12, const Color(0x00000000)) : t.surfaceHover;
        return AnimatedOpacity(
          opacity: s.disabled ? 0.5 : 1,
          duration: t.motionFast,
          child: AnimatedContainer(
            duration: context.uiAnimate ? t.motionFast : Duration.zero,
            curve: t.easeStandard,
            constraints: const BoxConstraints(minHeight: uiMinTouchTarget),
            padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space3),
            decoration: BoxDecoration(
              color: fill,
              // Keyboard focus also gets an inset ring, so it never reads like a hover.
              border: Border.all(color: s.focused ? t.borderFocus : const Color(0x00000000), width: 2),
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: action.danger ? fg : (t.icon ?? fg), size: 20),
              child: DefaultTextStyle.merge(
                style: theme.typography.body.copyWith(fontSize: t.fontSizeMd, height: 1.35, color: fg),
                child: Row(
                  spacing: t.space3,
                  children: [
                    if (action.icon != null) UiIcon(action.icon!),
                    Expanded(child: Text(action.label)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
