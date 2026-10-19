import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../theme/theme.dart';

/// One tab of a [UiTabs]: its [label] and its panel [child].
///
/// An optional Hugeicons [icon] draws before the label. With [iconOnly] the label isn't shown but is
/// still the tab's accessible name.
@immutable
class UiTab {
  const UiTab({required this.label, required this.child, this.icon, this.iconOnly = false, this.disabled = false});

  final String label;
  final Widget child;
  final UiIconData? icon;
  final bool iconOnly;
  final bool disabled;
}

/// `ui-tabs`: tabs over panels. [selectedIndex] is the open tab; [onChanged] reports a new one.
///
/// The tab strip scrolls sideways when it holds more tabs than fit (a two-word tab never wraps), and
/// keeps the selected tab in view. Inactive panels stay mounted (their state survives) but take no
/// space and are hidden from screen readers. Keyboard, as on the web: one tab stop; Left/Right move
/// and select (wrapping, skipping disabled tabs), Home/End jump to the ends. When every tab is
/// [UiTab.iconOnly] they share the strip evenly.
class UiTabs extends StatefulWidget {
  const UiTabs({super.key, required this.tabs, this.selectedIndex = 0, this.onChanged, this.label = 'Tabs'});

  final List<UiTab> tabs;
  final int selectedIndex;
  final ValueChanged<int>? onChanged;

  /// Accessible name of the tab strip.
  final String label;

  @override
  State<UiTabs> createState() => _UiTabsState();
}

class _UiTabsState extends State<UiTabs> {
  final List<FocusNode> _nodes = [];
  final List<GlobalKey> _keys = [];

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

  KeyEventResult _onKey(int i, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final count = widget.tabs.length;
    final k = e.logicalKey;
    int next;
    int step;
    if (k == LogicalKeyboardKey.arrowRight) {
      next = (i + 1) % count;
      step = 1;
    } else if (k == LogicalKeyboardKey.arrowLeft) {
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
    final even = widget.tabs.isNotEmpty && widget.tabs.every((tab) => tab.iconOnly && tab.icon != null);
    final tabs = [
      for (var i = 0; i < widget.tabs.length; i++)
        Focus(
          canRequestFocus: false,
          includeSemantics: false,
          skipTraversal: true,
          onKeyEvent: (_, e) => _onKey(i, e),
          child: _TabButton(
            key: _keys[i],
            tab: widget.tabs[i],
            selected: i == widget.selectedIndex,
            focusNode: _nodes[i],
            onTap: () => _select(i),
          ),
        ),
    ];
    final strip = Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.tabBar,
      label: widget.label,
      child: even
          ? Row(spacing: t.space1, children: [for (final w in tabs) Expanded(child: w)])
          : Row(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: tabs),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The strip's 1px rule runs under the tabs, so the selected tab's 2px line covers it.
        Stack(children: [
          Positioned(left: 0, right: 0, bottom: 0, height: 1, child: ColoredBox(color: t.border)),
          if (even) strip else SingleChildScrollView(scrollDirection: Axis.horizontal, child: strip),
        ]),
        SizedBox(height: t.space4),
        for (var i = 0; i < widget.tabs.length; i++)
          Visibility(
            visible: i == widget.selectedIndex,
            maintainState: true,
            child: Semantics(container: true, role: SemanticsRole.tabPanel, label: widget.tabs[i].label, child: widget.tabs[i].child),
          ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({super.key, required this.tab, required this.selected, required this.focusNode, required this.onTap});
  final UiTab tab;
  final bool selected;
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
          if (!iconOnly) Text(tab.label, maxLines: 1, softWrap: false, style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.35, color: fg)),
        ]);
        // The role sits inside the builder so UiInteractive's merged node carries it.
        return Semantics(
          role: SemanticsRole.tab,
          label: iconOnly ? tab.label : null,
          child: Opacity(
            opacity: s.disabled ? 0.5 : 1,
            child: AnimatedContainer(
              duration: context.uiAnimate ? t.motionBase : Duration.zero,
              curve: t.easeStandard,
              constraints: BoxConstraints(minHeight: touch ? uiMinTouchTarget : 0, minWidth: iconOnly ? t.sizeTouch : 0),
              padding: EdgeInsets.symmetric(vertical: t.space2, horizontal: t.space3),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: selected ? t.primary : const Color(0x00000000), width: 2)),
              ),
              // The strip scrolls (and clips), so the ring sits inside the tab.
              foregroundDecoration: s.focused
                  ? BoxDecoration(border: Border.all(color: t.borderFocus, width: 2), borderRadius: BorderRadius.circular(t.radiusXs))
                  : null,
              child: Align(
                widthFactor: 1,
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
