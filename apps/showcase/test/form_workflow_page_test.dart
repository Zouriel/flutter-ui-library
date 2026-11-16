import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/docs/doc.dart';
import 'package:zouriel_ui_showcase/pages/form_workflow_page.dart';
import 'package:zouriel_ui_showcase/pages/registry.dart';

Finder button(String label) => find.byWidgetPredicate((w) => w is UiButton && w.label == label);

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 1600) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const UiApp(home: FormWorkflowPage()));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _submit(WidgetTester tester, int days, {String label = 'Submit'}) async {
  final engine = tester.state<UiFormRendererState>(find.byType(UiFormRenderer)).engine;
  engine.setValue('f_name', null, 'Aminath');
  engine.setValue('f_type', null, 'annual');
  engine.setValue('f_days', null, days);
  await tester.pump();
  await tester.tap(button(label));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('is registered next to the workflow pages and has its sections', (tester) async {
    expect(showcasePageById('form-workflow')?.label, 'Form → workflow');
    await _pump(tester);
    expect([for (final s in tester.widgetList<DocSection>(find.byType(DocSection))) s.name], ['Live example', 'Integrating it', 'Bridge API']);
    expect(find.text('Submit the form to see the payload, the picked workflow and the route.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _done(tester);
  });

  testWidgets('a long leave goes to the manager and the finance queue, a short one needs nobody', (tester) async {
    await _pump(tester);
    await _submit(tester, 5);
    expect(find.text('Leave approval'), findsWidgets);
    expect(find.text('Manager approval'), findsWidgets);
    expect(find.text('Queue: Finance queue'), findsOneWidget);
    expect(find.textContaining('"workflowId": "wf-leave"'), findsOneWidget);
    // The manager rejecting ends the route before the finance task.
    await tester.ensureVisible(find.text('Rejects'));
    await tester.pump();
    await tester.tap(find.text('Rejects'));
    await tester.pump();
    expect(find.text('No queue'), findsOneWidget);
    expect(find.text('Approval · rejected'), findsOneWidget);
    await _done(tester);
  });

  testWidgets('a short leave is auto-approved', (tester) async {
    await _pump(tester);
    await _submit(tester, 2);
    expect(find.text('No approval needed'), findsOneWidget);
    expect(find.text('No queue'), findsOneWidget);
    await _done(tester);
  });

  testWidgets('the language switcher shows the form in Dhivehi and the submission carries the locale', (tester) async {
    await _pump(tester);
    expect(find.text('Your name'), findsWidgets);
    await tester.tap(find.text('ދިވެހި'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ނަން'), findsWidgets);
    // The button's own word is Dhivehi now too (the form's language, not just its labels).
    await _submit(tester, 5, label: uiFbStringsDv.submit);
    expect(find.textContaining('"locale": "dv"'), findsOneWidget);
    await _done(tester);
  });
}
