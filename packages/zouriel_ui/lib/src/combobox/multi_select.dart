import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../forms/text/form_field.dart';
import '../forms/text/text_core.dart';
import '../overlay/anchored.dart';
import '../theme/theme.dart';
import 'combobox.dart';
import 'listbox.dart';

/// `ui-multi-select`: choose several options, shown as chips in the field.
///
/// The value is the chosen values in the order chosen. Type to filter; ArrowUp/Down move,
/// Enter toggles the active option, Backspace in an empty field removes the last chip, Escape, a
/// tap outside or leaving the field closes the list. Each chip has a "Remove <label>" button; with
/// [clearable] (the default) a Clear all button at the end empties the selection.
class UiMultiSelect extends StatefulWidget {
  const UiMultiSelect({
    super.key,
    required this.options,
    this.value = const [],
    this.onChanged,
    this.placeholder = 'Select…',
    this.label,
    this.size = UiSize.md,
    this.invalid = false,
    this.radius,
    this.clearable = true,
    this.enabled = true,
    this.focusNode,
  });

  final List<UiComboboxOption> options;
  final List<String> value;
  final ValueChanged<List<String>>? onChanged;
  final String placeholder;

  /// Accessible name when no [UiFormField] label names it.
  final String? label;

  /// Minimum height, matching the other fields; chips wrap onto more rows.
  final UiSize size;
  final bool invalid;
  final bool? radius;
  final bool clearable;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  State<UiMultiSelect> createState() => UiMultiSelectState();
}

/// State of a [UiMultiSelect]; [clear] is public like the web `clear()`.
class UiMultiSelectState extends State<UiMultiSelect> {
  final OverlayPortalController _overlay = OverlayPortalController();
  final TextEditingController _query = TextEditingController();
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'multi-select'));
  bool _open = false;
  int _active = 0;
  bool _suppressOpen = false;
  bool _hadFocus = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    _query.addListener(_onQuery);
  }

  @override
  void didUpdateWidget(UiMultiSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
    if (!widget.enabled && _open) _close();
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _query.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  String _labelOf(String v) {
    for (final o in widget.options) {
      if (o.value == v) return o.label;
    }
    return v;
  }

  List<UiComboboxOption> get _filtered {
    final q = _query.text.trim().toLowerCase();
    return q.isEmpty ? widget.options : widget.options.where((o) => o.label.toLowerCase().contains(q)).toList();
  }

  void _onFocus() {
    final f = _focus.hasFocus;
    if (f && !_hadFocus) {
      if (_suppressOpen) {
        _suppressOpen = false;
      } else {
        _openPanel();
      }
    } else if (!f && _hadFocus) {
      _close();
    }
    _hadFocus = f;
    if (mounted) setState(() {});
  }

  void _onQuery() {
    if (mounted) setState(() {});
  }

  void _openPanel() {
    if (!widget.enabled || _open) return;
    _open = true;
    _overlay.show();
    setState(() {});
  }

  void _close() {
    if (!_open) return;
    _open = false;
    _overlay.hide();
    if (mounted) setState(() {});
  }

  void _toggle(String v) {
    if (!widget.enabled) return;
    final next = widget.value.contains(v) ? widget.value.where((x) => x != v).toList() : [...widget.value, v];
    widget.onChanged?.call(next);
  }

  /// Empties the selection and leaves focus in the field with the list closed.
  void clear() {
    if (!widget.enabled) return;
    widget.onChanged?.call(const []);
    _close();
    if (!_focus.hasFocus) _suppressOpen = true;
    _focus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final items = _filtered;
    final k = e.logicalKey;
    final last = items.isEmpty ? 0 : items.length - 1;
    if (k == LogicalKeyboardKey.arrowDown) {
      if (!_open) {
        _openPanel();
      }
      setState(() => _active = (_active + 1).clamp(0, last));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      setState(() => _active = (_active - 1).clamp(0, last));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      if (_open && _active < items.length) {
        _toggle(items[_active].value);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (k == LogicalKeyboardKey.escape && _open) {
      _close();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.backspace && _query.text.isEmpty && widget.value.isNotEmpty) {
      _toggle(widget.value.last);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onText(String _) {
    _active = 0;
    _openPanel();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final scope = UiFieldScope.maybeOf(context);
    final touch = uiTouchPlatform(context);
    final rowH = touch ? uiMinTouchTarget : 24.0;
    final minH = math.max(widget.size.height(t), touch ? uiMinTouchTarget : 0.0);
    final items = _filtered;
    final name = widget.label ?? scope?.label;
    final fontSize = uiFieldFontSize(t, widget.size);

    final field = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled
          ? () {
              _openPanel();
              _focus.requestFocus();
            }
          : null,
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.text : SystemMouseCursors.forbidden,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minH),
          child: UiFieldFrame(
            focused: _focus.hasFocus,
            invalid: uiFieldInvalid(context, widget.invalid),
            enabled: widget.enabled,
            radius: widget.radius,
            padding: EdgeInsetsDirectional.fromSTEB(t.space1, touch ? 0 : 2, t.space3, touch ? 0 : 2),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minH - (touch ? 2 : 6)),
              child: Row(children: [
                Expanded(
                  child: Wrap(
                    spacing: t.space1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final v in widget.value) _Chip(label: _labelOf(v), height: rowH, enabled: widget.enabled, onRemove: () => _toggle(v)),
                      ConstrainedBox(
                        constraints: BoxConstraints(minWidth: 80, minHeight: rowH),
                        child: IntrinsicWidth(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: t.space2),
                            child: UiTextEditor(
                              controller: _query,
                              focusNode: _focus,
                              style: uiFieldTextStyle(context, widget.size).copyWith(fontSize: fontSize),
                              placeholder: widget.value.isEmpty ? widget.placeholder : null,
                              enabled: widget.enabled,
                              onChanged: _onText,
                              onKeyEvent: _onKey,
                              semanticLabel: name,
                              onTap: _openPanel,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.clearable && widget.value.isNotEmpty && widget.enabled)
                  SizedBox(height: rowH, child: UiFieldButton(label: context.uiStrings.clearAll, visual: 24, onTap: clear, icon: const UiIcon(HugeIcons.strokeRoundedCancel01, strokeWidth: 2))),
                // The chevron, as on the combobox, centred on the whole field however many rows the chips take.
                SizedBox(width: t.space1),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: context.uiAnimate ? t.motionFast : Duration.zero,
                  child: UiIcon(HugeIcons.strokeRoundedArrowDown01, size: 14, strokeWidth: 2, color: t.textMuted),
                ),
              ]),
            ),
          ),
        ),
      ),
    );

    return UiAnchoredOverlay(
      controller: _overlay,
      matchAnchorWidth: true,
      onDismiss: _close,
      panelBuilder: (context, anchor) => TextFieldTapRegion(
        child: UiListboxPanel(
          semanticLabel: name,
          multiselect: true,
          checkboxes: true,
          activeIndex: _active,
          onHover: (i) => setState(() => _active = i),
          onPick: (i) {
            setState(() => _active = i);
            _toggle(items[i].value);
          },
          items: [for (final o in items) UiListboxItem(label: o.label, selected: widget.value.contains(o.value))],
        ),
      ),
      child: field,
    );
  }
}

/// A chosen value: a primary-tinted pill with a remove button (the web `.chip`).
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.height, required this.enabled, required this.onRemove});
  final String label;
  final double height;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    final hit = touch ? uiMinTouchTarget : 24.0;
    final style = context.uiText.body.copyWith(fontSize: t.fontSizeSm, color: t.text, height: 1.2);
    // The 16px remove circle sits near the chip's end; its hit area reaches past the chip's edge.
    final overhang = touch && enabled ? (hit / 2 - 13).clamp(0.0, double.infinity) : 0.0;
    return SizedBox(
      height: height,
      child: Stack(alignment: AlignmentDirectional.centerStart, children: [
        Padding(
          padding: EdgeInsetsDirectional.only(end: overhang),
          child: Container(
            height: 22,
            padding: EdgeInsetsDirectional.only(start: t.space2, end: enabled ? t.space1 : t.space2),
            decoration: BoxDecoration(
              color: uiMix(t.primary, 0.18, t.surface),
              border: Border.all(color: t.primary.withValues(alpha: 0.45)),
              borderRadius: BorderRadius.circular(t.radiusPill),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
              if (enabled) const SizedBox(width: 16),
            ]),
          ),
        ),
        // A disabled field has nothing to remove, so its chips carry no x (as Clear all hides).
        if (enabled) PositionedDirectional(
          end: 0,
          top: 0,
          bottom: 0,
          width: hit,
          child: ExcludeFocus(
            child: UiInteractive(
              onTap: onRemove,
              enabled: enabled,
              semanticLabel: 'Remove $label',
              excludeChildSemantics: true,
              pressScale: false,
              padTouchTarget: false,
              builder: (context, s) => Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: s.hovered || s.pressed ? t.text.withValues(alpha: 0.14) : null),
                  child: UiIcon(HugeIcons.strokeRoundedCancel01, size: 12, strokeWidth: 2, color: t.text.withValues(alpha: s.hovered ? 1 : 0.7)),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
