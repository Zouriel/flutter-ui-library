import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fake_api.dart';

// Port of @zouriel/ui 1fd2132: the reset list's token, "move" items, and the engine's new refusals,
// which read through the usual error text.

Finder button(String label) => find.byWidgetPredicate((w) => w is UiButton && w.label == label);

Map<String, Object?> _item(String id, String title, {String kind = 'field', bool undoable = true, String? warning}) =>
    {'id': id, 'kind': kind, 'title': title, 'detail': null, 'workflow': 'W', 'step': 'S', 'undoable': undoable, 'selected': undoable, 'warning': warning};

Future<FakeWorkflowApi> _pump(WidgetTester tester, {List<Map<String, Object?>>? items, String? token}) async {
  final api = FakeWorkflowApi();
  api.recordJson['reset'] = {'label': 'Start over', 'to': 'draft', 'toLabel': 'Draft', 'confirm': null, 'form': null};
  api.resetItems = items ?? [_item('created:document:d9', 'Delete Document “Checklist”')];
  api.resetToken = token;
  await pumpUi(tester, SizedBox(width: 420, height: 900, child: SingleChildScrollView(child: UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.compact))), size: const Size(420, 900));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  test('the HTTP client sends the token back, and leaves it out without one', () async {
    final seen = <http.Request>[];
    final api = UiWorkflowHttpApi(baseUrl: 'https://app.example/wf', client: MockClient((r) async {
      seen.add(r);
      return http.Response(r.method == 'GET' ? '{"reset":{"label":"Start over"},"items":[],"token":"tk1"}' : '{"id":"1"}', 200);
    }));
    expect((await api.resetPreview('application', '1')).token, 'tk1');
    await api.resetRecord('application', '1', token: 'tk1');
    await api.resetRecord('application', '1');
    expect(jsonDecode(seen[1].body), {'input': <String, Object?>{}, 'token': 'tk1'});
    expect(jsonDecode(seen[2].body), {'input': <String, Object?>{}});
    expect(UiWfResetPreview.fromJson({'items': <Object?>[]}).token, isNull);
  });

  testWidgets('the list\'s token goes back with the reset', (tester) async {
    final api = await _pump(tester, token: 'tk1');
    await tester.tap(button('Start over'));
    await tester.pumpAndSettle();
    await tester.tap(button('Start over').last);
    await tester.pumpAndSettle();
    expect(api.lastResetUndo, ['created:document:d9']);
    expect(api.lastResetToken, 'tk1');
  });

  testWidgets('after resetChanged the new list\'s token is the one sent', (tester) async {
    final api = await _pump(tester, token: 'tk1');
    api.resetFailures.add(const UiWfApiError(409, 'resetChanged', 'What the workflow did has changed.'));
    await tester.tap(button('Start over'));
    await tester.pumpAndSettle();
    api.resetToken = 'tk2';
    await tester.tap(button('Start over').last);
    await tester.pumpAndSettle();
    expect(api.lastResetToken, 'tk1');
    expect(find.text('What the workflow did has changed.'), findsOneWidget);
    await tester.tap(button('Start over').last);
    await tester.pumpAndSettle();
    expect(api.lastResetToken, 'tk2');
  });

  testWidgets('no token is sent while the list is read again, nor from an older engine', (tester) async {
    final api = await _pump(tester);
    await tester.tap(button('Start over'));
    await tester.pumpAndSettle();
    await tester.tap(button('Start over').last);
    await tester.pumpAndSettle();
    expect(api.lastResetToken, isNull);
  });

  testWidgets('a record the workflow moved is listed as a Move, locked, with its warning', (tester) async {
    await _pump(tester, items: [
      _item('move:application:7', 'Application “Visa”: back to Submitted', kind: 'move', undoable: false, warning: 'Moves can’t be taken back here; start that record over instead.'),
    ]);
    await tester.tap(button('Start over'));
    await tester.pumpAndSettle();
    expect(find.text('Move'), findsOneWidget);
    final box = tester.widget<UiCheckbox>(find.ancestor(of: find.text('Application “Visa”: back to Submitted'), matching: find.byType(UiCheckbox)));
    expect(box.value, isFalse);
    expect(box.onChanged, isNull);
    expect(find.textContaining('Moves can’t be taken back here'), findsOneWidget);
  });

  group('the engine\'s refusals read through the usual error text', () {
    testWidgets('remarks the engine requires on a move (commentRequired)', (tester) async {
      final api = await _pump(tester);
      api.failNext = const UiWfApiError(400, 'commentRequired', 'Add remarks to make this move.');
      await tester.tap(button('Withdraw'));
      await tester.pumpAndSettle();
      expect(find.text('Add remarks to make this move.'), findsOneWidget);
    });

    testWidgets('a move from another lifecycle (wrongLifecycle)', (tester) async {
      final api = await _pump(tester);
      api.failNext = const UiWfApiError(409, 'wrongLifecycle', 'This application follows another lifecycle now; reload it.');
      await tester.tap(button('Withdraw'));
      await tester.pumpAndSettle();
      expect(find.text('This application follows another lifecycle now; reload it.'), findsOneWidget);
    });

    testWidgets('a reset outside the states it is offered in (notAllowed), shown in the dialog', (tester) async {
      final api = await _pump(tester);
      api.resetFailures.add(const UiWfApiError(403, 'notAllowed', 'Starting over isn’t offered in this state.'));
      await tester.tap(button('Start over'));
      await tester.pumpAndSettle();
      await tester.tap(button('Start over').last);
      await tester.pumpAndSettle();
      expect(find.text('Starting over isn’t offered in this state.'), findsOneWidget);
    });

    testWidgets('a list refused because no reset is offered: the dialog says it couldn\'t be listed', (tester) async {
      final api = await _pump(tester);
      api.failNext = const UiWfApiError(403, 'notAllowed', 'Starting over isn’t offered here.');
      await tester.tap(button('Start over'));
      await tester.pumpAndSettle();
      expect(find.text("What the workflow did couldn't be listed, so the reset will leave it as it is."), findsOneWidget);
    });
  });
}
