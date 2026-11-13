import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../badge/badge.dart';
import '../button/button.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../theme/theme.dart';

/// One row of a [UiSectionList] (the web `UiSectionListItem`).
class UiSectionListItem {
  const UiSectionListItem({
    required this.id,
    required this.label,
    this.description,
    this.icon,
    this.hidden = false,
    this.locked = false,
    this.editable = true,
    this.removable = true,
    this.hideable = true,
  });

  final String id;
  final String label;

  /// A second, smaller line under the label.
  final String? description;

  /// A hugeicon shown before the label.
  final UiIconData? icon;

  /// Shown dimmed with a "Hidden" badge; the eye button shows it again.
  final bool hidden;

  /// Can't be moved and keeps its place (a cover that is always first).
  final bool locked;
  final bool editable;
  final bool removable;
  final bool hideable;
}

/// Moves [ids]' item at [from] to [to] (indices in the final list), keeping every locked id at its
/// index. Returns null when nothing changes. Shared by drags and arrow keys.
List<String>? uiSortableMove(List<String> ids, Set<String> locked, int from, int to) {
  if (from == to || from < 0 || from >= ids.length || locked.contains(ids[from])) return null;
  final moving = ids[from];
  final free = [for (final id in ids) if (!locked.contains(id) && id != moving) id];
  // Where the moved item lands among the free items: count the free items before [to] in the
  // list as it would be without the moved one.
  final without = [...ids]..removeAt(from);
  final clamped = to.clamp(0, without.length);
  var slot = 0;
  for (var i = 0; i < clamped; i++) {
    if (!locked.contains(without[i])) slot++;
  }
  free.insert(slot, moving);
  final out = <String>[];
  var k = 0;
  for (final id in ids) {
    out.add(locked.contains(id) ? id : free[k++]);
  }
  for (var i = 0; i < ids.length; i++) {
    if (out[i] != ids[i]) return out;
  }
  return null;
}

/// `ui-section-list`: cards the user puts in order by dragging their handle, each with an eye
/// (hide/show), a pencil (edit) and a bin (remove). Made for page sections in an editor.
///
/// The handle drags at once (touch and mouse) using the device's touch slop, so a drag on it wins
/// over the page's scroll while a swipe anywhere else scrolls. With the keyboard, focus a handle and
/// press the up or down arrow; screen readers get "Move up" / "Move down" actions. [locked] items
/// stay where they are. [onReorder] gets the whole new order of ids, only when it changed.
///
/// Sizes itself to its rows (it doesn't scroll), so it sits inside a page's own scroll view.
class UiSectionList extends StatefulWidget {
  const UiSectionList({
    super.key,
    required this.items,
    required this.onReorder,
    this.onToggleHidden,
    this.onEdit,
    this.onRemove,
    this.label = 'Sections',
    this.moveLabel = 'Drag to move',
    this.hideLabel = 'Hide',
    this.showLabel = 'Show',
    this.editLabel = 'Edit',
    this.removeLabel = 'Remove',
    this.hiddenLabel = 'Hidden',
  });

  final List<UiSectionListItem> items;
  final ValueChanged<List<String>> onReorder;

  /// The id and its new hidden value.
  final void Function(String id, bool hidden)? onToggleHidden;
  final ValueChanged<String>? onEdit;
  final ValueChanged<String>? onRemove;

  /// The list's accessible name.
  final String label;
  final String moveLabel, hideLabel, showLabel, editLabel, removeLabel, hiddenLabel;

  @override
  State<UiSectionList> createState() => _UiSectionListState();
}

class _UiSectionListState extends State<UiSectionList> {
  /// The order shown, which runs ahead of [UiSectionList.items] between a drop and the parent's
  /// rebuild, so a dropped row doesn't jump back for a frame.
  late List<String> _order = _ids;
  final _handles = <String, FocusNode>{};

  List<String> get _ids => [for (final i in widget.items) i.id];

  @override
  void didUpdateWidget(UiSectionList old) {
    super.didUpdateWidget(old);
    _order = _ids;
    final live = _order.toSet();
    _handles.removeWhere((id, node) {
      if (live.contains(id)) return false;
      node.dispose();
      return true;
    });
  }

  @override
  void dispose() {
    for (final n in _handles.values) {
      n.dispose();
    }
    super.dispose();
  }

  FocusNode _handle(String id) => _handles.putIfAbsent(id, () => FocusNode(debugLabel: 'sortable handle $id'));

  UiSectionListItem _item(String id) => widget.items.firstWhere((i) => i.id == id);

  Set<String> get _locked => {for (final i in widget.items) if (i.locked) i.id};

  void _apply(List<String>? next, {String? announce}) {
    if (next == null) return;
    setState(() => _order = next);
    widget.onReorder(next);
    if (announce != null) {
      final view = View.maybeOf(context);
      final id = announce;
      final at = next.indexOf(id) + 1;
      if (view != null) unawaited(SemanticsService.sendAnnouncement(view, '${_item(id).label} moved to position $at of ${next.length}', Directionality.of(context)));
    }
  }

  /// One step up or down, skipping locked rows.
  void _step(String id, int dir) {
    final locked = _locked;
    var to = _order.indexOf(id) + dir;
    while (to >= 0 && to < _order.length && locked.contains(_order[to])) {
      to += dir;
    }
    if (to < 0 || to >= _order.length) return;
    _apply(uiSortableMove(_order, locked, _order.indexOf(id), to), announce: id);
    // The row moved: keep the keyboard on its handle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handle(id).requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Semantics(
      container: true,
      label: widget.label,
      child: ReorderableList(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _order.length,
        onReorderItem: (from, to) => _apply(uiSortableMove(_order, _locked, from, to)),
        proxyDecorator: (child, index, animation) => AnimatedBuilder(
          animation: animation,
          builder: (context, child) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.uiTheme.config.radius ? t.radius : 0),
              boxShadow: t.shadow2,
            ),
            child: child,
          ),
          child: child,
        ),
        itemBuilder: (context, index) {
          final id = _order[index];
          final item = _item(id);
          return Padding(
            key: ValueKey(id),
            padding: EdgeInsets.only(bottom: index == _order.length - 1 ? 0 : t.space2),
            child: _Row(
              item: item,
              index: index,
              count: _order.length,
              focusNode: _handle(id),
              owner: widget,
              onStep: (dir) => _step(id, dir),
              canUp: _canStep(id, -1),
              canDown: _canStep(id, 1),
            ),
          );
        },
      ),
    );
  }

  bool _canStep(String id, int dir) {
    final locked = _locked;
    if (locked.contains(id)) return false;
    var to = _order.indexOf(id) + dir;
    while (to >= 0 && to < _order.length && locked.contains(_order[to])) {
      to += dir;
    }
    return to >= 0 && to < _order.length;
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.index,
    required this.count,
    required this.focusNode,
    required this.owner,
    required this.onStep,
    required this.canUp,
    required this.canDown,
  });

  final UiSectionListItem item;
  final int index, count;
  final FocusNode focusNode;
  final UiSectionList owner;
  final ValueChanged<int> onStep;
  final bool canUp, canDown;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final rounded = context.uiTheme.config.radius;
    final muted = item.hidden;
    final textColor = muted ? t.textMuted : t.text;
    final icon = item.icon;
    final wide = (MediaQuery.maybeSizeOf(context)?.width ?? 400) >= 360;
    return Container(
      constraints: const BoxConstraints(minHeight: uiMinTouchTarget + 8),
      padding: EdgeInsetsDirectional.only(start: t.space1, end: t.space1, top: t.space1, bottom: t.space1),
      decoration: BoxDecoration(
        color: muted ? t.surfaceSubtle : t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(rounded ? t.radius : 0),
      ),
      child: Row(children: [
        if (item.locked)
          const SizedBox(width: uiMinTouchTarget)
        else
          _Handle(
            item: item,
            index: index,
            focusNode: focusNode,
            label: '${owner.moveLabel} ${item.label}',
            onStep: onStep,
            canUp: canUp,
            canDown: canDown,
          ),
        // Narrower than 360 the name needs the room more than the icon (as on the web).
        if (icon != null && wide) ...[
          IconTheme.merge(data: IconThemeData(size: 20, color: muted ? t.textMuted : (t.icon ?? t.text)), child: UiIcon(icon)),
          SizedBox(width: t.space3),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(item.label, style: context.uiText.body.copyWith(color: textColor, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (item.description != null && item.description!.isNotEmpty)
              Text(item.description!, style: context.uiText.caption.copyWith(color: t.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
            // Under the text, so a narrow row never has to fit it beside the name.
            if (item.hidden) Padding(padding: EdgeInsets.only(top: t.space1), child: UiBadge(label: owner.hiddenLabel)),
          ]),
        ),
        if (item.hideable && owner.onToggleHidden != null)
          Semantics(
            toggled: item.hidden,
            child: UiIconButton(
              icon: UiIcon(item.hidden ? HugeIcons.strokeRoundedViewOffSlash : HugeIcons.strokeRoundedView),
              label: '${item.hidden ? owner.showLabel : owner.hideLabel} ${item.label}',
              onPressed: () => owner.onToggleHidden!(item.id, !item.hidden),
            ),
          ),
        if (item.editable && owner.onEdit != null)
          UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedPencilEdit02), label: '${owner.editLabel} ${item.label}', onPressed: () => owner.onEdit!(item.id)),
        if (item.removable && owner.onRemove != null)
          UiIconButton(
            icon: const UiIcon(HugeIcons.strokeRoundedDelete02),
            iconColor: t.danger,
            label: '${owner.removeLabel} ${item.label}',
            onPressed: () => owner.onRemove!(item.id),
          ),
      ]),
    );
  }
}

/// The grip: starts a drag at once, and moves its row with the arrow keys.
class _Handle extends StatefulWidget {
  const _Handle({required this.item, required this.index, required this.focusNode, required this.label, required this.onStep, required this.canUp, required this.canDown});
  final UiSectionListItem item;
  final int index;
  final FocusNode focusNode;
  final String label;
  final ValueChanged<int> onStep;
  final bool canUp, canDown;

  @override
  State<_Handle> createState() => _HandleState();
}

class _HandleState extends State<_Handle> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Semantics(
      label: widget.label,
      customSemanticsActions: {
        if (widget.canUp) const CustomSemanticsAction(label: 'Move up'): () => widget.onStep(-1),
        if (widget.canDown) const CustomSemanticsAction(label: 'Move down'): () => widget.onStep(1),
      },
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (f) => setState(() => _focused = f),
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            widget.onStep(-1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            widget.onStep(1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ReorderableDragStartListener(
          index: widget.index,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Container(
              width: uiMinTouchTarget,
              height: uiMinTouchTarget,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(t.radiusSm),
                boxShadow: _focused && uiFocusVisible.value ? t.focusRing : null,
              ),
              child: IconTheme.merge(data: IconThemeData(size: 22, color: t.textMuted), child: const UiIcon(HugeIcons.strokeRoundedDragDropVertical)),
            ),
          ),
        ),
      ),
    );
  }
}
