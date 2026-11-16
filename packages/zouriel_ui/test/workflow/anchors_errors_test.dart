import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zouriel_ui/src/workflow/runtime.dart' show WfRunView, WfTaskInbox;
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fake_api.dart';

/// 0.87.0: tour anchors on the workflow panel and tasks drawer (with revealers for closed drawers),
/// and the plain "unavailable" text with a closed "Technical details" disclosure.

const _unavailable = "Workflows aren't available right now. Try again later.";
const _laravel404 = '{"message":"The route api/workflows/records/application/1 could not be found."}';
const _html404 = '<!DOCTYPE html><html><head><title>Not Found</title><style>body{color:red}</style></head><body><h1>404   Not Found</h1>\n<p>nginx</p></body></html>';

FakeWorkflowApi _api() => FakeWorkflowApi()..recordJson['reset'] = {'label': 'Start over', 'to': 'draft', 'toLabel': 'Draft', 'confirm': null, 'form': null};

Future<void> _pumpPanel(WidgetTester tester, UiWorkflowApi api, UiWorkflowPanelLayout layout, {String? prefix, UiStrings strings = const UiStrings()}) async {
  tester.view.physicalSize = const Size(900, 1000) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(
    // No animations: the tour's breathing ring would keep pumpAndSettle busy.
    config: UiConfig(strings: strings, animations: false),
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 900,
        height: 1000,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: layout, anchorPrefix: prefix),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _pumpDrawer(WidgetTester tester, UiWorkflowTasksDrawer drawer) async {
  tester.view.physicalSize = const Size(900, 900) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(config: const UiConfig(animations: false), home: Center(child: drawer)));
  await tester.pumpAndSettle();
}

UiWorkflowHttpApi _http(http.Response Function(http.Request r) reply) =>
    UiWorkflowHttpApi(baseUrl: 'https://app.example/api/workflows', client: MockClient((r) async => reply(r)));

/// A fake with one stopped workflow (listed for people who may intervene).
class _WithStopped extends FakeWorkflowApi {
  _WithStopped() {
    canIntervene = true;
  }

  @override
  Future<UiWfPage<UiWfInstance>> instances(UiWfInstanceQuery q) async => UiWfPage([UiWfInstance.fromJson(instanceJson)], 1);
}

const _inPanel = ['p.move.approve', 'p.move.withdraw', 'p.manual.escalate', 'p.reset', 'p.task-entry'];

void main() {
  // A tour left running by a failed test must not reach into the next one.
  tearDown(UiTour.stop);

  group('anchors', () {
    for (final layout in [UiWorkflowPanelLayout.vertical, UiWorkflowPanelLayout.horizontal, UiWorkflowPanelLayout.compact]) {
      testWidgets('the ${layout.name} panel marks its moves, manual starts, reset and tasks', (tester) async {
        await _pumpPanel(tester, _api(), layout, prefix: 'p');
        for (final id in _inPanel) {
          expect(UiTour.hasAnchor(id), isTrue, reason: id);
        }
        expect(UiTour.hasAnchor('p.open'), isFalse, reason: 'no rail outside the drawer layouts');
      });
    }

    testWidgets('without a prefix there are no anchors', (tester) async {
      await _pumpPanel(tester, _api(), UiWorkflowPanelLayout.vertical);
      expect(find.byType(UiTourAnchor), findsNothing);
      expect(find.text('Approve'), findsWidgets, reason: 'the controls are there all the same');
    });

    testWidgets('the confirmation and the decision dialogs mark their main buttons', (tester) async {
      await _pumpPanel(tester, _api(), UiWorkflowPanelLayout.vertical, prefix: 'p');
      await tester.tap(find.widgetWithText(UiButton, 'Approve').first);
      await tester.pumpAndSettle();
      expect(UiTour.hasAnchor('p.confirm'), isTrue);
      await tester.tap(find.widgetWithText(UiButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(UiTour.hasAnchor('p.confirm'), isFalse);
      await tester.tap(find.text('Finance sign-off'));
      await tester.pumpAndSettle();
      expect(UiTour.hasAnchor('p.task.approved'), isTrue);
      expect(UiTour.hasAnchor('p.task.rejected'), isTrue);
    });

    for (final layout in [UiWorkflowPanelLayout.sideDrawer, UiWorkflowPanelLayout.bottomDrawer]) {
      testWidgets('${layout.name}: the rail is p.open; a tour pointing at a move opens the drawer pinned and points at the button', (tester) async {
        await _pumpPanel(tester, _api(), layout, prefix: 'p');
        final panel = tester.state<UiWorkflowPanelState>(find.byType(UiWorkflowPanel));
        expect(UiTour.hasAnchor('p.open'), isTrue);
        expect(UiTour.hasAnchor('p.move.approve'), isFalse, reason: 'inside the closed drawer');
        expect(panel.isOpen, isFalse);

        final outcome = UiTour.start(tester.element(find.byType(UiWorkflowPanel)), const UiTourSpec('wf', [
          UiTourStep('p.open', 'The workflow lives here.'),
          UiTourStep('p.move.approve', 'Approve from here.'),
          UiTourStep('p.task.approved', 'A dialog: never opened for the person.'),
        ]));
        await tester.pumpAndSettle();
        expect(panel.isOpen, isTrue, reason: 'the revealer opened the drawer');
        expect(UiTour.active, 'wf');
        expect(find.text('1 of 2'), findsOneWidget, reason: 'the dialog step is left out');

        // Pinned: a pointer leaving the drawer does not close it (a hover-opened peek would close).
        tester.widget<UiDrawerPeek>(find.byType(UiDrawerPeek)).onPointerExit!();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(panel.isOpen, isTrue);
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('2 of 2'), findsOneWidget);
        final button = tester.getRect(find.widgetWithText(UiButton, 'Approve').last);
        expect(UiTour.debugHole!.contains(button.center), isTrue);
        expect(panel.isOpen, isTrue);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(await outcome, UiTourOutcome.finished);
      });
    }

    testWidgets('a drawer panel without a prefix reveals nothing: the tour has no step to show', (tester) async {
      await _pumpPanel(tester, _api(), UiWorkflowPanelLayout.sideDrawer);
      final panel = tester.state<UiWorkflowPanelState>(find.byType(UiWorkflowPanel));
      final outcome = UiTour.start(tester.element(find.byType(UiWorkflowPanel)), const UiTourSpec('wf', [UiTourStep('p.move.approve', 'Approve.')]));
      await tester.pumpAndSettle();
      expect(await outcome, UiTourOutcome.closed);
      expect(panel.isOpen, isFalse);
    });

    testWidgets('tasks drawer: its button is p.open; a tour pointing at a task opens it; each task is p.task-entry', (tester) async {
      final api = _WithStopped();
      await _pumpDrawer(tester, UiWorkflowTasksDrawer(api: api, anchorPrefix: 'p'));
      final drawer = tester.state<UiWorkflowTasksDrawerState>(find.byType(UiWorkflowTasksDrawer));
      expect(UiTour.hasAnchor('p.open'), isTrue);
      expect(UiTour.hasAnchor('p.task-entry'), isFalse);
      final outcome = UiTour.start(tester.element(find.byType(UiWorkflowTasksDrawer)), const UiTourSpec('tasks', [
        UiTourStep('p.task-entry', 'Your tasks.'),
        UiTourStep('p.stopped', 'Stopped workflows.'),
      ]));
      await tester.pumpAndSettle();
      expect(drawer.isOpen, isTrue);
      expect(UiTour.hasAnchor('p.task-entry'), isTrue);
      expect(UiTour.hasAnchor('p.stopped'), isTrue);
      expect(find.text('1 of 2'), findsOneWidget);
      UiTour.stop();
      expect(await outcome, UiTourOutcome.closed);
    });

    testWidgets('tasks drawer without a prefix: no anchors, the tour does not open it', (tester) async {
      await _pumpDrawer(tester, UiWorkflowTasksDrawer(api: FakeWorkflowApi()));
      final drawer = tester.state<UiWorkflowTasksDrawerState>(find.byType(UiWorkflowTasksDrawer));
      final outcome = UiTour.start(tester.element(find.byType(UiWorkflowTasksDrawer)), const UiTourSpec('tasks', [UiTourStep('p.task-entry', 'Your tasks.')]));
      await tester.pumpAndSettle();
      expect(await outcome, UiTourOutcome.closed);
      expect(drawer.isOpen, isFalse);
      expect(find.byType(UiTourAnchor), findsNothing);
    });
  });

  group('UiTour revealers', () {
    testWidgets('reveal asks only revealers whose prefix matches, and a remover takes one away', (tester) async {
      final asked = <String>[];
      final remove = UiTour.registerRevealer('x.', (id) {
        asked.add(id);
        return id == 'x.yes';
      });
      addTearDown(remove);
      expect(UiTour.reveal('x.yes'), isTrue);
      expect(UiTour.reveal('x.no'), isFalse);
      expect(UiTour.reveal('y.yes'), isFalse);
      expect(asked, ['x.yes', 'x.no']);
      remove();
      expect(UiTour.reveal('x.yes'), isFalse);
    });
  });

  group('error text', () {
    test('a 404 without an engine code is unreachable, with the method, path, status and message as detail', () async {
      final api = _http((_) => http.Response(_laravel404, 404, headers: {'content-type': 'application/json'}));
      final e = await api.record('application', '1').then<Object?>((_) => null, onError: (Object e) => e) as UiWfApiError;
      expect(e.code, 'unreachable');
      expect(e.status, 404);
      expect(e.message, _unavailable);
      expect(e.detail, 'GET /records/application/1: HTTP 404 - The route api/workflows/records/application/1 could not be found.');
      expect(wfErrorText(e, 'fallback'), _unavailable);
      expect(wfErrorText(e, 'fallback', UiStrings.dv), UiStrings.dv.workflowUnavailable);
      expect(wfErrorDetail(e), e.detail);
    });

    test('an HTML page becomes plain text in the detail; a network failure is status 0', () async {
      final html = await _http((_) => http.Response(_html404, 404)).me().then<Object?>((_) => null, onError: (Object e) => e) as UiWfApiError;
      expect(html.code, 'unreachable');
      expect(html.detail, 'GET /me: HTTP 404 - Not Found 404 Not Found nginx');
      final long = await _http((_) => http.Response('<p>${'x' * 400}</p>', 502)).me().then<Object?>((_) => null, onError: (Object e) => e) as UiWfApiError;
      expect(long.detail!.length, lessThan(340));
      expect(long.detail, endsWith('…'));
      final down = UiWorkflowHttpApi(baseUrl: 'https://app.example/w', client: MockClient((_) async => throw http.ClientException('Connection refused')));
      final net = await down.me().then<Object?>((_) => null, onError: (Object e) => e) as UiWfApiError;
      expect(net.status, 0);
      expect(net.code, 'unreachable');
      expect(net.detail, startsWith('GET /me: no answer - '));
      expect(net.detail, contains('Connection refused'));
    });

    test('engine refusals (a JSON code) and 401/403 keep their own message, with no detail', () async {
      for (final (status, body, code, message) in [
        (422, '{"code":"notAllowed","message":"You are not allowed to “Approve”."}', 'notAllowed', 'You are not allowed to “Approve”.'),
        (503, '{"code":"unavailable","message":"The engine is paused."}', 'unavailable', 'The engine is paused.'),
        (403, '<html>Forbidden</html>', 'http403', 'You are not allowed to do that.'),
        (401, '{"message":"Unauthenticated."}', 'http401', 'Unauthenticated.'),
        (400, '{"message":"Bad input."}', 'http400', 'Bad input.'),
      ]) {
        final e = await _http((_) => http.Response(body, status, headers: {'content-type': 'application/json; charset=utf-8'})).me().then<Object?>((_) => null, onError: (Object e) => e) as UiWfApiError;
        expect(e.code, code, reason: '$status');
        expect(e.message, message, reason: '$status');
        expect(e.detail, isNull, reason: '$status');
        expect(wfErrorText(e, 'fallback'), message, reason: '$status');
      }
    });

    for (final (name, body) in [('a Laravel 404', _laravel404), ('an HTML 404', _html404)]) {
      testWidgets('the panel says workflows are unavailable for $name, the detail only after opening the disclosure', (tester) async {
        await _pumpPanel(tester, _http((_) => http.Response(body, 404)), UiWorkflowPanelLayout.vertical);
        expect(find.text(_unavailable), findsOneWidget);
        expect(find.textContaining('could not be found'), findsNothing);
        expect(find.textContaining('nginx'), findsNothing);
        expect(find.textContaining('HTTP 404'), findsNothing);
        expect(find.text('Technical details'), findsOneWidget);
        await tester.tap(find.text('Technical details'));
        await tester.pumpAndSettle();
        expect(find.textContaining('GET /records/application/1: HTTP 404 - '), findsOneWidget);
        await tester.tap(find.text('Technical details'));
        await tester.pumpAndSettle();
        expect(find.textContaining('HTTP 404'), findsNothing);
      });
    }

    testWidgets('in Dhivehi the sentence and the disclosure follow the strings', (tester) async {
      await _pumpPanel(tester, _http((_) => http.Response(_laravel404, 404)), UiWorkflowPanelLayout.vertical, strings: UiStrings.dv);
      expect(find.text(UiStrings.dv.workflowUnavailable), findsOneWidget);
      expect(find.text(UiStrings.dv.technicalDetails), findsOneWidget);
      expect(find.text(_unavailable), findsNothing);
    });

    testWidgets('an engine refusal shows its own message, with no disclosure', (tester) async {
      final api = _api()..failNext = const UiWfApiError(422, 'notAllowed', 'You may not see this record.');
      await _pumpPanel(tester, api, UiWorkflowPanelLayout.vertical);
      expect(find.text('You may not see this record.'), findsOneWidget);
      expect(find.text('Technical details'), findsNothing);
    });

    final loaders = <String, Widget Function(UiWorkflowApi api)>{
      'task inbox': (api) => WfTaskInbox(api: api),
      'run view': (api) => WfRunView(api: api, instanceId: 'i1'),
      'audit log': (api) => UiWorkflowAudit(api: api),
      'permissions': (api) => UiWorkflowPermissions(api: api),
    };
    for (final MapEntry(key: name, value: build) in loaders.entries) {
      testWidgets('the $name says workflows are unavailable, with the detail behind the disclosure', (tester) async {
        await pumpUi(tester, SizedBox(width: 800, height: 900, child: SingleChildScrollView(child: build(_http((_) => http.Response(_html404, 404))))), size: const Size(800, 900));
        await tester.pumpAndSettle();
        expect(find.text(_unavailable), findsWidgets);
        expect(find.textContaining('nginx'), findsNothing);
        await tester.tap(find.text('Technical details').first);
        await tester.pumpAndSettle();
        expect(find.textContaining('nginx'), findsOneWidget);
      });
    }
  });
}
