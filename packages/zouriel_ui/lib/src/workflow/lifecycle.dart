import 'dart:math' as math;
import 'dart:ui' show PathMetric, PointerDeviceKind;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../button/button.dart';
import '../button/segmented.dart';
import '../canvas/viewport.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../form_builder/engine/js.dart' show jsRound;
import '../theme/theme.dart';
import 'bits.dart';
import 'canvas.dart';
import 'definition.dart';
import 'dnd.dart';
import 'icons.dart';
import 'layout.dart';
import 'schema.dart';
import 'scope.dart';
import 'store.dart';

class _DrawnEdge {
  const _DrawnEdge(this.id, this.transition, this.path, this.label, this.auto, this.selected);
  final String id;
  final UiWfTransition transition;
  final UiWfEdgePath path;
  final Offset label;
  final bool auto;
  final bool selected;
}

/// The lifecycle diagram (the web `ui-wf-lifecycle-canvas`): states as cards, transitions as
/// arrows. Drag a card to move it, drag from its handle onto another card to add a transition (on
/// touch: tap the handle, then the target), and use "Tidy up" to lay everything out again. A List
/// view shows the same as text.
class WfLifecycleCanvas extends StatefulWidget {
  const WfLifecycleCanvas({super.key});

  @override
  State<WfLifecycleCanvas> createState() => _WfLifecycleCanvasState();
}

class _WfLifecycleCanvasState extends State<WfLifecycleCanvas> {
  final UiCanvasViewportController _viewport = UiCanvasViewportController();
  String _view = 'diagram';
  String? _connectFrom;

  /// The rubber band from a handle being dragged (world coordinates).
  (Offset, Offset)? _rubber;

  /// The card being dragged and where it is now (committed on release).
  ({String id, Offset at})? _dragPos;
  Offset _dragOrigin = Offset.zero;
  Offset _dragDelta = Offset.zero;
  String? _hovered;

  @override
  void dispose() {
    _viewport.dispose();
    super.dispose();
  }

  UiWfLayout _layoutOf(UiWfLifecycle? lc) =>
      lc != null ? autoLayout(lc) : const UiWfLayout(positions: {}, edges: [], width: wfNodeW, height: wfNodeH);

  Offset _pos(UiWfLayout layout, String id) {
    final d = _dragPos;
    if (d != null && d.id == id) return d.at;
    return layout.positions[id] ?? Offset.zero;
  }

  void _select(UiWorkflowBuilderController store, WfBuilderUi ui, UiWfSelection s) {
    store.selection = s;
    ui.inspect();
  }

  void _clickState(UiWorkflowBuilderController store, WfBuilderUi ui, UiWfState s) {
    final from = _connectFrom;
    if (from != null && from != s.id) {
      setState(() => _connectFrom = null);
      store.addTransition(from, s.id);
      ui.inspect();
      return;
    }
    _select(store, ui, UiWfSelection.state(s.id));
  }

  void _addState(UiWorkflowBuilderController store, WfBuilderUi ui, UiWfLayout l) {
    final at = [jsRound(l.width + 40).toInt(), jsRound(math.max(0, l.height / 2 - wfNodeH / 2)).toInt()];
    store.addState('New state', at);
    ui.inspect();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewport.reveal(Rect.fromLTWH(at[0].toDouble(), at[1].toDouble(), wfNodeW, wfNodeH));
    });
  }

  void _tidy(UiWorkflowBuilderController store) {
    store.tidyLayout();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewport.fit();
    });
  }

  void _addFromList(UiWorkflowBuilderController store, WfBuilderUi ui, List<UiWfState> states, UiWfState s) {
    final target = states.where((x) => x.id != s.id && x.category != 'initial').firstOrNull ?? states.where((x) => x.id != s.id).firstOrNull;
    if (target != null) store.addTransition(s.id, target.id);
    ui.inspect();
  }

  /// The state whose card holds a world point.
  String? _stateAt(UiWfLayout layout, List<UiWfState> states, Offset world) {
    for (final s in states.reversed) {
      if ((_pos(layout, s.id) & const Size(wfNodeW, wfNodeH)).contains(world)) return s.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final ctx = WfBuilderScope.of(context);
    final store = ctx.store;
    final ui = ctx.ui;
    final lc = store.def.lifecycle;
    final states = lc?.states ?? const <UiWfState>[];
    final transitions = lc?.transitions ?? const <UiWfTransition>[];
    final layout = _layoutOf(lc);
    final hasManual = (lc?.layout ?? const {}).isNotEmpty;
    final anyState = transitions.where((t) => t.fromAny).toList();
    final sel = store.selection;

    String stateLabel(String id) => states.where((s) => s.id == id).firstOrNull?.label ?? '?';
    List<UiWfTransition> outgoing(String id) => transitions.where((t) => transitionAllows(store.def, t, id)).toList();

    final bar = Container(
      padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: 6),
      decoration: BoxDecoration(color: t.surface, border: Border(bottom: BorderSide(color: t.borderSubtle))),
      child: Wrap(spacing: t.space2, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        UiSegmented<String>(
          label: 'View',
          size: UiSize.sm,
          value: _view,
          options: const [UiSegmentedOption(value: 'diagram', label: 'Diagram'), UiSegmentedOption(value: 'list', label: 'List')],
          onChanged: (v) => setState(() => _view = v),
        ),
        if (_connectFrom != null)
          Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: [
            Text('Now tap the state it goes to', style: context.uiText.body.copyWith(fontSize: 12.5, color: t.primary)),
            FbLink(label: 'Cancel', onTap: () => setState(() => _connectFrom = null)),
          ]),
        UiButton(label: 'Tidy up', size: UiSize.sm, variant: UiButtonVariant.ghost, icon: const UiIcon(WfIcons.gridView), onPressed: hasManual ? () => _tidy(store) : null),
        UiButton(label: 'State', size: UiSize.sm, variant: UiButtonVariant.outline, icon: const UiIcon(WfIcons.add01), onPressed: () => _addState(store, ui, layout)),
      ]),
    );

    if (_view == 'list') {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        bar,
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(t.space2),
            children: [
              for (final s in states)
                Padding(
                  padding: EdgeInsets.only(bottom: t.space2),
                  child: _ListState(
                    state: s,
                    selected: sel == UiWfSelection.state(s.id),
                    outgoing: outgoing(s.id),
                    stateLabel: stateLabel,
                    isSelected: (id) => sel == UiWfSelection.transition(id),
                    onSelect: () => _clickState(store, ui, s),
                    onSelectTransition: (id) => _select(store, ui, UiWfSelection.transition(id)),
                    onAdd: () => _addFromList(store, ui, states, s),
                  ),
                ),
            ],
          ),
        ),
      ]);
    }

    final lanes = <String, int>{};
    final edges = <_DrawnEdge>[];
    for (final e in layout.edges) {
      final pair = ([e.from, e.to]..sort()).join('|');
      final lane = lanes[pair] ?? 0;
      lanes[pair] = lane + 1;
      final tr = transitions.firstWhere((x) => e.id.startsWith('${x.id}:'));
      final p = edgePath(_pos(layout, e.from), _pos(layout, e.to), e.back, lane);
      edges.add(_DrawnEdge(e.id, tr, p, p.label, tr.auto != null, sel == UiWfSelection.transition(tr.id)));
    }
    final cw = layout.width + 120, ch = layout.height + 160;
    final touch = uiTouchPlatform(context);

    final diagram = UiCanvasViewport(
      controller: _viewport,
      contentWidth: cw,
      contentHeight: ch,
      minimap: true,
      minimapItems: [for (final s in states) UiMinimapItem(_pos(layout, s.id) & const Size(wfNodeW, wfNodeH), active: sel == UiWfSelection.state(s.id))],
      label: 'Lifecycle diagram',
      onBackgroundTap: () {
        setState(() => _connectFrom = null);
        store.selection = UiWfSelection.workflow;
      },
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _EdgePainter(
                edges: edges,
                rubber: _rubber,
                line: t.text.withValues(alpha: 0.32),
                head: t.text.withValues(alpha: 0.40),
                on: t.primary,
              ),
            ),
          ),
        ),
        for (final e in edges)
          Positioned(
            left: e.label.dx,
            top: e.label.dy,
            child: FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              child: _EdgeLabel(edge: e, onTap: () => _select(store, ui, UiWfSelection.transition(e.transition.id))),
            ),
          ),
        for (final s in states)
          Positioned(
            left: _pos(layout, s.id).dx,
            top: _pos(layout, s.id).dy,
            child: _StateCard(
              key: ValueKey('state-${s.id}'),
              state: s,
              touch: touch,
              selected: sel == UiWfSelection.state(s.id),
              hovered: _hovered == s.id,
              dragging: _dragPos?.id == s.id,
              bad: store.problemsOf(s.id).any((p) => p.isError),
              target: _connectFrom != null && _connectFrom != s.id,
              outCount: outgoing(s.id).length,
              onHover: (on) => setState(() => _hovered = on ? s.id : (_hovered == s.id ? null : _hovered)),
              onTap: () => _clickState(store, ui, s),
              onKeyMove: (d) {
                final p = _pos(layout, s.id);
                store.placeState(s.id, math.max(0, p.dx + d.dx), math.max(0, p.dy + d.dy));
              },
              onDragStart: () {
                _dragOrigin = _pos(layout, s.id);
                _dragDelta = Offset.zero;
              },
              onDragUpdate: (screenDelta) {
                _dragDelta += screenDelta / _viewport.view.zoom;
                if (_dragPos == null && _dragDelta.distance < 4) return;
                // Snap to an 8px grid so cards line up.
                final at = Offset(((_dragOrigin.dx + _dragDelta.dx) / 8).roundToDouble() * 8, ((_dragOrigin.dy + _dragDelta.dy) / 8).roundToDouble() * 8);
                setState(() => _dragPos = (id: s.id, at: at));
              },
              onDragEnd: (commit) {
                final d = _dragPos;
                setState(() => _dragPos = null);
                if (commit && d != null) store.placeState(s.id, d.at.dx, d.at.dy);
              },
              onHandleTap: () => setState(() => _connectFrom = _connectFrom == s.id ? null : s.id),
              onHandleDrag: (global) {
                final p = _pos(layout, s.id);
                setState(() => _rubber = (Offset(p.dx + wfNodeW, p.dy + wfNodeH / 2), _viewport.toWorld(global)));
              },
              onHandleDrop: (global, commit) {
                setState(() => _rubber = null);
                if (!commit) return;
                final to = _stateAt(layout, states, _viewport.toWorld(global));
                if (to != null && to != s.id) {
                  store.addTransition(s.id, to);
                  ui.inspect();
                }
              },
            ),
          ),
      ]),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      bar,
      Expanded(child: diagram),
      if (anyState.isNotEmpty)
        Container(
          padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: 6),
          decoration: BoxDecoration(color: t.surface, border: Border(top: BorderSide(color: t.borderSubtle))),
          child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('From any state', style: context.uiText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: t.textSecondary)),
            for (final tr in anyState)
              _AnyChip(
                label: tr.label,
                to: stateLabel(tr.to),
                selected: sel == UiWfSelection.transition(tr.id),
                onTap: () => _select(store, ui, UiWfSelection.transition(tr.id)),
              ),
          ]),
        ),
    ]);
  }
}

class _AnyChip extends StatelessWidget {
  const _AnyChip({required this.label, required this.to, required this.selected, required this.onTap});
  final String label;
  final String to;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      selected: selected,
      semanticLabel: '$label $wfArrow $to',
      excludeChildSemantics: true,
      pressScale: false,
      builder: (context, s) => Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? t.primary : (s.hovered ? t.border : t.surfaceHover),
          borderRadius: BorderRadius.circular(t.radiusXs),
          boxShadow: s.focused ? t.focusRing : null,
        ),
        child: Builder(builder: (context) {
          final fg = selected ? t.primaryContrast : t.textSecondary;
          final style = context.uiText.label.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg);
          // The arrow is drawn: not every font has the arrow character.
          return Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [Text(label, style: style), UiIcon(WfIcons.arrowRight02, size: 11, strokeWidth: 2, color: fg), Text(to, style: style)]);
        }),
      ),
    );
  }
}

class _EdgeLabel extends StatelessWidget {
  const _EdgeLabel({required this.edge, required this.onTap});
  final _DrawnEdge edge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final on = edge.selected;
    return UiInteractive(
      onTap: onTap,
      selected: on,
      semanticLabel: 'Transition ${edge.transition.label}',
      excludeChildSemantics: true,
      pressScale: false,
      padTouchTarget: false,
      builder: (context, s) {
        final fg = on ? t.primaryContrast : (s.hovered ? t.text : t.textSecondary);
        return Container(
          height: 20,
          constraints: const BoxConstraints(maxWidth: 150),
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: on ? t.primary : t.surface,
            border: Border.all(color: on || s.hovered ? t.primary : t.border),
            borderRadius: BorderRadius.circular(10),
            boxShadow: s.focused ? t.focusRing : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 3, children: [
            if (edge.auto) UiIcon(WfIcons.clock02, size: 11, strokeWidth: 2, color: fg),
            Flexible(child: Text(edge.transition.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(fontSize: 11, fontWeight: FontWeight.w500, color: fg, height: 1))),
          ]),
        );
      },
    );
  }
}

const _mouseKinds = {PointerDeviceKind.mouse, PointerDeviceKind.trackpad};

class _StateCard extends StatelessWidget {
  const _StateCard({
    super.key,
    required this.state,
    required this.touch,
    required this.selected,
    required this.hovered,
    required this.dragging,
    required this.bad,
    required this.target,
    required this.outCount,
    required this.onHover,
    required this.onTap,
    required this.onKeyMove,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onHandleTap,
    required this.onHandleDrag,
    required this.onHandleDrop,
  });

  final UiWfState state;
  final bool touch;
  final bool selected;
  final bool hovered;
  final bool dragging;
  final bool bad;
  final bool target;
  final int outCount;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;
  final ValueChanged<Offset> onKeyMove;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final ValueChanged<bool> onDragEnd;
  final VoidCallback onHandleTap;
  final ValueChanged<Offset> onHandleDrag;
  final void Function(Offset global, bool commit) onHandleDrop;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final s = state;
    final tone = wfToneColor(t, s.tone ?? 'neutral');
    final terminal = s.category == 'terminal';
    final kind = s.category == 'initial' ? 'Start' : (terminal ? 'Final' : '');
    final handleSize = touch ? 24.0 : 14.0;
    final semantic = '${s.label}${s.category == 'initial' ? ', starting state' : terminal ? ', final state' : ''}';

    final card = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, e) {
        if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
        final step = HardwareKeyboard.instance.isShiftPressed ? 40.0 : 8.0;
        final d = switch (e.logicalKey) {
          LogicalKeyboardKey.arrowLeft => Offset(-step, 0),
          LogicalKeyboardKey.arrowRight => Offset(step, 0),
          LogicalKeyboardKey.arrowUp => Offset(0, -step),
          LogicalKeyboardKey.arrowDown => Offset(0, step),
          _ => null,
        };
        if (d == null) return KeyEventResult.ignored;
        onKeyMove(d);
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        onPanStart: (_) => onDragStart(),
        onPanUpdate: (d) => onDragUpdate(d.delta),
        onPanEnd: (_) => onDragEnd(true),
        onPanCancel: () => onDragEnd(false),
        child: UiInteractive(
          onTap: onTap,
          selected: selected,
          semanticLabel: semantic,
          excludeChildSemantics: true,
          pressScale: false,
          padTouchTarget: false,
          cursor: dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
          builder: (context, st) {
            final border = selected
                ? t.primary
                : target
                ? t.primary
                : bad
                ? Color.lerp(t.border, t.danger, 0.6)!
                : (st.hovered ? Color.lerp(t.border, t.primary, 0.45)! : t.border);
            return Container(
              width: wfNodeW,
              height: wfNodeH,
              decoration: BoxDecoration(
                color: t.surface,
                border: target ? null : Border.all(color: border),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  ...(dragging ? t.shadow3 : (selected ? t.shadow2 : t.shadow1)),
                  if (selected) BoxShadow(color: t.primary, spreadRadius: 1),
                  if (st.focused) ...t.focusRing,
                ],
              ),
              foregroundDecoration: null,
              child: CustomPaint(
                foregroundPainter: target ? _DashedBorder(t.primary, 10) : null,
                child: Stack(children: [
                  if (terminal)
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(7)),
                      ),
                    ),
                  Positioned(left: 0, top: 8, bottom: 8, child: Container(width: 3, decoration: BoxDecoration(color: tone, borderRadius: const BorderRadius.horizontal(right: Radius.circular(3))))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 12, 6),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, spacing: 1, children: [
                      if (kind.isNotEmpty) Text(kind.toUpperCase(), style: context.uiText.label.copyWith(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, height: 1.1, color: t.textMuted)),
                      Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600, height: 1.25, color: t.text)),
                      Text(
                        '$outCount way${outCount == 1 ? '' : 's'} out${s.sla != null ? ' · time limit' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.body.copyWith(fontSize: 11, height: 1.2, color: t.textMuted),
                      ),
                    ]),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    );

    final showHandle = touch || hovered || selected;
    final handle = GestureDetector(
      supportedDevices: _mouseKinds,
      onPanStart: (d) => onHandleDrag(d.globalPosition),
      onPanUpdate: (d) => onHandleDrag(d.globalPosition),
      onPanEnd: (d) => onHandleDrop(d.globalPosition, true),
      onPanCancel: () => onHandleDrop(Offset.zero, false),
      child: UiInteractive(
        onTap: onHandleTap,
        semanticLabel: 'Add a transition from ${s.label}',
        excludeChildSemantics: true,
        padTouchTarget: false,
        cursor: SystemMouseCursors.precise,
        builder: (context, st) => AnimatedOpacity(
          opacity: showHandle || st.focused || st.hovered ? 1 : 0,
          duration: context.uiAnimate ? t.motionFast : Duration.zero,
          child: AnimatedScale(
            scale: st.hovered ? 1.25 : 1,
            duration: context.uiAnimate ? t.motionFast : Duration.zero,
            child: Container(
              width: handleSize,
              height: handleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.primary,
                border: Border.all(color: t.surface, width: 2),
                boxShadow: st.focused ? t.focusRing : null,
              ),
            ),
          ),
        ),
      ),
    );

    // The box reaches past the card's right edge so the handle, which overhangs it, can be hit.
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: SizedBox(
        width: wfNodeW + handleSize / 2,
        height: wfNodeH,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(left: 0, top: 0, child: card),
          if (!terminal) Positioned(left: wfNodeW - handleSize / 2, top: wfNodeH / 2 - handleSize / 2, child: handle),
        ]),
      ),
    );
  }
}

/// A dashed rounded border (a state that can take a new transition).
class _DashedBorder extends CustomPainter {
  _DashedBorder(this.color, this.radius);
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(0.5));
    canvas.drawPath(_dashed(path, 5, 4), Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

Path _dashed(Path source, double dash, double gap) {
  final out = Path();
  for (final PathMetric m in source.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      out.addPath(m.extractPath(d, math.min(d + dash, m.length)), Offset.zero);
      d += dash + gap;
    }
  }
  return out;
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.edges, required this.rubber, required this.line, required this.head, required this.on});
  final List<_DrawnEdge> edges;
  final (Offset, Offset)? rubber;
  final Color line;
  final Color head;
  final Color on;

  void _arrow(Canvas canvas, Path path, Color color, double size) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final m = metrics.last;
    final tan = m.getTangentForOffset(m.length);
    if (tan == null) return;
    final dir = tan.vector / tan.vector.distance;
    final tip = tan.position;
    final base = tip - dir * size;
    final n = Offset(-dir.dy, dir.dx) * (size / 2);
    canvas.drawPath(Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base.dx + n.dx, base.dy + n.dy)
      ..lineTo(base.dx - n.dx, base.dy - n.dy)
      ..close(), Paint()..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Selected arrows last, so they sit on top.
    for (final e in [...edges.where((e) => !e.selected), ...edges.where((e) => e.selected)]) {
      final path = e.path.toPath();
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = e.selected ? 2.2 : 1.6
        ..color = e.selected ? on : line;
      canvas.drawPath(e.auto ? _dashed(path, 5, 4) : path, paint);
      _arrow(canvas, path, e.selected ? on : head, e.selected ? 10 : 9);
    }
    final r = rubber;
    if (r != null) {
      final p = Path()
        ..moveTo(r.$1.dx, r.$1.dy)
        ..lineTo(r.$2.dx, r.$2.dy);
      canvas.drawPath(_dashed(p, 4, 3), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = on);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => true;
}

class _ListState extends StatelessWidget {
  const _ListState({
    required this.state,
    required this.selected,
    required this.outgoing,
    required this.stateLabel,
    required this.isSelected,
    required this.onSelect,
    required this.onSelectTransition,
    required this.onAdd,
  });

  final UiWfState state;
  final bool selected;
  final List<UiWfTransition> outgoing;
  final String Function(String id) stateLabel;
  final bool Function(String id) isSelected;
  final VoidCallback onSelect;
  final ValueChanged<String> onSelectTransition;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final s = state;
    final tone = s.tone == null || s.tone == 'neutral' ? t.border : wfToneColor(t, s.tone);
    return Semantics(
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: selected ? t.primary : t.border),
          borderRadius: BorderRadius.circular(t.radius),
        ),
        clipBehavior: Clip.antiAlias,
        // The tone bar on the left edge (a non-uniform border can't be rounded).
        foregroundDecoration: BoxDecoration(border: Border(left: BorderSide(color: tone, width: 3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          UiInteractive(
            onTap: onSelect,
            selected: selected,
            semanticLabel: s.label,
            excludeChildSemantics: true,
            pressScale: false,
            builder: (context, st) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(boxShadow: st.focused ? t.focusRing : null),
              child: Row(spacing: 8, children: [
                Expanded(child: Text(s.label, style: context.uiText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: t.text))),
                if (s.category != 'active') WfChip(s.category == 'initial' ? 'Start' : 'Final'),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 10, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2, children: [
              for (final tr in outgoing)
                UiInteractive(
                  onTap: () => onSelectTransition(tr.id),
                  selected: isSelected(tr.id),
                  semanticLabel: '${tr.label}, to ${stateLabel(tr.to)}',
                  excludeChildSemantics: true,
                  pressScale: false,
                  builder: (context, st) => Container(
                    constraints: const BoxConstraints(minHeight: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected(tr.id) ? t.primary.withValues(alpha: 0.12) : (st.hovered ? t.surfaceHover : null),
                      borderRadius: BorderRadius.circular(t.radiusXs),
                      boxShadow: st.focused ? t.focusRing : null,
                    ),
                    child: Row(spacing: 8, children: [
                      Flexible(child: Text(tr.label, style: context.uiText.body.copyWith(fontSize: 13, color: t.text))),
                      UiIcon(WfIcons.arrowRight02, size: 12, color: t.textMuted),
                      Text(stateLabel(tr.to), style: context.uiText.body.copyWith(fontSize: 13, color: t.textMuted)),
                      if (tr.auto != null) const WfChip('automatic'),
                    ]),
                  ),
                ),
              if (s.category != 'terminal') Align(alignment: AlignmentDirectional.centerStart, child: FbLink(label: 'Add a transition', fontSize: 12, onTap: onAdd)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The steps that run for the selected state (on entering, on leaving, when late) or transition
/// ("then do"), shown under the diagram as a step list (the web `ui-wf-lifecycle-runs`). With
/// nothing selected it shrinks to a one-line hint, leaving the room to the diagram.
class WfLifecycleRuns extends StatefulWidget {
  const WfLifecycleRuns({super.key});

  /// Whether the pane is showing only its hint (nothing it could show is selected).
  static bool isIdle(UiWorkflowBuilderController store) => _lists(store).isEmpty;

  /// The selected state or transition, or the one that holds the selected step.
  static UiWfSelection? _owner(UiWorkflowBuilderController store) {
    final s = store.selection;
    if (s == null) return null;
    if (s.kind == 'state' || s.kind == 'transition') return s;
    if (s.kind == 'step') {
      final loc = store.steps[s.id];
      final root = loc?.path.first;
      if (root == null || root == 'root') return null;
      final i = root.indexOf(':');
      final kind = root.substring(0, i), id = root.substring(i + 1);
      return kind == 'transition' ? UiWfSelection.transition(id) : UiWfSelection.state(id);
    }
    return null;
  }

  static List<({String value, String label})> _lists(UiWorkflowBuilderController store) {
    final o = _owner(store);
    if (o == null) return const [];
    final lc = store.def.lifecycle;
    if (o.kind == 'transition') {
      return lc?.transitions.any((t) => t.id == o.id) ?? false ? [(value: 'transition:${o.id}', label: 'Then do')] : const [];
    }
    final st = lc?.states.where((x) => x.id == o.id).firstOrNull;
    if (st == null) return const [];
    return [
      (value: 'onEnter:${o.id}', label: 'On entering'),
      if (st.category != 'initial') (value: 'onExit:${o.id}', label: 'On leaving'),
      if (st.sla != null) (value: 'sla:${o.id}', label: 'When late'),
    ];
  }

  @override
  State<WfLifecycleRuns> createState() => _WfLifecycleRunsState();
}

class _WfLifecycleRunsState extends State<WfLifecycleRuns> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _viewport = GlobalKey(debugLabel: 'wf runs viewport');
  WfDnd? _dnd;
  String? _tab;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = WfBuilderScope.of(context).store;
    final lists = WfLifecycleRuns._lists(store);
    if (lists.isEmpty) {
      return Container(
        color: t.bg,
        padding: EdgeInsets.all(t.space3),
        child: Text('Select a state or a transition to see the steps it runs.', textAlign: TextAlign.center, style: context.uiText.body.copyWith(fontSize: 13, color: t.textMuted)),
      );
    }
    final sel = store.selection;
    String active;
    final root = sel?.kind == 'step' ? store.steps[sel!.id]?.path.first : null;
    if (root != null && lists.any((l) => l.value == root)) {
      // A selected step shows the list it is in.
      active = root;
    } else {
      active = lists.where((l) => l.value == _tab).firstOrNull?.value ?? lists.first.value;
    }
    final owner = WfLifecycleRuns._owner(store)!;
    final lc = store.def.lifecycle;
    final title = owner.kind == 'transition'
        ? 'After “${lc?.transitions.where((x) => x.id == owner.id).firstOrNull?.label ?? ''}”'
        : 'In “${lc?.states.where((x) => x.id == owner.id).firstOrNull?.label ?? ''}”';
    final kind = active.split(':').first;
    final hint = switch (kind) {
      'transition' => 'These run right after the record moves (the person who moved it is “whoever started it”).',
      'onEnter' => 'These run every time a record arrives in this state. They stop if it leaves.',
      'onExit' => 'These run every time a record leaves this state.',
      _ => 'These run once if a record stays in this state longer than its time limit.',
    };
    return ColoredBox(
      color: t.bg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: 6),
          decoration: BoxDecoration(color: t.surface, border: Border(bottom: BorderSide(color: t.borderSubtle))),
          child: Wrap(spacing: t.space3, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Semantics(header: true, child: Text(title, style: context.uiText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: t.text))),
            if (lists.length > 1)
              UiSegmented<String>(
                label: 'Which steps',
                size: UiSize.sm,
                value: active,
                options: [for (final l in lists) UiSegmentedOption(value: l.value, label: l.label)],
                onChanged: (v) => setState(() => _tab = v),
              ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: _viewport,
            controller: _scroll,
            padding: EdgeInsets.all(t.space3),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(padding: const EdgeInsets.only(bottom: 4), child: FbHint(hint)),
                  WfStepList(listId: active, steps: listSteps(store.def, active) ?? const []),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
