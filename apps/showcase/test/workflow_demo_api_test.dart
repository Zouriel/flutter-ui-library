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
    // A Draft application with nothing open: no reset is offered, so its list is refused.
    expect(() => api.resetPreview('application', '1'), throwsA(isA<UiWfApiError>().having((e) => e.code, 'code', 'notAllowed')));

    // Submitted again: the workflow assigns a reviewer and opens a checklist, which can be taken back again.
    api.actingAs = 'ali'; // the applicant submits it
    await api.applyTransition('application', '1', 'submit');
    api.actingAs = 'hana';
    expect(api.reviewer, 'Rana Ibrahim');
    expect([for (final i in (await api.resetPreview('application', '1')).items) i.id], ['field:application:1:reviewer', 'created:document:d9']);
  });

  test('a reset with ids the list no longer has is refused as changed; on a Draft application it is not offered', () async {
    final api = DemoWorkflowApi();
    expect(() => api.resetRecord('application', '1', undo: ['created:document:d99']), throwsA(isA<UiWfApiError>().having((e) => e.code, 'code', 'resetChanged')));
    await api.resetRecord('application', '1');
    expect((await api.record('application', '1')).reset, isNull);
    expect(() => api.resetRecord('application', '1'), throwsA(isA<UiWfApiError>().having((e) => e.code, 'code', 'notAllowed')));
  });

  test('each person sees and may do only their part', () async {
    final api = DemoWorkflowApi();
    // The head of office: the reviewer's moves and Start over, the transcript task, every screen.
    var r = await api.record('application', '1');
    expect([for (final t in r.transitions) t.key], ['approve', 'reject', 'sendBack']);
    expect(r.reset, isNotNull);
    expect((await api.me()).canPublish, isTrue);
    expect([for (final t in (await api.tasks(const UiWfTaskQuery(scope: 'mine', status: ['open']))).items) t.title], ['Check the transcript']);
    // The applicant: withdraw only, no reset, no tasks, no audit log.
    api.actingAs = 'ali';
    r = await api.record('application', '1');
    expect([for (final t in r.transitions) t.key], ['withdraw']);
    expect(r.reset, isNull);
    expect(r.tasks.every((t) => !t.canDecide), isTrue);
    expect((await api.me()).canPublish, isFalse);
    expect(() => api.audit(const UiWfAuditQuery()), throwsA(isA<UiWfApiError>()));
    expect(() => api.applyTransition('application', '1', 'approve'), throwsA(isA<UiWfApiError>()));
    expect([for (final a in api.applications) a.stateLabel], ['In review', 'Draft', 'Approved']);
    expect([for (final t in (await api.record('application', '2')).transitions) t.key], ['submit', 'withdraw']);
    // Finance: the sign-off.
    api.actingAs = 'mariyam';
    final mine = (await api.tasks(const UiWfTaskQuery(scope: 'mine', status: ['open']))).items;
    expect([for (final t in mine) (t.title, t.canDecide)], [('Finance sign-off', true)]);
  });

  test('remarks are kept in the history', () async {
    final api = DemoWorkflowApi();
    await api.applyTransition('application', '1', 'reject', comment: 'Missing transcript');
    final h = await api.recordHistory('application', '1');
    expect(h.any((e) => wfDescribeHistory(e, (k) => '$k').contains('(“Missing transcript”)')), isTrue);
  });

  test('the reset list has a token: a reset with an older one is refused as changed', () async {
    final api = DemoWorkflowApi();
    final preview = await api.resetPreview('application', '1');
    expect(preview.token, isNotNull);
    expect(preview.items.where((i) => i.kind == 'move').single.undoable, isFalse);
    await expectLater(api.resetRecord('application', '1', token: 'tk-old'), throwsA(isA<UiWfApiError>().having((e) => e.code, 'code', 'resetChanged')));
    await api.resetRecord('application', '1', undo: ['field:programme:p1:budget'], token: preview.token);
    expect(api.budget, 50000);
  });

  test('another lifecycle\'s records are refused as wrongLifecycle', () async {
    final api = DemoWorkflowApi();
    await expectLater(api.applyTransition('visa', '1', 'approve'), throwsA(isA<UiWfApiError>().having((e) => e.code, 'code', 'wrongLifecycle')));
  });

  test('saving permissions says what it did', () async {
    final api = DemoWorkflowApi();
    final def = (await api.definition('wf_status')).published!;
    final submit = def.lifecycle!.transitions.first;
    final same = await api.updatePermissions('wf_status', [(node: submit.id, who: submit.who!)]);
    expect(same.changed, isFalse);
    expect(same.version, 1);
    final saved = await api.updatePermissions('wf_status', [(node: submit.id, who: [UiWfAssignee.role('reviewer')])]);
    expect((saved.changed, saved.version, saved.recordsMoved), (true, 2, 3));
    expect(saved.draftSkipped, isEmpty);
    api.actingAs = 'ali';
    await expectLater(api.updatePermissions('wf_status', const []), throwsA(isA<UiWfApiError>().having((e) => e.status, 'status', 403)));
  });

  test('the demo bank: while it is down the payment fails, is tried again on the clock, and stops after the fourth attempt', () async {
    final api = DemoWorkflowApi()..bankDown = true;
    api.actingAs = 'mariyam';
    await api.decide('t1', 'approved');
    var run = await api.instance('run1');
    expect(run.status, 'waiting', reason: 'the first attempt failed; another is scheduled');
    for (var i = 0; i < 3; i++) {
      api.advance(const Duration(minutes: 5));
    }
    run = await api.instance('run1');
    expect(run.status, 'incident');
    expect(run.error, 'InvalidOperationException: Bank API: 503 Service Unavailable');
    expect(run.steps!.last.attempt, 4);
    // Stopped runs are listed for the drawer and on the record.
    expect((await api.instances(const UiWfInstanceQuery(status: ['incident']))).items.single.id, 'run1');
    expect((await api.record('application', '1')).instances.single.status, 'incident');
    // Only admins put it right; tried again while the bank is still down, it stops again.
    await expectLater(api.retry('run1'), throwsA(isA<UiWfApiError>()));
    api.actingAs = 'hana';
    expect((await api.retry('run1')).status, 'incident');
    api.bankDown = false;
    expect((await api.retry('run1')).status, 'completed');
  });

  test('skipping the payment gives its results; cancelling stops the run', () async {
    final api = DemoWorkflowApi()..bankDown = true;
    api.actingAs = 'mariyam';
    await api.decide('t1', 'approved');
    for (var i = 0; i < 3; i++) {
      api.advance(const Duration(minutes: 5));
    }
    api.actingAs = 'hana';
    final skipped = await api.skip('run1', outputs: {'invoiceNo': 'INV-9'});
    expect(skipped.status, 'completed');
    expect(skipped.steps!.last.status, 'skipped');
    final cancelled = await api.cancel('run1', reason: 'Withdrawn');
    expect(cancelled.status, 'cancelled');
  });
}
