import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/form_builder/engine/schema.dart' show UiFormSubmission, UiFbPickedFile;
import 'package:zouriel_ui/src/workflow/runtime.dart'
    show WfRecordActions, WfRunView, showWfDecideDialog, wfFormAnswers, wfRemarksCounter, wfRemarksMax, wfSkipValue;
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fake_api.dart';

// Mirrors @zouriel/ui 533924c: untouched form answers are sent, remarks have a 2,000-character
// limit, record actions never act on an old record, typed skip results, and the audit's loading
// state and run-only export.

Finder button(String label) => find.byWidgetPredicate((w) => w is UiButton && w.label == label);
Finder inModal(Finder f) => find.descendant(of: find.byType(UiModal), matching: f);

/// A form whose one answer is already filled in (a default nobody touches).
const Map<String, Object?> prefilled = {
  'schemaVersion': 1, 'id': 'f1', 'title': 'Questions',
  'pages': [
    {'id': 'p1', 'elements': [{'kind': 'field', 'id': 'e1', 'type': 'text', 'key': 'reason', 'label': 'Reason', 'defaultValue': 'Late documents'}]},
  ],
};

/// Records what the engine was sent.
class _Sent extends FakeWorkflowApi {
  final sent = <List<Object?>>[];
  @override
  Future<UiWfTask> decide(String id, String outcome, {String? comment, UiJson? data}) async {
    sent.add(['decide', id, outcome, comment, data]);
    return UiWfTask.fromJson({...FakeWorkflowApi.taskJson(id), 'status': 'completed', 'outcome': outcome});
  }

  @override
  Future<UiWfRecord> applyTransition(String entity, String id, String key, {UiJson? input, String? comment}) async {
    sent.add(['apply', entity, id, key, input, comment]);
    return UiWfRecord.fromJson(recordJson);
  }

  @override
  Future<UiWfInstance> startManual(String workflow, String? entity, String? id, {UiJson? input}) async {
    sent.add(['manual', workflow, id, input]);
    return UiWfInstance.fromJson({'id': 'm1'});
  }

  @override
  Future<UiWfInstance> skip(String id, {UiJson? outputs, String? target}) async {
    sent.add(['skip', id, outputs, target]);
    return UiWfInstance.fromJson({...instanceJson, 'status': 'running'});
  }
}

UiWfTask _task([Map<String, Object?> extra = const {}]) => UiWfTask.fromJson({...FakeWorkflowApi.taskJson('t1'), ...extra});

Future<void> _openDecide(WidgetTester tester, UiWfTask task, UiWorkflowApi api) async {
  await pumpUi(tester, Builder(builder: (ctx) => UiButton(label: 'Open', onPressed: () => showWfDecideDialog(ctx, task: task, api: api))), size: const Size(700, 900));
  await tester.tap(button('Open'));
  await tester.pumpAndSettle();
}

Finder _remarksBox() => find.descendant(of: find.byWidgetPredicate((w) => w is UiTextarea && w.maxLength != null), matching: find.byType(EditableText));

void main() {
  group('helpers', () {
    test('reads every answer from the submission and refuses picked files that have nowhere to go', () {
      expect(wfFormAnswers(const UiFormSubmission(formId: 'f', revision: null, data: {'a': 1}, submittedAt: '', files: {})).data, {'a': 1});
      final withFile = wfFormAnswers(UiFormSubmission(formId: 'f', revision: null, data: const {}, submittedAt: '', files: {
        'doc': [UiFbPickedFile(name: 'x.txt', size: 1, type: 'text/plain')],
      }));
      expect(withFile.error, 'The files picked in this form can’t be sent: the form needs an upload address for them.');
    });

    test('turns a skipped step\'s results into their registry types', () {
      expect(wfSkipValue('number', ' 42 '), 42);
      expect(wfSkipValue('number', 'abc'), isNull);
      expect(wfSkipValue('currency', 12.5), 12.5);
      expect(wfSkipValue('boolean', false), false);
      expect(wfSkipValue('boolean', 'true'), true);
      expect(wfSkipValue('text', '  ok '), 'ok');
      expect(wfSkipValue('text', '  '), isNull);
      expect(wfSkipValue('date', null), isNull);
    });

    test('shows the remarks counter only near the 2,000-character limit', () {
      expect(wfRemarksCounter('x' * 100), '');
      expect(wfRemarksCounter('x' * 1850), '1,850 / 2,000');
    });
  });

  group('decide dialog', () {
    testWidgets('sends the form\'s answers even when nobody touched them (a default value)', (tester) async {
      final api = _Sent();
      await _openDecide(tester, _task({'form': prefilled}), api);
      await tester.tap(inModal(button('Approve')));
      await tester.pumpAndSettle();
      expect(api.sent.single, ['decide', 't1', 'approved', null, {'reason': 'Late documents'}]);
    });

    testWidgets('remarks are capped at 2,000, counted near the limit and sent trimmed', (tester) async {
      final api = _Sent();
      await _openDecide(tester, _task(), api);
      expect(tester.widget<UiTextarea>(find.byWidgetPredicate((w) => w is UiTextarea && w.maxLength != null)).maxLength, wfRemarksMax);
      await tester.enterText(_remarksBox(), 'x' * 1850);
      await tester.pump();
      expect(find.text('1,850 / 2,000'), findsOneWidget);
      await tester.enterText(_remarksBox(), 'x' * 2100);
      await tester.pump();
      expect(find.text('2,000 / 2,000'), findsOneWidget, reason: 'the field takes no more');
      await tester.enterText(_remarksBox(), '  Missing transcript ');
      await tester.pump();
      expect(find.textContaining('/ 2,000'), findsNothing);
      await tester.tap(inModal(button('Reject')));
      await tester.pumpAndSettle();
      expect(api.sent.single, ['decide', 't1', 'rejected', 'Missing transcript', const <String, Object?>{}]);
    });
  });

  group('record actions', () {
    UiWfRecord rec(_Sent api, {String id = '1', List<Object?>? transitions, List<Object?>? manual}) => UiWfRecord.fromJson({
          ...api.recordJson, 'id': id, 'tasks': <Object?>[],
          'transitions': ?transitions, 'manual': ?manual,
        });

    testWidgets('a move with a form sends the answers nobody touched', (tester) async {
      final api = _Sent();
      final r = rec(api, transitions: [{'key': 'withdraw', 'label': 'Withdraw', 'to': 'draft', 'toLabel': 'Draft', 'tone': null, 'confirm': null, 'form': prefilled}]);
      await pumpUi(tester, SizedBox(width: 600, child: WfRecordActions(api: api, record: r, entity: 'application', entityId: '1')), size: const Size(700, 900));
      await tester.tap(button('Withdraw'));
      await tester.pumpAndSettle();
      await tester.tap(inModal(button('Withdraw')));
      await tester.pumpAndSettle();
      expect(api.sent.single, ['apply', 'application', '1', 'withdraw', {'reason': 'Late documents'}, null]);
    });

    testWidgets('a manual start with a form sends its prefilled answers', (tester) async {
      final api = _Sent();
      final r = rec(api, transitions: const [], manual: [{'key': 'ask', 'label': 'Ask for documents', 'form': prefilled}]);
      await pumpUi(tester, SizedBox(width: 600, child: WfRecordActions(api: api, record: r, entity: 'application', entityId: '1')), size: const Size(700, 900));
      await tester.tap(button('Ask for documents'));
      await tester.pumpAndSettle();
      await tester.tap(inModal(button('Ask for documents')));
      await tester.pumpAndSettle();
      expect(api.sent.single, ['manual', 'ask', '1', {'reason': 'Late documents'}]);
    });

    testWidgets('never sends an old record\'s move against a new id while the host is switching', (tester) async {
      final api = _Sent();
      final old = rec(api, transitions: [{'key': 'withdraw', 'label': 'Withdraw', 'to': 'draft', 'toLabel': 'Draft', 'tone': null, 'confirm': null, 'form': null}]);
      // The host already names record 2 but still binds record 1.
      await pumpUi(tester, SizedBox(width: 600, child: WfRecordActions(api: api, record: old, entity: 'application', entityId: '2')), size: const Size(700, 900));
      await tester.tap(button('Withdraw'));
      await tester.pumpAndSettle();
      expect(api.sent, isEmpty);
    });

    testWidgets('forgets an error and closes an open task when it is shown another record', (tester) async {
      final api = _Sent();
      final host = ValueNotifier('1');
      UiWfRecord r1 = rec(api, transitions: [{'key': 'withdraw', 'label': 'Withdraw', 'to': 'draft', 'toLabel': 'Draft', 'tone': null, 'confirm': null, 'form': null}]);
      r1 = UiWfRecord.fromJson({...r1.json, 'tasks': [FakeWorkflowApi.taskJson('t1')]});
      await pumpUi(
        tester,
        SizedBox(width: 600, child: ValueListenableBuilder(valueListenable: host, builder: (_, id, _) => WfRecordActions(api: _Failing(), record: id == '1' ? r1 : rec(api, id: '2'), entity: 'application', entityId: id))),
        size: const Size(700, 900),
      );
      await tester.tap(button('Withdraw'));
      await tester.pumpAndSettle();
      expect(find.text('Refused'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(RegExp('^Finance sign-off,')));
      await tester.pumpAndSettle();
      expect(find.byType(UiModal), findsOneWidget);
      host.value = '2';
      await tester.pumpAndSettle();
      expect(find.text('Refused'), findsNothing);
      expect(find.byType(UiModal), findsNothing);
    });
  });

  group('skip dialog', () {
    testWidgets('asks each result in its own type, requires the required ones and sends numbers as numbers', (tester) async {
      final api = _Sent()..canIntervene = true;
      api.registry = UiWorkflowRegistry.fromJson({
        ...api.registry.json,
        'actions': [
          {'key': 'invoice', 'label': 'Create invoice', 'inputs': <Object?>[], 'outputs': [
            {'key': 'invoiceNo', 'label': 'Invoice number', 'type': 'text', 'required': true},
            {'key': 'amount', 'label': 'Amount', 'type': 'number'},
            {'key': 'paid', 'label': 'Paid', 'type': 'boolean'},
          ]},
        ],
      });
      await pumpUi(tester, SizedBox(width: 520, child: WfRunView(api: api, instanceId: 'i1')), size: const Size(520, 1000));
      // The second stopped path is the app action (Archive documents → invoice).
      await tester.tap(button('Skip').at(1));
      await tester.pumpAndSettle();
      expect(find.text('Invoice number (required)'), findsOneWidget);
      expect(find.byType(UiNumberInput), findsOneWidget);
      await tester.tap(inModal(button('Skip the step')));
      await tester.pumpAndSettle();
      expect(find.text('Give Invoice number: the steps after it need it.'), findsOneWidget);
      expect(api.sent, isEmpty);
      await tester.enterText(find.descendant(of: find.byWidgetPredicate((w) => w is UiInput && w.semanticLabel == 'Invoice number'), matching: find.byType(EditableText)), ' INV-9 ');
      await tester.enterText(find.descendant(of: find.byType(UiNumberInput), matching: find.byType(EditableText)), '42');
      await tester.pump();
      await tester.tap(inModal(button('Skip the step')));
      await tester.pumpAndSettle();
      expect(api.sent.single, ['skip', 'i1', {'invoiceNo': 'INV-9', 'amount': 42}, 'tokB']);
    });

    testWidgets('cancel remarks are capped at 2,000', (tester) async {
      final api = _Sent()..canIntervene = true;
      await pumpUi(tester, SizedBox(width: 520, child: WfRunView(api: api, instanceId: 'i1')), size: const Size(520, 1000));
      await tester.tap(button('Cancel the run'));
      await tester.pumpAndSettle();
      expect(tester.widget<UiTextarea>(find.byWidgetPredicate((w) => w is UiTextarea && w.maxLength != null)).maxLength, 2000);
    });
  });

  group('audit', () {
    testWidgets('says it is loading before the first page, not that there are no entries', (tester) async {
      final api = _SlowAudit();
      await pumpUi(tester, SizedBox(width: 700, child: UiWorkflowAudit(api: api)), size: const Size(700, 800));
      expect(find.text('Loading…'), findsOneWidget);
      expect(find.text('No entries.'), findsNothing);
      api.gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('No entries.'), findsOneWidget);
    });

    testWidgets('exports the record\'s entries, and offers no export for one run (the export has no run filter)', (tester) async {
      final api = FakeWorkflowApi();
      await pumpUi(tester, SizedBox(width: 700, height: 1600, child: SingleChildScrollView(child: UiWorkflowAudit(api: api, entity: 'application', entityId: '1', onExport: (_, _) {}))), size: const Size(700, 1600));
      expect(button('CSV'), findsOneWidget);
      await pumpUi(tester, SizedBox(width: 700, height: 1600, child: SingleChildScrollView(child: UiWorkflowAudit(key: const ValueKey('run'), api: api, instanceId: 'i1', onExport: (_, _) {}))), size: const Size(700, 1600));
      expect(button('CSV'), findsNothing);
      expect(find.textContaining('an export can’t be limited to one run'), findsOneWidget);
    });
  });
}

class _Failing extends _Sent {
  @override
  Future<UiWfRecord> applyTransition(String entity, String id, String key, {UiJson? input, String? comment}) async => throw const UiWfApiError(403, 'no', 'Refused');
}

class _SlowAudit extends FakeWorkflowApi {
  final gate = Completer<void>();
  @override
  Future<List<UiWfAuditEntry>> audit(UiWfAuditQuery q) async {
    await gate.future;
    return const [];
  }
}
