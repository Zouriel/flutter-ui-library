import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/docs/doc.dart';
import 'package:zouriel_ui_showcase/pages/form_builder_page.dart';
import 'package:zouriel_ui_showcase/pages/registry.dart';
import 'package:zouriel_ui_showcase/pages/workflow_components_page.dart';

/// 0.87.0 showcase: the panel's tour, the unavailable engine, and the renderer's prefill and server errors.

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1280, 9000) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(config: const UiConfig(animations: false), home: ShowcaseNav(go: (_) {}, child: page)));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _done(WidgetTester tester) async {
  UiTour.stop();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('workflow components: the panel tour points at its controls; the unavailable engine hides its detail', (tester) async {
    await _pump(tester, const WorkflowComponentsPage());
    expect(UiTour.hasAnchor('wfDemo.reset'), isTrue);
    await tester.tap(find.widgetWithText(UiButton, 'Take the tour'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(UiTour.active, 'showcase.workflow-panel');
    UiTour.stop();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text("Workflows aren't available right now. Try again later."), findsOneWidget);
    expect(find.textContaining('could not be found'), findsNothing);
    await tester.tap(find.text('Technical details'));
    await tester.pump();
    expect(find.text('GET /records/application/1: HTTP 404 - The route api/workflows/records/application/1 could not be found.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _done(tester);
  });

  testWidgets('form builder: the prefilled form shows the answers; the server answer marks the field and lists the rest', (tester) async {
    await _pump(tester, const FormBuilderPage());
    final demo = find.byWidgetPredicate((w) => w is DocSection && w.name == 'Starting answers and server errors');
    expect(demo, findsOneWidget);
    final form = find.descendant(of: demo, matching: find.byType(UiFormRenderer));
    expect(find.descendant(of: form, matching: find.text('Aisha Ali')), findsOneWidget);
    expect(find.descendant(of: form, matching: find.widgetWithText(UiButton, 'Submit')), findsOneWidget);
    await tester.tap(find.widgetWithText(UiButton, 'Answer as the server would'));
    await tester.pump();
    await tester.pump();
    expect(find.descendant(of: form, matching: find.text('Use the name on your ID card.')), findsNWidgets(2));
    expect(find.descendant(of: form, matching: find.text('Applications close at 2 pm today.')), findsOneWidget);
    expect(find.text('Named no question: office_note'), findsOneWidget);
    await tester.tap(find.widgetWithText(UiButton, 'Clear'));
    await tester.pump();
    expect(find.text('Applications close at 2 pm today.'), findsNothing);
    expect(tester.takeException(), isNull);
    await _done(tester);
  });
}
