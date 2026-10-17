import 'dart:convert';

import 'api.dart';
import 'bits.dart';
import 'json.dart';

// How the runtime widgets word history and outcomes (the web `runtime-shared.ts`): shared by the
// record panel and the workflow panel.

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
      return '${name.isEmpty ? 'Moved' : name}: ${stateLabel(before['state'])} $wfArrow ${stateLabel(after['state'])}';
    case 'lifecycle.autoTransitioned':
      return 'Moved automatically: ${stateLabel(before['state'])} $wfArrow ${stateLabel(after['state'])}';
    case 'lifecycle.autoSkipped':
      return 'An automatic move was skipped';
    case 'lifecycle.reset':
      final input = data['input'] is Map ? wfMap(data['input']) : const <String, Object?>{};
      final why = s(input['reason'] ?? input.values.whereType<String>().firstOrNull);
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

/// A run's status as people read it; the run view, run lists and the record panel all use it.
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
    final title = (name != null && name.isNotEmpty) ? name : workflowTitle?.call(key);
    return 'Workflow: ${title ?? (key.isEmpty ? 'unknown' : wfHumanize(key))}';
  }
  if (name != null && name.isNotEmpty) return name;
  if (e.actorType == 'system') return 'System';
  return e.actorId ?? wfHumanize(e.actorType);
}

/// Whether a finished step ended by running out of time (an approval or task, or a wait, that timed out).
bool wfStepTimedOut(Object? output) => output is Map && (output['outcome'] == 'timedOut' || output['timedOut'] == true);

