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
    {'id': 'hana', 'name': 'Hana Ibrahim', 'email': 'hana@example.com', 'title': 'Head of office', 'roles': ['reviewer', 'head', 'admin']},
    {'id': 'ali', 'name': 'Ali Rasheed', 'email': 'ali@example.com', 'title': 'Applicant', 'roles': ['applicant']},
    {'id': 'mariyam', 'name': 'Mariyam Saeed', 'email': 'mariyam@example.com', 'title': 'Finance', 'roles': ['finance']},
  ];

  /// The people the demos can act as.
  static List<({String id, String name, String title})> get people => [
        for (final u in _users) (id: u['id']! as String, name: u['name']! as String, title: u['title']! as String),
      ];

  /// Who the API acts as: what they may do follows their roles (the head of office may do everything).
  String actingAs = 'hana';

  Map<String, Object?> get _actor => _users.firstWhere((u) => u['id'] == actingAs, orElse: () => _users.first);
  String get _actorName => _actor['name']! as String;
  bool _hasRole(String role) => (_actor['roles']! as List).contains(role);
  bool get _isAdmin => _hasRole('admin');

  void _onlyAdmins(String what) {
    if (!_isAdmin) throw UiWfApiError(403, 'forbidden', 'Only admins can $what.');
  }

  /// The lifecycle the workflow panel shows (published, so automations can be triggered by it).
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
  /// The applications by id; "1" is the one the workflows have worked on.
  late Map<String, Map<String, Object?>> _records;
  Map<String, Object?> get _record => _records['1']!;

  /// Each application's applicant (who may submit or withdraw it).
  static const Map<String, String> _applicants = {'1': 'ali', '2': 'ali', '3': 'ali'};

  /// The applications, for a picker.
  List<({String id, String title, String stateLabel, String? stateTone})> get applications => [
        for (final e in _records.entries)
          (id: e.key, title: e.value['title']! as String, stateLabel: e.value['stateLabel']! as String, stateTone: e.value['stateTone'] as String?),
      ];

  /// The application's own fields that the demo workflow changes (and a reset can put back).
  late Map<String, Object?> _fields;

  /// The documents that exist (the workflow creates the review checklist; a reset can delete it).
  late List<String> _documents;

  /// The ids of what the workflow did since the application last started over (the reset list).
  late List<String> _done;

  /// The application's reviewer, as the demo workflow last set it (null once a reset put it back).
  String? get reviewer => _fields['reviewer'] as String?;

  /// The programme's budget, which the workflow reserved from.
  int get budget => _fields['budget']! as int;

  /// Whether the review checklist the workflow created still exists.
  bool get hasChecklist => _documents.contains('d9');
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
    _records = {};
    _records['1'] = {
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
    _records['2'] = _plainRecord('2', 'Nursing diploma, Ali Rasheed', 'draft');
    _records['3'] = _plainRecord('3', 'Law degree, Ali Rasheed', 'approved');
    _fields = {'reviewer': 'Rana Ibrahim', 'budget': 42000};
    _documents = ['d9'];
    _done = ['field:application:1:reviewer', 'created:document:d9', 'field:programme:p1:budget', 'move:application:3', 'message:m1'];
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

  /// An application the workflows haven't done anything to yet, in [state].
  Map<String, Object?> _plainRecord(String id, String title, String state) {
    final r = <String, Object?>{
      'entity': 'application', 'id': id, 'title': title, 'lifecycle': 'applicationStatus', 'lifecycleTitle': 'Application status',
      'status': 'active', 'stateEnteredAt': _ago(const Duration(days: 2)), 'instances': <Object?>[], 'manual': <Object?>[],
      'states': _record['states'],
    };
    _setState(r, state);
    return r;
  }

  /// Moves a record to [state] (its label, tone and the moves from there).
  void _setState(Map<String, Object?> r, String state) {
    final s = (r['states']! as List).cast<Map>().firstWhere((x) => x['key'] == state);
    r['state'] = state;
    r['stateLabel'] = s['label'];
    r['stateTone'] = s['tone'];
    r['stateEnteredAt'] = _now();
    r['transitions'] = _transitionsFrom(state);
  }

  Map<String, Object?> _rec(String id) => _records[id] ?? (throw const UiWfApiError(404, 'notFound', 'There is no such application.'));

  /// Whether the acting person may make a move (by its `who`: the applicant, or a role).
  bool _mayMove(Map<String, Object?> t, String recordId) {
    for (final w in (t['_who'] as List? ?? const []).cast<Map>()) {
      if (w['field'] == 'entity.applicant' && _applicants[recordId] == actingAs) return true;
      if (w['role'] is String && _hasRole(w['role'] as String)) return true;
    }
    return false;
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
            'tone': t.tone, 'confirm': t.confirm, 'form': t.inputForm, 'comment': ?t.comment?.name,
            // Who may make it (kept here, never sent).
            '_who': [for (final w in t.who ?? const <UiWfAssignee>[]) w.json],
          },
    ];
  }

  void _log(String category, String action, {Object? before, Object? after, Object? data, String? actor, String? at, String entityId = '1'}) {
    _seq++;
    _audit.insert(0, {
      'seq': _seq, 'id': 'a$_seq', 'at': at ?? _now(), 'actorType': actor == null ? 'workflow' : 'user', 'actorName': actor, 'actorId': actor == null ? null : 'u',
      'category': category, 'action': action, 'subjectType': category, 'subjectId': entityId, 'entity': 'application', 'entityId': entityId, 'instanceId': 'run1',
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
    'type': 'user', 'id': actingAs, 'name': _actorName, 'roles': _actor['roles'],
    'can': {'edit': _isAdmin, 'publish': _isAdmin, 'settings': _isAdmin, 'intervene': _isAdmin, 'audit': _isAdmin},
  }));

  @override
  Future<({UiWorkflowSettings settings, int revision})> settings() => _later(() => (settings: UiWorkflowSettings.fromJson(_clone(_settings.json)), revision: _settingsRevision));

  @override
  Future<int> saveSettings(UiWorkflowSettings settings, int revision) => _later(() {
    _onlyAdmins('change the workflow settings');
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
  Future<UiWfPermissionsSummary> updatePermissions(String id, List<({String node, List<UiWfAssignee> who})> changes, {String? note}) => _later(() {
    _onlyAdmins('change who may do what');
    final d = _defs[id]!;
    if (d['published'] == null) throw const UiWfApiError(409, 'not_published', 'Publish the workflow first.');
    // Apply each change to a JSON definition: a transition's or the reset's/start button's "who",
    // or a person step's assignees. Answers the nodes it found.
    Set<String> apply(Object? json) {
      final found = <String>{};
      if (json is! Map) return found;
      for (final c in changes) {
        final who = [for (final a in c.who) a.json];
        if (c.node == 'reset' && json['lifecycle'] is Map && (json['lifecycle'] as Map)['reset'] is Map) {
          ((json['lifecycle'] as Map)['reset'] as Map)['who'] = who;
          found.add(c.node);
        }
        if (c.node == 'trigger' && json['trigger'] is Map) {
          (json['trigger'] as Map)['who'] = who;
          found.add(c.node);
        }
        void walk(Object? x) {
          if (x is Map) {
            if (x['id'] == c.node) {
              x[x.containsKey('from') ? 'who' : 'assignees'] = who;
              found.add(c.node);
            }
            x.values.forEach(walk);
          } else if (x is List) {
            x.forEach(walk);
          }
        }
        walk(json['lifecycle']);
        walk(json['steps']);
      }
      return found;
    }

    final next = _clone(d['published']);
    apply(next);
    // Nothing different from what is published: no new version.
    if (jsonEquals(next, d['published'])) return UiWfPermissionsSummary.fromJson({..._summary(id).json, 'changed': false});
    final skipped = <String>[];
    if (d['draft'] != null) {
      final draft = _clone(d['draft']);
      final found = apply(draft);
      // Steps or moves the draft no longer has keep it as it was.
      skipped.addAll([for (final c in changes) if (!found.contains(c.node)) c.node]);
      d['draft'] = draft;
    }
    final v = (d['version'] as int) + 1;
    d['version'] = v;
    d['published'] = next;
    d['status'] = 'published';
    (d['versions'] as List).insert(0, _version(v, note ?? 'Changed who may do what'));
    _log('definition', 'published', data: {'version': v}, actor: _actorName);
    // Records (or runs) on the old version move onto the new one.
    final moved = id == 'wf_status' ? _records.length : (_run['status'] == 'waiting' ? 1 : 0);
    return UiWfPermissionsSummary.fromJson({..._summary(id).json, 'changed': true, 'draftSkipped': skipped, 'recordsMoved': moved});
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
  Future<UiWfPage<UiWfInstance>> instances(UiWfInstanceQuery q) =>
      _later(() => q.entityId == null || q.entityId == '1' ? UiWfPage([UiWfInstance.fromJson(_run)], 1) : const UiWfPage(<UiWfInstance>[], 0));

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
    final mine = q.scope != 'all';
    if (!mine) _onlyAdmins("see everyone's tasks");
    final list = [
      for (final t in _tasks)
        if (statuses.contains(t['status']) && (!mine || (t['assignees']! as List).contains(actingAs))) t,
    ];
    return UiWfPage([for (final t in list.take(q.take ?? 25)) _asSeen(t)], list.length);
  });

  /// A task as the acting person sees it: they can decide it when it is open and theirs.
  UiWfTask _asSeen(Map<String, Object?> t) =>
      UiWfTask.fromJson({..._clone(t) as Map<String, Object?>, 'canDecide': t['status'] == 'open' && (t['assignees']! as List).contains(actingAs)});

  @override
  Future<UiWfTask> task(String id) => _later(() => _asSeen(_tasks.firstWhere((t) => t['id'] == id)));

  @override
  Future<UiWfTask> decide(String id, String outcome, {String? comment, UiJson? data}) => _later(() {
    final t = _tasks.firstWhere((x) => x['id'] == id);
    if (!(t['assignees']! as List).contains(actingAs)) throw const UiWfApiError(403, 'notAllowed', 'This task is for someone else.');
    if (t['requireComment'] == 'reject' && outcome == 'rejected' && (comment ?? '').trim().isEmpty) {
      throw const UiWfApiError(422, 'commentRequired', 'Say why you are rejecting it.');
    }
    t['status'] = 'completed';
    t['outcome'] = outcome;
    t['canDecide'] = false;
    t['completedAt'] = _now();
    t['decisions'] = [{'userId': actingAs, 'name': _actorName, 'outcome': outcome, 'comment': comment, 'data': data, 'at': _now()}];
    _log('task', 'decided', data: {'outcome': outcome, 'comment': comment}, actor: _actorName);
    if (id == 't1') {
      _run['status'] = outcome == 'approved' ? 'completed' : 'completed';
      (_run['steps'] as List).last = {...(_run['steps'] as List).last as Map<String, Object?>, 'status': 'completed'};
    }
    return _asSeen(t);
  });

  @override
  Future<UiWfTask> delegate(String id, String to, {String? note}) => _later(() {
    final t = _tasks.firstWhere((x) => x['id'] == id);
    t['assignees'] = [to];
    t['assigneeNames'] = [_users.where((u) => u['id'] == to).firstOrNull?['name'] ?? to];
    return _asSeen(t);
  });

  @override
  Future<UiWfTask> reassign(String id, List<String> assignees, {String? reason}) => delegate(id, assignees.first);

  // ── Records ─────────────────────────────────────────────────────────────────────────────

  /// A record as the acting person sees it: only the moves they may make, the open tasks about it
  /// (decidable when theirs), and Start over for the head of office once it would change something.
  UiWfRecord _recordNow(String id) {
    final r = _rec(id);
    final open = [for (final t in _tasks) if (t['status'] == 'open' && t['entityId'] == id) t];
    final canReset = _hasRole('head') && (r['state'] != 'draft' || open.isNotEmpty);
    return UiWfRecord.fromJson({
      ..._clone(r) as Map<String, Object?>,
      'transitions': [
        for (final t in (r['transitions']! as List).cast<Map<String, Object?>>())
          if (_mayMove(t, id)) {...t}..remove('_who'),
      ],
      'manual': _isAdmin ? r['manual'] : <Object?>[],
      'tasks': [for (final t in open) _asSeen(t).json],
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

  /// What the demo workflow did since the application last started over, for the reset list: only
  /// what is still listed in [_done], so a reset empties it until the application moves on again.
  List<Map<String, Object?>> _resetItems(String recordId) {
    // Only application 1 has had workflows do things to it.
    if (recordId != '1') return const [];
    final all = <String, Map<String, Object?>>{
      'field:application:1:reviewer': {'kind': 'field', 'title': 'Reviewer of Application “${_record['title'] ?? 'Bursary'}”: back to nobody',
        'detail': 'Now ${_fields['reviewer'] ?? 'nobody'}', 'workflow': 'Scholarship review', 'step': 'Assign the reviewer', 'undoable': true, 'selected': true},
      'created:document:d9': {'kind': 'created', 'title': 'Delete Document “Review checklist”', 'detail': 'Created by the workflow',
        'workflow': 'Scholarship review', 'step': 'Open a checklist', 'undoable': true, 'selected': true},
      'field:programme:p1:budget': {'kind': 'field', 'title': 'Budget of Programme “Engineering”: back to 50,000', 'detail': 'Now ${_money(budget)}',
        'workflow': 'Scholarship review', 'step': 'Reserve the amount', 'undoable': true, 'selected': false,
        'warning': 'Changed again since the workflow set it to 45,200; ticking it overwrites that.'},
      'move:application:3': {'kind': 'move', 'title': 'Application “Law degree, Ali Rasheed”: moved to Approved', 'detail': null,
        'workflow': 'Scholarship review', 'step': 'Close related applications', 'undoable': false, 'selected': false,
        'warning': 'Moves can’t be taken back here; start that application over instead.'},
      'message:m1': {'kind': 'message', 'title': 'Message “We received your application” to Ali Rasheed', 'detail': null,
        'workflow': 'Scholarship review', 'step': 'Thank the applicant', 'undoable': false, 'selected': false, 'warning': "Already sent; it can't be taken back."},
    };
    return [for (final id in _done) if (all[id] case final item?) {'id': id, ...item}];
  }

  static String _money(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');

  /// Takes back one thing the workflow did (a field put back, a created record deleted).
  void _takeBack(String id) {
    switch (id) {
      case 'field:application:1:reviewer':
        _fields['reviewer'] = null;
      case 'created:document:d9':
        _documents.remove('d9');
      case 'field:programme:p1:budget':
        _fields['budget'] = 50000;
    }
  }

  @override
  Future<UiWfResetPreview> resetPreview(String entity, String id) => _later(() {
    _sameLifecycle(entity);
    final reset = _recordNow(id).reset;
    if (reset == null) throw const UiWfApiError(403, 'notAllowed', 'Starting over isn’t offered here.');
    return UiWfResetPreview.fromJson({'reset': reset.json, 'items': _resetItems(id), 'token': _resetToken(id)});
  });

  /// Changes whenever the list would: a reset sent with an older one is refused as changed.
  String _resetToken(String id) => 'tk-$id-${_resetItems(id).map((i) => '${i['id']}=${i['detail']}').join('|')}';

  /// The demo office has one lifecycle, on applications: anything else follows another one.
  void _sameLifecycle(String entity) {
    if (entity != 'application') throw const UiWfApiError(409, 'wrongLifecycle', 'This record follows another lifecycle.');
  }

  @override
  Future<UiWfRecord> resetRecord(String entity, String id, {UiJson? input, List<String>? undo, String? comment, String? token}) => _later(() {
    _sameLifecycle(entity);
    final r = _rec(id);
    if (_recordNow(id).reset == null) throw const UiWfApiError(403, 'notAllowed', 'You can’t start this application over.');
    if (token != null && token != _resetToken(id)) throw const UiWfApiError(409, 'resetChanged', 'What the workflow did has changed; check the list again.');
    final before = r['state'];
    final items = _resetItems(id);
    if (undo?.any((u) => !items.any((i) => i['id'] == u)) ?? false) {
      throw const UiWfApiError(409, 'resetChanged', 'What the workflow did has changed; check the list again.');
    }
    final undone = [for (final i in items) if (undo?.contains(i['id']) ?? false) i['title']];
    for (final u in undo ?? const <String>[]) {
      _takeBack(u);
    }
    // Starting over: from here the list holds only what the workflow does next.
    if (id == '1') _done = [];
    for (final task in _tasks) {
      if (task['status'] == 'open' && task['entityId'] == id) task['status'] = 'cancelled';
    }
    _setState(r, 'draft');
    _log('lifecycle', 'reset', before: {'state': before}, after: {'state': 'draft'}, data: {'label': 'Start over', 'input': input ?? const {}, 'undone': undone, 'comment': ?comment},
        actor: _actorName, entityId: id);
    return _recordNow(id);
  });

  @override
  Future<UiWfRecord> record(String entity, String id) => _later(() => _recordNow(id));

  @override
  Future<List<UiWfAuditEntry>> recordHistory(String entity, String id, {int take = 200}) => _later(() => [
        for (final a in _audit.where((a) => a['entityId'] == id && (a['category'] == 'lifecycle' || a['category'] == 'task')).take(take)) UiWfAuditEntry.fromJson(a),
      ]);

  @override
  Future<UiWfRecord> applyTransition(String entity, String id, String key, {UiJson? input, String? comment}) => _later(() {
    final r = _rec(id);
    _sameLifecycle(entity);
    final t = (r['transitions']! as List).cast<Map<String, Object?>>().where((x) => x['key'] == key).firstOrNull;
    if (t == null || !_mayMove(t, id)) throw const UiWfApiError(403, 'notAllowed', 'That move isn’t possible from here.');
    if (t['comment'] == 'required' && (comment ?? '').trim().isEmpty) throw const UiWfApiError(400, 'commentRequired', 'Add remarks to make this move.');
    final before = r['state'];
    _setState(r, t['to']! as String);
    _log('lifecycle', 'transitioned', before: {'state': before}, after: {'state': t['to']}, data: {'transition': key, 'label': t['label'], 'comment': ?comment},
        actor: _actorName, entityId: id);
    if (id == '1' && before == 'draft' && t['to'] == 'review') {
      // The workflow assigns a reviewer and opens a checklist again, which a later reset can take back.
      _fields['reviewer'] = 'Rana Ibrahim';
      if (!_documents.contains('d9')) _documents.add('d9');
      _done = ['field:application:1:reviewer', 'created:document:d9', ..._done.where((d) => !d.startsWith('field:application:1:reviewer') && d != 'created:document:d9')];
    }
    if (t['to'] == 'approved' || t['to'] == 'rejected') {
      for (final task in _tasks) {
        if (task['status'] == 'open' && task['entityId'] == id) task['status'] = 'cancelled';
      }
    }
    return _recordNow(id);
  });

  @override
  Future<UiWfRecord> forceState(String entity, String id, String state, String reason, {bool skipSteps = false}) => _later(() {
    _onlyAdmins('move a record by force');
    _setState(_rec(id), state);
    _log('lifecycle', 'forced', after: {'state': state}, data: {'reason': reason}, actor: _actorName, entityId: id);
    return _recordNow(id);
  });

  @override
  Future<UiWfInstance> startManual(String workflow, String? entity, String? id, {UiJson? input}) => _later(() {
    final task = _task('t${_tasks.length + 1}', 'Upload the missing documents', 'task', due: const Duration(days: 5));
    _tasks.add({...task, 'entityId': id ?? '1', 'entityTitle': _records[id ?? '1']?['title']});
    _log('task', 'created', data: {'title': 'Upload the missing documents'}, actor: _actorName, entityId: id ?? '1');
    return UiWfInstance.fromJson({'id': 'run${_tasks.length}', 'status': 'waiting'});
  });

  // ── Audit ───────────────────────────────────────────────────────────────────────────────

  @override
  Future<List<UiWfAuditEntry>> audit(UiWfAuditQuery q) => _later(() {
    _onlyAdmins('read the audit log');
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
