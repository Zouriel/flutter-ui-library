/// Shapes returned by the workflow REST API (spec `api/openapi.yaml`), and the client the workflow
/// widgets talk to an engine through. Engines in every language return these; the widgets only
/// use [UiWorkflowApi], so tests and demos can plug in their own.
///
/// Like the definition model, every shape is a typed view over the JSON the server sent.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'json.dart';
import 'schema.dart';

extension type const UiWfProblem._(UiJson json) implements Object {
  UiWfProblem.fromJson(Object? j) : json = wfMap(j);
  UiWfProblem({required String code, required String severity, String? node, required String message})
    : json = {'code': code, 'severity': severity, 'node': node, 'message': message};
  String get code => wfStr(json['code']);

  /// `error` or `warning`.
  String get severity => wfStr(json['severity'], 'error');
  bool get isError => severity == 'error';

  /// The step, state or transition the problem is on (null: the workflow itself).
  String? get node => wfStrOrNull(json['node']);
  String get message => wfStr(json['message']);
}

extension type const UiWfDefinitionSummary._(UiJson json) implements Object {
  UiWfDefinitionSummary.fromJson(Object? j) : json = wfMap(j);
  String get id => wfStr(json['id']);
  String get key => wfStr(json['key']);
  String get kind => wfStr(json['kind'], 'automation');
  String get title => wfStr(json['title']);
  String? get entity => wfStrOrNull(json['entity']);

  /// `draft`, `published` or `archived`.
  String get status => wfStr(json['status'], 'draft');
  int get version => wfInt(json['version']) ?? 0;
  bool get hasDraftChanges => json['hasDraftChanges'] == true;
  String get updatedAt => wfStr(json['updatedAt']);
  String? get updatedBy => wfStrOrNull(json['updatedBy']);
  int get runningInstances => wfInt(json['runningInstances']) ?? 0;
}

extension type const UiWfVersionInfo._(UiJson json) implements Object {
  UiWfVersionInfo.fromJson(Object? j) : json = wfMap(j);
  int get version => wfInt(json['version']) ?? 0;
  String? get note => wfStrOrNull(json['note']);
  String get publishedAt => wfStr(json['publishedAt']);
  String? get publishedBy => wfStrOrNull(json['publishedBy']);
  int get instances => wfInt(json['instances']) ?? 0;
}

extension type const UiWfDefinitionDetail._(UiJson json) implements Object {
  UiWfDefinitionDetail.fromJson(Object? j) : json = wfMap(j);
  UiWfDefinitionSummary get summary => UiWfDefinitionSummary.fromJson(json['summary']);
  UiWorkflowDefinition get draft => UiWorkflowDefinition.fromJson(json['draft']);
  UiWorkflowDefinition? get published => json['published'] is Map ? UiWorkflowDefinition.fromJson(json['published']) : null;
  List<UiWfVersionInfo> get versions => wfList(json['versions'], UiWfVersionInfo.fromJson);
  List<UiWfProblem> get problems => wfList(json['problems'], UiWfProblem.fromJson);
}

extension type const UiWfStepRun._(UiJson json) implements Object {
  UiWfStepRun.fromJson(Object? j) : json = wfMap(j);
  String get id => wfStr(json['id']);
  String get nodeId => wfStr(json['nodeId']);
  String get type => wfStr(json['type']);
  String? get title => wfStrOrNull(json['title']);
  int get attempt => wfInt(json['attempt']) ?? 1;

  /// `running`, `waiting`, `completed`, `failed`, `skipped` or `cancelled`.
  String get status => wfStr(json['status']);
  Object? get input => json['input'];
  Object? get output => json['output'];
  String? get error => wfStrOrNull(json['error']);
  String get startedAt => wfStr(json['startedAt']);
  String? get endedAt => wfStrOrNull(json['endedAt']);
}

extension type const UiWfDecision._(UiJson json) implements Object {
  UiWfDecision.fromJson(Object? j) : json = wfMap(j);
  String get userId => wfStr(json['userId']);
  String? get name => wfStrOrNull(json['name']);
  String get outcome => wfStr(json['outcome']);
  String? get comment => wfStrOrNull(json['comment']);
  UiJson? get data => wfMapOrNull(json['data']);
  String get at => wfStr(json['at']);
}

/// One button of a task as the engine reports it.
extension type const UiWfOutcomeOption._(UiJson json) implements Object {
  UiWfOutcomeOption.fromJson(Object? j) : json = wfMap(j);
  String get key => wfStr(json['key']);
  String get label => wfStr(json['label']);
  String? get tone => wfStrOrNull(json['tone']);
}

extension type const UiWfTask._(UiJson json) implements Object {
  UiWfTask.fromJson(Object? j) : json = wfMap(j);
  String get id => wfStr(json['id']);
  String get instanceId => wfStr(json['instanceId']);

  /// `approval` or `task`.
  String get kind => wfStr(json['kind'], 'task');
  String get title => wfStr(json['title']);
  String? get instructions => wfStrOrNull(json['instructions']);
  String get definitionKey => wfStr(json['definitionKey']);
  String? get entity => wfStrOrNull(json['entity']);
  String? get entityId => wfStrOrNull(json['entityId']);
  String? get entityTitle => wfStrOrNull(json['entityTitle']);

  /// `open`, `completed`, `cancelled` or `timedOut`.
  String get status => wfStr(json['status'], 'open');
  List<String> get assignees => wfStrings(json['assignees']);
  List<String> get assigneeNames => wfStrings(json['assigneeNames']);

  /// `{type, value?}` for approvals.
  UiJson? get rule => wfMapOrNull(json['rule']);
  List<UiWfOutcomeOption> get outcomes => wfList(json['outcomes'], UiWfOutcomeOption.fromJson);
  List<UiWfDecision> get decisions => wfList(json['decisions'], UiWfDecision.fromJson);

  /// The task's form (form-builder JSON).
  UiJson? get form => wfMapOrNull(json['form']);

  /// `never`, `reject`, `always` or null.
  String? get requireComment => wfStrOrNull(json['requireComment']);
  bool get allowDelegation => json['allowDelegation'] == true;
  String? get outcome => wfStrOrNull(json['outcome']);
  String get dueAt => wfStr(json['dueAt']);
  bool get overdue => json['overdue'] == true;
  int get escalationLevel => wfInt(json['escalationLevel']) ?? 0;
  String get createdAt => wfStr(json['createdAt']);
  String? get completedAt => wfStrOrNull(json['completedAt']);
  bool get canDecide => json['canDecide'] == true;
}

/// Instance statuses: `queued`, `running`, `waiting`, `incident`, `completed`, `failed`,
/// `cancelled`, `active`, `outOfSync`.
const List<String> uiWfInstanceStatuses = ['queued', 'running', 'waiting', 'incident', 'completed', 'failed', 'cancelled', 'active', 'outOfSync'];

/// `{id, status, waiting, stepId}`: where a run's tokens are.
extension type const UiWfRunToken._(UiJson json) implements Object {
  UiWfRunToken.fromJson(Object? j) : json = wfMap(j);
  String get id => wfStr(json['id']);
  String get status => wfStr(json['status']);
  String? get waiting => wfStrOrNull(json['waiting']);
  String? get stepId => wfStrOrNull(json['stepId']);
}

extension type const UiWfInstance._(UiJson json) implements Object {
  UiWfInstance.fromJson(Object? j) : json = wfMap(j);
  String get id => wfStr(json['id']);
  String get definitionId => wfStr(json['definitionId']);
  String get definitionKey => wfStr(json['definitionKey']);
  String get title => wfStr(json['title']);
  int get version => wfInt(json['version']) ?? 0;

  /// `automation`, `record` or `run`.
  String get kind => wfStr(json['kind'], 'automation');
  String? get parentId => wfStrOrNull(json['parentId']);
  String? get reason => wfStrOrNull(json['reason']);
  String? get entity => wfStrOrNull(json['entity']);
  String? get entityId => wfStrOrNull(json['entityId']);
  String? get entityTitle => wfStrOrNull(json['entityTitle']);
  String get status => wfStr(json['status']);
  String? get state => wfStrOrNull(json['state']);
  String? get stateLabel => wfStrOrNull(json['stateLabel']);
  String? get error => wfStrOrNull(json['error']);
  String? get errorStepId => wfStrOrNull(json['errorStepId']);
  String? get initiatorId => wfStrOrNull(json['initiatorId']);
  String? get initiatorName => wfStrOrNull(json['initiatorName']);
  String get startedAt => wfStr(json['startedAt']);
  String get updatedAt => wfStr(json['updatedAt']);
  String? get endedAt => wfStrOrNull(json['endedAt']);
  UiJson? get trigger => wfMapOrNull(json['trigger']);
  List<UiWfStepRun>? get steps => wfListOrNull(json['steps'], UiWfStepRun.fromJson);
  List<UiWfRunToken>? get tokens => wfListOrNull(json['tokens'], UiWfRunToken.fromJson);
  UiJson? get outputs => wfMapOrNull(json['outputs']);
  UiJson? get variables => wfMapOrNull(json['variables']);
  List<UiWfTask>? get tasks => wfListOrNull(json['tasks'], UiWfTask.fromJson);
}

extension type const UiWfTransitionOption._(UiJson json) implements Object {
  UiWfTransitionOption.fromJson(Object? j) : json = wfMap(j);
  UiWfTransitionOption({required String key, required String label, String to = '', String toLabel = '', String? tone, String? confirm, UiJson? form, UiWfRemarks? comment})
    : json = {'key': key, 'label': label, 'to': to, 'toLabel': toLabel, 'tone': tone, 'confirm': confirm, 'form': form, if (comment != null) 'comment': comment.name};
  String get key => wfStr(json['key']);
  String get label => wfStr(json['label']);
  String get to => wfStr(json['to']);
  String get toLabel => wfStr(json['toLabel']);
  String? get tone => wfStrOrNull(json['tone']);
  String? get confirm => wfStrOrNull(json['confirm']);
  UiJson? get form => wfMapOrNull(json['form']);

  /// Whether the person is asked for remarks (resolved by the engine: red moves default to
  /// optional). Older engines omit it; see [wfRemarksFor].
  UiWfRemarks? get comment => UiWfRemarks.parse(json['comment']);
}

/// `{key, label, form}`: a workflow someone can start by hand from the record.
extension type const UiWfManualOption._(UiJson json) implements Object {
  UiWfManualOption.fromJson(Object? j) : json = wfMap(j);
  String get key => wfStr(json['key']);
  String get label => wfStr(json['label']);
  UiJson? get form => wfMapOrNull(json['form']);
}

/// `{key, label, category, tone}`: a state of the record's lifecycle.
extension type const UiWfRecordState._(UiJson json) implements Object {
  UiWfRecordState.fromJson(Object? j) : json = wfMap(j);
  String get key => wfStr(json['key']);
  String get label => wfStr(json['label']);
  String get category => wfStr(json['category'], 'active');
  String? get tone => wfStrOrNull(json['tone']);
}

/// A record as workflows see it (`GET /records/{entity}/{id}`).
extension type const UiWfRecord._(UiJson json) implements Object {
  UiWfRecord.fromJson(Object? j) : json = wfMap(j);
  String get entity => wfStr(json['entity']);
  String get id => wfStr(json['id']);
  String? get title => wfStrOrNull(json['title']);
  String? get lifecycle => wfStrOrNull(json['lifecycle']);
  String? get lifecycleTitle => wfStrOrNull(json['lifecycleTitle']);
  String? get state => wfStrOrNull(json['state']);
  String? get stateLabel => wfStrOrNull(json['stateLabel']);
  String? get stateTone => wfStrOrNull(json['stateTone']);
  String? get status => wfStrOrNull(json['status']);
  String? get stateEnteredAt => wfStrOrNull(json['stateEnteredAt']);
  List<UiWfTransitionOption> get transitions => wfList(json['transitions'], UiWfTransitionOption.fromJson);
  List<UiWfTask> get tasks => wfList(json['tasks'], UiWfTask.fromJson);
  List<UiWfInstance> get instances => wfList(json['instances'], UiWfInstance.fromJson);
  List<UiWfManualOption> get manual => wfList(json['manual'], UiWfManualOption.fromJson);
  List<UiWfRecordState> get states => wfList(json['states'], UiWfRecordState.fromJson);

  /// Starting the workflow over, when this person may and it would change something (else null).
  UiWfResetOption? get reset => json['reset'] is Map ? UiWfResetOption.fromJson(json['reset']) : null;
}

/// `{label, to, toLabel, confirm, form, comment}`: the record's reset as offered to the viewer.
extension type const UiWfResetOption._(UiJson json) implements Object {
  UiWfResetOption.fromJson(Object? j) : json = wfMap(j);
  String get label => wfStr(json['label']);
  String get to => wfStr(json['to']);
  String get toLabel => wfStr(json['toLabel']);
  String? get confirm => wfStrOrNull(json['confirm']);
  UiJson? get form => wfMapOrNull(json['form']);

  /// Whether the person is asked for remarks; null = optional.
  UiWfRemarks? get comment => UiWfRemarks.parse(json['comment']);
}

/// One thing a workflow did that a reset can list (spec §6 reset).
extension type const UiWfResetItem._(UiJson json) implements Object {
  UiWfResetItem.fromJson(Object? j) : json = wfMap(j);

  /// Send back in [UiWorkflowApi.resetRecord]'s `undo` to take it back.
  String get id => wfStr(json['id']);

  /// `field` (a field it changed), `created` (a record it created), `action`, `message`, `webhook` or
  /// `move` (another record the workflow moved; never undoable, with a warning).
  String get kind => wfStr(json['kind']);

  /// What taking it back does, in words.
  String get title => wfStr(json['title']);
  String? get detail => wfStrOrNull(json['detail']);

  /// The workflow and step that did it.
  String get workflow => wfStr(json['workflow']);
  String get step => wfStr(json['step']);

  /// False for messages, webhooks and actions the app cannot undo.
  bool get undoable => json['undoable'] == true;

  /// Ticked by default (not when changed again since, or when it cannot be undone).
  bool get selected => json['selected'] == true;

  /// Why it is unticked or cannot be undone.
  String? get warning => wfStrOrNull(json['warning']);
}

/// What resetting a record would do: the reset as offered, and what the workflow did that it can take back.
extension type const UiWfResetPreview._(UiJson json) implements Object {
  UiWfResetPreview.fromJson(Object? j) : json = wfMap(j);
  UiWfResetOption get reset => UiWfResetOption.fromJson(json['reset']);
  List<UiWfResetItem> get items => wfList(json['items'], UiWfResetItem.fromJson);

  /// Send back with the reset ([UiWorkflowApi.resetRecord]'s `token`): if the list changed since, the
  /// reset fails with `resetChanged`. Older engines omit it.
  String? get token => wfStrOrNull(json['token']);
}

/// What [UiWorkflowApi.updatePermissions] returns: the published version's summary, and what the
/// change did.
extension type const UiWfPermissionsSummary._(UiJson json) implements UiWfDefinitionSummary {
  UiWfPermissionsSummary.fromJson(Object? j) : json = wfMap(j);

  /// False when nothing changed (no new version was published); null from older engines.
  bool? get changed => json['changed'] is bool ? json['changed'] as bool : null;

  /// Steps or moves the draft no longer has, so the draft kept them as they were.
  List<String> get draftSkipped => wfStrings(json['draftSkipped']);

  /// Records moved onto the new version, so the new permissions apply to them too.
  int get recordsMoved => wfInt(json['recordsMoved']) ?? 0;
}

extension type const UiWfAuditEntry._(UiJson json) implements Object {
  UiWfAuditEntry.fromJson(Object? j) : json = wfMap(j);
  int get seq => wfInt(json['seq']) ?? 0;
  String get id => wfStr(json['id']);
  String get at => wfStr(json['at']);
  String? get tenant => wfStrOrNull(json['tenant']);

  /// `user`, `system`, `workflow`…
  String get actorType => wfStr(json['actorType']);
  String? get actorId => wfStrOrNull(json['actorId']);
  String? get actorName => wfStrOrNull(json['actorName']);
  String get category => wfStr(json['category']);
  String get action => wfStr(json['action']);
  String get subjectType => wfStr(json['subjectType']);
  String get subjectId => wfStr(json['subjectId']);
  String? get entity => wfStrOrNull(json['entity']);
  String? get entityId => wfStrOrNull(json['entityId']);
  String? get instanceId => wfStrOrNull(json['instanceId']);
  String? get definitionId => wfStrOrNull(json['definitionId']);

  /// JSON text.
  String? get before => wfStrOrNull(json['before']);
  String? get after => wfStrOrNull(json['after']);
  String? get data => wfStrOrNull(json['data']);
  String get correlationId => wfStr(json['correlationId']);
  String? get causationId => wfStrOrNull(json['causationId']);
  String get prevHash => wfStr(json['prevHash']);
  String get hash => wfStr(json['hash']);
}

extension type const UiWfAuditVerification._(UiJson json) implements Object {
  UiWfAuditVerification.fromJson(Object? j) : json = wfMap(j);
  bool get valid => json['valid'] == true;
  int get checked => wfInt(json['checked']) ?? 0;
  int? get brokenAtSeq => wfInt(json['brokenAtSeq']);
  String? get problem => wfStrOrNull(json['problem']);

  /// `[{from, to}]`.
  List<UiJson> get purgedGaps => wfList(json['purgedGaps'], wfMap);
}

/// A page of results.
class UiWfPage<T> {
  const UiWfPage(this.items, this.total);
  final List<T> items;
  final int total;
}

extension type const UiWfUser._(UiJson json) implements Object {
  UiWfUser.fromJson(Object? j) : json = wfMap(j);
  String get id => wfStr(json['id']);
  String get name => wfStr(json['name']);
  String? get email => wfStrOrNull(json['email']);
  List<String>? get roles => wfStringsOrNull(json['roles']);
  List<String>? get groups => wfStringsOrNull(json['groups']);
}

/// The signed-in person, as the engine sees them, and what they may do (`GET /me`).
extension type const UiWfMe._(UiJson json) implements Object {
  UiWfMe.fromJson(Object? j) : json = wfMap(j);
  String get type => wfStr(json['type']);
  String? get id => wfStrOrNull(json['id']);
  String? get name => wfStrOrNull(json['name']);
  List<String> get roles => wfStrings(json['roles']);
  bool _can(String k) => wfMap(json['can'])[k] == true;
  bool get canEdit => _can('edit');
  bool get canPublish => _can('publish');
  bool get canSettings => _can('settings');
  bool get canIntervene => _can('intervene');
  bool get canAudit => _can('audit');

  /// `{edit, publish, settings, intervene, audit}`.
  UiJson get can => wfMap(json['can']);
}

extension type const UiWfTriggerOverview._(UiJson json) implements Object {
  UiWfTriggerOverview.fromJson(Object? j) : json = wfMap(j);
  String get definitionId => wfStr(json['definitionId']);
  String get definitionKey => wfStr(json['definitionKey']);
  String get title => wfStr(json['title']);
  String get kind => wfStr(json['kind'], 'automation');
  String get type => wfStr(json['type']);
  String? get entity => wfStrOrNull(json['entity']);
  String? get field => wfStrOrNull(json['field']);
  String get summary => wfStr(json['summary']);
  int get version => wfInt(json['version']) ?? 0;
}

/// Something that happens during a test run: `decide`, `advance`, `signal` or `set`.
extension type const UiWfSimulationEvent._(UiJson json) implements Object {
  UiWfSimulationEvent.fromJson(Object? j) : json = wfMap(j);
  UiWfSimulationEvent(String type, [UiJson more = const {}]) : json = wfCompact({'type': type, ...more});
  String get type => wfStr(json['type']);
  String? get step => wfStrOrNull(json['step']);
  String? get outcome => wfStrOrNull(json['outcome']);
  String? get comment => wfStrOrNull(json['comment']);
  UiJson? get data => wfMapOrNull(json['data']);
  String? get user => wfStrOrNull(json['user']);
  String? get duration => wfStrOrNull(json['duration']);
  String? get signal => wfStrOrNull(json['signal']);
  UiJson? get values => wfMapOrNull(json['values']);
  UiWfSimulationEvent patch(UiJson p) => UiWfSimulationEvent._(wfPatch(json, p));
}

/// What a test run starts from: `{entityId?, values?, trigger?, fromState?, transition?, input?, events?}`.
extension type const UiWfSimulationRequest._(UiJson json) implements Object {
  UiWfSimulationRequest.fromJson(Object? j) : json = wfMap(j);
  UiWfSimulationRequest({String? entityId, UiJson? values, UiJson? trigger, String? fromState, String? transition, UiJson? input, List<UiWfSimulationEvent>? events})
    : json = wfCompact({'entityId': entityId, 'values': values, 'trigger': trigger, 'fromState': fromState, 'transition': transition, 'input': input, 'events': events});
  String? get entityId => wfStrOrNull(json['entityId']);
  String? get fromState => wfStrOrNull(json['fromState']);
  String? get transition => wfStrOrNull(json['transition']);
  UiJson? get trigger => wfMapOrNull(json['trigger']);
  List<UiWfSimulationEvent> get events => wfList(json['events'], UiWfSimulationEvent.fromJson);
}

/// One line of a test run's log.
extension type const UiWfSimulationLog._(UiJson json) implements Object {
  UiWfSimulationLog.fromJson(Object? j) : json = wfMap(j);
  String get kind => wfStr(json['kind']);
  String get action => wfStr(json['action']);
  String? get subject => wfStrOrNull(json['subject']);
  String? get text => wfStrOrNull(json['text']);
  Object? get data => json['data'];
  String get at => wfStr(json['at']);
}

extension type const UiWfSimulationResult._(UiJson json) implements Object {
  UiWfSimulationResult.fromJson(Object? j) : json = wfMap(j);
  List<UiWfProblem> get problems => wfList(json['problems'], UiWfProblem.fromJson);
  List<UiWfSimulationLog> get log => wfList(json['log'], UiWfSimulationLog.fromJson);
  List<UiWfInstance> get instances => wfList(json['instances'], UiWfInstance.fromJson);
  List<UiWfTask> get openTasks => wfList(json['openTasks'], UiWfTask.fromJson);
  UiJson? get record => wfMapOrNull(json['record']);
  String? get error => wfStrOrNull(json['error']);
}

/// Filters for `GET /instances`.
class UiWfInstanceQuery {
  const UiWfInstanceQuery({this.definitionId, this.definitionKey, this.entity, this.entityId, this.status, this.kind, this.parentId, this.skip, this.take});
  final String? definitionId;
  final String? definitionKey;
  final String? entity;
  final String? entityId;
  final List<String>? status;
  final List<String>? kind;
  final String? parentId;
  final int? skip;
  final int? take;

  Map<String, Object?> toParams() => {
    'definitionId': definitionId, 'definitionKey': definitionKey, 'entity': entity, 'entityId': entityId,
    'status': status, 'kind': kind, 'parentId': parentId, 'skip': skip, 'take': take,
  };
}

/// Filters for `GET /tasks`.
class UiWfTaskQuery {
  const UiWfTaskQuery({this.scope, this.status, this.entity, this.entityId, this.skip, this.take});

  /// `mine` or `all`.
  final String? scope;
  final List<String>? status;
  final String? entity;
  final String? entityId;
  final int? skip;
  final int? take;

  Map<String, Object?> toParams() => {'scope': scope, 'status': status, 'entity': entity, 'entityId': entityId, 'skip': skip, 'take': take};
}

/// Filters for `GET /audit` (and its export, with [format] `csv` or `json`).
class UiWfAuditQuery {
  const UiWfAuditQuery({this.category, this.action, this.entity, this.entityId, this.instanceId, this.definitionId, this.actorId, this.from, this.to, this.before, this.take, this.format});
  final String? category;
  final String? action;
  final String? entity;
  final String? entityId;
  final String? instanceId;
  final String? definitionId;
  final String? actorId;
  final String? from;
  final String? to;
  final int? before;
  final int? take;
  final String? format;

  UiWfAuditQuery copyWith({int? before, String? format}) => UiWfAuditQuery(
    category: category, action: action, entity: entity, entityId: entityId, instanceId: instanceId, definitionId: definitionId,
    actorId: actorId, from: from, to: to, before: before ?? this.before, take: take, format: format ?? this.format,
  );

  Map<String, Object?> toParams() => {
    'category': category, 'action': action, 'entity': entity, 'entityId': entityId, 'instanceId': instanceId, 'definitionId': definitionId,
    'actorId': actorId, 'from': from, 'to': to, 'before': before, 'take': take, 'format': format,
  };
}

/// A refusal from the engine, e.g. `code: 'notAllowed', message: 'You are not allowed to “Approve”.'`.
class UiWfApiError implements Exception {
  const UiWfApiError(this.status, this.code, this.message, [this.details]);
  final int status;
  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => 'UiWfApiError($status, $code): $message';
}

/// Everything the workflow widgets ask of an engine. [UiWorkflowHttpApi] calls the REST API;
/// tests and demos can supply their own.
abstract class UiWorkflowApi {
  Future<UiWorkflowSchema> schema();

  /// Who is signed in and what they may do. Optional: this default answers null ("not known"),
  /// and then the builder and the permissions page offer editing and the server decides. An API
  /// that `extends UiWorkflowApi` can leave it out; one that `implements` it returns null.
  Future<UiWfMe?> me() async => null;
  Future<({UiWorkflowSettings settings, int revision})> settings();
  Future<int> saveSettings(UiWorkflowSettings settings, int revision);
  Future<List<UiWfTriggerOverview>> triggers();
  Future<List<UiWfUser>> searchUsers(String query, {int take = 20});
  Future<UiWfUser?> user(String id);

  Future<List<UiWfDefinitionSummary>> definitions();
  Future<UiWfDefinitionDetail> definition(String id);
  Future<UiWfDefinitionSummary> createDefinition(UiWorkflowDefinition def);
  Future<UiWfDefinitionSummary> saveDraft(UiWorkflowDefinition def);
  Future<void> deleteDefinition(String id);
  Future<UiWfDefinitionSummary> publish(String id, {String? note});
  Future<UiWfDefinitionSummary> archive(String id);
  Future<UiWfDefinitionSummary> restore(String id);
  Future<UiWfDefinitionSummary> rollback(String id, int version);

  /// Changes who may do what in a published workflow at once: publishes a new version that is the
  /// current one plus only these changes (and applies them to the draft, if any). `node` is a
  /// transition or step id, `reset` or `trigger`.
  Future<UiWfPermissionsSummary> updatePermissions(String id, List<({String node, List<UiWfAssignee> who})> changes, {String? note});
  Future<UiWorkflowDefinition> version(String id, int version);
  Future<List<String>> diff(String id);
  Future<List<UiWfProblem>> validate(UiWorkflowDefinition def);
  Future<UiWfSimulationResult> simulate(UiWorkflowDefinition def, UiWfSimulationRequest request);

  Future<UiWfPage<UiWfInstance>> instances(UiWfInstanceQuery q);
  Future<UiWfInstance> instance(String id);
  Future<UiWorkflowDefinition> instanceDefinition(String id);
  Future<UiWfInstance> cancel(String id, {String? reason});
  /// Retries a stopped step. [target] picks the incident (a token id or failed step id) when
  /// several paths stopped; null means the first.
  Future<UiWfInstance> retry(String id, {String? target});

  /// Skips a stopped step, optionally giving its outputs. [target] as for [retry].
  Future<UiWfInstance> skip(String id, {UiJson? outputs, String? target});
  Future<UiWfInstance> migrate(String id, int version, {Map<String, String>? stateMap});

  Future<UiWfPage<UiWfTask>> tasks(UiWfTaskQuery q);
  Future<UiWfTask> task(String id);
  Future<UiWfTask> decide(String id, String outcome, {String? comment, UiJson? data});
  Future<UiWfTask> delegate(String id, String to, {String? note});
  Future<UiWfTask> reassign(String id, List<String> assignees, {String? reason});

  Future<UiWfRecord> record(String entity, String id);
  Future<List<UiWfAuditEntry>> recordHistory(String entity, String id, {int take = 200});
  /// Makes a move, with its form's answers and the person's remarks ([comment]).
  Future<UiWfRecord> applyTransition(String entity, String id, String key, {UiJson? input, String? comment});
  Future<UiWfRecord> forceState(String entity, String id, String state, String reason, {bool skipSteps = false});

  /// What starting the record over would take back: every change its workflows made since it last
  /// started over. Optional (the web's `resetPreview?`): this default throws [UnimplementedError],
  /// and then the reset dialog only confirms. An API that `extends UiWorkflowApi` can leave it out;
  /// one that `implements` it throws [UnimplementedError] itself.
  Future<UiWfResetPreview> resetPreview(String entity, String id) async => throw UnimplementedError('resetPreview');

  /// Starts the record's workflow over (the lifecycle's reset), with the reset form's answers, the
  /// ids of the [resetPreview] items to take back, the person's remarks ([comment]) and the list's
  /// [token] (so a list that changed since fails with `resetChanged` instead of overwriting).
  Future<UiWfRecord> resetRecord(String entity, String id, {UiJson? input, List<String>? undo, String? comment, String? token});
  Future<UiWfInstance> startManual(String workflow, String? entity, String? id, {UiJson? input});

  Future<List<UiWfAuditEntry>> audit(UiWfAuditQuery q);
  String auditExportUrl(UiWfAuditQuery q);
  Future<Uint8List> exportAudit(UiWfAuditQuery q);
  Future<UiWfAuditVerification> verifyAudit({int? fromSeq});
}

/// The query string for [params]: empty values left out, lists joined with commas.
String uiWfQueryString(Map<String, Object?> params) {
  final parts = <String>[];
  for (final e in params.entries) {
    final v = e.value;
    if (v == null || v == '') continue;
    final s = v is List ? v.map(jsString).join(',') : jsString(v);
    parts.add('${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(s)}');
  }
  return parts.isEmpty ? '' : '?${parts.join('&')}';
}

String _e(String s) => Uri.encodeComponent(s);

/// The REST implementation of [UiWorkflowApi] (the web `UiWorkflowHttpApi`).
///
/// ```dart
/// final api = UiWorkflowHttpApi(baseUrl: 'https://app.example.com/api/workflows',
///     headers: () async => {'Authorization': 'Bearer ${await auth.token()}'});
/// ```
class UiWorkflowHttpApi implements UiWorkflowApi {
  UiWorkflowHttpApi({required String baseUrl, http.Client? client, this.headers}) : base = baseUrl.replaceFirst(RegExp(r'/+$'), ''), _client = client; // ignore: prefer_initializing_formals

  /// Where the API is mounted, without a trailing slash.
  final String base;

  /// Extra headers on every request (sign-in, a session…); called per request.
  final FutureOr<Map<String, String>> Function()? headers;

  /// Replace to route requests through your own HTTP layer (retries, logging, a test client).
  final http.Client? _client;
  http.Client? _own;
  http.Client get client => _client ?? (_own ??= http.Client());

  /// Closes the HTTP client this API made for itself (not one you passed in).
  void close() => _own?.close();

  Future<Object?> _call(String method, String path, [Object? body = _none]) async {
    final req = http.Request(method, Uri.parse(base + path));
    req.headers['Accept'] = 'application/json';
    if (!identical(body, _none)) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    if (headers != null) req.headers.addAll(await headers!());
    final res = await http.Response.fromStream(await client.send(req));
    if (res.statusCode == 204) return null;
    Object? json;
    try {
      json = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      json = null;
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final e = json is Map ? json : const {};
      final fallback = res.statusCode == 403 ? 'You are not allowed to do that.' : res.statusCode == 401 ? 'Please sign in.' : 'The server answered ${res.statusCode}.';
      throw UiWfApiError(res.statusCode, wfStrOrNull(e['code']) ?? 'http${res.statusCode}', wfStrOrNull(e['message']) ?? fallback, e['details']);
    }
    return json;
  }

  static const Object _none = Object();

  List<T> _list<T>(Object? j, T Function(Object? x) read) => wfList(j, read);
  UiWfPage<T> _page<T>(Object? j, T Function(Object? x) read) => UiWfPage(wfList(wfMap(j)['items'], read), wfInt(wfMap(j)['total']) ?? 0);

  @override
  Future<UiWorkflowSchema> schema() async => UiWorkflowSchema.fromJson(await _call('GET', '/schema'));
  @override
  Future<UiWfMe> me() async => UiWfMe.fromJson(await _call('GET', '/me'));
  @override
  Future<({UiWorkflowSettings settings, int revision})> settings() async {
    final j = wfMap(await _call('GET', '/settings'));
    return (settings: UiWorkflowSettings.fromJson(j['settings']), revision: wfInt(j['revision']) ?? 0);
  }

  @override
  Future<int> saveSettings(UiWorkflowSettings settings, int revision) async =>
      wfInt(wfMap(await _call('PUT', '/settings', {'settings': settings.json, 'revision': revision}))['revision']) ?? revision;
  @override
  Future<List<UiWfTriggerOverview>> triggers() async => _list(await _call('GET', '/triggers'), UiWfTriggerOverview.fromJson);
  @override
  Future<List<UiWfUser>> searchUsers(String query, {int take = 20}) async =>
      _list(await _call('GET', '/directory/users${uiWfQueryString({'q': query, 'take': take})}'), UiWfUser.fromJson);
  @override
  Future<UiWfUser?> user(String id) async {
    try {
      return UiWfUser.fromJson(await _call('GET', '/directory/users/${_e(id)}'));
    } on UiWfApiError catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  @override
  Future<List<UiWfDefinitionSummary>> definitions() async => _list(await _call('GET', '/definitions'), UiWfDefinitionSummary.fromJson);
  @override
  Future<UiWfDefinitionDetail> definition(String id) async => UiWfDefinitionDetail.fromJson(await _call('GET', '/definitions/${_e(id)}'));
  @override
  Future<UiWfDefinitionSummary> createDefinition(UiWorkflowDefinition def) async => UiWfDefinitionSummary.fromJson(await _call('POST', '/definitions', def.json));
  @override
  Future<UiWfDefinitionSummary> saveDraft(UiWorkflowDefinition def) async => UiWfDefinitionSummary.fromJson(await _call('PUT', '/definitions/${_e(def.id)}', def.json));
  @override
  Future<void> deleteDefinition(String id) async => _call('DELETE', '/definitions/${_e(id)}');
  @override
  Future<UiWfDefinitionSummary> publish(String id, {String? note}) async => UiWfDefinitionSummary.fromJson(await _call('POST', '/definitions/${_e(id)}/publish', {'note': note}));
  @override
  Future<UiWfDefinitionSummary> archive(String id) async => UiWfDefinitionSummary.fromJson(await _call('POST', '/definitions/${_e(id)}/archive'));
  @override
  Future<UiWfDefinitionSummary> restore(String id) async => UiWfDefinitionSummary.fromJson(await _call('POST', '/definitions/${_e(id)}/restore'));
  @override
  Future<UiWfDefinitionSummary> rollback(String id, int version) async => UiWfDefinitionSummary.fromJson(await _call('POST', '/definitions/${_e(id)}/rollback', {'version': version}));
  @override
  Future<UiWfPermissionsSummary> updatePermissions(String id, List<({String node, List<UiWfAssignee> who})> changes, {String? note}) async => UiWfPermissionsSummary.fromJson(await _call('POST', '/definitions/${_e(id)}/permissions', {
        'changes': [for (final c in changes) {'node': c.node, 'who': [for (final a in c.who) a.json]}],
        'note': note,
      }));
  @override
  Future<UiWorkflowDefinition> version(String id, int version) async => UiWorkflowDefinition.fromJson(await _call('GET', '/definitions/${_e(id)}/versions/$version'));
  @override
  Future<List<String>> diff(String id) async => wfStrings(await _call('GET', '/definitions/${_e(id)}/diff'));
  @override
  Future<List<UiWfProblem>> validate(UiWorkflowDefinition def) async => _list(await _call('POST', '/validate', def.json), UiWfProblem.fromJson);
  @override
  Future<UiWfSimulationResult> simulate(UiWorkflowDefinition def, UiWfSimulationRequest request) async =>
      UiWfSimulationResult.fromJson(await _call('POST', '/simulate', {'definition': def.json, 'request': request.json}));

  @override
  Future<UiWfPage<UiWfInstance>> instances(UiWfInstanceQuery q) async => _page(await _call('GET', '/instances${uiWfQueryString(q.toParams())}'), UiWfInstance.fromJson);
  @override
  Future<UiWfInstance> instance(String id) async => UiWfInstance.fromJson(await _call('GET', '/instances/${_e(id)}'));
  @override
  Future<UiWorkflowDefinition> instanceDefinition(String id) async => UiWorkflowDefinition.fromJson(await _call('GET', '/instances/${_e(id)}/definition'));
  @override
  Future<UiWfInstance> cancel(String id, {String? reason}) async => UiWfInstance.fromJson(await _call('POST', '/instances/${_e(id)}/cancel', {'reason': reason}));
  @override
  Future<UiWfInstance> retry(String id, {String? target}) async => UiWfInstance.fromJson(await _call('POST', '/instances/${_e(id)}/retry', {'target': target}));
  @override
  Future<UiWfInstance> skip(String id, {UiJson? outputs, String? target}) async =>
      UiWfInstance.fromJson(await _call('POST', '/instances/${_e(id)}/skip', {'outputs': outputs, 'target': target}));
  @override
  Future<UiWfInstance> migrate(String id, int version, {Map<String, String>? stateMap}) async =>
      UiWfInstance.fromJson(await _call('POST', '/instances/${_e(id)}/migrate', {'version': version, 'stateMap': stateMap}));

  @override
  Future<UiWfPage<UiWfTask>> tasks(UiWfTaskQuery q) async => _page(await _call('GET', '/tasks${uiWfQueryString(q.toParams())}'), UiWfTask.fromJson);
  @override
  Future<UiWfTask> task(String id) async => UiWfTask.fromJson(await _call('GET', '/tasks/${_e(id)}'));
  @override
  Future<UiWfTask> decide(String id, String outcome, {String? comment, UiJson? data}) async =>
      UiWfTask.fromJson(await _call('POST', '/tasks/${_e(id)}/decide', {'outcome': outcome, 'comment': comment, 'data': data}));
  @override
  Future<UiWfTask> delegate(String id, String to, {String? note}) async => UiWfTask.fromJson(await _call('POST', '/tasks/${_e(id)}/delegate', {'to': to, 'note': note}));
  @override
  Future<UiWfTask> reassign(String id, List<String> assignees, {String? reason}) async =>
      UiWfTask.fromJson(await _call('POST', '/tasks/${_e(id)}/reassign', {'assignees': assignees, 'reason': reason}));

  @override
  Future<UiWfRecord> record(String entity, String id) async => UiWfRecord.fromJson(await _call('GET', '/records/${_e(entity)}/${_e(id)}'));
  @override
  Future<List<UiWfAuditEntry>> recordHistory(String entity, String id, {int take = 200}) async =>
      _list(await _call('GET', '/records/${_e(entity)}/${_e(id)}/history${uiWfQueryString({'take': take})}'), UiWfAuditEntry.fromJson);
  @override
  Future<UiWfRecord> applyTransition(String entity, String id, String key, {UiJson? input, String? comment}) async =>
      UiWfRecord.fromJson(await _call('POST', '/records/${_e(entity)}/${_e(id)}/transitions/${_e(key)}', {
        'input': input,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      }));
  @override
  Future<UiWfRecord> forceState(String entity, String id, String state, String reason, {bool skipSteps = false}) async =>
      UiWfRecord.fromJson(await _call('POST', '/records/${_e(entity)}/${_e(id)}/force-state', {'state': state, 'reason': reason, 'skipSteps': skipSteps}));
  @override
  Future<UiWfResetPreview> resetPreview(String entity, String id) async =>
      UiWfResetPreview.fromJson(await _call('GET', '/records/${_e(entity)}/${_e(id)}/reset'));

  @override
  Future<UiWfRecord> resetRecord(String entity, String id, {UiJson? input, List<String>? undo, String? comment, String? token}) async =>
      UiWfRecord.fromJson(await _call('POST', '/records/${_e(entity)}/${_e(id)}/reset', {
        'input': input ?? const <String, Object?>{},
        if (undo != null && undo.isNotEmpty) 'undo': undo,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
        if (token != null && token.isNotEmpty) 'token': token,
      }));
  @override
  Future<UiWfInstance> startManual(String workflow, String? entity, String? id, {UiJson? input}) async {
    final path = entity != null && entity.isNotEmpty && id != null && id.isNotEmpty
        ? '/records/${_e(entity)}/${_e(id)}/manual/${_e(workflow)}'
        : '/manual/${_e(workflow)}';
    return UiWfInstance.fromJson(await _call('POST', path, {'input': input}));
  }

  @override
  Future<List<UiWfAuditEntry>> audit(UiWfAuditQuery q) async => _list(await _call('GET', '/audit${uiWfQueryString(q.toParams())}'), UiWfAuditEntry.fromJson);
  @override
  String auditExportUrl(UiWfAuditQuery q) => '$base/audit/export${uiWfQueryString(q.toParams())}';
  @override
  Future<Uint8List> exportAudit(UiWfAuditQuery q) async {
    final req = http.Request('GET', Uri.parse(auditExportUrl(q)));
    if (headers != null) req.headers.addAll(await headers!());
    final res = await http.Response.fromStream(await client.send(req));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw UiWfApiError(res.statusCode, 'http${res.statusCode}', res.statusCode == 403 ? 'You are not allowed to export the audit log.' : 'The server answered ${res.statusCode}.');
    }
    return res.bodyBytes;
  }

  @override
  Future<UiWfAuditVerification> verifyAudit({int? fromSeq}) async => UiWfAuditVerification.fromJson(await _call('POST', '/audit/verify${uiWfQueryString({'fromSeq': fromSeq})}'));
}
