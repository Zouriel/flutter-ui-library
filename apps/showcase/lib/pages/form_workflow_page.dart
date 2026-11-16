import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

const _json = JsonEncoder.withIndent('  ');

const String _workflowId = 'wf-leave';
const String _serviceCode = 'HR-LEAVE';

/// The leave request. English and Dhivehi labels live in the form; the routing lives in the workflow.
final Map<String, Object?> _leaveForm = {
  'schemaVersion': 2,
  'id': 'leave-request',
  'title': {'en': 'Leave request', 'dv': 'ލީވް އެދުން'},
  'revision': 1,
  'defaultLocale': 'en',
  'supportedLocales': [
    {'code': 'en'},
    {'code': 'dv'},
  ],
  'pages': [
    {
      'id': 'p1',
      'elements': [
        {'kind': 'field', 'id': 'f_name', 'type': 'text', 'key': 'employee', 'label': {'en': 'Your name', 'dv': 'ނަން'}, 'required': true},
        {
          'kind': 'field', 'id': 'f_type', 'type': 'select', 'key': 'leave_type', 'label': {'en': 'Kind of leave', 'dv': 'ލީވްގެ ބާވަތް'}, 'required': true,
          'options': [
            {'id': 'o1', 'value': 'annual', 'label': {'en': 'Annual leave', 'dv': 'އަހަރީ ލީވް'}},
            {'id': 'o2', 'value': 'sick', 'label': {'en': 'Sick leave', 'dv': 'ބަލިމީހާގެ ލީވް'}},
          ],
        },
        {'kind': 'field', 'id': 'f_days', 'type': 'number', 'key': 'days', 'label': {'en': 'Days', 'dv': 'ދުވަސް'}, 'required': true, 'props': {'min': 1, 'max': 60}},
        {'kind': 'field', 'id': 'f_why', 'type': 'textarea', 'key': 'reason', 'label': {'en': 'Reason', 'dv': 'ސަބަބު'}},
      ],
    },
  ],
};

/// Longer than 3 days: the manager signs it off, then finance pays it out. Otherwise nobody needs to look.
UiWorkflowDefinition _leaveWorkflow() {
  final branch = createStep('branch').json;
  final approval = createStep('approval').json;
  final pay = createStep('task').json;
  final notify = createStep('notify').json;
  final payTask = {
    ...pay,
    'title': 'Adjust the leave balance',
    'assignees': [{'group': 'finance'}],
    'outcomes': [
      {...((pay['outcomes'] as List).first as Map).cast<String, Object?>(), 'label': 'Done'},
    ],
  };
  final manager = {
    ...approval,
    'title': 'Manager approval',
    'assignees': [{'role': 'manager'}],
    'outcomes': {'approved': [payTask], 'rejected': <Object?>[], 'timedOut': <Object?>[]},
  };
  final path = ((branch['paths'] as List).first as Map).cast<String, Object?>();
  final step = {
    ...branch,
    'title': 'How long is the leave?',
    'paths': [
      {
        ...path,
        'label': 'More than 3 days',
        'when': {'match': 'all', 'conditions': [{'ref': 'entity.days', 'op': 'gt', 'value': {'const': 3}}]},
        'steps': [manager],
      },
    ],
    'otherwise': {...(branch['otherwise'] as Map).cast<String, Object?>(), 'label': '3 days or fewer', 'steps': [{...notify, 'title': 'Tell the employee: approved'}]},
  };
  final base = createWorkflow('automation', title: 'Leave approval', entity: 'request').json;
  return UiWorkflowDefinition.fromJson({
    ...base,
    'id': _workflowId,
    'key': 'leave',
    'trigger': {'type': 'created', 'label': 'A leave request is submitted'},
    'steps': [step],
  });
}

/// The ids of every approval step anywhere in [json] (steps nest in paths, outcomes and cases).
void _approvalIds(Object? json, List<String> out) {
  if (json is Map) {
    if (json['type'] == 'approval' && json['id'] is String) out.add(json['id'] as String);
    for (final v in json.values) {
      _approvalIds(v, out);
    }
  } else if (json is List) {
    for (final v in json) {
      _approvalIds(v, out);
    }
  }
}

/// Integration: a submitted form becomes a workflow run. The form holds no routing; the workflow holds no questions.
class FormWorkflowPage extends StatefulWidget {
  const FormWorkflowPage({super.key});

  @override
  State<FormWorkflowPage> createState() => _FormWorkflowPageState();
}

class _FormWorkflowPageState extends State<FormWorkflowPage> {
  final UiFormDefinition _form = migrateDefinition(_leaveForm);
  late UiWorkflowDefinition _workflow = _leaveWorkflow();
  late final UiWorkflowSchema _schema = wfSubmissionRegistry(
    fbSubmissionFields(_form),
    entity: 'request',
    entityLabel: 'Leave request',
    roles: [UiWfLabelled.fromJson({'key': 'manager', 'label': 'Line manager'})],
    groups: [UiWfLabelled.fromJson({'key': 'finance', 'label': 'Finance queue'})],
  );
  String _locale = 'en';
  String _decision = 'approved';
  UiFormSubmission? _last;

  UiWorkflowDefinition? get _picked => _last == null
      ? null
      : wfPickWorkflow(
          [UiWfSubmissionBinding(workflow: _workflow, serviceCodes: [_serviceCode], formIds: [_form.id])],
          formId: _last!.formId,
          workflowId: _last!.workflowId,
          serviceCode: _last!.serviceCode,
        );

  /// Recomputed on every build, so a changed condition changes the route for the same answers.
  UiWfRoute? get _route {
    final s = _last;
    final w = _picked;
    if (s == null || w == null) return null;
    final ids = <String>[];
    _approvalIds(w.json, ids);
    return wfRouteSubmission(w, s, decisions: {for (final id in ids) id: _decision}, registry: _schema.registry);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final size = MediaQuery.sizeOf(context);
    final locales = fbLocales(_form);
    final label = context.uiText.caption.copyWith(color: t.textMuted);

    return DocPage(
      eyebrow: 'Integration',
      title: 'Form → workflow',
      lead: 'A form only collects answers. What happens next (who approves, which queue gets the work) is written in a workflow, and it reads '
          'the submitted answers. The form builder holds no routing, and the workflow builder holds no questions. A small bridge in the '
          'workflow area (submission_bridge) hands one to the other.',
      children: [
        DocSection(
          name: 'Live example',
          widget: 'UiFormRenderer → wfRouteSubmission → UiWorkflowBuilder',
          summary: 'Submit the leave request below, in English or Dhivehi. The workflow decides the route from the answers: more than 3 days '
              'goes to the manager, then the finance queue; otherwise it is approved on its own. Then change the condition in the builder '
              '(select the branch, edit its condition): the route under it changes at once for the same answers. Everything here runs on the device.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space4, children: [
            UiText('1. The form (knows nothing about the workflow)', variant: UiTextVariant.label),
            Align(
              alignment: Alignment.centerLeft,
              child: UiSegmented<String>(
                label: 'Form language',
                size: UiSize.sm,
                value: _locale,
                onChanged: (v) => setState(() => _locale = v),
                options: [for (final l in locales) UiSegmentedOption(value: l.code, label: l.label)],
              ),
            ),
            UiFormRenderer(
              definition: _form,
              locale: _locale,
              link: const UiFbSubmissionLink(workflowId: _workflowId, serviceCode: _serviceCode),
              onSubmitted: (s) => setState(() => _last = s),
            ),
            UiText('2. The workflow (owns the routing)', variant: UiTextVariant.label),
            Container(
              height: (size.height - 160).clamp(520, 700),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
              child: UiWorkflowBuilder(definition: _workflow, schema: _schema, onChanged: (d) => setState(() => _workflow = d)),
            ),
            UiText('3. What the bridge did', variant: UiTextVariant.label),
            ..._result(context, label),
          ]),
        ),
        DocSection(
          name: 'Integrating it',
          widget: 'submission_bridge',
          summary: 'Five calls. The bridge is pure and needs no engine to preview; with an engine, wfStartFromSubmission starts the real run '
              'through the API client\'s startManual and the engine routes it from the same definition.',
          code: '''// 1. The host links the form to a process. The form definition never holds this.
UiFormRenderer(
  definition: form,
  locale: 'dv',
  link: UiFbSubmissionLink(workflowId: 'wf-leave', serviceCode: 'HR-LEAVE'),
  onSubmitted: onSubmit,
)

Future<void> onSubmit(UiFormSubmission s) async {
  // 2. Which workflow? workflowId, then serviceCode, then form id. null: nothing is bound.
  final wf = wfPickWorkflow(bindings, formId: s.formId, workflowId: s.workflowId, serviceCode: s.serviceCode);
  if (wf == null) return;

  // 3a. Preview on the client: the route the answers take (branches, approvals, queues).
  final route = wfRouteSubmission(wf, s, registry: registry);

  // 3b. Or start it on the engine: the answers arrive as input.* and the engine routes them.
  final run = await wfStartFromSubmission(api, wf, s);
}

// 4. Author conditions against the form's answers in the workflow builder (no engine needed):
UiWorkflowBuilder(definition: wf, schema: wfSubmissionRegistry(fbSubmissionFields(form)), onChanged: save)''',
        ),
        DocSection(
          name: 'Bridge API',
          widget: 'functions',
          summary: 'The form builder\'s own condition language is reused: a workflow condition is its JSON with token paths as ref. In a workflow, '
              'an answer is entity.days (the form\'s answers shown as a record type), input.days or trigger.data.days. Link and form details '
              'are trigger.formId, trigger.locale, trigger.serviceCode and trigger.workflowId.',
          code: '''class UiWfRoute {
  String workflowId, workflowKey, title;
  List<UiWfRouteStep> steps;        // in order: stepId, type, title, path, assignees, queue, taken, outcome
  List<UiWfRouteStep> approvals;    // the approval steps reached
  List<String> queues;              // groups tasks were queued to
  List<UiWfRouteDecision> decisions; // each branch / switch: stepId, title, taken (null: nothing matched)
  String result;                    // 'completed' | 'failed'
  String? reason;
}''',
          api: const [
            ApiRow('wfSubmissionPayload(s)', 'UiFormSubmission → UiWfSubmissionPayload', 'The plain JSON a workflow start receives: formId, revision, locale, submittedAt, workflowId, serviceCode, data, fields. No picked files.'),
            ApiRow('wfPickWorkflow(list, formId:, workflowId:, serviceCode:)', 'List<Object> → UiWorkflowDefinition?', 'By workflowId (a definition id or key), else serviceCode (binding.serviceCodes), else formId (binding.formIds). A workflowId that matches nothing returns null. The list holds UiWfSubmissionBindings or bare definitions.'),
            ApiRow('wfStartFromSubmission(api, wf, s)', 'Future<UiWfInstance>', 'Starts the workflow on an engine with the answers as input. Throws a StateError when files were picked and have no upload address.'),
            ApiRow('wfRouteSubmission(wf, s, ...)', 'decisions:, registry:, today: → UiWfRoute', 'Client-side route. A branch takes its first path whose condition holds, else otherwise; a switch compares its value to each case; parallel paths are all walked; approvals follow approved (or decisions[stepId]); tasks follow their first outcome. Waits, loops and go-tos are listed, not entered.'),
            ApiRow('wfConditionHolds(when, s)', '(UiWfCondition?, Object) → bool', 'One workflow condition against a submission (or payload), with the form builder\'s own evaluation.'),
            ApiRow('wfSubmissionRegistry(fields, ...)', 'roles:, groups:, channels:, entity:, entityLabel: → UiWorkflowSchema', 'The answers as a record type for UiWorkflowBuilder(schema:), so conditions can be picked as entity.<answer path>.'),
            ApiRow('wfSubmissionEntity / wfSubmissionTokens', '(fields) → UiWfEntityDescriptor / List<UiWfToken>', 'The same hints as a record type for your own registry, or as input.<path> tokens under "Form answers".'),
            ApiRow('wfAnswerAt(data, path)', '(Object?, String) → Object?', 'Reads address.city or children[].age (one value per row) from the answers.'),
          ],
        ),
      ],
    );
  }

  List<Widget> _result(BuildContext context, TextStyle label) {
    final t = context.ui;
    final s = _last;
    if (s == null) return [UiText('Submit the form to see the payload, the picked workflow and the route.', color: t.textMuted)];
    final picked = _picked;
    final route = _route;
    return [
      Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: 130, child: Text('Picked workflow', style: label)),
        if (picked != null) ...[UiBadge(label: picked.title, tone: UiStatus.primary), Text(picked.id, style: label)] else const UiBadge(label: 'none matched', tone: UiStatus.danger),
      ]),
      Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: 130, child: Text('Manager decides', style: label)),
        UiSegmented<String>(
          label: 'Manager decision',
          size: UiSize.sm,
          value: _decision,
          onChanged: (v) => setState(() => _decision = v),
          options: const [UiSegmentedOption(value: 'approved', label: 'Approves'), UiSegmentedOption(value: 'rejected', label: 'Rejects')],
        ),
      ]),
      if (route == null)
        UiText('No workflow is bound to this submission, so nothing was started.', color: t.textMuted)
      else ...[
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
          for (final st in route.steps)
            Padding(
              padding: EdgeInsetsDirectional.only(start: st.path.length * 18.0),
              child: Wrap(spacing: t.space2, runSpacing: t.space1, crossAxisAlignment: WrapCrossAlignment.center, children: [
                UiText(st.title, variant: UiTextVariant.label),
                if (st.taken != null) UiText('took “${st.taken}”', color: t.textMuted),
                if (st.type == 'approval') UiWorkflowStateBadge(label: 'Approval · ${st.outcome}', tone: st.outcome == 'approved' ? 'success' : 'danger'),
                if (st.queue != null) UiWorkflowStateBadge(label: 'Queue · ${st.queue}', tone: 'info'),
                if (st.assignees.isNotEmpty) UiText('for ${st.assignees.map((a) => a.label).join(', ')}', color: t.textMuted),
              ]),
            ),
        ]),
        Wrap(spacing: t.space2, runSpacing: t.space2, children: [
          UiWorkflowStateBadge(label: route.approvals.isNotEmpty ? '${route.approvals.length} approval(s)' : 'No approval needed', tone: route.approvals.isNotEmpty ? 'warning' : 'success'),
          UiWorkflowStateBadge(label: route.queues.isNotEmpty ? 'Queue: ${route.queues.join(', ')}' : 'No queue', tone: route.queues.isNotEmpty ? 'info' : 'neutral'),
        ]),
      ],
      UiText('The payload the workflow receives', variant: UiTextVariant.label),
      DocCode(code: _json.convert(wfSubmissionPayload(s).toJson()), language: 'JSON'),
    ];
  }
}
