import 'dart:collection';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../behaviors/scrolling.dart';
import '../core/interactive.dart';
import '../theme/theme.dart';

/// Horizontal alignment of a table column.
enum UiColumnAlign { start, center, end }

/// A column of a [UiTable].
///
/// The cell value is read with [value], or, when rows are maps, `row[key]`. [format] turns it into
/// the text shown (default: `toString()`, empty for null).
@immutable
class UiColumn<T> {
  const UiColumn({required this.key, required this.header, this.sortable = false, this.align = UiColumnAlign.start, this.value, this.format});

  final String key;
  final String header;
  final bool sortable;
  final UiColumnAlign align;
  final Object? Function(T row)? value;
  final String Function(Object? value, T row)? format;

  Object? read(T row) {
    if (value != null) return value!(row);
    final r = row;
    return r is Map ? r[key] : null;
  }

  String text(T row) {
    final v = read(row);
    if (format != null) return format!(v, row);
    return v == null ? '' : v.toString();
  }
}

/// Something a row can have done to it (edit, remove, resend): a real button in a trailing column.
@immutable
class UiRowAction<T> {
  const UiRowAction({required this.label, required this.run, this.disabled, this.semanticLabel});

  final String label;
  final void Function(T row) run;

  /// Unavailable for this row in particular.
  final bool Function(T row)? disabled;

  /// Screen-reader label, when "Edit" on its own doesn't say which row it edits.
  final String Function(T row)? semanticLabel;
}

/// Sort direction of a [UiTable] column.
enum UiSortDirection { ascending, descending }

/// Natural, case-insensitive comparison: "item 2" sorts before "Item 10" (the web table's
/// `Intl.Collator(undefined, { numeric: true, sensitivity: 'base' })`).
int uiNaturalCompare(String a, String b) {
  final chunk = RegExp(r'\d+|\D+');
  final ca = chunk.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
  final cb = chunk.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
  for (var i = 0; i < ca.length && i < cb.length; i++) {
    final x = ca[i], y = cb[i];
    final dx = _isDigits(x), dy = _isDigits(y);
    int c;
    if (dx && dy) {
      final tx = x.replaceFirst(RegExp(r'^0+(?=\d)'), ''), ty = y.replaceFirst(RegExp(r'^0+(?=\d)'), '');
      c = tx.length != ty.length ? tx.length.compareTo(ty.length) : tx.compareTo(ty);
    } else {
      c = x.compareTo(y);
    }
    if (c != 0) return c;
  }
  return ca.length.compareTo(cb.length);
}

bool _isDigits(String s) => s.codeUnitAt(0) >= 48 && s.codeUnitAt(0) <= 57;

/// `ui-table`: a data table with tap-to-sort headers, optional row selection and per-row actions.
///
/// Sorting cycles ascending, descending, unsorted; numbers compare as numbers, text naturally and
/// case-insensitively, and empty cells always go last. Selected rows are tracked by identity and
/// forgotten when they leave [data]. With no rows it shows [emptyText]. On a narrow screen the table
/// keeps its natural width and scrolls sideways inside its border, with the cut-off edge faded,
/// instead of squeezing the columns.
class UiTable<T> extends StatefulWidget {
  const UiTable({
    super.key,
    required this.columns,
    required this.data,
    this.selectable = false,
    this.actions = const [],
    this.emptyText = 'No data',
    this.radius,
    this.onSelectionChanged,
  });

  final List<UiColumn<T>> columns;
  final List<T> data;
  final bool selectable;
  final List<UiRowAction<T>> actions;
  final String emptyText;
  final bool? radius;
  final ValueChanged<List<T>>? onSelectionChanged;

  @override
  State<UiTable<T>> createState() => _UiTableState<T>();
}

class _UiTableState<T> extends State<UiTable<T>> {
  String? _sortKey;
  UiSortDirection? _sortDir;
  Set<T> _selected = LinkedHashSet<T>.identity();
  int? _hover;

  /// The selection, limited to rows still in the data.
  Set<T> get _current {
    final rows = LinkedHashSet<T>.identity()..addAll(widget.data);
    return LinkedHashSet<T>.identity()..addAll(_selected.where(rows.contains));
  }

  List<T> get _sorted {
    final key = _sortKey, dir = _sortDir;
    if (key == null || dir == null) return widget.data;
    final col = widget.columns.firstWhere((c) => c.key == key);
    final copy = [...widget.data];
    copy.sort((a, b) {
      final av = col.read(a), bv = col.read(b);
      final ae = av == null || av == '', be = bv == null || bv == '';
      if (ae && be) return 0;
      if (ae) return 1;
      if (be) return -1;
      final cmp = av is num && bv is num ? av.compareTo(bv) : uiNaturalCompare(av.toString(), bv.toString());
      return dir == UiSortDirection.ascending ? cmp : -cmp;
    });
    return copy;
  }

  void _sortBy(String key) {
    setState(() {
      if (_sortKey != key) {
        _sortKey = key;
        _sortDir = UiSortDirection.ascending;
      } else if (_sortDir == UiSortDirection.ascending) {
        _sortDir = UiSortDirection.descending;
      } else {
        _sortKey = null;
        _sortDir = null;
      }
    });
  }

  void _toggleRow(T row) {
    final next = _current;
    if (!next.remove(row)) next.add(row);
    setState(() => _selected = next);
    widget.onSelectionChanged?.call(next.toList());
  }

  void _toggleAll(bool on) {
    final next = LinkedHashSet<T>.identity();
    if (on) next.addAll(widget.data);
    setState(() => _selected = next);
    widget.onSelectionChanged?.call(next.toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final r = (widget.radius ?? theme.config.radius) ? t.radius : 0.0;
    final rows = _sorted;
    final current = _current;
    final all = widget.data.isNotEmpty && current.length == widget.data.length;
    final some = current.isNotEmpty && !all;
    final body = context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.35, color: t.text, fontFeatures: const [FontFeature.tabularFigures()]);
    final head = body.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: t.textMuted);
    final pad = EdgeInsets.symmetric(vertical: t.space2, horizontal: t.space3);
    final hasActions = widget.actions.isNotEmpty;
    final touch = uiTouchPlatform(context);

    Alignment align(UiColumnAlign a) => switch (a) { UiColumnAlign.start => Alignment.centerLeft, UiColumnAlign.center => Alignment.center, UiColumnAlign.end => Alignment.centerRight };
    TextAlign textAlign(UiColumnAlign a) => switch (a) { UiColumnAlign.start => TextAlign.start, UiColumnAlign.center => TextAlign.center, UiColumnAlign.end => TextAlign.end };

    Widget hoverable(int i, Widget child) => MouseRegion(
          onEnter: (_) => setState(() => _hover = i),
          onExit: (_) => setState(() {
            if (_hover == i) _hover = null;
          }),
          child: child,
        );

    final header = TableRow(
      decoration: BoxDecoration(color: t.surfaceRaised),
      children: [
        if (widget.selectable)
          Semantics(
            container: true,
            role: SemanticsRole.columnHeader,
            child: Padding(padding: EdgeInsets.symmetric(horizontal: t.space3), child: _Check(checked: all, mixed: some, label: 'Select all rows', onChanged: widget.data.isEmpty ? null : _toggleAll)),
          ),
        for (final col in widget.columns)
          Semantics(
            container: true,
            role: SemanticsRole.columnHeader,
            child: Padding(
              padding: pad,
              child: Align(
                alignment: align(col.align),
                widthFactor: 1,
                child: col.sortable
                    ? _SortButton(label: col.header, style: head, dir: _sortKey == col.key ? _sortDir : null, onTap: () => _sortBy(col.key))
                    : Text(col.header, style: head, maxLines: 1, softWrap: false),
              ),
            ),
          ),
        // Named by its semantics, with no visible text.
        if (hasActions) Semantics(container: true, role: SemanticsRole.columnHeader, label: 'Actions', child: const SizedBox.shrink()),
      ],
    );

    final dataRows = <TableRow>[
      for (var i = 0; i < rows.length; i++)
        TableRow(
          // Keyed by the row itself, so sorting moves rows rather than relabelling them.
          key: ObjectKey(rows[i]),
          decoration: BoxDecoration(color: current.contains(rows[i]) ? t.selected : (_hover == i ? t.surfaceHover : null)),
          children: [
            if (widget.selectable)
              hoverable(i, Padding(
                padding: EdgeInsets.symmetric(horizontal: t.space3),
                child: _Check(checked: current.contains(rows[i]), label: 'Select row ${i + 1}', onChanged: (_) => _toggleRow(rows[i])),
              )),
            for (final col in widget.columns)
              hoverable(i, Padding(
                padding: pad,
                child: Align(alignment: align(col.align), widthFactor: 1, child: Text(col.text(rows[i]), style: body, textAlign: textAlign(col.align))),
              )),
            if (hasActions)
              hoverable(i, Padding(
                // The same cell padding as the data cells, so action rows are as tall as the web (42px)
                // and the buttons keep clear of the row lines; space2 between buttons. On touch the
                // buttons' 48px hit areas already keep them 11px clear, so no extra height there.
                padding: touch ? EdgeInsets.symmetric(horizontal: t.space3) : pad,
                child: Row(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
                  for (final a in widget.actions)
                    _ActionButton(
                      label: a.label,
                      semanticLabel: a.semanticLabel?.call(rows[i]),
                      onTap: a.disabled?.call(rows[i]) ?? false ? null : () => a.run(rows[i]),
                    ),
                ]),
              )),
          ],
        ),
    ];

    final widths = <int, TableColumnWidth>{};
    var c = 0;
    if (widget.selectable) widths[c++] = const IntrinsicColumnWidth();
    for (var k = 0; k < widget.columns.length; k++) {
      widths[c++] = const IntrinsicColumnWidth(flex: 1);
    }
    if (hasActions) widths[c++] = const IntrinsicColumnWidth();

    final table = Table(
      columnWidths: widths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(horizontalInside: BorderSide(color: t.border)),
      children: [header, ...dataRows],
    );

    return Container(
      decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(r)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r > 1 ? r - 1 : 0),
        child: LayoutBuilder(builder: (context, box) {
          Widget content = table;
          if (rows.isEmpty) {
            content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              table,
              DecoratedBox(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
                child: Padding(
                  padding: EdgeInsets.all(t.space6),
                  child: Text(widget.emptyText, textAlign: TextAlign.center, style: body.copyWith(color: t.textMuted)),
                ),
              ),
            ]);
          }
          // Wide: fill the width and let long text wrap (flexible columns shrink to fit). Narrow (a
          // phone): the columns keep their natural width and the table scrolls, with a faded edge.
          if (box.maxWidth.isFinite && box.maxWidth > 600) return SizedBox(width: box.maxWidth, child: content);
          return UiScrollFade(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: box.maxWidth.isFinite ? box.maxWidth : 0),
                child: IntrinsicWidth(child: content),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// The table's checkbox: a 14px box (with a 48dp hit area on touch) that can show "some".
class _Check extends StatelessWidget {
  const _Check({required this.checked, required this.label, required this.onChanged, this.mixed = false});
  final bool checked;
  final bool mixed;
  final String label;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final on = checked || mixed;
    return UiInteractive(
      onTap: onChanged == null ? null : () => onChanged!(!(checked || mixed)),
      enabled: onChanged != null,
      button: false,
      checked: checked,
      pressScale: false,
      builder: (context, s) => Semantics(
        label: label,
        mixed: mixed ? true : null,
        child: SizedBox.square(
          // A 24px box around the 14px square, the web's WCAG 2.5.8 minimum.
          dimension: 24,
          child: Center(
            child: AnimatedContainer(
              duration: context.uiAnimate ? t.motionFast : Duration.zero,
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: on ? t.primary : t.surface,
                border: Border.all(color: on ? t.primary : t.controlBorder),
                borderRadius: BorderRadius.circular(3),
                boxShadow: s.focused ? t.focusRing : const [],
              ),
              child: on ? CustomPaint(painter: _MarkPainter(t.primaryContrast, mixed: mixed && !checked)) : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color, {required this.mixed});
  final Color color;
  final bool mixed;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 12);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = mixed ? (Path()..moveTo(3, 6)..lineTo(9, 6)) : (Path()..moveTo(2.5, 6.2)..lineTo(5, 8.6)..lineTo(9.5, 3.6));
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color || old.mixed != mixed;
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.label, required this.style, required this.dir, required this.onTap});
  final String label;
  final TextStyle style;
  final UiSortDirection? dir;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      pressScale: false,
      builder: (context, s) {
        final c = s.hovered || s.pressed ? t.text : style.color!;
        // The web's aria-sort, as the button's value: "Name, sorted ascending".
        return Semantics(
          value: dir == null ? null : (dir == UiSortDirection.ascending ? 'sorted ascending' : 'sorted descending'),
          child: Container(
          constraints: const BoxConstraints(minHeight: 24, minWidth: 24),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(t.radiusXs), boxShadow: s.focused ? t.focusRing : const []),
          child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
            Text(label, style: style.copyWith(color: c), maxLines: 1, softWrap: false),
            Opacity(opacity: dir == null ? 0.4 : 1, child: CustomPaint(size: const Size.square(12), painter: _SortPainter(c, dir))),
          ]),
        ));
      },
    );
  }
}

/// The web sort arrows (12-unit paths): a chevron pair when unsorted, one chevron when sorted.
class _SortPainter extends CustomPainter {
  _SortPainter(this.color, this.dir);
  final Color color;
  final UiSortDirection? dir;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 12);
    final path = switch (dir) {
      UiSortDirection.ascending => Path()..moveTo(3, 7.5)..lineTo(6, 4.5)..lineTo(9, 7.5),
      UiSortDirection.descending => Path()..moveTo(3, 4.5)..lineTo(6, 7.5)..lineTo(9, 4.5),
      null => Path()..moveTo(3.5, 4.5)..lineTo(6, 2)..lineTo(8.5, 4.5)..moveTo(3.5, 7.5)..lineTo(6, 10)..lineTo(8.5, 7.5),
    };
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SortPainter old) => old.color != color || old.dir != dir;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap, this.semanticLabel});
  final String label;
  final String? semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      enabled: onTap != null,
      semanticLabel: semanticLabel ?? label,
      excludeChildSemantics: true,
      builder: (context, s) => Opacity(
        opacity: s.disabled ? 0.5 : 1,
        child: AnimatedContainer(
          duration: context.uiAnimate ? t.motionFast : Duration.zero,
          height: t.sizeSm,
          padding: EdgeInsets.symmetric(horizontal: t.space2),
          decoration: BoxDecoration(
            color: s.hovered || s.pressed ? t.surfaceHover : t.surface,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(t.radiusXs),
            boxShadow: s.focused ? t.focusRing : const [],
          ),
          child: Align(widthFactor: 1, child: Text(label, style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.35))),
        ),
      ),
    );
  }
}

/// `ui-row-actions`: the buttons of a row in a table you build yourself (or any small group of
/// actions): space2 apart so neighbours never touch, at the end of the row (the start with
/// [align] start), wrapping onto another line when there isn't room. Follows the text direction.
class UiRowActions extends StatelessWidget {
  const UiRowActions({super.key, required this.children, this.align = UiRowActionsAlign.end});

  final List<Widget> children;
  final UiRowActionsAlign align;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Wrap(
      spacing: t.space2,
      runSpacing: t.space2,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: align == UiRowActionsAlign.end ? WrapAlignment.end : WrapAlignment.start,
      children: children,
    );
  }
}

/// Which end of the cell [UiRowActions] sit at.
enum UiRowActionsAlign { start, end }
