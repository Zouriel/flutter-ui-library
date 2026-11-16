import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/bits.dart' show WfChecks, WfSectionTitle, WfSelect, WfSwitch;
import 'package:zouriel_ui/src/workflow/editors.dart';
import 'package:zouriel_ui/src/workflow/history.dart';
import 'package:zouriel_ui/src/workflow/inspector.dart';
import 'package:zouriel_ui/src/workflow/scope.dart' show WfBuilderScope;
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fake_api.dart';

/// Departments, portals and queues; separation of duties; paused time limits; public processing time.

UiWorkflowRegistry _registry({bool lists = true}) => UiWorkflowRegistry.fromJson({
      'specVersion': 1,
      'entities': [
        {'key': 'application', 'label': 'Application', 'fields': [{'key': 'status', 'label': 'Status', 'type': 'enum', 'lifecycle': true, 'options': [{'value': 'a', 'label': 'A'}]}]},
      ],
      'roles': [{'key': 'finance', 'label': 'Finance'}, {'key': 'head', 'label': 'Head of office'}],
      if (lists) ...{
        'signals': [{'key': 'docs.requested', 'label': 'Documents requested'}, {'key': 'docs.received', 'label': 'Documents received'}],
        'departments': [{'key': 'licensing', 'label': 'Licensing department'}],
        'portals': [{'key': 'citizen', 'label': 'Citizen portal'}],
        'queues': [{'key': 'frontdesk', 'label': 'Front desk queue'}],
      },
    });

UiWorkflowDefinition _lifecycle() => UiWorkflowDefinition.fromJson({
      'specVersion': 1, 'id': 'wf_life', 'key': 'life', 'kind': 'lifecycle', 'title': 'Application', 'entity': 'application',
      'lifecycle': {
        'field': 'status', 'mode': 'enforce',
        'states': [
          {'id': 'draft', 'key': 'Draft', 'label': 'Draft', 'category': 'initial'},
          {'id': 'hold', 'key': 'Hold', 'label': 'On hold', 'category': 'active'},
          {'id': 'review', 'key': 'Review', 'label': 'Review', 'category': 'active', 'sla': {'within': 'P2D', 'steps': <Object?>[]}},
          {'id': 'done', 'key': 'Done', 'label': 'Done', 'category': 'terminal'},
        ],
        'transitions': [
          {'id': 'submit', 'key': 'submit', 'label': 'Submit', 'from': ['draft'], 'to': 'review', 'who': <Object?>[]},
        ],
      },
    });

UiWorkflowDefinition _automation() => UiWorkflowDefinition.fromJson({
      'specVersion': 1, 'id': 'wf_a', 'key': 'a', 'kind': 'automation', 'title': 'Check', 'entity': 'application',
      'trigger': {'type': 'created'},
      'steps': [
        {'id': 'ap', 'type': 'approval', 'title': 'Sign-off', 'assignees': [{'role': 'finance'}], 'rule': {'type': 'any'}, 'due': 'P3D', 'outcomes': {'approved': <Object?>[], 'rejected': <Object?>[], 'timedOut': <Object?>[]}},
      ],
    });

Future<UiWorkflowBuilderController> _pumpInspector(WidgetTester tester, UiWorkflowDefinition def, UiWfSelection sel, {UiWorkflowRegistry? registry}) async {
  final store = UiWorkflowBuilderController(definition: def)
    ..schema = UiWorkflowSchema(registry: registry ?? _registry())
    ..selection = sel;
  addTearDown(store.dispose);
  await pumpUi(tester, SizedBox(width: 380, height: 1600, child: WfBuilderScope(controller: store, child: const WfInspector(showHead: false))), size: const Size(380, 1600));
  return store;
}

WfSelect _select(WidgetTester tester, String label) => tester.widget<WfSelect>(find.byWidgetPredicate((w) => w is WfSelect && w.label == label));
WfSwitch _switch(WidgetTester tester, String label) => tester.widget<WfSwitch>(find.byWidgetPredicate((w) => w is WfSwitch && w.label == label));
Finder _title(String text) => find.byWidgetPredicate((w) => w is WfSectionTitle && w.text == text);
Finder _checks(String label) => find.byWidgetPredicate((w) => w is WfChecks && w.label == label);
Future<void> _toggle(WidgetTester tester, String group, String option) async {
  await tester.tap(find.descendant(of: _checks(group), matching: find.text(option)));
  await tester.pumpAndSettle();
}

UiJson _step(UiWorkflowBuilderController c) => c.selectedStep!.json;
UiJson _sla(UiWorkflowBuilderController c) => c.selectedState!.sla!.json;

void main() {
  group('schema and JSON', () {
    test('the new keys parse and serialise back unchanged', () {
      final json = {
        'specVersion': 1, 'id': 'x', 'key': 'x', 'kind': 'lifecycle', 'title': 'X', 'entity': 'application',
        'publicProcessingTime': {'estimate': '5 working days', 'display': true},
        'lifecycle': {
          'field': 'status',
          'states': [
            {'id': 's1', 'key': 'a', 'label': 'A', 'category': 'initial', 'sla': {'within': 'P5D', 'calendar': 'working', 'steps': <Object?>[], 'pauseOnStatus': ['s2'], 'pauseOnEvent': ['e1'], 'resumeOnEvent': ['e2']}},
            {'id': 's2', 'key': 'b', 'label': 'B', 'category': 'terminal'},
          ],
          'transitions': <Object?>[],
        },
      };
      final def = UiWorkflowDefinition.fromJson(jsonDecode(jsonEncode(json)));
      expect(def.publicProcessingTime!.estimate, '5 working days');
      expect(def.publicProcessingTime!.display, isTrue);
      final sla = def.lifecycle!.states.first.sla!;
      expect(sla.pauseOnStatus, ['s2']);
      expect(sla.pauseOnEvent, ['e1']);
      expect(sla.resumeOnEvent, ['e2']);
      expect(jsonEncode(def.toJson()), jsonEncode(json));

      final approval = UiWfApprovalStep.of(UiWfStep.fromJson({'id': 'a', 'type': 'approval', 'makerChecker': {'excludeInitiator': true, 'requiredRole': 'finance'}}));
      expect(approval.makerChecker!.excludeInitiator, isTrue);
      expect(approval.makerChecker!.excludePreviousApprover, isFalse);
      expect(approval.makerChecker!.requiredRole, 'finance');
    });

    test('the assignee kinds', () {
      expect(UiWfAssignee.department('d').json, {'department': 'd'});
      expect(UiWfAssignee.portal('p').json, {'portal': 'p'});
      expect(UiWfAssignee.queue('q').json, {'queue': 'q'});
      expect([for (final a in [UiWfAssignee.department('d'), UiWfAssignee.portal('p'), UiWfAssignee.queue('q')]) '${a.kind}:${a.value}'], ['department:d', 'portal:p', 'queue:q']);
      final reg = _registry();
      expect((reg.departments!.single.key, reg.portals!.single.key, reg.queues!.single.key), ('licensing', 'citizen', 'frontdesk'));
      expect(_registry(lists: false).departments, isNull);
    });

    test('a definition that uses none of it serialises exactly as before', () {
      final json = _lifecycle().toJson();
      final before = jsonEncode(json);
      expect(jsonEncode(UiWorkflowDefinition.fromJson(jsonDecode(before)).toJson()), before);
      expect(before, isNot(contains('pauseOn')));
      expect(before, isNot(contains('publicProcessingTime')));
      expect(jsonEncode(_automation().toJson()), isNot(contains('makerChecker')));
    });

    test('a record view carries the processing time only when the engine sends it', () {
      expect(UiWfRecord.fromJson({'entity': 'a', 'id': '1'}).publicProcessingTime, isNull);
      expect(UiWfRecord.fromJson({'entity': 'a', 'id': '1', 'publicProcessingTime': '5 working days'}).publicProcessingTime, '5 working days');
    });

    test('removing a state drops it from other states\' pause lists, and the key when it was the last', () {
      final def = UiWorkflowDefinition.fromJson({
        ..._lifecycle().json,
        'lifecycle': {
          ..._lifecycle().lifecycle!.json,
          'states': [
            {'id': 'draft', 'key': 'Draft', 'label': 'Draft', 'category': 'initial'},
            {'id': 'hold', 'key': 'Hold', 'label': 'On hold', 'category': 'active'},
            {'id': 'other', 'key': 'Other', 'label': 'Other', 'category': 'active'},
            {'id': 'review', 'key': 'Review', 'label': 'Review', 'category': 'active', 'sla': {'within': 'P2D', 'steps': <Object?>[], 'pauseOnStatus': ['hold', 'other']}},
          ],
        },
      });
      final one = removeState(def, 'hold').lifecycle!.states.last.sla!;
      expect(one.pauseOnStatus, ['other']);
      final none = removeState(removeState(def, 'hold'), 'other').lifecycle!.states.last.sla!;
      expect(none.json.containsKey('pauseOnStatus'), isFalse);
    });
  });

  group('labels', () {
    test('describeAssignees uses the registry label, then the key', () {
      final ctx = UiWfDescribeContext(registry: _registry(), def: createWorkflow('automation'));
      expect(describeAssignees([UiWfAssignee.department('licensing'), UiWfAssignee.portal('citizen'), UiWfAssignee.queue('frontdesk')], ctx), 'Licensing department, Citizen portal and Front desk queue');
      expect(describeAssignees([UiWfAssignee.queue('gone')], ctx), 'gone');
    });

    test('audit labels and sentences for a paused and resumed time limit', () {
      expect(wfAuditActionLabel('lifecycle', 'slaPaused'), 'Time limit paused');
      expect(wfAuditActionLabel('lifecycle', 'slaResumed'), 'Time limit running again');
      UiWfAuditEntry entry(String action) => UiWfAuditEntry.fromJson({'seq': 1, 'actorType': 'system', 'category': 'lifecycle', 'action': action, 'data': '{"state":"Review","reason":"event","signal":"docs.requested"}'});
      String label(Object? k) => const {'Review': 'In review'}[k] ?? '$k';
      expect(wfDescribeHistory(entry('slaPaused'), label), 'Time limit paused in In review');
      expect(wfDescribeHistory(entry('slaResumed'), label), 'Time limit running again in In review');
    });
  });

  group('assignee editor', () {
    testWidgets('offers departments, portals and queues and emits each kind; chips show labels', (tester) async {
      var value = <UiWfAssignee>[];
      await pumpUi(tester, StatefulBuilder(builder: (context, set) => SizedBox(width: 380, child: WfAssigneesEditor(registry: _registry(), value: value, onChanged: (v) => set(() => value = v)))));
      final options = _select(tester, 'Add to people').options;
      expect([for (final o in options) o.label], containsAllInOrder(['A department › Licensing department', 'A portal › Citizen portal', 'A queue › Front desk queue']));
      expect([for (final o in options) o.value], containsAll(['department:licensing', 'portal:citizen', 'queue:frontdesk']));
      for (final v in ['department:licensing', 'portal:citizen', 'queue:frontdesk']) {
        _select(tester, 'Add to people').onChanged!(v);
        await tester.pumpAndSettle();
      }
      expect([for (final a in value) a.json], [{'department': 'licensing'}, {'portal': 'citizen'}, {'queue': 'frontdesk'}]);
      expect(find.text('Licensing department'), findsOneWidget);
      expect(find.text('Citizen portal'), findsOneWidget);
      expect(find.text('Front desk queue'), findsOneWidget);
    });

    testWidgets('nothing is offered when the registry lists none', (tester) async {
      await pumpUi(tester, SizedBox(width: 380, child: WfAssigneesEditor(registry: _registry(lists: false), value: const [], onChanged: (_) {})));
      expect([for (final o in _select(tester, 'Add to people').options) o.label], isNot(contains(startsWith('A department'))));
      expect([for (final o in _select(tester, 'Add to people').options) o.label], isNot(contains(startsWith('A queue'))));
    });
  });

  group('approval: separation of duties', () {
    testWidgets('each control writes makerChecker; turning all off removes the key', (tester) async {
      final c = await _pumpInspector(tester, _automation(), const UiWfSelection.step('ap'));
      expect(_title('Separation of duties'), findsOneWidget);
      expect(find.text('Stops one person from both asking and approving.'), findsOneWidget);
      expect(_step(c).containsKey('makerChecker'), isFalse);

      _switch(tester, 'The person who started it cannot approve').onChanged!(true);
      await tester.pumpAndSettle();
      expect(_step(c)['makerChecker'], {'excludeInitiator': true});

      _switch(tester, 'Whoever approved the step before cannot approve this one').onChanged!(true);
      await tester.pumpAndSettle();
      _select(tester, 'Must hold the role').onChanged!('finance');
      await tester.pumpAndSettle();
      expect(_step(c)['makerChecker'], {'excludeInitiator': true, 'excludePreviousApprover': true, 'requiredRole': 'finance'});
      expect([for (final o in _select(tester, 'Must hold the role').options) o.label], ['Any role', 'Finance', 'Head of office']);

      _switch(tester, 'The person who started it cannot approve').onChanged!(false);
      await tester.pumpAndSettle();
      _select(tester, 'Must hold the role').onChanged!('');
      await tester.pumpAndSettle();
      expect(_step(c)['makerChecker'], {'excludePreviousApprover': true});
      _switch(tester, 'Whoever approved the step before cannot approve this one').onChanged!(false);
      await tester.pumpAndSettle();
      expect(_step(c).containsKey('makerChecker'), isFalse);
    });

    testWidgets('the role select is hidden when the registry has no roles', (tester) async {
      final reg = UiWorkflowRegistry.fromJson({'specVersion': 1, 'entities': <Object?>[]});
      await _pumpInspector(tester, _automation(), const UiWfSelection.step('ap'), registry: reg);
      expect(_title('Separation of duties'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is WfSelect && w.label == 'Must hold the role'), findsNothing);
    });
  });

  group('state: pause and resume the time limit', () {
    testWidgets('the three lists write the sla keys and removing the last option removes the key', (tester) async {
      final c = await _pumpInspector(tester, _lifecycle(), const UiWfSelection.state('review'));
      expect(find.text('Time spent paused does not count towards the limit.'), findsOneWidget);
      expect(_sla(c).keys, isNot(contains('pauseOnStatus')));

      // Other states only: the state itself is not offered.
      expect(find.descendant(of: _checks('Pause the clock while the record is in'), matching: find.text('Review')), findsNothing);
      // A final state ends the clock, so it is not offered either.
      expect(find.descendant(of: _checks('Pause the clock while the record is in'), matching: find.text('Done')), findsNothing);
      await _toggle(tester, 'Pause the clock while the record is in', 'On hold');
      await _toggle(tester, 'Pause the clock while the record is in', 'Draft');
      expect(_sla(c)['pauseOnStatus'], ['draft', 'hold']);
      await _toggle(tester, 'Pause the clock when', 'Documents requested');
      await _toggle(tester, 'Start it again when', 'Documents received');
      expect(_sla(c), containsPair('pauseOnEvent', ['docs.requested']));
      expect(_sla(c), containsPair('resumeOnEvent', ['docs.received']));
      expect(_sla(c)['within'], 'P2D');

      await _toggle(tester, 'Pause the clock while the record is in', 'On hold');
      expect(_sla(c)['pauseOnStatus'], ['draft']);
      await _toggle(tester, 'Pause the clock while the record is in', 'Draft');
      await _toggle(tester, 'Pause the clock when', 'Documents requested');
      await _toggle(tester, 'Start it again when', 'Documents received');
      expect(jsonEncode(_sla(c)), jsonEncode({'within': 'P2D', 'steps': <Object?>[]}));
    });

    testWidgets('signal lists are hidden when the registry has none, and nothing shows without a time limit', (tester) async {
      await _pumpInspector(tester, _lifecycle(), const UiWfSelection.state('review'), registry: _registry(lists: false));
      expect(_checks('Pause the clock while the record is in'), findsOneWidget);
      expect(_checks('Pause the clock when'), findsNothing);
      expect(_checks('Start it again when'), findsNothing);
    });

    testWidgets('a state without a time limit has no pause controls', (tester) async {
      await _pumpInspector(tester, _lifecycle(), const UiWfSelection.state('hold'));
      expect(_checks('Pause the clock while the record is in'), findsNothing);
      expect(find.text('Time spent paused does not count towards the limit.'), findsNothing);
    });
  });

  group('workflow settings: public processing time', () {
    for (final def in [_automation(), _lifecycle()]) {
      testWidgets('${def.kind}: estimate and switch write the key; both off removes it', (tester) async {
        final c = await _pumpInspector(tester, def, UiWfSelection.workflow);
        expect(_title('Public processing time'), findsOneWidget);
        expect(find.text('Shown to people outside the office, for example on the service page. It does not change any time limit.'), findsOneWidget);
        expect(c.def.json.containsKey('publicProcessingTime'), isFalse);

        await tester.enterText(find.byWidgetPredicate((w) => w is UiInput && w.placeholder == 'e.g. 5 working days'), '5 working days');
        await tester.pumpAndSettle();
        expect(c.def.json['publicProcessingTime'], {'estimate': '5 working days', 'display': false});
        _switch(tester, 'Show this to the public').onChanged!(true);
        await tester.pumpAndSettle();
        expect(c.def.json['publicProcessingTime'], {'estimate': '5 working days', 'display': true});

        _switch(tester, 'Show this to the public').onChanged!(false);
        await tester.pumpAndSettle();
        await tester.enterText(find.byWidgetPredicate((w) => w is UiInput && w.placeholder == 'e.g. 5 working days'), '');
        await tester.pumpAndSettle();
        expect(c.def.json.containsKey('publicProcessingTime'), isFalse);
      });
    }

    testWidgets('the estimate stops at 200 characters', (tester) async {
      final c = await _pumpInspector(tester, _automation(), UiWfSelection.workflow);
      await tester.enterText(find.byWidgetPredicate((w) => w is UiInput && w.placeholder == 'e.g. 5 working days'), 'x' * 250);
      await tester.pumpAndSettle();
      expect(c.def.publicProcessingTime!.estimate.length, 200);
    });
  });

  group('record panel', () {
    testWidgets('says the usual processing time only when the record carries it', (tester) async {
      final api = FakeWorkflowApi();
      await pumpUi(tester, SizedBox(width: 480, height: 900, child: SingleChildScrollView(child: UiWorkflowPanel(api: api, entity: 'application', entityId: '1'))), size: const Size(480, 900));
      await tester.pumpAndSettle();
      expect(find.textContaining('Usual processing time'), findsNothing);

      api.recordJson['publicProcessingTime'] = '5 working days';
      final key = GlobalKey<UiWorkflowPanelState>();
      await pumpUi(tester, SizedBox(width: 480, height: 900, child: SingleChildScrollView(child: UiWorkflowPanel(key: key, api: api, entity: 'application', entityId: '1'))), size: const Size(480, 900));
      await tester.pumpAndSettle();
      expect(find.text('Usual processing time: 5 working days'), findsOneWidget);
    });

    testWidgets('also in the compact layout', (tester) async {
      final api = FakeWorkflowApi()..recordJson['publicProcessingTime'] = '2 weeks';
      await pumpUi(tester, SizedBox(width: 480, height: 900, child: SingleChildScrollView(child: UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.compact))), size: const Size(480, 900));
      await tester.pumpAndSettle();
      expect(find.text('Usual processing time: 2 weeks'), findsOneWidget);
    });
  });
}
