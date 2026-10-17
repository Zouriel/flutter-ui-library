import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/bits.dart' show WfSelect;
import 'package:zouriel_ui/src/workflow/global_settings.dart' show wfSettingsProblemField, wfWithoutRemovedSettings;
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fake_api.dart';

// Mirrors @zouriel/ui 00bd610: the engine's settings contract (removed fields, invalidSettings
// problems placed at their fields).

Finder control(String text) => find.ancestor(of: find.text(text), matching: find.byType(UiInteractive)).first;
Finder button(String label) => find.byWidgetPredicate((w) => w is UiButton && w.label == label);

/// Refuses every save with [error].
class _Refusing extends FakeWorkflowApi {
  _Refusing(this.error, UiWorkflowSettings s) {
    settingsValue = s;
  }
  final UiWfApiError error;
  final sent = <UiWorkflowSettings>[];
  @override
  Future<int> saveSettings(UiWorkflowSettings settings, int revision) async {
    sent.add(settings);
    throw error;
  }
}

class _Saving extends FakeWorkflowApi {
  _Saving(UiWorkflowSettings s) {
    settingsValue = s;
  }
  final sent = <UiWorkflowSettings>[];
  @override
  Future<int> saveSettings(UiWorkflowSettings settings, int revision) async {
    sent.add(settings);
    return revision + 1;
  }
}

Future<GlobalKey<UiWorkflowGlobalSettingsState>> _pump(WidgetTester tester, UiWorkflowApi api) async {
  final key = GlobalKey<UiWorkflowGlobalSettingsState>();
  await pumpUi(tester, SizedBox(width: 900, height: 1200, child: UiWorkflowGlobalSettings(key: key, api: api)), size: const Size(900, 1200));
  return key;
}

const _erp = {'key': 'erp', 'label': 'ERP', 'baseUrl': 'https://erp.example.com', 'auth': 'none'};

void main() {
  group('fields the engine removed', () {
    testWidgets('has no "tasks are due" default; the reminder is counted from when the task opens', (tester) async {
      await _pump(tester, FakeWorkflowApi());
      await tester.tap(control('Defaults'));
      await tester.pumpAndSettle();
      expect(find.text('Tasks are due within'), findsNothing);
      expect(find.text('Remind people of an open task after'), findsOneWidget);
    });

    testWidgets('does not send back taskDue, escalationDefault or a channel sender kept from older settings', (tester) async {
      final api = _Saving(UiWorkflowSettings.fromJson({
        'version': 1, 'defaults': {'taskDue': 'P3D', 'forEachMax': 50}, 'people': {'delegation': true, 'escalationDefault': [{'role': 'head'}]},
        'channels': {'email': {'enabled': true, 'sender': 'noreply@x', 'footer': 'Bye'}},
      }));
      final key = await _pump(tester, api);
      expect(key.currentState!.dirty, isFalse, reason: 'stripping what the engine dropped is not an edit');
      await tester.tap(control('Sat'));
      await tester.pump();
      await key.currentState!.save();
      final sent = api.sent.single.json;
      expect(sent['defaults'], {'forEachMax': 50});
      expect(sent['people'], {'delegation': true});
      expect(sent['channels'], {'email': {'enabled': true, 'footer': 'Bye'}});
    });

    test('wfWithoutRemovedSettings leaves everything else alone', () {
      final s = UiWorkflowSettings.fromJson({'version': 1, 'timeZone': 'UTC', 'defaults': {'reminders': ['P1D']}});
      expect(wfWithoutRemovedSettings(s).json, s.json);
    });
  });

  group('refused saves (invalidSettings)', () {
    const problems = [
      "Unknown time zone 'Mars/Olympus'.",
      'Working hours must end after they start.',
      "'P1X' is not a duration.",
      "Connection 'erp' needs an http(s) address.",
      'Something new the page does not know.',
    ];
    final refusal = UiWfApiError(400, 'invalidSettings', problems.join(' '), problems);
    final bad = UiWorkflowSettings.fromJson({
      'version': 1, 'timeZone': 'Mars/Olympus', 'calendar': {'hours': ['17:00', '09:00']}, 'defaults': {'reminders': ['P1X']},
      'webhooks': {'connections': [{'key': 'x', 'label': 'X', 'baseUrl': 'https://x.example.com', 'auth': 'none'}, {..._erp, 'baseUrl': 'ftp://erp'}]},
    });

    testWidgets('places each problem next to its field, marks the sections, and says the rest in the footer', (tester) async {
      final key = await _pump(tester, _Refusing(refusal, bad));
      await key.currentState!.save();
      await tester.pumpAndSettle();
      expect(find.text('4 settings need fixing before saving (marked in the sections). Something new the page does not know.'), findsOneWidget);
      expect([for (final s in ['time', 'defaults', 'webhooks', 'audit', 'watching']) if (find.byKey(ValueKey('bad-$s')).evaluate().isNotEmpty) s], ['time', 'defaults', 'webhooks']);
      expect(find.text("Unknown time zone 'Mars/Olympus'."), findsOneWidget);
      expect(find.text('Working hours must end after they start.'), findsOneWidget);
      await tester.tap(control('Defaults'));
      await tester.pumpAndSettle();
      expect(find.text("'P1X' is not a duration."), findsOneWidget);
      await tester.tap(control('Webhooks'));
      await tester.pumpAndSettle();
      final msg = find.text("Connection 'erp' needs an http(s) address.");
      expect(msg, findsOneWidget);
      // Under the second card (ERP), not the first.
      expect(tester.getTopLeft(msg).dy, greaterThan(tester.getTopLeft(find.textContaining('Key erp', findRichText: true)).dy));
    });

    testWidgets('a problem stops showing once its field is changed', (tester) async {
      final key = await _pump(tester, _Refusing(refusal, bad));
      await key.currentState!.save();
      await tester.pumpAndSettle();
      expect(find.text("Unknown time zone 'Mars/Olympus'."), findsOneWidget);
      await tester.tap(control('Sat'));
      await tester.pumpAndSettle();
      expect(find.text("Unknown time zone 'Mars/Olympus'."), findsOneWidget, reason: 'another field changed');
      tester.widget<WfSelect>(find.byWidgetPredicate((w) => w is WfSelect && w.label == 'Time zone')).onChanged!('UTC');
      await tester.pumpAndSettle();
      expect(find.text("Unknown time zone 'Mars/Olympus'."), findsNothing);
      expect(find.text('Working hours must end after they start.'), findsOneWidget, reason: 'its field is unchanged');
    });

    testWidgets('other refusals still show the engine\'s message alone', (tester) async {
      final key = await _pump(tester, _Refusing(const UiWfApiError(409, 'staleSettings', 'Someone else changed the settings. Reload and try again.'), UiWorkflowSettings()));
      await tester.tap(control('Sat'));
      await tester.pump();
      await key.currentState!.save();
      await tester.pumpAndSettle();
      expect(find.text('Someone else changed the settings. Reload and try again.'), findsOneWidget);
    });
  });

  test('wfSettingsProblemField places the engine\'s messages as the web does', () {
    final st = UiWorkflowSettings.fromJson({
      'version': 1, 'defaults': {'reminders': ['P1D', 'bad'], 'retry': {'max': 3, 'initial': 'soon'}}, 'webhooks': {'connections': [_erp]},
    });
    const table = [
      ("Unknown time zone 'X'.", 'timeZone'),
      ("'funday' is not a day; use mon, tue, wed, thu, fri, sat or sun.", 'days'),
      ('A working day is listed twice.', 'days'),
      ('Working hours are a start and an end time.', 'hours'),
      ('Working hours must be times like 09:00 and 17:00 (HH:mm).', 'hours'),
      ("'2026-02-30' is not a date (YYYY-MM-DD).", 'holidays'),
      ('Retries can be 0 to 10.', 'retry'),
      ("'slow' is not a way to space retries (fixed or exponential).", 'retry'),
      ("'soon' is not a duration.", 'retry'),
      ("'bad' is not a duration.", 'reminders'),
      ("'x' is not a concurrency mode (perRecordSerial, parallel or skipIfRunning).", 'concurrency'),
      ('The loop protection limit (maxChainDepth) must be 1 to 20.', 'maxChainDepth'),
      ("The most items a 'for each' covers (forEachMax) must be 1 to 500.", 'forEachMax'),
      ("'https://a.example.com/x' is not an origin like https://api.example.com (scheme and host only).", 'origins'),
      ("Connection key 'erp' must start with a lower-case letter and use letters, digits and _.", 'conn:0'),
      ("Two connections are called 'erp'.", 'conn:0'),
      ("Connection 'erp' uses a secret but names none.", 'conn:0'),
      ("Connection 'gone' needs an http(s) address.", 'connections'),
      ("Audit entries of 'step' must be kept at least 1 day.", 'retention'),
      ("'nodot' is not a masked field like entity.field or input.key.", 'masked'),
      ('A paused entry names no record type.', 'paused'),
      ('Anything else.', 'general'),
    ];
    for (final (m, field) in table) {
      expect(wfSettingsProblemField(m, st), field, reason: m);
    }
  });
}
