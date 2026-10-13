import 'package:flutter/widgets.dart';

import '../../core/interactive.dart';
import '../../theme/theme.dart';
import 'marks.dart';

/// `ui-checkbox`: a boolean control with its label beside it. The whole row is the touch target.
///
/// Controlled: pass [value] and [onChanged]; leave [onChanged] null to disable it. A null [value]
/// draws the mixed state (a dash) and is announced as mixed; tapping it checks it.
class UiCheckbox extends StatelessWidget {
  const UiCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.child,
    this.invalid = false,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  });

  final bool? value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  /// Rich label content instead of [label].
  final Widget? child;

  /// Draws the box with the danger border (the web `aria-invalid`).
  final bool invalid;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Accessible name when there is no visible label.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return UiInteractive(
      onTap: enabled ? () => onChanged!(!(value ?? false)) : null,
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
      button: false,
      checked: value == true,
      semanticLabel: semanticLabel,
      pressScale: false,
      builder: (context, s) => Semantics(
        mixed: value == null ? true : null,
        child: UiMarkRow(
          disabled: !enabled,
          label: label,
          mark: UiCheckMark(value: value, states: s, invalid: invalid),
          child: child,
        ),
      ),
    );
  }
}

/// One option of a [UiCheckboxGroup].
@immutable
class UiCheckboxOption<T> {
  const UiCheckboxOption({required this.label, required this.value, this.disabled = false});
  final String label;
  final T value;
  final bool disabled;
}

/// `ui-checkbox-group`: a multi-select set of checkboxes. [value] is the list of chosen values,
/// in the order they were chosen.
///
/// [selectAll] adds a master checkbox that ticks or clears every enabled option and shows the mixed
/// state while the selection is partial. It never changes disabled options: their state is kept.
class UiCheckboxGroup<T> extends StatelessWidget {
  const UiCheckboxGroup({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.direction = Axis.vertical,
    this.selectAll = false,
    this.selectAllLabel = 'Select all',
  });

  final List<UiCheckboxOption<T>> options;
  final List<T> value;

  /// Null disables the whole group.
  final ValueChanged<List<T>>? onChanged;

  /// The group's accessible name.
  final String? label;
  final Axis direction;
  final bool selectAll;
  final String selectAllLabel;

  List<UiCheckboxOption<T>> get _togglable => options.where((o) => !o.disabled).toList();
  bool get _allSelected => _togglable.isNotEmpty && _togglable.every((o) => value.contains(o.value));
  bool get _someSelected => !_allSelected && _togglable.any((o) => value.contains(o.value));

  void _toggle(T v) {
    final next = [...value];
    next.contains(v) ? next.remove(v) : next.add(v);
    onChanged!(next);
  }

  void _toggleAll() {
    final next = [...value];
    final select = !_allSelected;
    for (final o in _togglable) {
      if (select && !next.contains(o.value)) next.add(o.value);
      if (!select) next.remove(o.value);
    }
    onChanged!(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final enabled = onChanged != null;
    final row = direction == Axis.horizontal;
    final touch = uiTouchPlatform(context);
    final items = <Widget>[
      for (final o in options)
        UiCheckbox(
          value: value.contains(o.value),
          label: o.label,
          onChanged: enabled && !o.disabled ? (_) => _toggle(o.value) : null,
        ),
    ];
    Widget? master;
    if (selectAll && options.isNotEmpty) {
      master = Container(
        padding: row ? EdgeInsetsDirectional.only(end: t.space4) : EdgeInsets.only(bottom: touch ? 0 : t.space2),
        decoration: BoxDecoration(
          border: row ? BorderDirectional(end: BorderSide(color: t.border)) : Border(bottom: BorderSide(color: t.border)),
        ),
        child: UiCheckbox(
          value: _allSelected ? true : _someSelected ? null : false,
          onChanged: enabled ? (_) => _toggleAll() : null,
          child: Text(selectAllLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
    }
    final children = [?master, ...items];
    return Semantics(
      container: true,
      label: label,
      explicitChildNodes: true,
      child: row
          ? Wrap(spacing: t.space4, runSpacing: touch ? 0 : t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: children)
          : Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: touch ? 0 : t.space2, children: children),
    );
  }
}
