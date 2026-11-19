import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../guidance/tour.dart';
import '../theme/theme.dart';

/// Horizontal distribution of tabs along the strip (the web `align` input).
enum UiTabsAlignment { start, center, fill }

/// Visual treatment of the tab strip (the web `appearance` input).
enum UiTabsAppearance { line, glow }

/// One tab of a [UiTabs]: its [label] and optional panel [child]. Omit [child] on every tab for
/// strip-only mode (no panel gap or tab panels).
///
/// An optional Hugeicons [icon] draws before the label. With [iconOnly] the label isn't shown but is
/// still the tab's accessible name.
@immutable
class UiTab {
  const UiTab({
    required this.label,
    this.child,
    this.icon,
    this.iconOnly = false,
    this.disabled = false,
    this.anchor,
    this.badge,
    this.badgeLabel,
  });

  final String label;
  final Widget? child;
  final UiIconData? icon;
  final bool iconOnly;
  final bool disabled;

  /// A tour anchor id ([UiTourAnchor]) for this tab's button, so a [UiTour] step can point at it.
  /// Null: no anchor.
  final String? anchor;

  /// A small count after the label (e.g. unread messages; the web `badge`). Nothing shows for null, '' or
  /// '0' (0.79). Screen readers hear it after the label, or [badgeLabel] instead when given ("3 new").
  final String? badge;
  final String? badgeLabel;

  /// The badge as shown, or null when there is none.
  String? get badgeText => badge == null || badge!.isEmpty || badge == '0' ? null : badge;
}

/// `ui-tabs`: tabs over panels. [selectedIndex] is the open tab; [onChanged] reports a new one.
///
/// The tab strip scrolls sideways when it holds more tabs than fit (a two-word tab never wraps), and
/// keeps the selected tab in view. Inactive panels stay mounted (their state survives) but take no
/// space and are hidden from screen readers. Keyboard, as on the web: one tab stop; Left/Right move
/// and select (wrapping, skipping disabled tabs), Home/End jump to the ends. When every tab is
/// [UiTab.iconOnly], or [align] is [UiTabsAlignment.fill], they share the strip evenly. With
/// [UiTabsAlignment.center] the strip centres when tabs fit and scrolls when wider.
/// When no tab provides a [UiTab.child], only the strip renders (no panel gap).
class UiTabs extends StatefulWidget {
  const UiTabs({
    super.key,
    required this.tabs,
    this.selectedIndex = 0,
    this.onChanged,
    this.label,
    this.align = UiTabsAlignment.start,
    this.appearance = UiTabsAppearance.line,
  });

  final List<UiTab> tabs;
  final int selectedIndex;
  final ValueChanged<int>? onChanged;

  /// Accessible name of the tab strip.
  /// The tab list's name; [UiStrings.tabs] when null.
  final String? label;

  /// Alignment/distribution of tabs along the strip. [UiTabsAlignment.fill] gives every tab an
  /// equal share of the available width and ellipsizes long labels.
  final UiTabsAlignment align;

  /// [UiTabsAppearance.line] keeps the underline and rule; [UiTabsAppearance.glow] replaces both
  /// with one soft accent glow that moves to the selected tab.
  final UiTabsAppearance appearance;

  @override
  State<UiTabs> createState() => _UiTabsState();
}

class _UiTabsState extends State<UiTabs> {
  final List<FocusNode> _nodes = [];
  final List<GlobalKey> _keys = [];
  final GlobalKey _stripKey = GlobalKey();
  double? _glowLeft;
  double? _glowWidth;
  bool _glowMeasureQueued = false;

  void _sync() {
    while (_nodes.length < widget.tabs.length) {
      _nodes.add(FocusNode(debugLabel: 'tab ${_nodes.length}'));
      _keys.add(GlobalKey());
    }
    for (var i = 0; i < widget.tabs.length; i++) {
      // Roving tab stop: only the selected tab is reached with Tab.
      _nodes[i].skipTraversal = i != widget.selectedIndex;
    }
  }

  @override
  void didUpdateWidget(UiTabs old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex || old.appearance != widget.appearance || old.align != widget.align) {
      _measureGlowNow();
    }
    if (old.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(widget.selectedIndex));
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// Scroll the strip just enough to show the tab (the web `scrollIntoView({inline: 'nearest'})`).
  void _reveal(int i) {
    if (!mounted || i >= _keys.length) return;
    final box = _keys[i].currentContext?.findRenderObject();
    if (box == null || !box.attached) return;
    box.showOnScreen(duration: context.uiAnimate ? context.ui.motionBase : Duration.zero, curve: context.ui.easeStandard);
  }

  void _select(int i) {
    if (widget.tabs[i].disabled || i == widget.selectedIndex) return;
    widget.onChanged?.call(i);
  }

  bool _measureGlowNow() {
    if (!mounted || widget.appearance != UiTabsAppearance.glow || widget.selectedIndex >= _keys.length) return false;
    final strip = _stripKey.currentContext?.findRenderObject();
    final tab = _keys[widget.selectedIndex].currentContext?.findRenderObject();
    if (strip is! RenderBox || tab is! RenderBox || !strip.attached || !tab.attached || !strip.hasSize || !tab.hasSize) return false;
    final left = tab.localToGlobal(Offset.zero, ancestor: strip).dx;
    final width = tab.size.width;
    if (_glowLeft != null && (left - _glowLeft!).abs() < 0.01 && _glowWidth != null && (width - _glowWidth!).abs() < 0.01) return false;
    _glowLeft = left;
    _glowWidth = width;
    return true;
  }

  void _queueGlowMeasure() {
    if (_glowMeasureQueued) return;
    _glowMeasureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _glowMeasureQueued = false;
      if (_measureGlowNow()) setState(() {});
    });
  }

  KeyEventResult _onKey(int i, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final count = widget.tabs.length;
    final k = e.logicalKey;
    int next;
    int step;
    // The tab row runs from the start edge, so in RTL ArrowLeft is the next tab.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    if (k == (rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight)) {
      next = (i + 1) % count;
      step = 1;
    } else if (k == (rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft)) {
      next = (i - 1 + count) % count;
      step = -1;
    } else if (k == LogicalKeyboardKey.home) {
      next = 0;
      step = 1;
    } else if (k == LogicalKeyboardKey.end) {
      next = count - 1;
      step = -1;
    } else {
      return KeyEventResult.ignored;
    }
    // Disabled tabs can't take focus, so step past them in the direction of travel.
    for (var n = 0; n < count && widget.tabs[next].disabled; n++) {
      next = (next + step + count) % count;
    }
    if (widget.tabs[next].disabled) return KeyEventResult.handled;
    _select(next);
    _nodes[next].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    final t = context.ui;
    final fill = widget.align == UiTabsAlignment.fill;
    final glow = widget.appearance == UiTabsAppearance.glow;
    final even = fill || (widget.tabs.isNotEmpty && widget.tabs.every((tab) => tab.iconOnly && tab.icon != null));
    final tabs = [
      for (var i = 0; i < widget.tabs.length; i++)
        Focus(
          canRequestFocus: false,
          includeSemantics: false,
          skipTraversal: true,
          onKeyEvent: (_, e) => _onKey(i, e),
          child: _anchored(
            widget.tabs[i].anchor,
            _TabButton(
              key: _keys[i],
              tab: widget.tabs[i],
              selected: i == widget.selectedIndex,
              fill: fill,
              glow: glow,
              focusNode: _nodes[i],
              onTap: () => _select(i),
            ),
          ),
        ),
    ];
    final row = even
        ? Row(spacing: t.space1, children: [for (final w in tabs) Expanded(child: w)])
        : Row(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: tabs);
    final strip = Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.tabBar,
      label: widget.label ?? context.uiStrings.tabs,
      child: Stack(
        key: _stripKey,
        clipBehavior: Clip.none,
        children: [
          if (glow && _glowLeft != null && _glowWidth != null)
            AnimatedPositioned(
              key: const ValueKey('ui-tab-glow'),
              duration: context.uiAnimate ? t.motionBase : Duration.zero,
              curve: t.easeStandard,
              left: _glowLeft,
              width: _glowWidth,
              bottom: 0,
              height: t.space6,
              child: IgnorePointer(child: ExcludeSemantics(child: CustomPaint(painter: _GlowPainter(t.primary)))),
            ),
          row,
        ],
      ),
    );
    if (glow) _queueGlowMeasure();
    final hasPanels = widget.tabs.any((tab) => tab.child != null);
    final Widget barContent;
    if (even) {
      barContent = strip;
    } else if (widget.align == UiTabsAlignment.center) {
      barContent = LayoutBuilder(builder: (context, box) {
        final minW = box.maxWidth.isFinite ? box.maxWidth : 0.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minW),
            child: Center(child: strip),
          ),
        );
      });
    } else {
      barContent = SingleChildScrollView(scrollDirection: Axis.horizontal, child: strip);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The strip's 1px rule runs under the tabs, so the selected tab's 2px line covers it.
        Stack(children: [
          if (!glow) Positioned(left: 0, right: 0, bottom: 0, height: 1, child: ColoredBox(color: t.border)),
          barContent,
        ]),
        if (hasPanels) ...[
          SizedBox(height: t.space4),
          for (var i = 0; i < widget.tabs.length; i++)
            Visibility(
              visible: i == widget.selectedIndex,
              maintainState: true,
              child: Semantics(
                container: true,
                role: SemanticsRole.tabPanel,
                label: widget.tabs[i].label,
                child: widget.tabs[i].child ?? const SizedBox.shrink(),
              ),
            ),
        ],
      ],
    );
  }
}

/// Wraps [child] in a [UiTourAnchor] when [id] is set; otherwise returns it unchanged.
Widget _anchored(String? id, Widget child) => id == null || id.isEmpty ? child : UiTourAnchor(id: id, child: child);

class _TabButton extends StatelessWidget {
  const _TabButton({super.key, required this.tab, required this.selected, required this.focusNode, required this.onTap, required this.fill, required this.glow});
  final UiTab tab;
  final bool selected;
  final bool fill;
  final bool glow;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    final iconOnly = tab.iconOnly && tab.icon != null;
    return UiInteractive(
      onTap: onTap,
      enabled: !tab.disabled,
      focusNode: focusNode,
      selected: selected,
      button: false,
      pressScale: false,
      padTouchTarget: false,
      builder: (context, s) {
        final fg = selected || s.hovered || s.pressed ? t.text : t.textMuted;
        final content = Row(mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
          if (tab.icon != null) UiIcon(tab.icon!, size: iconOnly ? 22 : 18, color: selected ? fg : (t.icon ?? fg)),
          if (!iconOnly)
            Flexible(
              child: Text(
                tab.label,
                maxLines: 1,
                softWrap: false,
                overflow: fill ? TextOverflow.ellipsis : TextOverflow.clip,
                style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.35, color: fg),
              ),
            ),
          if (tab.badgeText case final b?)
            Semantics(
              label: tab.badgeLabel ?? b,
              excludeSemantics: true,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(999)),
                child: Text(b,
                    maxLines: 1,
                    style: context.uiText.body.copyWith(
                        fontSize: 12, height: 1, fontWeight: FontWeight.w600, color: t.primaryContrast, fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            ),
        ]);
        // The role sits inside the builder so UiInteractive's merged node carries it.
        return Semantics(
          role: SemanticsRole.tab,
          label: iconOnly ? (tab.badgeText == null ? tab.label : '${tab.label}, ${tab.badgeLabel ?? tab.badgeText}') : null,
          child: Opacity(
            opacity: s.disabled ? 0.5 : 1,
            child: AnimatedContainer(
              duration: context.uiAnimate ? t.motionBase : Duration.zero,
              curve: t.easeStandard,
              constraints: BoxConstraints(minHeight: touch ? uiMinTouchTarget : 0, minWidth: iconOnly ? t.sizeTouch : 0),
              padding: EdgeInsets.symmetric(vertical: t.space2, horizontal: t.space3),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: selected && !glow ? t.primary : const Color(0x00000000), width: 2)),
              ),
              // The strip scrolls (and clips), so the ring sits inside the tab.
              foregroundDecoration: s.focused
                  ? BoxDecoration(border: Border.all(color: t.borderFocus, width: 2), borderRadius: BorderRadius.circular(t.radiusXs))
                  : null,
              child: Align(
                widthFactor: fill ? null : 1,
                heightFactor: 1,
                // Press feedback on the contents only, so the selected line doesn't shrink with it.
                child: AnimatedScale(
                  scale: s.pressed && context.uiAnimate ? t.scalePress : 1,
                  duration: t.motionFast,
                  curve: t.easeStandard,
                  child: iconOnly ? ExcludeSemantics(child: content) : content,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = size.width / 2;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(1, size.height / size.width);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.46), color.withValues(alpha: 0)],
          stops: const [0, 0.72],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => color != oldDelegate.color;
}
