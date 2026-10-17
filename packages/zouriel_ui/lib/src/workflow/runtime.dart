import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../button/button.dart';
import '../button/segmented.dart';
import '../combobox/combobox.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../dialog/modal.dart';
import '../form_builder/renderer/form_renderer.dart';
import '../forms/choice/checkbox.dart';
import '../forms/text/inputs.dart';
import '../theme/theme.dart';
import 'api.dart';
import 'bits.dart';
import 'clock.dart';
import 'definition.dart';
import 'history.dart';
import 'icons.dart';
import 'json.dart';
import 'schema.dart';

// The widgets that run workflows in an app (the web `runtime.ts`): a record's state badge, the
// record actions (used by the workflow panel), the task inbox (with the decide dialog), one run's
// view and the audit log. There is
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
    // Info has the theme's own colour (themes without one give it the primary's); the rest by tone.
    final c = tone == null || tone == 'neutral' ? t.textSecondary : tone == 'info' ? t.info : wfToneColor(t, tone);
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

// ── Task decision (shared by the inbox and the workflow panel) ───────────────────────────────

class _DecideState extends ChangeNotifier {
  String comment = '';

  /// Set when a decision that needs remarks was made without them.
  bool commentMissing = false;
  String delegateTo = '';

  /// The chosen person, kept listed so the field keeps showing their name while others are searched.
  UiWfUser? delegateUser;

  /// People to hand the task to, from the API's directory search.
  List<UiWfUser> people = const [];
  int peopleSeq = 0;
  Timer? peopleTimer;
  bool delegateOpen = false;
  UiJson answers = {};
  bool busy = false;
  String error = '';

  /// Set once the dialog has closed: an answer that arrives after that is not shown.
  bool _disposed = false;

  void set(VoidCallback f) {
    if (_disposed) return;
    f();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    peopleTimer?.cancel();
    super.dispose();
  }
}

/// The decide dialog (the web `ui-wf-decide`): instructions, the task's form, a comment, and its
/// buttons. Completes with the task as the engine returned it after a decision or a hand-over, or
/// null when closed. While a decision is on its way the dialog can't be closed (Close, the
/// backdrop, Escape and Back wait for it). [onDecided] gets every saved decision or hand-over,
/// even one whose answer arrives after the dialog was taken away, so the host can always reload.
Future<UiWfTask?> showWfDecideDialog(BuildContext context, {required UiWfTask task, required UiWorkflowApi api, ValueChanged<UiWfTask>? onDecided}) {
  final st = _DecideState();
  final formKey = GlobalKey<UiFormRendererState>();
  String outcomeLabel(String key) => wfOutcomeLabel(key, [for (final o in task.outcomes) (key: o.key, label: o.label)]);

  /// Looks people up as the name is typed (debounced; a slower older answer never replaces a newer one).
  void searchPeople(String query) {
    st.peopleTimer?.cancel();
    st.peopleTimer = Timer(Duration(milliseconds: query.isEmpty ? 0 : 250), () async {
      final n = ++st.peopleSeq;
      try {
        final found = await api.searchUsers(query.trim(), take: 20);
        if (n != st.peopleSeq) return;
        // People already on the task (or who decided) can't take it over; the engine refuses them too.
        final taken = {...task.assignees, ...task.decisions.map((d) => d.userId)};
        final chosen = st.delegateUser;
        final options = [for (final u in found) if (!taken.contains(u.id)) u];
        if (chosen != null && !options.any((u) => u.id == chosen.id)) options.insert(0, chosen);
        st.set(() => st.people = options);
      } catch (_) {
        if (n == st.peopleSeq) st.set(() => st.people = const []);
      }
    });
  }

  Future<void> decide(BuildContext ctx, String outcome) async {
    // A second tap while the first is on its way would send the decision twice.
    if (st.busy) return;
    // The form checks itself first and shows what's wrong next to each answer; the engine checks again.
    if (task.form != null && formKey.currentState?.submit() == null) return;
    if (wfCommentRequired(task, outcome) && st.comment.trim().isEmpty) {
      st.set(() {
        st.commentMissing = true;
        st.error = 'Add remarks to explain “${outcomeLabel(outcome)}”.';
      });
      return;
    }
    st.set(() {
      st.busy = true;
      st.error = '';
    });
    try {
      final res = await api.decide(task.id, outcome, comment: st.comment.isEmpty ? null : st.comment, data: st.answers);
      onDecided?.call(res);
      if (ctx.mounted) Navigator.of(ctx).pop(res);
    } catch (e) {
      st.set(() => st.error = _errorText(e, 'The decision could not be saved.'));
    } finally {
      st.set(() => st.busy = false);
    }
  }

  Future<void> delegate(BuildContext ctx) async {
    if (st.busy || st.delegateTo.isEmpty) return;
    st.set(() {
      st.busy = true;
      st.error = '';
    });
    try {
      final res = await api.delegate(task.id, st.delegateTo);
      onDecided?.call(res);
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
        final remarks = wfRemarksLabel(task);
        // Nothing closes the dialog while a decision is on its way (Close, the backdrop, Escape, Back).
        return PopScope(canPop: !st.busy, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
          if (task.entityTitle != null) Text(task.entityTitle!, style: _body(ctx, size: 14, weight: FontWeight.w600)),
          if (task.instructions != null) Text(task.instructions!, style: _body(ctx, size: 14, height: 1.5)),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Due ${wfDateTime(task.dueAt)} (${wfAgo(task.dueAt, UiWorkflowClock.nowOf(ctx))})'),
              if (task.overdue) ...[const TextSpan(text: ' · '), TextSpan(text: 'overdue', style: TextStyle(color: t.danger, fontWeight: FontWeight.w700))],
            ]),
            style: _body(ctx, size: 12.5, color: t.textMuted),
          ),
          if (task.decisions.isNotEmpty)
            // A bulleted list, like the web `ul.decisions`.
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2, children: [
              for (final d in task.decisions)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ExcludeSemantics(child: SizedBox(width: t.space4, child: Text('•', textAlign: TextAlign.center, style: _body(ctx)))),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: d.name ?? d.userId, style: const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: ' chose “${outcomeLabel(d.outcome)}”${d.comment != null ? ': “${d.comment}”' : ''}'),
                      ]),
                      style: _body(ctx),
                    ),
                  ),
                ]),
            ]),
          if (task.form != null)
            UiFormRenderer(key: formKey, definition: task.form!, showActions: false, showTitle: false, onValueChanged: (v) => st.answers = v),
          FbSetting(
            label: remarks,
            child: UiTextarea(
              value: st.comment,
              rows: 2,
              autosize: true,
              semanticLabel: remarks,
              invalid: st.commentMissing,
              onChanged: (v) {
                st.comment = v;
                if (st.commentMissing) st.set(() => st.commentMissing = false);
              },
            ),
          ),
          if (task.allowDelegation) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FbLink(
                label: 'Hand it to someone else',
                fontSize: 12.5,
                onTap: () {
                  st.set(() => st.delegateOpen = !st.delegateOpen);
                  if (st.delegateOpen) searchPeople('');
                },
              ),
            ),
            // One combobox that searches the directory as the name is typed, then Hand over (the web
            // `ui-combobox` in `details.delegate`).
            if (st.delegateOpen)
              Row(spacing: t.space2, children: [
                Expanded(
                  child: UiCombobox(
                    size: UiSize.sm,
                    placeholder: 'Search for a person',
                    label: 'Hand it to',
                    options: [for (final u in st.people) UiComboboxOption(value: u.id, label: u.email != null ? '${u.name} (${u.email})' : u.name)],
                    value: st.delegateTo.isEmpty ? null : st.delegateTo,
                    onQuery: searchPeople,
                    onChanged: (v) => st.set(() {
                      st.delegateTo = v ?? '';
                      st.delegateUser = v == null ? null : st.people.where((u) => u.id == v).firstOrNull;
                    }),
                  ),
                ),
                UiButton(label: 'Hand over', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: st.busy || st.delegateTo.isEmpty ? null : () => delegate(ctx)),
              ]),
          ],
          if (st.error.isNotEmpty) WfNote(st.error),
        ]));
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
          UiButton(label: 'Close', variant: UiButtonVariant.ghost, onPressed: st.busy ? null : () => Navigator.of(ctx).pop()),
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

// ── Record actions ──────────────────────────────────────────────────────────────────────────

/// The moves a person may make on a record now, its manual workflows and open tasks, with the
/// dialogs that go with them (confirmation, transition form, decision): the web
/// `ui-wf-record-actions`, used by the workflow panel.
class WfRecordActions extends StatefulWidget {
  const WfRecordActions({
    super.key,
    required this.api,
    required this.record,
    required this.entity,
    required this.entityId,
    this.showTasks = true,
    this.emptyText = '',
    this.onChanged,
    this.onReload,
  });

  final UiWorkflowApi? api;
  final UiWfRecord record;
  final String entity;
  final String entityId;

  /// List the record's open tasks.
  final bool showTasks;

  /// Said when this person has nothing to do here (no moves, manual workflows or tasks); empty says nothing.
  final String emptyText;

  /// A move was applied: the record as it is now.
  final Future<void> Function(UiWfRecord record)? onChanged;

  /// Something changed that needs a fresh read (a decision, a manual start).
  final Future<void> Function()? onReload;

  @override
  State<WfRecordActions> createState() => _WfRecordActionsState();
}

/// What the record actions' confirmation is for.
enum _ActionKind { move, reset, manual }

/// A move, reset or manual start waiting for its confirmation (the web `WfPendingAction`), with
/// whether remarks are asked.
class _PendingAction {
  const _PendingAction(this.option, this.kind, this.remarks);
  final UiWfTransitionOption option;
  final _ActionKind kind;
  final UiWfRemarks remarks;
}

/// Everything the open confirmation holds; it is dropped when the dialog closes, and writes after
/// that are ignored (an answer can arrive after the dialog was closed).
class _ActionDialog extends ChangeNotifier {
  _ActionDialog(this.pending);
  final _PendingAction pending;
  bool busy = false;
  String error = '';
  UiJson input = {};

  /// The person's remarks on the move or reset (spec §6 remarks).
  String remark = '';

  /// Set when a required remark was left empty on confirm.
  bool remarkMissing = false;

  /// The reset's list of what the workflow did, and which of it to take back.
  List<UiWfResetItem> items = const [];
  Set<String> chosen = const {};
  bool loading = false;

  /// The list has been read (it may be empty).
  bool loaded = false;
  String listError = '';

  /// The list's token, sent back so a reset fails if the list changed since it was read.
  String? token;

  bool _disposed = false;
  bool get disposed => _disposed;

  void set(VoidCallback f) {
    if (_disposed) return;
    f();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _WfRecordActionsState extends State<WfRecordActions> {
  bool _busy = false;
  String _error = '';

  /// The open confirmation and its route, if any.
  _ActionDialog? _dialog;
  Route<void>? _dialogRoute;

  /// Bumped per reset-list request and when the dialog closes, so a late answer is dropped.
  int _resetSeq = 0;

  @override
  void didUpdateWidget(WfRecordActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A dialog belongs to the record it was opened for: switching records closes it.
    if (oldWidget.entity != widget.entity || oldWidget.entityId != widget.entityId) _closeDialog(later: true);
  }

  @override
  void dispose() {
    // Nothing is left to confirm for once these actions are gone.
    _closeDialog(later: true);
    super.dispose();
  }

  /// Closes the confirmation (if open) and forgets everything it held, the reset's list included.
  /// [later]: after this frame (from a build or a dispose, when the navigator can't change).
  void _closeDialog({bool later = false}) {
    _resetSeq++;
    final route = _dialogRoute;
    if (route == null) return;
    void close() {
      if (!route.isActive) return;
      if (route.isCurrent) {
        route.navigator?.pop();
      } else {
        route.navigator?.removeRoute(route);
      }
    }

    if (later) {
      WidgetsBinding.instance.addPostFrameCallback((_) => close());
    } else {
      close();
    }
  }

  void _start(UiWfTransitionOption t) {
    if (_busy) return;
    final p = _PendingAction(t, _ActionKind.move, wfRemarksFor(t));
    if (t.form == null && t.confirm == null && p.remarks == UiWfRemarks.none) {
      _apply(t.key, const {}, null);
      return;
    }
    _confirm(p);
  }

  void _startManual(UiWfManualOption m) {
    if (_busy) return;
    if (m.form == null) {
      _runManual(m.key, const {}, null);
      return;
    }
    _confirm(_PendingAction(UiWfTransitionOption(key: m.key, label: m.label, tone: 'primary', form: m.form), _ActionKind.manual, UiWfRemarks.none));
  }

  /// Starting over: always confirmed (it stops work in progress), with the reset's form when it has one.
  void _startReset(UiWfResetOption rs) {
    if (_busy) return;
    final d = _confirm(_PendingAction(
      UiWfTransitionOption(key: '', label: rs.label, to: rs.to, toLabel: rs.toLabel, tone: 'danger',
          confirm: rs.confirm ?? 'Start over from “${rs.toLabel}”? Open tasks and runs stop.', form: rs.form),
      _ActionKind.reset,
      rs.comment ?? UiWfRemarks.optional,
    ));
    _loadResetItems(d);
  }

  /// Reads what the workflow did, ticking what the engine suggests (everything that can be undone
  /// and wasn't changed since). With [keepChoices], items still listed keep the person's ticks.
  Future<void> _loadResetItems(_ActionDialog d, {bool keepChoices = false}) async {
    final api = widget.api;
    final seq = ++_resetSeq;
    final beforeItems = {for (final i in d.items) i.id};
    final beforeChosen = d.chosen;
    d.set(() {
      d.items = const [];
      d.chosen = const {};
      d.token = null;
      d.listError = '';
      d.loaded = false;
    });
    if (api == null) return;
    d.set(() => d.loading = true);
    try {
      final preview = await api.resetPreview(widget.entity, widget.entityId);
      // The dialog may have been closed, or the list asked for again, while this one was on its way.
      if (seq != _resetSeq) return;
      d.set(() {
        d.items = preview.items;
        d.token = preview.token;
        d.chosen = {
          for (final i in preview.items)
            if (i.undoable && (keepChoices && beforeItems.contains(i.id) ? beforeChosen.contains(i.id) : i.selected)) i.id,
        };
        d.loaded = true;
      });
    } on UnimplementedError {
      // This API can't list it: the reset only confirms.
    } catch (_) {
      if (seq == _resetSeq) d.set(() => d.listError = "What the workflow did couldn't be listed, so the reset will leave it as it is.");
    } finally {
      if (seq == _resetSeq) d.set(() => d.loading = false);
    }
  }

  /// The confirmation (or form, or remarks) before a move, a reset or a manual start.
  _ActionDialog _confirm(_PendingAction p) {
    _closeDialog();
    final d = _ActionDialog(p);
    final o = p.option;
    final reset = p.kind == _ActionKind.reset;
    final formKey = GlobalKey<UiFormRendererState>();
    _dialog = d;

    Future<void> confirm(BuildContext ctx) async {
      // A double tap must not apply the move twice; nor may the reset go before its list arrives.
      if (d.busy || d.loading) return;
      // The form checks itself first and shows what's wrong next to each answer; the engine checks again.
      if (o.form != null && formKey.currentState?.submit() == null) return;
      if (p.remarks == UiWfRemarks.required && d.remark.trim().isEmpty) {
        d.set(() {
          d.remarkMissing = true;
          d.error = 'Add remarks to explain this.';
        });
        return;
      }
      d.set(() => d.busy = true);
      final ok = switch (p.kind) {
        _ActionKind.reset => await _reset(d),
        _ActionKind.manual => await _runManual(o.key, d.input, d),
        _ActionKind.move => await _apply(o.key, d.input, d),
      };
      d.set(() => d.busy = false);
      if (ok && identical(_dialog, d)) _closeDialog();
    }

    showUiModal<void>(
      context: context,
      title: o.label,
      // A reset's list of what the workflow did needs the room.
      size: reset ? UiModalSize.lg : UiModalSize.md,
      builder: (ctx) {
        _dialogRoute = ModalRoute.of(ctx);
        return ListenableBuilder(
          listenable: d,
          builder: (ctx, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: ctx.ui.space2, children: [
            if (o.confirm != null) Text(o.confirm!, style: _body(ctx, size: 14)),
            if (o.form != null)
              UiFormRenderer(key: formKey, definition: o.form!, showActions: false, showTitle: false, onValueChanged: (v) => d.input = v)
            else if (o.confirm == null)
              Text('Move this record to “${o.toLabel}”?', style: _body(ctx, size: 14)),
            if (p.remarks != UiWfRemarks.none)
              FbSetting(
                label: 'Remarks${p.remarks == UiWfRemarks.required ? ' (required)' : ' (optional)'}',
                child: UiTextarea(
                  value: d.remark,
                  rows: 2,
                  autosize: true,
                  invalid: d.remarkMissing,
                  semanticLabel: 'Remarks',
                  onChanged: (v) {
                    d.remark = v;
                    if (d.remarkMissing) d.set(() => d.remarkMissing = false);
                  },
                ),
              ),
            if (reset) _WfResetUndoList(dialog: d),
            if (d.error.isNotEmpty) WfNote(d.error),
          ]),
        );
      },
      footerBuilder: (ctx) => ListenableBuilder(
        listenable: d,
        builder: (ctx, _) => Row(children: [
          UiButton(label: 'Cancel', variant: UiButtonVariant.ghost, onPressed: d.busy ? null : () => Navigator.of(ctx).pop()),
          const Spacer(),
          UiButton(
            label: o.label,
            variant: o.tone == 'danger' ? UiButtonVariant.destructive : UiButtonVariant.primary,
            // Not before the reset's list arrives: confirming then would take back nothing.
            onPressed: d.busy || d.loading ? null : () => confirm(ctx),
          ),
        ]),
      ),
    ).whenComplete(() {
      if (identical(_dialog, d)) {
        _dialog = null;
        _dialogRoute = null;
        _resetSeq++;
      }
      d.dispose();
    });
    return d;
  }

  /// Shows [msg] in the dialog while it is open, else under the buttons (it may have been closed).
  void _fail(_ActionDialog? d, String msg) {
    if (d != null && !d.disposed) {
      d.set(() => d.error = msg);
    } else if (mounted) {
      setState(() => _error = msg);
    }
  }

  Future<bool> _apply(String key, UiJson input, _ActionDialog? d) async {
    final api = widget.api;
    if (api == null || _busy) return false;
    setState(() => _busy = true);
    try {
      final remark = d != null && d.pending.remarks != UiWfRemarks.none && d.remark.trim().isNotEmpty ? d.remark.trim() : null;
      final r = await api.applyTransition(widget.entity, widget.entityId, key, input: input, comment: remark);
      if (mounted) setState(() => _error = '');
      await widget.onChanged?.call(r);
      return true;
    } catch (e) {
      _fail(d, _errorText(e, 'That did not work.'));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _reset(_ActionDialog d) async {
    final api = widget.api;
    if (api == null || _busy) return false;
    setState(() => _busy = true);
    try {
      final undo = [for (final i in d.items) if (d.chosen.contains(i.id)) i.id];
      final remark = d.remark.trim();
      final r = await api.resetRecord(widget.entity, widget.entityId, input: d.input, undo: undo.isEmpty ? null : undo, comment: remark.isEmpty ? null : remark, token: d.token);
      if (mounted) setState(() => _error = '');
      await widget.onChanged?.call(r);
      return true;
    } catch (e) {
      _fail(d, _errorText(e, 'The workflow could not be reset.'));
      // Someone else changed what the workflow did meanwhile: show the list as it is now, keeping the person's ticks.
      if (!d.disposed && e is UiWfApiError && e.code == 'resetChanged') _loadResetItems(d, keepChoices: true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _runManual(String key, UiJson input, _ActionDialog? d) async {
    final api = widget.api;
    if (api == null || _busy) return false;
    setState(() => _busy = true);
    try {
      await api.startManual(key, widget.entity, widget.entityId, input: input);
      if (mounted) setState(() => _error = '');
      await widget.onReload?.call();
      return true;
    } catch (e) {
      _fail(d, _errorText(e, 'That did not work.'));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openTask(UiWfTask t) async {
    final api = widget.api;
    if (api == null) return;
    // Reloads on every saved decision, even one that lands after the dialog was taken away.
    await showWfDecideDialog(context, task: t, api: api, onDecided: (_) => widget.onReload?.call());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final r = widget.record;
    final tasks = widget.showTasks ? r.tasks : const <UiWfTask>[];
    final reset = r.reset;
    final nothing = r.transitions.isEmpty && r.manual.isEmpty && tasks.isEmpty && reset == null;
    // Small buttons with a mouse; the regular size on touch screens, where small ones look cramped.
    final size = uiTouchPlatform(context) ? UiSize.md : UiSize.sm;
    if (nothing && widget.emptyText.isEmpty && _error.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space3, children: [
      if (r.transitions.isNotEmpty || r.manual.isNotEmpty)
        Wrap(spacing: t.space2, runSpacing: t.space2, children: [
          for (final tr in r.transitions) UiButton(label: tr.label, size: size, variant: _variantOf(tr.tone), onPressed: _busy ? null : () => _start(tr)),
          for (final m in r.manual) UiButton(label: m.label, size: size, variant: UiButtonVariant.outline, onPressed: _busy ? null : () => _startManual(m)),
        ]),
      if (reset != null)
        // Set apart by a dashed rule (the web `.reset { border-top: 1px dashed }`).
        CustomPaint(
          key: const ValueKey('wf-reset-row'),
          painter: WfDashedTopRule(t.border),
          child: Padding(
          padding: EdgeInsets.only(top: t.space2),
          child: Wrap(spacing: t.space2, runSpacing: t.space2, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Back to “${reset.toLabel}”: open tasks and runs stop.', style: _body(context, size: 12, color: t.textMuted)),
            UiButton(label: reset.label, size: size, variant: UiButtonVariant.outline, onPressed: _busy ? null : () => _startReset(reset)),
          ]),
        )),
      if (tasks.isNotEmpty)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          const _Heading('Waiting for'),
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: UiInteractive(
                onTap: () => _openTask(task),
                enabled: task.canDecide,
                semanticLabel: '${task.title}, ${task.assigneeNames.join(', ')}, due ${wfAgo(task.dueAt, UiWorkflowClock.nowOf(context))}${task.canDecide ? ', your turn' : ''}',
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
                        Text('${task.assigneeNames.join(', ')} · due ${wfAgo(task.dueAt, UiWorkflowClock.nowOf(context))}', style: _body(context, size: 12, color: t.textMuted)),
                      ]),
                    ),
                    if (task.canDecide) const WfChip('Your turn', tone: 'primary'),
                  ]),
                ),
              ),
            ),
        ]),
      if (nothing && widget.emptyText.isNotEmpty) FbHint(widget.emptyText),
      if (_error.isNotEmpty) WfNote(_error),
    ]);
  }
}

/// A 1px dashed rule along the top edge (the web `border-top: 1px dashed`).
@visibleForTesting
class WfDashedTopRule extends CustomPainter {
  const WfDashedTopRule(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + 3 > size.width ? size.width : x + 3, 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(WfDashedTopRule old) => old.color != color;
}

// ── Task inbox ──────────────────────────────────────────────────────────────────────────────

/// The task inbox inside [UiWorkflowTasksDrawer]: approvals and tasks, due first, overdue marked,
/// open or finished, each opening its decision. Internal: apps use the drawer.
class WfTaskInbox extends StatefulWidget {
  const WfTaskInbox({super.key, required this.api, this.scope = 'mine', this.pageSize = 25, this.onDecided});
  final UiWorkflowApi? api;

  /// `mine` (the signed-in person's) or `all` (needs admin rights).
  final String scope;
  final int pageSize;

  /// After a decision, so the host can refresh related views.
  final ValueChanged<UiWfTask>? onDecided;

  @override
  State<WfTaskInbox> createState() => WfTaskInboxState();
}

class WfTaskInboxState extends State<WfTaskInbox> {
  String _status = 'open';
  List<UiWfTask> _tasks = const [];
  int _total = 0;
  String _error = '';
  late int _take = widget.pageSize;
  int _seq = 0;

  /// The list has been read at least once (until then it says it is loading, not that it is empty).
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(WfTaskInbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.api != widget.api || old.scope != widget.scope || old.pageSize != widget.pageSize) {
      _take = widget.pageSize;
      _startOver();
    }
  }

  /// A different list (another engine, scope or tab): forget the old one and read it afresh.
  void _startOver() {
    setState(() {
      _loaded = false;
      _tasks = const [];
      _total = 0;
    });
    reload();
  }

  /// What the empty list says: loading until the first answer (nothing next to an error), then
  /// worded for whose tasks these are.
  String get _emptyText {
    if (!_loaded) return _error.isNotEmpty ? '' : 'Loading…';
    final all = widget.scope == 'all';
    if (_status == 'done') return all ? 'No finished tasks yet.' : 'You haven’t finished any tasks yet.';
    return all ? 'No open tasks.' : 'Nothing is waiting for you.';
  }

  Future<void> reload() async {
    final api = widget.api;
    if (api == null) return;
    final n = ++_seq;
    try {
      final page = await api.tasks(UiWfTaskQuery(scope: widget.scope, status: _status == 'open' ? const ['open'] : const ['completed', 'timedOut', 'cancelled'], take: _take));
      if (!mounted || n != _seq) return;
      setState(() {
        _tasks = page.items;
        _total = page.total;
        _loaded = true;
        _error = '';
      });
    } catch (e) {
      if (mounted && n == _seq) setState(() => _error = _errorText(e, 'Could not load tasks.'));
    }
  }

  String _outcomeLabel(UiWfTask t) => wfTaskResult(t);

  Future<void> _open(UiWfTask t) async {
    final api = widget.api;
    if (api == null) return;
    await showWfDecideDialog(context, task: t, api: api, onDecided: (res) {
      widget.onDecided?.call(res);
      if (mounted) reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
      Row(children: [
        UiSegmented<String>(
          label: 'Which tasks',
          size: UiSize.sm,
          value: _status,
          options: const [UiSegmentedOption(value: 'open', label: 'Open'), UiSegmentedOption(value: 'done', label: 'Done')],
          onChanged: (v) {
            _status = v;
            _take = widget.pageSize;
            _startOver();
          },
        ),
        const Spacer(),
        FbIconButton(icon: WfIcons.refresh, label: 'Refresh', onPressed: reload),
      ]),
      if (_error.isNotEmpty) WfNote(_error),
      if (_tasks.isEmpty && _emptyText.isNotEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: t.space6),
          child: Text(_emptyText, textAlign: TextAlign.center, style: _body(context, color: t.textMuted)),
        ),
      for (final task in _tasks) _TaskRow(task: task, outcome: _outcomeLabel(task), onTap: () => _open(task)),
      if (_total > _tasks.length)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: UiButton(
            label: 'Show more',
            size: UiSize.sm,
            variant: UiButtonVariant.outline,
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
    final due = '${task.overdue ? 'Overdue' : 'Due'} ${wfAgo(task.dueAt, UiWorkflowClock.nowOf(context))}';
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

/// One run drawn over its workflow (the web `ui-wf-run-view`): each step with what happened (done,
/// waiting, failed, skipped), the paths not taken greyed out, and, for people who may intervene, try
/// again, skip (giving the step's results) and cancel (with remarks). When several paths stopped, each
/// can be retried or skipped on its own. Internal: the workflow panel and the tasks drawer show it
/// where the run matters.
class WfRunView extends StatefulWidget {
  const WfRunView({super.key, required this.api, required this.instanceId, this.canIntervene, this.showHead = true, this.onChanged});
  final UiWorkflowApi? api;
  final String instanceId;

  /// Show retry, skip and cancel. Left null, the view asks the engine (`me().canIntervene`), so only
  /// people the server lets intervene see them; the server checks again either way.
  final bool? canIntervene;

  /// Show the run's title, version and status (off where the host already names the run).
  final bool showHead;
  final ValueChanged<UiWfInstance>? onChanged;

  @override
  State<WfRunView> createState() => WfRunViewState();
}

/// A skip or cancel dialog's state: on its way, and its error. Writes after it closed are ignored
/// (an answer can arrive after the dialog was taken away).
class _RunDialog extends ChangeNotifier {
  bool busy = false;
  String error = '';
  bool _disposed = false;
  void set(VoidCallback f) {
    if (_disposed) return;
    f();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class WfRunViewState extends State<WfRunView> {
  UiWfInstance? _run;
  UiWorkflowDefinition? _def;
  bool _busy = false;
  String _error = '';
  bool _allowed = false;
  int _seq = 0;

  /// A skip dialog is being prepared (its step's outputs are being read): a second tap waits.
  bool _skipPending = false;

  bool get _mayIntervene => widget.canIntervene ?? _allowed;

  @override
  void initState() {
    super.initState();
    reload();
    _askAllowed();
  }

  @override
  void didUpdateWidget(WfRunView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.api != widget.api || old.instanceId != widget.instanceId) reload();
    if (old.api != widget.api || old.canIntervene != widget.canIntervene) _askAllowed();
  }

  /// Whether the engine lets this person intervene, when the host doesn't say.
  void _askAllowed() {
    final api = widget.api;
    if (api == null || widget.canIntervene != null) return;
    Future.sync(api.me).then((me) {
      if (mounted) setState(() => _allowed = me?.canIntervene ?? false);
    }).catchError((Object _) {
      if (mounted) setState(() => _allowed = false);
    });
  }

  Future<void> reload() async {
    final api = widget.api;
    if (api == null) return;
    final n = ++_seq;
    try {
      final results = await Future.wait([api.instance(widget.instanceId), api.instanceDefinition(widget.instanceId)]);
      if (!mounted || n != _seq) return;
      setState(() {
        _run = results[0] as UiWfInstance;
        _def = results[1] as UiWorkflowDefinition;
        _error = '';
      });
    } catch (e) {
      if (mounted && n == _seq) setState(() => _error = _errorText(e, 'Could not load the run.'));
    }
  }

  /// The paths stopped by a failure: one per token waiting on an incident, named after its step.
  List<({String token, String? stepId, String name})> get _incidents {
    final r = _run;
    final steps = _def != null ? indexSteps(_def!) : null;
    return [
      for (final tk in r?.tokens ?? const <UiWfRunToken>[])
        if (tk.waiting == 'incident')
          (token: tk.id, stepId: tk.stepId, name: _incidentName(steps, tk)),
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
    const texts = {'completed': 'Done', 'timedOut': 'Out of time', 'waiting': 'Waiting', 'running': 'Running', 'failed': 'Failed', 'skipped': 'Skipped', 'cancelled': 'Cancelled', 'notRun': ''};
    return [
      for (final loc in indexSteps(def).values)
        if (loc.path.first == rootList)
          () {
            final runs = byNode[loc.step.id] ?? const <UiWfStepRun>[];
            final last = runs.lastOrNull;
            // A step that finished because its time ran out isn't "done": it took its timeout path.
            final status = last?.status == 'completed' && wfStepTimedOut(last?.output) ? 'timedOut' : last?.status ?? 'notRun';
            return _RunRow(
              loc.step.id,
              stepName(loc.step),
              loc.path.length - 1,
              status,
              texts[status] ?? status,
              // The step's own detail keeps the engine's full text, for whoever debugs it.
              last?.error ?? (runs.length > 1 ? '${runs.length} attempts' : ''),
              status == 'completed' ? WfIcons.tick02 : status == 'timedOut' ? WfIcons.clock02 : (status == 'failed' ? WfIcons.cancel01 : wfStepIcon(loc.step.type)),
            );
          }(),
    ];
  }

  /// Tries again, skips or cancels; answers whether it worked. A [dialog]'s buttons wait meanwhile,
  /// and it shows the error.
  Future<bool> _act(String kind, {String? target, UiJson? outputs, String? reason, _RunDialog? dialog}) async {
    final api = widget.api;
    final r = _run;
    if (api == null || r == null || _busy) return false;
    setState(() {
      _busy = true;
      _error = '';
    });
    dialog?.set(() {
      dialog.busy = true;
      dialog.error = '';
    });
    try {
      final next = kind == 'retry'
          ? await api.retry(r.id, target: target)
          : kind == 'skip'
          ? await api.skip(r.id, outputs: outputs, target: target)
          : await api.cancel(r.id, reason: reason);
      if (!mounted) return true;
      _seq++;
      setState(() => _run = next);
      widget.onChanged?.call(next);
      return true;
    } catch (e) {
      final msg = _errorText(e, 'That did not work.');
      if (mounted) setState(() => _error = msg);
      dialog?.set(() => dialog.error = msg);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
      dialog?.set(() => dialog.busy = false);
    }
  }

  /// A skip or cancel dialog: Back and the confirm button wait while it is on its way, and so do
  /// the backdrop, Escape and the back button.
  Future<void> _runDialog({required String title, required List<Widget> Function(BuildContext ctx) body, required String confirm, UiButtonVariant variant = UiButtonVariant.primary, required Future<bool> Function(_RunDialog d) onConfirm}) async {
    final d = _RunDialog();
    await showUiModal<void>(
      context: context,
      title: title,
      size: UiModalSize.md,
      builder: (ctx) => ListenableBuilder(
        listenable: d,
        builder: (ctx, _) => PopScope(
          canPop: !d.busy,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: ctx.ui.space2, children: [
            ...body(ctx),
            if (d.error.isNotEmpty) WfNote(d.error),
          ]),
        ),
      ),
      footerBuilder: (ctx) => ListenableBuilder(
        listenable: d,
        builder: (ctx, _) => Row(children: [
          UiButton(label: 'Back', variant: UiButtonVariant.ghost, onPressed: d.busy ? null : () => Navigator.of(ctx).pop()),
          const Spacer(),
          UiButton(
            label: confirm,
            variant: variant,
            onPressed: d.busy
                ? null
                : () async {
                    final ok = await onConfirm(d);
                    if (ok && ctx.mounted) Navigator.of(ctx).pop();
                  },
          ),
        ]),
      ),
    );
    d.dispose();
  }

  /// Skipping: the run carries on as if the step had finished, with the results given here (for an
  /// app action, its outputs as the registry declares them, with labels people know).
  Future<void> _askSkip(String? target, String? stepId) async {
    // Reading the step's outputs takes a moment: a second tap meanwhile must not open a second dialog.
    if (_skipPending) return;
    _skipPending = true;
    try {
      await _openSkip(target, stepId);
    } finally {
      _skipPending = false;
    }
  }

  Future<void> _openSkip(String? target, String? stepId) async {
    final api = widget.api;
    final def = _def;
    final step = def != null && stepId != null ? indexSteps(def)[stepId]?.step : null;
    var outputs = <({String key, String label})>[];
    if (step?.type == 'action' && api != null) {
      final schema = await Future.sync(api.schema).then<UiWorkflowSchema?>((s) => s).catchError((Object _) => null);
      final action = schema?.registry.actions?.where((a) => a.key == UiWfActionStep.of(step!).action).firstOrNull;
      outputs = [for (final o in action?.outputs ?? const <UiWfParamDescriptor>[]) (key: o.key, label: o.label)];
    }
    if (!mounted) return;
    final values = <String, String>{};
    final name = step != null ? stepName(step) : 'the step';
    await _runDialog(
      title: 'Skip “$name”',
      confirm: 'Skip the step',
      body: (ctx) => [
        Text('The run carries on as if this step had finished.${outputs.isNotEmpty ? ' Give what it would have produced, for the steps after it.' : ''}', style: _body(ctx, size: 14)),
        for (final o in outputs)
          FbSetting(label: o.label, child: UiInput(size: UiSize.sm, semanticLabel: o.label, value: values[o.key], onChanged: (v) => values[o.key] = v)),
      ],
      onConfirm: (d) {
        final given = <String, Object?>{
          for (final e in values.entries)
            if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
        };
        return _act('skip', target: target, outputs: given.isEmpty ? null : given, dialog: d);
      },
    );
  }

  /// Cancelling is a negative action: confirmed, with optional remarks that go into the audit.
  Future<void> _askCancel() async {
    var remarks = '';
    await _runDialog(
      title: 'Cancel the run',
      confirm: 'Cancel the run',
      variant: UiButtonVariant.destructive,
      body: (ctx) => [
        Text('The run stops here and its open tasks are cancelled. What it already did stays done.', style: _body(ctx, size: 14)),
        FbSetting(
          label: 'Remarks (optional)',
          child: UiTextarea(value: remarks, rows: 2, autosize: true, semanticLabel: 'Remarks (optional)', onChanged: (v) => remarks = v),
        ),
      ],
      onConfirm: (d) => _act('cancel', reason: remarks.trim().isEmpty ? null : remarks.trim(), dialog: d),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final r = _run;
    if (r == null) return _error.isNotEmpty ? WfNote(_error) : const FbHint('Loading…');
    final incidents = _incidents;
    UiButton btn(String label, VoidCallback onTap, {UiButtonVariant variant = UiButtonVariant.primary}) =>
        UiButton(label: label, size: UiSize.sm, variant: variant, onPressed: _busy ? null : onTap);
    final cancel = btn('Cancel the run', _askCancel, variant: UiButtonVariant.destructive);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
      if (widget.showHead)
        Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
          Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(r.title, style: _body(context, size: 14, weight: FontWeight.w700)),
            Text('v${r.version}', style: context.uiText.code.copyWith(fontSize: 11.5, color: t.textMuted)),
            WfChip(wfRunStatusLabel(r.status), tone: wfRunStatusTone(r.status)),
            if ((r.stateLabel ?? '').isNotEmpty) Text('· ${r.stateLabel}', style: _body(context, color: t.textSecondary)),
          ]),
          Text(
            '${r.entityTitle ?? r.entityId ?? ''} · started ${wfAgo(r.startedAt, UiWorkflowClock.nowOf(context))}${r.initiatorName != null ? ' by ${r.initiatorName}' : ''}',
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
              Text.rich(TextSpan(children: [const TextSpan(text: 'Stopped: ', style: TextStyle(fontWeight: FontWeight.w700)), TextSpan(text: wfReadableError(r.error))]), style: _body(context)),
              if (_mayIntervene && incidents.length > 1) ...[
                // Several paths stopped: each can be retried or skipped on its own.
                for (final i in incidents)
                  Row(spacing: t.space2, children: [
                    Expanded(child: Text(i.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _body(context))),
                    btn('Try again', () => _act('retry', target: i.token)),
                    btn('Skip', () => _askSkip(i.token, i.stepId), variant: UiButtonVariant.outline),
                  ]),
                Align(alignment: AlignmentDirectional.centerStart, child: cancel),
              ] else if (_mayIntervene)
                Wrap(spacing: t.space2, runSpacing: t.space2, children: [
                  btn('Try again', () => _act('retry')),
                  btn('Skip the step', () => _askSkip(null, r.errorStepId), variant: UiButtonVariant.outline),
                  cancel,
                ])
              else
                const FbHint('Someone who looks after workflows can try it again or skip it.'),
            ]),
          ),
        )
      else if (_mayIntervene && (r.status == 'waiting' || r.status == 'running' || r.status == 'queued'))
        Align(alignment: AlignmentDirectional.centerStart, child: cancel),
      if (_error.isNotEmpty) WfNote(_error),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final s in _rows) _RunStepRow(row: s),
      ]),
      if (r.tasks?.isNotEmpty ?? false)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
          const WfSectionTitle('Tasks'),
          for (final task in r.tasks!)
            Text(
              '•  ${task.title} — ${task.status == 'open' ? 'waiting for ${task.assigneeNames.join(', ')}, due ${wfAgo(task.dueAt, UiWorkflowClock.nowOf(context))}' : wfTaskResult(task)}',
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
      'skipped' || 'cancelled' || 'timedOut' => t.warning,
      _ => t.textMuted,
    };
    final edge = switch (row.status) { 'completed' || 'waiting' || 'running' || 'failed' || 'timedOut' => c, _ => t.border };
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

  /// What is typed in the record filter; it reaches [_recordFilter] (and the server) after a pause.
  String _recordText = '';
  String _recordFilter = '';
  Timer? _recordTimer;
  final Set<int> _raw = {};
  int _seq = 0;
  List<UiWfAuditEntry> _entries = const [];
  bool _hasMore = false;
  final Set<int> _open = {};
  UiWfAuditVerification? _verification;
  bool _busy = false;
  String _error = '';

  /// Workflow titles by key, so entries by a workflow name it rather than its key.
  Map<String, String> _titles = const {};

  @override
  void initState() {
    super.initState();
    load(false);
    _loadTitles();
  }

  int _titlesSeq = 0;

  Future<void> _loadTitles() async {
    final n = ++_titlesSeq;
    try {
      final d = await widget.api?.definitions();
      if (d != null && mounted && n == _titlesSeq) setState(() => _titles = {for (final x in d) x.key: x.title});
    } catch (_) {
      // Keys read as words when the titles can't be loaded.
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(UiWorkflowAudit oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.api != widget.api || old.entity != widget.entity || old.entityId != widget.entityId || old.instanceId != widget.instanceId) load(false);
    // Another engine names its workflows its own way.
    if (old.api != widget.api) {
      _titles = const {};
      _loadTitles();
    }
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
    final n = ++_seq;
    try {
      final before = older && _entries.isNotEmpty ? _entries.last.seq : null;
      final page = await api.audit(_query(before: before));
      if (!mounted || n != _seq) return;
      setState(() {
        _entries = older ? [..._entries, ...page] : page;
        _hasMore = page.length == widget.pageSize;
        _error = '';
      });
    } catch (e) {
      if (mounted && n == _seq) setState(() => _error = _errorText(e, 'Could not load the audit log.'));
    }
  }

  Future<void> _verify() async {
    final api = widget.api;
    if (api == null || _busy) return;
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
    if (api == null || _busy) return;
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
      // Filters on the left, the buttons pushed to the right while they fit on one line (the web
      // `.grow` spacer); on narrow screens they wrap.
      LayoutBuilder(builder: (context, box) {
        final filters = <Widget>[
          SizedBox(
            width: 200,
            child: WfSelect(
              label: 'Kind',
              value: _category.isEmpty ? 'all' : _category,
              options: [(value: 'all', label: 'Everything'), for (final c in wfAuditCategories) (value: c.value, label: c.label)],
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
                value: _recordText,
                placeholder: 'Record id',
                semanticLabel: 'Record id',
                onChanged: (s) {
                  setState(() => _recordText = s);
                  _recordTimer?.cancel();
                  _recordTimer = Timer(const Duration(milliseconds: 350), () {
                    if (!mounted || s.trim() == _recordFilter) return;
                    setState(() => _recordFilter = s.trim());
                    load(false);
                  });
                },
              ),
            ),
        ];
        final buttons = <Widget>[
          UiButton(label: 'Check integrity', size: UiSize.sm, variant: UiButtonVariant.ghost, icon: const UiIcon(WfIcons.securityCheck, size: 14), onPressed: _busy ? null : _verify),
          if (widget.onExport != null)
            UiButton(label: 'CSV', size: UiSize.sm, variant: UiButtonVariant.ghost, icon: const UiIcon(WfIcons.download04, size: 14), onPressed: _busy ? null : () => _export('csv')),
        ];
        if (box.maxWidth >= 620) {
          return Row(spacing: t.space2, children: [...filters, const Spacer(), ...buttons]);
        }
        return Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [...filters, ...buttons]);
      }),
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
              who: wfActorLabel(_entries[i], (k) => _titles[k]),
              entry: _entries[i],
              open: _open.contains(_entries[i].seq),
              raw: _raw.contains(_entries[i].seq),
              onToggle: () => setState(() => _open.contains(_entries[i].seq) ? _open.remove(_entries[i].seq) : _open.add(_entries[i].seq)),
              onToggleRaw: () => setState(() => _raw.contains(_entries[i].seq) ? _raw.remove(_entries[i].seq) : _raw.add(_entries[i].seq)),
            ),
          ],
        ]),
      ),
      if (_hasMore) Align(alignment: AlignmentDirectional.centerStart, child: UiButton(label: 'Older entries', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => load(true))),
    ]);
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry, required this.who, required this.open, required this.raw, required this.onToggle, required this.onToggleRaw});
  final UiWfAuditEntry entry;

  /// Who did it, as people read it.
  final String who;
  final bool open;

  /// Shows before/after/details as the stored JSON rather than key/value rows.
  final bool raw;
  final VoidCallback onToggle;
  final VoidCallback onToggleRaw;

  /// One line per key of an audit entry's JSON field, for people to read.
  static List<(String, String)> _rows(String? text) => [
    for (final e in wfAuditJson(text).entries)
      (
        wfHumanize(e.key),
        switch (e.value) {
          null => '—',
          final bool b => b ? 'Yes' : 'No',
          final Map<Object?, Object?> m => jsonEncode(m),
          final List<Object?> l => jsonEncode(l),
          final v => jsString(v),
        },
      ),
  ];

  String _subject(UiWfAuditEntry e) {
    final record = e.entity != null ? '${wfHumanize(e.entity!)} ${e.entityId ?? ''}'.trim() : '';
    final subject = '${wfHumanize(e.subjectType)} ${e.subjectId}';
    return record.isNotEmpty && e.subjectType != e.entity ? '$subject ($record)' : (record.isNotEmpty ? record : subject);
  }

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
        semanticLabel: 'Entry ${e.seq}: ${wfAuditCategoryLabel(e.category)}, ${wfAuditActionLabel(e.category, e.action)}, $who, ${wfDateTime(e.at)}',
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
                TextSpan(text: wfAuditCategoryLabel(e.category).toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.33, color: catColor)),
                TextSpan(text: ' ${wfAuditActionLabel(e.category, e.action)}'),
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
        LayoutBuilder(builder: (context, box) => Container(
          color: t.bg,
          // Lined up under the entry's text on wide screens (the web `padding-left: 66px`).
          padding: EdgeInsets.fromLTRB(box.maxWidth < 420 ? 10 : 66, 6, 10, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            pair('About', Text(_subject(e), style: _body(context, size: 12))),
            if (raw) ...[
              if (e.before != null) pair('Before', Text(e.before!, style: code)),
              if (e.after != null) pair('After', Text(e.after!, style: code)),
              if (e.data != null) pair('Details', Text(e.data!, style: code)),
            ] else
              for (final (label, text) in [('Before', e.before), ('After', e.after), ('Details', e.data)])
                if (_rows(text).isNotEmpty)
                  pair(
                    label,
                    Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2, children: [
                      for (final (k, v) in _rows(text))
                        Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 10, children: [
                          ConstrainedBox(constraints: const BoxConstraints(minWidth: 80), child: Text(k, style: _body(context, size: 12, color: t.textMuted))),
                          Expanded(child: Text(v, style: _body(context, size: 12))),
                        ]),
                    ]),
                  ),
            pair('Hash', Text(e.hash, style: code.copyWith(color: t.textMuted))),
            if (e.before != null || e.after != null || e.data != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: UiButton(label: raw ? 'Show as a list' : 'Show the raw data', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: onToggleRaw),
              ),
          ]),
        )),
    ]);
  }
}

/// What the workflow did since the record last started over, for the reset to take back (spec §6
/// reset list): ticked as the engine suggests, changed-since items unticked, and things that can't be
/// undone (sent messages) locked with the reason. The record actions load it into [dialog]; this
/// only shows it. Shows nothing when the API can't list it.
class _WfResetUndoList extends StatelessWidget {
  const _WfResetUndoList({required this.dialog});
  final _ActionDialog dialog;

  static String _kindLabel(String kind) =>
      const {'field': 'Field', 'created': 'New record', 'action': 'Action', 'message': 'Message', 'webhook': 'Webhook', 'move': 'Move'}[kind] ?? wfHumanize(kind);

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final d = dialog;
    final hint = _body(context, size: 12, color: t.textMuted);
    if (d.loading) return Text('Looking up what the workflow did…', style: hint);
    if (d.listError.isNotEmpty) return Text(d.listError, style: hint);
    if (d.loaded && d.items.isEmpty) return Text('Nothing the workflow did needs taking back.', style: hint);
    if (d.items.isEmpty) return const SizedBox.shrink();
    final undoable = [for (final i in d.items) if (i.undoable) i.id];
    void choose(String id, bool on) => d.set(() => d.chosen = on ? {...d.chosen, id} : ({...d.chosen}..remove(id)));
    return Builder(
      builder: (context) {
        final chosen = d.chosen;
        final busy = d.busy;
        final all = chosen.length >= undoable.length;
        return Container(
          padding: EdgeInsets.only(top: t.space3),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            Row(children: [
              const Expanded(child: WfSectionTitle('Also take back')),
              if (undoable.length > 1)
                UiButton(
                  label: all ? 'Select none' : 'Select all',
                  size: UiSize.sm,
                  variant: UiButtonVariant.ghost,
                  onPressed: busy ? null : () => d.set(() => d.chosen = all ? {} : undoable.toSet()),
                ),
            ]),
            Text('What the workflow did since the record last started over. Untick anything that should stay; the workflow carries on either way.',
                style: _body(context, size: 12, color: t.textMuted, height: 1.35)),
            for (final it in d.items)
              Container(
                padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
                decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
                  // Start-aligned: the checkbox's touch target would otherwise centre a short title.
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: UiCheckbox(
                      value: chosen.contains(it.id),
                      onChanged: it.undoable && !busy ? (v) => choose(it.id, v) : null,
                      // Read with the box, so screen readers hear why it is unticked or locked.
                      semanticLabel: it.warning == null ? it.title : '${it.title}. ${it.warning}',
                      child: ExcludeSemantics(
                        child: Text(it.title, style: _body(context, size: 13.5, weight: FontWeight.w600, color: it.undoable ? null : t.textMuted)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      WfChip(_kindLabel(it.kind)),
                      Text([it.workflow, it.step, if (it.detail != null) it.detail!].join(' · '), style: _body(context, size: 12, color: t.textMuted)),
                    ]),
                  ),
                  if (it.warning != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: ExcludeSemantics(child: Text(it.warning!, style: _body(context, size: 12, color: it.undoable ? t.warning : t.textMuted, height: 1.4))),
                    ),
                ]),
              ),
          ]),
        );
      },
    );
  }
}
