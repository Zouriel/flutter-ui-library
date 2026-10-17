import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// An in-memory engine for widget tests: a lifecycle record (application 1) with an open approval,
/// a task inbox, one run, an audit log and settings. Every call is recorded in [calls].
class FakeWorkflowApi extends Fake implements UiWorkflowApi {
  FakeWorkflowApi() {
    reset();
  }

  final List<String> calls = [];
  late Map<String, Object?> recordJson;
  late List<Map<String, Object?>> taskList;
  late Map<String, Object?> instanceJson;
  late Map<String, Object?> instanceDef;
  late List<Map<String, Object?>> auditList;
  UiWorkflowSettings settingsValue = UiWorkflowSettings();
  int settingsRevision = 3;
  List<UiWfTriggerOverview> triggerList = const [];
  UiWorkflowRegistry registry = UiWorkflowRegistry.fromJson({
    'entities': [
      {
        'key': 'application', 'label': 'Application',
        'fields': [
          {'key': 'status', 'label': 'Status', 'type': 'enum', 'lifecycle': true, 'watchable': true},
          {'key': 'amount', 'label': 'Amount', 'type': 'currency', 'settable': true},
          {'key': 'iban', 'label': 'IBAN', 'type': 'text', 'sensitive': true},
        ],
      },
    ],
    'channels': [{'key': 'email', 'label': 'Email'}, {'key': 'inApp', 'label': 'In the app'}],
    'actions': [{'key': 'invoice', 'label': 'Create invoice', 'description': 'Raises an invoice', 'inputs': <Object?>[], 'outputs': <Object?>[]}],
    'signals': [{'key': 'paid', 'label': 'Payment received', 'fields': <Object?>[]}],
  });

  /// Makes the next call fail with this error.
  UiWfApiError? failNext;

  static Map<String, Object?> taskJson(String id, {String title = 'Finance sign-off', bool canDecide = true, String status = 'open', String? outcome, bool overdue = false}) => {
    'id': id, 'instanceId': 'i1', 'kind': 'approval', 'title': title, 'instructions': 'Check the amount.', 'definitionKey': 'review',
    'entity': 'application', 'entityId': '1', 'entityTitle': 'Aminath’s application', 'status': status, 'assignees': ['fin'], 'assigneeNames': ['Finance'],
    'outcomes': [
      {'key': 'approved', 'label': 'Approve', 'tone': 'success'},
      {'key': 'rejected', 'label': 'Reject', 'tone': 'danger'},
    ],
    'decisions': <Object?>[], 'form': null, 'requireComment': 'reject', 'allowDelegation': true, 'outcome': outcome,
    'dueAt': DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String(), 'overdue': overdue, 'escalationLevel': 0,
    'createdAt': DateTime.now().toUtc().toIso8601String(), 'completedAt': null, 'canDecide': canDecide,
  };

  void reset() {
    recordJson = {
      'entity': 'application', 'id': '1', 'title': 'Aminath’s application', 'lifecycle': 'appLife', 'lifecycleTitle': 'Application lifecycle',
      'state': 'review', 'stateLabel': 'In review', 'stateTone': 'info', 'status': 'active',
      'stateEnteredAt': DateTime.now().subtract(const Duration(hours: 3)).toUtc().toIso8601String(),
      'transitions': [
        {'key': 'approve', 'label': 'Approve', 'to': 'approved', 'toLabel': 'Approved', 'tone': 'success', 'confirm': 'Approve this application?', 'form': null},
        {'key': 'withdraw', 'label': 'Withdraw', 'to': 'draft', 'toLabel': 'Draft', 'tone': null, 'confirm': null, 'form': null},
      ],
      'tasks': [taskJson('t1')],
      'instances': <Object?>[],
      'manual': [{'key': 'escalate', 'label': 'Ask for documents', 'form': null}],
      'states': [
        {'key': 'draft', 'label': 'Draft', 'category': 'initial', 'tone': 'neutral'},
        {'key': 'review', 'label': 'In review', 'category': 'active', 'tone': 'info'},
        {'key': 'approved', 'label': 'Approved', 'category': 'terminal', 'tone': 'success'},
      ],
    };
    taskList = [
      for (var i = 1; i <= 3; i++) taskJson('t$i', title: 'Task $i', overdue: i == 2),
    ];
    instanceDef = createWorkflow('automation', title: 'Review', entity: 'application')
        .patch({
          'steps': [
            {'id': 'p', 'type': 'parallel', 'join': {'type': 'all'}, 'paths': [
              {'id': 'p1', 'label': 'Finance', 'steps': [{'id': 'a', 'type': 'webhook', 'title': 'Tell the ERP', 'method': 'POST', 'url': 'https://erp'}]},
              {'id': 'p2', 'label': 'Docs', 'steps': [{'id': 'b', 'type': 'action', 'title': 'Archive documents', 'action': 'invoice'}]},
            ]},
            {'id': 'c', 'type': 'notify', 'title': 'Tell the applicant', 'channel': 'email', 'to': <Object?>[], 'body': 'Done'},
          ],
        })
        .json;
    instanceJson = {
      'id': 'i1', 'definitionId': 'd1', 'definitionKey': 'review', 'title': 'Review', 'version': 2, 'kind': 'automation', 'status': 'incident',
      'error': 'The ERP did not answer.', 'entityTitle': 'Aminath’s application', 'initiatorName': 'Hana',
      'startedAt': DateTime.now().subtract(const Duration(minutes: 30)).toUtc().toIso8601String(), 'updatedAt': '',
      'steps': [
        {'id': 'r1', 'nodeId': 'p', 'type': 'parallel', 'attempt': 1, 'status': 'running', 'startedAt': ''},
        {'id': 'r2', 'nodeId': 'a', 'type': 'webhook', 'attempt': 1, 'status': 'failed', 'error': 'Timed out', 'startedAt': ''},
        {'id': 'r3', 'nodeId': 'b', 'type': 'action', 'attempt': 1, 'status': 'failed', 'error': 'No invoice', 'startedAt': ''},
      ],
      'tokens': [
        {'id': 'tokA', 'status': 'waiting', 'waiting': 'incident', 'stepId': 'a'},
        {'id': 'tokB', 'status': 'waiting', 'waiting': 'incident', 'stepId': 'b'},
      ],
      'tasks': <Object?>[],
    };
    auditList = [
      for (var i = 60; i >= 1; i--)
        {
          'seq': i, 'id': 'e$i', 'at': '2026-10-17T09:${(i % 60).toString().padLeft(2, '0')}:00Z', 'actorType': 'user', 'actorId': 'u$i', 'actorName': i.isEven ? 'Hana' : null,
          'category': i % 3 == 0 ? 'lifecycle' : 'task', 'action': i % 3 == 0 ? 'transitioned' : 'decided', 'subjectType': 'record', 'subjectId': '1',
          'entity': 'application', 'entityId': '1', 'before': '{"state":"draft"}', 'after': '{"state":"review"}', 'data': '{"label":"Submit","outcome":"approved"}',
          'correlationId': 'c', 'prevHash': 'p', 'hash': 'hash$i',
        },
    ];
  }

  Future<T> _do<T>(String call, T Function() f) async {
    calls.add(call);
    final e = failNext;
    if (e != null) {
      failNext = null;
      throw e;
    }
    return f();
  }

  @override
  Future<UiWorkflowSchema> schema() => _do('schema', () => UiWorkflowSchema(registry: registry));

  /// What me() says about intervening.
  bool canIntervene = false;

  @override
  Future<UiWfMe> me() => _do('me', () => UiWfMe.fromJson({'type': 'user', 'id': 'hana', 'can': {'intervene': canIntervene}}));

  static const people = [
    {'id': 'hana', 'name': 'Hana Ibrahim', 'email': 'hana@example.com'},
    {'id': 'ali', 'name': 'Ali Rasheed', 'email': 'ali@example.com'},
    {'id': 'mariyam', 'name': 'Mariyam Saeed'},
  ];

  @override
  Future<List<UiWfUser>> searchUsers(String query, {int take = 20}) => _do('searchUsers:$query', () => [
    for (final u in people)
      if ((u['name'] as String).toLowerCase().contains(query.toLowerCase())) UiWfUser.fromJson(u),
  ]);

  @override
  Future<({UiWorkflowSettings settings, int revision})> settings() => _do('settings', () => (settings: settingsValue, revision: settingsRevision));

  @override
  Future<int> saveSettings(UiWorkflowSettings settings, int revision) => _do('saveSettings:$revision', () {
    settingsValue = settings;
    return ++settingsRevision;
  });

  @override
  Future<List<UiWfTriggerOverview>> triggers() => _do('triggers', () => triggerList);

  @override
  Future<UiWfRecord> record(String entity, String id) => _do('record:$entity/$id', () => UiWfRecord.fromJson(jsonDecode(jsonEncode(recordJson))));

  @override
  Future<List<UiWfAuditEntry>> recordHistory(String entity, String id, {int take = 200}) => _do('history', () => [
    UiWfAuditEntry.fromJson({'seq': 2, 'at': DateTime.now().toUtc().toIso8601String(), 'actorType': 'user', 'actorName': 'Hana', 'category': 'lifecycle', 'action': 'transitioned',
      'before': '{"state":"draft"}', 'after': '{"state":"review"}', 'data': '{"label":"Submit"}'}),
    UiWfAuditEntry.fromJson({'seq': 1, 'at': DateTime.now().toUtc().toIso8601String(), 'actorType': 'system', 'category': 'lifecycle', 'action': 'created', 'after': '{"state":"draft"}'}),
  ]);

  @override
  Future<UiWfRecord> applyTransition(String entity, String id, String key, {UiJson? input}) => _do('apply:$key', () {
    final t = (recordJson['transitions'] as List).cast<Map>().firstWhere((x) => x['key'] == key);
    recordJson = {...recordJson, 'state': t['to'], 'stateLabel': t['toLabel'], 'stateTone': t['tone'], 'transitions': <Object?>[], 'tasks': <Object?>[]};
    return UiWfRecord.fromJson(jsonDecode(jsonEncode(recordJson)));
  });

  /// The input and the ids taken back of the last reset.
  UiJson? lastResetInput;
  List<String>? lastResetUndo;

  /// What [resetPreview] lists; null: the API can't list it.
  List<Map<String, Object?>>? resetItems;

  @override
  Future<UiWfResetPreview> resetPreview(String entity, String id) => _do('resetPreview', () {
    if (resetItems == null) throw UnimplementedError();
    return UiWfResetPreview.fromJson({'reset': recordJson['reset'], 'items': resetItems});
  });

  @override
  Future<UiWfRecord> resetRecord(String entity, String id, {UiJson? input, List<String>? undo}) => _do('reset', () {
    lastResetInput = input;
    lastResetUndo = undo;
    recordJson = {...recordJson, 'state': 'draft', 'stateLabel': 'Draft', 'stateTone': 'neutral', 'tasks': <Object?>[], 'reset': null};
    return UiWfRecord.fromJson(jsonDecode(jsonEncode(recordJson)));
  });

  @override
  Future<UiWfInstance> startManual(String workflow, String? entity, String? id, {UiJson? input}) => _do('manual:$workflow', () => UiWfInstance.fromJson({'id': 'm1'}));

  @override
  Future<UiWfPage<UiWfTask>> tasks(UiWfTaskQuery q) => _do('tasks:${q.status?.join(',')}:${q.take}', () {
    final open = q.status?.contains('open') ?? true;
    final list = open ? taskList : [taskJson('d1', title: 'Old task', status: 'completed', outcome: 'rejected', canDecide: false)];
    return UiWfPage([for (final t in list.take(q.take ?? 25)) UiWfTask.fromJson(t)], list.length);
  });

  @override
  Future<UiWfTask> decide(String id, String outcome, {String? comment, UiJson? data}) => _do('decide:$id:$outcome:${comment ?? ''}', () {
    recordJson = {...recordJson, 'tasks': <Object?>[]};
    taskList = taskList.where((t) => t['id'] != id).toList();
    return UiWfTask.fromJson({...taskJson(id), 'status': 'completed', 'outcome': outcome});
  });

  @override
  Future<UiWfTask> delegate(String id, String to, {String? note}) => _do('delegate:$id:$to', () => UiWfTask.fromJson(taskJson(id)));

  @override
  Future<UiWfInstance> instance(String id) => _do('instance:$id', () => UiWfInstance.fromJson(instanceJson));

  @override
  Future<UiWorkflowDefinition> instanceDefinition(String id) => _do('instanceDefinition:$id', () => UiWorkflowDefinition.fromJson(instanceDef));

  @override
  Future<UiWfInstance> retry(String id, {String? target}) => _do('retry:$id:${target ?? ''}', () => UiWfInstance.fromJson({...instanceJson, 'status': 'running'}));

  @override
  Future<UiWfInstance> skip(String id, {UiJson? outputs, String? target}) => _do('skip:$id:${target ?? ''}', () => UiWfInstance.fromJson({...instanceJson, 'status': 'running'}));

  @override
  Future<UiWfInstance> cancel(String id, {String? reason}) => _do('cancel:$id', () => UiWfInstance.fromJson({...instanceJson, 'status': 'cancelled'}));

  @override
  Future<List<UiWfAuditEntry>> audit(UiWfAuditQuery q) => _do('audit:${q.category ?? ''}:${q.entityId ?? ''}:${q.before ?? ''}', () {
    final list = auditList.where((e) => (q.category == null || e['category'] == q.category) && (q.before == null || (e['seq'] as int) < q.before!));
    return [for (final e in list.take(q.take ?? 50)) UiWfAuditEntry.fromJson(e)];
  });

  @override
  Future<UiWfAuditVerification> verifyAudit({int? fromSeq}) => _do('verify', () => UiWfAuditVerification.fromJson({'valid': true, 'checked': 60}));

  @override
  Future<Uint8List> exportAudit(UiWfAuditQuery q) => _do('export:${q.format}', () => Uint8List.fromList(utf8.encode('seq,at\n')));
}
