import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../theme/theme.dart';
import 'date_names.dart';

enum _Mode { days, months, years }

/// The month grid shared by [UiCalendar], [UiDatePicker] and [UiDateRangePicker], with the
/// month and year grids opened from the heading.
///
/// Keyboard: the day grid is one tab stop. Arrow keys move by day and week (crossing months),
/// PageUp/PageDown by month, Home/End to the month's ends, Enter or Space picks. The month and
/// year grids work the same way: one tab stop, arrows move (Up/Down by a row of three), Home/End to
/// the first/last cell, PageUp/PageDown by a year (month grid) or a page of 12 years (year grid),
/// Enter or Space picks; opening a grid focuses the month or year in view. Every day is a button
/// named with its full date.
class UiCalendarView extends StatefulWidget {
  const UiCalendarView({
    super.key,
    required this.onPick,
    this.value,
    this.range = false,
    this.rangeStart,
    this.rangeEnd,
    this.min,
    this.max,
    this.enabled = true,
    this.autofocus = false,
    this.raised = false,
  });

  final ValueChanged<String> onPick;

  /// The chosen day (single mode).
  final String? value;

  /// Range mode: [rangeStart]..[rangeEnd] are drawn as a band, and hovering previews the end.
  final bool range;
  final String? rangeStart;
  final String? rangeEnd;
  final String? min;
  final String? max;
  final bool enabled;

  /// Focus the chosen day (or today) when shown, as the date picker's popover does.
  final bool autofocus;

  /// Drawn on a raised surface (a popover): hover fills use the raised hover colour.
  final bool raised;

  @override
  State<UiCalendarView> createState() => UiCalendarViewState();
}

/// State of a [UiCalendarView]; [focusDay] moves the keyboard focus to a day.
class UiCalendarViewState extends State<UiCalendarView> {
  late int _year, _month;
  _Mode _mode = _Mode.days;
  String? _focusIso;
  int _gridMonth = 0;
  int _gridYear = 0;
  String? _hover;
  final FocusNode _dayFocus = FocusNode(debugLabel: 'days');
  final FocusNode _monthFocus = FocusNode(debugLabel: 'months');
  final FocusNode _yearFocus = FocusNode(debugLabel: 'years');

  String? get _anchor => widget.range ? widget.rangeStart : widget.value;

  @override
  void initState() {
    super.initState();
    final d = uiParseIsoDate(_anchor) ?? uiToday();
    _year = d.year;
    _month = d.month - 1;
    _gridYear = _year;
    for (final n in [_dayFocus, _monthFocus, _yearFocus]) {
      n.addListener(_rebuild);
    }
    FocusManager.instance.addHighlightModeListener(_onHighlight);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focusDay(widget.value ?? uiIsoDate(uiToday()));
      });
    }
  }

  @override
  void didUpdateWidget(UiCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final was = oldWidget.range ? oldWidget.rangeStart : oldWidget.value;
    final now = _anchor;
    if (now != was && now != null) {
      final d = uiParseIsoDate(now);
      // A value written from outside shows its month (not when it was just picked here).
      if (d != null && !(d.year == _year && d.month - 1 == _month)) {
        _year = d.year;
        _month = d.month - 1;
      }
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlight);
    _dayFocus.dispose();
    _monthFocus.dispose();
    _yearFocus.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onHighlight(FocusHighlightMode _) => _rebuild();

  bool get _keyboard => FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  bool _blocked(String iso) => (widget.min != null && iso.compareTo(widget.min!) < 0) || (widget.max != null && iso.compareTo(widget.max!) > 0);

  /// The day in view that holds the tab stop: the focused one, else the chosen one, else the first
  /// that can be picked.
  String? get _tabDay {
    final count = uiDaysInMonth(_year, _month);
    final days = [for (var d = 1; d <= count; d++) uiIsoOf(_year, _month, d)].where((i) => !_blocked(i)).toList();
    for (final want in [_focusIso, _anchor]) {
      if (want != null && days.contains(want)) return want;
    }
    return days.isEmpty ? null : days.first;
  }

  /// Shows [iso]'s month and gives that day the keyboard focus.
  void focusDay(String iso) {
    final d = uiParseIsoDate(iso);
    if (d == null) return;
    setState(() {
      _mode = _Mode.days;
      _year = d.year;
      _month = d.month - 1;
      _focusIso = iso;
    });
    _dayFocus.requestFocus();
  }

  void _shift(int delta) {
    setState(() {
      switch (_mode) {
        case _Mode.days:
          final d = DateTime(_year, _month + 1 + delta, 1);
          _year = d.year;
          _month = d.month - 1;
        case _Mode.months:
          _year += delta;
        case _Mode.years:
          // Pages through the years without choosing one; the tab stop moves with the page.
          _gridYear += delta * 12;
      }
    });
  }

  void _showMonths() {
    setState(() {
      _gridMonth = _month;
      _mode = _Mode.months;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _monthFocus.requestFocus());
  }

  void _showYears() {
    setState(() {
      _gridYear = _year;
      _mode = _Mode.years;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _yearFocus.requestFocus());
  }

  void _pickMonth(int m) {
    _month = m;
    final v = _anchor;
    final prefix = uiIsoOf(_year, m, 1).substring(0, 8);
    final target = v != null && v.startsWith(prefix) ? v : uiIsoOf(_year, m, 1);
    focusDay(target);
  }

  void _pickYear(int y) {
    _year = y;
    _showMonths();
  }

  void _pick(String iso) {
    if (!widget.enabled || _blocked(iso)) return;
    setState(() => _focusIso = iso);
    widget.onPick(iso);
  }

  bool _isKey(KeyEvent e) => e is KeyDownEvent || e is KeyRepeatEvent;

  KeyEventResult _onDayKey(FocusNode node, KeyEvent e) {
    if (!_isKey(e)) return KeyEventResult.ignored;
    final cur = _tabDay;
    if (cur == null) return KeyEventResult.ignored;
    final d = uiParseIsoDate(cur)!;
    final y = d.year, m = d.month - 1, day = d.day;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final k = e.logicalKey;
    String? next;
    if (k == LogicalKeyboardKey.arrowLeft) {
      next = uiIsoOf(y, m, day + (rtl ? 1 : -1));
    } else if (k == LogicalKeyboardKey.arrowRight) {
      next = uiIsoOf(y, m, day + (rtl ? -1 : 1));
    } else if (k == LogicalKeyboardKey.arrowUp) {
      next = uiIsoOf(y, m, day - 7);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      next = uiIsoOf(y, m, day + 7);
    } else if (k == LogicalKeyboardKey.home) {
      next = uiIsoOf(y, m, 1);
    } else if (k == LogicalKeyboardKey.end) {
      next = uiIsoOf(y, m, uiDaysInMonth(y, m));
    } else if (k == LogicalKeyboardKey.pageUp) {
      next = uiIsoOf(y, m - 1, day.clamp(1, uiDaysInMonth(y, m - 1)));
    } else if (k == LogicalKeyboardKey.pageDown) {
      next = uiIsoOf(y, m + 1, day.clamp(1, uiDaysInMonth(y, m + 1)));
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.space) {
      _pick(cur);
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }
    focusDay(next);
    return KeyEventResult.handled;
  }

  KeyEventResult _onMonthKey(FocusNode node, KeyEvent e) {
    if (!_isKey(e)) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final moves = {
      LogicalKeyboardKey.arrowLeft: rtl ? 1 : -1,
      LogicalKeyboardKey.arrowRight: rtl ? -1 : 1,
      LogicalKeyboardKey.arrowUp: -3,
      LogicalKeyboardKey.arrowDown: 3,
    };
    int next;
    if (moves.containsKey(k)) {
      // A move off the grid (e.g. Up from the first row) stays put rather than jumping sideways.
      final n = _gridMonth + moves[k]!;
      next = n < 0 || n > 11 ? _gridMonth : n;
    } else if (k == LogicalKeyboardKey.home) {
      next = 0;
    } else if (k == LogicalKeyboardKey.end) {
      next = 11;
    } else if (k == LogicalKeyboardKey.pageUp || k == LogicalKeyboardKey.pageDown) {
      setState(() => _year += k == LogicalKeyboardKey.pageUp ? -1 : 1);
      return KeyEventResult.handled;
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.space) {
      _pickMonth(_gridMonth);
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }
    setState(() => _gridMonth = next);
    return KeyEventResult.handled;
  }

  KeyEventResult _onYearKey(FocusNode node, KeyEvent e) {
    if (!_isKey(e)) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final start = (_gridYear ~/ 12) * 12;
    final moves = {
      LogicalKeyboardKey.arrowLeft: rtl ? 1 : -1,
      LogicalKeyboardKey.arrowRight: rtl ? -1 : 1,
      LogicalKeyboardKey.arrowUp: -3,
      LogicalKeyboardKey.arrowDown: 3,
      LogicalKeyboardKey.pageUp: -12,
      LogicalKeyboardKey.pageDown: 12,
    };
    int next;
    if (moves.containsKey(k)) {
      // Moving past either end of the page turns the page.
      next = _gridYear + moves[k]!;
    } else if (k == LogicalKeyboardKey.home) {
      next = start;
    } else if (k == LogicalKeyboardKey.end) {
      next = start + 11;
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.space) {
      _pickYear(_gridYear);
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }
    setState(() => _gridYear = next);
    return KeyEventResult.handled;
  }

  bool _inRange(String d) {
    final start = widget.rangeStart;
    if (start == null) return false;
    final hi = widget.rangeEnd ?? _hover;
    if (hi == null) return false;
    final lo = start.compareTo(hi) < 0 ? start : hi;
    final up = start.compareTo(hi) < 0 ? hi : start;
    return d.compareTo(lo) > 0 && d.compareTo(up) < 0;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) => _build(context, c.maxWidth));

  Widget _build(BuildContext context, double maxWidth) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final touch = uiTouchPlatform(context);
    // 48dp days on touch screens; narrower only when the space really isn't there.
    final preferred = touch ? uiMinTouchTarget : 32.0;
    final cell = maxWidth.isFinite && maxWidth < preferred * 7 ? (maxWidth / 7).floorToDouble() : preferred;
    final width = cell * 7;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final hoverFill = widget.raised ? t.elevatedHover : t.surfaceHover;
    final small = context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.35, color: t.text);
    final months = uiMonthNames(context);
    final monthsShort = uiMonthNames(context, short: true);
    final pageStart = (_gridYear ~/ 12) * 12;
    final yearRange = '$pageStart – ${pageStart + 11}';

    final (prevLabel, nextLabel) = switch (_mode) {
      _Mode.days => ('Previous month', 'Next month'),
      _Mode.months => ('Previous year', 'Next year'),
      _Mode.years => ('Previous years', 'Next years'),
    };

    Widget nav(String label, int delta) => UiInteractive(
          onTap: widget.enabled ? () => _shift(delta) : null,
          semanticLabel: label,
          excludeChildSemantics: true,
          builder: (context, s) => AnimatedContainer(
            duration: t.motionFast,
            width: t.sizeSm,
            height: t.sizeSm,
            decoration: BoxDecoration(
              color: s.hovered || s.pressed ? hoverFill : null,
              borderRadius: BorderRadius.circular(theme.radius(t.radiusXs)),
              boxShadow: s.focused ? t.focusRing : const [],
            ),
            child: Center(
              child: UiIcon(
                (delta < 0) != rtl ? HugeIcons.strokeRoundedArrowLeft01 : HugeIcons.strokeRoundedArrowRight01,
                size: 16,
                color: s.hovered ? t.text : t.textMuted,
              ),
            ),
          ),
        );

    Widget headingButton(String text, VoidCallback onTap, String label) => UiInteractive(
          onTap: widget.enabled ? onTap : null,
          semanticLabel: label,
          excludeChildSemantics: true,
          builder: (context, s) => AnimatedContainer(
            duration: t.motionFast,
            padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: 2),
            decoration: BoxDecoration(
              color: s.hovered || s.pressed ? hoverFill : null,
              borderRadius: BorderRadius.circular(theme.radius(t.radiusXs)),
              boxShadow: s.focused ? t.focusRing : const [],
            ),
            child: Text(text, style: small.copyWith(fontWeight: FontWeight.w600, color: s.hovered ? t.primary : t.text)),
          ),
        );

    final heading = switch (_mode) {
      _Mode.days => Row(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
          headingButton(months[_month], _showMonths, 'Choose month, ${months[_month]}'),
          headingButton('$_year', _showYears, 'Choose year, $_year'),
        ]),
      _Mode.months => headingButton('$_year', _showYears, 'Choose year, $_year'),
      _Mode.years => Semantics(liveRegion: true, child: Text(yearRange, style: small.copyWith(fontWeight: FontWeight.w600))),
    };

    final head = Padding(
      padding: EdgeInsets.only(bottom: t.space2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [nav(prevLabel, -1), heading, nav(nextLabel, 1)]),
    );

    Widget body;
    switch (_mode) {
      case _Mode.days:
        body = _days(context, cell, hoverFill, small);
      case _Mode.months:
        body = _grid(
          focusNode: _monthFocus,
          onKey: _onMonthKey,
          label: 'Months of $_year',
          cells: [
            for (var m = 0; m < 12; m++)
              _GridCell(
                text: monthsShort[m],
                label: '${months[m]} $_year',
                selected: m == _month,
                tab: m == _gridMonth,
                onTap: () => _pickMonth(m),
              ),
          ],
          hoverFill: hoverFill,
          small: small,
          cell: cell,
        );
      case _Mode.years:
        body = _grid(
          focusNode: _yearFocus,
          onKey: _onYearKey,
          label: 'Years $yearRange',
          cells: [
            for (var y = pageStart; y < pageStart + 12; y++)
              _GridCell(text: '$y', label: '$y', selected: y == _year, tab: y == _gridYear, onTap: () => _pickYear(y)),
          ],
          hoverFill: hoverFill,
          small: small,
          cell: cell,
        );
    }

    return SizedBox(
      width: width,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, body]),
    );
  }

  Widget _grid({
    required FocusNode focusNode,
    required FocusOnKeyEventCallback onKey,
    required String label,
    required List<_GridCell> cells,
    required Color hoverFill,
    required TextStyle small,
    required double cell,
  }) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final ringOn = focusNode.hasFocus && _keyboard;
    final rows = <Widget>[];
    for (var r = 0; r < 4; r++) {
      rows.add(Row(spacing: t.space1, children: [
        for (var c = 0; c < 3; c++)
          Expanded(child: _gridCellView(cells[r * 3 + c], ringOn: ringOn, hoverFill: hoverFill, small: small, height: uiTouchPlatform(context) ? cell : 34)),
      ]));
    }
    return Semantics(
      container: true,
      label: label,
      explicitChildNodes: true,
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: onKey,
        child: Column(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: rows),
      ),
    );
  }

  Widget _gridCellView(_GridCell c, {required bool ringOn, required Color hoverFill, required TextStyle small, required double height}) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    return _Hoverable(
      enabled: widget.enabled,
      onTap: c.onTap,
      builder: (hovered) => Semantics(
        button: true,
        selected: c.selected,
        label: c.label,
        enabled: widget.enabled,
        onTap: widget.enabled ? c.onTap : null,
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: t.motionFast,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.selected ? t.primary : hovered ? hoverFill : null,
            borderRadius: BorderRadius.circular(theme.radius(t.radiusXs)),
            boxShadow: ringOn && c.tab ? t.focusRing : const [],
          ),
          child: Text(c.text, style: small.copyWith(color: c.selected ? t.primaryContrast : t.text)),
        ),
      ),
    );
  }

  Widget _days(BuildContext context, double cell, Color hoverFill, TextStyle small) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final weekdays = uiWeekdayNames(context);
    final lead = DateTime(_year, _month + 1, 1).weekday % 7;
    final count = uiDaysInMonth(_year, _month);
    final todayIso = uiIsoDate(uiToday());
    final tab = _tabDay;
    final ringOn = _dayFocus.hasFocus && _keyboard;
    final start = widget.rangeStart, end = widget.rangeEnd;
    final ranged = widget.range && start != null && (end != null || (_hover != null && _hover!.compareTo(start) > 0));
    final r = Radius.circular(theme.radius(t.radiusXs));

    Widget day(int d) {
      final iso = uiIsoOf(_year, _month, d);
      final blocked = _blocked(iso);
      final isStart = widget.range && iso == start;
      final isEnd = widget.range && iso == end;
      final inRange = widget.range && _inRange(iso);
      final selected = widget.range ? (isStart || isEnd) : iso == widget.value;
      final today = iso == todayIso;
      BorderRadiusGeometry radius = BorderRadius.all(r);
      if (inRange) radius = BorderRadius.zero;
      if (ranged && isStart && !isEnd) radius = BorderRadiusDirectional.horizontal(start: r);
      if (ranged && isEnd && !isStart) radius = BorderRadiusDirectional.horizontal(end: r);
      final label = uiFormatIsoDate(context, iso);
      final canPick = widget.enabled && !blocked;
      return _Hoverable(
        enabled: canPick,
        onTap: () {
          _pick(iso);
          if (_dayFocus.hasFocus || !uiTouchPlatform(context)) _dayFocus.requestFocus();
        },
        onHover: widget.range ? (h) => setState(() => _hover = h ? iso : (_hover == iso ? null : _hover)) : null,
        builder: (hovered) => Semantics(
          button: true,
          label: label,
          hint: today ? 'Today' : null,
          selected: selected || inRange,
          enabled: canPick,
          onTap: canPick ? () => _pick(iso) : null,
          excludeSemantics: true,
          child: Opacity(
            opacity: blocked ? 0.5 : 1,
            child: AnimatedContainer(
              duration: t.motionFast,
              width: cell,
              height: cell,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? t.primary
                    : inRange
                        ? t.selected
                        : hovered && canPick
                            ? hoverFill
                            : null,
                borderRadius: radius,
                border: today && !selected ? Border.all(color: t.border) : null,
                boxShadow: ringOn && iso == tab ? t.focusRing : const [],
              ),
              child: Text('$d', style: small.copyWith(color: selected ? t.primaryContrast : t.text, fontFeatures: const [FontFeature.tabularFigures()])),
            ),
          ),
        ),
      );
    }

    final cells = <Widget>[
      for (var i = 0; i < lead; i++) SizedBox(width: cell, height: cell),
      for (var d = 1; d <= count; d++) day(d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(SizedBox(width: cell, height: cell));
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ExcludeSemantics(
        child: Row(children: [
          for (final w in weekdays)
            SizedBox(
              width: cell,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(w, textAlign: TextAlign.center, style: small.copyWith(fontSize: 11, color: t.textMuted)),
              ),
            ),
        ]),
      ),
      Semantics(
        container: true,
        explicitChildNodes: true,
        label: uiMonthYear(context, _year, _month),
        child: Focus(
          focusNode: _dayFocus,
          onKeyEvent: _onDayKey,
          child: MouseRegion(
            onExit: widget.range ? (_) => setState(() => _hover = null) : null,
            child: Column(mainAxisSize: MainAxisSize.min, spacing: 2, children: [
              for (var i = 0; i < cells.length; i += 7) Row(children: cells.sublist(i, i + 7)),
            ]),
          ),
        ),
      ),
    ]);
  }
}

class _GridCell {
  const _GridCell({required this.text, required this.label, required this.selected, required this.tab, required this.onTap});
  final String text;
  final String label;
  final bool selected;
  final bool tab;
  final VoidCallback onTap;
}

/// Hover tracking and a tap for a calendar cell (focus lives on the grid, not the cell).
class _Hoverable extends StatefulWidget {
  const _Hoverable({required this.builder, required this.onTap, this.enabled = true, this.onHover});
  final Widget Function(bool hovered) builder;
  final VoidCallback onTap;
  final bool enabled;
  final ValueChanged<bool>? onHover;

  @override
  State<_Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<_Hoverable> {
  bool _hovered = false;

  void _set(bool v) {
    setState(() => _hovered = v);
    widget.onHover?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      onEnter: (_) => _set(true),
      onExit: (_) => _set(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        excludeFromSemantics: true,
        child: widget.builder(_hovered),
      ),
    );
  }
}
