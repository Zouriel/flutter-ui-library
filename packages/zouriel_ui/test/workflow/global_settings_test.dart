import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fake_api.dart';

Finder button(String label) => find.byWidgetPredicate((w) => w is UiButton && w.label == label);

Future<GlobalKey<UiWorkflowGlobalSettingsState>> pumpSettings(WidgetTester tester, Widget Function(GlobalKey<UiWorkflowGlobalSettingsState> key) build, {Size size = const Size(900, 760)}) async {
  final key = GlobalKey<UiWorkflowGlobalSettingsState>();
  await pumpUi(tester, SizedBox(width: size.width, height: size.height, child: build(key)), size: size);
  return key;
}

void main() {
  testWidgets('loads through the API and saves with its revision', (tester) async {
    final api = FakeWorkflowApi();
    UiWorkflowSettings? saved;
    final key = await pumpSettings(tester, (k) => UiWorkflowGlobalSettings(key: k, api: api, onSettingsChanged: (s) => saved = s));
    expect(api.calls, containsAll(['settings', 'schema', 'triggers']));
    expect(tester.widget<UiButton>(button('Save settings')).onPressed, isNull);
    // Saturday becomes a working day.
    await tester.tap(find.text('Sat'));
    await tester.pump();
    expect(key.currentState!.dirty, isTrue);
    expect(key.currentState!.value.workDays, ['mon', 'tue', 'wed', 'thu', 'fri', 'sat']);
    await tester.tap(button('Save settings'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('saveSettings:3'));
    expect(saved?.workDays, contains('sat'));
    expect(find.text('Saved.'), findsOneWidget);
    expect(key.currentState!.dirty, isFalse);
    // The next save sends the new revision.
    await tester.tap(find.text('Mon'));
    await tester.pump();
    await tester.tap(button('Save settings'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('saveSettings:4'));
  });

  testWidgets('discard goes back to what was saved', (tester) async {
    final api = FakeWorkflowApi();
    final key = await pumpSettings(tester, (k) => UiWorkflowGlobalSettings(key: k, api: api));
    await tester.tap(find.text('Sun'));
    await tester.pump();
    expect(key.currentState!.dirty, isTrue);
    await tester.tap(button('Discard'));
    await tester.pump();
    expect(key.currentState!.dirty, isFalse);
    expect(key.currentState!.value.workDays, isNot(contains('sun')));
  });

  testWidgets('webhook addresses must be an origin; connections get keys from their names', (tester) async {
    final key = await pumpSettings(tester, (k) => UiWorkflowGlobalSettings(key: k, settings: UiWorkflowSettings(), registry: FakeWorkflowApi().registry));
    await tester.tap(find.text('Webhooks'));
    await tester.pumpAndSettle();
    final address = find.bySemanticsLabel('Address');
    await tester.enterText(find.descendant(of: find.byType(UiInput).first, matching: find.byType(EditableText)), 'https://hooks.example.com/path');
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('Enter an address like https://hooks.example.com (no path).'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(UiInput).first, matching: find.byType(EditableText)), 'https://hooks.example.com/');
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(key.currentState!.value.allowedOrigins, ['https://hooks.example.com']);
    expect(address, findsWidgets);
    await tester.tap(find.text('Add a connection'));
    await tester.pump();
    expect(key.currentState!.value.connections.single.key, 'connection1');
    await tester.enterText(find.descendant(of: find.byType(UiInput).at(1), matching: find.byType(EditableText)), 'ERP live');
    await tester.pump();
    expect(key.currentState!.value.connections.single.key, 'erpLive');
  });

  testWidgets('without an API, saving hands the settings back', (tester) async {
    UiWorkflowSettings? saved;
    await pumpSettings(tester, (k) => UiWorkflowGlobalSettings(key: k, settings: UiWorkflowSettings.fromJson({'version': 1, 'timeZone': 'Indian/Maldives'}), onSettingsChanged: (s) => saved = s));
    await tester.tap(find.text('Defaults'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('People may hand tasks to someone else'));
    await tester.pump();
    await tester.tap(button('Save settings'));
    await tester.pump();
    expect(saved?.people?['delegation'], isTrue);
    expect(saved?.timeZone, 'Indian/Maldives');
  });

  testWidgets('pausing a record type saves at once; conflicting triggers are flagged', (tester) async {
    final api = FakeWorkflowApi()
      ..triggerList = [
        UiWfTriggerOverview.fromJson({'definitionId': 'a', 'title': 'Remind', 'kind': 'automation', 'type': 'fieldChanged', 'entity': 'application', 'field': 'status', 'summary': 'When Status changes'}),
        UiWfTriggerOverview.fromJson({'definitionId': 'b', 'title': 'Escalate', 'kind': 'automation', 'type': 'fieldChanged', 'entity': 'application', 'field': 'status', 'summary': 'When Status changes'}),
      ];
    final key = await pumpSettings(tester, (k) => UiWorkflowGlobalSettings(key: k, api: api));
    await tester.tap(find.text('Watching'));
    await tester.pumpAndSettle();
    expect(find.text('Two workflows start on the same change here. Check they don’t work against each other.'), findsOneWidget);
    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();
    expect(key.currentState!.value.paused, ['application']);
    expect(api.calls, contains('saveSettings:3'));
    expect(find.text('Paused'), findsOneWidget); // the switch says what it is now
    expect(find.bySemanticsLabel(RegExp('Pause workflows for Application')), findsOneWidget);
  });

  testWidgets('pausing saves only the pause; other edits stay unsaved', (tester) async {
    final api = FakeWorkflowApi()
      ..triggerList = [
        UiWfTriggerOverview.fromJson({'definitionId': 'a', 'title': 'Remind', 'kind': 'automation', 'type': 'fieldChanged', 'entity': 'application', 'field': 'status', 'summary': 'When Status changes'}),
      ];
    final key = await pumpSettings(tester, (k) => UiWorkflowGlobalSettings(key: k, api: api));
    await tester.tap(find.text('Sat'));
    await tester.pump();
    await tester.tap(find.text('Watching'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();
    // The engine got the pause on top of what was saved, without Saturday.
    expect(api.settingsValue.paused, ['application']);
    expect(api.settingsValue.workDays, isNot(contains('sat')));
    // The page keeps both, and still has Saturday to save.
    expect(key.currentState!.value.paused, ['application']);
    expect(key.currentState!.value.workDays, contains('sat'));
    expect(key.currentState!.dirty, isTrue);
    expect(find.text('Paused. Your other changes are not saved yet.'), findsOneWidget);
  });

  testWidgets('time zones start with UTC and keep a saved zone the list lacks; retention reads as words', (tester) async {
    final api = FakeWorkflowApi()..settingsValue = UiWorkflowSettings.fromJson({'version': 1, 'timeZone': 'Antarctica/Troll'});
    await pumpSettings(tester, (k) => UiWorkflowGlobalSettings(key: k, api: api));
    expect(find.text('Antarctica/Troll'), findsOneWidget);
    await tester.tap(find.text('Antarctica/Troll'));
    await tester.pumpAndSettle();
    expect(find.text('UTC (Coordinated Universal Time)'), findsOneWidget);
    expect(find.text('America/New York'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Audit log'));
    await tester.pumpAndSettle();
    expect(find.text('Tasks and approvals'), findsOneWidget);
    expect(find.text('Record moves'), findsOneWidget);
  });

  testWidgets('hidden fields read as record type › field', (tester) async {
    final api = FakeWorkflowApi()..settingsValue = UiWorkflowSettings.fromJson({'version': 1, 'audit': {'maskedFields': ['application.amount']}});
    await pumpSettings(tester, (k) => UiWorkflowGlobalSettings(key: k, api: api));
    await tester.tap(find.text('Audit log'));
    await tester.pumpAndSettle();
    expect(find.text('Application › Amount'), findsOneWidget);
    expect(find.bySemanticsLabel('Stop hiding Application › Amount'), findsOneWidget);
  });

  testWidgets('audit masking offers only fields that are not already hidden or sensitive', (tester) async {
    final key = await pumpSettings(tester, (k) => UiWorkflowGlobalSettings(key: k, settings: UiWorkflowSettings(), registry: FakeWorkflowApi().registry));
    await tester.tap(find.text('Audit log'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a field…'));
    await tester.pumpAndSettle();
    expect(find.text('Application › IBAN'), findsNothing);
    await tester.tap(find.text('Application › Amount'));
    await tester.pumpAndSettle();
    expect(key.currentState!.value.maskedFields, ['application.amount']);
  });

  testWidgets('a phone shows the sections as a scrolling row', (tester) async {
    await pumpSettings(tester, (k) => UiWorkflowGlobalSettings(key: k, settings: UiWorkflowSettings(), registry: FakeWorkflowApi().registry), size: const Size(390, 760));
    expect(tester.getTopLeft(find.text('Defaults')).dy, lessThan(tester.getTopLeft(find.text('Time and working hours')).dy));
  });

  testWidgets('meets the tap target and label guidelines', (tester) async {
    final h = tester.ensureSemantics();
    await pumpSettings(tester, (k) => UiWorkflowGlobalSettings(key: k, settings: UiWorkflowSettings(), registry: FakeWorkflowApi().registry));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    h.dispose();
  });

  testWidgets('golden', (tester) async {
    final reg = FakeWorkflowApi().registry;
    await expectThemedGolden(
      tester,
      'workflow_global_settings',
      (_) => SizedBox(height: 560, child: UiWorkflowGlobalSettings(settings: UiWorkflowSettings.fromJson({'version': 1, 'calendar': {'holidays': ['2026-12-25']}}), registry: reg)),
      width: 720,
      height: 600,
    );
  });
}
