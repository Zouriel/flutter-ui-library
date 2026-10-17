/// The workflow definition format (Zouriel Workflows spec v1) shared by [UiWorkflowBuilder] (which
/// edits it) and the engines that run it. It is the same JSON the Angular `@zouriel/ui/workflow`
/// reads and writes, so a workflow built on the web opens unchanged in Flutter and back.
///
/// Every type here is a zero-cost typed view (an extension type) over the JSON object itself:
/// `step.json` is the stored map. Reading never copies and never drops anything, so keys this
/// version doesn't know survive a round trip untouched. Views are treated as immutable: the
/// definition helpers (`definition.dart`) make new objects the way the web helpers spread them,
/// so an unchanged part of a definition stays the identical object.
///
/// Identity: states, transitions, steps, paths, cases and outcomes have an immutable `id`.
/// References inside a definition point at ids, except token paths (`entity.status`,
/// `steps.s3.outcome`), which point at registry keys and step ids.
library;

import 'json.dart';

const int uiWfSpecVersion = 1;

// ── Values ──────────────────────────────────────────────────────────────────────────────────

/// A value: `{const}`, `{ref}` (a token path), `{today}` (today ± days) or `{calc}`.
extension type const UiWfOperand._(UiJson json) implements Object {
  UiWfOperand.fromJson(Object? j) : json = wfMap(j);
  UiWfOperand.constant(Object? value) : json = {'const': value};
  UiWfOperand.ref(String path) : json = {'ref': path};
  UiWfOperand.today(num days) : json = {'today': days};

  bool get isRef => json.containsKey('ref');
  bool get isToday => json.containsKey('today');
  bool get isCalc => json.containsKey('calc');
  bool get isConst => !isRef && !isToday && !isCalc;
  String? get ref => isRef ? wfStr(json['ref']) : null;
  num? get today => isToday ? (wfNum(json['today']) ?? 0) : null;
  Object? get constValue => json['const'];

  /// The calculation (form-builder calc JSON over token paths).
  UiJson? get calc => wfMapOrNull(json['calc']);
  UiJson toJson() => json;
}

/// Text with tokens: a string, or a list of strings and `{ref}` parts.
extension type const UiWfTemplate._(Object json) implements Object {
  UiWfTemplate.fromJson(Object? j) : json = j is List ? j : wfStr(j);
  const UiWfTemplate.text(String text) : json = text;
  UiWfTemplate.parts(List<Object> parts) : json = parts;

  bool get isText => json is String;

  /// The parts: strings and token paths (as [UiWfTemplateRef]).
  List<Object> get parts {
    final j = json;
    if (j is String) return j.isEmpty ? const [] : [j];
    return [
      for (final p in j as List)
        if (p is Map) UiWfTemplateRef(wfStr(p['ref'])) else wfStr(p),
    ];
  }

  bool get isEmpty => parts.isEmpty;
  Object toJson() => json;
}

/// A token in a template.
class UiWfTemplateRef {
  const UiWfTemplateRef(this.ref);
  final String ref;
  UiJson toJson() => {'ref': ref};
  @override
  bool operator ==(Object other) => other is UiWfTemplateRef && other.ref == ref;
  @override
  int get hashCode => ref.hashCode;
}

/// The form builder's condition JSON with token paths as `ref`: a rule, or a group of conditions.
extension type const UiWfCondition._(UiJson json) implements Object {
  UiWfCondition.fromJson(Object? j) : json = wfMap(j);
  UiWfCondition.group(String match, List<UiWfCondition> conditions) : json = {'match': match, 'conditions': conditions};
  UiWfCondition.rule(String ref, String op, {UiWfOperand? value, UiWfOperand? value2})
    : json = wfCompact({'ref': ref, 'op': op, 'value': value, 'value2': value2});

  /// An empty "all of these" group.
  static UiWfCondition empty() => UiWfCondition.group('all', []);

  bool get isGroup => json.containsKey('conditions');

  /// `all`, `any` or `none` (groups).
  String get match => wfStr(json['match'], 'all');
  List<UiWfCondition> get conditions => wfList(json['conditions'], UiWfCondition.fromJson);

  /// The token path a rule checks.
  String get ref => wfStr(json['ref']);

  /// A form-builder operator name (`eq`, `anyOf`, `before`…).
  String get op => wfStr(json['op'], 'eq');
  UiWfOperand? get value => json['value'] is Map ? UiWfOperand.fromJson(json['value']) : null;
  UiWfOperand? get value2 => json['value2'] is Map ? UiWfOperand.fromJson(json['value2']) : null;
  UiJson toJson() => json;
}

/// One entry of a people list: exactly one of `role`, `group`, `user`, `field`, `managerOf`,
/// `initiator`, or (recipients only) `email`.
extension type const UiWfAssignee._(UiJson json) implements Object {
  UiWfAssignee.fromJson(Object? j) : json = wfMap(j);
  UiWfAssignee.role(String key) : json = {'role': key};
  UiWfAssignee.group(String key) : json = {'group': key};
  UiWfAssignee.user(String id) : json = {'user': id};
  UiWfAssignee.field(String path) : json = {'field': path};
  UiWfAssignee.managerOf(String of) : json = {'managerOf': of};
  UiWfAssignee.initiator() : json = {'initiator': true};
  UiWfAssignee.email(UiWfTemplate email) : json = {'email': email.json};

  static const kinds = ['role', 'group', 'user', 'field', 'managerOf', 'initiator', 'email'];

  /// Which key is set.
  String get kind => kinds.firstWhere(json.containsKey, orElse: () => '');
  String get value => kind == 'email' || kind == 'initiator' ? '' : wfStr(json[kind]);
  UiWfTemplate? get email => json.containsKey('email') ? UiWfTemplate.fromJson(json['email']) : null;
  UiJson toJson() => json;
}

/// Who counts deadlines how: `calendar` or `working`.
abstract final class UiWfCalendar {
  static const calendar = 'calendar';
  static const working = 'working';
}

// ── Triggers ────────────────────────────────────────────────────────────────────────────────

/// Trigger types: `created`, `fieldChanged`, `stateEntered`, `transitionApplied`, `deleted`,
/// `dateReached`, `schedule`, `manual`, `signal`.
const List<String> uiWfTriggerTypes = ['created', 'fieldChanged', 'stateEntered', 'transitionApplied', 'deleted', 'dateReached', 'schedule', 'manual', 'signal'];

extension type const UiWfTrigger._(UiJson json) implements Object {
  UiWfTrigger.fromJson(Object? j) : json = wfMap(j);
  UiWfTrigger(String type) : json = {'type': type};

  String get type => wfStr(json['type'], 'fieldChanged');
  UiWfCondition? get when => json['when'] is Map ? UiWfCondition.fromJson(json['when']) : null;
  bool get retrigger => json['retrigger'] == true;
  String? get field => wfStrOrNull(json['field']);
  List<Object?>? get from => json['from'] is List ? List<Object?>.of(json['from'] as List) : null;
  List<Object?>? get to => json['to'] is List ? List<Object?>.of(json['to'] as List) : null;
  String? get lifecycle => wfStrOrNull(json['lifecycle']);
  List<String>? get states => wfStringsOrNull(json['states']);
  List<String>? get transitions => wfStringsOrNull(json['transitions']);
  String? get offset => wfStrOrNull(json['offset']);
  String? get at => wfStrOrNull(json['at']);
  String? get cron => wfStrOrNull(json['cron']);

  /// `{when?, limit}`: run once per matching record (schedules).
  UiJson? get forEach => wfMapOrNull(json['forEach']);
  String? get label => wfStrOrNull(json['label']);

  /// A form definition (form-builder JSON) asked when starting by hand.
  UiJson? get form => wfMapOrNull(json['form']);
  List<UiWfAssignee>? get who => wfListOrNull(json['who'], UiWfAssignee.fromJson);
  String? get signal => wfStrOrNull(json['signal']);
  UiWfTrigger patch(UiJson p) => UiWfTrigger._(wfPatch(json, p));
  UiJson toJson() => json;
}

// ── Steps ───────────────────────────────────────────────────────────────────────────────────

extension type const UiWfRetry._(UiJson json) implements Object {
  UiWfRetry.fromJson(Object? j) : json = wfMap(j);
  int get max => wfInt(json['max']) ?? 0;

  /// `fixed` or `exponential`.
  String? get backoff => wfStrOrNull(json['backoff']);
  String? get initial => wfStrOrNull(json['initial']);
  String? get maxDelay => wfStrOrNull(json['maxDelay']);
  UiJson toJson() => json;
}

/// A list of steps with an id (an "otherwise", a parallel path, a timeout list…).
extension type const UiWfStepList._(UiJson json) implements Object {
  UiWfStepList.fromJson(Object? j) : json = wfMap(j);
  UiWfStepList({required String id, String? label, List<UiWfStep> steps = const []}) : json = wfCompact({'id': id, 'label': label, 'steps': steps});
  String get id => wfStr(json['id']);
  String? get label => wfStrOrNull(json['label']);
  List<UiWfStep> get steps => wfList(json['steps'], UiWfStep.fromJson);
  UiJson toJson() => json;
}

/// Step types, in the spec's words.
abstract final class UiWfStepType {
  static const approval = 'approval';
  static const task = 'task';
  static const branch = 'branch';
  static const switchStep = 'switch';
  static const parallel = 'parallel';
  static const forEach = 'forEach';
  static const wait = 'wait';
  static const setFields = 'setFields';
  static const setVariables = 'setVariables';
  static const applyTransition = 'applyTransition';
  static const notify = 'notify';
  static const webhook = 'webhook';
  static const action = 'action';
  static const subWorkflow = 'subWorkflow';
  static const goTo = 'goTo';
  static const end = 'end';
}

/// Any step. Read its type's settings through the typed views ([UiWfApprovalStep.of]…).
extension type const UiWfStep._(UiJson json) implements Object {
  UiWfStep.fromJson(Object? j) : json = wfMap(j);

  String get id => wfStr(json['id']);
  String get type => wfStr(json['type']);
  String? get title => wfStrOrNull(json['title']);
  String? get note => wfStrOrNull(json['note']);
  bool get disabled => json['disabled'] == true;
  UiWfRetry? get retry => json['retry'] is Map ? UiWfRetry.fromJson(json['retry']) : null;
  String? get timeout => wfStrOrNull(json['timeout']);

  /// `stop`, `continue`, or `{steps}` (raw).
  Object? get onError => json['onError'];

  /// The steps run when it fails, when [onError] is a list.
  List<UiWfStep>? get onErrorSteps => json['onError'] is Map ? wfList(wfMap(json['onError'])['steps'], UiWfStep.fromJson) : null;

  /// A copy with [p] merged in (null values remove keys).
  UiWfStep patch(UiJson p) => UiWfStep._(wfPatch(json, p));
  UiJson toJson() => json;
}

/// `{id, label, when?, steps}`: one path of a branch.
extension type const UiWfBranchPath._(UiJson json) implements Object {
  UiWfBranchPath.fromJson(Object? j) : json = wfMap(j);
  String get id => wfStr(json['id']);
  String get label => wfStr(json['label']);
  UiWfCondition? get when => json['when'] is Map ? UiWfCondition.fromJson(json['when']) : null;
  List<UiWfStep> get steps => wfList(json['steps'], UiWfStep.fromJson);
  UiWfBranchPath patch(UiJson p) => UiWfBranchPath._(wfPatch(json, p));
}

extension type const UiWfBranchStep._(UiJson json) implements UiWfStep {
  UiWfBranchStep.of(UiWfStep s) : json = s.json;
  List<UiWfBranchPath> get paths => wfList(json['paths'], UiWfBranchPath.fromJson);
  UiWfStepList? get otherwise => json['otherwise'] is Map ? UiWfStepList.fromJson(json['otherwise']) : null;
}

/// `{id, label, values, steps}`: one case of a switch.
extension type const UiWfSwitchCase._(UiJson json) implements Object {
  UiWfSwitchCase.fromJson(Object? j) : json = wfMap(j);
  String get id => wfStr(json['id']);
  String get label => wfStr(json['label']);
  List<Object?> get values => json['values'] is List ? List<Object?>.of(json['values'] as List) : <Object?>[];
  List<UiWfStep> get steps => wfList(json['steps'], UiWfStep.fromJson);
  UiWfSwitchCase patch(UiJson p) => UiWfSwitchCase._(wfPatch(json, p));
}

extension type const UiWfSwitchStep._(UiJson json) implements UiWfStep {
  UiWfSwitchStep.of(UiWfStep s) : json = s.json;
  String get on => wfStr(json['on']);
  List<UiWfSwitchCase> get cases => wfList(json['cases'], UiWfSwitchCase.fromJson);
  UiWfStepList? get otherwise => json['otherwise'] is Map ? UiWfStepList.fromJson(json['otherwise']) : null;
}

extension type const UiWfParallelStep._(UiJson json) implements UiWfStep {
  UiWfParallelStep.of(UiWfStep s) : json = s.json;
  List<UiWfStepList> get paths => wfList(json['paths'], UiWfStepList.fromJson);

  /// `all`, `any` or `count`.
  String get joinType => wfStr(wfMap(json['join'])['type'], 'all');
  int? get joinCount => wfInt(wfMap(json['join'])['count']);
}

extension type const UiWfForEachStep._(UiJson json) implements UiWfStep {
  UiWfForEachStep.of(UiWfStep s) : json = s.json;
  String get collection => wfStr(json['collection']);
  UiWfCondition? get when => json['when'] is Map ? UiWfCondition.fromJson(json['when']) : null;

  /// `sequential` or `parallel`.
  String get mode => wfStr(json['mode'], 'sequential');
  int? get concurrency => wfInt(json['concurrency']);
  int get max => wfInt(json['max']) ?? 100;
  List<UiWfStep> get steps => wfList(json['steps'], UiWfStep.fromJson);
}

/// `{after, assignees, notify?}`.
extension type const UiWfEscalation._(UiJson json) implements Object {
  UiWfEscalation.fromJson(Object? j) : json = wfMap(j);
  String get after => wfStr(json['after']);
  List<UiWfAssignee> get assignees => wfList(json['assignees'], UiWfAssignee.fromJson);
  bool get notify => json['notify'] == true;
}

/// What approval and task steps share: people, a deadline, reminders, escalation, a form.
extension type const UiWfHumanStep._(UiJson json) implements UiWfStep {
  UiWfHumanStep.of(UiWfStep s) : json = s.json;
  List<UiWfAssignee> get assignees => wfList(json['assignees'], UiWfAssignee.fromJson);
  String get due => wfStr(json['due']);
  String? get calendar => wfStrOrNull(json['calendar']);
  List<String>? get reminders => wfStringsOrNull(json['reminders']);
  UiWfEscalation? get escalation => json['escalation'] is Map ? UiWfEscalation.fromJson(json['escalation']) : null;
  UiJson? get form => wfMapOrNull(json['form']);
  UiWfTemplate? get instructions => json.containsKey('instructions') ? UiWfTemplate.fromJson(json['instructions']) : null;
  bool get allowDelegation => json['allowDelegation'] == true;

  /// `never`, `reject` (approvals) or `always`.
  String? get requireComment => wfStrOrNull(json['requireComment']);
}

extension type const UiWfApprovalStep._(UiJson json) implements UiWfHumanStep {
  UiWfApprovalStep.of(UiWfStep s) : json = s.json;

  /// `any`, `all`, `count` or `percent`.
  String get ruleType => wfStr(wfMap(json['rule'])['type'], 'any');
  num? get ruleValue => wfNum(wfMap(json['rule'])['value']);
  List<UiWfStep> outcome(String key) => wfList(wfMap(json['outcomes'])[key], UiWfStep.fromJson);
}

/// `{id, key, label, tone?, steps}`: one button of a task.
extension type const UiWfTaskOutcome._(UiJson json) implements Object {
  UiWfTaskOutcome.fromJson(Object? j) : json = wfMap(j);
  String get id => wfStr(json['id']);
  String get key => wfStr(json['key']);
  String get label => wfStr(json['label']);
  String? get tone => wfStrOrNull(json['tone']);
  List<UiWfStep> get steps => wfList(json['steps'], UiWfStep.fromJson);
  UiWfTaskOutcome patch(UiJson p) => UiWfTaskOutcome._(wfPatch(json, p));
}

extension type const UiWfTaskStep._(UiJson json) implements UiWfHumanStep {
  UiWfTaskStep.of(UiWfStep s) : json = s.json;
  List<UiWfTaskOutcome> get outcomes => wfList(json['outcomes'], UiWfTaskOutcome.fromJson);
  UiWfStepList get onTimeout => UiWfStepList.fromJson(json['onTimeout']);
}

/// What a wait step waits for: `duration`, `date`, `condition` or `signal`.
extension type const UiWfWaitUntil._(UiJson json) implements Object {
  UiWfWaitUntil.fromJson(Object? j) : json = wfMap(j);
  String get type => wfStr(json['type'], 'duration');
  String? get duration => wfStrOrNull(json['duration']);
  String? get calendar => wfStrOrNull(json['calendar']);
  UiWfOperand? get date => json['date'] is Map ? UiWfOperand.fromJson(json['date']) : null;
  String? get offset => wfStrOrNull(json['offset']);
  String? get at => wfStrOrNull(json['at']);
  UiWfCondition? get when => json['when'] is Map ? UiWfCondition.fromJson(json['when']) : null;
  String? get timeout => wfStrOrNull(json['timeout']);
  UiWfStepList? get onTimeout => json['onTimeout'] is Map ? UiWfStepList.fromJson(json['onTimeout']) : null;
  String? get signal => wfStrOrNull(json['signal']);
}

extension type const UiWfWaitStep._(UiJson json) implements UiWfStep {
  UiWfWaitStep.of(UiWfStep s) : json = s.json;
  UiWfWaitUntil get until => UiWfWaitUntil.fromJson(json['until']);
}

/// `{field, value}` in an update-record step.
extension type const UiWfFieldValue._(UiJson json) implements Object {
  UiWfFieldValue.fromJson(Object? j) : json = wfMap(j);
  String get field => wfStr(json['field']);
  UiWfOperand? get value => json['value'] is Map ? UiWfOperand.fromJson(json['value']) : null;
}

extension type const UiWfSetFieldsStep._(UiJson json) implements UiWfStep {
  UiWfSetFieldsStep.of(UiWfStep s) : json = s.json;
  String? get target => wfStrOrNull(json['target']);
  List<UiWfFieldValue> get values => wfList(json['values'], UiWfFieldValue.fromJson);
}

/// `{variable, value}` in a set-variables step (`variable` is the variable's id).
extension type const UiWfVariableValue._(UiJson json) implements Object {
  UiWfVariableValue.fromJson(Object? j) : json = wfMap(j);
  String get variable => wfStr(json['variable']);
  UiWfOperand? get value => json['value'] is Map ? UiWfOperand.fromJson(json['value']) : null;
}

extension type const UiWfSetVariablesStep._(UiJson json) implements UiWfStep {
  UiWfSetVariablesStep.of(UiWfStep s) : json = s.json;
  List<UiWfVariableValue> get values => wfList(json['values'], UiWfVariableValue.fromJson);
}

Map<String, UiWfOperand>? _operands(Object? v) => v is Map ? {for (final e in wfMap(v).entries) e.key: UiWfOperand.fromJson(e.value)} : null;

extension type const UiWfApplyTransitionStep._(UiJson json) implements UiWfStep {
  UiWfApplyTransitionStep.of(UiWfStep s) : json = s.json;
  String? get target => wfStrOrNull(json['target']);
  String get lifecycle => wfStr(json['lifecycle']);
  String get transition => wfStr(json['transition']);
  Map<String, UiWfOperand>? get input => _operands(json['input']);

  /// `fail` or `skip`.
  String get ifNotAllowed => wfStr(json['ifNotAllowed'], 'fail');
}

extension type const UiWfNotifyStep._(UiJson json) implements UiWfStep {
  UiWfNotifyStep.of(UiWfStep s) : json = s.json;
  String get channel => wfStr(json['channel']);
  List<UiWfAssignee> get to => wfList(json['to'], UiWfAssignee.fromJson);
  UiWfTemplate? get subject => json.containsKey('subject') ? UiWfTemplate.fromJson(json['subject']) : null;
  UiWfTemplate get body => UiWfTemplate.fromJson(json['body']);
  UiWfTemplate? get link => json.containsKey('link') ? UiWfTemplate.fromJson(json['link']) : null;
}

extension type const UiWfWebhookStep._(UiJson json) implements UiWfStep {
  UiWfWebhookStep.of(UiWfStep s) : json = s.json;
  String? get connection => wfStrOrNull(json['connection']);
  String? get url => wfStrOrNull(json['url']);

  /// `GET`, `POST`, `PUT`, `PATCH` or `DELETE`.
  String get method => wfStr(json['method'], 'POST');
  UiWfTemplate? get path => json.containsKey('path') ? UiWfTemplate.fromJson(json['path']) : null;
  Map<String, UiWfTemplate>? get headers => json['headers'] is Map ? {for (final e in wfMap(json['headers']).entries) e.key: UiWfTemplate.fromJson(e.value)} : null;
  bool get hasBody => json.containsKey('body');
  Object? get body => json['body'];
  List<int>? get expect => wfListOrNull(json['expect'], (x) => wfInt(x) ?? 0);
}

extension type const UiWfActionStep._(UiJson json) implements UiWfStep {
  UiWfActionStep.of(UiWfStep s) : json = s.json;
  String get action => wfStr(json['action']);
  Map<String, UiWfOperand>? get input => _operands(json['input']);
}

extension type const UiWfSubWorkflowStep._(UiJson json) implements UiWfStep {
  UiWfSubWorkflowStep.of(UiWfStep s) : json = s.json;
  String get workflow => wfStr(json['workflow']);
  String? get target => wfStrOrNull(json['target']);
  bool get wait => json['wait'] != false;
  Map<String, UiWfOperand>? get input => _operands(json['input']);
}

extension type const UiWfGoToStep._(UiJson json) implements UiWfStep {
  UiWfGoToStep.of(UiWfStep s) : json = s.json;
  String get target => wfStr(json['target']);
  int get maxTimes => wfInt(json['maxTimes']) ?? 3;
}

extension type const UiWfEndStep._(UiJson json) implements UiWfStep {
  UiWfEndStep.of(UiWfStep s) : json = s.json;

  /// `completed` or `failed`.
  String get result => wfStr(json['result'], 'completed');
  UiWfTemplate? get reason => json.containsKey('reason') ? UiWfTemplate.fromJson(json['reason']) : null;
}

/// Tones: `neutral`, `primary`, `info`, `success`, `warning`, `danger`.
const List<String> uiWfTones = ['neutral', 'primary', 'info', 'success', 'warning', 'danger'];

// ── Lifecycles ──────────────────────────────────────────────────────────────────────────────

/// `{within, calendar?, steps}`: what happens when a record stays in a state too long.
extension type const UiWfSla._(UiJson json) implements Object {
  UiWfSla.fromJson(Object? j) : json = wfMap(j);
  String get within => wfStr(json['within']);
  String? get calendar => wfStrOrNull(json['calendar']);
  List<UiWfStep> get steps => wfList(json['steps'], UiWfStep.fromJson);
}

extension type const UiWfState._(UiJson json) implements Object {
  UiWfState.fromJson(Object? j) : json = wfMap(j);

  String get id => wfStr(json['id']);

  /// The value stored in the record's field for this state.
  String get key => wfStr(json['key']);
  String get label => wfStr(json['label']);

  /// `initial`, `active` or `terminal`.
  String get category => wfStr(json['category'], 'active');
  String? get tone => wfStrOrNull(json['tone']);
  String? get description => wfStrOrNull(json['description']);
  List<UiWfStep>? get onEnter => wfListOrNull(json['onEnter'], UiWfStep.fromJson);
  List<UiWfStep>? get onExit => wfListOrNull(json['onExit'], UiWfStep.fromJson);
  bool get keepRunsOnExit => json['keepRunsOnExit'] == true;
  UiWfSla? get sla => json['sla'] is Map ? UiWfSla.fromJson(json['sla']) : null;
  UiWfState patch(UiJson p) => UiWfState._(wfPatch(json, p));
  UiJson toJson() => json;
}

extension type const UiWfTransition._(UiJson json) implements Object {
  UiWfTransition.fromJson(Object? j) : json = wfMap(j);

  String get id => wfStr(json['id']);
  String get key => wfStr(json['key']);
  String get label => wfStr(json['label']);

  /// Whether it starts from every non-final state (`from: '*'`).
  bool get fromAny => json['from'] == '*';

  /// The state ids it starts from (empty when [fromAny]).
  List<String> get from => fromAny ? const [] : wfStrings(json['from']);
  String get to => wfStr(json['to']);
  List<UiWfAssignee>? get who => wfListOrNull(json['who'], UiWfAssignee.fromJson);
  UiWfCondition? get when => json['when'] is Map ? UiWfCondition.fromJson(json['when']) : null;

  /// The form asked when applying it (`input.form`).
  UiJson? get inputForm => wfMapOrNull(wfMapOrNull(json['input'])?['form']);
  List<UiWfStep>? get steps => wfListOrNull(json['steps'], UiWfStep.fromJson);

  /// `{after, calendar?}` or `{when}`.
  UiJson? get auto => wfMapOrNull(json['auto']);
  String? get confirm => wfStrOrNull(json['confirm']);
  String? get tone => wfStrOrNull(json['tone']);
  bool get hidden => json['hidden'] == true;
  UiWfTransition patch(UiJson p) => UiWfTransition._(wfPatch(json, p));
  UiJson toJson() => json;
}

extension type const UiWfLifecycle._(UiJson json) implements Object {
  UiWfLifecycle.fromJson(Object? j) : json = wfMap(j);

  String get field => wfStr(json['field']);

  /// `enforce` or `observe`.
  String? get mode => wfStrOrNull(json['mode']);
  List<UiWfState> get states => wfList(json['states'], UiWfState.fromJson);
  List<UiWfTransition> get transitions => wfList(json['transitions'], UiWfTransition.fromJson);

  /// Positions on the diagram, by state id. States without one are placed automatically.
  Map<String, List<num>>? get layout => json['layout'] is Map
      ? {
          for (final e in wfMap(json['layout']).entries)
            if (e.value is List) e.key: [for (final n in e.value as List) if (n is num) n],
        }
      : null;
  UiWfLifecycle patch(UiJson p) => UiWfLifecycle._(wfPatch(json, p));
  UiJson toJson() => json;
}

// ── Definition ──────────────────────────────────────────────────────────────────────────────

extension type const UiWfVariable._(UiJson json) implements Object {
  UiWfVariable.fromJson(Object? j) : json = wfMap(j);
  String get id => wfStr(json['id']);
  String get key => wfStr(json['key']);
  String get label => wfStr(json['label']);

  /// `text`, `number`, `boolean`, `date`, `dateTime`, `user` or `json`.
  String get type => wfStr(json['type'], 'text');
  Object? get defaultValue => json['default'];
  UiWfVariable patch(UiJson p) => UiWfVariable._(wfPatch(json, p));
}

/// A definition's own `settings`.
extension type const UiWfDefinitionSettings._(UiJson json) implements Object {
  UiWfDefinitionSettings.fromJson(Object? j) : json = wfMap(j);

  /// `perRecordSerial`, `parallel` or `skipIfRunning`.
  String? get concurrency => wfStrOrNull(json['concurrency']);
  List<UiWfAssignee>? get owners => wfListOrNull(json['owners'], UiWfAssignee.fromJson);
  bool get notifyOwnersOnIncident => json['notifyOwnersOnIncident'] == true;
  String? get calendar => wfStrOrNull(json['calendar']);
}

/// A workflow: an automation (a trigger and steps) or a lifecycle (states and transitions).
extension type const UiWorkflowDefinition._(UiJson json) implements Object {
  UiWorkflowDefinition.fromJson(Object? j) : json = wfMap(j);

  int get specVersion => wfInt(json['specVersion']) ?? uiWfSpecVersion;
  String get id => wfStr(json['id']);
  String get key => wfStr(json['key']);

  /// `automation` or `lifecycle`.
  String get kind => wfStr(json['kind'], 'automation');
  bool get isLifecycle => kind == 'lifecycle';
  String get title => wfStr(json['title']);
  String? get description => wfStrOrNull(json['description']);
  int? get revision => wfInt(json['revision']);
  String? get entity => wfStrOrNull(json['entity']);
  UiWfTrigger? get trigger => json['trigger'] is Map ? UiWfTrigger.fromJson(json['trigger']) : null;
  List<UiWfStep>? get steps => wfListOrNull(json['steps'], UiWfStep.fromJson);
  UiWfLifecycle? get lifecycle => json['lifecycle'] is Map ? UiWfLifecycle.fromJson(json['lifecycle']) : null;
  List<UiWfVariable>? get variables => wfListOrNull(json['variables'], UiWfVariable.fromJson);
  UiWfDefinitionSettings? get settings => json['settings'] is Map ? UiWfDefinitionSettings.fromJson(json['settings']) : null;

  /// A copy with [p] merged in (null values remove keys).
  UiWorkflowDefinition patch(UiJson p) => UiWorkflowDefinition._(wfPatch(json, p));

  /// A deep copy (nothing shared with this one).
  UiWorkflowDefinition clone() => UiWorkflowDefinition._(jsonClone(json) as UiJson);
  UiJson toJson() => json;
}

// ── Registry (what the app allows workflows to use) ─────────────────────────────────────────

/// Field types: `text`, `longText`, `email`, `phone`, `url`, `number`, `currency`, `boolean`,
/// `date`, `dateTime`, `enum`, `user`, `relation`, `collection`, `json`.
const List<String> uiWfFieldTypes = ['text', 'longText', 'email', 'phone', 'url', 'number', 'currency', 'boolean', 'date', 'dateTime', 'enum', 'user', 'relation', 'collection', 'json'];

extension type const UiWfFieldOption._(UiJson json) implements Object {
  UiWfFieldOption.fromJson(Object? j) : json = wfMap(j);
  UiWfFieldOption(Object value, String label) : json = {'value': value, 'label': label};

  /// A string or a number.
  Object? get value => json['value'];
  String get label => wfStr(json['label']);
}

extension type const UiWfFieldDescriptor._(UiJson json) implements Object {
  UiWfFieldDescriptor.fromJson(Object? j) : json = wfMap(j);
  String get key => wfStr(json['key']);
  String get label => wfStr(json['label']);
  String get type => wfStr(json['type'], 'text');
  List<UiWfFieldOption>? get options => wfListOrNull(json['options'], UiWfFieldOption.fromJson);
  String? get entity => wfStrOrNull(json['entity']);
  bool get readable => json['readable'] != false;
  bool get watchable => json['watchable'] == true;
  bool get settable => json['settable'] == true;
  bool get lifecycle => json['lifecycle'] == true;
  bool get sensitive => json['sensitive'] == true;
  bool get required => json['required'] == true;
}

extension type const UiWfEntityDescriptor._(UiJson json) implements Object {
  UiWfEntityDescriptor.fromJson(Object? j) : json = wfMap(j);
  String get key => wfStr(json['key']);
  String get label => wfStr(json['label']);
  String? get pluralLabel => wfStrOrNull(json['pluralLabel']);
  String? get titleField => wfStrOrNull(json['titleField']);
  List<UiWfFieldDescriptor> get fields => wfList(json['fields'], UiWfFieldDescriptor.fromJson);
}

extension type const UiWfParamDescriptor._(UiJson json) implements Object {
  UiWfParamDescriptor.fromJson(Object? j) : json = wfMap(j);
  String get key => wfStr(json['key']);
  String get label => wfStr(json['label']);
  String get type => wfStr(json['type'], 'text');
  bool get required => json['required'] == true;
  List<UiWfFieldOption>? get options => wfListOrNull(json['options'], UiWfFieldOption.fromJson);
  String? get entity => wfStrOrNull(json['entity']);
  String? get description => wfStrOrNull(json['description']);
}

extension type const UiWfActionDescriptor._(UiJson json) implements Object {
  UiWfActionDescriptor.fromJson(Object? j) : json = wfMap(j);
  String get key => wfStr(json['key']);
  String get label => wfStr(json['label']);
  String? get description => wfStrOrNull(json['description']);
  String? get category => wfStrOrNull(json['category']);
  String? get entity => wfStrOrNull(json['entity']);
  List<UiWfParamDescriptor> get inputs => wfList(json['inputs'], UiWfParamDescriptor.fromJson);
  List<UiWfParamDescriptor> get outputs => wfList(json['outputs'], UiWfParamDescriptor.fromJson);
}

extension type const UiWfSignalDescriptor._(UiJson json) implements Object {
  UiWfSignalDescriptor.fromJson(Object? j) : json = wfMap(j);
  String get key => wfStr(json['key']);
  String get label => wfStr(json['label']);
  String? get entity => wfStrOrNull(json['entity']);
  List<UiWfParamDescriptor> get fields => wfList(json['fields'], UiWfParamDescriptor.fromJson);
}

/// `{key, label, description?}`: a channel, role or group.
extension type const UiWfLabelled._(UiJson json) implements Object {
  UiWfLabelled.fromJson(Object? j) : json = wfMap(j);
  String get key => wfStr(json['key']);
  String get label => wfStr(json['label']);
  String? get description => wfStrOrNull(json['description']);
}

/// What the app allows workflows to use: record types and their fields, actions, events,
/// channels, roles and groups.
extension type const UiWorkflowRegistry._(UiJson json) implements Object {
  UiWorkflowRegistry.fromJson(Object? j) : json = wfMap(j);
  List<UiWfEntityDescriptor> get entities => wfList(json['entities'], UiWfEntityDescriptor.fromJson);
  List<UiWfActionDescriptor>? get actions => wfListOrNull(json['actions'], UiWfActionDescriptor.fromJson);
  List<UiWfSignalDescriptor>? get signals => wfListOrNull(json['signals'], UiWfSignalDescriptor.fromJson);
  List<UiWfLabelled>? get channels => wfListOrNull(json['channels'], UiWfLabelled.fromJson);
  List<UiWfLabelled>? get roles => wfListOrNull(json['roles'], UiWfLabelled.fromJson);
  List<UiWfLabelled>? get groups => wfListOrNull(json['groups'], UiWfLabelled.fromJson);
  UiJson toJson() => json;
}

/// One step type as `GET /schema` reports it.
extension type const UiWfSchemaStep._(UiJson json) implements Object {
  UiWfSchemaStep.fromJson(Object? j) : json = wfMap(j);
  String get type => wfStr(json['type']);
  String get label => wfStr(json['label']);
  List<String> get outputs => wfStrings(json['outputs']);
}

/// `GET /schema`: the registry plus what each step type outputs.
extension type const UiWorkflowSchema._(UiJson json) implements Object {
  UiWorkflowSchema.fromJson(Object? j) : json = wfMap(j);
  UiWorkflowSchema({required UiWorkflowRegistry registry, List<UiWfSchemaStep> steps = const []}) : json = {'specVersion': uiWfSpecVersion, 'registry': registry.json, 'steps': steps};
  int get specVersion => wfInt(json['specVersion']) ?? uiWfSpecVersion;
  UiWorkflowRegistry get registry => UiWorkflowRegistry.fromJson(json['registry']);
  List<UiWfSchemaStep> get steps => wfList(json['steps'], UiWfSchemaStep.fromJson);
  UiJson toJson() => json;
}

// ── Global settings ─────────────────────────────────────────────────────────────────────────

/// A webhook connection: `{key, label, baseUrl, auth?, secretName?, header?}`.
extension type const UiWfConnection._(UiJson json) implements Object {
  UiWfConnection.fromJson(Object? j) : json = wfMap(j);
  String get key => wfStr(json['key']);
  String get label => wfStr(json['label']);
  String get baseUrl => wfStr(json['baseUrl']);

  /// `none` or `secret`.
  String get auth => wfStr(json['auth'], 'none');
  String? get secretName => wfStrOrNull(json['secretName']);
  String? get header => wfStrOrNull(json['header']);
}

/// The app's workflow settings (`GET /settings`).
extension type const UiWorkflowSettings._(UiJson json) implements Object {
  UiWorkflowSettings.fromJson(Object? j) : json = wfMap(j);
  UiWorkflowSettings() : json = {'version': 1};

  int get version => wfInt(json['version']) ?? 1;
  String? get timeZone => wfStrOrNull(json['timeZone']);

  /// `{days?, hours?, holidays?}`.
  UiJson? get calendar => wfMapOrNull(json['calendar']);

  /// Working days (`mon`…`sun`); Monday to Friday when not set.
  List<String> get workDays => wfStringsOrNull(calendar?['days']) ?? const ['mon', 'tue', 'wed', 'thu', 'fri'];

  /// `[from, to]` as `HH:mm`; 09:00–17:00 when not set.
  List<String> get hours {
    final h = wfStringsOrNull(calendar?['hours']);
    return h != null && h.length == 2 ? h : const ['09:00', '17:00'];
  }

  List<String> get holidays => wfStrings(calendar?['holidays']);

  /// `{retry?, taskDue?, reminders?, concurrency?, maxChainDepth?, forEachMax?}`.
  UiJson? get defaults => wfMapOrNull(json['defaults']);

  /// `{delegation?, escalationDefault?}`.
  UiJson? get people => wfMapOrNull(json['people']);

  /// Per channel key: `{enabled?, sender?, footer?}`.
  Map<String, UiJson>? get channels => json['channels'] is Map ? {for (final e in wfMap(json['channels']).entries) e.key: wfMap(e.value)} : null;
  List<String> get allowedOrigins => wfStrings(wfMapOrNull(json['webhooks'])?['allowedOrigins']);
  List<UiWfConnection> get connections => wfList(wfMapOrNull(json['webhooks'])?['connections'], UiWfConnection.fromJson);

  /// `{retentionDays?, maskedFields?}`.
  UiJson? get audit => wfMapOrNull(json['audit']);
  List<String> get maskedFields => wfStrings(audit?['maskedFields']);

  /// Record types whose triggers are paused.
  List<String> get paused => wfList(json['paused'], (x) => wfStr(wfMap(x)['entity']));
  UiWorkflowSettings patch(UiJson p) => UiWorkflowSettings._(wfPatch(json, p));
  UiJson toJson() => json;
}
