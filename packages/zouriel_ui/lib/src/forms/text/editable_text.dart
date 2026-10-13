import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../theme/theme.dart';
import 'form_field.dart';
import 'text_core.dart';

/// `ui-editable-text`: click-to-edit inline text.
///
/// Shows the text as a button (with a pencil, always visible on touch screens, on hover or focus
/// otherwise). Tapping it, or Enter/Space, opens a field with the text selected; Enter or leaving
/// the field commits, Escape cancels.
class UiEditableText extends StatefulWidget {
  const UiEditableText({super.key, required this.value, this.onChanged, this.placeholder = 'Empty', this.enabled = true, this.semanticLabel, this.style});

  final String value;
  final ValueChanged<String>? onChanged;
  final String placeholder;
  final bool enabled;

  /// Accessible name, e.g. "Board name"; announced with the current text.
  final String? semanticLabel;

  /// Text style override (defaults to body text).
  final TextStyle? style;

  @override
  State<UiEditableText> createState() => _UiEditableTextState();
}

class _UiEditableTextState extends State<UiEditableText> {
  final TextEditingController _draft = TextEditingController();
  final FocusNode _fieldFocus = FocusNode();
  final FocusNode _viewFocus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _fieldFocus.addListener(() {
      if (!_fieldFocus.hasFocus && _editing) _commit();
    });
  }

  @override
  void dispose() {
    _draft.dispose();
    _fieldFocus.dispose();
    _viewFocus.dispose();
    super.dispose();
  }

  void _edit() {
    if (!widget.enabled) return;
    _draft.value = TextEditingValue(text: widget.value, selection: TextSelection(baseOffset: 0, extentOffset: widget.value.length));
    setState(() => _editing = true);
    // Focus once the field exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editing) _fieldFocus.requestFocus();
    });
  }

  void _commit() {
    if (!_editing) return;
    final v = _draft.text;
    setState(() => _editing = false);
    if (v != widget.value) widget.onChanged?.call(v);
    _refocusView();
  }

  void _cancel() {
    setState(() => _editing = false);
    _refocusView();
  }

  void _refocusView() {
    if (!_fieldFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewFocus.requestFocus();
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      _cancel();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final style = (widget.style ?? context.uiText.body).copyWith(fontSize: widget.style?.fontSize ?? t.fontSizeMd, height: 1.35, color: t.text);
    final r = BorderRadius.circular(theme.radius());
    final pad = EdgeInsets.symmetric(horizontal: t.space2, vertical: 2);
    final label = widget.semanticLabel ?? UiFieldScope.maybeOf(context)?.label;

    if (_editing) {
      return IntrinsicWidth(
        child: Container(
          padding: pad,
          constraints: const BoxConstraints(minWidth: 120),
          decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.primary), borderRadius: r, boxShadow: t.focusRing),
          child: UiTextEditor(
            controller: _draft,
            focusNode: _fieldFocus,
            style: style,
            onSubmitted: (_) => _commit(),
            onKeyEvent: _onKey,
            semanticLabel: label,
          ),
        ),
      );
    }

    final touch = uiTouchPlatform(context);
    final empty = widget.value.isEmpty;
    return UiInteractive(
      onTap: _edit,
      enabled: widget.enabled,
      focusNode: _viewFocus,
      cursor: SystemMouseCursors.text,
      pressScale: false,
      semanticLabel: label == null ? null : '$label: ${empty ? widget.placeholder : widget.value}',
      semanticHint: 'Edit',
      excludeChildSemantics: label != null,
      builder: (context, s) => AnimatedContainer(
        duration: t.motionFast,
        padding: pad,
        decoration: BoxDecoration(
          border: Border.all(color: s.hovered ? t.border : const Color(0x00000000)),
          borderRadius: r,
          boxShadow: s.focused ? t.focusRing : const [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
          Flexible(child: Text(empty ? widget.placeholder : widget.value, style: empty ? style.copyWith(color: t.textMuted) : style)),
          // Touch has no hover, so the edit affordance is always shown there.
          AnimatedOpacity(
            opacity: touch || s.hovered || s.focused ? 1 : 0,
            duration: t.motionFast,
            child: UiIcon(HugeIcons.strokeRoundedEdit02, size: 13, color: t.textMuted),
          ),
        ]),
      ),
    );
  }
}
