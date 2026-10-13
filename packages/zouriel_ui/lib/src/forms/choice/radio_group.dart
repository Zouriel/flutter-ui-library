import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/interactive.dart';
import '../../theme/theme.dart';
import 'marks.dart';
import 'roving.dart';

/// One option of a [UiRadioGroup].
@immutable
class UiRadioOption<T> {
  const UiRadioOption({required this.label, required this.value, this.disabled = false});
  final String label;
  final T value;
  final bool disabled;
}

/// `ui-radio-group`: one choice from a list. Like native radios, the group is one tab stop (the
/// chosen option, or the first enabled one) and the arrow keys move the choice, wrapping and
/// skipping disabled options. Null [onChanged] disables the group.
class UiRadioGroup<T> extends StatefulWidget {
  const UiRadioGroup({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.direction = Axis.vertical,
  });

  final List<UiRadioOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;

  /// The group's accessible name.
  final String? label;
  final Axis direction;

  @override
  State<UiRadioGroup<T>> createState() => _UiRadioGroupState<T>();
}

class _UiRadioGroupState<T> extends State<UiRadioGroup<T>> with UiRovingFocus<UiRadioGroup<T>> {
  bool _usable(int i) => widget.onChanged != null && !widget.options[i].disabled;

  int? get _tabStop {
    final chosen = widget.options.indexWhere((o) => o.value == widget.value);
    if (chosen >= 0 && _usable(chosen)) return chosen;
    for (var i = 0; i < widget.options.length; i++) {
      if (_usable(i)) return i;
    }
    return null;
  }

  bool _onKey(LogicalKeyboardKey key, int at) {
    final step = uiArrowStep(key, Directionality.of(context));
    if (step == 0) return false;
    final n = widget.options.length;
    for (var k = 1; k <= n; k++) {
      final i = ((at + step * k) % n + n) % n;
      if (_usable(i)) {
        widget.onChanged!(widget.options[i].value);
        rovingFocus(i);
        return true;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final opts = widget.options;
    syncRoving(opts.length, _tabStop);
    final touch = uiTouchPlatform(context);
    final items = [
      for (var i = 0; i < opts.length; i++)
        UiInteractive(
          focusNode: rovingNode(i),
          enabled: _usable(i),
          onTap: _usable(i) ? () => widget.onChanged!(opts[i].value) : null,
          button: false,
          checked: opts[i].value == widget.value,
          pressScale: false,
          builder: (context, s) => Semantics(
            inMutuallyExclusiveGroup: true,
            child: UiMarkRow(
              disabled: !_usable(i),
              label: opts[i].label,
              mark: UiRadioMark(selected: opts[i].value == widget.value, states: s),
            ),
          ),
        ),
    ];
    return Semantics(
      container: true,
      role: SemanticsRole.radioGroup,
      label: widget.label,
      explicitChildNodes: true,
      child: rovingKeys(
        onKey: _onKey,
        child: widget.direction == Axis.horizontal
            ? Wrap(spacing: t.space4, runSpacing: touch ? 0 : t.space2, children: items)
            : Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: touch ? 0 : t.space2, children: items),
      ),
    );
  }
}
