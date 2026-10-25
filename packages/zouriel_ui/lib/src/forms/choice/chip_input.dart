import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../badge/badge.dart';
import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../theme/theme.dart';
import 'bare_input.dart';

/// A zero-width space kept at the start of the field. Soft keyboards send no key event for
/// Backspace in an empty field, but they do delete this, which is how "Backspace removes the last
/// chip" works on phones as well as with a hardware keyboard.
const String _sentinel = '​';

/// `ui-chip-input`: free-text tags. Enter or a comma adds the typed text (trimmed) as a chip;
/// Backspace in an empty field removes the last chip; each chip has a remove button. Duplicates are
/// kept, like the web. Null [onChanged] disables it.
class UiChipInput extends StatefulWidget {
  const UiChipInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.label,
    this.invalid = false,
    this.radius,
    this.focusNode,
  });

  final List<String> value;
  final ValueChanged<List<String>>? onChanged;

  /// [UiStrings.addTag] when null.
  final String? placeholder;

  /// Accessible name for the text field when no visible label names it.
  final String? label;

  /// Danger border (the web `aria-invalid`).
  final bool invalid;
  final bool? radius;
  final FocusNode? focusNode;

  @override
  State<UiChipInput> createState() => _UiChipInputState();
}

class _UiChipInputState extends State<UiChipInput> {
  final TextEditingController _ctrl = TextEditingController(text: _sentinel);
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'chip input'));

  bool get _enabled => widget.onChanged != null;
  String get _typed => _ctrl.text.startsWith(_sentinel) ? _ctrl.text.substring(1) : _ctrl.text;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_keepCaretAfterSentinel);
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(UiChipInput old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ctrl.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  void _keepCaretAfterSentinel() {
    final sel = _ctrl.selection;
    if (_ctrl.text.startsWith(_sentinel) && sel.isValid && (sel.start < 1 || sel.end < 1)) {
      _ctrl.selection = TextSelection(baseOffset: math.max(1, sel.baseOffset), extentOffset: math.max(1, sel.extentOffset));
    }
  }

  void _setText(String typed) {
    _ctrl.value = TextEditingValue(text: _sentinel + typed, selection: TextSelection.collapsed(offset: typed.length + 1));
  }

  void _changed(String text) {
    if (!text.startsWith(_sentinel)) {
      // The sentinel was deleted: Backspace at the very start.
      final rest = text.replaceAll(_sentinel, '');
      _setText(rest);
      if (rest.isEmpty && widget.value.isNotEmpty) widget.onChanged!(widget.value.sublist(0, widget.value.length - 1));
      setState(() {});
      return;
    }
    final typed = text.substring(1);
    if (typed.contains(',')) {
      final parts = typed.split(',');
      final added = parts.take(parts.length - 1).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      _setText(parts.last.trimLeft());
      if (added.isNotEmpty) widget.onChanged!([...widget.value, ...added]);
    }
    setState(() {});
  }

  void _submitted(String _) {
    final typed = _typed.trim();
    if (typed.isEmpty) return;
    _setText('');
    widget.onChanged!([...widget.value, typed]);
    _focus.requestFocus();
  }

  void _removeAt(int i) {
    if (!_enabled) return;
    widget.onChanged!([...widget.value]..removeAt(i));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final r = (widget.radius ?? theme.config.radius) ? t.radius : 0.0;
    final focused = _focus.hasFocus;
    final style = context.uiText.body.copyWith(fontSize: t.fontSizeMd, color: t.text, height: 1.35);
    final touch = uiTouchPlatform(context);
    final showPlaceholder = widget.value.isEmpty && _typed.isEmpty;

    return AnimatedOpacity(
      opacity: _enabled ? 1 : 0.5,
      duration: t.motionBase,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _enabled ? _focus.requestFocus : null,
        child: AnimatedContainer(
          duration: context.uiAnimate ? t.motionBase : Duration.zero,
          constraints: BoxConstraints(minHeight: touch ? uiMinTouchTarget : t.sizeMd),
          padding: EdgeInsets.symmetric(horizontal: t.space1, vertical: 2),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: widget.invalid ? t.danger : focused ? t.primary : t.controlBorder),
            borderRadius: BorderRadius.circular(r),
            boxShadow: !focused
                ? const []
                : widget.invalid
                    ? [UiRingShadow(color: t.danger, spread: 4), UiRingShadow(color: t.bg, spread: 2)]
                    : t.focusRing,
          ),
          child: LayoutBuilder(builder: (context, c) {
            final measure = TextPainter(text: TextSpan(text: _typed.isEmpty ? (showPlaceholder ? (widget.placeholder ?? context.uiStrings.addTag) : '') : _typed, style: style), textDirection: Directionality.of(context), maxLines: 1)
              ..layout();
            final entryW = (measure.width + t.space2 * 2 + 4).clamp(80.0, c.maxWidth);
            measure.dispose();
            return Wrap(
              spacing: t.space1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < widget.value.length; i++)
                  UiChip(label: widget.value[i], tone: UiStatus.primary, onRemove: _enabled ? () => _removeAt(i) : null),
                SizedBox(
                  width: entryW,
                  height: touch ? uiMinTouchTarget - 6 : 24,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: t.space2),
                    child: Stack(
                      alignment: AlignmentDirectional.centerStart,
                      children: [
                        if (showPlaceholder)
                          IgnorePointer(child: ExcludeSemantics(child: Text(widget.placeholder ?? context.uiStrings.addTag, maxLines: 1, style: style.copyWith(color: t.textMuted)))),
                        UiBareInput(
                          controller: _ctrl,
                          focusNode: _focus,
                          enabled: _enabled,
                          style: style,
                          semanticLabel: widget.label,
                          textInputAction: TextInputAction.done,
                          onChanged: _changed,
                          onSubmitted: _submitted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
