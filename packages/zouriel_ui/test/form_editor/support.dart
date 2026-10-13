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
