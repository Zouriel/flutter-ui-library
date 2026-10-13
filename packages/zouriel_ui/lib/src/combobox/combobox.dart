import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/fonts.dart';
import '../core/icon.dart';
import '../core/types.dart';
import '../forms/text/form_field.dart';
import '../forms/text/text_core.dart';
import '../overlay/anchored.dart';
import '../theme/theme.dart';
import 'listbox.dart';

/// One choice in a [UiCombobox] or [UiMultiSelect].
@immutable
class UiComboboxOption {
  const UiComboboxOption({required this.label, required this.value, this.fontFamily, this.fontPackage});

  final String label;
  final String value;

  /// Show this option in this font family.
  final String? fontFamily;

  /// The package that bundles the font (e.g. `'zouriel_ui'`); null for app or system fonts.
  final String? fontPackage;
}

/// `ui-combobox`: a filterable autocomplete.
///
/// Focusing or tapping the field opens the list, which shows every option with the chosen one
/// active; typing filters it by label. ArrowUp/Down move, Enter chooses, Escape, a tap outside or
/// leaving the field closes. Leaving the field puts the chosen label back, so typed text never
/// becomes the value. With [clearable] (the default) a Clear button shows while a value is
/// chosen; it, or emptying the text and leaving the field, sets the value to null.
///
/// [fontPreview] draws each option, and the chosen value, in the font it names (the option's
/// `fontFamily`, or its value as a family name, from [fontPackage] when bundled in a package).
class UiCombobox extends StatefulWidget {
  const UiCombobox({
    super.key,
    required this.options,
    this.value,
    this.onChanged,
    this.placeholder = 'Search…',
    this.label,
    this.size = UiSize.md,
    this.invalid = false,
    this.radius,
    this.clearable = true,
    this.enabled = true,
    this.fontPreview = false,
    this.fontPackage,
    this.focusNode,
  });

  final List<UiComboboxOption> options;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final String placeholder;

  /// Accessible name when no [UiFormField] label names it.
  final String? label;
  final UiSize size;
  final bool invalid;
  final bool? radius;
  final bool clearable;
  final bool enabled;
  final bool fontPreview;
  final String? fontPackage;
  final FocusNode? focusNode;

  @override
  State<UiCombobox> createState() => UiComboboxState();
}

/// State of a [UiCombobox]; [clear] is public like the web `clear()`.
class UiComboboxState extends State<UiCombobox> {
  final OverlayPortalController _overlay = OverlayPortalController();
  final TextEditingController _query = TextEditingController();
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'combobox'));
  bool _open = false;
  bool _typed = false;
  int _active = 0;
  bool _suppressOpen = false;
  bool _hadFocus = false;

  @override
  void initState() {
    super.initState();
    _query.text = _labelOf(widget.value) ?? '';
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(UiCombobox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
    // A value set from outside, or options that arrive after the value, show the chosen label.
    if (!_open && (oldWidget.value != widget.value || oldWidget.options != widget.options)) {
      final label = _labelOf(widget.value);
      if (label != null || oldWidget.value != widget.value) _setQuery(label ?? '');
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

  String? _labelOf(String? v) {
    for (final o in widget.options) {
      if (o.value == v) return o.label;
    }
    return null;
  }

  void _setQuery(String text) {
    if (_query.text != text)
      _query.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
  }

  List<UiComboboxOption> get _filtered {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty || !_typed) return widget.options;
    return widget.options.where((o) => o.label.toLowerCase().contains(q)).toList();
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
      _blur();
    }
    _hadFocus = f;
    if (mounted) setState(() {});
  }

  void _openPanel() {
    if (!widget.enabled) return;
    if (!_open) {
      // A fresh open lists everything, with the chosen option active, until the user types.
      _typed = false;
      final i = widget.options.indexWhere((o) => o.value == widget.value);
      _active = i < 0 ? 0 : i;
      _open = true;
      _overlay.show();
      setState(() {});
    }
  }

  void _close() {
    if (!_open) return;
    _open = false;
    _overlay.hide();
    if (mounted) setState(() {});
  }

  void _blur() {
    _close();
    // An emptied field clears the value rather than snapping back to the old label.
    if (widget.clearable && _query.text.trim().isEmpty && widget.value != null) {
      widget.onChanged?.call(null);
      return;
    }
    _setQuery(_labelOf(widget.value) ?? '');
  }

  void _select(UiComboboxOption o) {
    _setQuery(o.label);
    _close();
    if (o.value != widget.value) widget.onChanged?.call(o.value);
  }

  /// Clears the value (null) and leaves focus in the field with the list closed.
  void clear() {
    if (!widget.enabled) return;
    _setQuery('');
    _close();
    widget.onChanged?.call(null);
    if (!_focus.hasFocus) _suppressOpen = true;
    _focus.requestFocus();
  }

  void _onText(String text) {
    _typed = true;
    _active = 0;
    if (!_open) {
      _open = true;
      _overlay.show();
    }
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final items = _filtered;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      if (!_open) {
        _openPanel();
      } else {
        setState(() => _active = (_active + 1).clamp(0, items.isEmpty ? 0 : items.length - 1));
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      setState(() => _active = (_active - 1).clamp(0, items.isEmpty ? 0 : items.length - 1));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      if (!_open) return KeyEventResult.ignored;
      if (_active < items.length) _select(items[_active]);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape && _open) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  TextStyle? _fontOf(UiComboboxOption o) =>
      uiFontPreviewStyle(context, o.fontFamily ?? (widget.fontPreview ? o.value : null), package: o.fontPackage ?? widget.fontPackage);

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final h = widget.size.height(t);
    final scope = UiFieldScope.maybeOf(context);
    UiComboboxOption? chosen;
    for (final o in widget.options) {
      if (o.value == widget.value) chosen = o;
    }
    var style = uiFieldTextStyle(context, widget.size);
    if (widget.fontPreview && chosen != null) {
      final f = _fontOf(chosen);
      style = uiApplyFont(style, f);
    }
    final showClear = widget.clearable && widget.value != null && widget.enabled;
    final items = _filtered;

    final field = UiFieldFrame(
      height: h,
      focused: _focus.hasFocus,
      invalid: uiFieldInvalid(context, widget.invalid),
      enabled: widget.enabled,
      radius: widget.radius,
      padding: EdgeInsetsDirectional.only(start: t.space3, end: t.space3),
      child: Row(
        children: [
          Expanded(
            child: UiTextEditor(
              controller: _query,
              focusNode: _focus,
              style: style,
              placeholder: widget.placeholder,
              enabled: widget.enabled,
              onChanged: _onText,
              onKeyEvent: _onKey,
              semanticLabel: widget.label ?? scope?.label,
              // A tap on the already-focused field reopens a closed list.
              onTap: () {
                if (_focus.hasFocus) _openPanel();
              },
            ),
          ),
          if (showClear)
            UiFieldButton(label: 'Clear', visual: 24, onTap: clear, icon: const UiIcon(HugeIcons.strokeRoundedCancel01, strokeWidth: 2)),
          SizedBox(width: showClear ? t.space1 : t.space2),
          AnimatedRotation(
            turns: _open ? 0.5 : 0,
            duration: context.uiAnimate ? t.motionFast : Duration.zero,
            child: UiIcon(HugeIcons.strokeRoundedArrowDown01, size: 14, strokeWidth: 2, color: t.textMuted),
          ),
        ],
      ),
    );

    return UiAnchoredOverlay(
      controller: _overlay,
      matchAnchorWidth: true,
      onDismiss: _close,
      // Taps in the list count as inside the text field, so they don't blur it before they land.
      panelBuilder: (context, anchor) => TextFieldTapRegion(
        child: UiListboxPanel(
          semanticLabel: widget.label ?? scope?.label,
          activeIndex: _active,
          onHover: (i) => setState(() => _active = i),
          onPick: (i) => _select(items[i]),
          items: [for (final o in items) UiListItem(label: o.label, selected: o.value == widget.value, style: _fontOf(o))],
        ),
      ),
      child: field,
    );
  }
}
