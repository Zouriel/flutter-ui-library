import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../button/button.dart';
import '../button/segmented.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../dialog/modal.dart';
import '../form_builder/renderer/form_renderer.dart';
import '../forms/text/inputs.dart';
import '../theme/theme.dart';
import 'api.dart';
import 'bits.dart';
import 'definition.dart';
import 'icons.dart';
import 'json.dart';
import 'schema.dart';

// The widgets that run workflows in an app (the web `runtime.ts`): a record's state badge, the
// record panel, the task inbox (with the decide dialog), one run's view and the audit log. There is
// no dependency injection in Flutter: each takes the engine's [UiWorkflowApi] as `api`.

String _errorText(Object e, String fallback) {
  if (e is UiWfApiError) {
    final d = e.details;
    final details = d is List ? [for (final x in d) if (x is Map && x['message'] is String) x['message'] as String] : const <String>[];
    return details.isNotEmpty ? '${e.message} ${details.join(' ')}' : e.message;
  }
  return fallback;
}

UiButtonVariant _variantOf(String? tone, {UiButtonVariant otherwise = UiButtonVariant.outline}) => switch (tone) {
  'danger' => UiButtonVariant.destructive,
  'success' || 'primary' => UiButtonVariant.primary,
  _ => otherwise,
};

TextStyle _body(BuildContext context, {double size = 13, Color? color, FontWeight? weight, double? height}) =>
    context.uiText.body.copyWith(fontSize: size, color: color ?? context.ui.text, fontWeight: weight, height: height);

/// A small uppercase heading inside a runtime widget (the web `h3`).
class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 6), child: WfSectionTitle(text));
}

// ── State badge ─────────────────────────────────────────────────────────────────────────────

/// `ui-workflow-state-badge`: a record's lifecycle state as a small coloured chip.
class UiWorkflowStateBadge extends StatelessWidget {
  const UiWorkflowStateBadge({super.key, required this.label, this.tone = 'neutral'});
  final String label;

  /// `neutral`, `info`/`primary`, `success`, `warning` or `danger`.
  final String? tone;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final c = tone == null || tone == 'neutral' ? t.textSecondary : wfToneColor(t, tone);
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(11)),
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            Text(label, maxLines: 1, style: context.uiText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: c, height: 1)),
          ]),
        ),
      ),
    );
  }
}

// ── Task decision (shared by the inbox and the record panel) ─────────────────────────────────

class _DecideState extends ChangeNotifier {
  String comment = '';
  String delegateTo = '';
  bool delegateOpen = false;
  UiJson answers = {};
  bool busy = false;
  String error = '';
  void set(VoidCallback f) {
    f();
    notifyListeners();
  }
}

/// The decide dialog (the web `ui-wf-decide`): instructions, the task's form, a comment, and its
/// buttons. Completes with the task as the engine returned it after a decision or a hand-over, or
/// null when closed.
Future<UiWfTask?> showWfDecideDialog(BuildContext context, {required UiWfTask task, required UiWorkflowApi api}) {
  final st = _DecideState();
  String outcomeLabel(String key) => task.outcomes.where((o) => o.key == key).firstOrNull?.label.toLowerCase() ?? key;

  Future<void> decide(BuildContext ctx, String outcome) async {
    st.set(() {
      st.busy = true;
      st.error = '';
    });
    try {
      final res = await api.decide(task.id, outcome, comment: st.comment.isEmpty ? null : st.comment, data: st.answers);
      if (ctx.mounted) Navigator.of(ctx).pop(res);
    } catch (e) {
      st.set(() => st.error = _errorText(e, 'The decision could not be saved.'));
    } finally {
      st.set(() => st.busy = false);
    }
  }

  Future<void> delegate(BuildContext ctx) async {
    st.set(() => st.busy = true);
    try {
      final res = await api.delegate(task.id, st.delegateTo);
      if (ctx.mounted) Navigator.of(ctx).pop(res);
    } catch (e) {
      st.set(() => st.error = _errorText(e, 'Could not hand it over.'));
    } finally {
      st.set(() => st.busy = false);
    }
  }

  final future = showUiModal<UiWfTask>(
    context: context,
    title: task.title,
    size: UiModalSize.md,
    builder: (ctx) => ListenableBuilder(
      listenable: st,
      builder: (ctx, _) {
        final t = ctx.ui;
        final rc = task.requireComment;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
          if (task.entityTitle != null) Text(task.entityTitle!, style: _body(ctx, size: 14, weight: FontWeight.w600)),
          if (task.instructions != null) Text(task.instructions!, style: _body(ctx, size: 14, height: 1.5)),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Due ${wfDateTime(task.dueAt)} (${wfAgo(task.dueAt)})'),
              if (task.overdue) ...[const TextSpan(text: ' · '), TextSpan(text: 'overdue', style: TextStyle(color: t.danger, fontWeight: FontWeight.w700))],
            ]),
            style: _body(ctx, size: 12.5, color: t.textMuted),
          ),
          if (task.decisions.isNotEmpty)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final d in task.decisions)
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: d.name ?? d.userId, style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: ' chose ${outcomeLabel(d.outcome)}${d.comment != null ? ': “${d.comment}”' : ''}'),
                  ]),
                  style: _body(ctx),
                ),
            ]),
          if (task.form != null)
            UiFormRenderer(definition: task.form!, showActions: false, showTitle: false, onValueChanged: (v) => st.answers = v),
          FbSetting(
            label: 'Comment${rc == 'always' ? ' (required)' : rc == 'reject' ? ' (required to reject)' : ''}',
            child: UiTextarea(value: st.comment, rows: 2, autosize: true, semanticLabel: 'Comment', onChanged: (v) => st.comment = v),
          ),
          if (task.allowDelegation) ...[
            Align(alignment: AlignmentDirectional.centerStart, child: FbLink(label: 'Hand it to someone else', fontSize: 12.5, onTap: () => st.set(() => st.delegateOpen = !st.delegateOpen))),
            if (st.delegateOpen)
              Row(spacing: t.space2, children: [
                Expanded(child: UiInput(size: UiSize.sm, value: st.delegateTo, placeholder: 'Their user id', semanticLabel: 'User id', onChanged: (v) => st.set(() => st.delegateTo = v))),
                UiButton(label: 'Hand over', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: st.busy || st.delegateTo.isEmpty ? null : () => delegate(ctx)),
              ]),
          ],
          if (st.error.isNotEmpty) WfNote(st.error),
        ]);
      },
    ),
    footerBuilder: (ctx) => ListenableBuilder(
      listenable: st,
      builder: (ctx, _) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: ctx.ui.space2,
        runSpacing: ctx.ui.space2,
        children: [
          UiButton(label: 'Close', variant: UiButtonVariant.ghost, onPressed: () => Navigator.of(ctx).pop()),
          Wrap(spacing: ctx.ui.space2, runSpacing: ctx.ui.space2, children: [
            for (final o in task.outcomes)
              UiButton(label: o.label, variant: _variantOf(o.tone), onPressed: st.busy || !task.canDecide ? null : () => decide(ctx, o.key)),
          ]),
        ],
      ),
    ),
  );
  return future.whenComplete(st.dispose);
}

// ── Record panel ────────────────────────────────────────────────────────────────────────────

/// `ui-workflow-record-panel`: drop onto a record's page: its lifecycle state, the moves the
/// signed-in person may make (with their forms), open tasks, buttons for manual workflows, and the
/// history of what happened.
class UiWorkflowRecordPanel extends StatefulWidget {
  const UiWorkflowRecordPanel({super.key, required this.api, required this.entity, required this.entityId, this.showHistory = true, this.onChanged});

  /// The engine. Nothing loads while it is null.
  final UiWorkflowApi? api;
  final String entity;
  final String entityId;
  final bool showHistory;

  /// After the record changed through the panel (so the page can reload its own data).
  final ValueChanged<UiWfRecord>? onChanged;

  @override
  State<UiWorkflowRecordPanel> createState() => UiWorkflowRecordPanelState();
}

class UiWorkflowRecordPanelState extends State<UiWorkflowRecordPanel> {
  UiWfRecord? _record;
  List<UiWfAuditEntry> _history = const [];
  bool _busy = false;
  String _error = '';

  UiWfRecord? get record => _record;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(UiWorkflowRecordPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.api != widget.api || old.entity != widget.entity || old.entityId != widget.entityId) reload();
  }

  /// Reloads the panel (e.g. after the page changed the record itself).
  Future<void> reload() async {
    final api = widget.api;
    if (api == null) return;
    try {
      final r = await api.record(widget.entity, widget.entityId);
      if (!mounted) return;
      setState(() {
        _record = r;
        _error = '';
      });
      await _loadHistory(api);
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e, 'Could not load the record’s workflow.'));
    }
  }

  Future<void> _loadHistory(UiWorkflowApi api) async {
    if (!widget.showHistory) return;
    try {
      final h = await api.recordHistory(widget.entity, widget.entityId, take: 50);
      if (mounted) setState(() => _history = h);
    } catch (_) {
      if (mounted) setState(() => _history = const []);
    }
  }

  bool _passed(UiWfRecord r, String key) {
    final i = r.states.indexWhere((s) => s.key == key);
    final here = r.states.indexWhere((s) => s.key == r.state);
    return i >= 0 && here >= 0 && i < here;
  }

  void _start(UiWfTransitionOption t) {
    if (t.form == null && t.confirm == null) {
      _apply(t.key, const {}, null);
      return;
    }
    _confirm(t, manual: false);
  }

  void _startManual(UiWfManualOption m) {
    if (m.form == null) {
      _runManual(m.key, const {}, null);
      return;
    }
    _confirm(UiWfTransitionOption(key: m.key, label: m.label, tone: 'primary', form: m.form), manual: true);
  }

  /// The confirmation (or form) before a move or a manual start.
  void _confirm(UiWfTransitionOption p, {required bool manual}) {
    final err = ValueNotifier<String>('');
    final busy = ValueNotifier<bool>(false);
    var input = <String, Object?>{};
    showUiModal<void>(
      context: context,
      title: p.label,
      size: UiModalSize.md,
      builder: (ctx) => ValueListenableBuilder(
        valueListenable: err,
        builder: (ctx, e, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: ctx.ui.space2, children: [
          if (p.confirm != null) Text(p.confirm!, style: _body(ctx, size: 14)),
          if (p.form != null)
            UiFormRenderer(definition: p.form!, showActions: false, showTitle: false, onValueChanged: (v) => input = v)
          else if (p.confirm == null)
            Text('Move this record to “${p.toLabel}”?', style: _body(ctx, size: 14)),
          if (e.isNotEmpty) WfNote(e),
        ]),
      ),
      footerBuilder: (ctx) => ValueListenableBuilder(
        valueListenable: busy,
        builder: (ctx, b, _) => Row(children: [
          UiButton(label: 'Cancel', variant: UiButtonVariant.ghost, onPressed: () => Navigator.of(ctx).pop()),
          const Spacer(),
          UiButton(
            label: p.label,
            variant: p.tone == 'danger' ? UiButtonVariant.destructive : UiButtonVariant.primary,
            onPressed: b
                ? null
                : () async {
                    busy.value = true;
                    final ok = manual ? await _runManual(p.key, input, err) : await _apply(p.key, input, err);
                    busy.value = false;
                    if (ok && ctx.mounted) Navigator.of(ctx).pop();
                  },
          ),
        ]),
      ),
    ).whenComplete(() {
      err.dispose();
      busy.dispose();
    });
  }

  Future<bool> _apply(String key, UiJson input, ValueNotifier<String>? err) async {
    final api = widget.api;
    if (api == null) return false;
    setState(() => _busy = true);
    try {
      final r = await api.applyTransition(widget.entity, widget.entityId, key, input: input);
      if (!mounted) return true;
      setState(() => _record = r);
      widget.onChanged?.call(r);
      await _loadHistory(api);
      return true;
    } catch (e) {
      final msg = _errorText(e, 'That did not work.');
      if (err != null) {
        err.value = msg;
      } else if (mounted) {
        setState(() => _error = msg);
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _runManual(String key, UiJson input, ValueNotifier<String>? err) async {
    final api = widget.api;
    if (api == null) return false;
    setState(() => _busy = true);
    try {
      await api.startManual(key, widget.entity, widget.entityId, input: input);
      await reload();
      return true;
    } catch (e) {
      final msg = _errorText(e, 'That did not work.');
      if (err != null) {
        err.value = msg;
      } else if (mounted) {
        setState(() => _error = msg);
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openTask(UiWfTask t) async {
    final api = widget.api;
    if (api == null) return;
    final res = await showWfDecideDialog(context, task: t, api: api);
    if (res != null) await reload();
  }

  String _describeHistory(UiWfAuditEntry h) {
    UiJson parse(String? s) {
      if (s == null) return const {};
      try {
        return wfMap(jsonDecode(s));
      } catch (_) {
        return const {};
      }
    }

    final data = parse(h.data), before = parse(h.before), after = parse(h.after);
    String label(Object? k) => _record?.states.where((s) => s.key == k).firstOrNull?.label ?? (k == null ? '' : jsString(k));
    String s(Object? v) => v == null ? '' : jsString(v);
    switch ('${h.category}.${h.action}') {
      case 'lifecycle.created':
        return 'Started in ${label(after['state'])}';
      case 'lifecycle.transitioned':
        return '${s(data['label'] ?? data['transition'] ?? 'Moved')}: ${label(before['state'])} $wfArrow ${label(after['state'])}';
      case 'lifecycle.autoTransitioned':
        return 'Moved automatically: ${label(before['state'])} $wfArrow ${label(after['state'])}';
      case 'lifecycle.forced':
        return 'Moved by an admin to ${label(after['state'])}: ${s(data['reason'])}';
      case 'lifecycle.writeRefused':
        return 'A direct change to the state was refused';
      case 'task.decided':
        final c = data['comment'];
        return 'Decided: ${s(data['outcome'])}${c != null && c != '' ? ' (“${s(c)}”)' : ''}';
      case 'task.created':
        return 'Task created: ${s(data['title'])}';
      default:
        return '${h.category} ${h.action}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final r = _record;
    if (r == null) {
      return _error.isNotEmpty ? WfNote(_error) : const FbHint('Loading…');
    }
    return DefaultTextStyle.merge(
      style: _body(context, size: 13.5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space3, children: [
        Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (r.state != null) ...[
            UiWorkflowStateBadge(label: r.stateLabel ?? r.state!, tone: r.stateTone),
            Text('since ${wfAgo(r.stateEnteredAt)}', style: _body(context, size: 12, color: t.textMuted)),
            if (r.status == 'outOfSync') const WfChip('Out of sync', tone: 'warning'),
          ] else
            const FbHint('No lifecycle for this record type.'),
        ]),
        if (r.states.length > 1)
          Semantics(
            container: true,
            label: 'Lifecycle',
            child: Wrap(spacing: 4, runSpacing: 4, children: [
              for (final s in r.states)
                Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(color: s.key == r.state ? t.primary : t.surfaceHover, borderRadius: BorderRadius.circular(11)),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      s.label,
                      style: context.uiText.label.copyWith(
                        fontSize: 11.5,
                        height: 1,
                        fontWeight: s.key == r.state ? FontWeight.w600 : FontWeight.w500,
                        color: s.key == r.state ? t.primaryContrast : (_passed(r, s.key) ? t.textSecondary : t.textMuted),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        if (r.transitions.isNotEmpty || r.manual.isNotEmpty)
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final tr in r.transitions) UiButton(label: tr.label, size: UiSize.sm, variant: _variantOf(tr.tone), onPressed: _busy ? null : () => _start(tr)),
            for (final m in r.manual) UiButton(label: m.label, size: UiSize.sm, variant: UiButtonVariant.ghost, onPressed: _busy ? null : () => _startManual(m)),
          ]),
        if (r.tasks.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            const _Heading('Waiting for'),
            for (final task in r.tasks)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: UiInteractive(
                  onTap: () => _openTask(task),
                  enabled: task.canDecide,
                  semanticLabel: '${task.title}, ${task.assigneeNames.join(', ')}, due ${wfAgo(task.dueAt)}${task.canDecide ? ', your turn' : ''}',
                  excludeChildSemantics: true,
                  pressScale: false,
                  builder: (context, s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: t.surface,
                      border: Border.all(color: s.hovered && !s.disabled ? t.primary : t.border),
                      borderRadius: BorderRadius.circular(t.radius),
                      boxShadow: s.focused ? t.focusRing : null,
                    ),
                    child: Row(spacing: 8, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
                          Text(task.title, style: _body(context, size: 13.5, weight: FontWeight.w600)),
                          Text('${task.assigneeNames.join(', ')} · due ${wfAgo(task.dueAt)}', style: _body(context, size: 12, color: t.textMuted)),
                        ]),
                      ),
                      if (task.canDecide) const WfChip('Your turn', tone: 'primary'),
                    ]),
                  ),
                ),
              ),
          ]),
        if (widget.showHistory)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            const _Heading('History'),
            if (_history.isEmpty) const FbHint('Nothing yet.'),
            for (final h in _history)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
                decoration: BoxDecoration(border: Border(left: BorderSide(color: t.border, width: 2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  WfArrowText(_describeHistory(h), style: _body(context)),
                  Text('${h.actorName ?? h.actorType} · ${wfAgo(h.at)}', style: _body(context, size: 11.5, color: t.textMuted)),
                ]),
              ),
          ]),
        if (_error.isNotEmpty) WfNote(_error),
      ]),
    );
  }
}

// ── Task inbox ──────────────────────────────────────────────────────────────────────────────

/// `ui-workflow-tasks`: the signed-in person's approvals and tasks: due first, overdue marked.
class UiWorkflowTasks extends StatefulWidget {
  const UiWorkflowTasks({super.key, required this.api, this.scope = 'mine', this.pageSize = 25, this.onDecided});
  final UiWorkflowApi? api;

  /// `mine` (the signed-in person's) or `all` (needs admin rights).
  final String scope;
  final int pageSize;

  /// After a decision, so the host can refresh related views.
  final ValueChanged<UiWfTask>? onDecided;

  @override
  State<UiWorkflowTasks> createState() => UiWorkflowTasksState();
}

class UiWorkflowTasksState extends State<UiWorkflowTasks> {
  String _status = 'open';
  List<UiWfTask> _tasks = const [];
  int _total = 0;
  String _error = '';
  late int _take = widget.pageSize;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(UiWorkflowTasks oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.api != widget.api || old.scope != widget.scope || old.pageSize != widget.pageSize) {
      _take = widget.pageSize;
      reload();
    }
  }

  Future<void> reload() async {
    final api = widget.api;
    if (api == null) return;
    try {
      final page = await api.tasks(UiWfTaskQuery(scope: widget.scope, status: _status == 'open' ? const ['open'] : const ['completed', 'timedOut', 'cancelled'], take: _take));
      if (!mounted) return;
      setState(() {
        _tasks = page.items;
        _total = page.total;
        _error = '';
      });
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e, 'Could not load tasks.'));
    }
  }

  String _outcomeLabel(UiWfTask t) {
    if (t.status == 'timedOut') return 'Out of time';
    if (t.status == 'cancelled') return 'Cancelled';
    return t.outcomes.where((o) => o.key == t.outcome).firstOrNull?.label ?? t.outcome ?? 'Done';
  }

  Future<void> _open(UiWfTask t) async {
    final api = widget.api;
    if (api == null) return;
    final res = await showWfDecideDialog(context, task: t, api: api);
    if (res != null) {
      widget.onDecided?.call(res);
      await reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
      Row(children: [
        UiSegmented<String>(
          label: 'Tasks',
          size: UiSize.sm,
          value: _status,
          options: const [UiSegmentedOption(value: 'open', label: 'Open'), UiSegmentedOption(value: 'done', label: 'Done')],
          onChanged: (v) {
            setState(() => _status = v);
            reload();
          },
        ),
        const Spacer(),
        FbIconButton(icon: WfIcons.refresh, label: 'Refresh', onPressed: reload),
      ]),
      if (_error.isNotEmpty) WfNote(_error),
      if (_tasks.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: t.space6),
          child: Text(_status == 'open' ? 'Nothing is waiting for you.' : 'No finished tasks yet.', textAlign: TextAlign.center, style: _body(context, color: t.textMuted)),
        ),
      for (final task in _tasks) _TaskRow(task: task, outcome: _outcomeLabel(task), onTap: () => _open(task)),
      if (_total > _tasks.length)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: UiButton(
            label: 'Show more',
            size: UiSize.sm,
            variant: UiButtonVariant.ghost,
            onPressed: () {
              _take += widget.pageSize;
              reload();
            },
          ),
        ),
    ]);
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.outcome, required this.onTap});
  final UiWfTask task;
  final String outcome;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final open = task.status == 'open';
    final due = '${task.overdue ? 'Overdue' : 'Due'} ${wfAgo(task.dueAt)}';
    return UiInteractive(
      onTap: onTap,
      semanticLabel: '${task.title}, ${task.entityTitle ?? task.definitionKey}, ${open ? due : outcome}',
      excludeChildSemantics: true,
      pressScale: false,
      builder: (context, s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: s.hovered ? t.primary : t.border),
          borderRadius: BorderRadius.circular(t.radius),
          boxShadow: s.focused ? t.focusRing : null,
        ),
        // Overdue: a red bar down the left edge (the web `border-left: 3px`).
        foregroundDecoration: task.overdue ? BoxDecoration(border: Border(left: BorderSide(color: t.danger, width: 3))) : null,
        child: Row(spacing: 10, children: [
          WfIconTile(task.kind == 'approval' ? WfIcons.checkmarkCircle02 : WfIcons.inbox, color: t.primary),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task.title, style: _body(context, size: 13.5, weight: FontWeight.w600)),
              Text(task.entityTitle ?? task.definitionKey, maxLines: 1, overflow: TextOverflow.ellipsis, style: _body(context, size: 12, color: t.textMuted)),
            ]),
          ),
          if (open)
            Text(due, style: _body(context, size: 12, color: task.overdue ? t.danger : t.textSecondary, weight: task.overdue ? FontWeight.w600 : null))
          else
            WfChip(outcome, tone: task.outcome == 'rejected' ? 'danger' : task.status == 'timedOut' ? 'warning' : 'success'),
        ]),
      ),
    );
  }
}

// ── Run view ────────────────────────────────────────────────────────────────────────────────

class _RunRow {
  const _RunRow(this.id, this.name, this.depth, this.status, this.statusText, this.detail, this.icon);
  final String id;
  final String name;
  final int depth;
  final String status;
  final String statusText;
  final String detail;
  final UiIconData icon;
}

/// `ui-workflow-run`: one run drawn over its workflow: each step with what happened (done, waiting,
/// failed, skipped), the paths not taken greyed out, and an admin's retry/skip/cancel. When several
/// paths stopped, each can be retried or skipped on its own.
class UiWorkflowRun extends StatefulWidget {
  const UiWorkflowRun({super.key, required this.api, required this.instanceId, this.canIntervene = false, this.onChanged});
  final UiWorkflowApi? api;
  final String instanceId;

  /// Show retry, skip and cancel (needs the intervention permission on the server).
  final bool canIntervene;
  final ValueChanged<UiWfInstance>? onChanged;

  @override
  State<UiWorkflowRun> createState() => UiWorkflowRunState();
}

class UiWorkflowRunState extends State<UiWorkflowRun> {
  UiWfInstance? _run;
  UiWorkflowDefinition? _def;
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(UiWorkflowRun oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.api != widget.api || old.instanceId != widget.instanceId) reload();
  }

  Future<void> reload() async {
    final api = widget.api;
    if (api == null) return;
    try {
      final results = await Future.wait([api.instance(widget.instanceId), api.instanceDefinition(widget.instanceId)]);
      if (!mounted) return;
      setState(() {
        _run = results[0] as UiWfInstance;
        _def = results[1] as UiWorkflowDefinition;
        _error = '';
      });
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e, 'Could not load the run.'));
    }
  }

  /// The paths stopped by a failure: one per token waiting on an incident, named after its step.
  List<({String token, String name})> get _incidents {
    final r = _run;
    final steps = _def != null ? indexSteps(_def!) : null;
    return [
      for (final tk in r?.tokens ?? const <UiWfRunToken>[])
        if (tk.waiting == 'incident')
          (token: tk.id, name: _incidentName(steps, tk)),
    ];
  }

  static String _incidentName(Map<String, UiWfStepLocation>? steps, UiWfRunToken tk) {
    final id = tk.stepId;
    final step = id == null || steps == null ? null : steps[id]?.step;
    return step != null ? stepName(step) : (tk.stepId ?? tk.id);
  }

  List<_RunRow> get _rows {
    final r = _run;
    final def = _def;
    if (r == null || def == null) return const [];
    final byNode = <String, List<UiWfStepRun>>{};
    for (final s in r.steps ?? const <UiWfStepRun>[]) {
      (byNode[s.nodeId] ??= []).add(s);
    }
    final rootList = r.kind == 'run' && (r.reason ?? '').isNotEmpty ? r.reason! : 'root';
    const texts = {'completed': 'Done', 'waiting': 'Waiting', 'running': 'Running', 'failed': 'Failed', 'skipped': 'Skipped', 'cancelled': 'Cancelled', 'notRun': ''};
    return [
      for (final loc in indexSteps(def).values)
        if (loc.path.first == rootList)
          () {
            final runs = byNode[loc.step.id] ?? const <UiWfStepRun>[];
            final last = runs.lastOrNull;
            final status = last?.status ?? 'notRun';
            return _RunRow(
              loc.step.id,
              stepName(loc.step),
              loc.path.length - 1,
              status,
              texts[status] ?? status,
              last?.error ?? (runs.length > 1 ? '${runs.length} attempts' : ''),
              status == 'completed' ? WfIcons.tick02 : (status == 'failed' ? WfIcons.cancel01 : wfStepIcon(loc.step.type)),
            );
          }(),
    ];
  }

  static String _statusLabel(String s) =>
      const {'queued': 'Queued', 'running': 'Running', 'waiting': 'Waiting', 'incident': 'Stopped', 'completed': 'Finished', 'failed': 'Failed', 'cancelled': 'Cancelled', 'active': 'Active', 'outOfSync': 'Out of sync'}[s] ??
      s;

  static String _statusTone(String s) => s == 'completed'
      ? 'success'
      : (s == 'incident' || s == 'failed')
      ? 'danger'
      : (s == 'cancelled' || s == 'outOfSync')
      ? 'warning'
      : 'info';

  Future<void> _act(String kind, [String? target]) async {
    final api = widget.api;
    final r = _run;
    if (api == null || r == null) return;
    setState(() => _busy = true);
    try {
      final next = kind == 'retry'
          ? await api.retry(r.id, target: target)
          : kind == 'skip'
          ? await api.skip(r.id, target: target)
          : await api.cancel(r.id, reason: 'Cancelled from the run view');
      if (!mounted) return;
      setState(() => _run = next);
      widget.onChanged?.call(next);
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e, 'That did not work.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final r = _run;
    if (r == null) return _error.isNotEmpty ? WfNote(_error) : const FbHint('Loading…');
    final incidents = _incidents;
    UiButton btn(String label, String kind, {UiButtonVariant variant = UiButtonVariant.primary, String? target}) =>
        UiButton(label: label, size: UiSize.sm, variant: variant, onPressed: _busy ? null : () => _act(kind, target));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(r.title, style: _body(context, size: 14, weight: FontWeight.w700)),
          Text('v${r.version}', style: context.uiText.code.copyWith(fontSize: 11.5, color: t.textMuted)),
          WfChip(_statusLabel(r.status), tone: _statusTone(r.status)),
        ]),
        Text(
          '${r.entityTitle ?? r.entityId ?? ''} · started ${wfAgo(r.startedAt)}${r.initiatorName != null ? ' by ${r.initiatorName}' : ''}',
          style: _body(context, size: 12, color: t.textMuted),
        ),
      ]),
      if (r.status == 'incident')
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: t.danger.withValues(alpha: 0.10),
              border: Border.all(color: t.danger.withValues(alpha: 0.30)),
              borderRadius: BorderRadius.circular(t.radius),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 6, children: [
              Text.rich(TextSpan(children: [const TextSpan(text: 'Stopped: ', style: TextStyle(fontWeight: FontWeight.w700)), TextSpan(text: r.error ?? '')]), style: _body(context)),
              if (widget.canIntervene && incidents.length > 1) ...[
                // Several paths stopped: each can be retried or skipped on its own.
                for (final i in incidents)
                  Row(spacing: t.space2, children: [
                    Expanded(child: Text(i.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _body(context))),
                    btn('Try again', 'retry', target: i.token),
                    btn('Skip', 'skip', variant: UiButtonVariant.outline, target: i.token),
                  ]),
                Align(alignment: AlignmentDirectional.centerStart, child: btn('Cancel the run', 'cancel', variant: UiButtonVariant.ghost)),
              ] else if (widget.canIntervene)
                Wrap(spacing: t.space2, runSpacing: t.space2, children: [
                  btn('Try again', 'retry'),
                  btn('Skip the step', 'skip', variant: UiButtonVariant.outline),
                  btn('Cancel the run', 'cancel', variant: UiButtonVariant.ghost),
                ]),
            ]),
          ),
        )
      else if (widget.canIntervene && (r.status == 'waiting' || r.status == 'running' || r.status == 'queued'))
        Align(alignment: AlignmentDirectional.centerStart, child: btn('Cancel the run', 'cancel', variant: UiButtonVariant.ghost)),
      if (_error.isNotEmpty) WfNote(_error),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final s in _rows) _RunStepRow(row: s),
      ]),
      if (r.tasks?.isNotEmpty ?? false)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
          const WfSectionTitle('Tasks'),
          for (final task in r.tasks!)
            Text(
              '•  ${task.title} — ${task.status == 'open' ? 'waiting for ${task.assigneeNames.join(', ')}' : (task.outcome ?? task.status)}',
              style: _body(context),
            ),
        ]),
    ]);
  }
}

class _RunStepRow extends StatelessWidget {
  const _RunStepRow({required this.row});
  final _RunRow row;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final c = switch (row.status) {
      'completed' => t.success,
      'waiting' || 'running' => t.primary,
      'failed' => t.danger,
      'skipped' || 'cancelled' => t.warning,
      _ => t.textMuted,
    };
    final edge = switch (row.status) { 'completed' || 'waiting' || 'running' || 'failed' => c, _ => t.border };
    return Opacity(
      opacity: row.status == 'notRun' ? 0.45 : 1,
      child: Container(
        padding: EdgeInsets.fromLTRB(8 + row.depth * 16.0, 5, 8, 5),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: edge, width: 2))),
        child: Semantics(
          label: '${row.name}${row.statusText.isNotEmpty ? ', ${row.statusText}' : ', not run'}${row.detail.isNotEmpty ? ', ${row.detail}' : ''}',
          child: ExcludeSemantics(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2, children: [
              Row(spacing: 8, children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: UiIcon(row.icon, size: 13, strokeWidth: 1.9, color: c),
                ),
                Expanded(child: Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _body(context, weight: FontWeight.w500))),
                Text(row.statusText, style: _body(context, size: 11.5, color: t.textSecondary)),
              ]),
              if (row.detail.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 28), child: Text(row.detail, style: _body(context, size: 12, color: t.textMuted))),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Audit log ───────────────────────────────────────────────────────────────────────────────

const List<String> _auditCategories = ['definition', 'instance', 'step', 'lifecycle', 'task', 'trigger', 'settings', 'audit'];

/// `ui-workflow-audit`: the tamper-evident audit log: filter by record, run or kind, see
/// before/after values, export, and check the hash chain.
///
/// The web version downloads the export in the browser; here the bytes go to [onExport], so the
/// app can save or share them (path_provider, share_plus…).
class UiWorkflowAudit extends StatefulWidget {
  const UiWorkflowAudit({super.key, required this.api, this.entity, this.entityId, this.instanceId, this.pageSize = 50, this.onExport});
  final UiWorkflowApi? api;

  /// Show only one record's entries.
  final String? entity;
  final String? entityId;

  /// Show only one run's entries.
  final String? instanceId;
  final int pageSize;

  /// Gets the exported file (`csv`); the CSV button shows only when this is set.
  final void Function(Uint8List bytes, String format)? onExport;

  @override
  State<UiWorkflowAudit> createState() => UiWorkflowAuditState();
}

class UiWorkflowAuditState extends State<UiWorkflowAudit> {
  String _category = '';
  String _recordFilter = '';
  List<UiWfAuditEntry> _entries = const [];
  bool _hasMore = false;
  final Set<int> _open = {};
  UiWfAuditVerification? _verification;
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    load(false);
  }

  @override
  void didUpdateWidget(UiWorkflowAudit oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.api != widget.api || old.entity != widget.entity || old.entityId != widget.entityId || old.instanceId != widget.instanceId) load(false);
  }

  UiWfAuditQuery _query({int? before, String? format}) => UiWfAuditQuery(
    category: _category.isEmpty ? null : _category,
    entity: widget.entity,
    entityId: widget.entityId ?? (_recordFilter.isEmpty ? null : _recordFilter),
    instanceId: widget.instanceId,
    take: widget.pageSize,
    before: before,
    format: format,
  );

  /// Loads the newest entries, or the next older page.
  Future<void> load(bool older) async {
    final api = widget.api;
    if (api == null) return;
    try {
      final before = older && _entries.isNotEmpty ? _entries.last.seq : null;
      final page = await api.audit(_query(before: before));
      if (!mounted) return;
      setState(() {
        _entries = older ? [..._entries, ...page] : page;
        _hasMore = page.length == widget.pageSize;
        _error = '';
      });
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e, 'Could not load the audit log.'));
    }
  }

  Future<void> _verify() async {
    final api = widget.api;
    if (api == null) return;
    setState(() => _busy = true);
    try {
      final v = await api.verifyAudit();
      if (mounted) setState(() => _verification = v);
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e, 'Could not check the chain.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(String format) async {
    final api = widget.api;
    if (api == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await api.exportAudit(_query(format: format));
      widget.onExport?.call(bytes, format);
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e, 'The export failed.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final v = _verification;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
      Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 160,
          child: WfSelect(
            label: 'Kind',
            value: _category.isEmpty ? 'all' : _category,
            options: [(value: 'all', label: 'Everything'), for (final c in _auditCategories) (value: c, label: c)],
            onChanged: (c) {
              setState(() => _category = c == 'all' ? '' : c);
              load(false);
            },
          ),
        ),
        if (widget.entityId == null)
          SizedBox(
            width: 140,
            child: UiInput(
              size: UiSize.sm,
              value: _recordFilter,
              placeholder: 'Record id',
              semanticLabel: 'Record id',
              onChanged: (s) {
                setState(() => _recordFilter = s);
                load(false);
              },
            ),
          ),
        UiButton(label: 'Check integrity', size: UiSize.sm, variant: UiButtonVariant.ghost, icon: const UiIcon(WfIcons.securityCheck, size: 14), onPressed: _busy ? null : _verify),
        if (widget.onExport != null)
          UiButton(label: 'CSV', size: UiSize.sm, variant: UiButtonVariant.ghost, icon: const UiIcon(WfIcons.download04, size: 14), onPressed: _busy ? null : () => _export('csv')),
      ]),
      if (v != null)
        Semantics(
          liveRegion: true,
          child: v.valid
              ? Text('The chain is intact: ${v.checked} entries checked.', style: _body(context, size: 12.5, color: t.success))
              : WfNote('The chain is broken at entry ${v.brokenAtSeq}: ${v.problem ?? ''}', alert: false),
        ),
      if (_error.isNotEmpty) WfNote(_error),
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_entries.isEmpty)
            Padding(padding: EdgeInsets.all(t.space6), child: Text('No entries.', textAlign: TextAlign.center, style: _body(context, color: t.textMuted))),
          for (var i = 0; i < _entries.length; i++) ...[
            if (i > 0) Container(height: 1, color: t.borderSubtle),
            _AuditRow(
              entry: _entries[i],
              open: _open.contains(_entries[i].seq),
              onToggle: () => setState(() => _open.contains(_entries[i].seq) ? _open.remove(_entries[i].seq) : _open.add(_entries[i].seq)),
            ),
          ],
        ]),
      ),
      if (_hasMore) Align(alignment: AlignmentDirectional.centerStart, child: UiButton(label: 'Older entries', size: UiSize.sm, variant: UiButtonVariant.ghost, onPressed: () => load(true))),
    ]);
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry, required this.open, required this.onToggle});
  final UiWfAuditEntry entry;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final e = entry;
    final catColor = switch (e.category) {
      'lifecycle' => t.primary,
      'task' => t.success,
      'settings' || 'definition' => t.warning,
      _ => t.textSecondary,
    };
    final who = e.actorName ?? e.actorId ?? e.actorType;
    final code = context.uiText.code.copyWith(fontSize: 11.5, color: t.text);
    Widget pair(String k, Widget v) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 10, children: [
        SizedBox(width: 70, child: Text(k, style: _body(context, size: 12, color: t.textMuted))),
        Expanded(child: v),
      ]),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      UiInteractive(
        onTap: onToggle,
        semanticLabel: 'Entry ${e.seq}: ${e.category} ${e.action}, $who, ${wfDateTime(e.at)}',
        toggled: open,
        excludeChildSemantics: true,
        pressScale: false,
        builder: (context, s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: s.hovered ? t.surfaceHover : t.surface, boxShadow: s.focused ? t.focusRing : null),
          child: LayoutBuilder(builder: (context, box) {
            final narrow = box.maxWidth < 420;
            final what = Text.rich(
              TextSpan(children: [
                TextSpan(text: e.category.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.33, color: catColor)),
                TextSpan(text: ' ${e.action}'),
              ]),
              style: _body(context),
            );
            final whoText = Text(who, maxLines: 1, overflow: TextOverflow.ellipsis, style: _body(context, color: t.textSecondary));
            final at = Text(wfDateTime(e.at), style: _body(context, size: 12, color: t.textMuted));
            final seq = SizedBox(width: narrow ? 48 : 56, child: Text('#${e.seq}', style: context.uiText.code.copyWith(fontSize: 11.5, color: t.textMuted)));
            if (narrow) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
                seq,
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [what, whoText, at])),
              ]);
            }
            return Row(spacing: 8, children: [seq, Expanded(flex: 5, child: what), Expanded(flex: 3, child: whoText), at]);
          }),
        ),
      ),
      if (open)
        Container(
          color: t.bg,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            pair('Subject', Text('${e.subjectType} ${e.subjectId}${e.entity != null ? ' (${e.entity} ${e.entityId})' : ''}', style: _body(context, size: 12))),
            if (e.before != null) pair('Before', Text(e.before!, style: code)),
            if (e.after != null) pair('After', Text(e.after!, style: code)),
            if (e.data != null) pair('Details', Text(e.data!, style: code)),
            pair('Hash', Text(e.hash, style: code.copyWith(color: t.textMuted))),
          ]),
        ),
    ]);
  }
}
