import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../badge/badge.dart';
import '../button/button.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../dialog/bottom_sheet.dart';
import '../dialog/drawer.dart';
import '../dialog/route.dart';
import '../forms/choice/marks.dart';
import '../forms/text/inputs.dart';
import '../overlay/anchored.dart';
import '../overlay/panel.dart';
import '../theme/theme.dart';
import 'filter_model.dart';

export 'filter_model.dart';

/// `ui-filter-button`: the one compact "Filter" button a toolbar needs however many filters there
/// are. A filter icon and the label; while filters are on, a count bubble ("2") that screen readers
/// hear as "Filter, 2 on". [UiFilter] opens its panel from it.
class UiFilterButton extends StatelessWidget {
  const UiFilterButton({super.key, this.count = 0, required this.onPressed, this.label, this.size = UiSize.sm});

  /// How many filters are on ([uiFilterCount]): the badge.
  final int count;
  final VoidCallback? onPressed;

  /// The visible words; null: the strings' filter ("Filter").
  final String? label;
  final UiSize size;

  @override
  Widget build(BuildContext context) {
    final strings = context.uiStrings;
    final on = count > 0;
    return UiButton(
      label: label ?? strings.filter,
      icon: const UiIcon(HugeIcons.strokeRoundedFilterHorizontal),
      variant: on ? UiButtonVariant.secondary : UiButtonVariant.outline,
      size: size,
      badge: on ? (count > 9 ? '9+' : '$count') : null,
      badgeTone: UiBadgeTone.primary,
      badgeLabel: on ? uiFormatString(strings.filterOn, {'n': count}) : null,
      onPressed: onPressed,
    );
  }
}

/// `ui-filter-panel`: the sections of a filter, one under another, each a titled group of rows: the
/// section's "all" row (Everyone) first, then its options with their counts. A multiple section has
/// checkboxes (any chosen option passes), the others radios. From `searchAt` options (8) a section
/// gets a search field that narrows its rows. Every tap calls [onChanged] at once. Rows are at least
/// 44px tall (48dp to the touch). Not scrollable itself: put it in a scroll view, or use [UiFilter].
class UiFilterPanel extends StatefulWidget {
  const UiFilterPanel({super.key, required this.sections, required this.value, required this.onChanged});

  final List<UiFilterSection> sections;
  final UiFilterValue value;
  final ValueChanged<UiFilterValue> onChanged;

  @override
  State<UiFilterPanel> createState() => _UiFilterPanelState();
}

class _UiFilterPanelState extends State<UiFilterPanel> {
  final Map<String, String> _queries = {};

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final strings = context.uiStrings;
    final children = <Widget>[];
    for (final s in widget.sections) {
      if (children.isNotEmpty) children.add(SizedBox(height: t.space4));
      final query = (_queries[s.id] ?? '').trim().toLowerCase();
      final shown = query.isEmpty ? s.options : [for (final o in s.options) if (o.label.toLowerCase().contains(query)) o];
      final chosen = widget.value[s.id] ?? const <String>[];
      children.add(Semantics(
        container: true,
        explicitChildNodes: true,
        label: s.title,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: EdgeInsetsDirectional.only(start: t.space2, end: t.space2, bottom: t.space1),
            child: Semantics(
              header: true,
              child: Text(s.title, style: context.uiText.caption.copyWith(fontSize: t.fontSizeSm, fontWeight: FontWeight.w600, color: t.textMuted)),
            ),
          ),
          if (s.options.length >= s.searchAt)
            Padding(
              padding: EdgeInsets.only(bottom: t.space1),
              child: UiSearchInput(
                size: UiSize.sm,
                label: s.title,
                value: _queries[s.id] ?? '',
                onChanged: (q) => setState(() => _queries[s.id] = q),
              ),
            ),
          if (query.isEmpty)
            _UiFilterRow(
              label: s.allLabel ?? strings.filterAll,
              count: s.allCount,
              on: chosen.isEmpty,
              round: !s.multiple,
              onTap: () {
                if (chosen.isNotEmpty) widget.onChanged(uiFilterSet(widget.value, s.id, const []));
              },
            ),
          for (final o in shown)
            _UiFilterRow(
              label: o.label,
              count: o.count,
              on: chosen.contains(o.id),
              round: !s.multiple,
              onTap: () => widget.onChanged(uiFilterToggle(s, widget.value, o.id)),
            ),
          if (shown.isEmpty)
            Padding(
              padding: EdgeInsets.all(t.space2),
              child: Text(strings.noResults, style: context.uiText.caption.copyWith(fontSize: t.fontSizeSm, color: t.textMuted)),
            ),
        ]),
      ));
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// One option row: the mark, the label, the count at the end; 44px tall at least.
class _UiFilterRow extends StatelessWidget {
  const _UiFilterRow({required this.label, required this.on, required this.round, required this.onTap, this.count});

  final String label;
  final int? count;
  final bool on;
  final bool round;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: UiInteractive(
        onTap: onTap,
        button: false,
        checked: on,
        pressScale: false,
        semanticLabel: count == null ? label : '$label, $count',
        excludeChildSemantics: true,
        builder: (context, states) => AnimatedContainer(
          duration: context.uiAnimate ? t.motionFast : Duration.zero,
          constraints: const BoxConstraints(minHeight: 44),
          padding: EdgeInsets.symmetric(horizontal: t.space2),
          decoration: BoxDecoration(
            color: states.hovered || states.pressed ? t.surfaceHover : const Color(0x00000000),
            borderRadius: BorderRadius.circular(t.radiusSm),
            boxShadow: states.focused ? t.focusRing : null,
          ),
          child: Row(children: [
            round ? UiRadioMark(selected: on, states: states) : UiCheckMark(value: on, states: states),
            SizedBox(width: t.space3),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: t.space2),
                child: Text(label, style: context.uiText.body.copyWith(fontSize: t.fontSizeMd, color: t.text, height: 1.35)),
              ),
            ),
            if (count != null) ...[
              SizedBox(width: t.space2),
              Text('$count', style: context.uiText.caption.copyWith(fontSize: t.fontSizeSm, color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ]),
        ),
      ),
    );
  }
}

/// `ui-filter-footer`: Clear all (off while nothing is on) and the close button, "Show 12" when
/// [resultCount] is given, else "Done".
class UiFilterFooter extends StatelessWidget {
  const UiFilterFooter({super.key, required this.count, this.resultCount, required this.onClearAll, required this.onDone});

  /// How many filters are on.
  final int count;

  /// How many items pass, for "Show 12"; null for "Done".
  final int? resultCount;
  final VoidCallback onClearAll;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final strings = context.uiStrings;
    return Row(children: [
      UiButton(label: strings.filterClearAll, variant: UiButtonVariant.ghost, onPressed: count == 0 ? null : onClearAll),
      const Spacer(),
      UiButton(label: resultCount == null ? strings.filterDone : uiFormatString(strings.filterShow, {'n': resultCount}), onPressed: onDone),
    ]);
  }
}

/// What the open sheet shows, kept current while the page behind changes.
class _Live {
  const _Live(this.sections, this.value, this.resultCount);
  final List<UiFilterSection> sections;
  final UiFilterValue value;
  final int? resultCount;
}

/// `ui-filter`: a [UiFilterButton] that opens the filter panel. On a narrow screen (under
/// [narrowAt], 600px) the panel is a modal bottom sheet with the footer pinned to it; on a wider one
/// it is a popover under the button, 340px wide, whose body scrolls between its title and footer.
/// Each tap in the panel calls [onChanged] at once, so the page behind updates as you choose; the
/// footer's "Show N" (from [resultCount]) or Done closes it, Clear all turns every section off.
/// Escape, a tap outside, a drag down and the back button close it too.
///
/// Add a section to [sections] to add a filter: the toolbar keeps its one button.
class UiFilter extends StatefulWidget {
  const UiFilter({
    super.key,
    required this.sections,
    required this.value,
    required this.onChanged,
    this.resultCount,
    this.label,
    this.title,
    this.size = UiSize.sm,
    this.enabled = true,
    this.narrowAt = 600,
  });

  final List<UiFilterSection> sections;
  final UiFilterValue value;
  final ValueChanged<UiFilterValue> onChanged;

  /// How many items pass the current value, for the footer's "Show 12"; null for "Done".
  final int? resultCount;

  /// The button's words; null: "Filter".
  final String? label;

  /// The panel's title; null: the button's words.
  final String? title;
  final UiSize size;
  final bool enabled;

  /// Below this width (logical px) the panel is a bottom sheet.
  final double narrowAt;

  @override
  State<UiFilter> createState() => _UiFilterState();
}

class _UiFilterState extends State<UiFilter> {
  final OverlayPortalController _popover = OverlayPortalController();
  late final ValueNotifier<_Live> _live = ValueNotifier(_Live(widget.sections, widget.value, widget.resultCount));
  bool _sheetOpen = false;
  final FocusNode _panelFocus = FocusNode(debugLabel: 'UiFilter panel', skipTraversal: true);

  @override
  void didUpdateWidget(UiFilter old) {
    super.didUpdateWidget(old);
    // The open sheet is another route: tell it after this build, never during it.
    final live = _Live(widget.sections, widget.value, widget.resultCount);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _live.value = live;
    });
  }

  @override
  void dispose() {
    _live.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  String _heading(UiStrings strings) => widget.title ?? widget.label ?? strings.filter;

  void _change(UiFilterValue v) {
    // Shown at once in the open panel, before the page rebuilds this widget with it.
    _live.value = _Live(_live.value.sections, v, _live.value.resultCount);
    widget.onChanged(v);
  }

  void _toggle() {
    if (_popover.isShowing) return _closePopover();
    if (MediaQuery.sizeOf(context).width < widget.narrowAt) {
      _openSheet();
    } else {
      setState(_popover.show);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _popover.isShowing) _panelFocus.requestFocus();
      });
    }
  }

  void _closePopover() {
    if (_popover.isShowing) setState(_popover.hide);
  }

  Future<void> _openSheet() async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    final strings = context.uiStrings;
    final heading = _heading(strings);
    await Navigator.of(context, rootNavigator: true).push<void>(UiDialogRoute<void>.themed(
      context,
      transitions: (context, animation, child) => uiSheetTransition(context, animation, child, UiDrawerSide.bottom),
      builder: (routeContext) => ValueListenableBuilder<_Live>(
        valueListenable: _live,
        builder: (context, live, _) => Stack(children: [
          UiBottomSheet(
            title: heading,
            snaps: const [0, 0.85],
            snap: 1,
            closable: true,
            maxWidth: 560,
            // Closed by its X, a drag or Back: the route goes too.
            onSnapChanged: (i) {
              if (i == 0) Navigator.of(routeContext).pop();
            },
            footer: UiFilterFooter(
              count: uiFilterCount(live.value),
              resultCount: live.resultCount,
              onClearAll: () => _change(const {}),
              onDone: () => Navigator.of(routeContext).pop(),
            ),
            child: UiFilterPanel(sections: live.sections, value: live.value, onChanged: _change),
          ),
        ]),
      ),
    ));
    _sheetOpen = false;
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
      _closePopover();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final strings = context.uiStrings;
    final heading = _heading(strings);
    return UiAnchoredOverlay(
      controller: _popover,
      placement: UiPlacement.bottomStart,
      onDismiss: _closePopover,
      panelBuilder: (context, anchor) {
        final screen = MediaQuery.sizeOf(context);
        return Semantics(
          container: true,
          explicitChildNodes: true,
          role: SemanticsRole.dialog,
          label: heading,
          child: Focus(
            focusNode: _panelFocus,
            onKeyEvent: _onKey,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: math.min(340, screen.width - 16), minWidth: math.min(340, screen.width - 16), maxHeight: math.min(560, screen.height * 0.7)),
              child: UiOverlayPanel(
                padding: EdgeInsets.zero,
                origin: AlignmentDirectional.topStart.resolve(Directionality.of(context)),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(t.space4, t.space3, t.space4, t.space2),
                    child: Semantics(header: true, child: Text(heading, style: context.uiText.body.copyWith(fontSize: t.fontSizeMd, fontWeight: FontWeight.w600, color: t.text))),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(t.space2, 0, t.space2, t.space3),
                      child: UiFilterPanel(sections: widget.sections, value: widget.value, onChanged: _change),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
                      child: UiFilterFooter(
                        count: uiFilterCount(widget.value),
                        resultCount: widget.resultCount,
                        onClearAll: () => _change(const {}),
                        onDone: _closePopover,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
      child: UiFilterButton(
        count: uiFilterCount(widget.value),
        label: widget.label,
        size: widget.size,
        onPressed: widget.enabled ? _toggle : null,
      ),
    );
  }
}

/// `ui-filter-chips`: the filters that are on, as small chips ("Aisha" with a remove button) with
/// Clear all after them, for under a toolbar. Nothing shows while no filter is on.
class UiFilterChips extends StatelessWidget {
  const UiFilterChips({super.key, required this.sections, required this.value, required this.onChanged, this.label});

  final List<UiFilterSection> sections;
  final UiFilterValue value;
  final ValueChanged<UiFilterValue> onChanged;

  /// The group's accessible name; null: "Filter".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final strings = context.uiStrings;
    final active = uiActiveFilters(sections, value);
    if (active.isEmpty) return const SizedBox.shrink();
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: label ?? strings.filter,
      // One token both ways, as the web's ui-filter-chips (gap: --ui-space-2).
      child: Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (final a in active)
          UiChip(
            key: ValueKey('${a.section}:${a.option}'),
            label: a.label,
            tone: UiStatus.primary,
            onRemove: () => onChanged(uiFilterRemove(value, a.section, a.option)),
          ),
        UiButton(label: strings.filterClearAll, variant: UiButtonVariant.ghost, size: UiSize.sm, onPressed: () => onChanged(const {})),
      ]),
    );
  }
}
