import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../behaviors/scrolling.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../forms/text/inputs.dart';
import '../overlay/anchored.dart';
import '../overlay/menu.dart';
import '../theme/theme.dart';
import 'bits.dart';
import 'definition.dart';
import 'dnd.dart';
import 'icons.dart';
import 'schema.dart';
import 'scope.dart';
import 'store.dart';

/// The trigger card at the top of an automation (the web `ui-wf-trigger-card`).
class WfTriggerCard extends StatelessWidget {
  const WfTriggerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final ctx = WfBuilderScope.of(context);
    final store = ctx.store;
    final trigger = store.def.trigger;
    final selected = store.selection?.kind == 'trigger';
    final summary = describeTrigger(trigger, store.describeContext());
    final when = trigger?.when;
    final condition = when != null && (!when.isGroup || when.conditions.isNotEmpty);
    final problems = store.problemsOf(null).where((p) => p.isError).toList();
    return _CardWidth(child: UiInteractive(
      onTap: () {
        store.selection = UiWfSelection.trigger;
        ctx.ui.inspect();
      },
      selected: selected,
      semanticLabel: 'Trigger: $summary',
      excludeChildSemantics: true,
      pressScale: false,
      builder: (context, s) => AnimatedContainer(
        duration: context.uiAnimate ? t.motionFast : Duration.zero,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(
            color: selected
                ? t.primary
                : problems.isNotEmpty
                ? Color.lerp(t.border, t.danger, 0.55)!
                : s.hovered
                ? Color.lerp(t.border, t.primary, 0.45)!
                : t.border,
          ),
          borderRadius: BorderRadius.circular(t.radius),
          boxShadow: [
            ...t.shadow1,
            if (selected) BoxShadow(color: t.primary, spreadRadius: 1),
            if (s.focused) ...t.focusRing,
          ],
        ),
        child: Row(spacing: 10, children: [
          WfIconTile(wfTriggerIcon(trigger?.type ?? 'fieldChanged'), color: t.primary, size: 30, iconSize: 16, solid: true),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('STARTS', style: context.uiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.55, color: t.textMuted)),
              Text(summary, style: context.uiText.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.3, color: t.text)),
              if (condition) Text('Only when conditions hold', style: context.uiText.body.copyWith(fontSize: 12, color: t.textSecondary)),
            ]),
          ),
          if (problems.isNotEmpty) WfChip('${problems.length}', tone: 'danger', tooltip: problems.first.message),
        ]),
      ),
    ));
  }
}

/// Takes taps on a part of the canvas that isn't its background (a branch column, a connector, a
/// "+" row), so they don't fall through and select the workflow's settings. Taps on controls inside
/// still reach them (the innermost wins).
class _NotBackground extends StatelessWidget {
  const _NotBackground({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(behavior: HitTestBehavior.opaque, excludeFromSemantics: true, onTap: () {}, child: child);
}

/// One step: grip, icon, name, one-line summary, problems, and a menu (the web `ui-wf-step-card`).
/// The border warms under the mouse; the grip shows on hover or when selected (always on touch).
/// Read-only keeps the grip's and menu's room, so cards don't shift.
class WfStepCard extends StatefulWidget {
  const WfStepCard({super.key, required this.step});
  final UiWfStep step;

  @override
  State<WfStepCard> createState() => _WfStepCardState();
}

class _WfStepCardState extends State<WfStepCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final t = context.ui;
    final ctx = WfBuilderScope.of(context);
    final store = ctx.store;
    final dnd = ctx.dnd;
    final info = stepInfo(step.type);
    final icon = wfStepIcon(step.type);
    final name = stepName(step);
    final summary = describeStep(step, store.describeContext(store.tokens(UiWfAt.step(step.id))));
    final selected = store.selection == UiWfSelection.step(step.id);
    final problems = store.problemsOf(step.id);
    final errors = problems.where((p) => p.isError).toList();
    final warnings = problems.where((p) => !p.isError).toList();
    final loc = store.steps[step.id];
    final siblings = loc == null ? 0 : (listSteps(store.def, loc.listId)?.length ?? 0);
    final catColor = wfCategoryColor(t, info.category);
    final touch = uiTouchPlatform(context);

    WfDragPayload payload() => WfDragPayload.move(id: step.id, label: name, icon: icon);

    void select() {
      if (dnd?.consumeClick() ?? false) return;
      store.selection = UiWfSelection.step(step.id);
      ctx.ui.inspect();
    }

    void onMenu(UiMenuItem item) {
      final l = store.steps[step.id];
      switch (item.value) {
        case 'up':
          if (l != null) store.moveStep(step.id, l.listId, l.index - 1);
        case 'down':
          if (l != null) store.moveStep(step.id, l.listId, l.index + 2);
        case 'duplicate':
          store.duplicateStep(step.id);
        case 'toggle':
          store.updateStep(step.id, {'disabled': step.disabled ? null : true});
        case 'delete':
          ctx.ui.requestDelete(step.id);
      }
    }

    final ro = store.readOnly;
    final gripShown = touch || _hovered || selected;
    Widget grip = Semantics(
      label: 'Move $name (or use the menu)',
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: SizedBox(
            key: const ValueKey('wf-grip'),
            width: touch ? 30 : 20,
            child: AnimatedOpacity(
              opacity: gripShown ? 1 : 0,
              duration: context.uiAnimate ? t.motionFast : Duration.zero,
              child: Center(child: UiIcon(WfIcons.dragDropVertical, size: 14, color: t.textMuted)),
            ),
          ),
        ),
      ),
    );
    if (dnd != null && !ro) grip = WfDragSource(dnd: dnd, immediate: true, payload: payload, child: grip);
    // Someone only looking can inspect a step but not move or change it: the grip and the menu keep
    // their room (nothing shifts) but are hidden and can't be used.
    if (ro) grip = Visibility(visible: false, maintainSize: true, maintainAnimation: true, maintainState: true, child: grip);

    Widget body = UiInteractive(
      onTap: select,
      selected: selected,
      semanticLabel: '$name: $summary',
      excludeChildSemantics: true,
      pressScale: false,
      padTouchTarget: false,
      builder: (context, s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(t.radiusXs), boxShadow: s.focused ? t.focusRing : null),
        child: Row(spacing: 10, children: [
          WfIconTile(icon, color: catColor),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(spacing: 6, children: [
                Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3, color: t.text))),
                if (step.disabled) const WfChip('Off', height: 16),
              ]),
              Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.body.copyWith(fontSize: 12, height: 1.35, color: t.textSecondary)),
            ]),
          ),
        ]),
      ),
    );
    if (dnd != null && !ro) body = WfDragSource(dnd: dnd, payload: payload, child: body);

    // Long titles never widen the canvas: cards take their column's width and truncate. On a canvas
    // widened by a branch further down, top-level cards stay readable and centred, menus in reach.
    return _CardWidth(child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Opacity(
      opacity: step.disabled ? 0.6 : 1,
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.fromLTRB(0, 4, 4, 4),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(
            color: selected
                ? t.primary
                : errors.isNotEmpty
                ? Color.lerp(t.border, t.danger, 0.55)!
                : _hovered
                ? Color.lerp(t.border, t.primary, 0.4)!
                : t.border,
          ),
          borderRadius: BorderRadius.circular(t.radius),
          boxShadow: [...t.shadow1, if (selected) BoxShadow(color: t.primary, spreadRadius: 1)],
        ),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2, children: [
            grip,
            Expanded(child: body),
            if (errors.isNotEmpty)
              Center(child: WfChip('${errors.length}', tone: 'danger', tooltip: errors.first.message))
            else if (warnings.isNotEmpty)
              Center(child: WfChip('!', tone: 'warning', tooltip: warnings.first.message)),
            Visibility(
              visible: !ro,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Center(
              child: UiMenu(
                placement: UiPlacement.bottomEnd,
                items: [
                  UiMenuItem(label: 'Move up', value: 'up', disabled: loc == null || loc.index == 0),
                  UiMenuItem(label: 'Move down', value: 'down', disabled: loc == null || loc.index >= siblings - 1),
                  const UiMenuItem(label: 'Duplicate', value: 'duplicate'),
                  UiMenuItem(label: step.disabled ? 'Turn on' : 'Turn off (skip it)', value: 'toggle'),
                  const UiMenuItem(label: 'Delete', value: 'delete', danger: true),
                ],
                onSelect: onMenu,
                builder: (context, toggle, open) => FbIconButton(icon: WfIcons.moreHorizontal, label: 'More for $name', onPressed: toggle),
              ),
            ),
            ),
          ]),
        ),
      ),
    )));
  }
}

/// At most 560 wide and never wider than the visible canvas, centred (the web card's
/// `max-width: min(560px, 100cqi); margin-inline: auto`): on a canvas widened by branches, the card
/// the view opens centred on shows whole.
class _CardWidth extends StatelessWidget {
  const _CardWidth({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final room = context.dependOnInheritedWidgetOfExactType<_CanvasRoom>()?.width ?? double.infinity;
    return Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: math.min(560, room)), child: child));
  }
}

/// The visible width of the automation canvas, for [_CardWidth].
class _CanvasRoom extends InheritedWidget {
  const _CanvasRoom({required this.width, required super.child});
  final double width;

  @override
  bool updateShouldNotify(_CanvasRoom old) => old.width != width;
}

/// A "+" between steps: tap to pick a step for this place (the web `ui-wf-add-slot`).
class WfAddSlot extends StatelessWidget {
  const WfAddSlot({super.key, required this.listId, required this.index, this.first = false, this.label = 'Add a step here'});
  final String listId;
  final int index;

  /// The first slot of a top-level list: the connector starts in the middle.
  final bool first;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final ctx = WfBuilderScope.of(context);
    final ui = ctx.ui;
    final touch = uiTouchPlatform(context);
    final h = touch ? 34.0 : 26.0;
    final d = touch ? 28.0 : 20.0;
    return _NotBackground(child: SizedBox(
      height: h,
      child: Stack(alignment: Alignment.center, children: [
        Positioned(top: first ? h / 2 : 0, bottom: 0, child: Container(width: 2, color: t.border)),
        // Someone only looking can't add steps: the connector stays, the + goes.
        if (!ctx.store.readOnly)
          UiInteractive(
          onTap: () => ui.requestAdd(WfDropTarget(listId, index)),
          semanticLabel: label,
          excludeChildSemantics: true,
          builder: (context, s) {
            final on = s.hovered || s.focused || s.pressed;
            return AnimatedScale(
              scale: on ? 1.12 : 1,
              duration: context.uiAnimate ? t.motionFast : Duration.zero,
              child: Container(
                width: d,
                height: d,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? t.primary : t.bg,
                  border: Border.all(color: on ? t.primary : t.border),
                  boxShadow: s.focused ? t.focusRing : null,
                ),
                child: UiIcon(WfIcons.add01, size: 12, strokeWidth: 2.2, color: on ? t.primaryContrast : t.textMuted),
              ),
            );
          },
        ),
      ]),
    ));
  }
}

/// A list of steps with "+" slots between them; containers draw their own lists below them, as
/// columns side by side (stacked and collapsible on phones). The web `ui-wf-steps`.
class WfStepList extends StatelessWidget {
  const WfStepList({super.key, required this.listId, required this.steps, this.lead = false});
  final String listId;
  final List<UiWfStep> steps;

  /// Inside a container (no empty-state message, connector starts at the top).
  final bool lead;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final ctx = WfBuilderScope.of(context);
    final dnd = ctx.dnd;
    final stacked = ctx.ui.layout == UiWorkflowBuilderLayout.narrow;
    final canDrag = ctx.ui.layout == UiWorkflowBuilderLayout.wide;

    final column = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      WfAddSlot(listId: listId, index: 0, first: !lead),
      for (var i = 0; i < steps.length; i++) ...[
        KeyedSubtree(
          key: dnd?.itemKey(steps[i].id),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            WfStepCard(step: steps[i]),
            if (stepSlots(steps[i]) case final slots when slots.isNotEmpty) _Fork(step: steps[i], slots: slots, stacked: stacked),
          ]),
        ),
        WfAddSlot(listId: listId, index: i + 1),
      ],
      if (steps.isEmpty && !lead)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'No steps yet. Press + to add one${canDrag ? ', or drag one in from the left' : ''}.',
            textAlign: TextAlign.center,
            style: context.uiText.body.copyWith(fontSize: 12.5, color: t.textMuted),
          ),
        ),
    ]);

    final Widget list = dnd == null
        ? column
        : ListenableBuilder(
            listenable: dnd,
            builder: (context, child) {
              final over = dnd.drop?.target?.listId == listId && dnd.drop!.valid;
              return Container(
                decoration: BoxDecoration(color: over ? t.primary.withValues(alpha: 0.05) : null, borderRadius: BorderRadius.circular(t.radius)),
                child: child,
              );
            },
            child: column,
          );
    return KeyedSubtree(key: dnd?.listKey(listId), child: list);
  }
}

/// The columns of a container step (paths, outcomes, the loop body…).
class _Fork extends StatelessWidget {
  const _Fork({required this.step, required this.slots, required this.stacked});
  final UiWfStep step;
  final List<UiWfSlot> slots;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final ui = WfBuilderScope.of(context).ui;
    Widget lane(UiWfSlot s) {
      final listId = '${step.id}/${s.slot}';
      final collapsed = stacked && ui.isCollapsed(listId);
      final toneColor = s.tone == null ? null : wfToneColor(t, s.tone);
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
        decoration: BoxDecoration(
          color: t.surface.withValues(alpha: 0.55),
          border: Border.all(color: s.kind == 'error' ? Color.lerp(t.border, t.danger, 0.4)! : t.border),
          borderRadius: BorderRadius.circular(t.radius),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: stacked ? Alignment.centerLeft : Alignment.center,
            child: UiInteractive(
              onTap: stacked ? () => ui.toggleCollapsed(listId) : null,
              enabled: stacked,
              toggled: stacked ? !collapsed : null,
              semanticLabel: '${s.label}${s.steps.isNotEmpty ? ', ${s.steps.length} step${s.steps.length == 1 ? '' : 's'}' : ''}',
              excludeChildSemantics: true,
              pressScale: false,
              padTouchTarget: stacked,
              cursor: stacked ? SystemMouseCursors.click : MouseCursor.defer,
              builder: (context, st) => Container(
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: toneColor?.withValues(alpha: 0.13) ?? t.surfaceHover,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: st.focused ? t.focusRing : null,
                ),
                child: Row(mainAxisSize: stacked ? MainAxisSize.max : MainAxisSize.min, spacing: 6, children: [
                  Flexible(
                    fit: stacked ? FlexFit.tight : FlexFit.loose,
                    child: Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: toneColor ?? t.textSecondary)),
                  ),
                  if (s.steps.isNotEmpty) Text('${s.steps.length}', style: context.uiText.label.copyWith(fontSize: 11.5, fontWeight: FontWeight.w500, color: t.textMuted)),
                  if (stacked) UiIcon(collapsed ? WfIcons.arrowDown01 : WfIcons.arrowUp01, size: 12, strokeWidth: 2, color: toneColor ?? t.textSecondary),
                ]),
              ),
            ),
          ),
          if (!collapsed) WfStepList(listId: listId, steps: s.steps, lead: true),
        ]),
      );
    }

    Widget connector(Widget child) => Stack(children: [
      Positioned(top: 0, left: 0, right: 0, height: 10, child: Center(child: Container(width: 2, color: t.border))),
      Padding(padding: const EdgeInsets.only(bottom: 4), child: child),
    ]);

    // The columns and their connector aren't the canvas background: a tap there selects nothing.
    if (stacked) return _NotBackground(child: connector(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final s in slots) lane(s)])));
    // Columns never shrink below a readable width: the canvas as a whole widens and scrolls
    // sideways instead (see wfListWidth). Wider branches get a bigger share.
    return _NotBackground(child: connector(Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: wfForkGap, children: [
      for (final s in slots) Expanded(flex: _laneWidth(s.steps).round(), child: lane(s)),
    ])));
  }
}

/// The narrowest a branch column gets.
const double wfLaneMinWidth = 230;

/// The space between branch columns.
const double wfForkGap = 12;

/// A column's inner padding and border, on both sides.
const double _lanePad = 14;

double _laneWidth(List<UiWfStep> steps) => math.max(wfLaneMinWidth, wfListWidth(steps) + _lanePad);

/// The width a list of steps needs so every branch column keeps [wfLaneMinWidth]: the widest of
/// its steps, where a container needs its columns side by side.
double wfListWidth(List<UiWfStep> steps) {
  var w = 0.0;
  for (final step in steps) {
    final slots = stepSlots(step);
    if (slots.isEmpty) continue;
    final need = slots.fold(0.0, (sum, s) => sum + _laneWidth(s.steps)) + (slots.length - 1) * wfForkGap;
    w = math.max(w, need);
  }
  return w;
}

/// The step catalogue: search, categories, tap to add or drag onto the canvas (the web
/// `ui-wf-step-picker`).
class WfStepPicker extends StatefulWidget {
  const WfStepPicker({super.key, required this.onChosen, this.compact = false, this.dnd, this.scrollController});
  final ValueChanged<String> onChosen;

  /// Descriptions in a roomier grid (dialogs and sheets).
  final bool compact;

  /// Lets types be dragged onto the canvas (only beside it, not in a dialog).
  final WfDnd? dnd;
  final ScrollController? scrollController;

  @override
  State<WfStepPicker> createState() => _WfStepPickerState();
}

class _WfStepPickerState extends State<WfStepPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final q = _query.trim().toLowerCase();
    final groups = [
      for (final name in uiWfStepCategories)
        if ([for (final s in uiWfStepTypes) if (s.category == name && (q.isEmpty || '${s.label} ${s.description}'.toLowerCase().contains(q))) s] case final types when types.isNotEmpty)
          (name: name, types: types),
    ];

    Widget tile(UiWfStepInfo info) {
      final color = wfCategoryColor(t, info.category);
      Widget w = UiInteractive(
        onTap: () {
          if (widget.dnd?.consumeClick() ?? false) return;
          widget.onChosen(info.type);
        },
        semanticLabel: info.label,
        semanticHint: info.description,
        excludeChildSemantics: true,
        pressScale: false,
        builder: (context, s) => Container(
          constraints: BoxConstraints(minHeight: widget.compact ? 48 : 36),
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 8 : 6, vertical: widget.compact ? 8 : 5),
          decoration: BoxDecoration(
            color: s.hovered || s.pressed || s.focused ? t.surfaceHover : null,
            border: widget.compact ? Border.all(color: t.borderSubtle) : null,
            borderRadius: BorderRadius.circular(t.radius),
            boxShadow: s.focused ? t.focusRing : null,
          ),
          child: Row(spacing: 8, children: [
            WfIconTile(wfStepIcon(info.type), color: color, size: 26),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(info.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: t.text, height: 1.3)),
                if (widget.compact) Text(info.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.uiText.body.copyWith(fontSize: 12, height: 1.3, color: t.textSecondary)),
              ]),
            ),
          ]),
        ),
      );
      final dnd = widget.dnd;
      if (dnd != null) w = WfDragSource(dnd: dnd, payload: () => WfDragPayload.add(type: info.type, label: info.label, icon: wfStepIcon(info.type)), child: w);
      return w;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      UiSearchInput(size: UiSize.sm, value: _query, placeholder: 'Search steps', label: 'Search steps', onChanged: (v) => setState(() => _query = v)),
      SizedBox(height: t.space2),
      Expanded(
        child: ListView(
          controller: widget.scrollController,
          padding: EdgeInsets.only(bottom: t.space2),
          children: [
            if (groups.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: t.space4),
                child: Text('No step matches “$_query”.', textAlign: TextAlign.center, style: context.uiText.body.copyWith(fontSize: 13, color: t.textMuted)),
              ),
            for (final g in groups) ...[
              Padding(padding: EdgeInsets.only(top: t.space2, bottom: 4), child: WfSectionTitle(g.name)),
              LayoutBuilder(builder: (context, box) {
                final cols = widget.compact ? (box.maxWidth / 220).floor().clamp(1, 4) : 1;
                final gap = widget.compact ? 4.0 : 2.0;
                final w = (box.maxWidth - (cols - 1) * gap) / cols;
                return Wrap(spacing: gap, runSpacing: gap, children: [for (final i in g.types) SizedBox(width: w, child: tile(i))]);
              }),
            ],
            if (q.isNotEmpty) Semantics(liveRegion: true, label: '${groups.fold(0, (n, g) => n + g.types.length)} matches', child: const SizedBox.shrink()),
          ],
        ),
      ),
    ]);
  }
}

/// Dots on the canvas background (the web `radial-gradient` grid).
class WfDotGrid extends CustomPainter {
  WfDotGrid(this.color, {this.spacing = 18, this.origin = Offset.zero});
  final Color color;
  final double spacing;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    if (spacing < 4) return;
    final paint = Paint()..color = color;
    final ox = origin.dx % spacing, oy = origin.dy % spacing;
    for (var y = oy; y < size.height; y += spacing) {
      for (var x = ox; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(WfDotGrid old) => old.color != color || old.spacing != spacing || old.origin != origin;
}

/// The automation canvas: the trigger card, then the steps (the web `ui-wf-automation-canvas`).
class WfAutomationCanvas extends StatefulWidget {
  const WfAutomationCanvas({super.key, this.bottomPadding = 0});

  /// Extra room at the bottom (for a floating button on phones).
  final double bottomPadding;

  @override
  State<WfAutomationCanvas> createState() => _WfAutomationCanvasState();
}

class _WfAutomationCanvasState extends State<WfAutomationCanvas> {
  final ScrollController _scroll = ScrollController();
  final ScrollController _hscroll = ScrollController();

  /// The workflow the wide canvas was last centred for.
  String? _centredFor;
  final GlobalKey _viewport = GlobalKey(debugLabel: 'wf automation viewport');
  WfDnd? _dnd;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dnd = WfBuilderScope.of(context).dnd;
    if (dnd != _dnd) {
      _dnd?.removeScroller(_viewport);
      _dnd = dnd?..addScroller(_viewport, _scroll);
    }
  }

  @override
  void dispose() {
    _dnd?.removeScroller(_viewport);
    _scroll.dispose();
    _hscroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = WfBuilderScope.of(context).store;
    return GestureDetector(
      key: _viewport,
      behavior: HitTestBehavior.opaque,
      // Tapping empty canvas shows the workflow's own settings.
      onTap: () => store.selection = UiWfSelection.workflow,
      child: CustomPaint(
        painter: WfDotGrid(t.text.withValues(alpha: 0.09)),
        child: SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(t.space3, t.space4, t.space3, t.space12 + widget.bottomPadding),
          child: LayoutBuilder(builder: (context, box) {
            // 760 for a plain list; wider when branches need room, then the canvas scrolls sideways.
            final stacked = WfBuilderScope.of(context).ui.layout == UiWorkflowBuilderLayout.narrow;
            final needed = stacked ? 0.0 : wfListWidth(store.def.steps ?? const []);
            final room = box.maxWidth;
            final width = needed > room ? needed : math.min(760.0, room);
            final flow = SizedBox(
              width: width,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const WfTriggerCard(),
                WfStepList(listId: 'root', steps: store.def.steps ?? const [], lead: true),
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(color: t.surfaceHover, borderRadius: BorderRadius.circular(10)),
                    child: ExcludeSemantics(child: Text('End', style: context.uiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: t.textMuted))),
                  ),
                ),
              ]),
            );
            if (needed > room && _centredFor != store.def.id) {
              // A canvas wider than the view (branches) opens on its middle, where the trigger and
              // the main line are.
              _centredFor = store.def.id;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _hscroll.hasClients) _hscroll.jumpTo(_hscroll.position.maxScrollExtent / 2);
              });
            }
            return _CanvasRoom(
              width: room,
              // Columns running on past an edge fade out there, so they read as "scrolls on", not "cut off".
              child: needed > room ? UiScrollFade(child: SingleChildScrollView(controller: _hscroll, scrollDirection: Axis.horizontal, child: flow)) : Center(child: flow),
            );
          }),
        ),
      ),
    );
  }
}
