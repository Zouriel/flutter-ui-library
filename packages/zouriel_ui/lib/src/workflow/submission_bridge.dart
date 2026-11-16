/// The bridge from a submitted form to a workflow (port of the web `submission-bridge.ts`). The form
/// builder knows nothing about workflows: a form only emits a [UiFormSubmission]. Everything that
/// decides where the answers go (which workflow, which branch, who approves, which queue gets the
/// task) is written in the workflow definition and runs from the submitted payload. This file is the
/// thin, typed hand-over:
///
///  * [wfSubmissionPayload] turns a submission into the plain JSON a workflow start receives;
///  * [wfPickWorkflow] chooses the workflow for it (`workflowId`, `serviceCode`, then form id);
///  * [wfStartFromSubmission] starts it on an engine through [UiWorkflowApi.startManual];
///  * [wfRouteSubmission] walks the definition on the client, with the library's own condition
///    evaluation, and returns the route the answers take (no engine needed);
///  * [wfSubmissionRegistry] describes the answers as a record type, so conditions can be authored
///    against them in the workflow builder (`entity.<answer path>`).
///
/// Conditions in a workflow read the answers as `entity.<path>`, `input.<path>` or `trigger.data.<path>`
/// (the three are the same value), plus `trigger.formId`, `trigger.revision`, `trigger.locale`,
/// `trigger.serviceCode`, `trigger.workflowId`, and `steps.<id>.outcome` of a decided approval or task.
library;

import '../form_builder/engine/conditions.dart' show UiFbConditionContext, evaluateCondition, isEmptyValue;
import '../form_builder/engine/schema.dart' show UiFbCondition, UiFbFieldType, UiFbSubmissionField, UiFormSubmission;
import 'api.dart';
import 'definition.dart' show UiWfToken, stepName;
import 'json.dart';
import 'schema.dart';

// ── Payload ───────────────────────────────────────────────────────────────

/// What a workflow start receives from a submitted form: plain JSON, no picked files.
class UiWfSubmissionPayload {
  const UiWfSubmissionPayload({
    required this.formId,
    required this.revision,
    required this.locale,
    required this.submittedAt,
    this.workflowId,
    this.serviceCode,
    required this.data,
    required this.fields,
  });

  final String formId;
  final num? revision;
  final String locale;
  final String submittedAt;
  final String? workflowId;
  final String? serviceCode;
  final UiJson data;
  final List<UiFbSubmissionField> fields;

  UiJson toJson() => {
    'formId': formId,
    'revision': revision,
    'locale': locale,
    'submittedAt': submittedAt,
    if (workflowId != null) 'workflowId': workflowId,
    if (serviceCode != null) 'serviceCode': serviceCode,
    'data': data,
    'fields': [for (final f in fields) f.toJson()],
  };
}

/// The submission as a workflow payload. Files are dropped (they need an upload address first).
UiWfSubmissionPayload wfSubmissionPayload(UiFormSubmission s) => UiWfSubmissionPayload(
  formId: s.formId,
  revision: s.revision,
  locale: s.locale,
  submittedAt: s.submittedAt,
  workflowId: s.workflowId == null || s.workflowId!.isEmpty ? null : s.workflowId,
  serviceCode: s.serviceCode == null || s.serviceCode!.isEmpty ? null : s.serviceCode,
  data: jsonClone(s.data) as UiJson,
  fields: List.of(s.fields),
);

UiWfSubmissionPayload _payloadOf(Object s) => s is UiWfSubmissionPayload ? s : wfSubmissionPayload(s as UiFormSubmission);

// ── Picking the workflow ──────────────────────────────────────────────────

/// A workflow and what it takes in: the service codes and form ids it is the process for.
class UiWfSubmissionBinding {
  const UiWfSubmissionBinding({required this.workflow, this.serviceCodes, this.formIds});
  final UiWorkflowDefinition workflow;
  final List<String>? serviceCodes;
  final List<String>? formIds;
}

/// The workflow for a submission, or null. [bindings] holds [UiWfSubmissionBinding]s or bare
/// [UiWorkflowDefinition]s. The first match wins, in this order: the submission's [workflowId] (a
/// definition `id` or `key`), its [serviceCode] (a binding's `serviceCodes`), then its [formId] (a
/// binding's `formIds`). A [workflowId] that matches nothing is not guessed around.
UiWorkflowDefinition? wfPickWorkflow(List<Object> bindings, {required String formId, String? workflowId, String? serviceCode}) {
  final list = [for (final b in bindings) b is UiWfSubmissionBinding ? b : UiWfSubmissionBinding(workflow: b as UiWorkflowDefinition)];
  if (workflowId != null && workflowId.isNotEmpty) {
    return list.where((b) => b.workflow.id == workflowId || b.workflow.key == workflowId).firstOrNull?.workflow;
  }
  if (serviceCode != null && serviceCode.isNotEmpty) {
    final hit = list.where((b) => b.serviceCodes?.contains(serviceCode) ?? false).firstOrNull;
    if (hit != null) return hit.workflow;
  }
  return list.where((b) => b.formIds?.contains(formId) ?? false).firstOrNull?.workflow;
}

// ── Starting it on an engine ──────────────────────────────────────────────

/// Starts the workflow on an engine with the submission's answers (`input.*` in the workflow).
/// Throws a [StateError] when the submission has files picked and no upload address (the engine
/// takes JSON only).
Future<UiWfInstance> wfStartFromSubmission(UiWorkflowApi api, UiWorkflowDefinition workflow, UiFormSubmission s) {
  if (s.files.values.any((f) => f.isNotEmpty)) {
    throw StateError('The files picked in this form can’t be sent: the form needs an upload address for them.');
  }
  return api.startManual(workflow.key, null, null, input: wfSubmissionPayload(s).data);
}

// ── Reading answers in conditions ─────────────────────────────────────────

/// The value at a path of the answers: `address.city`, `children[].age` (one value per row).
Object? wfAnswerAt(Object? data, String path) {
  final parts = path.split('.').where((p) => p.isNotEmpty).toList();
  Object? read(Object? v, int i) {
    if (i >= parts.length) return v;
    final p = parts[i];
    final rows = p.endsWith('[]');
    final key = rows ? p.substring(0, p.length - 2) : p;
    final next = v is Map ? v[key] : null;
    if (!rows) return read(next, i + 1);
    return next is List ? [for (final r in next) read(r, i + 1)] : <Object?>[];
  }

  return read(data, 0);
}

class _Ctx implements UiFbConditionContext {
  _Ctx(this.payload, this.outcomes, this._today);
  final UiWfSubmissionPayload payload;
  final Map<String, String> outcomes;
  final String _today;

  @override
  Object? value(String ref) {
    for (final prefix in const ['entity.', 'input.', 'trigger.data.']) {
      if (ref.startsWith(prefix)) return wfAnswerAt(payload.data, ref.substring(prefix.length));
    }
    switch (ref) {
      case 'trigger.formId':
        return payload.formId;
      case 'trigger.revision':
        return payload.revision;
      case 'trigger.locale':
        return payload.locale;
      case 'trigger.serviceCode':
        return payload.serviceCode;
      case 'trigger.workflowId':
        return payload.workflowId;
      case 'trigger.at':
        return payload.submittedAt;
    }
    final m = RegExp(r'^steps\.([^.]+)\.outcome$').firstMatch(ref);
    return m == null ? null : outcomes[m.group(1)];
  }

  @override
  bool visible(String ref) => !isEmptyValue(value(ref));
  @override
  bool complete(String ref) => !isEmptyValue(value(ref));
  @override
  int? rows(String ref) {
    final v = value(ref);
    return v is List ? v.length : 0;
  }

  @override
  String today() => _today;
}

String _todayIso() => DateTime.now().toUtc().toIso8601String().substring(0, 10);

UiFbCondition? _cond(UiWfCondition? c) => UiFbCondition.maybe(c?.json);

/// Whether a workflow condition holds for a submission ([s] is a [UiFormSubmission] or a
/// [UiWfSubmissionPayload]). This is the form builder's own condition evaluation (a workflow
/// condition is its JSON with token paths as `ref`), not a second language.
bool wfConditionHolds(UiWfCondition? when, Object s, {String? today}) =>
    evaluateCondition(_cond(when), _Ctx(_payloadOf(s), {}, today ?? _todayIso()));

// ── The route ─────────────────────────────────────────────────────────────

/// A person or group a step hands work to, with a readable label.
class UiWfRouteAssignee {
  const UiWfRouteAssignee({required this.assignee, required this.label});
  final UiWfAssignee assignee;
  final String label;
}

/// One step the answers pass through, in the order they reach it.
class UiWfRouteStep {
  UiWfRouteStep({required this.stepId, required this.type, required this.title, required this.path, this.assignees = const [], this.queue, this.taken, this.outcome});
  final String stepId;
  final String type;
  final String title;

  /// Where it sits: the branch paths, outcomes and lists it is inside ("Over the limit" › "Approved").
  final List<String> path;
  List<UiWfRouteAssignee> assignees;

  /// For a task: the group (queue) it lands in, when it is assigned to one.
  String? queue;

  /// For a branch, switch: which path was taken.
  String? taken;

  /// For an approval or task: the outcome the walk followed (the `decisions` given, else approved / the first outcome).
  String? outcome;
}

/// Every branch/switch decision: which path it took ([taken] null: nothing matched and there was no "otherwise").
class UiWfRouteDecision {
  const UiWfRouteDecision({required this.stepId, required this.title, required this.taken});
  final String stepId;
  final String title;
  final String? taken;
}

class UiWfRoute {
  const UiWfRoute({
    required this.workflowId,
    required this.workflowKey,
    required this.title,
    required this.steps,
    required this.approvals,
    required this.queues,
    required this.decisions,
    required this.result,
    this.reason,
  });
  final String workflowId;
  final String workflowKey;
  final String title;
  final List<UiWfRouteStep> steps;
  final List<UiWfRouteStep> approvals;

  /// The groups tasks were queued to, in order, without repeats.
  final List<String> queues;
  final List<UiWfRouteDecision> decisions;

  /// How the walk ended: an End step's result, or the end of the steps (`completed`).
  final String result;

  /// The reason of an End step that failed or completed with one.
  final String? reason;
}

String _assigneeLabel(UiWfAssignee a, UiWorkflowRegistry? reg) {
  switch (a.kind) {
    case 'role':
      return reg?.roles?.where((r) => r.key == a.value).firstOrNull?.label ?? a.value;
    case 'group':
      return reg?.groups?.where((g) => g.key == a.value).firstOrNull?.label ?? a.value;
    case 'user':
      return a.value;
    case 'field':
      return 'the person in ${a.value}';
    case 'managerOf':
      return 'the manager of ${a.value}';
    default:
      return 'the person who submitted';
  }
}

String _textOf(UiWfTemplate? t) {
  if (t == null) return '';
  return [for (final p in t.parts) p is UiWfTemplateRef ? '{${p.ref}}' : '$p'].join();
}

/// Walks the workflow's steps with the submission's answers, entirely on the client, and returns the
/// route: the branch paths taken, the steps passed, the approvals and the queues. Only the steps
/// reachable from the trigger are walked. A branch takes its first path whose condition holds, else
/// "otherwise". A switch compares its `on` value (with the answers' normal matching) to each case.
/// Parallel paths are all walked. Approvals follow `approved` and tasks their first outcome unless
/// [decisions] (by step id) says otherwise; waits, loops and go-tos are listed but not entered.
/// [registry] gives roles and groups their labels ("Finance team", not `finance`); [today] is
/// `YYYY-MM-DD`, for conditions on dates.
UiWfRoute wfRouteSubmission(
  UiWorkflowDefinition def,
  Object s, {
  Map<String, String>? decisions,
  UiWorkflowRegistry? registry,
  String? today,
}) {
  final payload = _payloadOf(s);
  final outcomes = <String, String>{};
  final ctx = _Ctx(payload, outcomes, today ?? _todayIso());
  final steps = <UiWfRouteStep>[];
  final taken = <UiWfRouteDecision>[];
  var result = 'completed';
  String? reason;
  var ended = false;

  List<UiWfRouteAssignee> people(Iterable<UiWfAssignee> list) => [for (final a in list) UiWfRouteAssignee(assignee: a, label: _assigneeLabel(a, registry))];

  void walk(List<UiWfStep>? list, List<String> path) {
    for (final step in list ?? const <UiWfStep>[]) {
      if (ended) return;
      if (step.disabled) continue;
      final row = UiWfRouteStep(stepId: step.id, type: step.type, title: stepName(step), path: path);
      switch (step.type) {
        case UiWfStepType.branch:
          final b = UiWfBranchStep.of(step);
          final hit = b.paths.where((p) => evaluateCondition(_cond(p.when), ctx)).firstOrNull;
          final other = b.otherwise;
          final label = hit != null ? (hit.label.isEmpty ? 'If' : hit.label) : other != null ? ((other.label ?? '').isEmpty ? 'Otherwise' : other.label!) : null;
          row.taken = label;
          steps.add(row);
          taken.add(UiWfRouteDecision(stepId: step.id, title: row.title, taken: label));
          if (hit != null) {
            walk(hit.steps, [...path, label!]);
          } else if (other != null) {
            walk(other.steps, [...path, label!]);
          }
        case UiWfStepType.switchStep:
          final sw = UiWfSwitchStep.of(step);
          final on = ctx.value(sw.on);
          final onText = (on is Map && on['value'] != null ? jsString(on['value']) : on == null ? '' : jsString(on)).trim().toLowerCase();
          final hit = sw.cases.where((c) => c.values.any((v) => jsString(v).trim().toLowerCase() == onText)).firstOrNull;
          final other = sw.otherwise;
          final label = hit != null ? hit.label : other != null ? ((other.label ?? '').isEmpty ? 'Otherwise' : other.label!) : null;
          row.taken = label;
          steps.add(row);
          taken.add(UiWfRouteDecision(stepId: step.id, title: row.title, taken: label));
          if (hit != null) {
            walk(hit.steps, [...path, label!]);
          } else if (other != null) {
            walk(other.steps, [...path, label!]);
          }
        case UiWfStepType.parallel:
          steps.add(row);
          for (final p in UiWfParallelStep.of(step).paths) {
            walk(p.steps, [...path, (p.label ?? '').isEmpty ? 'Path' : p.label!]);
          }
        case UiWfStepType.approval:
          final a = UiWfApprovalStep.of(step);
          row.assignees = people(a.assignees);
          final outcome = decisions?[step.id] ?? 'approved';
          row.outcome = outcome;
          outcomes[step.id] = outcome;
          steps.add(row);
          walk(a.outcome(outcome), [...path, outcome == 'approved' ? 'Approved' : outcome == 'rejected' ? 'Rejected' : 'Timed out']);
        case UiWfStepType.task:
          final t = UiWfTaskStep.of(step);
          row.assignees = people(t.assignees);
          final group = t.assignees.where((a) => a.kind == 'group').firstOrNull;
          row.queue = group == null ? null : _assigneeLabel(group, registry);
          final all = t.outcomes;
          final chosen = all.where((o) => o.key == decisions?[step.id]).firstOrNull ?? all.firstOrNull;
          row.outcome = chosen?.key;
          if (chosen != null) outcomes[step.id] = chosen.key;
          steps.add(row);
          if (chosen != null) walk(chosen.steps, [...path, chosen.label]);
        case UiWfStepType.end:
          steps.add(row);
          final e = UiWfEndStep.of(step);
          result = e.result;
          final text = _textOf(e.reason);
          reason = text.isEmpty ? null : text;
          ended = true;
        case UiWfStepType.notify:
          row.assignees = people(UiWfNotifyStep.of(step).to.where((r) => r.kind != 'email'));
          steps.add(row);
        default:
          steps.add(row);
      }
    }
  }

  walk(def.steps, const []);

  final queues = <String>[];
  for (final q in steps.map((x) => x.queue)) {
    if (q != null && q.isNotEmpty && !queues.contains(q)) queues.add(q);
  }
  return UiWfRoute(
    workflowId: def.id,
    workflowKey: def.key,
    title: def.title,
    steps: steps,
    approvals: steps.where((x) => x.type == UiWfStepType.approval).toList(),
    queues: queues,
    decisions: taken,
    result: result,
    reason: reason,
  );
}

// ── Authoring conditions against a form's answers ─────────────────────────

const Map<String, String> _typeOf = {
  'text': 'text', 'textarea': 'longText', 'email': 'email', 'phone': 'phone', 'url': 'url', 'number': 'number', 'currency': 'currency',
  'date': 'date', 'time': 'text', 'select': 'text', 'radio': 'text', 'checkboxes': 'json', 'multiselect': 'json', 'checkbox': 'boolean',
  'toggle': 'boolean', 'rating': 'number', 'slider': 'number', 'file': 'json', 'hidden': 'text', 'calculated': 'number', //
};

/// The workflow field type of a form answer's type (`text` for an unknown one).
String wfFieldTypeOf(UiFbFieldType t) => _typeOf[t.name] ?? 'text';

/// The submission's fields as record fields, keyed by answer path (`address.city`). Files are left out.
List<UiWfFieldDescriptor> wfSubmissionFieldDescriptors(List<UiFbSubmissionField> fields) {
  final seen = <String>{};
  final out = <UiWfFieldDescriptor>[];
  for (final f in fields) {
    if (f.type.name == 'file' || !seen.add(f.path)) continue;
    out.add(UiWfFieldDescriptor.fromJson({'key': f.path, 'label': f.label.isEmpty ? f.key : f.label, 'type': wfFieldTypeOf(f.type), 'readable': true}));
  }
  return out;
}

/// The answers as a record type (`request` by default) for a workflow registry.
UiWfEntityDescriptor wfSubmissionEntity(List<UiFbSubmissionField> fields, {String key = 'request', String label = 'Request'}) =>
    UiWfEntityDescriptor.fromJson({'key': key, 'label': label, 'pluralLabel': '${label}s', 'fields': [for (final f in wfSubmissionFieldDescriptors(fields)) f.json]});

/// A schema for `UiWorkflowBuilder(schema: ...)` that makes the form's answers pickable in
/// conditions (as `entity.<path>`), with the roles, groups and channels the app has. Needs no engine.
UiWorkflowSchema wfSubmissionRegistry(
  List<UiFbSubmissionField> fields, {
  List<UiWfLabelled>? roles,
  List<UiWfLabelled>? groups,
  List<UiWfLabelled>? channels,
  String? entity,
  String? entityLabel,
}) => UiWorkflowSchema.fromJson({
  'specVersion': uiWfSpecVersion,
  'registry': {
    'specVersion': uiWfSpecVersion,
    'entities': [wfSubmissionEntity(fields, key: entity ?? 'request', label: entityLabel ?? 'Request').json],
    if (roles != null) 'roles': [for (final r in roles) r.json],
    if (groups != null) 'groups': [for (final g in groups) g.json],
    if (channels != null) 'channels': [for (final c in channels) c.json],
  },
  'steps': <Object?>[],
});

/// The same answers as condition tokens (`input.<path>` under "Form answers"), for pickers you build yourself.
List<UiWfToken> wfSubmissionTokens(List<UiFbSubmissionField> fields) => [
  for (final f in wfSubmissionFieldDescriptors(fields)) UiWfToken(path: 'input.${f.key}', label: f.label, group: 'Form answers', type: f.type),
];
