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
import 'calendar_view.dart';
import 'date_names.dart';

/// `ui-date-picker`: a date field that opens a calendar popover. The value is an ISO
/// `YYYY-MM-DD` day (or null), shown as local text ("October 13, 2026").
///
/// Tap the field, or press Enter, Space or ArrowDown on it, to open; focus goes to the chosen day
/// (or today). Keys in the calendar as in [UiCalendarView]. Tab stays inside the popover; Escape or
/// a tap outside closes it and returns to the field. [min]/[max] limit which days can be picked.
class UiDatePicker extends StatefulWidget {
  const UiDatePicker({
    super.key,
    this.value,
    this.onChanged,
    this.placeholder = 'Select a date',
    this.size = UiSize.md,
    this.radius,
    this.min,
    this.max,
    this.invalid = false,
    this.enabled = true,
    this.label,
    this.focusNode,
  });

  final String? value;
  final ValueChanged<String>? onChanged;
  final String placeholder;
  final UiSize size;
  final bool? radius;
  final String? min;
  final String? max;
  final bool invalid;
  final bool enabled;

  /// Accessible name when no [UiFormField] label names it.
  final String? label;
  final FocusNode? focusNode;

  @override
  State<UiDatePicker> createState() => _UiDatePickerState();
}

class _UiDatePickerState extends State<UiDatePicker> {
  final OverlayPortalController _overlay = OverlayPortalController();
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'date field'));
  UiFieldLink? _link;
  bool _open = false;

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
    _ownFocus?.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!widget.enabled) return;
    if (_open) {
      _close();
    } else {
      setState(() => _open = true);
      _overlay.show();
    }
  }

  /// Closes and puts focus back on the field.
  void _close() {
    if (!_open) return;
    setState(() => _open = false);
    _overlay.hide();
    _focus.requestFocus();
  }

  void _pick(String iso) {
    _close();
    if (iso != widget.value) widget.onChanged?.call(iso);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final h = widget.size.height(t);
    final style = uiFieldTextStyle(context, widget.size);
    // An empty or malformed value is no date: the placeholder shows, as for null.
    final shown = uiParseIsoDate(widget.value) == null ? null : uiFormatIsoDate(context, widget.value!);
    final name = widget.label ?? UiFieldScope.maybeOf(context)?.label;

    final field = UiInteractive(
      onTap: _toggle,
      enabled: widget.enabled,
      focusNode: _focus,
      pressScale: false,
      padTouchTarget: false,
      semanticLabel: name,
      semanticHint: 'Opens a calendar',
      shortcuts: const {SingleActivator(LogicalKeyboardKey.arrowDown): ActivateIntent()},
      builder: (context, s) => Semantics(
        value: shown ?? '',
        expanded: _open,
        child: UiFieldFrame(
          height: h,
          focused: s.focused,
          active: _open,
          invalid: uiFieldInvalid(context, widget.invalid),
          enabled: widget.enabled,
          radius: widget.radius,
          padding: EdgeInsetsDirectional.only(start: t.space3, end: t.space3),
          child: Row(spacing: t.space2, children: [
            Expanded(
              child: ExcludeSemantics(
                child: Text(shown ?? widget.placeholder, maxLines: 1, overflow: TextOverflow.ellipsis, style: shown == null ? style.copyWith(color: t.textMuted) : style),
              ),
            ),
            UiIcon(HugeIcons.strokeRoundedCalendar01, size: 16, color: t.textMuted),
          ]),
        ),
      ),
    );

    return UiAnchoredOverlay(
      controller: _overlay,
      onDismiss: _close,
      panelBuilder: (context, anchor) => Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: 'Choose a date',
        // Tab stays inside the popover.
        child: FocusScope(
          child: Container(
            padding: EdgeInsets.all(t.space3),
            decoration: BoxDecoration(
              color: t.surfaceRaised,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(theme.radius()),
              boxShadow: t.shadow2,
            ),
            child: UiCalendarView(
              value: widget.value,
              min: widget.min,
              max: widget.max,
              raised: true,
              autofocus: true,
              onPick: _pick,
            ),
          ),
        ),
      ),
      child: field,
    );
  }
}
