import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

const fixtures = 'test/form_engine/fixtures';

/// A fixture shared with the Angular suite.
Object? fixture(String name) => jsonDecode(File('$fixtures/$name').readAsStringSync());
UiJson fixtureMap(String name) => (fixture(name) as Map).cast<String, Object?>();

/// 600 students, like the web showcase's demo list: S100.. with "Person n" labels.
final people = [for (var i = 0; i < 600; i++) UiFbSourceItem(value: 'S${100 + i}', label: 'Person ${i + 1}')];

/// A paged, searchable source over [people] that logs every query.
({UiFbOptionSource def, List<UiFbSourceQuery> calls}) peopleSource({List<UiFbSourceParamSpec>? params, String type = 'students'}) {
  final calls = <UiFbSourceQuery>[];
  return (
    calls: calls,
    def: UiFbOptionSource(
      type: type,
      label: 'Students',
      params: params,
      pageSize: 20,
      search: (q) {
        calls.add(q);
        final needle = q.query.toLowerCase();
        final hits = needle.isEmpty ? people : people.where((p) => p.label.toLowerCase().contains(needle)).toList();
        final items = hits.skip((q.page - 1) * q.pageSize).take(q.pageSize).toList();
        return UiFbSourcePage(items: items, total: hits.length);
      },
    ),
  );
}

/// Courses that follow the Programme answer, as in the scholarship sample (`health-1` = Anatomy).
final coursesSource = UiFbOptionSource(
  type: 'courses',
  label: 'Courses',
  params: const [UiFbSourceParamSpec(key: 'programme', label: 'Programme', required: true)],
  pageSize: 20,
  search: (q) {
    final names = q.params['programme'] == 'health'
        ? ['Anatomy', 'Physiology', 'Community health', 'Pharmacology', 'Nursing practice I', 'Nursing practice II', 'Public health nutrition', 'Medical ethics', 'health-9']
        : ['Calculus I', 'Linear algebra'];
    final items = [
      for (var i = 0; i < names.length; i++)
        // The ninth is labelled with its own value, like a bare saved value read back as a choice.
        UiFbSourceItem(value: '${q.params['programme']}-${i + 1}', label: names[i] == 'health-9' ? 'health-9' : names[i]),
    ].where((it) => it.label.toLowerCase().contains(q.query.toLowerCase())).toList();
    return UiFbSourcePage(items: items, hasMore: false);
  },
);

/// A file picker that hands back [files] every time.
UiFilePicker fakePicker(List<UiPickedFile> files) => ({required bool multiple, required List<String> accept}) async => files;

/// Pumps a renderer in a scroll view at phone width (or [size]).
Future<GlobalKey<UiFormRendererState>> pumpForm(
  WidgetTester tester, {
  required Object definition,
  UiJson? data,
  UiFormMode? mode,
  List<UiFbOptionSourceDef> sources = const [],
  ValueChanged<UiFormSubmission>? onSubmitted,
  UiFilePicker? picker,
  Size size = const Size(390, 844),
  String today = '2026-10-13',
}) async {
  final key = GlobalKey<UiFormRendererState>();
  await pumpUi(
    tester,
    SizedBox(
      width: size.width,
      height: size.height,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: UiFormRenderer(
          key: key,
          definition: definition,
          data: data,
          mode: mode,
          optionSources: sources,
          onSubmitted: onSubmitted,
          filePicker: picker,
          today: () => today,
        ),
      ),
    ),
    size: size,
  );
  return key;
}

UiFbField fieldJson(String id, String type, [Map<String, Object?> extra = const {}]) =>
    UiFbField.fromJson({'kind': 'field', 'id': id, 'type': type, 'key': id, 'label': id.toUpperCase(), ...extra});

UiJson form(List<UiJson> elements, {UiJson settings = const {}, String title = 'Test form'}) => {
      'schemaVersion': 1,
      'id': 'f',
      'title': title,
      'settings': settings,
      'pages': [
        {'id': 'p1', 'elements': elements},
      ],
    };

UiJson f(String id, String type, [Map<String, Object?> extra = const {}]) => {'kind': 'field', 'id': id, 'type': type, 'key': id, 'label': id.toUpperCase(), ...extra};

/// Finds a text control by the field label it carries (UiFieldScope label).
Finder editableIn(String label) => find.descendant(
      of: find.byWidgetPredicate((w) => w is UiFbFieldView && w.field.label == label),
      matching: find.byType(EditableText),
    );

Finder fieldView(String label, {int at = 0}) => find.byWidgetPredicate((w) => w is UiFbFieldView && w.field.label == label).at(at);

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

/// Waits for real async work (sources returning futures) in fake time.
Future<void> flush(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}
