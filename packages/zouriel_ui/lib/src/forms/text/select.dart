import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../combobox/listbox.dart';
import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../overlay/anchored.dart';
import '../../theme/theme.dart';
import 'form_field.dart';
import 'text_core.dart';

/// One choice in a [UiSelect].
@immutable
class UiSelectOption {
  const UiSelectOption({required this.label, required this.value, this.disabled = false, this.fontFamily, this.fontPackage});

  final String label;
  final String value;
  final bool disabled;

  /// Show this option in this font family.
  final String? fontFamily;

  /// The package that bundles the font (e.g. `'zouriel_ui'`); null for app or system fonts.
  final String? fontPackage;
}

/// `ui-select`: a single-choice dropdown.
///
/// The closed field shows the chosen label (or [placeholder]); tapping it, or Enter, Space or
/// ArrowDown, opens the list with the chosen option active. In the list, ArrowUp/Down,
/// Home/End and typing a letter move, Enter or Space chooses, Escape or a tap outside closes and
/// focus returns to the field. For filtering, use [UiCombobox].
///
/// Font pickers: with [fontPreview] each option, and the closed field, is drawn in the font it
/// names: the option's `fontFamily`, or its value as a family name (from [fontPackage] when the
/// fonts are bundled in a package). Unlike native web selects, this works on every platform.
class UiSelect extends StatefulWidget {
  const UiSelect({
    super.key,
    required this.options,
    this.value,
    this.onChanged,
    this.placeholder,
    this.label,
    this.size = UiSize.md,
    this.invalid = false,
    this.radius,
    this.enabled = true,
    this.fontPreview = false,
    this.fontPackage,
    this.focusNode,
  });

  final List<UiSelectOption> options;
  final String? value;
  final ValueChanged<String>? onChanged;

  /// Shown while nothing is chosen.
  final String? placeholder;

  /// Accessible name when no [UiFormField] label names it.
  final String? label;
  final UiSize size;
  final bool invalid;
  final bool? radius;
  final bool enabled;

  /// Draw each option, and the closed field, in the font it names.
  final bool fontPreview;

  /// Package for value-named preview fonts whose option has no `fontPackage`.
  final String? fontPackage;
  final FocusNode? focusNode;

  @override
  State<UiSelect> createState() => _UiSelectState();
}

class _UiSelectState extends State<UiSelect> {
  final OverlayPortalController _overlay = OverlayPortalController();
  final FocusNode _listFocus = FocusNode(debugLabel: 'select list');
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'select'));
  UiFieldLink? _link;
  int _active = 0;
  bool _open = false;
  String _typeahead = '';
  DateTime _typedAt = DateTime(0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final link = UiFieldScope.maybeOf(context)?.link;
    if (link != _link) {
      _link?.detach(_focus);
      _link = link;
      _link?.attach(_focus);
    }
  }

  @override
  void dispose() {
    _link?.detach(_focus);
    _listFocus.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  int get _selectedIndex => widget.options.indexWhere((o) => o.value == widget.value);

  TextStyle? _fontOf(UiSelectOption o) =>
      uiFontPreviewStyle(context, o.fontFamily ?? (widget.fontPreview ? o.value : null), package: o.fontPackage ?? widget.fontPackage);

  void _show() {
    if (!widget.enabled || _open) return;
    final sel = _selectedIndex;
    _active = sel >= 0 ? sel : _firstEnabled(0, 1);
    setState(() => _open = true);
    _overlay.show();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) _listFocus.requestFocus();
    });
  }

  void _close({bool refocus = true}) {
    if (!_open) return;
    setState(() => _open = false);
    _overlay.hide();
    if (refocus) _focus.requestFocus();
  }

  void _pick(int i) {
    final o = widget.options[i];
    if (o.disabled) return;
    _close();
    if (o.value != widget.value) widget.onChanged?.call(o.value);
  }

  int _firstEnabled(int from, int dir) {
    for (var i = from; i >= 0 && i < widget.options.length; i += dir) {
      if (!widget.options[i].disabled) return i;
    }
    return _active;
  }

  KeyEventResult _onListKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final n = widget.options.length;
    int? next;
    if (k == LogicalKeyboardKey.arrowDown) {
      next = _firstEnabled(_active + 1, 1);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      next = _firstEnabled(_active - 1, -1);
    } else if (k == LogicalKeyboardKey.home) {
      next = _firstEnabled(0, 1);
    } else if (k == LogicalKeyboardKey.end) {
      next = _firstEnabled(n - 1, -1);
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.space) {
      if (n > 0) _pick(_active);
      return KeyEventResult.handled;
    } else if (k == LogicalKeyboardKey.tab) {
      _close(refocus: false);
      return KeyEventResult.ignored;
    } else {
      final ch = e.character;
      if (ch != null && ch.trim().isNotEmpty && ch.length == 1) {
        // Type-ahead, as native selects do: letters typed in quick succession build a prefix.
        final now = DateTime.now();
        _typeahead = now.difference(_typedAt).inMilliseconds < 700 ? _typeahead + ch.toLowerCase() : ch.toLowerCase();
        _typedAt = now;
        for (var j = 0; j < n; j++) {
          final i = (_active + (_typeahead.length == 1 ? 1 : 0) + j) % n;
          final o = widget.options[i];
          if (!o.disabled && o.label.toLowerCase().startsWith(_typeahead)) {
            next = i;
            break;
          }
        }
        if (next == null) return KeyEventResult.handled;
      } else {
        return KeyEventResult.ignored;
      }
    }
    setState(() => _active = next!);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final scope = UiFieldScope.maybeOf(context);
    final sel = _selectedIndex;
    final chosen = sel >= 0 ? widget.options[sel] : null;
    final h = widget.size.height(t);
    var style = uiFieldTextStyle(context, widget.size);
    final font = chosen != null && widget.fontPreview ? _fontOf(chosen) : null;
    if (font != null) style = style.merge(font);
    final shown = chosen?.label ?? widget.placeholder ?? '';
    final name = widget.label ?? scope?.label;

    final field = UiInteractive(
      onTap: _open ? _close : _show,
      enabled: widget.enabled,
      focusNode: _focus,
      pressScale: false,
      padTouchTarget: false,
      semanticLabel: name,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowDown): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.arrowUp): ActivateIntent(),
      },
      builder: (context, s) => Semantics(
        value: chosen?.label ?? '',
        hint: chosen == null ? widget.placeholder : null,
        expanded: _open,
        child: UiFieldFrame(
          height: h,
          focused: s.focused || _open,
          invalid: uiFieldInvalid(context, widget.invalid),
          enabled: widget.enabled,
          radius: widget.radius,
          padding: EdgeInsetsDirectional.only(start: t.space3, end: t.space3),
          child: Row(spacing: t.space2, children: [
            Expanded(
              child: ExcludeSemantics(
                child: Text(shown, maxLines: 1, overflow: TextOverflow.ellipsis, style: chosen == null ? style.copyWith(color: t.textMuted) : style),
              ),
            ),
            UiIcon(HugeIcons.strokeRoundedArrowDown01, size: 14, strokeWidth: 2, color: t.textMuted),
          ]),
        ),
      ),
    );

    return UiAnchoredOverlay(
      controller: _overlay,
      matchAnchorWidth: true,
      onDismiss: _close,
      panelBuilder: (context, anchor) => Focus(
          focusNode: _listFocus,
          onKeyEvent: _onListKey,
          child: UiListboxPanel(
            semanticLabel: name,
            maxHeight: 320,
            activeIndex: _active,
            onHover: (i) => setState(() => _active = i),
            onPick: _pick,
            items: [
              for (final o in widget.options)
                UiListItem(label: o.label, disabled: o.disabled, selected: o.value == widget.value, style: _fontOf(o)),
            ],
          ),
        ),
      child: field,
    );
  }
}
