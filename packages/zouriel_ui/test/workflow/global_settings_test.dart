import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fake_api.dart';

Finder button(String label) => find.byWidgetPredicate((w) => w is UiButton && w.label == label);

/// The control a text sits in: taps land on it (the text itself takes no hits).
Finder control(String text) => find.ancestor(of: find.text(text), matching: find.byType(UiInteractive)).first;

Future<GlobalKey<UiWorkflowGlobalSettingsState>> pumpSettings(WidgetTester tester, Widget Function(GlobalKey<UiWorkflowGlobalSettingsState> key) build, {Size size = const Size(900, 760)}) async {
  final key = GlobalKey<UiWorkflowGlobalSettingsState>();
  await pumpUi(tester, SizedBox(width: size.width, height: size.height, child: build(key)), size: size);
  return key;
}

void main() {
  // A tap that misses its widget fails the test instead of passing without doing anything.
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

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
    await tester.tap(control('Webhooks'));
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
    await tester.tap(control('Defaults'));
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
    await tester.tap(control('Watching'));
    await tester.pumpAndSettle();
    expect(find.text('Two workflows start on the same change here. Check they don’t work against each other.'), findsOneWidget);
    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();
    expect(key.currentState!.value.paused, ['application']);
    expect(api.calls, contains('saveSettings:3'));
    expect(find.text('Paused'), findsOneWidget); // the switch says what it is now
    expect(find.bySemanticsLabel(RegExp('Run workflows for Application')), findsOneWidget);
  });

  testWidgets('pausing saves only the pause; other edits stay unsaved', (tester) async {
    final api = FakeWorkflowApi()
      ..triggerList = [
        UiWfTriggerOverview.fromJson({'definitionId': 'a', 'title': 'Remind', 'kind': 'automation', 'type': 'fieldChanged', 'entity': 'application', 'field': 'status', 'summary': 'When Status changes'}),
      ];
    final key = await pumpSettings(tester, (k) => UiWorkflowGlobalSettings(key: k, api: api));
    await tester.tap(find.text('Sat'));
    await tester.pump();
    await tester.tap(control('Watching'));
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
    await tester.tap(control('Audit log'));
    await tester.pumpAndSettle();
    expect(find.text('Tasks and approvals'), findsOneWidget);
    expect(find.text('Record moves'), findsOneWidget);
  });

  testWidgets('hidden fields read as record type › field', (tester) async {
    final api = FakeWorkflowApi()..settingsValue = UiWorkflowSettings.fromJson({'version': 1, 'audit': {'maskedFields': ['application.amount']}});
    await pumpSettings(tester, (k) => UiWorkflowGlobalSettings(key: k, api: api));
    await tester.tap(control('Audit log'));
    await tester.pumpAndSettle();
    expect(find.text('Application › Amount'), findsOneWidget);
    expect(find.bySemanticsLabel('Stop hiding Application › Amount'), findsOneWidget);
  });

  testWidgets('audit masking offers only fields that are not already hidden or sensitive', (tester) async {
    final key = await pumpSettings(tester, (k) => UiWorkflowGlobalSettings(key: k, settings: UiWorkflowSettings(), registry: FakeWorkflowApi().registry));
    await tester.tap(control('Audit log'));
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

  testWidgets('switches to its phone layout on its own, with no width given', (tester) async {
    Future<(double, double)> navTops(Size screen) async {
      await pumpUi(
        tester,
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(height: 560, child: UiWorkflowGlobalSettings(settings: UiWorkflowSettings(), registry: FakeWorkflowApi().registry)),
          ]),
        ),
        size: screen,
      );
      expect(tester.takeException(), isNull);
      // Two of the section buttons.
      return (tester.getTopLeft(find.text('Time & calendar')).dy, tester.getTopLeft(find.text('Defaults')).dy);
    }

    final (phoneA, phoneB) = await navTops(const Size(390, 844));
    expect(phoneA, phoneB, reason: 'on a phone the sections are rows above the form (wrapping, never cut off)');
    final (wideA, wideB) = await navTops(const Size(1100, 844));
    expect(wideB, greaterThan(wideA), reason: 'wide, they are a column beside the form');
  });

  testWidgets('picking a holiday adds it at once, and the picker empties for the next one', (tester) async {
    final key = await pumpSettings(tester, (k) => UiWorkflowGlobalSettings(key: k, settings: UiWorkflowSettings(), registry: FakeWorkflowApi().registry));
    expect(find.text('Add holiday'), findsNothing);
    await tester.tap(find.bySemanticsLabel(RegExp('^Holiday date')));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    await tester.tap(find.bySemanticsLabel('${months[now.month - 1]} 15, ${now.year}'));
    await tester.pumpAndSettle();
    final day = '${now.year}-${now.month.toString().padLeft(2, '0')}-15';
    expect(key.currentState!.value.holidays, [day]);
    expect(find.text('Add a holiday'), findsOneWidget);
  });

  testWidgets('a slower answer from the earlier api never replaces the newer one', (tester) async {
    final slow = _GatedSettings(UiWorkflowSettings.fromJson({'version': 1, 'timeZone': 'Asia/Tokyo'}));
    final fast = FakeWorkflowApi()..settingsValue = UiWorkflowSettings.fromJson({'version': 1, 'timeZone': 'Europe/Oslo'});
    final api = ValueNotifier<UiWorkflowApi>(slow);
    final key = GlobalKey<UiWorkflowGlobalSettingsState>();
    await pumpUi(tester, SizedBox(width: 900, height: 760, child: ValueListenableBuilder(valueListenable: api, builder: (_, v, _) => UiWorkflowGlobalSettings(key: key, api: v))), size: const Size(900, 760));
    api.value = fast;
    await tester.pumpAndSettle();
    expect(key.currentState!.value.timeZone, 'Europe/Oslo');
    slow.gate.complete();
    await tester.pumpAndSettle();
    expect(key.currentState!.value.timeZone, 'Europe/Oslo');
  });

  for (final w in [360.0, 320.0]) {
    testWidgets('fits a ${w.toInt()}px phone inside a page\'s padding, holidays listed, every section', (tester) async {
      final settings = UiWorkflowSettings.fromJson({'version': 1, 'calendar': {'holidays': ['2026-12-25', '2027-01-01']}});
      // The showcase page gives it the phone's width less about 100px of padding.
      await pumpUi(
        tester,
        SizedBox(width: w, height: 760, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 49), child: UiWorkflowGlobalSettings(settings: settings, registry: FakeWorkflowApi().registry))),
        size: Size(w, 760),
      );
      expect(tester.takeException(), isNull);
      for (final section in ['Defaults', 'Webhooks', 'Audit log', 'Watching']) {
        await tester.ensureVisible(control(section));
        await tester.pumpAndSettle();
        await tester.tap(control(section));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: section);
      }
    });
  }

  // Mirrors @zouriel/ui 6beaec3: connection keys.
  group('webhook connection keys', () {
    UiWorkflowSettings saved() => UiWorkflowSettings.fromJson({
          'version': 1,
          'webhooks': {'connections': [{'key': 'erp', 'label': 'ERP', 'baseUrl': 'https://erp.example.com', 'auth': 'none'}]},
        });
    Future<GlobalKey<UiWorkflowGlobalSettingsState>> open(WidgetTester tester, FakeWorkflowApi api) async {
      final key = await pumpSettings(tester, (k) => UiWorkflowGlobalSettings(key: k, api: api), size: const Size(900, 1400));
      await tester.tap(control('Webhooks'));
      await tester.pumpAndSettle();
      return key;
    }

    Finder nameField(int i) => find.descendant(of: find.byWidgetPredicate((w) => w is UiInput && w.semanticLabel == 'Name').at(i), matching: find.byType(EditableText));

    testWidgets('renaming a saved connection keeps its key, so webhook steps using it keep working', (tester) async {
      final key = await open(tester, FakeWorkflowApi()..settingsValue = saved());
      await tester.enterText(nameField(0), 'Finance system');
      await tester.pump();
      expect(key.currentState!.value.connections.single.key, 'erp');
      expect(find.textContaining('webhook steps use it, so it stays when the name changes'), findsOneWidget);
    });

    testWidgets('a new connection is keyed after its name, and two with the same name get different keys', (tester) async {
      final key = await open(tester, FakeWorkflowApi()..settingsValue = saved());
      await tester.tap(control('Add a connection'));
      await tester.pumpAndSettle();
      await tester.tap(control('Add a connection'));
      await tester.pumpAndSettle();
      await tester.enterText(nameField(1), 'Bank');
      await tester.enterText(nameField(2), 'Bank');
      await tester.pump();
      expect([for (final c in key.currentState!.value.connections) c.key], ['erp', 'bank', 'bank2']);
      expect(find.text('Key bank2', findRichText: true), findsOneWidget, reason: 'the key is shown');
    });

    testWidgets('adding after a delete never reuses a key on the page or a saved one', (tester) async {
      final key = await open(tester, FakeWorkflowApi()..settingsValue = saved());
      await tester.tap(control('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(control('Add a connection'));
      await tester.pumpAndSettle();
      await tester.enterText(nameField(0), 'ERP');
      await tester.pump();
      expect(key.currentState!.value.connections.single.key, isNot('erp'), reason: 'the saved key may still be used by steps');
    });
  });
}


/// Answers settings() only when told to.
class _GatedSettings extends FakeWorkflowApi {
  _GatedSettings(UiWorkflowSettings s) {
    settingsValue = s;
  }
  final gate = Completer<void>();
  @override
  Future<({UiWorkflowSettings settings, int revision})> settings() async {
    await gate.future;
    return super.settings();
  }
}
