import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../table/table.dart' show UiColumnAlign;
import '../theme/theme.dart';

/// A column of a [UiTreeTable] after the first (tree) column.
@immutable
class UiTreeTableColumn {
  const UiTreeTableColumn({required this.key, required this.header, this.align = UiColumnAlign.start});
  final String key;
  final String header;
  final UiColumnAlign align;
}

/// A row of a [UiTreeTable]: its [label] in the first column, other cells from [data] by column key.
@immutable
class UiTreeTableRow {
  const UiTreeTableRow({required this.label, required this.value, this.data = const {}, this.children = const []});
  final String label;
  final String value;
  final Map<String, Object?> data;
  final List<UiTreeTableRow> children;
}

/// `ui-tree-table`: a table whose first column is an expandable tree. Parent rows have a chevron
/// button ("Expand Q1" / "Collapse Q1", with its expanded state) that shows their children indented
/// below. Scrolls sideways on narrow screens, like `UiTable`.
class UiTreeTable extends StatefulWidget {
  const UiTreeTable({super.key, required this.rows, required this.columns, this.firstHeader = 'Name', this.initiallyExpanded = const {}, this.radius});

  final List<UiTreeTableRow> rows;
  final List<UiTreeTableColumn> columns;
  final String firstHeader;
  final Set<String> initiallyExpanded;
  final bool? radius;

  @override
  State<UiTreeTable> createState() => _UiTreeTableState();
}

class _UiTreeTableState extends State<UiTreeTable> {
  late Set<String> _expanded = {...widget.initiallyExpanded};
  int? _hover;

  void _toggle(UiTreeTableRow r) {
    setState(() => _expanded = _expanded.contains(r.value) ? ({..._expanded}..remove(r.value)) : {..._expanded, r.value});
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final rad = (widget.radius ?? theme.config.radius) ? t.radius : 0.0;
    final body = context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.35, color: t.text, fontFeatures: const [FontFeature.tabularFigures()]);
    final head = body.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: t.textMuted);
    final pad = EdgeInsets.symmetric(vertical: t.space2, horizontal: t.space3);
    final touch = uiTouchPlatform(context);

    final flat = <(UiTreeTableRow, int)>[];
    void walk(List<UiTreeTableRow> rows, int depth) {
      for (final r in rows) {
        flat.add((r, depth));
        if (r.children.isNotEmpty && _expanded.contains(r.value)) walk(r.children, depth + 1);
      }
    }

    walk(widget.rows, 0);

    Alignment align(UiColumnAlign a) => switch (a) { UiColumnAlign.start => Alignment.centerLeft, UiColumnAlign.center => Alignment.center, UiColumnAlign.end => Alignment.centerRight };
    Widget hoverable(int i, Widget child) => MouseRegion(
          onEnter: (_) => setState(() => _hover = i),
          onExit: (_) => setState(() {
            if (_hover == i) _hover = null;
          }),
          child: child,
        );

    final table = Table(
      columnWidths: {for (var c = 0; c <= widget.columns.length; c++) c: const IntrinsicColumnWidth(flex: 1)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(horizontalInside: BorderSide(color: t.border)),
      children: [
        TableRow(decoration: BoxDecoration(color: t.surfaceRaised), children: [
          Semantics(container: true, role: SemanticsRole.columnHeader, child: Padding(padding: pad, child: Text(widget.firstHeader, style: head, softWrap: false))),
          for (final c in widget.columns)
            Semantics(
              container: true,
              role: SemanticsRole.columnHeader,
              child: Padding(padding: pad, child: Align(alignment: align(c.align), widthFactor: 1, child: Text(c.header, style: head, softWrap: false))),
            ),
        ]),
        for (var i = 0; i < flat.length; i++)
          TableRow(key: ValueKey(flat[i].$1.value), decoration: BoxDecoration(color: _hover == i ? t.surfaceHover : null), children: [
            hoverable(
              i,
              Padding(
                padding: EdgeInsetsDirectional.only(start: t.space3 + flat[i].$2 * 16 - (touch ? 12 : 4), end: t.space3),
                child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
                  if (flat[i].$1.children.isNotEmpty)
                    _Chevron(row: flat[i].$1, open: _expanded.contains(flat[i].$1.value), onTap: () => _toggle(flat[i].$1))
                  else
                    SizedBox(width: touch ? uiMinTouchTarget : 24, height: 24),
                  Flexible(child: Padding(padding: EdgeInsets.symmetric(vertical: t.space2), child: Text(flat[i].$1.label, style: body))),
                ]),
              ),
            ),
            for (final c in widget.columns)
              hoverable(
                i,
                Padding(
                  padding: pad,
                  child: Align(alignment: align(c.align), widthFactor: 1, child: Text(flat[i].$1.data[c.key]?.toString() ?? '', style: body)),
                ),
              ),
          ]),
      ],
    );

    return Container(
      decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(rad)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(rad > 1 ? rad - 1 : 0),
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: box.maxWidth.isFinite ? box.maxWidth : 0),
              child: IntrinsicWidth(child: table),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.row, required this.open, required this.onTap});
  final UiTreeTableRow row;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      pressScale: false,
      builder: (context, s) => Semantics(
        label: '${open ? 'Collapse' : 'Expand'} ${row.label}',
        expanded: open,
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: t.motionFast,
            width: 24,
            height: 24,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(t.radiusXs), boxShadow: s.focused ? t.focusRing : const []),
            child: Center(
              child: AnimatedRotation(
                turns: open ? (Directionality.of(context) == TextDirection.rtl ? -0.25 : 0.25) : 0,
                duration: context.uiAnimate ? t.motionFast : Duration.zero,
                curve: t.easeStandard,
                child: UiIcon(HugeIcons.strokeRoundedArrowRight01, size: 14, strokeWidth: 2, matchTextDirection: true, color: s.hovered ? t.text : t.textMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
