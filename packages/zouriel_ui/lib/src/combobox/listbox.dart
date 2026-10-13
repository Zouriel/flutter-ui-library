import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';
import '../core/fonts.dart';

/// The style that previews a font: [family] (from [package] when the font is bundled in a package,
/// e.g. `'zouriel_ui'`), falling back to the theme font for missing glyphs. Null when there's no
/// family. The Flutter twin of the web `uiFontStack`.
TextStyle? uiFontPreviewStyle(BuildContext context, String? family, {String? package}) {
  final f = family?.trim() ?? '';
  if (f.isEmpty) return null;
  final base = context.uiText.body.fontFamily;
  return TextStyle(
    fontFamily: package == null || package.isEmpty ? f : 'packages/$package/$f',
    fontFamilyFallback: [?base],
  );
}

/// One row of a listbox panel, as the panel needs it.
class UiListItem {
  const UiListItem({required this.label, this.disabled = false, this.selected = false, this.style});
  final String label;
  final bool disabled;
  final bool selected;

  /// Extra text style for the label (a preview font).
  final TextStyle? style;
}

/// The raised option list shared by the select, combobox and multi-select (the web `.panel`):
/// rows with the active one highlighted and the chosen ones tinted, an optional checkbox per row,
/// "No results" when empty, at most [maxHeight] tall and scrolling the active row into view.
class UiListboxPanel extends StatefulWidget {
  const UiListboxPanel({
    super.key,
    required this.items,
    required this.activeIndex,
    required this.onPick,
    this.onHover,
    this.checkboxes = false,
    this.maxHeight = 240,
    this.multiselect = false,
    this.semanticLabel,
    this.emptyText = 'No results',
  });

  final List<UiListItem> items;
  final int activeIndex;
  final ValueChanged<int> onPick;
  final ValueChanged<int>? onHover;
  final bool checkboxes;
  final double maxHeight;
  final bool multiselect;
  final String? semanticLabel;
  final String emptyText;

  @override
  State<UiListboxPanel> createState() => _UiListboxPanelState();
}

class _UiListboxPanelState extends State<UiListboxPanel> {
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _keys = {};

  GlobalKey _key(int i) => _keys.putIfAbsent(i, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(center: true));
  }

  @override
  void didUpdateWidget(UiListboxPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndex != widget.activeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the active row in view in a long list.
  void _reveal({bool center = false}) {
    if (!mounted) return;
    final ctx = _keys[widget.activeIndex]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: center ? 0.5 : 0,
      alignmentPolicy: center ? ScrollPositionAlignmentPolicy.explicit : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      duration: Duration.zero,
    );
    if (!center) {
      Scrollable.ensureVisible(ctx, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart, duration: Duration.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final ty = context.uiText;
    final touch = uiTouchPlatform(context);
    final rowStyle = ty.body.copyWith(fontSize: t.fontSizeMd, height: 1.35, color: t.text);

    Widget row(int i) {
      final item = widget.items[i];
      final active = i == widget.activeIndex;
      final fill = item.selected
          ? (active ? uiMix(t.selected, 0.5, t.elevatedHover) : t.selected)
          : active
              ? t.elevatedHover
              : null;
      var style = rowStyle.copyWith(fontWeight: item.selected && !widget.checkboxes ? FontWeight.w600 : null);
      if (item.disabled) style = style.copyWith(color: t.textMuted);
      style = uiApplyFont(style, item.style);
      return KeyedSubtree(
        key: _key(i),
        child: MouseRegion(
          onEnter: item.disabled ? null : (_) => widget.onHover?.call(i),
          child: UiInteractive(
            onTap: () => widget.onPick(i),
            enabled: !item.disabled,
            button: false,
            selected: widget.multiselect ? null : item.selected,
            checked: widget.multiselect ? item.selected : null,
            semanticLabel: item.label,
            excludeChildSemantics: true,
            pressScale: false,
            padTouchTarget: false,
            builder: (context, s) => Container(
              constraints: BoxConstraints(minHeight: touch ? uiMinTouchTarget : 0),
              padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
              alignment: AlignmentDirectional.centerStart,
              decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(theme.radius(t.radiusXs))),
              child: Row(spacing: t.space2, children: [
                if (widget.checkboxes) _Box(checked: item.selected),
                Expanded(child: Text(item.label, style: style)),
              ]),
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: Container(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(theme.radius()),
          boxShadow: t.shadow2,
        ),
        child: widget.items.isEmpty
            ? Padding(
                padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space3),
                child: Text(widget.emptyText, style: ty.caption.copyWith(height: 1.35)),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(theme.radius()),
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: EdgeInsets.all(t.space1),
                  // Rows aren't tab stops: the field (or the list) owns the keyboard.
                  child: ExcludeFocus(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [for (var i = 0; i < widget.items.length; i++) row(i)],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// The 16px checkbox drawn in multi-select rows (the web `.box` with its tick).
class _Box extends StatelessWidget {
  const _Box({required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: checked ? t.primary : t.surface,
        border: Border.all(color: checked ? t.primary : t.controlBorder),
        borderRadius: BorderRadius.circular(context.uiTheme.radius(t.radiusXs)),
      ),
      child: checked ? CustomPaint(painter: _TickPainter(t.primaryContrast)) : null,
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // The web path "M3 8.5l3 3 7-7" in a 16 box, drawn at 11px centred.
    final s = math.min(size.width, size.height) / 16;
    final path = Path()
      ..moveTo(3 * s, 8.5 * s)
      ..lineTo(6 * s, 11.5 * s)
      ..lineTo(13 * s, 4.5 * s);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.color != color;
}
