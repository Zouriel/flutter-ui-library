import 'dart:convert';
import 'dart:typed_data';

import 'package:zouriel_ui/zouriel_ui.dart';

/// An in-memory workflow engine for the showcase: a small scholarship office (applications with a
/// lifecycle, a finance approval, documents), so every workflow widget works offline. It keeps
/// definitions, versions, one record, its tasks and an audit trail, and checks definitions with a
/// few simple rules. The web showcase talks to the real .NET engine instead; apps use
/// [UiWorkflowHttpApi].
/// A deep copy of JSON.
Object? _clone(Object? v) => v == null ? null : jsonDecode(jsonEncode(v));

class DemoWorkflowApi implements UiWorkflowApi {
  DemoWorkflowApi() {
    reset();
  }

  static final UiWorkflowRegistry registry = UiWorkflowRegistry.fromJson({
    'specVersion': 1,
    'entities': [
      {
        'key': 'application', 'label': 'Application', 'pluralLabel': 'Applications', 'titleField': 'title',
        'fields': [
          {'key': 'title', 'label': 'Title', 'type': 'text', 'watchable': true, 'settable': true},
          {
            'key': 'status', 'label': 'Status', 'type': 'enum', 'watchable': true, 'lifecycle': true,
            'options': [
              {'value': 'draft', 'label': 'Draft'}, {'value': 'submitted', 'label': 'Submitted'}, {'value': 'review', 'label': 'In review'},
              {'value': 'approved', 'label': 'Approved'}, {'value': 'rejected', 'label': 'Rejected'},
            ],
          },
          {'key': 'priority', 'label': 'Priority', 'type': 'enum', 'watchable': true, 'settable': true, 'options': [{'value': 'normal', 'label': 'Normal'}, {'value': 'urgent', 'label': 'Urgent'}]},
          {'key': 'amount', 'label': 'Amount', 'type': 'currency', 'watchable': true, 'settable': true},
          {'key': 'applicant', 'label': 'Applicant', 'type': 'user'},
          {'key': 'reviewer', 'label': 'Reviewer', 'type': 'user', 'watchable': true, 'settable': true},
          {'key': 'deadline', 'label': 'Deadline', 'type': 'date', 'watchable': true, 'settable': true},
          {'key': 'paid', 'label': 'Paid', 'type': 'boolean', 'watchable': true, 'settable': true},
          {'key': 'notes', 'label': 'Notes', 'type': 'longText', 'settable': true, 'sensitive': true},
          {'key': 'documents', 'label': 'Documents', 'type': 'collection', 'entity': 'document'},
        ],
      },
      {
        'key': 'document', 'label': 'Document',
        'fields': [{'key': 'name', 'label': 'Name', 'type': 'text'}, {'key': 'verified', 'label': 'Verified', 'type': 'boolean', 'settable': true}],
      },
    ],
    'actions': [
      {
        'key': 'finance.createInvoice', 'label': 'Create invoice', 'category': 'Finance', 'description': 'Raises an invoice in the finance system.',
        'inputs': [{'key': 'amount', 'label': 'Amount', 'type': 'currency', 'required': true}],
        'outputs': [{'key': 'invoiceNo', 'label': 'Invoice number', 'type': 'text'}],
      },
    ],
    'signals': [
      {'key': 'payment.received', 'label': 'Payment received', 'entity': 'application', 'fields': [{'key': 'amount', 'label': 'Amount paid', 'type': 'currency'}]},
    ],
    'channels': [{'key': 'email', 'label': 'Email'}, {'key': 'inApp', 'label': 'In-app message'}],
    'roles': [{'key': 'reviewer', 'label': 'Reviewers'}, {'key': 'finance', 'label': 'Finance'}, {'key': 'admin', 'label': 'Admins'}],
    'groups': [{'key': 'committee', 'label': 'Scholarship committee'}],
  });

  static const _users = [
    {'id': 'ali', 'name': 'Ali Rasheed', 'email': 'ali@example.com', 'roles': ['applicant']},
    {'id': 'hana', 'name': 'Hana Ibrahim', 'email': 'hana@example.com', 'roles': ['reviewer']},
    {'id': 'mariyam', 'name': 'Mariyam Saeed', 'email': 'mariyam@example.com', 'roles': ['finance']},
  ];

  /// The lifecycle the record panel uses (published, so automations can be triggered by it).
  static UiWorkflowDefinition statusLifecycle() => UiWorkflowDefinition.fromJson({
    'specVersion': 1, 'id': 'wf_status', 'key': 'applicationStatus', 'kind': 'lifecycle', 'title': 'Application status', 'entity': 'application',
    'lifecycle': {
      'field': 'status', 'mode': 'enforce',
      'states': [
        {'id': 'st_draft', 'key': 'draft', 'label': 'Draft', 'category': 'initial', 'tone': 'neutral'},
        {'id': 'st_review', 'key': 'review', 'label': 'In review', 'category': 'active', 'tone': 'info', 'sla': {'within': 'P5D', 'steps': <Object?>[]}},
        {'id': 'st_approved', 'key': 'approved', 'label': 'Approved', 'category': 'terminal', 'tone': 'success'},
        {'id': 'st_rejected', 'key': 'rejected', 'label': 'Rejected', 'category': 'terminal', 'tone': 'danger'},
      ],
      'transitions': [
        {'id': 'tr_submit', 'key': 'submit', 'label': 'Submit', 'from': ['st_draft'], 'to': 'st_review', 'who': [{'field': 'entity.applicant'}], 'tone': 'primary'},
        {'id': 'tr_approve', 'key': 'approve', 'label': 'Approve', 'from': ['st_review'], 'to': 'st_approved', 'who': [{'role': 'reviewer'}], 'tone': 'success', 'confirm': 'Approve this application?'},
        {'id': 'tr_reject', 'key': 'reject', 'label': 'Reject', 'from': ['st_review'], 'to': 'st_rejected', 'who': [{'role': 'reviewer'}], 'tone': 'danger'},
        {'id': 'tr_back', 'key': 'sendBack', 'label': 'Send back', 'from': ['st_review'], 'to': 'st_draft', 'who': [{'role': 'reviewer'}]},
        {'id': 'tr_withdraw', 'key': 'withdraw', 'label': 'Withdraw', 'from': '*', 'to': 'st_rejected', 'who': [{'field': 'entity.applicant'}]},
      ],
    },
  });

  /// A finished automation: a finance approval for large amounts.
  static UiWorkflowDefinition financeCheck() => UiWorkflowDefinition.fromJson({
    'specVersion': 1, 'id': 'wf_finance', 'key': 'financeCheck', 'kind': 'automation', 'title': 'Finance check', 'entity': 'application',
    'trigger': {'type': 'stateEntered', 'lifecycle': 'applicationStatus', 'states': ['review']},
    'steps': [
      {
        'id': 's_big', 'type': 'branch', 'title': 'Large amount?',
        'paths': [{
          'id': 'p_big', 'label': 'Over 5,000', 'when': {'match': 'all', 'conditions': [{'ref': 'entity.amount', 'op': 'gt', 'value': {'const': 5000}}]},
          'steps': [{
            'id': 's_fin', 'type': 'approval', 'title': 'Finance sign-off', 'assignees': [{'role': 'finance'}], 'rule': {'type': 'any'}, 'due': 'P3D', 'reminders': ['P1D'],
            'outcomes': {
              'approved': [{'id': 's_inv', 'type': 'action', 'action': 'finance.createInvoice', 'input': {'amount': {'ref': 'entity.amount'}}}],
              'rejected': [{'id': 's_tell', 'type': 'notify', 'channel': 'email', 'to': [{'field': 'entity.applicant'}], 'subject': 'About your application', 'body': ['Finance could not approve ', {'ref': 'entity.title'}, '.']}],
              'timedOut': <Object?>[],
            },
          }],
        }],
        'otherwise': {'id': 'l_small', 'label': 'Otherwise', 'steps': <Object?>[]},
      },
    ],
  });

  late Map<String, Map<String, Object?>> _defs;
  late Map<String, Object?> _record;
  late List<Map<String, Object?>> _tasks;
  late List<Map<String, Object?>> _audit;
  late Map<String, Object?> _run;
  UiWorkflowSettings _settings = UiWorkflowSettings();
  int _settingsRevision = 1;
  int _seq = 0;

  String _now() => DateTime.now().toUtc().toIso8601String();
  String _ago(Duration d) => DateTime.now().toUtc().subtract(d).toIso8601String();

  /// Puts the office back as it started.
  void reset() {
    _seq = 0;
    final status = statusLifecycle();
    final finance = financeCheck();
    _defs = {
      status.id: {'draft': status.json, 'published': _clone(status.json), 'status': 'published', 'version': 1, 'versions': [_version(1, 'First version')], 'updatedAt': _ago(const Duration(days: 9))},
      finance.id: {'draft': finance.json, 'published': _clone(finance.json), 'status': 'published', 'version': 1, 'versions': [_version(1, 'Finance signs off large amounts')], 'updatedAt': _ago(const Duration(days: 7))},
    };
    _record = {
      'entity': 'application', 'id': '1', 'title': 'Marine biology degree, Ali Rasheed', 'lifecycle': 'applicationStatus', 'lifecycleTitle': 'Application status',
      'state': 'review', 'stateLabel': 'In review', 'stateTone': 'info', 'status': 'active', 'stateEnteredAt': _ago(const Duration(hours: 3)),
      'transitions': _transitionsFrom('review'),
      'instances': <Object?>[],
      'manual': [{'key': 'askDocuments', 'label': 'Ask for documents', 'form': null}],
      'states': [
        {'key': 'draft', 'label': 'Draft', 'category': 'initial', 'tone': 'neutral'}, {'key': 'review', 'label': 'In review', 'category': 'active', 'tone': 'info'},
        {'key': 'approved', 'label': 'Approved', 'category': 'terminal', 'tone': 'success'}, {'key': 'rejected', 'label': 'Rejected', 'category': 'terminal', 'tone': 'danger'},
      ],
    };
    _tasks = [
      _task('t1', 'Finance sign-off', 'approval', due: const Duration(days: 2)),
      _task('t2', 'Check the transcript', 'task', due: const Duration(hours: -5), overdue: true),
    ];
    _audit = [];
    _log('lifecycle', 'created', after: {'state': 'draft'}, actor: 'Ali Rasheed', at: _ago(const Duration(days: 1)));
    _log('lifecycle', 'transitioned', before: {'state': 'draft'}, after: {'state': 'review'}, data: {'transition': 'submit', 'label': 'Submit'}, actor: 'Ali Rasheed', at: _ago(const Duration(hours: 3)));
    _log('task', 'created', data: {'title': 'Finance sign-off'}, at: _ago(const Duration(hours: 3)));
    _run = {
      'id': 'run1', 'definitionId': finance.id, 'definitionKey': finance.key, 'title': finance.title, 'version': 1, 'kind': 'automation',
      'entity': 'application', 'entityId': '1', 'entityTitle': _record['title'], 'status': 'waiting', 'initiatorName': 'Ali Rasheed',
      'startedAt': _ago(const Duration(hours: 3)), 'updatedAt': _ago(const Duration(hours: 3)),
      'steps': [
        {'id': 'r1', 'nodeId': 's_big', 'type': 'branch', 'attempt': 1, 'status': 'completed', 'startedAt': _ago(const Duration(hours: 3))},
        {'id': 'r2', 'nodeId': 's_fin', 'type': 'approval', 'attempt': 1, 'status': 'waiting', 'startedAt': _ago(const Duration(hours: 3))},
      ],
      'tokens': [{'id': 'tok1', 'status': 'waiting', 'waiting': 'task', 'stepId': 's_fin'}],
      'tasks': [_tasks.first],
    };
    _settings = UiWorkflowSettings.fromJson({
      'version': 1, 'timeZone': 'Indian/Maldives',
      'calendar': {'days': ['sun', 'mon', 'tue', 'wed', 'thu'], 'hours': ['08:00', '16:00'], 'holidays': ['2026-12-25']},
      'webhooks': {'allowedOrigins': ['https://erp.example.com'], 'connections': [{'key': 'erp', 'label': 'ERP', 'baseUrl': 'https://erp.example.com/api', 'auth': 'secret', 'secretName': 'ERP_TOKEN'}]},
    });
    _settingsRevision = 1;
  }

  Map<String, Object?> _version(int v, String note) => {'version': v, 'note': note, 'publishedAt': _now(), 'publishedBy': 'Hana Ibrahim', 'instances': v == 1 ? 3 : 0};

  Map<String, Object?> _task(String id, String title, String kind, {required Duration due, bool overdue = false}) => {
    'id': id, 'instanceId': 'run1', 'kind': kind, 'title': title,
    'instructions': kind == 'approval' ? 'The amount is over 5,000. Check the budget line before approving.' : 'Make sure the transcript is certified.',
    'definitionKey': 'financeCheck', 'entity': 'application', 'entityId': '1', 'entityTitle': 'Marine biology degree, Ali Rasheed',
    'status': 'open', 'assignees': [kind == 'approval' ? 'mariyam' : 'hana'], 'assigneeNames': [kind == 'approval' ? 'Finance' : 'Hana Ibrahim'],
    'rule': kind == 'approval' ? {'type': 'any'} : null,
    'outcomes': kind == 'approval'
        ? [{'key': 'approved', 'label': 'Approve', 'tone': 'success'}, {'key': 'rejected', 'label': 'Reject', 'tone': 'danger'}]
        : [{'key': 'done', 'label': 'Done', 'tone': 'primary'}],
    'decisions': <Object?>[], 'form': null, 'requireComment': kind == 'approval' ? 'reject' : 'never', 'allowDelegation': true, 'outcome': null,
    'dueAt': DateTime.now().toUtc().add(due).toIso8601String(), 'overdue': overdue, 'escalationLevel': 0, 'createdAt': _ago(const Duration(hours: 3)), 'completedAt': null, 'canDecide': true,
  };

  List<Map<String, Object?>> _transitionsFrom(String stateKey) {
    final lc = UiWorkflowDefinition.fromJson(_defs['wf_status']?['published'] ?? statusLifecycle().json).lifecycle!;
    final state = lc.states.firstWhere((s) => s.key == stateKey);
    final def = UiWorkflowDefinition.fromJson({'kind': 'lifecycle', 'lifecycle': lc.json});
    return [
      for (final t in lc.transitions)
        if (transitionAllows(def, t, state.id) && !t.hidden)
          {
            'key': t.key, 'label': t.label, 'to': lc.states.firstWhere((s) => s.id == t.to).key, 'toLabel': lc.states.firstWhere((s) => s.id == t.to).label,
            'tone': t.tone, 'confirm': t.confirm, 'form': t.inputForm,
          },
    ];
  }

  void _log(String category, String action, {Object? before, Object? after, Object? data, String? actor, String? at}) {
    _seq++;
    _audit.insert(0, {
      'seq': _seq, 'id': 'a$_seq', 'at': at ?? _now(), 'actorType': actor == null ? 'workflow' : 'user', 'actorName': actor, 'actorId': actor == null ? null : 'u',
      'category': category, 'action': action, 'subjectType': category, 'subjectId': '1', 'entity': 'application', 'entityId': '1', 'instanceId': 'run1',
      'before': before == null ? null : jsonEncode(before), 'after': after == null ? null : jsonEncode(after), 'data': data == null ? null : jsonEncode(data),
      'correlationId': 'c$_seq', 'prevHash': 'h${_seq - 1}', 'hash': 'h$_seq',
    });
  }

  Future<T> _later<T>(T Function() f) => Future<T>.delayed(const Duration(milliseconds: 120), f);

  UiWfDefinitionSummary _summary(String id) {
    final d = _defs[id]!;
    final def = UiWorkflowDefinition.fromJson(d['draft']);
    return UiWfDefinitionSummary.fromJson({
      'id': id, 'key': def.key, 'kind': def.kind, 'title': def.title, 'entity': def.entity, 'status': d['status'], 'version': d['version'],
      'hasDraftChanges': d['published'] != null && !jsonEquals(d['draft'], d['published']), 'updatedAt': d['updatedAt'], 'updatedBy': 'Hana Ibrahim', 'runningInstances': 0,
    });
  }

  // ── Registry, settings, people ──────────────────────────────────────────────────────────

  @override
  Future<UiWorkflowSchema> schema() => _later(() => UiWorkflowSchema(registry: registry));

  @override
  Future<UiWfMe> me() => _later(() => UiWfMe.fromJson({
    'type': 'user', 'id': 'hana', 'name': 'Hana Ibrahim', 'roles': ['reviewer', 'admin'],
    'can': {'edit': true, 'publish': true, 'settings': true, 'intervene': true, 'audit': true},
  }));

  @override
  Future<({UiWorkflowSettings settings, int revision})> settings() => _later(() => (settings: UiWorkflowSettings.fromJson(_clone(_settings.json)), revision: _settingsRevision));

  @override
  Future<int> saveSettings(UiWorkflowSettings settings, int revision) => _later(() {
    if (revision != _settingsRevision) throw const UiWfApiError(409, 'conflict', 'Someone else changed the settings. Reload and try again.');
    _settings = UiWorkflowSettings.fromJson(_clone(settings.json));
    _log('settings', 'saved', actor: 'Hana Ibrahim');
    return ++_settingsRevision;
  });

  @override
  Future<List<UiWfTriggerOverview>> triggers() => _later(() => [
    UiWfTriggerOverview.fromJson({'definitionId': 'wf_status', 'definitionKey': 'applicationStatus', 'title': 'Application status', 'kind': 'lifecycle', 'type': 'lifecycle', 'entity': 'application', 'field': 'status', 'summary': 'Owns Status', 'version': 1}),
    UiWfTriggerOverview.fromJson({'definitionId': 'wf_finance', 'definitionKey': 'financeCheck', 'title': 'Finance check', 'kind': 'automation', 'type': 'stateEntered', 'entity': 'application', 'summary': 'When Application status enters review', 'version': 1}),
  ]);

  @override
  Future<List<UiWfUser>> searchUsers(String query, {int take = 20}) => _later(() => [
    for (final u in _users)
      if ((u['name'] as String).toLowerCase().contains(query.toLowerCase())) UiWfUser.fromJson(u),
  ].take(take).toList());

  @override
  Future<UiWfUser?> user(String id) => _later(() {
    final u = _users.where((x) => x['id'] == id).firstOrNull;
    return u == null ? null : UiWfUser.fromJson(u);
  });

  // ── Definitions ─────────────────────────────────────────────────────────────────────────

  @override
  Future<List<UiWfDefinitionSummary>> definitions() => _later(() => [for (final id in _defs.keys) _summary(id)]);

  @override
  Future<UiWfDefinitionDetail> definition(String id) => _later(() {
    final d = _defs[id];
    if (d == null) throw const UiWfApiError(404, 'notFound', 'There is no such workflow.');
    return UiWfDefinitionDetail.fromJson({'summary': _summary(id).json, 'draft': d['draft'], 'published': d['published'], 'versions': d['versions'], 'problems': <Object?>[]});
  });

  @override
  Future<UiWfDefinitionSummary> createDefinition(UiWorkflowDefinition def) => _later(() {
    _defs[def.id] = {'draft': _clone(def.json), 'published': null, 'status': 'draft', 'version': 0, 'versions': <Object?>[], 'updatedAt': _now()};
    _log('definition', 'created', actor: 'Hana Ibrahim');
    return _summary(def.id);
  });

  @override
  Future<UiWfDefinitionSummary> saveDraft(UiWorkflowDefinition def) => _later(() {
    final d = _defs[def.id];
    if (d == null) throw const UiWfApiError(404, 'notFound', 'Save it once first.');
    d['draft'] = _clone(def.json);
    d['updatedAt'] = _now();
    return _summary(def.id);
  });

  @override
  Future<void> deleteDefinition(String id) => _later(() => _defs.remove(id));

  @override
  Future<UiWfDefinitionSummary> publish(String id, {String? note}) => _later(() {
    final d = _defs[id]!;
    final problems = _lint(UiWorkflowDefinition.fromJson(d['draft']));
    if (problems.any((p) => p.isError)) throw UiWfApiError(422, 'invalid', 'Fix the problems first.', [for (final p in problems) p.json]);
    final v = (d['version'] as int) + 1;
    d['version'] = v;
    d['published'] = _clone(d['draft']);
    d['status'] = 'published';
    (d['versions'] as List).insert(0, _version(v, note ?? ''));
    _log('definition', 'published', data: {'version': v}, actor: 'Hana Ibrahim');
    return _summary(id);
  });

  @override
  Future<UiWfDefinitionSummary> archive(String id) => _later(() {
    _defs[id]!['status'] = 'archived';
    return _summary(id);
  });

  @override
  Future<UiWfDefinitionSummary> restore(String id) => _later(() {
    _defs[id]!['status'] = 'published';
    return _summary(id);
  });

  @override
  Future<UiWfDefinitionSummary> rollback(String id, int version) => _later(() {
    final d = _defs[id]!;
    d['draft'] = _clone(d['published']);
    return _summary(id);
  });

  @override
  Future<UiWfDefinitionSummary> updatePermissions(String id, List<({String node, List<UiWfAssignee> who})> changes, {String? note}) => _later(() {
    final d = _defs[id]!;
    if (d['published'] == null) throw const UiWfApiError(409, 'not_published', 'Publish the workflow first.');
    // Apply each change to a JSON definition: a transition's or the reset's/start button's "who",
    // or a person step's assignees.
    void apply(Object? json) {
      if (json is! Map) return;
      for (final c in changes) {
        final who = [for (final a in c.who) a.json];
        if (c.node == 'reset' && json['lifecycle'] is Map && (json['lifecycle'] as Map)['reset'] is Map) ((json['lifecycle'] as Map)['reset'] as Map)['who'] = who;
        if (c.node == 'trigger' && json['trigger'] is Map) (json['trigger'] as Map)['who'] = who;
        void walk(Object? x) {
          if (x is Map) {
            if (x['id'] == c.node) x[x.containsKey('from') ? 'who' : 'assignees'] = who;
            x.values.forEach(walk);
          } else if (x is List) {
            x.forEach(walk);
          }
        }
        walk(json['lifecycle']);
        walk(json['steps']);
      }
    }

    final next = _clone(d['published']);
    apply(next);
    if (d['draft'] != null) {
      final draft = _clone(d['draft']);
      apply(draft);
      d['draft'] = draft;
    }
    final v = (d['version'] as int) + 1;
    d['version'] = v;
    d['published'] = next;
    d['status'] = 'published';
    (d['versions'] as List).insert(0, _version(v, note ?? 'Changed who may do what'));
    _log('definition', 'published', data: {'version': v}, actor: 'Hana Ibrahim');
    return _summary(id);
  });

  @override
  Future<UiWorkflowDefinition> version(String id, int version) => _later(() => UiWorkflowDefinition.fromJson(_clone(_defs[id]!['published'])));

  @override
  Future<List<String>> diff(String id) => _later(() {
    final d = _defs[id]!;
    if (d['published'] == null || jsonEquals(d['draft'], d['published'])) return const [];
    final before = indexSteps(UiWorkflowDefinition.fromJson(d['published']));
    final after = indexSteps(UiWorkflowDefinition.fromJson(d['draft']));
    return [
      for (final e in after.entries)
        if (!before.containsKey(e.key)) 'Added “${stepName(e.value.step)}”' else if (!jsonEquals(before[e.key]!.step.json, e.value.step.json)) 'Changed “${stepName(e.value.step)}”',
      for (final e in before.entries)
        if (!after.containsKey(e.key)) 'Removed “${stepName(e.value.step)}”',
      if (UiWorkflowDefinition.fromJson(d['draft']).title != UiWorkflowDefinition.fromJson(d['published']).title) 'Renamed the workflow',
    ];
  });

  /// A few of the engine's checks, enough to show problems in the builder.
  List<UiWfProblem> _lint(UiWorkflowDefinition def) {
    final out = <UiWfProblem>[];
    if (def.title.trim().isEmpty) out.add(UiWfProblem(code: 'title', severity: 'error', message: 'Give the workflow a name.'));
    final t = def.trigger;
    if (def.kind == 'automation' && t != null) {
      if ((t.type == 'fieldChanged' || t.type == 'dateReached') && (t.field ?? '').isEmpty) out.add(UiWfProblem(code: 'triggerField', severity: 'error', message: 'Choose the field that starts it.'));
      if ((t.type == 'stateEntered' || t.type == 'transitionApplied') && (t.lifecycle ?? '').isEmpty) out.add(UiWfProblem(code: 'triggerLifecycle', severity: 'error', message: 'Choose the lifecycle that starts it.'));
      if (t.type == 'signal' && (t.signal ?? '').isEmpty) out.add(UiWfProblem(code: 'triggerSignal', severity: 'error', message: 'Choose the event that starts it.'));
    }
    if (def.kind == 'lifecycle' && (def.lifecycle?.field ?? '').isEmpty) out.add(UiWfProblem(code: 'lifecycleField', severity: 'error', message: 'Choose the field this lifecycle controls.'));
    for (final loc in indexSteps(def).values) {
      final s = loc.step;
      String? msg;
      switch (s.type) {
        case 'approval' || 'task':
          if (UiWfHumanStep.of(s).assignees.isEmpty) msg = 'Add the people who decide.';
        case 'notify':
          if (UiWfNotifyStep.of(s).to.isEmpty) msg = 'Add who gets the message.';
        case 'forEach':
          if (UiWfForEachStep.of(s).collection.isEmpty) msg = 'Choose what to repeat for.';
        case 'goTo':
          if (UiWfGoToStep.of(s).target.isEmpty) msg = 'Choose the step to go back to.';
        case 'action':
          if (UiWfActionStep.of(s).action.isEmpty) msg = 'Choose an action.';
        case 'subWorkflow':
          if (UiWfSubWorkflowStep.of(s).workflow.isEmpty) msg = 'Choose the workflow to run.';
        case 'switch':
          if (UiWfSwitchStep.of(s).on.isEmpty) msg = 'Choose what to switch on.';
        case 'webhook':
          final w = UiWfWebhookStep.of(s);
          if ((w.connection ?? '').isEmpty && (w.url ?? '').isEmpty) msg = 'Enter the address to call.';
      }
      if (msg != null) out.add(UiWfProblem(code: '${s.type}Incomplete', severity: 'error', node: s.id, message: '“${stepName(s)}”: $msg'));
      if (s.type == 'notify' && UiWfNotifyStep.of(s).body.isEmpty) out.add(UiWfProblem(code: 'emptyMessage', severity: 'warning', node: s.id, message: '“${stepName(s)}” has no message yet.'));
    }
    return out;
  }

  @override
  Future<List<UiWfProblem>> validate(UiWorkflowDefinition def) => _later(() => _lint(def));

  @override
  Future<UiWfSimulationResult> simulate(UiWorkflowDefinition def, UiWfSimulationRequest request) => _later(() {
    final log = <Map<String, Object?>>[];
    final tasks = <Map<String, Object?>>[];
    void line(String kind, String action, String text) => log.add({'kind': kind, 'action': action, 'text': text, 'at': _now()});
    line('instance', 'started', 'Started for application ${request.entityId ?? '1'}');
    final decisions = [for (final e in request.events) if (e.type == 'decide') e];
    var stopped = false;
    void run(List<UiWfStep> steps) {
      for (final s in steps) {
        if (stopped) return;
        if (s.disabled) {
          line('step', 'skipped', '${stepName(s)} (turned off)');
          continue;
        }
        switch (s.type) {
          case 'notify':
            final n = UiWfNotifyStep.of(s);
            line('notify', n.channel, '${stepName(s)} to ${describeAssignees(n.to, UiWfDescribeContext(registry: registry, def: def))}');
          case 'approval' || 'task':
            line('task', 'created', stepName(s));
            final d = decisions.where((e) => e.step == s.id).firstOrNull;
            if (d == null) {
              tasks.add({...?_tasks.firstOrNull, 'id': 'sim_${s.id}', 'title': stepName(s), 'assigneeNames': [describeAssignees(UiWfHumanStep.of(s).assignees, UiWfDescribeContext(registry: registry, def: def))]});
              line('step', 'waiting', '${stepName(s)} waits for a decision');
              stopped = true;
              return;
            }
            line('task', 'decided', '${stepName(s)}: ${d.outcome}');
            final slot = stepSlots(s).where((x) => x.slot == 'outcome:${d.outcome}').firstOrNull;
            if (slot != null) run(slot.steps);
          case 'branch':
            final slots = stepSlots(s);
            line('step', 'completed', '${stepName(s)}: took “${slots.first.label}”');
            run(slots.first.steps);
          case 'wait':
            line('step', 'waiting', '${stepName(s)} ${describeStep(s, UiWfDescribeContext(registry: registry, def: def))}');
            final advanced = request.events.any((e) => e.type == 'advance' || e.type == 'signal');
            if (!advanced) {
              stopped = true;
              return;
            }
            line('clock', 'advanced', 'Time moved on');
          case 'end':
            line('instance', 'completed', 'Finished');
            stopped = true;
            return;
          case 'action':
            line('action', 'run', stepName(s));
          case 'webhook':
            line('webhook', UiWfWebhookStep.of(s).method, stepName(s));
          default:
            line('step', 'completed', stepName(s));
        }
      }
    }

    run(def.steps ?? listSteps(def, 'transition:${def.lifecycle?.transitions.where((t) => t.key == request.transition).firstOrNull?.id}') ?? const []);
    if (!stopped) line('instance', 'completed', 'Finished');
    return UiWfSimulationResult.fromJson({
      'problems': [for (final p in _lint(def)) p.json],
      'log': log,
      'instances': <Object?>[],
      'openTasks': tasks,
      'record': {'id': request.entityId ?? '1', 'title': _record['title'], 'status': _record['state'], 'amount': 7200},
      'error': null,
    });
  });

  // ── Runs ────────────────────────────────────────────────────────────────────────────────

  @override
  Future<UiWfPage<UiWfInstance>> instances(UiWfInstanceQuery q) => _later(() => UiWfPage([UiWfInstance.fromJson(_run)], 1));

  @override
  Future<UiWfInstance> instance(String id) => _later(() => UiWfInstance.fromJson(_clone(_run)));

  @override
  Future<UiWorkflowDefinition> instanceDefinition(String id) => _later(() => UiWorkflowDefinition.fromJson(_clone(_defs['wf_finance']!['published'])));

  @override
  Future<UiWfInstance> cancel(String id, {String? reason}) => _later(() {
    _run['status'] = 'cancelled';
    return UiWfInstance.fromJson(_clone(_run));
  });

  @override
  Future<UiWfInstance> retry(String id, {String? target}) => _later(() {
    _run['status'] = 'waiting';
    return UiWfInstance.fromJson(_clone(_run));
  });

  @override
  Future<UiWfInstance> skip(String id, {UiJson? outputs, String? target}) => retry(id, target: target);

  @override
  Future<UiWfInstance> migrate(String id, int version, {Map<String, String>? stateMap}) => instance(id);

  // ── Tasks ───────────────────────────────────────────────────────────────────────────────

  @override
  Future<UiWfPage<UiWfTask>> tasks(UiWfTaskQuery q) => _later(() {
    final statuses = q.status ?? const ['open'];
    final list = [for (final t in _tasks) if (statuses.contains(t['status'])) t];
    return UiWfPage([for (final t in list.take(q.take ?? 25)) UiWfTask.fromJson(_clone(t))], list.length);
  });

  @override
  Future<UiWfTask> task(String id) => _later(() => UiWfTask.fromJson(_clone(_tasks.firstWhere((t) => t['id'] == id))));

  @override
  Future<UiWfTask> decide(String id, String outcome, {String? comment, UiJson? data}) => _later(() {
    final t = _tasks.firstWhere((x) => x['id'] == id);
    if (t['requireComment'] == 'reject' && outcome == 'rejected' && (comment ?? '').trim().isEmpty) {
      throw const UiWfApiError(422, 'commentRequired', 'Say why you are rejecting it.');
    }
    t['status'] = 'completed';
    t['outcome'] = outcome;
    t['canDecide'] = false;
    t['completedAt'] = _now();
    t['decisions'] = [{'userId': 'mariyam', 'name': 'Mariyam Saeed', 'outcome': outcome, 'comment': comment, 'data': data, 'at': _now()}];
    _log('task', 'decided', data: {'outcome': outcome, 'comment': comment}, actor: 'Mariyam Saeed');
    if (id == 't1') {
      _run['status'] = outcome == 'approved' ? 'completed' : 'completed';
      (_run['steps'] as List).last = {...(_run['steps'] as List).last as Map<String, Object?>, 'status': 'completed'};
    }
    return UiWfTask.fromJson(_clone(t));
  });

  @override
  Future<UiWfTask> delegate(String id, String to, {String? note}) => _later(() {
    final t = _tasks.firstWhere((x) => x['id'] == id);
    t['assignees'] = [to];
    t['assigneeNames'] = [_users.where((u) => u['id'] == to).firstOrNull?['name'] ?? to];
    t['canDecide'] = false;
    return UiWfTask.fromJson(_clone(t));
  });

  @override
  Future<UiWfTask> reassign(String id, List<String> assignees, {String? reason}) => delegate(id, assignees.first);

  // ── Records ─────────────────────────────────────────────────────────────────────────────

  UiWfRecord _recordNow() {
    final open = [for (final t in _tasks) if (t['status'] == 'open') t];
    // The demo lifecycle can be started over whenever that would change something.
    final canReset = _record['state'] != 'draft' || open.isNotEmpty;
    return UiWfRecord.fromJson({
      ..._clone(_record) as Map<String, Object?>,
      'tasks': open,
      'reset': canReset ? {'label': 'Start over', 'to': 'draft', 'toLabel': 'Draft', 'confirm': null, 'form': _resetForm} : null,
    });
  }

  static const Map<String, Object?> _resetForm = {
    'schemaVersion': 1, 'id': 'f_reset', 'title': 'Start over',
    'pages': [
      {'id': 'p1', 'elements': [
        {'kind': 'field', 'id': 'f_reason', 'key': 'reason', 'type': 'textarea', 'label': 'Why is it starting over?', 'required': true},
      ]},
    ],
  };

  @override
  Future<UiWfRecord> resetRecord(String entity, String id, {UiJson? input}) => _later(() {
    final before = _record['state'];
    for (final task in _tasks) {
      if (task['status'] == 'open') task['status'] = 'cancelled';
    }
    _record['state'] = 'draft';
    _record['stateLabel'] = 'Draft';
    _record['stateTone'] = 'neutral';
    _record['stateEnteredAt'] = _now();
    _record['transitions'] = _transitionsFrom('draft');
    _log('lifecycle', 'reset', before: {'state': before}, after: {'state': 'draft'}, data: {'label': 'Start over', 'input': input ?? const {}}, actor: 'Hana Ibrahim');
    return _recordNow();
  });

  @override
  Future<UiWfRecord> record(String entity, String id) => _later(_recordNow);

  @override
  Future<List<UiWfAuditEntry>> recordHistory(String entity, String id, {int take = 200}) =>
      _later(() => [for (final a in _audit.where((a) => a['category'] == 'lifecycle' || a['category'] == 'task').take(take)) UiWfAuditEntry.fromJson(a)]);

  @override
  Future<UiWfRecord> applyTransition(String entity, String id, String key, {UiJson? input}) => _later(() {
    final options = (_record['transitions'] as List).cast<Map<String, Object?>>();
    final t = options.where((x) => x['key'] == key).firstOrNull;
    if (t == null) throw const UiWfApiError(403, 'notAllowed', 'That move isn’t possible from here.');
    final before = _record['state'];
    _record['state'] = t['to'];
    _record['stateLabel'] = t['toLabel'];
    _record['stateTone'] = (_record['states'] as List).cast<Map>().firstWhere((s) => s['key'] == t['to'])['tone'];
    _record['stateEnteredAt'] = _now();
    _record['transitions'] = _transitionsFrom(t['to'] as String);
    _log('lifecycle', 'transitioned', before: {'state': before}, after: {'state': t['to']}, data: {'transition': key, 'label': t['label']}, actor: 'Hana Ibrahim');
    if (t['to'] == 'approved' || t['to'] == 'rejected') {
      for (final task in _tasks) {
        if (task['status'] == 'open') task['status'] = 'cancelled';
      }
    }
    return _recordNow();
  });

  @override
  Future<UiWfRecord> forceState(String entity, String id, String state, String reason, {bool skipSteps = false}) => _later(() {
    _record['state'] = state;
    _record['transitions'] = _transitionsFrom(state);
    _log('lifecycle', 'forced', after: {'state': state}, data: {'reason': reason}, actor: 'Hana Ibrahim');
    return _recordNow();
  });

  @override
  Future<UiWfInstance> startManual(String workflow, String? entity, String? id, {UiJson? input}) => _later(() {
    _tasks.add(_task('t${_tasks.length + 1}', 'Upload the missing documents', 'task', due: const Duration(days: 5)));
    _log('task', 'created', data: {'title': 'Upload the missing documents'}, actor: 'Hana Ibrahim');
    return UiWfInstance.fromJson({'id': 'run${_tasks.length}', 'status': 'waiting'});
  });

  // ── Audit ───────────────────────────────────────────────────────────────────────────────

  @override
  Future<List<UiWfAuditEntry>> audit(UiWfAuditQuery q) => _later(() {
    final list = [
      for (final a in _audit)
        if ((q.category == null || a['category'] == q.category) && (q.entityId == null || a['entityId'] == q.entityId) && (q.before == null || (a['seq'] as int) < q.before!)) a,
    ];
    return [for (final a in list.take(q.take ?? 50)) UiWfAuditEntry.fromJson(a)];
  });

  @override
  String auditExportUrl(UiWfAuditQuery q) => 'memory://audit/export${uiWfQueryString(q.toParams())}';

  @override
  Future<Uint8List> exportAudit(UiWfAuditQuery q) => _later(() {
    final rows = ['seq,at,category,action,actor', for (final a in _audit) '${a['seq']},${a['at']},${a['category']},${a['action']},${a['actorName'] ?? a['actorType']}'];
    return Uint8List.fromList(utf8.encode(rows.join('\n')));
  });

  @override
  Future<UiWfAuditVerification> verifyAudit({int? fromSeq}) => _later(() => UiWfAuditVerification.fromJson({'valid': true, 'checked': _audit.length, 'brokenAtSeq': null, 'problem': null, 'purgedGaps': <Object?>[]}));
}
