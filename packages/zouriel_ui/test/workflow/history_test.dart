import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fake_api.dart';

UiWfAuditEntry actor(String type, String? id, String? name) =>
    UiWfAuditEntry.fromJson({'seq': 1, 'actorType': type, 'actorId': id, 'actorName': name, 'category': 'task', 'action': 'created'});

void main() {
  group('wfActorLabel', () {
    test('names a workflow by its title, never its key', () {
      expect(wfActorLabel(actor('workflow', 'financeSignOff', null), (k) => k == 'financeSignOff' ? 'Pay approved scholarships' : null),
          'Workflow: Pay approved scholarships');
    });
    test('falls back to a readable key when the title is unknown', () {
      expect(wfActorLabel(actor('workflow', 'scholarshipReview', null)), 'Workflow: Scholarship review');
    });
    test('people by name; the engine as System', () {
      expect(wfActorLabel(actor('user', 'hana', 'Hana Yusuf')), 'Hana Yusuf');
      expect(wfActorLabel(actor('system', null, null)), 'System');
    });
  });

  test('wfStepTimedOut', () {
    expect(wfStepTimedOut({'outcome': 'timedOut'}), isTrue);
    expect(wfStepTimedOut({'timedOut': true}), isTrue);
    expect(wfStepTimedOut({'outcome': 'approved'}), isFalse);
    expect(wfStepTimedOut(null), isFalse);
  });

  testWidgets('the run view shows a timed-out step as Out of time, not Done', (tester) async {
    final api = FakeWorkflowApi();
    api.instanceJson['steps'] = [
      {'id': 'r1', 'nodeId': 'c', 'type': 'notify', 'attempt': 1, 'status': 'completed', 'output': {'outcome': 'timedOut'}, 'startedAt': ''},
    ];
    await pumpUi(tester, SizedBox(width: 420, height: 800, child: SingleChildScrollView(child: UiWorkflowRun(api: api, instanceId: 'i1'))), size: const Size(420, 800));
    await tester.pumpAndSettle();
    expect(find.text('Out of time'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
  });
}
