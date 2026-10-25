import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../theme/theme.dart';
import 'form_field.dart';
import 'text_core.dart';

/// Shows a number the way the web does: `3` not `3.0`.
String uiFormatNumber(num? v) {
  if (v == null) return '';
  if (v is int) return '$v';
  if (v.isFinite && v == v.roundToDouble() && v.abs() < 1e15) return '${v.toInt()}';
  return '$v';
}

/// `ui-number-input`: a numeric field with decrement and increment buttons side by side at its
/// end (48dp wide each on touch screens).
///
/// While typing, a number is passed on as soon as it's within [min]..[max]; half-typed or
/// out-of-range text waits for Enter or leaving the field, which clamps it and rounds it to
/// [precision]. Focusing the field selects the number so typing replaces it. ArrowUp/ArrowDown step
/// it. Give it a [label] (or [labelIcon]) to get a handle you drag sideways to scrub the value
/// ([step] per 2px).
class UiNumberInput extends StatefulWidget {
  const UiNumberInput({
    super.key,
    this.value,
    this.onChanged,
    this.min,
    this.max,
    this.step = 1,
    this.placeholder = '',
    this.size = UiSize.md,
    this.invalid = false,
    this.radius,
    this.label = '',
    this.labelIcon,
    this.semanticLabel,
    this.suffix = '',
    this.precision,
    this.steppers = true,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
  });

  final num? value;
  final ValueChanged<num?>? onChanged;
  final num? min;
  final num? max;
  final num step;
  final String placeholder;
  final UiSize size;
  final bool invalid;
  final bool? radius;

  /// A short label before the number ("X", "W") that you drag sideways to scrub the value.
  final String label;

  /// An icon in place of the text [label] (the web `[uiNumberLabel]` slot); keep [label] or
  /// [semanticLabel] set for screen readers.
  final Widget? labelIcon;

  /// Accessible name when the visible label is too terse (the web `ariaLabel`).
  final String? semanticLabel;

  /// A unit after the number, e.g. "px" or "°".
  final String suffix;

  /// Decimal places kept; values are rounded to this.
  final int? precision;
  final bool steppers;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<UiNumberInput> createState() => _UiNumberInputState();
}

class _UiNumberInputState extends State<UiNumberInput> {
  late final TextEditingController _controller = TextEditingController(text: uiFormatNumber(widget.value));
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  /// The last value passed on from typing, so the parent echoing it back doesn't rewrite the text.
  num? _typed;
  bool _hasTyped = false;
  num? _current;

  bool _scrubbing = false;
  double _scrubStartX = 0;
  num _scrubStartValue = 0;

  @override
  void initState() {
    super.initState();
    _current = widget.value;
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(UiNumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
    if (widget.value != _current) {
      _current = widget.value;
      _show(widget.value);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _controller.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus) _settle();
    setState(() {});
  }

  /// Writes a value into the field, unless it's being typed and already says that.
  void _show(num? v) {
    final typing = _focus.hasFocus;
    final parsed = num.tryParse(_controller.text);
    if (typing && _controller.text.isNotEmpty && parsed == v) return;
    final display = uiFormatNumber(v);
    if (_controller.text != display) {
      _controller.value = TextEditingValue(text: display, selection: TextSelection.collapsed(offset: display.length));
    }
  }

  num _round(num v) {
    final p = widget.precision;
    if (p == null) return v;
    final r = double.parse(v.toStringAsFixed(p));
    return r == r.roundToDouble() && v is int ? r.toInt() : r;
  }

  num _clamp(num v) {
    var x = v;
    if (widget.min != null) x = math.max(widget.min!, x);
    if (widget.max != null) x = math.min(widget.max!, x);
    return x;
  }

  void _onText(String raw) {
    if (raw.isEmpty || raw == '-' || raw.endsWith('.')) return;
    final v = num.tryParse(raw);
    if (v == null || !v.isFinite) return;
    if ((widget.min != null && v < widget.min!) || (widget.max != null && v > widget.max!)) return;
    final value = _round(v);
    _typed = value;
    _hasTyped = true;
    _current = value;
    widget.onChanged?.call(value);
  }

  /// Enter or leaving the field: the typed text becomes a valid value, shown as such.
  void _settle() {
    final raw = _controller.text;
    if (raw.isEmpty) {
      if (_current != null) _commit(null);
      return;
    }
    final v = num.tryParse(raw);
    _commit(v != null && v.isFinite ? v : _current, quietIfUnchanged: true);
  }

  void _commit(num? v, {bool quietIfUnchanged = false}) {
    final before = _hasTyped ? _typed : _current;
    num? next = v;
    if (next != null) next = _clamp(_round(next));
    _current = next;
    // Settling always shows the result, even when it equals the value ("1000" in a field capped at
    // 100 reads 100).
    final display = uiFormatNumber(next);
    if (_controller.text != display) {
      _controller.value = TextEditingValue(text: display, selection: TextSelection.collapsed(offset: display.length));
    }
    _hasTyped = false;
    _typed = null;
    if (!(quietIfUnchanged && next == before)) widget.onChanged?.call(next);
    setState(() {});
  }

  void _bump(num delta) => _commit((_current ?? 0) + delta);

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      _bump(widget.step);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      _bump(-widget.step);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _scrubStart(DragStartDetails d) {
    _scrubbing = true;
    _scrubStartX = d.globalPosition.dx;
    _scrubStartValue = _current ?? 0;
    setState(() {});
  }

  void _scrubUpdate(DragUpdateDetails d) {
    final factor = HardwareKeyboard.instance.isShiftPressed ? 10 : HardwareKeyboard.instance.isAltPressed ? 0.1 : 1;
    final delta = ((d.globalPosition.dx - _scrubStartX) / 2).round() * widget.step * factor;
    final next = _clamp(_round(_scrubStartValue + delta));
    if (next != _current) _commit(next);
  }

  void _scrubEnd() => setState(() => _scrubbing = false);

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final h = widget.size.height(t);
    final touch = uiTouchPlatform(context);
    final style = uiFieldTextStyle(context, widget.size).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final small = TextStyle(fontSize: t.fontSizeSm, color: t.textMuted, fontWeight: FontWeight.w500);
    final hasLabel = widget.label.isNotEmpty || widget.labelIcon != null;
    final name = widget.semanticLabel ?? (widget.label.isNotEmpty ? widget.label : null);

    Widget? scrub;
    if (hasLabel) {
      final color = _scrubbing ? t.primary : t.textMuted;
      final iconColor = _scrubbing ? t.primary : (t.icon ?? t.textMuted);
      scrub = ExcludeSemantics(
        child: MouseRegion(
          cursor: widget.enabled ? SystemMouseCursors.resizeLeftRight : SystemMouseCursors.forbidden,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: widget.enabled ? _scrubStart : null,
            onHorizontalDragUpdate: widget.enabled ? _scrubUpdate : null,
            onHorizontalDragEnd: widget.enabled ? (_) => _scrubEnd() : null,
            onHorizontalDragCancel: widget.enabled ? _scrubEnd : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: touch ? 32 : 18),
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: t.space2),
                child: Center(
                  widthFactor: 1,
                  child: widget.labelIcon != null
                      ? IconTheme.merge(data: IconThemeData(size: 14, color: iconColor), child: widget.labelIcon!)
                      : Text(widget.label, style: context.uiText.body.merge(small).copyWith(color: color)),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final stepW = touch ? uiMinTouchTarget : 24.0;
    // The buttons take the field's full (touch) height; their fill and dividers stay inside the box.
    final inset = (math.max(h, touch ? uiMinTouchTarget : h) - h) / 2 + 1;
    Widget stepper(String label, UiIconData icon, num delta, {required bool first}) => ExcludeFocus(
          child: UiInteractive(
            onTap: () => _bump(delta),
            enabled: widget.enabled,
            semanticLabel: label,
            excludeChildSemantics: true,
            padTouchTarget: false,
            builder: (context, s) => SizedBox(
              width: stepW,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: inset),
                child: Container(
                  decoration: BoxDecoration(
                    color: s.hovered || s.pressed ? t.surfaceHover : null,
                    border: BorderDirectional(
                      start: first ? BorderSide(color: t.border) : BorderSide.none,
                      end: first ? BorderSide(color: t.border) : BorderSide.none,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: UiIcon(icon, size: 12, strokeWidth: 2, color: s.hovered || s.pressed ? t.text : t.textMuted),
                ),
              ),
            ),
          ),
        );

    return ListenableBuilder(
      listenable: _focus,
      builder: (context, _) => UiFieldFrame(
        height: h,
        focused: _focus.hasFocus,
        invalid: uiFieldInvalid(context, widget.invalid),
        enabled: widget.enabled,
        radius: widget.radius,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ?scrub,
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.size == UiSize.sm ? t.space2 : t.space3),
              child: UiTextEditor(
                controller: _controller,
                focusNode: _focus,
                style: style,
                placeholder: widget.placeholder,
                enabled: widget.enabled,
                keyboardType: TextInputType.numberWithOptions(signed: widget.min == null || widget.min! < 0, decimal: widget.precision != 0),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-eE]'))],
                onChanged: _onText,
                onSubmitted: (_) => _settle(),
                selectAllOnFocus: true,
                onKeyEvent: _onKey,
                autofocus: widget.autofocus,
                semanticLabel: name,
              ),
            ),
          ),
          if (widget.suffix.isNotEmpty)
            ExcludeSemantics(
              child: Padding(
                padding: EdgeInsetsDirectional.only(end: t.space2),
                child: Center(widthFactor: 1, child: Text(widget.suffix, style: context.uiText.body.merge(small).copyWith(fontWeight: FontWeight.w400))),
              ),
            ),
          if (widget.steppers) ...[
            // Side by side, not stacked: two stacked buttons in a 30px field would each be 14px tall.
            stepper(uiFormatString(context.uiStrings.decrease, {'label': name ?? ''}).trim(), HugeIcons.strokeRoundedArrowDown01, -widget.step, first: true),
            stepper(uiFormatString(context.uiStrings.increase, {'label': name ?? ''}).trim(), HugeIcons.strokeRoundedArrowUp01, widget.step, first: false),
          ],
        ]),
      ),
    );
  }
}
