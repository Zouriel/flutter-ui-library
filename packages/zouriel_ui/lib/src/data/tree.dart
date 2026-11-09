import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../theme/theme.dart';

/// A node of a [UiTree].
@immutable
class UiTreeNode {
  const UiTreeNode({required this.label, required this.value, this.icon, this.children = const [], this.muted = false, this.container = false});

  final String label;
  final String value;

  /// A Hugeicons icon, drawn at 16px in the muted colour.
  final UiIconData? icon;
  final List<UiTreeNode> children;

  /// Draw the label dimmed (a hidden layer, an archived item). It can still be selected.
  final bool muted;

  /// Can take dropped children while reordering, even with none yet (an empty group).
  final bool container;

  bool get hasChildren => children.isNotEmpty;
}

/// A reorder asked for in a [UiTree]: move node [value] so it ends up as child number [index] of
/// [parent] (null = top level). [index] counts the list after the node has been taken out.
@immutable
class UiTreeMove {
  const UiTreeMove({required this.value, required this.parent, required this.index});
  final String value;
  final String? parent;
  final int index;

  @override
  bool operator ==(Object other) => other is UiTreeMove && other.value == value && other.parent == parent && other.index == index;
  @override
  int get hashCode => Object.hash(value, parent, index);
  @override
  String toString() => 'UiTreeMove($value -> ${parent ?? 'top'} #$index)';
}

class _Info {
  const _Info(this.node, this.parent, this.depth, this.index, this.count);
  final UiTreeNode node;
  final String? parent;
  final int depth;
  final int index;
  final int count;
}

/// Where a dragged row would land relative to the row under the pointer.
enum _DropPos { before, after, inside, first }

class _Drop {
  const _Drop(this.value, this.pos, this.move);
  final String value;
  final _DropPos pos;
  final UiTreeMove move;
}

class _ToggleIntent extends Intent {
  const _ToggleIntent();
}

/// `ui-tree`: an expandable hierarchy following the WAI-ARIA tree view pattern as far as Flutter's
/// accessibility can carry it.
///
/// A tap on a row selects it ([onSelect]); a tap on the chevron opens or closes it without selecting.
/// Each row is read with its level and position ("level 2, 1 of 3"), its expanded state, and
/// selection, and offers expand/collapse actions to screen readers.
///
/// Keyboard: one tab stop (the last focused item, else the selected one, else the first); Up/Down
/// move through visible items, Home/End jump to the ends, Right opens a closed parent and then moves
/// to its first child, Left closes an open parent and then moves to the parent, Enter/Space select,
/// `*` opens every sibling, and typing a letter jumps to the next item starting with it.
///
/// For a layers panel:
/// - [multiple]: [selectedValues] is the selection ([onSelectedValuesChanged]). A tap selects only
///   that node, Ctrl/Cmd-tap toggles it, Shift-tap selects the visible range from the last tapped
///   node, Space toggles the focused node. [onSelect] still reports every tapped node, so [selected]
///   can follow the last one.
/// - [trailingBuilder]: controls at the end of each row (eye, lock). Taps on them never select the row.
/// - [reorderable]: drag rows with a mouse or pen (after a 4px move) or long-press then drag on touch;
///   Alt+Up/Down moves the focused node among its siblings. A line shows where the row will land, or an outline when it will go into a node that
///   has children or is a [UiTreeNode.container]; never into itself or its own descendants. The tree
///   doesn't change [nodes]: it calls [onMove] and the app moves the node.
/// - [expanded] + [onExpandedChanged]: the open nodes, held by the app (to open the ancestors of a
///   node it selects). Left null, the tree keeps its own, starting from [initiallyExpanded].
/// - [onActivate]: a double tap on a label, or F2 (to rename).
/// - [renamable]: those same triggers open an in-place editor; [onRename] reports a committed label.
class UiTree extends StatefulWidget {
  const UiTree({
    super.key,
    required this.nodes,
    this.selected,
    this.onSelect,
    this.label,
    this.initiallyExpanded = const {},
    this.expanded,
    this.onExpandedChanged,
    this.multiple = false,
    this.selectedValues = const [],
    this.onSelectedValuesChanged,
    this.trailingBuilder,
    this.reorderable = false,
    this.onMove,
    this.onActivate,
    this.renamable = false,
    this.onRename,
  });

  final List<UiTreeNode> nodes;

  /// Value of the selected node; with [multiple], the last tapped one.
  final String? selected;
  final ValueChanged<UiTreeNode>? onSelect;

  /// Accessible name of the tree.
  final String? label;
  final Set<String> initiallyExpanded;

  /// The open nodes, when the app holds them; null lets the tree keep its own.
  final Set<String>? expanded;
  final ValueChanged<Set<String>>? onExpandedChanged;

  /// Select several nodes; the selection is then [selectedValues].
  final bool multiple;

  /// The selection when [multiple] is on.
  final List<String> selectedValues;

  /// The new selection, in tree order.
  final ValueChanged<List<String>>? onSelectedValuesChanged;

  /// Content at the end of each row; return null for none.
  final Widget? Function(BuildContext context, UiTreeNode node)? trailingBuilder;

  /// Drag rows and Alt+Up/Down to move nodes; the tree calls [onMove].
  final bool reorderable;
  final ValueChanged<UiTreeMove>? onMove;

  /// A double tap on a label, or F2.
  final ValueChanged<UiTreeNode>? onActivate;

  /// Let F2 or a double tap replace a label with an in-place editor.
  final bool renamable;

  /// A non-empty changed label committed by the user: `(value, label)`.
  final void Function(String value, String label)? onRename;

  @override
  State<UiTree> createState() => _UiTreeState();
}

class _UiTreeState extends State<UiTree> {
  late Set<String> _ownExpanded = {...widget.initiallyExpanded};
  String? _active;
  String? _anchor;
  final Map<String, FocusNode> _nodes = {};
  final Map<String, GlobalKey> _rowKeys = {};
  String? _editing;

  // Double tap on a label: the label pressed last, while a second press would still count.
  String? _labelDownValue;
  Timer? _labelTimer;

  // Dragging.
  String? _dragValue;
  Offset? _dragFrom;
  bool _dragOn = false;
  _Drop? _drop;

  Set<String> get _expanded => widget.expanded ?? _ownExpanded;

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onDragKey);
    _labelTimer?.cancel();
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
    final open = _expanded;
    void walk(List<UiTreeNode> list) {
      for (final n in list) {
        out.add(n.value);
        if (n.hasChildren && open.contains(n.value)) walk(n.children);
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

  void _setExpanded(Set<String> next) {
    widget.onExpandedChanged?.call(next);
    if (widget.expanded == null) setState(() => _ownExpanded = next);
  }

  void _setOpen(UiTreeNode n, bool open) {
    if (!n.hasChildren || _expanded.contains(n.value) == open) return;
    _setExpanded(open ? ({..._expanded, n.value}) : ({..._expanded}..remove(n.value)));
  }

  bool _isInside(String value, String ancestor, Map<String, _Info> index) {
    var p = index[value]?.parent;
    while (p != null) {
      if (p == ancestor) return true;
      p = index[p]?.parent;
    }
    return false;
  }

  List<UiTreeNode> _siblings(String? parent, Map<String, _Info> index) => parent == null ? widget.nodes : (index[parent]?.node.children ?? const []);

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

  // ── Selection ──────────────────────────────────────────────────────────────────────────

  void _choose(UiTreeNode n) => widget.onSelect?.call(n);

  List<String> _inTreeOrder(Iterable<String> values) {
    final want = values.toSet();
    return [for (final v in _index.keys) if (want.contains(v)) v];
  }

  void _setValues(List<String> next) => widget.onSelectedValuesChanged?.call(_inTreeOrder(next));

  void _tap(String v) {
    setState(() => _active = v);
    final n = _index[v]!.node;
    if (!widget.multiple) return _choose(n);
    final kb = HardwareKeyboard.instance;
    final ctrl = kb.isControlPressed || kb.isMetaPressed;
    if (kb.isShiftPressed) {
      final vis = _visible;
      final from = vis.indexOf(_anchor ?? widget.selected ?? v);
      final to = vis.indexOf(v);
      final range = from < 0 ? [v] : vis.sublist(math.min(from, to), math.max(from, to) + 1);
      _setValues(ctrl ? [...widget.selectedValues, ...range] : range);
    } else if (ctrl) {
      _toggleSel(v, select: false);
    } else {
      _anchor = v;
      _setValues([v]);
    }
    _choose(n);
  }

  void _toggleSel(String v, {bool select = true}) {
    _anchor = v;
    final next = {...widget.selectedValues};
    if (!next.remove(v)) next.add(v);
    _setValues(next.toList());
    if (select) _choose(_index[v]!.node);
  }

  void _labelDown(String v, PointerDownEvent e) {
    if (widget.onActivate == null && !widget.renamable) return;
    if (_labelTimer?.isActive == true && _labelDownValue == v) {
      _labelTimer!.cancel();
      _activate(_index[v]!.node);
      return;
    }
    // A raw listener and a timer, not a double-tap recognizer: that would hold every single tap
    // back until the double-tap time ran out.
    _labelDownValue = v;
    _labelTimer?.cancel();
    _labelTimer = Timer(kDoubleTapTimeout, () {});
  }

  void _activate(UiTreeNode n) {
    widget.onActivate?.call(n);
    if (widget.renamable) setState(() => _editing = n.value);
  }

  void _finishRename(UiTreeNode n, String text, {required bool cancel, required bool refocus}) {
    if (_editing != n.value) return;
    final label = text.trim();
    setState(() => _editing = null);
    if (!cancel && label.isNotEmpty && label != n.label) widget.onRename?.call(n.value, label);
    if (refocus) WidgetsBinding.instance.addPostFrameCallback((_) => _focus(n.value));
  }

  // ── Reordering ─────────────────────────────────────────────────────────────────────────

  void _moveBy(String value, int dir) {
    final index = _index;
    final info = index[value];
    if (info == null) return;
    final list = _siblings(info.parent, index);
    final to = list.indexWhere((c) => c.value == value) + dir;
    if (to < 0 || to >= list.length) return;
    widget.onMove?.call(UiTreeMove(value: value, parent: info.parent, index: to));
  }

  void _dragStart(String v, Offset global, {bool immediate = false}) {
    _dragValue = v;
    _dragFrom = global;
    _dragOn = false;
    if (immediate) _dragUpdate(global, force: true);
  }

  /// Returns true once the drag has really started (past the 4px threshold).
  bool _dragUpdate(Offset global, {bool force = false}) {
    final v = _dragValue;
    if (v == null) return false;
    if (!_dragOn) {
      if (!force && (global - _dragFrom!).distance < 4) return false;
      _dragOn = true;
      HardwareKeyboard.instance.addHandler(_onDragKey);
    }
    setState(() => _drop = _dropAt(global, v));
    return true;
  }

  void _dragEnd() {
    final drop = _drop;
    final on = _dragOn;
    _dragCancel();
    if (on && drop != null) widget.onMove?.call(drop.move);
  }

  void _dragCancel() {
    HardwareKeyboard.instance.removeHandler(_onDragKey);
    if (_dragValue == null && _drop == null) return;
    setState(() {
      _dragValue = null;
      _dragOn = false;
      _drop = null;
    });
  }

  bool _onDragKey(KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape && _dragOn) {
      _dragCancel();
      return true;
    }
    return false;
  }

  _Drop? _dropAt(Offset global, String dragged) {
    final index = _index;
    for (final v in _visible) {
      final box = _rowKeys[v]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final local = box.globalToLocal(global);
      if (local.dy < 0 || local.dy >= box.size.height || local.dx < 0 || local.dx > box.size.width) continue;
      // Never into itself or its own descendants.
      if (v == dragged || _isInside(v, dragged, index)) return null;
      final n = index[v]!.node;
      final rel = local.dy / box.size.height;
      final canHold = n.hasChildren || n.container;
      var pos = canHold ? (rel < 0.25 ? _DropPos.before : (rel > 0.75 ? _DropPos.after : _DropPos.inside)) : (rel < 0.5 ? _DropPos.before : _DropPos.after);
      // Just below an open parent the line sits above its first child, so that's where it goes.
      if (pos == _DropPos.after && n.hasChildren && _expanded.contains(v)) pos = _DropPos.first;
      final move = _moveFor(dragged, v, pos, index);
      return move == null ? null : _Drop(v, pos, move);
    }
    return null;
  }

  UiTreeMove? _moveFor(String dragged, String target, _DropPos pos, Map<String, _Info> index) {
    final info = index[target]!;
    String? parent;
    int at;
    if (pos == _DropPos.inside || pos == _DropPos.first) {
      parent = target;
      at = pos == _DropPos.first ? 0 : info.node.children.where((c) => c.value != dragged).length;
    } else {
      parent = info.parent;
      final list = _siblings(parent, index).where((c) => c.value != dragged).toList();
      at = list.indexWhere((c) => c.value == target) + (pos == _DropPos.after ? 1 : 0);
    }
    final from = index[dragged]!.parent;
    if (from == parent && _siblings(from, index).indexWhere((c) => c.value == dragged) == at) return null;
    return UiTreeMove(value: dragged, parent: parent, index: at);
  }

  // ── Keys ───────────────────────────────────────────────────────────────────────────────

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final index = _index;
    // Only the rows' own focus nodes: keys on controls in the trailing slot belong to them.
    final value = _nodes.entries.where((en) => en.value.hasPrimaryFocus).map((en) => en.key).firstOrNull;
    final info = value == null ? null : index[value];
    if (info == null || value == null) return KeyEventResult.ignored;
    final n = info.node;
    final vis = _visible;
    final at = vis.indexOf(value);
    final k = e.logicalKey;
    final kb = HardwareKeyboard.instance;
    if (widget.reorderable && kb.isAltPressed && (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown)) {
      _moveBy(value, k == LogicalKeyboardKey.arrowUp ? -1 : 1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      _focus(vis[(at + 1).clamp(0, vis.length - 1)]);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _focus(vis[(at - 1).clamp(0, vis.length - 1)]);
    } else if (k == LogicalKeyboardKey.home) {
      _focus(vis.first);
    } else if (k == LogicalKeyboardKey.end) {
      _focus(vis.last);
    } else if (k == LogicalKeyboardKey.f2) {
      if (widget.onActivate == null && !widget.renamable) return KeyEventResult.ignored;
      _activate(n);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      if (n.hasChildren) _expanded.contains(n.value) ? _focus(n.children.first.value) : _setOpen(n, true);
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      if (n.hasChildren && _expanded.contains(n.value)) {
        _setOpen(n, false);
      } else if (info.parent != null) {
        _focus(info.parent);
      }
    } else if (e.character == '*') {
      final siblings = _siblings(info.parent, index);
      _setExpanded({..._expanded, for (final s in siblings) if (s.hasChildren) s.value});
    } else {
      final ch = e.character;
      final mods = kb.isControlPressed || kb.isMetaPressed || kb.isAltPressed;
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
    final selSet = widget.selectedValues.toSet();
    // Drop focus nodes and keys of rows that no longer exist.
    for (final v in _nodes.keys.where((v) => !index.containsKey(v)).toList()) {
      _nodes.remove(v)!.dispose();
    }
    _rowKeys.removeWhere((v, _) => !index.containsKey(v));
    final reorder = widget.reorderable && widget.onMove != null;
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
                boxKey: _rowKeys.putIfAbsent(v, () => GlobalKey(debugLabel: 'tree row $v')),
                info: index[v]!,
                focusNode: _node(v)..skipTraversal = v != stop,
                open: _expanded.contains(v),
                selected: widget.multiple ? selSet.contains(v) : v == widget.selected,
                editing: _editing == v,
                trailing: widget.trailingBuilder?.call(context, index[v]!.node),
                dragging: _dragOn && _dragValue == v,
                drop: _drop?.value == v ? _drop!.pos : null,
                onTap: () => _tap(v),
                onToggleSelection: widget.multiple ? () => _toggleSel(v) : null,
                onToggle: () => _toggle(index[v]!.node),
                onFocus: () => setState(() => _active = v),
                onLabelDown: (e) => _labelDown(v, e),
                onRenameCommit: (text, {required bool refocus}) => _finishRename(index[v]!.node, text, cancel: false, refocus: refocus),
                onRenameCancel: () => _finishRename(index[v]!.node, '', cancel: true, refocus: true),
                onDragStart: reorder ? (g, {bool immediate = false}) => _dragStart(v, g, immediate: immediate) : null,
                onDragUpdate: _dragUpdate,
                onDragEnd: _dragEnd,
                onDragCancel: _dragCancel
              ),
          ],
        ),
      ),
    );
  }
}

class _RenameEditor extends StatefulWidget {
  const _RenameEditor({required this.label, required this.style, required this.onCommit, required this.onCancel});
  final String label;
  final TextStyle style;
  final void Function(String text, {required bool refocus}) onCommit;
  final VoidCallback onCancel;

  @override
  State<_RenameEditor> createState() => _RenameEditorState();
}

class _RenameEditorState extends State<_RenameEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.label,
  )..selection = TextSelection(baseOffset: 0, extentOffset: widget.label.length);
  final FocusNode _focusNode = FocusNode(debugLabel: 'tree rename');
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onFocus() {
    if (!_focusNode.hasFocus && !_finished) {
      _finished = true;
      widget.onCommit(_controller.text, refocus: false);
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _finished = true;
      widget.onCancel();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _finished = true;
      widget.onCommit(_controller.text, refocus: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocus)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return SizedBox(
      height: 24,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.borderFocus),
          borderRadius: BorderRadius.circular(t.radiusXs),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: t.space1),
          child: Focus(
            onKeyEvent: _onKey,
            child: EditableText(
              controller: _controller,
              focusNode: _focusNode,
              style: widget.style,
              cursorColor: t.text,
              backgroundCursorColor: t.surface,
              selectionColor: t.selected,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              inputFormatters: [LengthLimitingTextInputFormatter(80)],
              onSubmitted: (_) {
                if (_finished) return;
                _finished = true;
                widget.onCommit(_controller.text, refocus: true);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TreeRow extends StatefulWidget {
  const _TreeRow({
    super.key,
    required this.boxKey,
    required this.info,
    required this.focusNode,
    required this.open,
    required this.selected,
    required this.editing,
    required this.trailing,
    required this.dragging,
    required this.drop,
    required this.onTap,
    required this.onToggleSelection,
    required this.onToggle,
    required this.onFocus,
    required this.onLabelDown,
    required this.onRenameCommit,
    required this.onRenameCancel,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
  });
  final GlobalKey boxKey;
  final _Info info;
  final FocusNode focusNode;
  final bool open;
  final bool selected;
  final bool editing;
  final Widget? trailing;
  final bool dragging;
  final _DropPos? drop;
  final VoidCallback onTap;
  final VoidCallback? onToggleSelection;
  final VoidCallback onToggle;
  final VoidCallback onFocus;
  final ValueChanged<PointerDownEvent> onLabelDown;
  final void Function(String text, {required bool refocus}) onRenameCommit;
  final VoidCallback onRenameCancel;
  final void Function(Offset global, {bool immediate})? onDragStart;
  final bool Function(Offset global, {bool force}) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDragCancel;

  @override
  State<_TreeRow> createState() => _TreeRowState();
}

class _TreeRowState extends State<_TreeRow> {
  bool _hover = false;
  bool _pressed = false;
  // A mouse drag that never passed the threshold is still a click.
  bool _panMoved = false;

  void _set(VoidCallback f) {
    if (mounted) setState(f);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    final w = widget;
    final n = w.info.node;
    final kids = n.hasChildren;
    // On touch the chevron's hit area widens to fill the row's height.
    final chevW = touch ? 36.0 : 24.0;
    final trailing = w.trailing;
    final indent = t.space2 + w.info.depth * 16;
    final animate = context.uiAnimate ? t.motionFast : Duration.zero;

    Widget main = UiInteractive(
      onTap: w.editing ? null : w.onTap,
      focusNode: w.focusNode,
      button: false,
      selected: w.selected,
      pressScale: false,
      padTouchTarget: false,
      onFocusChange: (f) {
        if (f) w.onFocus();
      },
      // In multiple mode Space toggles the focused node; Enter still selects only it.
      shortcuts: w.onToggleSelection != null ? const {SingleActivator(LogicalKeyboardKey.space): _ToggleIntent()} : null,
      actions: w.onToggleSelection != null
          ? {
              _ToggleIntent: CallbackAction<_ToggleIntent>(onInvoke: (_) {
                w.onToggleSelection!();
                return null;
              }),
            }
          : null,
      builder: (context, s) => Semantics(
        label: w.editing ? 'Rename ${n.label}' : n.label,
        textField: w.editing ? true : null,
        hint: 'level ${w.info.depth + 1}, ${w.info.index + 1} of ${w.info.count}',
        expanded: kids ? w.open : null,
        onExpand: kids && !w.open ? w.onToggle : null,
        onCollapse: kids && w.open ? w.onToggle : null,
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: touch ? uiMinTouchTarget : 0),
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: math.max(0, t.space2 - (chevW - 16) / 2) + w.info.depth * 16,
                end: trailing != null ? t.space1 : t.space2,
                top: touch ? 0 : t.space1,
                bottom: touch ? 0 : t.space1,
              ),
              child: Row(spacing: t.space1, children: [
                // The chevron draws in the row's 16px slot; its hit box is bigger, overlapping the padding.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: kids ? w.onToggle : null,
                  child: SizedBox(
                    width: chevW,
                    height: touch ? uiMinTouchTarget : 24,
                    child: kids
                        ? Center(
                            child: AnimatedRotation(
                              turns: w.open ? (Directionality.of(context) == TextDirection.rtl ? -0.25 : 0.25) : 0,
                              duration: animate,
                              curve: t.easeStandard,
                              child: UiIcon(HugeIcons.strokeRoundedArrowRight01, size: 14, color: t.textMuted, strokeWidth: 2, matchTextDirection: true),
                            ),
                          )
                        : null,
                  ),
                ),
                if (n.icon != null) SizedBox(width: 16, child: UiIcon(n.icon!, size: 16, color: t.textMuted)),
                Expanded(
                  child: w.editing
                      ? _RenameEditor(
                          label: n.label,
                          style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.35, color: n.muted ? t.textMuted : null),
                          onCommit: w.onRenameCommit,
                          onCancel: w.onRenameCancel,
                        )
                      : Listener(
                          onPointerDown: w.onLabelDown,
                          child: Text(n.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.35, color: n.muted ? t.textMuted : null)),
                        ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );

    final start = w.editing ? null : w.onDragStart;
    if (start != null) {
      // Mouse and pen drag at once (past 4px); touch long-presses first, so the list still scrolls.
      main = GestureDetector(
        supportedDevices: const {PointerDeviceKind.mouse, PointerDeviceKind.stylus, PointerDeviceKind.invertedStylus},
        onPanDown: (d) {
          _panMoved = false;
          start(d.globalPosition);
        },
        onPanUpdate: (d) {
          if (w.onDragUpdate(d.globalPosition)) _panMoved = true;
        },
        onPanEnd: (_) {
          final moved = _panMoved;
          w.onDragEnd();
          if (!moved) w.onTap();
        },
        onPanCancel: w.onDragCancel,
        child: GestureDetector(
          supportedDevices: const {PointerDeviceKind.touch},
          onLongPressStart: (d) => start(d.globalPosition, immediate: true),
          onLongPressMoveUpdate: (d) => w.onDragUpdate(d.globalPosition, force: true),
          onLongPressEnd: (_) => w.onDragEnd(),
          onLongPressCancel: w.onDragCancel,
          child: main,
        ),
      );
    }

    final ring = BoxDecoration(border: Border.all(color: t.borderFocus, width: 2), borderRadius: BorderRadius.circular(t.radiusXs));
    final line = w.drop == _DropPos.before || w.drop == _DropPos.after || w.drop == _DropPos.first;
    return Listener(
      onPointerDown: (_) => _set(() => _pressed = true),
      onPointerUp: (_) => _set(() => _pressed = false),
      onPointerCancel: (_) => _set(() => _pressed = false),
      child: MouseRegion(
        onEnter: (_) => _set(() => _hover = true),
        onExit: (_) => _set(() => _hover = false),
        child: ListenableBuilder(
          listenable: Listenable.merge([w.focusNode, uiFocusVisible]),
          builder: (context, _) => Opacity(
            opacity: w.dragging ? 0.5 : 1,
            child: Stack(clipBehavior: Clip.none, children: [
              AnimatedContainer(
                key: w.boxKey,
                duration: animate,
                curve: t.easeStandard,
                decoration: BoxDecoration(
                  color: w.selected ? t.selected : (_hover || _pressed ? t.surfaceHover : null),
                  borderRadius: BorderRadius.circular(t.radiusXs),
                ),
                foregroundDecoration: (w.focusNode.hasPrimaryFocus && uiShowFocusRing) || w.drop == _DropPos.inside ? ring : null,
                child: trailing == null
                    ? main
                    : Row(children: [
                        Expanded(child: main),
                        // Beside the row's own tap target, not inside it: taps here never select the
                        // row, and the controls stay separate for screen readers.
                        Padding(padding: EdgeInsetsDirectional.only(end: t.space2), child: trailing),
                      ]),
              ),
              if (line)
                PositionedDirectional(
                  start: indent + (w.drop == _DropPos.first ? 16 : 0),
                  end: 0,
                  top: w.drop == _DropPos.before ? -1 : null,
                  bottom: w.drop == _DropPos.before ? null : -1,
                  height: 2,
                  child: IgnorePointer(
                    child: DecoratedBox(decoration: BoxDecoration(color: t.borderFocus, borderRadius: BorderRadius.circular(1))),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
