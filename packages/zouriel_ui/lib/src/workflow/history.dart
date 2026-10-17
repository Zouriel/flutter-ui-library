import 'dart:convert';

import 'api.dart';
import 'bits.dart';
import 'json.dart';
import 'schema.dart' show UiWfRemarks;

// How the runtime widgets word history and outcomes (the web `runtime-shared.ts`): shared by the
// workflow panel and the task inbox.

/// What to show for a failed call (the web `wfErrorText`): the engine's message with the details
/// it gave (e.g. which field is wrong), else [fallback].
String wfErrorText(Object e, String fallback) {
  if (e is UiWfApiError) {
    final d = e.details;
    final details = d is List ? [for (final x in d) if (x is Map && x['message'] is String) x['message'] as String] : const <String>[];
    return details.isNotEmpty ? '${e.message} ${details.join(' ')}' : e.message;
  }
  return fallback;
}

/// Parses an audit entry's JSON field; a broken one reads as empty rather than throwing.
UiJson wfAuditJson(String? text) {
  if (text == null || text.isEmpty) return const {};
  try {
    return wfMap(jsonDecode(text));
  } catch (_) {
    return const {};
  }
}

/// "someKey" becomes "Some key": the last resort for a key nobody gave a label.
String wfHumanize(String key) {
  final words = key
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll(RegExp(r'[_.-]+'), ' ')
      .trim()
      .toLowerCase();
  return words.isEmpty ? key : words[0].toUpperCase() + words.substring(1);
}

/// A decision's outcome as people read it: the task's own label when known, else a sensible default.
String wfOutcomeLabel(Object? key, [List<({String key, String label})>? outcomes]) {
  final k = key == null ? '' : jsString(key);
  for (final o in outcomes ?? const <({String key, String label})>[]) {
    if (o.key == k) return o.label;
  }
  return const {'approved': 'Approved', 'rejected': 'Rejected', 'timedOut': 'Out of time', 'cancelled': 'Cancelled', 'completed': 'Done'}[k] ??
      (k.isEmpty ? 'Done' : wfHumanize(k));
}

const Map<String, String> _auditActions = {
  'definition.created': 'Workflow created', 'definition.draftSaved': 'Draft saved', 'definition.published': 'Published',
  'definition.archived': 'Archived', 'definition.restored': 'Restored', 'definition.rolledBack': 'Rolled back to an earlier version',
  'definition.deleted': 'Workflow deleted',
  'instance.started': 'Run started', 'instance.queued': 'Run queued', 'instance.completed': 'Run finished', 'instance.failed': 'Run failed',
  'instance.cancelled': 'Run cancelled', 'instance.migrated': 'Run moved to another version', 'instance.retried': 'Stopped step tried again',
  'instance.skipped': 'Stopped step skipped', 'instance.incident': 'Run stopped on an error', 'instance.timerFailed': 'A timer could not run',
  'step.started': 'Step started', 'step.completed': 'Step done', 'step.failed': 'Step failed', 'step.retryScheduled': 'Retry scheduled',
  'step.skipped': 'Step skipped', 'step.branchTaken': 'Path chosen', 'step.waiting': 'Step waiting',
  'lifecycle.created': 'Lifecycle started', 'lifecycle.transitioned': 'Record moved', 'lifecycle.autoTransitioned': 'Moved automatically',
  'lifecycle.autoSkipped': 'Automatic move skipped', 'lifecycle.slaBreached': 'Stayed too long in a state', 'lifecycle.forced': 'Moved by an admin', 'lifecycle.reset': 'Workflow started over',
  'lifecycle.writeRefused': 'Direct state change refused', 'lifecycle.writeObserved': 'Direct state change seen', 'lifecycle.outOfSync': 'State out of sync',
  'task.created': 'Task created', 'task.assigned': 'Task assigned', 'task.reminded': 'Reminder sent', 'task.escalated': 'Task escalated',
  'task.delegated': 'Task handed to someone else', 'task.reassigned': 'Task reassigned', 'task.decided': 'Decided', 'task.cancelled': 'Task cancelled',
  'task.timedOut': 'Task ran out of time',
  'trigger.suppressed': 'Start held back', 'trigger.skipped': 'Start skipped', 'trigger.paused': 'Starts paused', 'trigger.resumed': 'Starts resumed',
  'trigger.failed': 'A workflow could not start',
  'settings.updated': 'Settings changed',
  'audit.exported': 'Audit log exported', 'audit.purged': 'Old entries removed',
};

/// An audit action's label ("lifecycle", "slaBreached" becomes "Stayed too long in a state").
String wfAuditActionLabel(String category, String action) => _auditActions['$category.$action'] ?? wfHumanize(action);

/// How a record history entry reads ("Submit: Draft → Submitted"). [stateLabel] turns state keys into labels.
String wfDescribeHistory(UiWfAuditEntry h, String Function(Object? key) stateLabel) {
  final data = wfAuditJson(h.data), before = wfAuditJson(h.before), after = wfAuditJson(h.after);
  String s(Object? v) => v == null ? '' : jsString(v);
  switch ('${h.category}.${h.action}') {
    case 'lifecycle.created':
      return 'Started in ${stateLabel(after['state'])}';
    case 'lifecycle.transitioned':
      final name = s(data['label'] ?? data['transition']);
      final remark = s(data['comment']);
      return '${name.isEmpty ? 'Moved' : name}: ${stateLabel(before['state'])} $wfArrow ${stateLabel(after['state'])}${remark.isEmpty ? '' : ' (“$remark”)'}';
    case 'lifecycle.autoTransitioned':
      return 'Moved automatically: ${stateLabel(before['state'])} $wfArrow ${stateLabel(after['state'])}';
    case 'lifecycle.autoSkipped':
      return 'An automatic move was skipped';
    case 'lifecycle.reset':
      final input = data['input'] is Map ? wfMap(data['input']) : const <String, Object?>{};
      // The person's remarks, else the reset form's reason.
      final remark = s(data['comment']);
      final why = remark.isNotEmpty ? remark : s(input['reason'] ?? input.values.whereType<String>().firstOrNull);
      final name = s(data['label']);
      final undone = data['undone'] is List ? (data['undone'] as List).length : 0;
      final took = undone == 0 ? '' : ', took back $undone thing${undone == 1 ? '' : 's'} the workflow did';
      return '${name.isEmpty ? 'Reset' : name}: ${stateLabel(before['state'])} $wfArrow ${stateLabel(after['state'])}${why.isEmpty ? '' : ' (“$why”)'}$took';
    case 'lifecycle.forced':
      final why = s(data['reason']);
      return 'Moved by an admin to ${stateLabel(after['state'])}${why.isEmpty ? '' : ': $why'}';
    case 'lifecycle.writeRefused':
      return 'A direct change to the state was refused';
    case 'lifecycle.slaBreached':
      return 'Stayed too long in ${stateLabel(data['state'] ?? before['state'] ?? after['state'])}';
    case 'lifecycle.outOfSync':
      return 'The state was changed outside the workflow';
    case 'task.created':
      return 'Waiting for: ${s(data['title'])}';
    case 'task.decided':
      final label = s(data['outcomeLabel']);
      final c = s(data['comment']);
      return 'Decided: ${label.isEmpty ? wfOutcomeLabel(data['outcome']) : label}${c.isEmpty ? '' : ' (“$c”)'}';
    case 'task.timedOut':
      return 'Ran out of time: ${s(data['title'])}';
    case 'task.delegated':
      return 'A task was handed to someone else';
    case 'task.reassigned':
      return 'A task was reassigned';
    case 'task.escalated':
      return 'A task was escalated';
    case 'instance.started':
      final what = s(data['title'] ?? data['definitionKey']);
      return 'Started: ${what.isEmpty ? 'a workflow' : what}';
    case 'instance.completed':
      return 'A workflow finished';
    case 'instance.failed':
      return 'A workflow failed';
    case 'instance.cancelled':
      return 'A workflow was cancelled';
    case 'instance.incident':
      return 'A workflow stopped on an error';
    case 'instance.timerFailed':
      return 'A timer could not run';
    case 'trigger.failed':
      final e = s(data['error']);
      return 'A workflow could not start${e.isEmpty ? '' : ': $e'}';
    default:
      return wfAuditActionLabel(h.category, h.action);
  }
}

/// How a finished task ended ("Approved", "Out of time", "Cancelled").
String wfTaskResult(UiWfTask t) {
  if (t.status == 'timedOut') return 'Out of time';
  if (t.status == 'cancelled') return 'Cancelled';
  return wfOutcomeLabel(t.outcome, [for (final o in t.outcomes) (key: o.key, label: o.label)]);
}

/// A run's status as people read it; the run view, run lists and the workflow panel all use it.
String wfRunStatusLabel(String? s) {
  if (s == null || s.isEmpty) return '';
  return const {
        'queued': 'Queued', 'running': 'Running', 'waiting': 'Waiting', 'incident': 'Stopped', 'completed': 'Finished',
        'failed': 'Failed', 'cancelled': 'Cancelled', 'active': 'Active', 'outOfSync': 'Out of sync',
      }[s] ??
      wfHumanize(s);
}

/// The tone a run status is shown in.
String wfRunStatusTone(String? s) => switch (s) {
  'completed' => 'success',
  'incident' || 'failed' => 'danger',
  'cancelled' || 'outOfSync' => 'warning',
  _ => 'info',
};

/// The audit log's categories, in the order filters list them.
const List<({String value, String label})> wfAuditCategories = [
  (value: 'lifecycle', label: 'Record moves'), (value: 'task', label: 'Tasks and decisions'), (value: 'instance', label: 'Runs'),
  (value: 'step', label: 'Steps'), (value: 'trigger', label: 'Triggers'), (value: 'definition', label: 'Workflow changes'),
  (value: 'settings', label: 'Settings'), (value: 'audit', label: 'The audit log itself'),
];

/// An audit category's label ("lifecycle" reads "Record moves").
String wfAuditCategoryLabel(String category) => wfAuditCategories.where((c) => c.value == category).firstOrNull?.label ?? wfHumanize(category);

/// Who did something, as people read it (the web `wfActorLabel`): a person's name; for a workflow,
/// "Workflow: <title>" (the actor id is the workflow's key, looked up with [workflowTitle]); "System"
/// for the engine itself.
String wfActorLabel(UiWfAuditEntry e, [String? Function(String key)? workflowTitle]) {
  final name = e.actorName;
  if (e.actorType == 'workflow') {
    final key = e.actorId ?? '';
    // The title when it is known: the engine may store the key as the actor's name.
    final known = workflowTitle?.call(key);
    final title = known != null && known.isNotEmpty ? known : (name != null && name.isNotEmpty ? name : null);
    return 'Workflow: ${title ?? (key.isEmpty ? 'unknown' : wfHumanize(key))}';
  }
  if (name != null && name.isNotEmpty) return name;
  if (e.actorType == 'system') return 'System';
  return e.actorId ?? wfHumanize(e.actorType);
}

/// Whether deciding [outcome] needs remarks (spec §7): always, or for a negative outcome when the
/// step asks for them on rejecting (an approval's "rejected", a task's red outcomes).
bool wfCommentRequired(UiWfTask t, String outcome) {
  if (t.requireComment == 'always') return true;
  if (t.requireComment != 'reject') return false;
  return outcome == 'rejected' || t.outcomes.any((o) => o.key == outcome && o.tone == 'danger');
}

/// How the remarks box is labelled: what it is required for, else optional.
String wfRemarksLabel(UiWfTask t) {
  if (t.requireComment == 'always') return 'Remarks (required)';
  if (t.requireComment == 'reject') {
    final negative = [for (final o in t.outcomes) if (wfCommentRequired(t, o.key)) o.label];
    if (negative.isNotEmpty) {
      return 'Remarks (required to ${negative.length == 1 && negative.first.isNotEmpty ? negative.first.toLowerCase() : 'choose ${negative.join(' or ')}'})';
    }
  }
  return 'Remarks (optional)';
}

/// Whether a move asks for remarks: its setting, else optional for red moves (older engines send none).
UiWfRemarks wfRemarksFor(UiWfTransitionOption t) => t.comment ?? (t.tone == 'danger' ? UiWfRemarks.optional : UiWfRemarks.none);

/// What a parked timer was for, by its purpose (`auto:<transition id>`, `sla:<state id>`,
/// `reminder`, `escalation`): how a sentence starts with it, and how it reads inside one.
const List<(String, String, String)> _timerPurposes = [
  ('auto', 'An automatic move', 'the automatic move'),
  ('sla', 'A time limit', 'the time limit'),
  ('reminder', 'A reminder', 'the reminder'),
  ('escalation', 'An escalation', 'the escalation'),
];

(String, String) _timerPurpose(String purpose) {
  for (final (p, start, inside) in _timerPurposes) {
    if (purpose == p || purpose.startsWith('$p:')) return (start, inside);
  }
  return ('A timer', 'the timer');
}

/// A run's error as people read it (the web `wfReadableError`): without the engine's exception-type
/// prefixes ("InvalidOperationException: Bank API: 503" reads "Bank API: 503"), and a parked timer
/// named by what it was for ("A timer (auto:t2) failed 10 times and was stopped: …" reads "An
/// automatic move failed 10 times and was stopped: …"). The step's own detail keeps the full text.
String wfReadableError(String? error) => (error ?? '')
    .replaceFirstMapped(RegExp(r'^A timer \(([^)]*)\)'), (m) => _timerPurpose(m.group(1)!).$1)
    .replaceAllMapped(RegExp(r'(^|:\s+)[A-Z]\w*Exception:\s*'), (m) => m.group(1)!);

/// The parked timer an incident's error names, as it reads inside a sentence ("the automatic move",
/// "the reminder"; else "the timer").
String wfParkedTimerName(String? error) {
  final m = RegExp(r'^A timer \(([^)]*)\)').firstMatch(error ?? '');
  return _timerPurpose(m?.group(1) ?? '').$2;
}

/// An instance held in `incident` by a timer the engine parked (spec §10: it kept failing) rather
/// than by a stopped step (the web `wfTimerParked`): always so for a lifecycle record instance (it has
/// no steps of its own), and for a run when none of its paths waits on a stopped step and its error is
/// the engine's parked-timer message ("A timer (reminder) failed …"). Retry re-arms the timer and
/// skip drops it.
bool wfTimerParked(UiWfInstance r) {
  if (r.status != 'incident') return false;
  if (r.kind == 'record') return true;
  return !(r.tokens ?? const <UiWfRunToken>[]).any((t) => t.waiting == 'incident') && (r.error ?? '').startsWith('A timer (');
}

/// A stopped workflow as the tasks drawer lists it (the web `wfStoppedLabel`): "title · record"
/// (the record's title, else its id), or just the title when it is about no record.
String wfStoppedLabel(UiWfInstance i) {
  final rec = (i.entityTitle ?? '').isNotEmpty ? i.entityTitle! : (i.entityId ?? '');
  return rec.isNotEmpty ? '${i.title} · $rec' : i.title;
}

/// Whether a finished step ended by running out of time (an approval or task, or a wait, that timed out).
bool wfStepTimedOut(Object? output) => output is Map && (output['outcome'] == 'timedOut' || output['timedOut'] == true);

