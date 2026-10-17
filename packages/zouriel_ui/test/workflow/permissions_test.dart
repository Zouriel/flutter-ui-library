import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zouriel_ui/src/workflow/bits.dart' show wfArrow;
import 'package:zouriel_ui/src/workflow/editors.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

// Port of the web `permissions.spec.ts`.

final _approval = {...createStep('approval').json, 'id': 'ap', 'title': 'Finance sign-off', 'assignees': [{'role': 'finance'}]};
final _task = {...createStep('task').json, 'id': 'tk', 'assignees': <Object?>[]};

final UiWorkflowDefinition _lifecycle = UiWorkflowDefinition.fromJson({
  'specVersion': 1, 'id': 'wf_l', 'key': 'review', 'kind': 'lifecycle', 'title': 'Scholarship review', 'entity': 'application',
  'lifecycle': {
    'field': 'status', 'mode': 'enforce',
    'states': [
      {'id': 'd', 'key': 'Draft', 'label': 'Draft', 'category': 'initial'},
      {'id': 's', 'key': 'Submitted', 'label': 'Submitted', 'category': 'active'},
      {'id': 'a', 'key': 'Approved', 'label': 'Approved', 'category': 'terminal'},
    ],
    'transitions': [
      {'id': 't1', 'key': 'submit', 'label': 'Submit', 'from': ['d'], 'to': 's', 'who': [{'initiator': true}]},
      {'id': 't2', 'key': 'approve', 'label': 'Approve', 'from': ['s'], 'to': 'a', 'who': [{'role': 'head'}], 'steps': [_approval]},
      {'id': 't3', 'key': 'expire', 'label': 'Expire', 'from': ['s'], 'to': 'd', 'auto': {'after': 'P30D'}},
      {'id': 't4', 'key': 'withdraw', 'label': 'Withdraw', 'from': '*', 'to': 'd'},
      {'id': 't5', 'key': 'archive', 'label': 'Archive', 'from': ['a'], 'to': 'd', 'hidden': true, 'who': [{'role': 'head'}]},
    ],
    'reset': {'label': 'Start over', 'who': [{'role': 'head'}]},
  },
});

final UiWorkflowDefinition _automation = UiWorkflowDefinition.fromJson({
  'specVersion': 1, 'id': 'wf_a', 'key': 'pay', 'kind': 'automation', 'title': 'Pay', 'entity': 'application',
  'trigger': {'type': 'manual', 'label': 'Pay now', 'who': [{'role': 'finance'}]},
  'steps': [_task],
});

UiWfDefinitionSummary _summary(UiWorkflowDefinition def, {int version = 1, String status = 'published'}) => UiWfDefinitionSummary.fromJson({
  'id': def.id, 'key': def.key, 'kind': def.kind, 'title': def.title, 'entity': def.entity, 'status': status, 'version': version, 'hasDraftChanges': false, 'updatedAt': '', 'runningInstances': 0,
});

class _Api extends Fake implements UiWorkflowApi {
  _Api({required this.canPublish, UiWorkflowDefinition? lifecycle, UiWorkflowDefinition? automation, this.users = const {}, this.failDefinitionAfter})
    : lc = lifecycle ?? _lifecycle,
      auto = automation ?? _automation;
  final bool canPublish;
  final UiWorkflowDefinition lc;
  final UiWorkflowDefinition auto;

  /// People the directory knows, by id.
  final Map<String, String> users;

  /// `definition(id)` fails once this many calls were made (a failed reload).
  final int? failDefinitionAfter;

  /// The published version the server reports for every workflow (another admin can bump it).
  int publishedVersion = 1;
  int definitionCalls = 0;
  final userCalls = <String>[];
  final saves = <({String id, List<({String node, List<UiWfAssignee> who})> changes, String? note})>[];

  /// When set, saves wait for it.
  Completer<void>? gate;
  Object? failSave;

  @override
  Future<List<UiWfDefinitionSummary>> definitions() async => [
        _summary(lc, version: publishedVersion),
        _summary(auto, version: publishedVersion),
        _summary(createWorkflow('automation', title: 'Never published')..json['id'] = 'wf_d', version: 0, status: 'draft'),
        _summary(UiWorkflowDefinition.fromJson({...auto.json, 'id': 'wf_x', 'title': 'Archived'}), status: 'archived'),
      ];

  @override
  Future<UiWfDefinitionDetail> definition(String id) async {
    definitionCalls++;
    if (failDefinitionAfter != null && definitionCalls > failDefinitionAfter!) throw Exception('offline');
    final def = id == lc.id ? lc : auto;
    return UiWfDefinitionDetail.fromJson({'summary': _summary(def, version: publishedVersion).json, 'draft': def.json, 'published': def.json, 'versions': <Object?>[], 'problems': <Object?>[]});
  }

  @override
  Future<UiWorkflowSchema> schema() async => UiWorkflowSchema(
        registry: UiWorkflowRegistry.fromJson({
          'entities': <Object?>[],
          'roles': [
            {'key': 'head', 'label': 'Head of office'},
            {'key': 'finance', 'label': 'Finance'},
          ],
        }),
      );

  @override
  Future<UiWfMe> me() async => UiWfMe.fromJson({'type': 'user', 'id': 'u', 'name': 'U', 'roles': <Object?>[], 'can': {'edit': canPublish, 'publish': canPublish}});

  @override
  Future<UiWfUser?> user(String id) async {
    userCalls.add(id);
    final name = users[id];
    return name == null ? null : UiWfUser.fromJson({'id': id, 'name': name});
  }

  @override
  Future<UiWfDefinitionSummary> updatePermissions(String id, List<({String node, List<UiWfAssignee> who})> changes, {String? note}) async {
    saves.add((id: id, changes: changes, note: note));
    await gate?.future;
    final e = failSave;
    if (e != null) throw e;
    publishedVersion++;
    return _summary(lc, version: publishedVersion);
  }
}

Future<_Api> _pump(WidgetTester tester, {bool canPublish = true, double width = 900, ValueChanged<UiWfDefinitionSummary>? onSaved, _Api? api}) async {
  final a = api ?? _Api(canPublish: canPublish);
  tester.view.physicalSize = Size(width, 1400) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(home: SingleChildScrollView(padding: const EdgeInsets.all(16), child: UiWorkflowPermissions(api: a, onSaved: onSaved))));
  await tester.pumpAndSettle();
  return a;
}

/// The read-only texts of the rows.
Iterable<String> _readTexts(WidgetTester tester) => [
      for (final w in tester.widgetList<Text>(find.byType(Text))) if (w.data != null) w.data!,
    ];

Finder _editor(String label) => find.byWidgetPredicate((w) => w is WfAssigneesEditor && w.label == label);
Finder _section(String id) => find.byKey(ValueKey('perm-$id'));

void main() {
  test('rows: moves, the reset, the start button and people steps, skipping hidden moves but not automatic ones', () {
    final rows = permissionRows(_lifecycle);
    expect([for (final r in rows) [r.node, r.kind, r.label, r.detail]], [
      ['t1', 'transition', 'Submit', 'Draft $wfArrow Submitted'],
      ['t2', 'transition', 'Approve', 'Submitted $wfArrow Approved'],
      // The engine offers an automatic move to the people in its `who`; a hidden one never.
      ['t3', 'transition', 'Expire', 'Submitted $wfArrow Draft'],
      ['t4', 'transition', 'Withdraw', 'Any state $wfArrow Draft'],
      ['reset', 'reset', 'Start over', 'Back to Draft'],
      ['ap', 'step', 'Finance sign-off', 'Approval'],
    ]);
    expect([for (final r in permissionRows(_automation)) [r.node, r.label, [for (final a in r.who) a.json]]], [
      ['trigger', '“Pay now” button', [{'role': 'finance'}]],
      ['tk', 'Task', <Object?>[]],
    ]);
  });

  test('the HTTP client posts the changes and the note', () async {
    final seen = <http.Request>[];
    final api = UiWorkflowHttpApi(
      baseUrl: 'https://app.example/api/workflows',
      client: MockClient((r) async {
        seen.add(r);
        return http.Response('{"id":"wf/1","version":3}', 200);
      }),
    );
    final s = await api.updatePermissions('wf/1', [(node: 't1', who: [UiWfAssignee.role('head')]), (node: 'reset', who: const [])], note: 'Heads only');
    expect(s.version, 3);
    expect(seen.single.method, 'POST');
    expect(seen.single.url.toString(), 'https://app.example/api/workflows/definitions/wf%2F1/permissions');
    expect(jsonDecode(seen.single.body), {
      'changes': [
        {'node': 't1', 'who': [{'role': 'head'}]},
        {'node': 'reset', 'who': <Object?>[]},
      ],
      'note': 'Heads only',
    });
  });

  testWidgets('shows each published, non-archived workflow by title, with an editor per row', (tester) async {
    await _pump(tester);
    expect(find.text('Pay'), findsOneWidget);
    expect(find.text('Scholarship review'), findsOneWidget);
    expect(find.text('Never published'), findsNothing);
    expect(find.text('Archived'), findsNothing);
    expect(tester.getTopLeft(find.text('Pay')).dy, lessThan(tester.getTopLeft(find.text('Scholarship review')).dy));
    expect(find.byType(WfAssigneesEditor), findsNWidgets(8));
    expect(find.text('Automation · v1'), findsOneWidget);
    expect(find.text('Lifecycle · v1'), findsOneWidget);
  });

  testWidgets('saves only the changed rows, once, with the note, and says which version is in use', (tester) async {
    final saved = <UiWfDefinitionSummary>[];
    final api = await _pump(tester, onSaved: saved.add);
    api.gate = Completer<void>();
    tester.widget<WfAssigneesEditor>(_editor('Submit')).onChanged([UiWfAssignee.role('head')]);
    await tester.pump();
    expect(tester.widget<Semantics>(find.ancestor(of: _editor('Submit'), matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.value == 'Changed'))).properties.value, 'Changed');
    final note = find.descendant(of: find.byWidgetPredicate((w) => w is UiInput && w.semanticLabel == 'Why these changes'), matching: find.byType(EditableText));
    await tester.enterText(note, 'Only the head submits for now');
    await tester.pump();
    final save = find.widgetWithText(UiButton, 'Save 1 change');
    expect(save, findsOneWidget);
    final press = tester.widget<UiButton>(save).onPressed!;
    press();
    press(); // a double tap saves once
    await tester.pump();
    api.gate!.complete();
    await tester.pumpAndSettle();
    expect(api.saves, hasLength(1));
    expect(api.saves.single.id, 'wf_l');
    expect([for (final c in api.saves.single.changes) [c.node, [for (final a in c.who) a.json]]], [
      ['t1', [{'role': 'head'}],],
    ]);
    expect(api.saves.single.note, 'Only the head submits for now');
    expect(find.text('Saved: version 2 is now in use.'), findsOneWidget);
    expect(find.text('Lifecycle · v2'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.value == 'Changed'), findsNothing);
    expect(saved.single.version, 2);
  });

  testWidgets('one save at a time across workflows; a refusal shows and keeps the changes', (tester) async {
    final api = await _pump(tester);
    api.gate = Completer<void>();
    api.failSave = const UiWfApiError(403, 'forbidden', 'You may not publish this workflow.');
    tester.widget<WfAssigneesEditor>(_editor('Submit')).onChanged([UiWfAssignee.role('head')]);
    tester.widget<WfAssigneesEditor>(_editor('Task')).onChanged([UiWfAssignee.role('finance')]);
    await tester.pump();
    final saves = find.widgetWithText(UiButton, 'Save 1 change');
    expect(saves, findsNWidgets(2));
    tester.widget<UiButton>(find.descendant(of: _section('wf_l'), matching: saves)).onPressed!();
    await tester.pump();
    expect(tester.widget<UiButton>(find.descendant(of: _section('wf_a'), matching: saves)).onPressed, isNull);
    api.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('You may not publish this workflow.'), findsOneWidget);
    expect(find.widgetWithText(UiButton, 'Save 1 change'), findsNWidgets(2));
  });

  testWidgets('setting a row back to what is published is not a change; Undo drops changes', (tester) async {
    await _pump(tester);
    final editor = tester.widget<WfAssigneesEditor>(_editor('Submit'));
    final published = editor.value;
    editor.onChanged(const []);
    await tester.pump();
    expect(find.textContaining('Save'), findsOneWidget);
    tester.widget<WfAssigneesEditor>(_editor('Submit')).onChanged([for (final a in published) UiWfAssignee.fromJson({...a.json})]);
    await tester.pump();
    expect(find.textContaining('Save'), findsNothing);
    tester.widget<WfAssigneesEditor>(_editor('Approve')).onChanged(const []);
    await tester.pump();
    await tester.tap(find.widgetWithText(UiButton, 'Undo'));
    await tester.pump();
    expect(find.textContaining('Save'), findsNothing);
    expect(tester.widget<WfAssigneesEditor>(_editor('Approve')).value.single.json, {'role': 'head'});
  });

  testWidgets('people who may not publish see who may do what, without editors', (tester) async {
    await _pump(tester, canPublish: false);
    expect(find.byType(WfAssigneesEditor), findsNothing);
    expect(find.textContaining('changing it needs the right to publish'), findsOneWidget);
    expect(find.text('Head of office'), findsWidgets);
    expect(find.text('Nobody yet.'), findsOneWidget); // the task with no one
    expect(find.text('Nobody by hand: only automatically, or from other workflows.'), findsNWidgets(2)); // Expire, Withdraw
    expect(find.textContaining('Save'), findsNothing);
  });

  testWidgets('search narrows to matching workflows and rows', (tester) async {
    await _pump(tester);
    Future<void> search(String q) async {
      await tester.enterText(find.descendant(of: find.byWidgetPredicate((w) => w is UiSearchInput && w.label == 'Find a workflow or step'), matching: find.byType(EditableText)), q);
      await tester.pumpAndSettle();
    }

    await search('start over');
    expect(find.byType(WfAssigneesEditor), findsOneWidget);
    expect(find.text('Start over'), findsOneWidget);
    expect(find.text('Pay'), findsNothing);
    await search('pay'); // a workflow's title keeps all its rows
    expect(find.byType(WfAssigneesEditor), findsNWidgets(2));
    await search('any state'); // details match too
    expect(find.text('Withdraw'), findsOneWidget);
    await search('zzz');
    expect(find.text('Nothing matches.'), findsOneWidget);
  });

  testWidgets('rows stack below 560 wide', (tester) async {
    await _pump(tester, width: 420);
    final label = tester.getRect(find.text('Submit'));
    final editor = tester.getRect(_editor('Submit'));
    expect(editor.top, greaterThan(label.bottom));
    await _pump(tester, width: 900);
    expect(tester.getRect(_editor('Submit')).left, greaterThan(tester.getRect(find.text('Submit')).right));
  });

  testWidgets('golden: the permissions list', (tester) async {
    final api = _Api(canPublish: true);
    await expectThemedGolden(tester, 'workflow_permissions', (_) => SingleChildScrollView(child: UiWorkflowPermissions(api: api)), width: 640, height: 1080);
  });

  testWidgets('every tap target has a label and, on a phone, a full-size target', (tester) async {
    final h = tester.ensureSemantics();
    await _pump(tester);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    h.dispose();
  });

  test('"who" lists compare as sets, ignoring order and key order', () {
    UiWfAssignee a(Map<String, Object?> j) => UiWfAssignee.fromJson(j);
    expect(sameWho([a({'role': 'a'}), a({'user': 'u'})], [a({'user': 'u'}), a({'role': 'a'})]), isTrue);
    expect(sameWho([a({'managerOf': 'initiator'})], [a({'managerOf': 'initiator'})]), isTrue);
    expect(sameWho([a({'role': 'a'})], [a({'role': 'b'})]), isFalse);
    expect(sameWho([a({'role': 'a'}), a({'role': 'a'})], [a({'role': 'a'}), a({'role': 'b'})]), isFalse);
  });

  testWidgets('search keeps rows with unsaved edits, so every counted change stays visible', (tester) async {
    await _pump(tester);
    tester.widget<WfAssigneesEditor>(_editor('Submit')).onChanged([UiWfAssignee.role('head')]);
    await tester.pump();
    await tester.enterText(find.descendant(of: find.byType(UiSearchInput), matching: find.byType(EditableText)), 'start over');
    await tester.pumpAndSettle();
    expect([for (final e in tester.widgetList<WfAssigneesEditor>(find.byType(WfAssigneesEditor))) e.label], ['Submit', 'Start over']);
    expect(find.widgetWithText(UiButton, 'Save 1 change'), findsOneWidget);
  });

  testWidgets('reordering chips is not a change', (tester) async {
    final lc = UiWorkflowDefinition.fromJson({
      ..._lifecycle.json,
      'lifecycle': {
        ..._lifecycle.lifecycle!.json,
        'transitions': [
          {..._lifecycle.lifecycle!.transitions.first.json, 'who': [{'role': 'head'}, {'initiator': true}]},
        ],
      },
    });
    await _pump(tester, api: _Api(canPublish: true, lifecycle: lc));
    tester.widget<WfAssigneesEditor>(_editor('Submit')).onChanged([UiWfAssignee.fromJson({'initiator': true}), UiWfAssignee.role('head')]);
    await tester.pump();
    expect(find.textContaining('Save'), findsNothing);
  });

  testWidgets('Undo drops the edits and the note', (tester) async {
    await _pump(tester);
    Finder note() => find.descendant(of: find.byWidgetPredicate((w) => w is UiInput && w.semanticLabel == 'Why these changes'), matching: find.byType(EditableText));
    tester.widget<WfAssigneesEditor>(_editor('Submit')).onChanged([UiWfAssignee.role('head')]);
    await tester.pump();
    await tester.enterText(note(), 'old reason');
    await tester.pump();
    await tester.tap(find.widgetWithText(UiButton, 'Undo'));
    await tester.pump();
    tester.widget<WfAssigneesEditor>(_editor('Submit')).onChanged([UiWfAssignee.role('head')]);
    await tester.pump();
    expect(tester.widget<EditableText>(note()).controller.text, '');
  });

  testWidgets('once saved, a failed reload keeps it saved: no error, no second publish, a note to reload', (tester) async {
    // Loading makes 2 definition calls, the check before saving a 3rd; the reload after saving fails.
    final api = await _pump(tester, api: _Api(canPublish: true, failDefinitionAfter: 3));
    tester.widget<WfAssigneesEditor>(_editor('Submit')).onChanged([UiWfAssignee.role('head')]);
    await tester.pump();
    await tester.tap(find.widgetWithText(UiButton, 'Save 1 change'));
    await tester.pumpAndSettle();
    expect(api.saves, hasLength(1));
    expect(find.textContaining('Saving failed'), findsNothing);
    expect(find.textContaining('Save 1 change'), findsNothing);
    expect(find.textContaining('Saved: version 2 is now in use.'), findsOneWidget);
    expect(find.textContaining('reload to see the latest'), findsOneWidget);
    // The row shows what was saved, as published.
    expect([for (final a in tester.widget<WfAssigneesEditor>(_editor('Submit')).value) a.json], [{'role': 'head'}]);
    expect(find.text('Lifecycle · v2'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.value == 'Changed'), findsNothing);
  });

  testWidgets('does not overwrite a version someone else published since the page loaded', (tester) async {
    final api = await _pump(tester);
    tester.widget<WfAssigneesEditor>(_editor('Submit')).onChanged([UiWfAssignee.role('head')]);
    await tester.pump();
    api.publishedVersion = 5; // another admin published
    await tester.tap(find.widgetWithText(UiButton, 'Save 1 change'));
    await tester.pumpAndSettle();
    expect(api.saves, isEmpty);
    expect(find.textContaining('Someone changed these permissions since you opened the page'), findsOneWidget);
    expect(tester.widget<UiButton>(find.widgetWithText(UiButton, 'Save 1 change')).onPressed, isNull);
    await tester.tap(find.widgetWithText(UiButton, 'Reload'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Someone changed these permissions'), findsNothing);
    expect(find.text('Lifecycle · v5'), findsOneWidget);
    expect(find.textContaining('Save 1 change'), findsNothing);
  });

  testWidgets('will not save an approval or task with nobody to decide it, and says why', (tester) async {
    final api = await _pump(tester);
    tester.widget<WfAssigneesEditor>(_editor('Finance sign-off')).onChanged(const []);
    await tester.pump();
    expect(find.textContaining('Add someone to “Finance sign-off”'), findsOneWidget);
    expect(tester.widget<UiButton>(find.widgetWithText(UiButton, 'Save 1 change')).onPressed, isNull);
    expect(api.saves, isEmpty);
  });

  testWidgets('says what an empty "who" means for each kind of row', (tester) async {
    final empty = UiWorkflowDefinition.fromJson({
      ..._lifecycle.json,
      'lifecycle': {
        ..._lifecycle.lifecycle!.json,
        'transitions': [
          {..._lifecycle.lifecycle!.transitions.first.json, 'who': <Object?>[]},
        ],
        'reset': {'label': 'Start over', 'who': <Object?>[]},
      },
    });
    final auto = UiWorkflowDefinition.fromJson({..._automation.json, 'trigger': {'type': 'manual', 'label': 'Pay now', 'who': <Object?>[]}});
    await _pump(tester, api: _Api(canPublish: false, lifecycle: empty, automation: auto));
    final read = _readTexts(tester).toList();
    expect(read, contains('Nobody by hand: only automatically, or from other workflows.'));
    expect(read, contains('Nobody.'));
    expect(read, contains('Nobody yet.')); // the task with no assignees
    expect(read, contains('Anyone who can see the record.'));
    expect(emptyWhoText('trigger'), 'Anyone who can see the record.');
    await _pump(tester, api: _Api(canPublish: true, lifecycle: empty, automation: auto));
    final hints = {for (final e in tester.widgetList<WfAssigneesEditor>(find.byType(WfAssigneesEditor))) e.label: e.emptyText};
    expect(hints['Submit'], 'Nobody by hand: only automatically, or from other workflows.');
    expect(hints['Start over'], 'Nobody.');
    expect(hints['Task'], startsWith('Nobody yet: add the people who decide.'));
  });

  testWidgets('read-only rows name people, not user ids', (tester) async {
    final withUser = UiWorkflowDefinition.fromJson({
      ..._lifecycle.json,
      'lifecycle': {..._lifecycle.lifecycle!.json, 'reset': {'label': 'Start over', 'who': [{'user': 'u7'}, {'role': 'head'}]}},
    });
    final api = await _pump(tester, api: _Api(canPublish: false, lifecycle: withUser, users: {'u7': 'Ana Lee'}));
    expect(find.text('Ana Lee and Head of office'), findsOneWidget);
    expect(api.userCalls, ['u7']);
  });

  testWidgets('without an API it says so instead of claiming nothing is published', (tester) async {
    await pumpUi(tester, const SingleChildScrollView(child: UiWorkflowPermissions(api: null)), size: const Size(900, 600));
    expect(find.textContaining('No workflow API is connected'), findsOneWidget);
    expect(find.textContaining('No published workflow'), findsNothing);
  });

  testWidgets('uses the library search field', (tester) async {
    await _pump(tester);
    expect(tester.widget<UiSearchInput>(find.byType(UiSearchInput)).label, 'Find a workflow or step');
  });
}
