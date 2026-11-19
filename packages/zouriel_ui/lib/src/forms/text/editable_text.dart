import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../core/on_media.dart';
import '../../theme/theme.dart';
import '../../text/text.dart';
import 'form_field.dart';
import 'text_core.dart';

/// `ui-editable-text`: click-to-edit inline text.
///
/// Shows the text as a button (with a pencil, always visible on touch screens, on hover or focus
/// otherwise). Tapping it, or Enter/Space, opens a field with the text selected; Enter or leaving
/// the field commits, Escape cancels.
class UiEditableText extends StatefulWidget {
  const UiEditableText({
    super.key,
    required this.value,
    this.onChanged,
    this.placeholder,
    this.enabled = true,
    this.semanticLabel,
    this.style,
    this.variant,
    this.flush = false,
    this.block = false,
    this.onMedia = false,
  });

  final String value;
  final ValueChanged<String>? onChanged;

  /// [UiStrings.empty] when null.
  final String? placeholder;
  final bool enabled;

  /// Accessible name, e.g. "Board name"; announced with the current text.
  final String? semanticLabel;

  /// Text style override (defaults to body text).
  final TextStyle? style;

  /// Typography from [UiText]. Null keeps the body default; [style] can refine or override it.
  final UiTextVariant? variant;

  /// Line the text up with what's above and below it (a label, a heading): the hover outline and the field reach
  /// out to the start instead of indenting the text by their padding and border (0.82.0). Off by default.
  final bool flush;

  /// Fill the available row instead of hugging the text.
  final bool block;

  /// Light, shadowed view text over photography. Also adopted from [UiOnMediaScope].
  final bool onMedia;

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
    var style = UiText.styleOf(context, widget.variant ?? UiTextVariant.body);
    if (widget.style != null) style = style.merge(widget.style);
    style = style.copyWith(fontSize: style.fontSize ?? t.fontSizeMd, height: style.height ?? 1.35);
    final media = widget.onMedia || UiOnMediaScope.active(context);
    final viewStyle = media && widget.style?.color == null
        ? style.copyWith(color: t.mediaOnScrim, shadows: [Shadow(color: t.mediaScrim.withValues(alpha: 0.55), offset: const Offset(0, 1), blurRadius: 4)])
        : style;
    final r = BorderRadius.circular(theme.radius());
    final pad = EdgeInsets.symmetric(horizontal: t.space2, vertical: 2);
    final label = widget.semanticLabel ?? UiFieldScope.maybeOf(context)?.label;

    if (_editing) {
      Widget field = Container(
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
        );
      if (!widget.block) field = IntrinsicWidth(child: field);
      return _flushed(context, _sized(Align(alignment: AlignmentDirectional.centerStart, widthFactor: widget.block ? null : 1, heightFactor: 1, child: field)));
    }

    final touch = uiTouchPlatform(context);
    final empty = widget.value.isEmpty;
    final placeholder = widget.placeholder ?? context.uiStrings.empty;
    // Inline: it hugs its text at the start of the line, even in a stretching column.
    final view = UiInteractive(
      onTap: _edit,
      enabled: widget.enabled,
      focusNode: _viewFocus,
      cursor: SystemMouseCursors.text,
      pressScale: false,
      semanticLabel: label == null ? null : '$label: ${empty ? placeholder : widget.value}',
      semanticHint: 'Edit',
      excludeChildSemantics: label != null,
      builder: (context, s) => AnimatedContainer(
        duration: t.motionFast,
        padding: pad,
        decoration: BoxDecoration(
          color: media && s.hovered ? t.mediaScrim.withValues(alpha: 0.28) : null,
          border: Border.all(color: s.hovered ? (media ? t.mediaOnScrim.withValues(alpha: 0.45) : t.border) : const Color(0x00000000)),
          borderRadius: r,
          boxShadow: s.focused ? t.focusRing : const [],
        ),
        child: Row(mainAxisSize: widget.block ? MainAxisSize.max : MainAxisSize.min, spacing: t.space2, children: [
          Flexible(child: Text(empty ? placeholder : widget.value, style: empty ? viewStyle.copyWith(color: media ? t.mediaOnScrim.withValues(alpha: 0.75) : t.textMuted) : viewStyle)),
          // Touch has no hover, so the edit affordance is always shown there.
          AnimatedOpacity(
            opacity: touch || s.hovered || s.focused ? 1 : 0,
            duration: t.motionFast,
            child: UiIcon(HugeIcons.strokeRoundedEdit02, size: 13, color: media ? t.mediaOnScrim : t.textMuted),
          ),
        ]),
      ),
    );
    return _flushed(context, _sized(Align(alignment: AlignmentDirectional.centerStart, widthFactor: widget.block ? null : 1, heightFactor: 1, child: view)));
  }

  Widget _sized(Widget child) => widget.block ? SizedBox(width: double.infinity, child: child) : child;

  /// [UiEditableText.flush]: moved back by the box's padding and border, toward the start of the line.
  Widget _flushed(BuildContext context, Widget child) {
    if (!widget.flush) return child;
    final x = context.uiTheme.tokens.space2 + 1;
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    return Transform.translate(offset: Offset(rtl ? x : -x, 0), child: child);
  }
}
