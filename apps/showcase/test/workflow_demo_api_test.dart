import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/workflow_demo_api.dart';

// The demo office's reset list: it lists what the workflow really did to application 1, a reset
// takes the ticked things back, and afterwards nothing is listed until the application moves on.
void main() {
  test('the reset list is about application 1 and empties once it started over', () async {
    final api = DemoWorkflowApi();
    final before = await api.resetPreview('application', '1');
    final ids = [for (final i in before.items) i.id];
    expect(ids, contains('field:application:1:reviewer'));
    expect(ids.where((id) => id.contains(':a1:')), isEmpty);
    expect(api.reviewer, 'Rana Ibrahim');
    expect(api.hasChecklist, isTrue);

    await api.resetRecord('application', '1', undo: ['field:application:1:reviewer', 'created:document:d9'], comment: 'Wrong programme');
    expect(api.reviewer, isNull, reason: 'the reviewer is really put back');
    expect(api.hasChecklist, isFalse);
    expect(api.budget, 42000, reason: 'unticked: left as it is');
    expect((await api.resetPreview('application', '1')).items, isEmpty);

    // Submitted again: the workflow assigns a reviewer and opens a checklist, which can be taken back again.
    await api.applyTransition('application', '1', 'submit');
    expect(api.reviewer, 'Rana Ibrahim');
    expect([for (final i in (await api.resetPreview('application', '1')).items) i.id], ['field:application:1:reviewer', 'created:document:d9']);
  });

  test('a reset with ids the list no longer has is refused as changed', () async {
    final api = DemoWorkflowApi();
    await api.resetRecord('application', '1');
    expect(() => api.resetRecord('application', '1', undo: ['created:document:d9']), throwsA(isA<UiWfApiError>().having((e) => e.code, 'code', 'resetChanged')));
  });

  test('remarks are kept in the history', () async {
    final api = DemoWorkflowApi();
    await api.applyTransition('application', '1', 'reject', comment: 'Missing transcript');
    final h = await api.recordHistory('application', '1');
    expect(h.any((e) => wfDescribeHistory(e, (k) => '$k').contains('(“Missing transcript”)')), isTrue);
  });
}
