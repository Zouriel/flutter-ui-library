import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import 'fake_api.dart';

// Mirrors submission-bridge.spec.ts of @zouriel/ui.

class _Api extends FakeWorkflowApi {
  final List<List<Object?>> started = [];
  @override
  Future<UiWfInstance> startManual(String workflow, String? entity, String? id, {UiJson? input}) async {
    started.add([workflow, entity, id, input]);
    return UiWfInstance.fromJson({'id': 'm1'});
  }
}

UiFormSubmission submission(UiJson data, {String? workflowId = 'wf-leave', String? serviceCode = 'HR-LEAVE', Map<String, List<UiFbPickedFile>> files = const {}}) => UiFormSubmission(
  formId: 'leave',
  revision: 3,
  locale: 'dv',
  values: data,
  submittedAt: '2026-11-16T08:00:00Z',
  workflowId: workflowId,
  serviceCode: serviceCode,
  fields: [
    UiFbSubmissionField(path: 'days', key: 'days', label: 'Days', type: UiFbFieldType.number),
    UiFbSubmissionField(path: 'address.city', key: 'city', label: 'City', type: UiFbFieldType.text),
    UiFbSubmissionField(path: 'children[].age', key: 'age', label: 'Age', type: UiFbFieldType.number),
    UiFbSubmissionField(path: 'cert', key: 'cert', label: 'Certificate', type: UiFbFieldType.file),
  ],
  files: files,
);

UiJson _when(String ref, String op, Object? v, [String match = 'all']) => {
  'match': match,
  'conditions': [
    {'ref': ref, 'op': op, 'value': {'const': v}},
  ],
};

({UiWorkflowDefinition def, String approvalId}) leave({num threshold = 3, UiJson? when}) {
  final branch = createStep('branch').json;
  final approval = createStep('approval').json;
  final task = createStep('task').json;
  final notify = createStep('notify').json;
  final pay = {...task, 'title': 'Pay out', 'assignees': [{'group': 'finance'}]};
  final mgr = {
    ...approval,
    'title': 'Manager approval',
    'assignees': [{'managerOf': 'initiator'}],
    'outcomes': {'approved': [pay], 'rejected': <Object?>[], 'timedOut': <Object?>[]},
  };
  final path = (branch['paths'] as List).first as Map;
  final b = {
    ...branch,
    'title': 'Long leave?',
    'paths': [
      {...path, 'label': 'Over the limit', 'when': when ?? _when('entity.days', 'gt', threshold), 'steps': [mgr]},
    ],
    'otherwise': {...(branch['otherwise'] as Map), 'label': 'Auto-approved', 'steps': [notify]},
  };
  final def = UiWorkflowDefinition.fromJson({
    ...createWorkflow('automation', title: 'Leave request', entity: 'request').json,
    'id': 'wf-leave',
    'key': 'leave',
    'trigger': {'type': 'created'},
    'steps': [b],
  });
  return (def: def, approvalId: mgr['id'] as String);
}

void main() {
  group('wfSubmissionPayload', () {
    test('carries the answers, locale, link and field list, without files', () {
      final p = wfSubmissionPayload(submission({'days': 5}, files: {'cert': [UiFbPickedFile(name: 'a.pdf', size: 1, type: 'application/pdf')]}));
      final j = p.toJson();
      expect({...j}..remove('fields'), {
        'formId': 'leave', 'revision': 3, 'locale': 'dv', 'submittedAt': '2026-11-16T08:00:00Z', 'workflowId': 'wf-leave', 'serviceCode': 'HR-LEAVE',
        'values': {'days': 5},
      });
      expect([for (final f in p.fields) f.path], ['days', 'address.city', 'children[].age', 'cert']);
      expect(j.containsKey('files'), isFalse);
      expect(() => jsonEncode(j), returnsNormally);
    });

    test('omits the link when the host set none', () {
      final p = wfSubmissionPayload(submission({}, workflowId: null, serviceCode: null));
      expect(p.toJson().containsKey('workflowId'), isFalse);
      expect(p.toJson().containsKey('serviceCode'), isFalse);
    });

    test('copies the answers, so a later edit does not reach the payload', () {
      final data = <String, Object?>{'days': 5};
      final p = wfSubmissionPayload(submission(data));
      data['days'] = 9;
      expect(p.values, {'days': 5});
    });
  });

  group('wfPickWorkflow', () {
    final a = leave().def;
    final b = a.patch({'id': 'wf-permit', 'key': 'permit'});
    final list = <Object>[
      UiWfSubmissionBinding(workflow: a, serviceCodes: ['HR-LEAVE']),
      UiWfSubmissionBinding(workflow: b, serviceCodes: ['PERMIT'], formIds: ['permit-form']),
    ];

    test('prefers workflowId (id or key), then serviceCode, then form id', () {
      expect(wfPickWorkflow(list, workflowId: 'wf-permit', serviceCode: 'HR-LEAVE', formId: 'x')!.id, 'wf-permit');
      expect(wfPickWorkflow(list, workflowId: 'leave', formId: 'x')!.id, 'wf-leave');
      expect(wfPickWorkflow(list, serviceCode: 'PERMIT', formId: 'x')!.id, 'wf-permit');
      expect(wfPickWorkflow(list, formId: 'permit-form')!.id, 'wf-permit');
    });

    test('returns null rather than guessing', () {
      expect(wfPickWorkflow(list, workflowId: 'nope', serviceCode: 'PERMIT', formId: 'permit-form'), isNull);
      expect(wfPickWorkflow(list, formId: 'other'), isNull);
      expect(wfPickWorkflow([a], workflowId: 'wf-leave', formId: 'x')!.id, 'wf-leave');
    });
  });

  group('wfRouteSubmission', () {
    test('sends a long leave to the manager, then the finance queue', () {
      final r = wfRouteSubmission(leave().def, submission({'days': 5}));
      expect(r.decisions, hasLength(1));
      expect(r.decisions.single.title, 'Long leave?');
      expect(r.decisions.single.taken, 'Over the limit');
      expect([for (final s in r.steps) s.title], ['Long leave?', 'Manager approval', 'Pay out']);
      expect(r.approvals, hasLength(1));
      expect(r.approvals[0].assignees[0].label, 'the manager of initiator');
      expect(r.queues, ['finance']);
      expect(r.steps[2].path, ['Over the limit', 'Approved']);
      expect(r.result, 'completed');
    });

    test('auto-approves a short leave', () {
      final r = wfRouteSubmission(leave().def, submission({'days': 2}));
      expect(r.decisions[0].taken, 'Auto-approved');
      expect(r.approvals, isEmpty);
      expect(r.queues, isEmpty);
    });

    test('changing the condition in the workflow changes the route for the same answers', () {
      final s = submission({'days': 5});
      expect(wfRouteSubmission(leave(threshold: 3).def, s).queues, ['finance']);
      expect(wfRouteSubmission(leave(threshold: 10).def, s).queues, isEmpty);
    });

    test('follows a decision and reads nested answers and row values', () {
      final l = leave();
      expect(wfRouteSubmission(l.def, submission({'days': 5}), decisions: {l.approvalId: 'rejected'}).queues, isEmpty);
      expect(wfAnswerAt({'address': {'city': 'Malé'}}, 'address.city'), 'Malé');
      expect(wfAnswerAt({'children': [{'age': 4}, {'age': 9}]}, 'children[].age'), [4, 9]);
      final alt = leave(when: _when('trigger.data.address.city', 'eq', 'malé', 'any'));
      expect(wfRouteSubmission(alt.def, submission({'days': 1, 'address': {'city': 'Malé'}})).queues, ['finance']);
    });

    test('accepts a payload and a condition on the link', () {
      final alt = leave(when: _when('trigger.serviceCode', 'eq', 'HR-LEAVE'));
      expect(wfRouteSubmission(alt.def, wfSubmissionPayload(submission({'days': 1}))).queues, ['finance']);
    });

    test('labels roles and groups from the registry', () {
      final registry = UiWorkflowRegistry.fromJson({
        'entities': <Object?>[],
        'groups': [{'key': 'finance', 'label': 'Finance team'}],
      });
      final r = wfRouteSubmission(leave().def, submission({'days': 5}), registry: registry);
      expect(r.queues, ['Finance team']);
    });

    test('walks switches, parallel paths and an end step; lists but does not enter waits', () {
      final sw = createStep('switch').json;
      final c = (sw['cases'] as List).first as Map;
      final par = createStep('parallel').json;
      final pp = (par['paths'] as List).cast<Map>();
      final wait = createStep('wait').json;
      final end = {...createStep('end').json, 'result': 'failed', 'reason': 'Not eligible'};
      final after = createStep('notify').json;
      final def = UiWorkflowDefinition.fromJson({
        ...createWorkflow('automation', title: 'T').json,
        'steps': [
          {...sw, 'on': 'entity.leave_type', 'cases': [
            {...c, 'label': 'Sick', 'values': ['SICK'], 'steps': [wait]},
          ], 'otherwise': {...(sw['otherwise'] as Map), 'steps': <Object?>[]}},
          {...par, 'paths': [
            {...pp[0], 'steps': [createStep('notify').json]},
            {...pp[1], 'steps': [createStep('notify').json]},
          ]},
          end,
          after,
        ],
      });
      final r = wfRouteSubmission(def, submission({'leave_type': 'sick'}));
      expect(r.decisions.single.taken, 'Sick');
      expect([for (final s in r.steps) s.type], ['switch', 'wait', 'parallel', 'notify', 'notify', 'end']);
      expect(r.steps[3].path, ['Path 1']);
      expect(r.steps[4].path, ['Path 2']);
      expect(r.result, 'failed');
      expect(r.reason, 'Not eligible');
      // Nothing matched and no "otherwise": no path taken.
      final none = wfRouteSubmission(UiWorkflowDefinition.fromJson({...def.json, 'steps': [(def.json['steps'] as List).first..['cases'] = <Object?>[]]}), submission({'leave_type': 'sick'}));
      expect(none.decisions.single.taken, 'Otherwise');
    });
  });

  group('wfConditionHolds', () {
    test('uses the form builder condition evaluation on the answers', () {
      final s = submission({'days': 5});
      expect(wfConditionHolds(UiWfCondition.fromJson(_when('entity.days', 'gt', 3)), s), isTrue);
      expect(wfConditionHolds(UiWfCondition.fromJson(_when('input.days', 'lt', 3)), wfSubmissionPayload(s)), isFalse);
      expect(wfConditionHolds(null, s), isTrue);
    });
  });

  group('wfStartFromSubmission', () {
    test('starts the workflow with the answers', () async {
      final api = _Api();
      await wfStartFromSubmission(api, leave().def, submission({'days': 5}));
      expect(api.started, [
        ['leave', null, null, {'days': 5}],
      ]);
    });

    test('refuses files that have no upload address', () {
      expect(
        () => wfStartFromSubmission(_Api(), leave().def, submission({}, files: {'cert': [UiFbPickedFile(name: 'a.pdf', size: 1, type: 'application/pdf')]})),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('files'))),
      );
    });
  });

  group('field hints', () {
    test('describes the answers as a record type for the builder and as tokens', () {
      final fields = submission({}).fields;
      final schema = wfSubmissionRegistry(fields, roles: [UiWfLabelled.fromJson({'key': 'manager', 'label': 'Manager'})]);
      final e = schema.registry.entities[0];
      expect(e.key, 'request');
      expect([for (final f in e.fields) [f.key, f.type]], [
        ['days', 'number'],
        ['address.city', 'text'],
        ['children[].age', 'number'],
      ]);
      expect(schema.registry.roles, hasLength(1));
      final t = wfSubmissionTokens(fields).first;
      expect([t.path, t.label, t.group, t.type], ['input.days', 'Days', 'Form answers', 'number']);
    });

    test('maps every field type', () {
      expect(wfFieldTypeOf(UiFbFieldType.textarea), 'longText');
      expect(wfFieldTypeOf(UiFbFieldType.checkboxes), 'json');
      expect(wfFieldTypeOf(UiFbFieldType.toggle), 'boolean');
      expect(wfFieldTypeOf(const UiFbFieldType('unknown')), 'text');
    });
  });

  group('wfFormFields with localized labels', () {
    test('resolves a label in the asked language, else the default', () {
      final form = {
        'defaultLocale': 'en',
        'pages': [
          {'id': 'p', 'elements': [{'kind': 'field', 'key': 'days', 'label': {'en': 'Days', 'dv': 'ދުވަސް'}}]},
        ],
      };
      expect(wfFormFields(form), [(key: 'days', label: 'Days')]);
      expect(wfFormFields(form, 'dv'), [(key: 'days', label: 'ދުވަސް')]);
    });
  });
}
