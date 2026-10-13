import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../theme/theme.dart';

/// A node of a [UiTree].
@immutable
class UiTreeNode {
  const UiTreeNode({required this.label, required this.value, this.icon, this.children = const []});

  final String label;
  final String value;

  /// A Hugeicons icon, drawn at 16px in the muted colour.
  final UiIconData? icon;
  final List<UiTreeNode> children;

  bool get hasChildren => children.isNotEmpty;
}

class _Info {
  const _Info(this.node, this.parent, this.depth, this.index, this.count);
  final UiTreeNode node;
  final String? parent;
  final int depth;
  final int index;
  final int count;
}

/// `ui-tree`: an expandable hierarchy with single selection, following the WAI-ARIA tree view
/// pattern as far as Flutter's accessibility can carry it.
///
/// A tap on a row selects it ([onSelect]); a tap on the chevron opens or closes it without selecting.
/// Each row is read with its level and position ("level 2, 1 of 3"), its expanded state, and
/// selection, and offers expand/collapse actions to screen readers.
///
/// Keyboard: one tab stop (the last focused item, else the selected one, else the first); Up/Down
/// move through visible items, Home/End jump to the ends, Right opens a closed parent and then moves
/// to its first child, Left closes an open parent and then moves to the parent, Enter/Space select,
/// `*` opens every sibling, and typing a letter jumps to the next item starting with it.
class UiTree extends StatefulWidget {
  const UiTree({super.key, required this.nodes, this.selected, this.onSelect, this.label, this.initiallyExpanded = const {}});

  final List<UiTreeNode> nodes;

  /// Value of the selected node.
  final String? selected;
  final ValueChanged<UiTreeNode>? onSelect;

  /// Accessible name of the tree.
  final String? label;
  final Set<String> initiallyExpanded;

  @override
  State<UiTree> createState() => _UiTreeState();
}

class _UiTreeState extends State<UiTree> {
  late Set<String> _expanded = {...widget.initiallyExpanded};
  String? _active;
  final Map<String, FocusNode> _nodes = {};

  @override
  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  Map<String, _Info> get _index {
    final map = <String, _Info>{};
    void walk(List<UiTreeNode> list, String? parent, int depth) {
      for (var i = 0; i < list.length; i++) {
        final n = list[i];
        map[n.value] = _Info(n, parent, depth, i, list.length);
        if (n.hasChildren) walk(n.children, n.value, depth + 1);
      }
    }

    walk(widget.nodes, null, 0);
    return map;
  }

  /// Values of the rows on screen, top to bottom.
  List<String> get _visible {
    final out = <String>[];
    void walk(List<UiTreeNode> list) {
      for (final n in list) {
        out.add(n.value);
        if (n.hasChildren && _expanded.contains(n.value)) walk(n.children);
      }
    }

    walk(widget.nodes);
    return out;
  }

  String? get _tabStop {
    final vis = _visible;
    if (_active != null && vis.contains(_active)) return _active;
    if (widget.selected != null && vis.contains(widget.selected)) return widget.selected;
    return vis.isEmpty ? null : vis.first;
  }

  FocusNode _node(String v) => _nodes.putIfAbsent(v, () => FocusNode(debugLabel: 'tree $v'));

  void _focus(String? v) {
    if (v == null) return;
    setState(() => _active = v);
    _node(v).requestFocus();
  }

  void _setOpen(UiTreeNode n, bool open) {
    if (!n.hasChildren || _expanded.contains(n.value) == open) return;
    setState(() => _expanded = open ? ({..._expanded, n.value}) : ({..._expanded}..remove(n.value)));
  }

  bool _isInside(String value, String ancestor, Map<String, _Info> index) {
    var p = index[value]?.parent;
    while (p != null) {
      if (p == ancestor) return true;
      p = index[p]?.parent;
    }
    return false;
  }

  void _toggle(UiTreeNode n) {
    final closing = _expanded.contains(n.value);
    // Collapsing over the focused item would drop focus; move it to the collapsed parent.
    if (closing && _active != null && _isInside(_active!, n.value, _index)) {
      final hadFocus = _nodes[_active]?.hasFocus ?? false;
      _active = n.value;
      if (hadFocus) _node(n.value).requestFocus();
    }
    _setOpen(n, !closing);
  }

  void _choose(UiTreeNode n) => widget.onSelect?.call(n);

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final index = _index;
    final value = _nodes.entries.where((en) => en.value.hasFocus).map((en) => en.key).firstOrNull;
    final info = value == null ? null : index[value];
    if (info == null || value == null) return KeyEventResult.ignored;
    final n = info.node;
    final vis = _visible;
    final at = vis.indexOf(value);
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      _focus(vis[(at + 1).clamp(0, vis.length - 1)]);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _focus(vis[(at - 1).clamp(0, vis.length - 1)]);
    } else if (k == LogicalKeyboardKey.home) {
      _focus(vis.first);
    } else if (k == LogicalKeyboardKey.end) {
      _focus(vis.last);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      if (n.hasChildren) _expanded.contains(n.value) ? _focus(n.children.first.value) : _setOpen(n, true);
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      if (n.hasChildren && _expanded.contains(n.value)) {
        _setOpen(n, false);
      } else if (info.parent != null) {
        _focus(info.parent);
      }
    } else if (e.character == '*') {
      final siblings = info.parent == null ? widget.nodes : index[info.parent]!.node.children;
      setState(() => _expanded = {..._expanded, for (final s in siblings) if (s.hasChildren) s.value});
    } else {
      final ch = e.character;
      final mods = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isAltPressed;
      if (ch == null || ch.length != 1 || ch.trim().isEmpty || mods) return KeyEventResult.ignored;
      // The next visible item (after this one, wrapping) whose label starts with the letter.
      final want = ch.toLowerCase();
      for (var j = 1; j <= vis.length; j++) {
        final v = vis[(at + j) % vis.length];
        if (index[v]!.node.label.toLowerCase().startsWith(want)) {
          _focus(v);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final index = _index;
    final vis = _visible;
    final stop = _tabStop;
    // Drop focus nodes of rows that no longer exist.
    for (final v in _nodes.keys.where((v) => !index.containsKey(v)).toList()) {
      _nodes.remove(v)!.dispose();
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.label,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: _onKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final v in vis)
              _TreeRow(
                // Keyed by value: rows shift when a parent opens, and must keep their own state.
                key: ValueKey(v),
                info: index[v]!,
                focusNode: _node(v)..skipTraversal = v != stop,
                open: _expanded.contains(v),
                selected: v == widget.selected,
                onTap: () {
                  setState(() => _active = v);
                  _choose(index[v]!.node);
                },
                onToggle: () => _toggle(index[v]!.node),
                onFocus: () => setState(() => _active = v),
              ),
          ],
        ),
      ),
    );
  }
}

class _TreeRow extends StatelessWidget {
  const _TreeRow({super.key, required this.info, required this.focusNode, required this.open, required this.selected, required this.onTap, required this.onToggle, required this.onFocus});
  final _Info info;
  final FocusNode focusNode;
  final bool open;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    final n = info.node;
    final kids = n.hasChildren;
    // On touch the chevron's hit area widens to fill the row's height.
    final chevW = touch ? 36.0 : 24.0;
    return UiInteractive(
      onTap: onTap,
      focusNode: focusNode,
      button: false,
      selected: selected,
      pressScale: false,
      padTouchTarget: false,
      onFocusChange: (f) {
        if (f) onFocus();
      },
      builder: (context, s) => Semantics(
        label: n.label,
        hint: 'level ${info.depth + 1}, ${info.index + 1} of ${info.count}',
        expanded: kids ? open : null,
        onExpand: kids && !open ? onToggle : null,
        onCollapse: kids && open ? onToggle : null,
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: context.uiAnimate ? t.motionFast : Duration.zero,
            curve: t.easeStandard,
            constraints: BoxConstraints(minHeight: touch ? uiMinTouchTarget : 0),
            padding: EdgeInsetsDirectional.only(start: math.max(0, t.space2 - (chevW - 16) / 2) + info.depth * 16, end: t.space2, top: touch ? 0 : t.space1, bottom: touch ? 0 : t.space1),
            decoration: BoxDecoration(
              color: selected ? t.selected : (s.hovered || s.pressed ? t.surfaceHover : null),
              borderRadius: BorderRadius.circular(t.radiusXs),
            ),
            foregroundDecoration: s.focused
                ? BoxDecoration(border: Border.all(color: t.borderFocus, width: 2), borderRadius: BorderRadius.circular(t.radiusXs))
                : null,
            child: Row(spacing: t.space1, children: [
              // The chevron draws in the row's 16px slot; its hit box is bigger, overlapping the padding.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: kids ? onToggle : null,
                child: SizedBox(
                  width: chevW,
                  height: touch ? uiMinTouchTarget : 24,
                  child: kids
                      ? Center(
                          child: AnimatedRotation(
                            turns: open ? 0.25 : 0,
                            duration: context.uiAnimate ? t.motionFast : Duration.zero,
                            curve: t.easeStandard,
                            child: UiIcon(HugeIcons.strokeRoundedArrowRight01, size: 14, color: t.textMuted, strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
              if (n.icon != null) SizedBox(width: 16, child: UiIcon(n.icon!, size: 16, color: t.textMuted)),
              Expanded(
                child: Text(n.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.35)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
