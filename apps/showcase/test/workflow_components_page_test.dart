import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/docs/doc.dart';
import 'package:zouriel_ui_showcase/pages/registry.dart';
import 'package:zouriel_ui_showcase/pages/workflow_builder_page.dart';
import 'package:zouriel_ui_showcase/pages/workflow_components_page.dart';

Finder button(String label) => find.byWidgetPredicate((w) => w is UiButton && w.label == label);

Future<List<String>> _pump(WidgetTester tester, Widget page, {Size size = const Size(1280, 900)}) async {
  final opened = <String>[];
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(home: ShowcaseNav(go: opened.add, child: page)));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  return opened;
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('opens as the head of office on an application past Draft, with every component', (tester) async {
    await _pump(tester, const WorkflowComponentsPage());
    expect(find.text('Which component goes where'), findsOneWidget);
    expect(find.text('Hana Ibrahim · Head of office'), findsOneWidget);
    expect(find.text('Marine biology degree, Ali Rasheed (In review)'), findsOneWidget);
    expect(find.textContaining('Start over shows to the head of office once an application has moved on from Draft.'), findsOneWidget);
    final sections = [for (final s in tester.widgetList<DocSection>(find.byType(DocSection))) s.name];
    expect(sections, [
      'Workflow panel', 'My tasks drawer', 'Audit log', 'State badge', 'Permissions', 'Global settings',
      'Putting a settings page together',
    ]);
    // The head of office may start this application over.
    expect(button('Start over'), findsOneWidget);
    // Every tone of the state badge.
    for (final label in ['Draft', 'Submitted', 'In progress', 'Under review', 'Approved', 'Rejected']) {
      expect(find.descendant(of: find.byType(UiWorkflowStateBadge), matching: find.text(label)), findsWidgets);
    }
    expect(tester.takeException(), isNull);
    await _done(tester);
  });

  testWidgets('the picker drives every demo: the applicant sees no Start over and no audit log', (tester) async {
    await _pump(tester, const WorkflowComponentsPage());
    final you = tester.widget<UiSelect>(find.byWidgetPredicate((w) => w is UiSelect && w.label == 'You are'));
    you.onChanged!('ali');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(button('Start over'), findsNothing);
    expect(button('Withdraw'), findsWidgets);
    expect(find.text('Only admins can read the audit log.'), findsOneWidget);
    expect(find.text('You can see who may do what; changing it needs the right to publish workflows.'), findsOneWidget);
    await _done(tester);
  });

  testWidgets('"Which component goes where" jumps to each section', (tester) async {
    await _pump(tester, const WorkflowComponentsPage());
    final scroll = Scrollable.of(tester.element(find.text('Which component goes where'))).position;
    expect(scroll.pixels, 0);
    tester.widget<UiButton>(button('(put together)')).onPressed!();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    expect(scroll.pixels, greaterThan(0));
    expect(tester.getTopLeft(find.text('Putting a settings page together')).dy, lessThan(900));
    // Worded as on the web.
    expect(find.text('(in the app\'s header; everyone\'s tasks for admins)'), findsOneWidget);
    expect(button('global settings'), findsOneWidget);
    expect(find.text('See'), findsOneWidget);
    await _done(tester);
  });

  testWidgets('works on a phone', (tester) async {
    await _pump(tester, const WorkflowComponentsPage(), size: const Size(390, 844));
    expect(tester.takeException(), isNull);
    await _done(tester);
  });

  testWidgets('the builder page keeps the builder and links here; the old page id opens this page', (tester) async {
    final opened = await _pump(tester, const WorkflowBuilderPage());
    final sections = [for (final s in tester.widgetList<DocSection>(find.byType(DocSection))) s.name];
    expect(sections, isNot(contains('Record panel')));
    expect(sections, isNot(contains('Permissions')));
    tester.widget<UiButton>(button('Open Workflow components')).onPressed!();
    expect(opened, ['workflow-components']);
    expect(showcasePageById('workflow-panel')?.id, 'workflow-components');
    expect(showcasePageById('workflow-components')?.label, 'Workflow components');
    await _done(tester);
  });

  testWidgets('the panel demo offers the compact layout (what the record panel was)', (tester) async {
    await _pump(tester, const WorkflowComponentsPage());
    final picker = tester.widget<UiSegmented<UiWorkflowPanelLayout>>(find.byWidgetPredicate((w) => w is UiSegmented<UiWorkflowPanelLayout>));
    expect([for (final o in picker.options) o.label], ['Vertical', 'Horizontal', 'Compact', 'Side drawer', 'Bottom drawer']);
    picker.onChanged!(UiWorkflowPanelLayout.compact);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<UiWorkflowPanel>(find.byType(UiWorkflowPanel)).layout, UiWorkflowPanelLayout.compact);
    expect(find.byKey(const ValueKey('wf-track')), findsOneWidget);
    expect(button('Start over'), findsOneWidget);
    await _done(tester);
  });

  testWidgets('Show a stopped payment: the payment fails while the bank is down, and the panel shows it under Stopped', (tester) async {
    await _pump(tester, const WorkflowComponentsPage());
    tester.widget<UiSegmented<UiWorkflowPanelLayout>>(find.byWidgetPredicate((w) => w is UiSegmented<UiWorkflowPanelLayout>)).onChanged!(UiWorkflowPanelLayout.compact);
    await tester.pump(const Duration(seconds: 1));
    tester.widget<UiButton>(button('Show a stopped payment')).onPressed!();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('STOPPED'), findsOneWidget); // every listed run stopped
    expect(find.text('Bank API: 503 Service Unavailable'), findsWidgets);
    // The head of office may put it right: the bank is back up, so trying again pays.
    final again = button('Try again');
    expect(again, findsOneWidget);
    tester.widget<UiButton>(again).onPressed!();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('Bank API: 503 Service Unavailable'), findsNothing);
    expect(tester.widget<UiButton>(button('Show a stopped payment')).onPressed, isNull, reason: 'the sign-off was decided');
    await _done(tester);
  });

  testWidgets('the stopped-payment note says what became of the picked application\'s finance check', (tester) async {
    await _pump(tester, const WorkflowComponentsPage());
    expect(find.textContaining('Has finance sign this application off'), findsOneWidget);
    tester.widget<UiSelect>(find.byWidgetPredicate((w) => w is UiSelect && w.label == 'Application')).onChanged!('3');
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('No finance check runs for this application'), findsOneWidget);
    expect(tester.widget<UiButton>(button('Show a stopped payment')).onPressed, isNull);
    await _done(tester);
  });

  testWidgets('Send another application for review gives finance a new sign-off', (tester) async {
    await _pump(tester, const WorkflowComponentsPage());
    tester.widget<UiButton>(button('Send another application for review')).onPressed!();
    await tester.pump(const Duration(seconds: 1));
    final apps = tester.widget<UiSelect>(find.byWidgetPredicate((w) => w is UiSelect && w.label == 'Application'));
    expect([for (final o in apps.options) o.label], contains('Nursing diploma, Ali Rasheed (In review)'));
    tester.widget<UiButton>(button('Send another application for review')).onPressed!();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Every other application is past Draft'), findsOneWidget);
    await _done(tester);
  });

  testWidgets('the API tables list what the widgets take; no page speaks of the internal inbox or run view', (tester) async {
    await _pump(tester, const WorkflowBuilderPage());
    final builderRows = [for (final d in tester.widgetList<DocSection>(find.byType(DocSection))) for (final r in [...d.api, ...d.callbacks]) r.name];
    expect(builderRows, containsAll(['readOnly', 'onDirtyChanged']));
    expect(find.textContaining('inbox'), findsNothing);
    await _done(tester);
    await _pump(tester, const WorkflowComponentsPage());
    final rows = [for (final d in tester.widgetList<DocSection>(find.byType(DocSection))) for (final r in [...d.api, ...d.callbacks]) r.name];
    expect(rows, containsAll(['open', 'onOpenChanged']));
    expect(find.textContaining('inbox'), findsNothing);
    expect(find.textContaining('run view'), findsNothing);
    await _done(tester);
  });

  for (final w in [360.0, 320.0]) {
    testWidgets('both workflow pages fit a ${w.toInt()}px phone (the holidays row used to overflow)', (tester) async {
      await _pump(tester, const WorkflowComponentsPage(), size: Size(w, 760));
      // Down to the global settings, where the holidays are.
      await tester.scrollUntilVisible(find.text('Holidays').first, 400, scrollable: find.byType(Scrollable).first);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await _done(tester);
      await _pump(tester, const WorkflowBuilderPage(), size: Size(w, 760));
      expect(tester.takeException(), isNull);
      await _done(tester);
    });
  }
}
