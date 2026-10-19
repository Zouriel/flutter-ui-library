import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';

import '../button/button.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../dialog/drawer.dart';
import '../dialog/modal.dart';
import '../feedback/alert.dart';
import '../navigation/stepper.dart';
import '../theme/theme.dart';
import 'api.dart';
import 'bits.dart';
import 'clock.dart';
import 'history.dart';
import 'icons.dart';
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
///
/// After a reset the path starts again: what happened before the latest reset is returned apart, in
/// `earlier` (oldest first), so states visited only before starting over show as not reached. When
/// the history is cut short (only the newest entries), entries before its first move belong to the
/// state that move left.
({List<UiWfPanelStep> steps, int active, List<UiWfAuditEntry> earlier}) wfPanelPath(UiWfRecord r, List<UiWfAuditEntry> history) {
  String label(String k) => r.states.where((s) => s.key == k).firstOrNull?.label ?? k;
  final steps = <UiWfPanelStep>[];
  final byKey = <String, UiWfPanelStep>{};
  UiWfPanelStep visit(String k) => byKey.putIfAbsent(k, () {
        final s = UiWfPanelStep(k, label(k));
        steps.add(s);
        return s;
      });
  final sorted = [...history]..sort((a, b) => a.seq.compareTo(b.seq));
  var lastReset = -1;
  for (var i = 0; i < sorted.length; i++) {
    if (sorted[i].category == 'lifecycle' && sorted[i].action == 'reset') lastReset = i;
  }
  final earlier = lastReset > 0 ? sorted.sublist(0, lastReset) : <UiWfAuditEntry>[];
  final current = lastReset > 0 ? sorted.sublist(lastReset) : sorted;
  String? entered(UiWfAuditEntry h) {
    final s = h.category == 'lifecycle' ? wfAuditJson(h.after)['state'] : null;
    return s is String && s.isNotEmpty ? s : null;
  }

  // A cut-short history may begin mid-state: the first move says which state it left.
  final firstMove = current.where((h) => entered(h) != null).firstOrNull;
  final left = firstMove == null ? null : wfAuditJson(firstMove.before)['state'];
  UiWfPanelStep? here = firstMove != null && !identical(firstMove, current.first) && left is String && left.isNotEmpty ? visit(left) : null;
  for (final h in current) {
    final k = entered(h);
    if (k != null) here = visit(k);
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
  return (steps: steps, active: active < 0 ? 0 : active, earlier: earlier);
}

/// What [UiWorkflowPanel.onChanged] compares between two reads: the state, its status, and each run's status.
String _signature(UiWfRecord r) => jsonEncode([r.state, r.status, [for (final i in r.instances) '${i.id}:${i.status}']..sort()]);

/// How many history entries the panel reads; the engine returns the newest ones.
const int wfPanelHistoryTake = 500;

/// How often the panel looks again while one of the record's runs is still going.
const Duration _runsPoll = Duration(seconds: 15);

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
///
/// In the drawer layouts the host can open and close the drawer with [open] and follow it with
/// [onOpenChanged] (the web `[(open)]`).
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
    this.open,
    this.onOpenChanged,
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

  /// Whenever the record's workflow changed as the panel saw it: a move made in the panel, and any
  /// reload that finds a new state or status or runs that started, finished or stopped (after a
  /// decision, a manual start, a retry, skip or cancel, or the panel looking again while runs go on).
  final ValueChanged<UiWfRecord>? onChanged;

  /// Drawer layouts: whether the drawer is open, when the host controls it (true opens it as a
  /// regular drawer, false closes it); null leaves it to the rail.
  final bool? open;

  /// Drawer layouts: the drawer opened (from the rail, a hover or [open]) or closed (in any way).
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<UiWorkflowPanel> createState() => UiWorkflowPanelState();
}

class UiWorkflowPanelState extends State<UiWorkflowPanel> with WidgetsBindingObserver {
  final _record = ValueNotifier<UiWfRecord?>(null);
  final _history = ValueNotifier<List<UiWfAuditEntry>>(const []);
  final _error = ValueNotifier<String>('');

  /// The history could not be read (the record could).
  final _historyError = ValueNotifier<bool>(false);

  /// "Earlier, before starting over" is open.
  final _earlierOpen = ValueNotifier<bool>(false);

  /// Bumped when the stuck-record banner's own state changes (who may act, busy, its error).
  final _stuckTick = ValueNotifier<int>(0);

  /// Whether the engine lets this person intervene (`me().canIntervene`), asked once the record is stuck.
  bool _mayIntervene = false;
  UiWorkflowApi? _interveneAskedFor;

  /// A retry or skip of the record's stopped timer is under way, and what went wrong with the last one.
  bool _recordBusy = false;
  String _recordActError = '';

  /// Looks again every 15 s while a run is still going and the app is in view.
  Timer? _poll;
  bool _visible = true;

  /// Runs shown open: a stopped run opens by itself the first time it is seen, so what to do is in view.
  final _openRuns = ValueNotifier<Set<String>>(const {});
  final Set<String> _seenStopped = {};
  final _rail = OverlayPortalController();
  int _seq = 0;
  bool _peek = false;
  bool _drawerOpen = false;
  Timer? _closeTimer;

  /// The regular drawer's route, so closing it from [UiWorkflowPanel.open] never pops something else.
  Route<void>? _drawerRoute;

  /// What [UiWorkflowPanel.onOpenChanged] was last told.
  bool _reportedOpen = false;

  bool get _isDrawer => widget.layout == UiWorkflowPanelLayout.sideDrawer || widget.layout == UiWorkflowPanelLayout.bottomDrawer;
  UiDrawerSide get _edge => widget.layout == UiWorkflowPanelLayout.bottomDrawer ? UiDrawerSide.bottom : widget.side;

  /// Whether the drawer is open (hover peek or regular drawer).
  bool get isOpen => _peek || _drawerOpen;

  @override
  void initState() {
    super.initState();
    // Shown for good (show() may not be called during a rebuild); it draws nothing unless a drawer layout.
    _rail.show();
    WidgetsBinding.instance.addObserver(this);
    final now = WidgetsBinding.instance.lifecycleState;
    _visible = now == null || now == AppLifecycleState.resumed || now == AppLifecycleState.inactive;
    reload();
    if (widget.open == true) WidgetsBinding.instance.addPostFrameCallback((_) => _openFromHost());
  }

  @override
  void didUpdateWidget(UiWorkflowPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.entity != widget.entity || old.entityId != widget.entityId) {
      // Another record: drop the old one at once, so its buttons and history never show for the new one.
      _seq++;
      _record.value = null;
      _history.value = const [];
      _historyError.value = false;
      _error.value = '';
      _openRuns.value = const {};
      _seenStopped.clear();
      _recordActError = '';
      _syncPoll();
    }
    if (old.api != widget.api || old.entity != widget.entity || old.entityId != widget.entityId) reload();
    if (old.open != widget.open) {
      if (widget.open == true && !isOpen) WidgetsBinding.instance.addPostFrameCallback((_) => _openFromHost());
      if (widget.open == false && isOpen) WidgetsBinding.instance.addPostFrameCallback((_) => _close());
    }
  }

  /// Tells the host when the drawer opened or closed.
  void _report() {
    if (isOpen == _reportedOpen) return;
    _reportedOpen = isOpen;
    widget.onOpenChanged?.call(isOpen);
  }

  void _openFromHost() {
    if (!mounted || !_isDrawer || isOpen || widget.open != true) return;
    _toggle();
  }

  /// Closes the peek or the regular drawer (its own route, even with a dialog on top of it).
  void _close() {
    if (!mounted) return;
    if (_peek) {
      setState(() => _peek = false);
      _report();
    }
    final route = _drawerRoute;
    if (route == null || !route.isActive) return;
    route.navigator?.popUntil((r) => r == route);
    if (route.isCurrent) route.navigator?.pop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
    _syncPoll();
  }

  /// Some run of the record is still going (queued, running or waiting): worth looking again.
  bool get _runsGoing => (_record.value?.instances ?? const <UiWfInstance>[]).any((i) => const {'queued', 'running', 'waiting'}.contains(i.status));

  /// Whether the panel is looking again on a timer now.
  bool get polling => _poll != null;

  void _syncPoll() {
    final go = _runsGoing && _visible && mounted;
    if (go == (_poll != null)) return;
    _poll?.cancel();
    _poll = go ? Timer.periodic(_runsPoll, (_) => reload()) : null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _poll = null;
    _closeTimer?.cancel();
    _historyError.dispose();
    _earlierOpen.dispose();
    _stuckTick.dispose();
    _record.dispose();
    _history.dispose();
    _error.dispose();
    _openRuns.dispose();
    super.dispose();
  }

  /// Reloads the record and its history (e.g. after the page changed the record itself).
  Future<void> reload() async {
    final api = widget.api;
    if (api == null) return;
    final n = ++_seq;
    try {
      var historyFailed = false;
      final results = await Future.wait<Object>([
        api.record(widget.entity, widget.entityId),
        widget.showHistory
            ? api.recordHistory(widget.entity, widget.entityId, take: wfPanelHistoryTake).catchError((Object _) {
                historyFailed = true;
                return <UiWfAuditEntry>[];
              })
            : Future.value(<UiWfAuditEntry>[]),
      ]);
      if (!mounted || n != _seq) return;
      final record = results[0] as UiWfRecord;
      final before = _record.value;
      _record.value = record;
      // A failed history read keeps what was shown rather than emptying it.
      if (!historyFailed) _history.value = results[1] as List<UiWfAuditEntry>;
      _historyError.value = historyFailed;
      _error.value = '';
      _syncPoll();
      if (record.status == 'incident') _askIntervene(api);
      if (before != null && _signature(before) != _signature(record)) widget.onChanged?.call(record);
      final stopped = [for (final i in record.instances) if (i.status == 'incident' && !_seenStopped.contains(i.id)) i.id];
      if (stopped.isNotEmpty) {
        _seenStopped.addAll(stopped);
        _openRuns.value = {..._openRuns.value, ...stopped};
      }
      if (_isDrawer) setState(() {}); // the rail's dots
    } catch (e) {
      if (mounted && n == _seq) _error.value = wfErrorText(e, 'Could not load the record’s workflow.');
    }
  }

  /// The record's lifecycle stuck: ask (once per API) whether this person may try it again or skip it.
  void _askIntervene(UiWorkflowApi api) {
    if (_interveneAskedFor == api) return;
    _interveneAskedFor = api;
    Future.sync(api.me).then((me) {
      if (!mounted) return;
      _mayIntervene = me?.canIntervene ?? false;
      _stuckTick.value++;
    }).catchError((Object _) {
      // A failed answer is not kept: the next time the record is read stuck, ask again.
      _interveneAskedFor = null;
      if (mounted) {
        _mayIntervene = false;
        _stuckTick.value++;
      }
    });
  }

  /// Tries the record's stopped timer again, or skips it. The record view doesn't carry its lifecycle
  /// instance's id, so it is looked up (the record's lifecycle instance in `incident`); if there is
  /// none any more (cleared meanwhile), the reload shows that. Answers whether it worked.
  Future<bool> _recordAct(String kind) async {
    final api = widget.api;
    final r = _record.value;
    if (api == null || r == null || _recordBusy) return false;
    final entity = widget.entity, id = widget.entityId;
    _recordBusy = true;
    _recordActError = '';
    _stuckTick.value++;
    try {
      final page = await api.instances(UiWfInstanceQuery(entity: entity, entityId: id, kind: const ['record'], status: const ['incident'], take: 10));
      final own = page.items.where((i) => r.lifecycle == null || i.definitionKey == r.lifecycle).firstOrNull ?? page.items.firstOrNull;
      if (own != null) await (kind == 'retry' ? api.retry(own.id) : api.skip(own.id));
      // Pointed at another record meanwhile: nothing here to update.
      if (!mounted || entity != widget.entity || id != widget.entityId) return false;
      await reload();
      return true;
    } catch (e) {
      if (mounted && entity == widget.entity && id == widget.entityId) _recordActError = wfErrorText(e, 'That did not work.');
      return false;
    } finally {
      _recordBusy = false;
      if (mounted) _stuckTick.value++;
    }
  }

  /// Skipping the record's stopped timer: confirmed, since what it would have done (an automatic move,
  /// a time limit) never happens.
  Future<void> _askSkipRecordTimer(UiWfRecord r) async {
    await showUiModal<void>(
      context: context,
      title: 'Skip ${wfParkedTimerName(r.error)}',
      size: UiModalSize.md,
      builder: (ctx) => ValueListenableBuilder(
        valueListenable: _stuckTick,
        builder: (ctx, _, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: ctx.ui.space2, children: [
          Text('It is dropped without running: the record stays where it is, with nothing scheduled in its place. It can still be moved by hand.',
              style: ctx.uiText.body.copyWith(fontSize: 14, color: ctx.ui.text)),
          if (_recordActError.isNotEmpty) WfNote(_recordActError),
        ]),
      ),
      footerBuilder: (ctx) => ValueListenableBuilder(
        valueListenable: _stuckTick,
        builder: (ctx, _, _) => Row(mainAxisAlignment: MainAxisAlignment.end, spacing: ctx.ui.space2, children: [
          UiButton(label: 'Back', variant: UiButtonVariant.ghost, onPressed: _recordBusy ? null : () => Navigator.of(ctx).pop()),
          UiButton(
            label: 'Skip it',
            onPressed: _recordBusy
                ? null
                : () async {
                    final ok = await _recordAct('skip');
                    if (ok && ctx.mounted) Navigator.of(ctx).pop();
                  },
          ),
        ]),
      ),
    );
  }

  /// The record's own lifecycle is stuck (spec §10: a timer that kept failing was parked). It is not
  /// frozen: its moves still work, and any move clears this.
  Widget _stuck(BuildContext context, UiWfRecord r) {
    final t = context.ui;
    return UiAlert(
      key: const ValueKey('wf-stuck'),
      tone: UiAlertTone.warning,
      heading: 'Needs attention',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
        Text(wfReadableError(r.error).isNotEmpty ? wfReadableError(r.error) : 'Something in this record’s workflow stopped.', style: context.uiText.body.copyWith(fontSize: 13, color: t.text)),
        if (_mayIntervene) ...[
          FbHint('Try again runs it now. Skip drops it, and the record stays ${(r.stateLabel ?? '').isNotEmpty ? 'in ${r.stateLabel}' : 'where it is'}. Moving the record also clears this.'),
          Wrap(spacing: t.space2, runSpacing: t.space2, children: [
            UiButton(label: 'Try again', size: UiSize.sm, onPressed: _recordBusy ? null : () => _recordAct('retry')),
            UiButton(label: 'Skip', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: _recordBusy ? null : () => _askSkipRecordTimer(r)),
          ]),
          if (_recordActError.isNotEmpty) WfNote(_recordActError),
        ] else
          const FbHint('The record can still be moved. Someone who looks after workflows has been told.'),
      ]),
    );
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
    _report();
  }

  /// Leaving the rail and the drawer closes a hover-opened peek, after a moment to cross the gap.
  void _hoverOut() {
    if (!_peek) return;
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _peek = false);
      _report();
    });
  }

  /// A tap, a click or Enter on the rail: open as a regular drawer (pinning a peek), or close.
  Future<void> _toggle() async {
    _closeTimer?.cancel();
    if (_peek) setState(() => _peek = false);
    if (_drawerOpen) return;
    setState(() => _drawerOpen = true);
    _report();
    await showUiDrawer<void>(
      context: context,
      side: _edge,
      title: widget.title,
      builder: (context) {
        _drawerRoute = ModalRoute.of(context);
        return _body(context, _edge == UiDrawerSide.bottom ? UiWorkflowPanelLayout.horizontal : UiWorkflowPanelLayout.vertical);
      },
    );
    _drawerRoute = null;
    if (!mounted) return;
    setState(() => _drawerOpen = false);
    _report();
  }

  // ── Building ────────────────────────────────────────────────────────────────────────────

  Widget _body(BuildContext context, UiWorkflowPanelLayout mode) {
    final horizontal = mode == UiWorkflowPanelLayout.horizontal;
    return ListenableBuilder(
      listenable: Listenable.merge([_record, _history, _error, _openRuns, _historyError, _earlierOpen, _stuckTick]),
      builder: (context, _) {
        final t = context.ui;
        final r = _record.value;
        if (r == null) return _error.value.isNotEmpty ? WfNote(_error.value) : const FbHint('Loading…');
        // A reload failed: what is shown may be out of date.
        final stale = _error.value.isEmpty
            ? null
            : WfNote.custom(
                child: Wrap(spacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text('${_error.value} What is shown may be out of date.', style: context.uiText.body.copyWith(fontSize: 13, color: t.text)),
                  FbLink(label: 'Try again', fontSize: 12.5, onTap: reload),
                ]),
              );
        final stuck = r.status == 'incident' ? _stuck(context, r) : null;
        Widget withStale(Widget body) => stale == null && stuck == null
            ? body
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [?stale, ?stuck, body]);
        // Compact, or no lifecycle: the state as a badge and a strip, the actions, and one flat history.
        if (r.state == null || mode == UiWorkflowPanelLayout.compact) return withStale(_compact(context, r, gap: mode == UiWorkflowPanelLayout.compact ? t.space2 : t.space3));
        final path = wfPanelPath(r, _history.value);
        final now = UiWorkflowClock.nowOf(context);
        final steps = [for (final s in path.steps) UiStep(label: s.label)];
        Widget actions() => _actions(r, emptyText: widget.emptyText);
        Widget log(List<UiWfAuditEntry> entries) => _log(context, r, entries);

        final historyNote = _historyError.value ? 'The history could not be loaded.' : _historyNote;
        return withStale(Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space3, children: [
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
                  if (state == UiStepState.active) ...[actions(), ?_runs(context, r)] else if (state == UiStepState.todo && entries.isEmpty) const FbHint('Not reached yet'),
                ];
                return parts.isEmpty ? null : Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: parts);
              },
            ),
          if (!horizontal && widget.showHistory && path.earlier.isNotEmpty) _earlier(context, r, path.earlier),
          if (!horizontal && widget.showHistory && historyNote.isNotEmpty) FbHint(historyNote),
          if (horizontal) ...[
            UiStepper(steps: steps, active: path.active, axis: Axis.horizontal, tone: UiStepperTone.success, label: widget.title),
            actions(),
            ?_runs(context, r),
            if (widget.showHistory && _historyError.value) const FbHint('The history could not be loaded.'),
            if (widget.showHistory && _history.value.isNotEmpty) ...[
              const WfSectionTitle('History'),
              log(_newestFirst.take(8).toList()),
            ],
          ],
        ]));
      },
    );
  }

  /// Said under the history when only the newest entries were read.
  String get _historyNote => _history.value.length >= wfPanelHistoryTake ? 'Showing the latest $wfPanelHistoryTake entries.' : '';

  /// What happened before the record last started over, folded away (the web `details.earlier`).
  Widget _earlier(BuildContext context, UiWfRecord r, List<UiWfAuditEntry> entries) {
    final t = context.ui;
    final open = _earlierOpen.value;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: UiInteractive(
          onTap: () => _earlierOpen.value = !open,
          toggled: open,
          semanticLabel: 'Earlier, before starting over (${entries.length})',
          excludeChildSemantics: true,
          pressScale: false,
          builder: (context, s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(t.radiusXs), boxShadow: s.focused ? t.focusRing : null),
            child: Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
              UiIcon(open ? WfIcons.arrowDown01 : WfIcons.arrowRight01, size: 12, strokeWidth: 2, color: t.textSecondary),
              Text('Earlier, before starting over (${entries.length})', style: context.uiText.body.copyWith(fontSize: 12.5, color: t.textSecondary)),
            ]),
          ),
        ),
      ),
      if (open) _log(context, r, entries),
    ]);
  }

  /// The record's workflows still running or stopped (stopped ones first), each opening its steps
  /// and, for people who may, try again, skip or cancel. Null when there are none.
  Widget? _runs(BuildContext context, UiWfRecord r) {
    const live = {'queued', 'running', 'waiting', 'incident'};
    final runs = [for (final i in r.instances) if (live.contains(i.status)) i]
      ..sort((a, b) => (b.status == 'incident' ? 1 : 0) - (a.status == 'incident' ? 1 : 0));
    if (runs.isEmpty) return null;
    final t = context.ui;
    final now = UiWorkflowClock.nowOf(context);
    final open = _openRuns.value;
    void toggle(String id) => _openRuns.value = open.contains(id) ? ({...open}..remove(id)) : {...open, id};
    // "Stopped" when every listed run stopped on an error, else "Running".
    final heading = runs.every((x) => x.status == 'incident') ? 'Stopped' : 'Running';
    return Semantics(
      container: true,
      label: heading,
      child: Padding(
        padding: EdgeInsets.only(top: t.space2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
          WfSectionTitle(heading),
          for (final run in runs)
            _RunCard(
              key: ValueKey('wf-run-${run.id}'),
              run: run,
              open: open.contains(run.id),
              subtitle: run.status == 'incident' ? (wfReadableError(run.error).isEmpty ? 'Stopped' : wfReadableError(run.error)) : 'since ${wfAgo(run.startedAt, now)}',
              onToggle: () => toggle(run.id),
              view: WfRunView(key: ValueKey('wf-run-view-${run.id}'), api: widget.api, instanceId: run.id, showHead: false, onChanged: (_) => reload()),
            ),
        ]),
      ),
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
      ?_runs(context, r),
      if (widget.showHistory)
        Padding(
          padding: EdgeInsets.only(top: t.space2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: 6, children: [
            const WfSectionTitle('History'),
            if (_history.value.isEmpty) FbHint(_historyError.value ? 'The history could not be loaded.' : 'Nothing yet.') else _log(context, r, _newestFirst),
            if (_history.value.isNotEmpty && (_historyError.value || _historyNote.isNotEmpty)) FbHint(_historyError.value ? 'The history could not be loaded.' : _historyNote),
          ]),
        ),
    ]);
  }

  /// A peeking rail's full width (a touch target), of which the gutter's 16px shows.
  static const double _railPeekWidth = 44;

  Widget _railWidget(BuildContext context) {
    if (!_isDrawer) return const SizedBox.shrink();
    final t = context.ui;
    final r = _record.value;
    final path = r == null ? (steps: <UiWfPanelStep>[], active: 0, earlier: <UiWfAuditEntry>[]) : wfPanelPath(r, _history.value);
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
    // Phones: a side rail only peeks into the page's 16px gutter (dots at its inner edge), so it neither covers the
    // content nor catches taps meant for it (the web's max-width 600px rule).
    final peek = vertical && MediaQuery.sizeOf(context).width < 600;
    final rail = MouseRegion(
      onEnter: (e) => _hoverIn(e.kind),
      onExit: (_) => _hoverOut(),
      child: UiInteractive(
        onTap: _toggle,
        semanticLabel: label,
        excludeChildSemantics: true,
        pressScale: false,
        builder: (context, s) => Container(
          width: peek ? _railPeekWidth : null,
          alignment: peek ? (edge == UiDrawerSide.left ? Alignment.centerRight : Alignment.centerLeft) : null,
          padding: peek
              ? EdgeInsets.symmetric(horizontal: t.space1, vertical: t.space3)
              : vertical ? EdgeInsets.symmetric(horizontal: t.space2, vertical: t.space3) : EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
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
      child: SafeArea(
        left: edge == UiDrawerSide.left,
        right: edge == UiDrawerSide.right,
        top: false,
        bottom: edge == UiDrawerSide.bottom,
        child: peek
            ? Transform.translate(offset: Offset((edge == UiDrawerSide.left ? -1 : 1) * (_railPeekWidth - t.space4), 0), child: rail)
            : rail,
      ),
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
      onClose: () {
        setState(() => _peek = false);
        _report();
      },
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
        // Passed states read as done (a tint of success, like the stepper's), not as not reached.
        decoration: BoxDecoration(color: here ? t.primary : (done ? t.success.withValues(alpha: 0.12) : t.surfaceHover), borderRadius: BorderRadius.circular(11)),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: context.uiText.label.copyWith(
              fontSize: 11.5,
              height: 1,
              fontWeight: here ? FontWeight.w600 : FontWeight.w500,
              color: here ? t.primaryContrast : (done ? t.success : t.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}

/// One running or stopped workflow in the panel's "Running" list: a row (status, title, why it
/// stopped or since when) that opens its steps.
class _RunCard extends StatelessWidget {
  const _RunCard({super.key, required this.run, required this.open, required this.subtitle, required this.onToggle, required this.view});
  final UiWfInstance run;
  final bool open;
  final String subtitle;
  final VoidCallback onToggle;
  final Widget view;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final stopped = run.status == 'incident';
    final edge = stopped ? Color.lerp(t.border, t.danger, 0.45)! : t.border;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: edge), borderRadius: BorderRadius.circular(t.radius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Semantics(
          expanded: open,
          child: UiInteractive(
            onTap: onToggle,
            semanticLabel: '${run.title}, ${wfRunStatusLabel(run.status)}, $subtitle',
            excludeChildSemantics: true,
            pressScale: false,
            builder: (context, s) => Container(
              color: s.hovered ? t.surfaceHover : null,
              padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
              child: Row(spacing: t.space2, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                    Row(spacing: t.space2, children: [
                      WfChip(wfRunStatusLabel(run.status), tone: wfRunStatusTone(run.status)),
                      Expanded(child: Text(run.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: t.text))),
                    ]),
                    Text(subtitle, style: context.uiText.body.copyWith(fontSize: 12, color: stopped ? t.danger : t.textMuted)),
                  ]),
                ),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: context.uiAnimate ? t.motionFast : Duration.zero,
                  child: UiIcon(WfIcons.arrowDown01, size: 14, strokeWidth: 1.8, color: t.textMuted),
                ),
              ]),
            ),
          ),
        ),
        if (open)
          Container(
            padding: EdgeInsets.fromLTRB(t.space3, t.space2, t.space3, t.space3),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
            child: view,
          ),
      ]),
    );
  }
}
