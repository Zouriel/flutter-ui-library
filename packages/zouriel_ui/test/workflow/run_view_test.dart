import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/runtime.dart' show WfRunView;
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

// Port of the web `run-view.spec.ts`: the run view inside the workflow panel and the tasks drawer.

Finder button(String label) => find.byWidgetPredicate((w) => w is UiButton && w.label == label);

final _pay = UiWfStep.fromJson({...createStep('action').json, 'id': 'pay', 'title': 'Create the payment', 'action': 'bank.pay', 'input': <String, Object?>{}});
final _mail = UiWfStep.fromJson({...createStep('notify').json, 'id': 'mail', 'title': 'Email the student'});
final UiWorkflowDefinition _def = createWorkflow('automation', title: 'Pay approved scholarships', entity: 'application').patch({'steps': [_pay.json, _mail.json]});

UiWfInstance stuck([Map<String, Object?> extra = const {}]) => UiWfInstance.fromJson({
      'id': 'r1', 'definitionId': _def.id, 'definitionKey': _def.key, 'title': _def.title, 'version': 1, 'kind': 'automation',
      'entity': 'application', 'entityId': '1', 'entityTitle': 'Bursary – Ali', 'status': 'incident',
      'error': 'InvalidOperationException: Bank API: 503 Service Unavailable', 'errorStepId': 'pay',
      'startedAt': DateTime.now().toUtc().toIso8601String(), 'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'steps': [
        {'id': 'sr1', 'nodeId': 'pay', 'type': 'action', 'attempt': 3, 'status': 'failed', 'error': 'InvalidOperationException: Bank API: 503 Service Unavailable', 'startedAt': ''},
      ],
      'tokens': [{'id': 't1', 'status': 'waiting', 'waiting': 'incident', 'stepId': 'pay'}],
      ...extra,
    });

class _Api extends Fake implements UiWorkflowApi {
  _Api(this.canIntervene);
  final bool canIntervene;
  final calls = <List<Object?>>[];

  @override
  Future<UiWfInstance> instance(String id) async => stuck();
  @override
  Future<UiWorkflowDefinition> instanceDefinition(String id) async => _def;
  @override
  Future<UiWfMe> me() async => UiWfMe.fromJson({'type': 'user', 'id': 'u', 'can': {'intervene': canIntervene}});
  @override
  Future<UiWorkflowSchema> schema() async => UiWorkflowSchema(
        registry: UiWorkflowRegistry.fromJson({
          'entities': <Object?>[],
          'actions': [
            {'key': 'bank.pay', 'label': 'Pay', 'inputs': <Object?>[], 'outputs': [{'key': 'reference', 'label': 'Payment reference', 'type': 'text'}]},
          ],
        }),
      );
  @override
  Future<UiWfInstance> retry(String id, {String? target}) async {
    calls.add(['retry', id, target]);
    return stuck({'status': 'running', 'error': null, 'tokens': <Object?>[]});
  }

  @override
  Future<UiWfInstance> skip(String id, {UiJson? outputs, String? target}) async {
    calls.add(['skip', id, outputs, target]);
    return stuck({'status': 'running', 'error': null, 'tokens': <Object?>[]});
  }

  @override
  Future<UiWfInstance> cancel(String id, {String? reason}) async {
    calls.add(['cancel', id, reason]);
    return stuck({'status': 'cancelled', 'tokens': <Object?>[]});
  }
}

Future<_Api> _pump(WidgetTester tester, {required bool canIntervene}) async {
  final api = _Api(canIntervene);
  await pumpUi(tester, SizedBox(width: 520, child: WfRunView(api: api, instanceId: 'r1')), size: const Size(520, 900));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('shows each step, why the run stopped (without the exception type), and the steps not reached', (tester) async {
    await _pump(tester, canIntervene: true);
    expect(find.textContaining('Stopped: Bank API: 503 Service Unavailable'), findsOneWidget);
    expect(find.textContaining('InvalidOperationException: Bank API'), findsOneWidget, reason: 'the step\'s own detail keeps the full text');
    expect(find.text('Create the payment'), findsOneWidget);
    expect(find.text('Email the student'), findsOneWidget);
    expect(tester.widget<Opacity>(find.ancestor(of: find.text('Email the student'), matching: find.byType(Opacity)).first).opacity, 0.45);
  });

  testWidgets('tries again for people who may intervene', (tester) async {
    final api = await _pump(tester, canIntervene: true);
    await tester.tap(button('Try again'));
    await tester.pumpAndSettle();
    expect(api.calls, [['retry', 'r1', null]]);
  });

  testWidgets('skips the step with the results it would have produced, named as the app declares them', (tester) async {
    final api = await _pump(tester, canIntervene: true);
    await tester.tap(button('Skip the step'));
    await tester.pumpAndSettle();
    expect(find.text('Skip “Create the payment”'), findsOneWidget);
    expect(find.text('Payment reference'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(UiInput), matching: find.byType(EditableText)), ' BML-48213 ');
    await tester.tap(button('Skip the step').last);
    await tester.pumpAndSettle();
    expect(api.calls, [['skip', 'r1', {'reference': 'BML-48213'}, null]]);
    expect(find.text('Skip “Create the payment”'), findsNothing);
  });

  testWidgets('skipping with nothing filled sends no results', (tester) async {
    final api = await _pump(tester, canIntervene: true);
    await tester.tap(button('Skip the step'));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(UiInput), matching: find.byType(EditableText)), '   ');
    await tester.tap(button('Skip the step').last);
    await tester.pumpAndSettle();
    expect(api.calls, [['skip', 'r1', null, null]]);
  });

  testWidgets('cancels only after a confirmation, with optional remarks', (tester) async {
    final api = await _pump(tester, canIntervene: true);
    await tester.tap(button('Cancel the run'));
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
    expect(find.text('Remarks (optional)'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(UiTextarea), matching: find.byType(EditableText)), 'Scholarship withdrawn');
    await tester.tap(button('Cancel the run').last);
    await tester.pumpAndSettle();
    expect(api.calls, [['cancel', 'r1', 'Scholarship withdrawn']]);
  });

  testWidgets('Back closes the confirmation without cancelling', (tester) async {
    final api = await _pump(tester, canIntervene: true);
    await tester.tap(button('Cancel the run'));
    await tester.pumpAndSettle();
    await tester.tap(button('Back'));
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
    expect(find.text('Remarks (optional)'), findsNothing);
  });

  testWidgets('people who may not intervene see why it stopped and who can fix it, without the buttons', (tester) async {
    await _pump(tester, canIntervene: false);
    expect(find.textContaining('Stopped: Bank API'), findsOneWidget);
    expect(button('Try again'), findsNothing);
    expect(find.text('Someone who looks after workflows can try it again or skip it.'), findsOneWidget);
  });

  testWidgets('showHead: false leaves out the title, version and status', (tester) async {
    final api = _Api(true);
    await pumpUi(tester, SizedBox(width: 520, child: WfRunView(api: api, instanceId: 'r1', showHead: false)), size: const Size(520, 900));
    await tester.pumpAndSettle();
    expect(find.text('Pay approved scholarships'), findsNothing);
    expect(find.text('v1'), findsNothing);
    await pumpUi(tester, SizedBox(width: 520, child: WfRunView(key: const ValueKey('head'), api: api, instanceId: 'r1')), size: const Size(520, 900));
    await tester.pumpAndSettle();
    expect(find.text('Pay approved scholarships'), findsOneWidget);
  });

  test('wfReadableError drops the engine\'s exception type, keeps everything else', () {
    expect(wfReadableError('InvalidOperationException: Bank API: 503 Service Unavailable'), 'Bank API: 503 Service Unavailable');
    expect(wfReadableError('Bank API: 503'), 'Bank API: 503');
    expect(wfReadableError('The approver left: no one to ask'), 'The approver left: no one to ask');
    expect(wfReadableError(null), '');
  });
}
