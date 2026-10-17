import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../dialog/drawer.dart';
import '../navigation/stepper.dart';
import '../theme/theme.dart';
import 'api.dart';
import 'bits.dart';
import 'clock.dart';
import 'history.dart';
import 'runtime.dart';

/// How [UiWorkflowPanel] sits on the page (the web `UiWorkflowPanelLayout`):
/// - [vertical]: a panel in the page, the states top to bottom with history and actions under each;
/// - [horizontal]: the states left to right, the current state's actions and the history below;
/// - [compact]: the state as a badge with a strip of states, the actions, and one flat history
///   (newest first), for a narrow column;
/// - [sideDrawer]: a column of dots on the screen's edge that opens the vertical panel in a drawer;
/// - [bottomDrawer]: a row of dots along the bottom that opens the horizontal panel in a drawer.
enum UiWorkflowPanelLayout { vertical, horizontal, compact, sideDrawer, bottomDrawer }

/// Whether the record has been through [key] already: an earlier state in the lifecycle's order.
bool _statePassed(UiWfRecord r, String key) {
  final i = r.states.indexWhere((s) => s.key == key);
  final here = r.states.indexWhere((s) => s.key == r.state);
  return i >= 0 && here >= 0 && i < here;
}

/// One state on the record's path, with what happened while it was there.
class UiWfPanelStep {
  UiWfPanelStep(this.key, this.label);
  final String key;
  final String label;

  /// History entries that happened in this state, oldest first.
  final List<UiWfAuditEntry> entries = [];
}

/// The states a record shows, in order (the web `wfPanelPath`): the states it has been through (first
/// visit first), then, unless it has finished, the states it hasn't reached yet in the lifecycle's
/// order. The active one is the current state; a state it went back from counts as not reached.
({List<UiWfPanelStep> steps, int active}) wfPanelPath(UiWfRecord r, List<UiWfAuditEntry> history) {
  String label(String k) => r.states.where((s) => s.key == k).firstOrNull?.label ?? k;
  final steps = <UiWfPanelStep>[];
  final byKey = <String, UiWfPanelStep>{};
  UiWfPanelStep visit(String k) => byKey.putIfAbsent(k, () {
        final s = UiWfPanelStep(k, label(k));
        steps.add(s);
        return s;
      });
  UiWfPanelStep? here;
  for (final h in [...history]..sort((a, b) => a.seq.compareTo(b.seq))) {
    final entered = h.category == 'lifecycle' ? wfAuditJson(h.after)['state'] : null;
    if (entered is String && entered.isNotEmpty) here = visit(entered);
    // An entry belongs to the state the record was in when it happened (a move, to the state it entered).
    here?.entries.add(h);
  }
  final state = r.state;
  if (state != null) visit(state);
  final active = state == null ? -1 : steps.indexWhere((s) => s.key == state);
  final finished = r.states.where((s) => s.key == state).firstOrNull?.category == 'terminal';
  if (!finished) {
    for (final s in r.states) {
      if (!byKey.containsKey(s.key)) visit(s.key);
    }
  }
  return (steps: steps, active: active < 0 ? 0 : active);
}

/// `ui-workflow-panel`: the workflow of one record, to attach to the record's page: its states as a
/// stepper (green for states it has been through, dark for those not reached), what happened in
/// each, and in the current state the moves this person may make, open tasks and manual workflows.
///
/// Choose where it sits with [layout]: `vertical`, `horizontal`, `compact` (a badge, a strip of
/// states, the actions and a flat history, for a narrow column) or a drawer. The drawer layouts put a
/// rail of dots on the screen's edge (wherever the widget sits in the tree): hovering it with a mouse
/// opens the drawer over the page (moving away closes it); tapping or clicking it opens it as a
/// regular drawer. A record type with no lifecycle still shows its manual workflows, open tasks and
/// history (the compact body) in every layout.
class UiWorkflowPanel extends StatefulWidget {
  const UiWorkflowPanel({
    super.key,
    required this.api,
    required this.entity,
    required this.entityId,
    this.layout = UiWorkflowPanelLayout.vertical,
    this.side = UiDrawerSide.right,
    this.title = 'Workflow',
    this.showHistory = true,
    this.emptyText = 'Nothing for you to do here right now.',
    this.onChanged,
  });

  /// The engine. Nothing loads while it is null.
  final UiWorkflowApi? api;
  final String entity;
  final String entityId;
  final UiWorkflowPanelLayout layout;

  /// Which edge the side drawer opens from ([UiDrawerSide.left] or [UiDrawerSide.right]).
  final UiDrawerSide side;

  /// The panel's heading (and the drawer's title); empty hides the heading.
  final String title;
  final bool showHistory;

  /// Said in the current state when this person has nothing to do there; empty hides it.
  final String emptyText;

  /// After the record moved through the panel, so the page can reload its own data.
  final ValueChanged<UiWfRecord>? onChanged;

  @override
  State<UiWorkflowPanel> createState() => UiWorkflowPanelState();
}

class UiWorkflowPanelState extends State<UiWorkflowPanel> {
  final _record = ValueNotifier<UiWfRecord?>(null);
  final _history = ValueNotifier<List<UiWfAuditEntry>>(const []);
  final _error = ValueNotifier<String>('');
  final _rail = OverlayPortalController();
  int _seq = 0;
  bool _peek = false;
  bool _drawerOpen = false;
  Timer? _closeTimer;

  bool get _isDrawer => widget.layout == UiWorkflowPanelLayout.sideDrawer || widget.layout == UiWorkflowPanelLayout.bottomDrawer;
  UiDrawerSide get _edge => widget.layout == UiWorkflowPanelLayout.bottomDrawer ? UiDrawerSide.bottom : widget.side;

  /// Whether the drawer is open (hover peek or regular drawer).
  bool get isOpen => _peek || _drawerOpen;

  @override
  void initState() {
    super.initState();
    // Shown for good (show() may not be called during a rebuild); it draws nothing unless a drawer layout.
    _rail.show();
    reload();
  }

  @override
  void didUpdateWidget(UiWorkflowPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.api != widget.api || old.entity != widget.entity || old.entityId != widget.entityId) reload();
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _record.dispose();
    _history.dispose();
    _error.dispose();
    super.dispose();
  }

  /// Reloads the record and its history (e.g. after the page changed the record itself).
  Future<void> reload() async {
    final api = widget.api;
    if (api == null) return;
    final n = ++_seq;
    try {
      final results = await Future.wait<Object>([
        api.record(widget.entity, widget.entityId),
        widget.showHistory ? api.recordHistory(widget.entity, widget.entityId, take: 100).catchError((_) => <UiWfAuditEntry>[]) : Future.value(<UiWfAuditEntry>[]),
      ]);
      if (!mounted || n != _seq) return;
      _record.value = results[0] as UiWfRecord;
      _history.value = results[1] as List<UiWfAuditEntry>;
      _error.value = '';
      if (_isDrawer) setState(() {}); // the rail's dots
    } catch (e) {
      if (mounted && n == _seq) _error.value = e is UiWfApiError ? e.message : 'Could not load the record’s workflow.';
    }
  }

  Future<void> _moved(UiWfRecord r) async {
    _record.value = r;
    widget.onChanged?.call(r);
    await reload();
  }

  String _describe(UiWfAuditEntry h) =>
      wfDescribeHistory(h, (k) => _record.value?.states.where((s) => s.key == k).firstOrNull?.label ?? (k == null ? '' : '$k'));

  // ── Opening the drawer ──────────────────────────────────────────────────────────────────

  /// Hover opens the peek only with a real hovering pointer (a mouse or trackpad), never a finger.
  void _hoverIn(PointerDeviceKind kind) {
    _closeTimer?.cancel();
    if (kind != PointerDeviceKind.mouse || isOpen) return;
    setState(() => _peek = true);
  }

  /// Leaving the rail and the drawer closes a hover-opened peek, after a moment to cross the gap.
  void _hoverOut() {
    if (!_peek) return;
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _peek = false);
    });
  }

  /// A tap, a click or Enter on the rail: open as a regular drawer (pinning a peek), or close.
  Future<void> _toggle() async {
    _closeTimer?.cancel();
    if (_peek) setState(() => _peek = false);
    if (_drawerOpen) return;
    setState(() => _drawerOpen = true);
    await showUiDrawer<void>(
      context: context,
      side: _edge,
      title: widget.title,
      builder: (context) => _body(context, _edge == UiDrawerSide.bottom ? UiWorkflowPanelLayout.horizontal : UiWorkflowPanelLayout.vertical),
    );
    if (mounted) setState(() => _drawerOpen = false);
  }

  // ── Building ────────────────────────────────────────────────────────────────────────────

  Widget _body(BuildContext context, UiWorkflowPanelLayout mode) {
    final horizontal = mode == UiWorkflowPanelLayout.horizontal;
    return ListenableBuilder(
      listenable: Listenable.merge([_record, _history, _error]),
      builder: (context, _) {
        final t = context.ui;
        final r = _record.value;
        if (r == null) return _error.value.isNotEmpty ? WfNote(_error.value) : const FbHint('Loading…');
        // Compact, or no lifecycle: the state as a badge and a strip, the actions, and one flat history.
        if (r.state == null || mode == UiWorkflowPanelLayout.compact) return _compact(context, r, gap: mode == UiWorkflowPanelLayout.compact ? t.space2 : t.space3);
        final path = wfPanelPath(r, _history.value);
        final now = UiWorkflowClock.nowOf(context);
        final steps = [for (final s in path.steps) UiStep(label: s.label)];
        Widget actions() => _actions(r, emptyText: widget.emptyText);
        Widget log(List<UiWfAuditEntry> entries) => _log(context, r, entries);

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space3, children: [
          Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
            UiWorkflowStateBadge(label: r.stateLabel ?? r.state!, tone: r.stateTone),
            Text('since ${wfAgo(r.stateEnteredAt, now)}', style: context.uiText.body.copyWith(fontSize: 12, color: t.textMuted)),
            if (r.status == 'outOfSync') const WfChip('Out of sync', tone: 'warning'),
          ]),
          if (!horizontal)
            UiStepper(
              steps: steps,
              active: path.active,
              axis: Axis.vertical,
              tone: UiStepperTone.success,
              label: widget.title,
              body: (context, i, state) {
                final entries = path.steps[i].entries;
                final parts = <Widget>[
                  if (widget.showHistory && entries.isNotEmpty) log(entries),
                  if (state == UiStepState.active) actions() else if (state == UiStepState.todo && entries.isEmpty) const FbHint('Not reached yet'),
                ];
                return parts.isEmpty ? null : Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: parts);
              },
            )
          else ...[
            UiStepper(steps: steps, active: path.active, axis: Axis.horizontal, tone: UiStepperTone.success, label: widget.title),
            actions(),
            if (widget.showHistory && _history.value.isNotEmpty) ...[
              const WfSectionTitle('History'),
              log(_newestFirst.take(8).toList()),
            ],
          ],
        ]);
      },
    );
  }

  List<UiWfAuditEntry> get _newestFirst => [..._history.value]..sort((a, b) => b.seq.compareTo(a.seq));

  Widget _actions(UiWfRecord r, {required String emptyText}) => WfRecordActions(
        api: widget.api,
        record: r,
        entity: widget.entity,
        entityId: widget.entityId,
        emptyText: emptyText,
        onChanged: _moved,
        onReload: reload,
      );

  /// History entries as a list with a rule on the left.
  Widget _log(BuildContext context, UiWfRecord r, List<UiWfAuditEntry> entries) {
    final t = context.ui;
    final now = UiWorkflowClock.nowOf(context);
    final muted = context.uiText.body.copyWith(fontSize: 11.5, color: t.textMuted);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: 4, children: [
      for (final h in entries)
        Container(
          padding: const EdgeInsets.fromLTRB(10, 4, 0, 4),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: t.border, width: 2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            WfArrowText(_describe(h), style: context.uiText.body.copyWith(fontSize: 13, color: t.text)),
            Text('${wfActorLabel(h, (k) => r.instances.where((i) => i.definitionKey == k).firstOrNull?.title)} · ${wfAgo(h.at, now)}', style: muted),
          ]),
        ),
    ]);
  }

  /// The compact body (also what every layout shows for a record type with no lifecycle): the state
  /// as a badge with a strip of states, the actions, and one flat history, newest first. [gap] is the
  /// only spacing between the blocks.
  Widget _compact(BuildContext context, UiWfRecord r, {required double gap}) {
    final t = context.ui;
    final now = UiWorkflowClock.nowOf(context);
    final state = r.state;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: gap, children: [
      Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (state != null) ...[
          UiWorkflowStateBadge(label: r.stateLabel ?? state, tone: r.stateTone),
          Text('since ${wfAgo(r.stateEnteredAt, now)}', style: context.uiText.body.copyWith(fontSize: 12, color: t.textMuted)),
          if (r.status == 'outOfSync') const WfChip('Out of sync', tone: 'warning'),
        ] else
          const FbHint('No lifecycle for this record type.'),
      ]),
      if (r.states.length > 1)
        Semantics(
          container: true,
          label: 'Lifecycle',
          child: Wrap(key: const ValueKey('wf-track'), spacing: 4, runSpacing: 4, children: [
            for (final s in r.states) _TrackState(label: s.label, here: s.key == state, done: _statePassed(r, s.key)),
          ]),
        ),
      // Without a lifecycle there is no "current state" to have nothing to do in.
      _actions(r, emptyText: state != null ? widget.emptyText : ''),
      if (widget.showHistory)
        Padding(
          padding: EdgeInsets.only(top: t.space2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: 6, children: [
            const WfSectionTitle('History'),
            if (_history.value.isEmpty) const FbHint('Nothing yet.') else _log(context, r, _newestFirst),
          ]),
        ),
    ]);
  }

  Widget _railWidget(BuildContext context) {
    if (!_isDrawer) return const SizedBox.shrink();
    final t = context.ui;
    final r = _record.value;
    final path = r == null ? (steps: <UiWfPanelStep>[], active: 0) : wfPanelPath(r, _history.value);
    // A record type with no lifecycle still gets one dot, so the rail can open.
    final dots = [
      for (final st in path.steps) UiStep(label: st.label),
      if (path.steps.isEmpty && r != null) UiStep(label: widget.title.isEmpty ? 'Workflow' : widget.title),
    ];
    final edge = _edge;
    final vertical = edge != UiDrawerSide.bottom;
    final rr = Radius.circular(t.radiusLg);
    final now = path.steps.isEmpty ? null : path.steps[path.active].label;
    final label = '${widget.title}${now == null ? '' : ': $now, step ${path.active + 1} of ${path.steps.length}'}. ${isOpen ? 'Close' : 'Open'}';
    final rail = MouseRegion(
      onEnter: (e) => _hoverIn(e.kind),
      onExit: (_) => _hoverOut(),
      child: UiInteractive(
        onTap: _toggle,
        semanticLabel: label,
        excludeChildSemantics: true,
        pressScale: false,
        builder: (context, s) => Container(
          padding: vertical ? EdgeInsets.symmetric(horizontal: t.space2, vertical: t.space3) : EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
          decoration: BoxDecoration(
            color: t.surfaceRaised,
            border: Border.all(color: t.border),
            borderRadius: switch (edge) {
              UiDrawerSide.left => BorderRadius.only(topRight: rr, bottomRight: rr),
              UiDrawerSide.bottom || UiDrawerSide.top => BorderRadius.only(topLeft: rr, topRight: rr),
              UiDrawerSide.right => BorderRadius.only(topLeft: rr, bottomLeft: rr),
            },
            boxShadow: [...t.shadow2, if (s.focused) ...t.focusRing],
          ),
          child: UiStepper(
            steps: dots,
            active: path.active,
            axis: vertical ? Axis.vertical : Axis.horizontal,
            variant: UiStepperVariant.dots,
            tone: UiStepperTone.success,
          ),
        ),
      ),
    );
    return Align(
      alignment: switch (edge) {
        UiDrawerSide.left => Alignment.centerLeft,
        UiDrawerSide.bottom || UiDrawerSide.top => Alignment.bottomCenter,
        UiDrawerSide.right => Alignment.centerRight,
      },
      child: SafeArea(left: edge == UiDrawerSide.left, right: edge == UiDrawerSide.right, top: false, bottom: edge == UiDrawerSide.bottom, child: rail),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    if (!_isDrawer) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: widget.layout == UiWorkflowPanelLayout.compact ? t.space2 : t.space3, children: [
        if (widget.title.isNotEmpty)
          Semantics(header: true, child: Text(widget.title, style: context.uiText.body.copyWith(fontSize: t.fontSizeMd, fontWeight: FontWeight.w600, color: t.text))),
        _body(context, widget.layout),
      ]);
    }
    // The rail lives in the overlay, fixed to the screen's edge; the peek drawer slides over it.
    return UiDrawerPeek(
      open: _peek,
      side: _edge,
      title: widget.title,
      onClose: () => setState(() => _peek = false),
      onPointerEnter: () => _closeTimer?.cancel(),
      onPointerExit: _hoverOut,
      drawer: (context) => _body(context, _edge == UiDrawerSide.bottom ? UiWorkflowPanelLayout.horizontal : UiWorkflowPanelLayout.vertical),
      child: OverlayPortal(controller: _rail, overlayChildBuilder: _railWidget, child: const SizedBox.shrink()),
    );
  }
}

/// One state in the compact strip: the current one filled, the ones passed in a stronger grey.
class _TrackState extends StatelessWidget {
  const _TrackState({required this.label, required this.here, required this.done});
  final String label;
  final bool here;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Semantics(
      selected: here,
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: here ? t.primary : t.surfaceHover, borderRadius: BorderRadius.circular(11)),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: context.uiText.label.copyWith(
              fontSize: 11.5,
              height: 1,
              fontWeight: here ? FontWeight.w600 : FontWeight.w500,
              color: here ? t.primaryContrast : (done ? t.textSecondary : t.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}
