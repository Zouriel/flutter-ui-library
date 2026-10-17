import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

const _full = '''
{
  "specVersion": 1, "id": "wf_1", "key": "review", "kind": "automation", "title": "Review", "entity": "application",
  "futureTopLevel": {"kept": true},
  "trigger": {"type": "fieldChanged", "field": "status", "to": ["Submitted"], "when": {"match": "all", "conditions": [{"ref": "entity.amount", "op": "gt", "value": {"const": 5000}}]}},
  "variables": [{"id": "v1", "key": "tries", "label": "Tries", "type": "number", "default": 0}],
  "settings": {"concurrency": "parallel", "owners": [{"role": "admin"}], "somethingNew": 1},
  "steps": [
    {"id": "s1", "type": "approval", "title": "Finance", "assignees": [{"role": "finance"}, {"managerOf": "initiator"}], "rule": {"type": "count", "value": 2},
     "due": "P3D", "reminders": ["P1D"], "escalation": {"after": "P2D", "assignees": [{"managerOf": "assignees"}]},
     "instructions": ["Check ", {"ref": "entity.title"}], "unknownStepKey": [1, 2, 3],
     "outcomes": {"approved": [{"id": "s2", "type": "notify", "channel": "email", "to": [{"email": "a@b.co"}], "body": "Approved"}], "rejected": [], "timedOut": []}},
    {"id": "s3", "type": "wait", "until": {"type": "signal", "signal": "paid", "timeout": "P7D", "onTimeout": {"id": "l1", "steps": []}}},
    {"id": "s4", "type": "webhook", "method": "PUT", "url": "https://x.example", "body": {"a": {"ref": "entity.id"}}, "onError": {"steps": []}},
    {"id": "s5", "type": "setFields", "values": [{"field": "status", "value": {"today": -2}}]}
  ]
}''';

void main() {
  group('definition JSON', () {
    test('round-trips exactly, unknown keys and all', () {
      final raw = jsonDecode(_full);
      final def = UiWorkflowDefinition.fromJson(raw);
      expect(jsonEncode(def.toJson()), jsonEncode(jsonDecode(_full)));
      // An edit keeps every key it didn't touch.
      final edited = updateStep(def, 's1', (s) => s.patch({'title': 'Finance sign-off'}));
      final j = jsonDecode(jsonEncode(edited.toJson())) as Map;
      expect(j['futureTopLevel'], {'kept': true});
      expect(((j['steps'] as List)[0] as Map)['unknownStepKey'], [1, 2, 3]);
      expect(((j['steps'] as List)[0] as Map)['title'], 'Finance sign-off');
      // The original is untouched.
      expect(def.steps![0].title, 'Finance');
    });

    test('typed views read every step type', () {
      final def = UiWorkflowDefinition.fromJson(jsonDecode(_full));
      final a = UiWfApprovalStep.of(def.steps![0]);
      expect(a.ruleType, 'count');
      expect(a.ruleValue, 2);
      expect(a.assignees.map((x) => x.kind), ['role', 'managerOf']);
      expect(a.escalation!.assignees.single.value, 'assignees');
      expect(templateText(a.instructions), 'Check [entity.title]');
      expect(a.outcome('approved').single.type, 'notify');
      expect(UiWfNotifyStep.of(a.outcome('approved').single).to.single.email!.json, 'a@b.co');
      final w = UiWfWaitStep.of(def.steps![1]).until;
      expect([w.type, w.signal, w.timeout, w.onTimeout!.id], ['signal', 'paid', 'P7D', 'l1']);
      expect(stepSlots(def.steps![1]).single.slot, 'onTimeout');
      expect(stepSlots(def.steps![2]).single.slot, 'error');
      expect(UiWfSetFieldsStep.of(def.steps![3]).values.single.value!.today, -2);
      final cond = def.trigger!.when!;
      expect(cond.isGroup, isTrue);
      expect(cond.conditions.single.op, 'gt');
      expect(cond.conditions.single.value!.constValue, 5000);
      expect(def.variables!.single.defaultValue, 0);
      expect(def.settings!.owners!.single.value, 'admin');
    });

    test('clone shares nothing', () {
      final def = UiWorkflowDefinition.fromJson(jsonDecode(_full));
      final c = def.clone();
      expect(jsonEncode(c.json), jsonEncode(def.json));
      expect(identical(c.json['steps'], def.json['steps']), isFalse);
    });
  });

  group('UiWorkflowHttpApi', () {
    late List<http.Request> seen;
    UiWorkflowHttpApi api(http.Response Function(http.Request r) reply) {
      seen = [];
      return UiWorkflowHttpApi(
        baseUrl: 'https://app.example/api/workflows/',
        headers: () async => {'Authorization': 'Bearer t'},
        client: MockClient((r) async {
          seen.add(r);
          return reply(r);
        }),
      );
    }

    test('calls the same endpoints with JSON bodies and the extra headers', () async {
      final a = api((r) => http.Response('{"id":"t1","outcomes":[],"decisions":[]}', 200));
      await a.decide('t/1', 'approved', comment: 'ok');
      final r = seen.single;
      expect(r.method, 'POST');
      expect(r.url.toString(), 'https://app.example/api/workflows/tasks/t%2F1/decide');
      expect(r.headers['Authorization'], 'Bearer t');
      expect(r.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(r.body), {'outcome': 'approved', 'comment': 'ok', 'data': null});
    });

    test('query strings skip empty values and join lists', () async {
      final a = api((r) => http.Response('{"items":[{"id":"t1"}],"total":7}', 200));
      final page = await a.tasks(const UiWfTaskQuery(scope: 'mine', status: ['completed', 'timedOut'], take: 25));
      expect(seen.single.url.toString(), 'https://app.example/api/workflows/tasks?scope=mine&status=completed%2CtimedOut&take=25');
      expect(page.total, 7);
      expect(page.items.single.id, 't1');
    });

    test('retry and skip can target one stopped path', () async {
      final a = api((r) => http.Response('{"id":"i1"}', 200));
      await a.retry('i1', target: 'tok2');
      await a.skip('i1', target: 'tok3');
      await a.retry('i1');
      expect(jsonDecode(seen[0].body), {'target': 'tok2'});
      expect(jsonDecode(seen[1].body), {'outputs': null, 'target': 'tok3'});
      expect(jsonDecode(seen[2].body), {'target': null});
    });

    test('bodiless posts send no content type; manual starts pick the record route', () async {
      final a = api((r) => http.Response('{}', 200));
      await a.archive('d1');
      expect(seen.single.headers.containsKey('Content-Type'), isFalse);
      await a.startManual('escalate', 'application', '9');
      await a.startManual('escalate', null, null);
      expect(seen[1].url.path, '/api/workflows/records/application/9/manual/escalate');
      expect(seen[2].url.path, '/api/workflows/manual/escalate');
    });

    test('refusals become UiWfApiError with the server message, or a fallback', () async {
      final a = api((r) => r.url.path.endsWith('/x')
          ? http.Response.bytes(utf8.encode('{"code":"notAllowed","message":"You are not allowed to “Approve”."}'), 403, headers: {'content-type': 'application/json; charset=utf-8'})
          : http.Response('', 403));
      await expectLater(a.record('x', 'x'), throwsA(isA<UiWfApiError>().having((e) => e.message, 'message', 'You are not allowed to “Approve”.').having((e) => e.code, 'code', 'notAllowed')));
      await expectLater(a.task('y'), throwsA(isA<UiWfApiError>().having((e) => e.message, 'message', 'You are not allowed to do that.').having((e) => e.code, 'code', 'http403')));
    });

    test('me reads GET /me', () async {
      final a = api((r) => http.Response('{"type":"user","id":"hana","name":"Hana","roles":["admin"],"can":{"edit":true,"publish":false}}', 200));
      final me = await a.me();
      expect(seen.single.url.path, '/api/workflows/me');
      expect([me.id, me.canEdit, me.canPublish, me.roles], ['hana', true, false, ['admin']]);
    });

    test('a missing user is null; 204 is fine', () async {
      final a = api((r) => r.method == 'DELETE' ? http.Response('', 204) : http.Response('{}', 404));
      expect(await a.user('nobody'), isNull);
      await a.deleteDefinition('d1');
    });

    test('audit export url and bytes', () async {
      final a = api((r) => http.Response('seq,at\n1,now', 200));
      const q = UiWfAuditQuery(category: 'task', format: 'csv');
      expect(a.auditExportUrl(q), 'https://app.example/api/workflows/audit/export?category=task&format=csv');
      expect(utf8.decode(await a.exportAudit(q)), 'seq,at\n1,now');
    });
  });
}
