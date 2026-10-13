import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// A field as JSON: key = id, label = upper-cased id (like the web spec's `f()`).
UiJson fj(String id, String type, [UiJson extra = const {}]) => {'kind': 'field', 'id': id, 'type': type, 'key': id, 'label': id.toUpperCase(), ...extra};

/// A one-page form from element JSON (like the web spec's `form()`).
UiFormDefinition formOf(List<UiJson> elements, {String id = 'f', String title = 'Test form', UiJson extra = const {}}) => UiFormDefinition.fromJson({
  'schemaVersion': 1,
  'id': id,
  'title': title,
  'pages': [
    {'id': 'p1', 'elements': elements},
  ],
  ...extra,
});

/// A controller with a clock the test moves by hand.
class FakeClock {
  DateTime now = DateTime(2026, 10, 14, 9);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

// ── Finding and driving controls ──

Finder input(String label) => find.descendant(of: find.byWidgetPredicate((w) => (w is UiInput && w.semanticLabel == label) || (w is UiTextarea && w.semanticLabel == label)), matching: find.byType(EditableText));
Finder select(String label) => find.byWidgetPredicate((w) => w is UiSelect && w.label == label);

Future<void> type(WidgetTester tester, String label, String text, {int at = 0}) async {
  final f = input(label).at(at);
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, Finder sel, String option) async {
  await tester.ensureVisible(sel);
  await tester.tap(sel);
  await tester.pumpAndSettle();
  final item = find.descendant(of: find.byType(UiListboxPanel), matching: find.text(option)).last;
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.tap(f, warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> segment(WidgetTester tester, String label, String option) async {
  final seg = find.byWidgetPredicate((w) => w is UiSegmented && w.label == label);
  await tester.ensureVisible(seg);
  await tester.tap(find.descendant(of: seg, matching: find.text(option)));
  await tester.pumpAndSettle();
}

