import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../overlay/anchored.dart';
import '../../theme/theme.dart';
import 'form_field.dart';
import 'text_core.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// `ui-time-picker`: a 24-hour time field. The value is `'HH:MM'`, or `'HH:MM:SS'` when [step] is
/// under a minute.
///
/// The web uses the browser's native time input; on phones that's a picker, so here the field
/// opens a popover with a column each for hours, minutes (in [step]s) and seconds. Tap a cell to
/// set that part. Keyboard: Enter, Space or ArrowDown opens it; ArrowUp/Down change the active
/// column, ArrowLeft/Right switch columns, Home/End jump to its ends, Enter or Escape closes.
class UiTimePicker extends StatefulWidget {
  const UiTimePicker({
    super.key,
    this.value,
    this.onChanged,
    this.step = 60,
    this.size = UiSize.md,
    this.invalid = false,
    this.radius,
    this.enabled = true,
    this.placeholder,
    this.label,
    this.focusNode,
  });

  final String? value;
  final ValueChanged<String>? onChanged;

  /// Granularity in seconds: 60 = minutes (default), 900 = quarter hours, under 60 shows seconds.
  final int step;
  final UiSize size;
  final bool invalid;
  final bool? radius;
  final bool enabled;

  /// Shown while empty; defaults to `--:--` (or `--:--:--`).
  final String? placeholder;

  /// Accessible name when no [UiFormField] label names it.
  final String? label;
  final FocusNode? focusNode;

  @override
  State<UiTimePicker> createState() => _UiTimePickerState();
}

class _UiTimePickerState extends State<UiTimePicker> {
  final OverlayPortalController _overlay = OverlayPortalController();
  final FocusNode _panelFocus = FocusNode(debugLabel: 'time columns');
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'time field'));
  UiFieldLink? _link;
  bool _open = false;
  int _column = 0;

  bool get _seconds => widget.step < 60;
  int get _minuteStep => widget.step >= 60 && widget.step % 60 == 0 ? math.max(1, widget.step ~/ 60) : 1;
  int get _secondStep => _seconds ? math.max(1, widget.step) : 1;

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
    _panelFocus.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  /// [hours, minutes, seconds] of the value, or null when empty or malformed.
  List<int>? get _parts {
    final m = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(widget.value ?? '');
    if (m == null) return null;
    return [int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3] ?? '0')];
  }

  void _set(int column, int v) {
    final p = _parts ?? [0, 0, 0];
    p[column] = v;
    final text = _seconds ? '${_two(p[0])}:${_two(p[1])}:${_two(p[2])}' : '${_two(p[0])}:${_two(p[1])}';
    if (text != widget.value) widget.onChanged?.call(text);
  }

  List<int> _values(int column) => switch (column) {
        0 => [for (var h = 0; h < 24; h++) h],
        1 => [for (var m = 0; m < 60; m += _minuteStep) m],
        _ => [for (var s = 0; s < 60; s += _secondStep) s],
      };

  void _show() {
    if (!widget.enabled || _open) return;
    setState(() {
      _open = true;
      _column = 0;
    });
    _overlay.show();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) _panelFocus.requestFocus();
    });
  }

  void _close() {
    if (!_open) return;
    setState(() => _open = false);
    _overlay.hide();
    _focus.requestFocus();
  }

  KeyEventResult _onPanelKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final columns = _seconds ? 3 : 2;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) {
      final d = (k == LogicalKeyboardKey.arrowRight) != rtl ? 1 : -1;
      setState(() => _column = (_column + d).clamp(0, columns - 1));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.space) {
      _close();
      return KeyEventResult.handled;
    }
    final values = _values(_column);
    final cur = (_parts ?? [0, 0, 0])[_column];
    var i = values.indexOf(cur);
    if (i < 0) i = 0;
    int? next;
    if (k == LogicalKeyboardKey.arrowDown) next = (i + 1) % values.length;
    if (k == LogicalKeyboardKey.arrowUp) next = (i - 1 + values.length) % values.length;
    if (k == LogicalKeyboardKey.home) next = 0;
    if (k == LogicalKeyboardKey.end) next = values.length - 1;
    if (next == null) return KeyEventResult.ignored;
    _set(_column, values[next]);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final h = widget.size.height(t);
    final style = uiFieldTextStyle(context, widget.size).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final empty = _parts == null;
    final placeholder = widget.placeholder ?? (_seconds ? '--:--:--' : '--:--');
    final name = widget.label ?? UiFieldScope.maybeOf(context)?.label;

    final field = UiInteractive(
      onTap: _open ? _close : _show,
      enabled: widget.enabled,
      focusNode: _focus,
      pressScale: false,
      padTouchTarget: false,
      semanticLabel: name,
      semanticHint: 'Opens a time picker',
      shortcuts: const {SingleActivator(LogicalKeyboardKey.arrowDown): ActivateIntent()},
      builder: (context, s) => Semantics(
        value: widget.value ?? '',
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
                child: Text(empty ? placeholder : widget.value!, maxLines: 1, style: empty ? style.copyWith(color: t.textMuted) : style),
              ),
            ),
            UiIcon(HugeIcons.strokeRoundedClock01, size: 16, color: t.textMuted),
          ]),
        ),
      ),
    );

    return UiAnchoredOverlay(
      controller: _overlay,
      onDismiss: _close,
      panelBuilder: (context, anchor) => Focus(
        focusNode: _panelFocus,
        onKeyEvent: _onPanelKey,
        child: Semantics(
          explicitChildNodes: true,
          label: 'Choose a time',
          child: Container(
            padding: EdgeInsets.all(t.space1),
            decoration: BoxDecoration(
              color: t.surfaceRaised,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(theme.radius()),
              boxShadow: t.shadow2,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
              for (var c = 0; c < (_seconds ? 3 : 2); c++)
                _TimeColumn(
                  label: const ['Hours', 'Minutes', 'Seconds'][c],
                  values: _values(c),
                  selected: _parts?[c],
                  active: _panelFocus.hasFocus && c == _column,
                  onPick: (v) {
                    setState(() => _column = c);
                    _set(c, v);
                  },
                ),
            ]),
          ),
        ),
      ),
      child: field,
    );
  }
}

class _TimeColumn extends StatefulWidget {
  const _TimeColumn({required this.label, required this.values, required this.selected, required this.active, required this.onPick});
  final String label;
  final List<int> values;
  final int? selected;
  final bool active;
  final ValueChanged<int> onPick;

  @override
  State<_TimeColumn> createState() => _TimeColumnState();
}

class _TimeColumnState extends State<_TimeColumn> {
  final ScrollController _scroll = ScrollController();

  double _rowH(BuildContext context) => uiTouchPlatform(context) ? uiMinTouchTarget : 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(center: true));
  }

  @override
  void didUpdateWidget(_TimeColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _reveal({bool center = false}) {
    if (!mounted || !_scroll.hasClients || widget.selected == null) return;
    final i = widget.values.indexOf(widget.selected!);
    if (i < 0) return;
    final rh = _rowH(context);
    final view = _scroll.position.viewportDimension;
    final top = i * rh;
    var target = _scroll.offset;
    if (center) {
      target = top - (view - rh) / 2;
    } else if (top < _scroll.offset) {
      target = top;
    } else if (top + rh > _scroll.offset + view) {
      target = top + rh - view;
    }
    _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final rh = _rowH(context);
    final style = context.uiText.body.copyWith(fontSize: t.fontSizeMd, color: t.text, fontFeatures: const [FontFeature.tabularFigures()]);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.label,
      child: Container(
        width: uiTouchPlatform(context) ? 64 : 52,
        height: rh * 6,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(theme.radius(t.radiusXs)),
          boxShadow: widget.active ? t.focusRing : const [],
        ),
        child: ExcludeFocus(
          child: ListView.builder(
            controller: _scroll,
            itemExtent: rh,
            itemCount: widget.values.length,
            padding: EdgeInsets.zero,
            itemBuilder: (context, i) {
              final v = widget.values[i];
              final sel = v == widget.selected;
              return UiInteractive(
                onTap: () => widget.onPick(v),
                button: false,
                selected: sel,
                semanticLabel: '${_two(v)} ${widget.label.toLowerCase()}',
                excludeChildSemantics: true,
                pressScale: false,
                padTouchTarget: false,
                builder: (context, s) => Container(
                  alignment: Alignment.center,
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    color: sel ? t.primary : s.hovered || s.pressed ? t.elevatedHover : null,
                    borderRadius: BorderRadius.circular(theme.radius(t.radiusXs)),
                  ),
                  child: Text(_two(v), style: style.copyWith(color: sel ? t.primaryContrast : t.text, fontWeight: sel ? FontWeight.w600 : null)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
