import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zouriel_ui/src/workflow/bits.dart' show WfSelect, wfArrow;
import 'package:zouriel_ui/src/workflow/inspector.dart';
import 'package:zouriel_ui/src/workflow/scope.dart';
import 'package:zouriel_ui/src/workflow/step_editors.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fake_api.dart';

// Port of @zouriel/ui 70754fc: remarks on negative actions, "Offer it" for the reset, the reset
// dialog fixes and the Create record fixes (definition.spec, runtime-shared.spec, inspector.spec and
// panel.spec of that commit).

Finder button(String label) => find.byWidgetPredicate((w) => w is UiButton && w.label == label);
Finder select(String label) => find.byWidgetPredicate((w) => w is WfSelect && w.label == label);

UiWfTask _task(Map<String, Object?> j) => UiWfTask.fromJson({'id': 't', 'outcomes': <Object?>[], ...j});

final _schema = UiWorkflowSchema.fromJson({
  'specVersion': 1,
  'steps': <Object?>[],
  'registry': {
    'specVersion': 1,
    'entities': [
      {'key': 'application', 'label': 'Application', 'fields': [
        {'key': 'title', 'label': 'Title', 'type': 'text', 'settable': true},
        {'key': 'status', 'label': 'Status', 'type': 'enum', 'lifecycle': true, 'settable': true},
      ]},
    ],
  },
});

/// draft → sub → rev → ok | no; rev → draft (send back); withdraw from any state.
UiWorkflowDefinition _life({Map<String, Object?>? reset}) {
  final d = createWorkflow('lifecycle', title: 'Life', entity: 'application');
  return UiWorkflowDefinition.fromJson({
    ...d.json,
    'lifecycle': {
      'field': 'status',
      'states': [
        {'id': 'draft', 'key': 'draft', 'label': 'Draft', 'category': 'initial'}, {'id': 'sub', 'key': 'sub', 'label': 'Submitted', 'category': 'active'},
        {'id': 'rev', 'key': 'rev', 'label': 'Review', 'category': 'active'}, {'id': 'ok', 'key': 'ok', 'label': 'Approved', 'category': 'terminal'},
        {'id': 'no', 'key': 'no', 'label': 'Rejected', 'category': 'terminal'}, {'id': 'wd', 'key': 'wd', 'label': 'Withdrawn', 'category': 'terminal'},
      ],
      'transitions': [
        {'id': 't1', 'key': 'submit', 'label': 'Submit', 'from': ['draft'], 'to': 'sub'},
        {'id': 't2', 'key': 'start', 'label': 'Start', 'from': ['sub'], 'to': 'rev'},
        {'id': 't3', 'key': 'ok', 'label': 'Approve', 'from': ['rev'], 'to': 'ok'},
        {'id': 't4', 'key': 'no', 'label': 'Reject', 'from': ['rev'], 'to': 'no', 'tone': 'danger'},
        {'id': 't5', 'key': 'back', 'label': 'Send back', 'from': ['rev'], 'to': 'draft'},
        {'id': 't6', 'key': 'wd', 'label': 'Withdraw', 'from': '*', 'to': 'wd'},
      ],
      'reset': ?reset,
    },
  });
}

/// The builder's editors with [def] loaded and [selection] chosen.
Future<UiWorkflowBuilderController> _pumpEditor(WidgetTester tester, UiWorkflowDefinition def, Widget editor, {List<UiWfDefinitionSummary> others = const []}) async {
  final c = UiWorkflowBuilderController(definition: def);
  c.schema = _schema;
  c.others = others;
  final wfUi = WfBuilderUi();
  addTearDown(() {
    c.dispose();
    wfUi.dispose();
  });
  tester.view.physicalSize = const Size(420, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(home: WfBuilderScope(controller: c, ui: wfUi, child: SingleChildScrollView(child: editor))));
  await tester.pumpAndSettle();
  return c;
}

Future<void> _pumpPanel(WidgetTester tester, FakeWorkflowApi api, {String entityId = '1'}) async {
  await pumpUi(tester, SizedBox(width: 420, height: 900, child: SingleChildScrollView(child: UiWorkflowPanel(api: api, entity: 'application', entityId: entityId, layout: UiWorkflowPanelLayout.compact))), size: const Size(420, 900));
  await tester.pumpAndSettle();
}

Map<String, Object?> _item(String id, String title, {bool selected = true}) =>
    {'id': id, 'kind': 'field', 'title': title, 'detail': null, 'workflow': 'W', 'step': 'S', 'undoable': true, 'selected': selected, 'warning': null};

void main() {
  group('remarks: helpers', () {
    final approval = _task({'kind': 'approval', 'requireComment': 'reject', 'outcomes': [{'key': 'approved', 'label': 'Approve'}, {'key': 'rejected', 'label': 'Reject'}]});
    final taskJson = {
      'kind': 'task', 'requireComment': 'reject',
      'outcomes': [{'key': 'done', 'label': 'Done', 'tone': 'success'}, {'key': 'decline', 'label': 'Decline', 'tone': 'danger'}, {'key': 'cancel', 'label': 'Cancel', 'tone': 'danger'}],
    };
    final task = _task(taskJson);

    test('are required for an approval\'s reject and a task\'s red outcomes when asked for on rejecting', () {
      expect(wfCommentRequired(approval, 'rejected'), isTrue);
      expect(wfCommentRequired(approval, 'approved'), isFalse);
      expect(wfCommentRequired(task, 'decline'), isTrue);
      expect(wfCommentRequired(task, 'done'), isFalse);
      expect(wfCommentRequired(_task({...taskJson, 'requireComment': 'always'}), 'done'), isTrue);
      expect(wfCommentRequired(_task({...taskJson, 'requireComment': 'never'}), 'decline'), isFalse);
      expect(wfCommentRequired(_task({...taskJson, 'requireComment': null}), 'decline'), isFalse);
    });

    test('the label says what they are required for', () {
      expect(wfRemarksLabel(approval), 'Remarks (required to reject)');
      expect(wfRemarksLabel(task), 'Remarks (required to choose Decline or Cancel)');
      expect(wfRemarksLabel(_task({...taskJson, 'outcomes': (taskJson['outcomes']! as List).take(2).toList()})), 'Remarks (required to decline)');
      expect(wfRemarksLabel(_task({...taskJson, 'requireComment': 'always'})), 'Remarks (required)');
      expect(wfRemarksLabel(_task({...taskJson, 'requireComment': 'never'})), 'Remarks (optional)');
    });

    test('show in the history of a move and of a reset', () {
      UiWfAuditEntry h(String action, Object data) => UiWfAuditEntry.fromJson({
            'category': 'lifecycle', 'action': action, 'before': '{"state":"Review"}', 'after': '{"state":"Draft"}', 'data': jsonEncode(data),
          });
      String s(Object? k) => '$k';
      expect(wfDescribeHistory(h('transitioned', {'label': 'Reject', 'comment': 'Missing transcript'}), s), 'Reject: Review $wfArrow Draft (“Missing transcript”)');
      expect(wfDescribeHistory(h('transitioned', {'label': 'Reject'}), s), 'Reject: Review $wfArrow Draft');
      expect(wfDescribeHistory(h('reset', {'label': 'Start over', 'input': {'reason': 'Form reason'}, 'comment': 'Wrong programme'}), s),
          'Start over: Review $wfArrow Draft (“Wrong programme”)');
      expect(wfDescribeHistory(h('reset', {'label': 'Start over', 'input': {'reason': 'Form reason'}}), s), 'Start over: Review $wfArrow Draft (“Form reason”)');
    });

    test('a move asks for remarks by its setting, else optionally when it is red', () {
      expect(wfRemarksFor(UiWfTransitionOption(key: 'a', label: 'A', tone: 'danger')), UiWfRemarks.optional);
      expect(wfRemarksFor(UiWfTransitionOption(key: 'a', label: 'A', tone: 'success')), UiWfRemarks.none);
      expect(wfRemarksFor(UiWfTransitionOption(key: 'a', label: 'A', tone: 'danger', comment: UiWfRemarks.none)), UiWfRemarks.none);
      expect(wfRemarksFor(UiWfTransitionOption(key: 'a', label: 'A', comment: UiWfRemarks.required)), UiWfRemarks.required);
      expect(UiWfRemarks.parse('optional'), UiWfRemarks.optional);
      expect(UiWfRemarks.parse('sometimes'), isNull);
    });

    test('the schema reads remarks and where the reset is offered', () {
      final d = _life(reset: {'who': <Object?>[], 'comment': 'required', 'states': ['rev', 'ok']});
      expect(d.lifecycle!.reset!.comment, UiWfRemarks.required);
      expect(d.lifecycle!.reset!.states, ['rev', 'ok']);
      expect(_life().lifecycle!.reset, isNull);
      final t = UiWfTransition.fromJson({'id': 'x', 'comment': 'none'});
      expect(t.comment, UiWfRemarks.none);
      expect(UiWfTransition.fromJson({'id': 'x'}).comment, isNull);
    });

    test('steps can read the remarks of the move or reset that started them', () {
      final paths = tokensAt(_life(), null).map((t) => t.path);
      expect(paths, contains('trigger.comment'));
      final entered = createWorkflow('automation', title: 'x', entity: 'application').patch({'trigger': {'type': 'stateEntered', 'lifecycle': 'l', 'states': ['a']}});
      final token = tokensAt(entered, null).where((t) => t.path == 'trigger.comment').single;
      expect((token.label, token.group, token.type), ('Remarks', 'What started it', 'text'));
    });

    test('a created record\'s id reads as text', () {
      final mk = UiWfStep.fromJson({...createStep('createRecord').json, 'id': 'mk', 'entity': 'application'});
      final d = insertStep(insertStep(createWorkflow('automation', title: 'x', entity: 'application'), 'root', 0, mk), 'root', 1, UiWfStep.fromJson({...createStep('notify').json, 'id': 'n'}));
      expect(tokensAt(d, null, at: const UiWfAt.step('n')).where((t) => t.path == 'steps.mk.id').single.type, 'text');
    });
  });

  group('remarks: the HTTP client', () {
    late List<http.Request> seen;
    UiWorkflowHttpApi api() {
      seen = [];
      return UiWorkflowHttpApi(baseUrl: 'https://app.example/wf', client: MockClient((r) async {
        seen.add(r);
        return http.Response('{"entity":"application","id":"1"}', 200);
      }));
    }

    test('sends remarks trimmed, and leaves them out when empty', () async {
      final a = api();
      await a.applyTransition('application', '1', 'reject', input: const {}, comment: '  Missing transcript ');
      await a.applyTransition('application', '1', 'reject', comment: '   ');
      await a.resetRecord('application', '1', undo: const ['x'], comment: ' Wrong programme');
      await a.resetRecord('application', '1');
      expect([for (final r in seen) jsonDecode(r.body)], [
        {'input': <String, Object?>{}, 'comment': 'Missing transcript'},
        {'input': null},
        {'input': <String, Object?>{}, 'undo': ['x'], 'comment': 'Wrong programme'},
        {'input': <String, Object?>{}},
      ]);
    });
  });

  test('wfStatesFrom: the state and everything after it, final states included, without looping back to the start', () {
    expect(wfStatesFrom(_life(), 'sub'), ['sub', 'rev', 'ok', 'no', 'wd']);
    expect(wfStatesFrom(_life(), 'rev'), ['rev', 'ok', 'no', 'wd']);
    expect(wfStatesFrom(_life(), 'ok'), ['ok']);
    // It stops at the reset's own target when that is somewhere else.
    final d = _life(reset: {'to': 'sub'});
    expect(wfStatesFrom(d, 'draft'), ['draft', 'wd']);
    expect(wfStatesFrom(d, 'unknown'), isEmpty);
  });

  group('the builder', () {
    testWidgets('the reset is offered everywhere by default, or from the first state after the start onwards, with the ticks adjustable', (tester) async {
      final def = UiWorkflowDefinition.fromJson({
        ...createWorkflow('lifecycle', title: 'Life', entity: 'application').json,
        'lifecycle': {
          'field': 'status',
          'states': [
            {'id': 'draft', 'key': 'draft', 'label': 'Draft', 'category': 'initial'}, {'id': 'rev', 'key': 'rev', 'label': 'Review', 'category': 'active'},
            {'id': 'done', 'key': 'done', 'label': 'Done', 'category': 'terminal'},
          ],
          'transitions': [
            {'id': 't1', 'key': 'submit', 'label': 'Submit', 'from': ['draft'], 'to': 'rev'}, {'id': 't2', 'key': 'finish', 'label': 'Finish', 'from': ['rev'], 'to': 'done'},
            {'id': 't3', 'key': 'back', 'label': 'Back', 'from': ['rev'], 'to': 'draft'},
          ],
          'reset': {'who': <Object?>[]},
        },
      });
      final c = await _pumpEditor(tester, def, const WfResetEditor());
      List<String>? states() => c.def.lifecycle!.reset!.states;
      expect(find.text('OFFER IT'), findsOneWidget);
      expect(states(), isNull);
      expect(select('From'), findsNothing);
      tester.widget<WfSelect>(select('Offer it')).onChanged!('some');
      await tester.pumpAndSettle();
      expect(states(), ['rev', 'done']);
      expect(tester.widget<WfSelect>(select('From')).value, 'rev');
      tester.widget<WfSelect>(select('From')).onChanged!('done');
      await tester.pumpAndSettle();
      expect(states(), ['done']);
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(states(), ['rev', 'done']);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(states(), ['rev']);
      expect(tester.widget<WfSelect>(select('From')).value, ''); // no state's "onwards" is just Review
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(states(), isEmpty);
      expect(find.text('Tick at least one state, or nobody can start a record over.'), findsOneWidget);
      tester.widget<WfSelect>(select('Offer it')).onChanged!('');
      await tester.pumpAndSettle();
      expect(states(), isNull);
    });

    testWidgets('the reset asks for remarks optionally by default; it can require them or not ask', (tester) async {
      final c = await _pumpEditor(tester, _life(reset: {'who': <Object?>[]}), const WfResetEditor());
      final remarks = tester.widget<WfSelect>(select('Remarks'));
      expect(remarks.value, '');
      expect([for (final o in remarks.options) o.label], ['Optional (default)', 'Required', 'Not asked']);
      remarks.onChanged!('required');
      await tester.pumpAndSettle();
      expect(c.def.lifecycle!.reset!.comment, UiWfRemarks.required);
      tester.widget<WfSelect>(select('Remarks')).onChanged!('');
      await tester.pumpAndSettle();
      expect(c.def.lifecycle!.reset!.json.containsKey('comment'), isFalse);
    });

    testWidgets('a move\'s remarks default to optional when it is red and to not asked otherwise', (tester) async {
      final c = await _pumpEditor(tester, _life(), const SizedBox.shrink());
      Future<WfSelect> remarksOf(String id) async {
        c.selection = UiWfSelection.transition(id);
        await tester.pumpWidget(UiApp(home: WfBuilderScope(controller: c, ui: WfBuilderUi(), child: const SingleChildScrollView(child: WfTransitionEditor()))));
        await tester.pumpAndSettle();
        return tester.widget<WfSelect>(select('Remarks'));
      }

      final red = await remarksOf('t4');
      expect(red.options.first.label, 'Default (optional, as it is red)');
      expect([for (final o in red.options.skip(1)) o.label], ['Not asked', 'Optional', 'Required']);
      expect((await remarksOf('t1')).options.first.label, 'Default (not asked)');
      (await remarksOf('t1')).onChanged!('required');
      await tester.pumpAndSettle();
      expect(c.def.lifecycle!.transitions.first.comment, UiWfRemarks.required);
      expect(find.textContaining('it shows in the history and steps can use it'), findsOneWidget);
    });

    testWidgets('approvals and tasks say what remarks are required for; a task says when no button is red', (tester) async {
      final ap = UiWfStep.fromJson({...createStep('approval').json, 'id': 'ap'});
      final tk = UiWfStep.fromJson({...createStep('task').json, 'id': 'tk', 'requireComment': 'reject'});
      final def = insertStep(insertStep(createWorkflow('automation', title: 'x', entity: 'application'), 'root', 0, ap), 'root', 1, tk);
      final c = await _pumpEditor(tester, def, WfStepEditor(step: ap));
      expect([for (final o in tester.widget<WfSelect>(select('Remarks')).options) o.label], ['Optional', 'Required to reject', 'Always required']);
      await tester.pumpWidget(UiApp(home: WfBuilderScope(controller: c, ui: WfBuilderUi(), child: SingleChildScrollView(child: WfStepEditor(step: c.def.steps![1])))));
      await tester.pumpAndSettle();
      expect([for (final o in tester.widget<WfSelect>(select('Remarks')).options) o.label], ['Optional', 'Required for red buttons', 'Always required']);
      expect(tester.widget<WfSelect>(select('Remarks')).value, 'reject');
      expect(find.textContaining('No button is red yet'), findsOneWidget);
    });

    testWidgets('Create record leaves out the lifecycle\'s field when a lifecycle controls that kind of record', (tester) async {
      final mk = UiWfStep.fromJson({...createStep('createRecord').json, 'id': 'mk', 'entity': 'application', 'values': [{'field': '', 'value': {'const': null}}]});
      final def = insertStep(createWorkflow('automation', title: 'x', entity: 'application'), 'root', 0, mk);
      Future<List<String>> fields(List<UiWfDefinitionSummary> others) async {
        await _pumpEditor(tester, def, WfStepEditor(step: mk), others: others);
        return [for (final o in tester.widget<WfSelect>(select('Field 1')).options) o.value];
      }

      expect(await fields(const []), ['title', 'status']);
      final life = UiWfDefinitionSummary.fromJson({'id': 'L', 'key': 'life', 'kind': 'lifecycle', 'entity': 'application', 'title': 'Life', 'version': 1});
      expect(await fields([life]), ['title']);
      // An unpublished lifecycle doesn't control anything yet.
      expect(await fields([UiWfDefinitionSummary.fromJson({...life.json, 'version': 0})]), ['title', 'status']);
    });

    testWidgets('Create record says so when the app no longer offers the chosen kind', (tester) async {
      final mk = UiWfStep.fromJson({...createStep('createRecord').json, 'id': 'mk', 'entity': 'visa'});
      await _pumpEditor(tester, insertStep(createWorkflow('automation', title: 'x', entity: 'application'), 'root', 0, mk), WfStepEditor(step: mk));
      expect(find.text('The app no longer offers this kind of record; choose another.'), findsOneWidget);
      expect(find.text('Set a field'), findsNothing);
    });
  });

  group('the record actions', () {
    testWidgets('a red move asks for optional remarks and sends them trimmed', (tester) async {
      final api = FakeWorkflowApi();
      api.recordJson['transitions'] = [
        {'key': 'reject', 'label': 'Reject', 'to': 'draft', 'toLabel': 'Draft', 'tone': 'danger', 'confirm': null, 'form': null},
      ];
      await _pumpPanel(tester, api);
      await tester.tap(button('Reject'));
      await tester.pumpAndSettle();
      expect(find.text('Remarks (optional)'), findsOneWidget);
      await tester.enterText(find.descendant(of: find.byType(UiTextarea), matching: find.byType(EditableText)), '  Missing transcript ');
      await tester.tap(button('Reject').last);
      await tester.pumpAndSettle();
      expect(api.calls, contains('apply:reject'));
      expect(api.lastApplyComment, 'Missing transcript');
    });

    testWidgets('a required remark refuses to go without', (tester) async {
      final api = FakeWorkflowApi();
      api.recordJson['transitions'] = [
        {'key': 'reject', 'label': 'Reject', 'to': 'draft', 'toLabel': 'Draft', 'tone': 'danger', 'confirm': null, 'form': null, 'comment': 'required'},
      ];
      await _pumpPanel(tester, api);
      await tester.tap(button('Reject'));
      await tester.pumpAndSettle();
      expect(find.text('Remarks (required)'), findsOneWidget);
      await tester.tap(button('Reject').last);
      await tester.pumpAndSettle();
      expect(api.calls.where((c) => c.startsWith('apply:')), isEmpty);
      expect(find.text('Add remarks to explain this.'), findsOneWidget);
      expect(tester.widget<UiTextarea>(find.byType(UiTextarea)).invalid, isTrue);
    });

    testWidgets('a move that is not red, has no form, confirmation or remarks setting goes straight through', (tester) async {
      final api = FakeWorkflowApi();
      await _pumpPanel(tester, api);
      await tester.tap(button('Withdraw'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('apply:withdraw'));
      expect(api.lastApplyComment, isNull);
      expect(find.byType(UiTextarea), findsNothing);
    });

    testWidgets('the reset can\'t be confirmed while its list is loading, and sends remarks with it', (tester) async {
      final api = FakeWorkflowApi();
      api.recordJson['reset'] = {'label': 'Start over', 'to': 'draft', 'toLabel': 'Draft', 'confirm': null, 'form': null};
      api.resetItems = [_item('created:document:d9', 'Delete Document “Checklist”')];
      api.previewGate = Completer<void>();
      await _pumpPanel(tester, api);
      await tester.tap(button('Start over'));
      await tester.pumpAndSettle();
      expect(find.text('Looking up what the workflow did…'), findsOneWidget);
      expect(tester.widget<UiButton>(button('Start over').last).onPressed, isNull);
      api.previewGate!.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<UiButton>(button('Start over').last).onPressed, isNotNull);
      expect(find.text('Remarks (optional)'), findsOneWidget);
      await tester.enterText(find.descendant(of: find.byType(UiTextarea), matching: find.byType(EditableText)), 'Wrong programme');
      await tester.tap(button('Start over').last);
      await tester.pumpAndSettle();
      expect(api.lastResetUndo, ['created:document:d9']);
      expect(api.lastResetComment, 'Wrong programme');
    });

    testWidgets('after a stale list the reset reads it again and keeps what the person unticked', (tester) async {
      final api = FakeWorkflowApi();
      api.recordJson['reset'] = {'label': 'Start over', 'to': 'draft', 'toLabel': 'Draft', 'confirm': null, 'form': null};
      api.resetItems = [_item('a', 'Keep me'), _item('b', 'Take back')];
      api.resetFailures.add(const UiWfApiError(409, 'resetChanged', 'What the workflow did has changed.'));
      await _pumpPanel(tester, api);
      await tester.tap(button('Start over'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep me'));
      await tester.pumpAndSettle();
      api.resetItems = [_item('a', 'Keep me'), _item('b', 'Take back'), _item('c', 'New one')];
      await tester.tap(button('Start over').last);
      await tester.pumpAndSettle();
      expect(find.text('What the workflow did has changed.'), findsOneWidget);
      bool? ticked(String title) => tester.widget<UiCheckbox>(find.ancestor(of: find.text(title), matching: find.byType(UiCheckbox))).value;
      expect([ticked('Keep me'), ticked('Take back'), ticked('New one')], [false, true, true]);
      await tester.tap(button('Start over').last);
      await tester.pumpAndSettle();
      expect(api.lastResetUndo, ['b', 'c']);
    });

    testWidgets('an empty list says nothing needs taking back', (tester) async {
      final api = FakeWorkflowApi();
      api.recordJson['reset'] = {'label': 'Start over', 'to': 'draft', 'toLabel': 'Draft', 'confirm': null, 'form': null};
      api.resetItems = [];
      await _pumpPanel(tester, api);
      await tester.tap(button('Start over'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing the workflow did needs taking back.'), findsOneWidget);
    });

    testWidgets('a warning is read with its checkbox', (tester) async {
      final h = tester.ensureSemantics();
      final api = FakeWorkflowApi();
      api.recordJson['reset'] = {'label': 'Start over', 'to': 'draft', 'toLabel': 'Draft', 'confirm': null, 'form': null};
      api.resetItems = [
        {..._item('m', 'Message to Ali'), 'kind': 'message', 'undoable': false, 'selected': false, 'warning': "Already sent; it can't be taken back."},
      ];
      await _pumpPanel(tester, api);
      await tester.tap(button('Start over'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel("Message to Ali. Already sent; it can't be taken back."), findsOneWidget);
      h.dispose();
    });

    testWidgets('a list that arrives after the dialog closed is dropped quietly', (tester) async {
      final api = FakeWorkflowApi();
      api.recordJson['reset'] = {'label': 'Start over', 'to': 'draft', 'toLabel': 'Draft', 'confirm': null, 'form': null};
      api.resetItems = [_item('a', 'Keep me')];
      api.previewGate = Completer<void>();
      await _pumpPanel(tester, api);
      await tester.tap(button('Start over'));
      await tester.pumpAndSettle();
      await tester.tap(button('Cancel'));
      await tester.pumpAndSettle();
      api.previewGate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Opened again, it reads the list afresh.
      await tester.tap(button('Start over'));
      await tester.pumpAndSettle();
      expect(find.text('Keep me'), findsOneWidget);
      expect(api.calls.where((c) => c == 'resetPreview'), hasLength(2));
    });

    testWidgets('an error that arrives after the dialog closed still shows', (tester) async {
      final api = FakeWorkflowApi();
      api.recordJson['reset'] = {'label': 'Start over', 'to': 'draft', 'toLabel': 'Draft', 'confirm': null, 'form': null};
      api.resetItems = [];
      api.resetGate = Completer<void>();
      api.resetFailures.add(const UiWfApiError(403, 'forbidden', 'You may not start this over.'));
      await _pumpPanel(tester, api);
      await tester.tap(button('Start over'));
      await tester.pumpAndSettle();
      await tester.tap(button('Start over').last);
      await tester.pump();
      // Closed (e.g. Escape) while the reset is on its way.
      Navigator.of(tester.element(find.text('Nothing the workflow did needs taking back.'))).pop();
      await tester.pumpAndSettle();
      api.resetGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('You may not start this over.'), findsOneWidget);
    });

    testWidgets('switching to another record closes the dialog', (tester) async {
      final api = FakeWorkflowApi();
      api.recordJson['reset'] = {'label': 'Start over', 'to': 'draft', 'toLabel': 'Draft', 'confirm': null, 'form': null};
      api.resetItems = [];
      final host = GlobalKey<_HostState>();
      tester.view.physicalSize = const Size(420, 900) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(home: _Host(key: host, api: api)));
      await tester.pumpAndSettle();
      await tester.tap(button('Start over'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing the workflow did needs taking back.'), findsOneWidget);
      host.currentState!.show('2');
      await tester.pumpAndSettle();
      expect(find.text('Nothing the workflow did needs taking back.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the reset dialog is large', (tester) async {
      final api = FakeWorkflowApi();
      api.recordJson['reset'] = {'label': 'Start over', 'to': 'draft', 'toLabel': 'Draft', 'confirm': null, 'form': null};
      await _pumpPanel(tester, api);
      await tester.tap(button('Start over'));
      await tester.pumpAndSettle();
      expect(tester.widget<UiModal>(find.byType(UiModal)).size, UiModalSize.lg);
    });
  });
}

/// A page that can switch which record its actions are for.
class _Host extends StatefulWidget {
  const _Host({super.key, required this.api});
  final FakeWorkflowApi api;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String _id = '1';
  void show(String id) => setState(() => _id = id);

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: WfRecordActions(api: widget.api, record: UiWfRecord.fromJson(widget.api.recordJson), entity: 'application', entityId: _id),
      );
}
