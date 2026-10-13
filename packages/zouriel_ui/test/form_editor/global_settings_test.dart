import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import 'support.dart';

class GsHost extends StatefulWidget {
  const GsHost({super.key, required this.initial, this.usage = const {}, required this.http});
  final UiFormGlobalSettings initial;
  final Map<String, int> usage;
  final UiFbHttpSourcesOptions http;
  @override
  State<GsHost> createState() => GsHostState();
}

class GsHostState extends State<GsHost> {
  late UiFormGlobalSettings settings = widget.initial;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: UiFormGlobalSettingsEditor(settings: settings, usage: widget.usage, httpSources: widget.http, onChanged: (s) => setState(() => settings = s)),
  );
}

void main() {
  final asked = <String>[];
  final http = UiFbHttpSourcesOptions(
    allowedOrigins: const ['https://api.example.com'],
    fetch: (url, signal) async {
      asked.add(url);
      return {
        'data': [
          {'id': 1, 'first': 'Aminath', 'last': 'Shareef'},
          {'id': 2, 'first': 'Ali', 'last': 'Rasheed'},
        ],
        'total': 2,
      };
    },
  );

  Future<GsHostState> pump(WidgetTester tester, UiFormGlobalSettings s, {Map<String, int> usage = const {}, Size size = const Size(390, 2600)}) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(home: GsHost(initial: s, usage: usage, http: http)));
    await tester.pumpAndSettle();
    return tester.state<GsHostState>(find.byType(GsHost));
  }

  testWidgets('adds a list whose key follows its name, maps the reply, and tests it the way forms will', (tester) async {
    asked.clear();
    final h = await pump(tester, createGlobalSettings());
    expect(find.text('No lists yet. Add one to let forms search your data, e.g. students or courses.'), findsOneWidget);
    await tapText(tester, 'Add a list');
    await type(tester, 'Name', 'Students');
    await type(tester, 'Address', 'https://api.example.com/students');
    await type(tester, 'Where the list is', 'data');
    await type(tester, 'What people see', '{first} {last}');
    final src = h.settings.sources!.single;
    expect(src.toJson(), {
      'type': 'students',
      'label': 'Students',
      'url': 'https://api.example.com/students',
      'itemsPath': 'data',
      'valueField': 'id',
      'labelField': '{first} {last}',
    });
    // A hand-typed key stops following the name.
    await type(tester, 'Key', 'pupils');
    await type(tester, 'Name', 'Learners');
    expect(h.settings.sources!.single.type, 'pupils');
    await type(tester, 'Search for', 'ami');
    await tapText(tester, 'Run test');
    expect(asked.single, startsWith('https://api.example.com/students?'));
    expect(asked.single, contains('q=ami'));
    expect(find.text('Works: found 2.'), findsOneWidget);
    expect(find.text('Aminath Shareef'), findsOneWidget);
    expect(find.textContaining('Fields in each item'), findsOneWidget);
    // The stored JSON makes a source the builder can use.
    expect(sourcesFromSettings(h.settings, http).single.label, 'Learners');
  });

  testWidgets('refuses an address the app doesn’t allow, and warns before deleting a list forms use', (tester) async {
    final s = UiFormGlobalSettings.fromJson({
      'version': 1,
      'sources': [
        {'type': 'people', 'label': 'People', 'url': 'https://elsewhere.org/p', 'valueField': 'id', 'labelField': 'name'},
      ],
    });
    final h = await pump(tester, s, usage: const {'people': 2});
    expect(find.text('2 forms'), findsOneWidget);
    expect(find.text('Fix'), findsOneWidget);
    await tapText(tester, 'People');
    expect(find.textContaining('This app doesn’t allow lists from https://elsewhere.org.'), findsOneWidget);
    await tapText(tester, 'Run test');
    expect(find.textContaining('This app doesn’t allow lists'), findsWidgets);
    await tapText(tester, 'Delete');
    expect(find.text('2 forms use this list. They’ll show “This list isn’t available” until it’s back.'), findsOneWidget);
    expect(h.settings.sources, hasLength(1));
    await tapText(tester, 'Delete anyway');
    expect(h.settings.sources, isEmpty);
  });

  testWidgets('settings for each question, with choices as value: label lines', (tester) async {
    final h = await pump(tester, createGlobalSettings());
    await tapText(tester, 'Add a list');
    await tapText(tester, 'Add a setting');
    await type(tester, 'Setting', 'faculty');
    await type(tester, 'Shown as', 'Faculty');
    await choose(tester, select('Kind of value'), 'Choice');
    await type(tester, 'Choices, one per line as value: label', 'health: Health and medicine\nlaw');
    await tapText(tester, 'Needed before searching');
    expect(h.settings.sources!.single.toJson()['params'], [
      {
        'key': 'faculty',
        'label': 'Faculty',
        'kind': 'select',
        'options': [
          {'value': 'health', 'label': 'Health and medicine'},
          {'value': 'law', 'label': 'law'},
        ],
        'required': true,
      },
    ]);
  });

  testWidgets('edits the defaults new forms start with', (tester) async {
    final h = await pump(tester, createGlobalSettings());
    await segment(tester, 'Settings section', 'New form defaults');
    await choose(tester, select('Question text'), 'To the left');
    await tapText(tester, 'List all problems at the top');
    expect(h.settings.toJson()['defaults'], {'labelPlacement': 'left', 'errorSummary': false});
    final def = createDefinition(title: 'New', defaults: h.settings.defaults);
    expect(def.settings!.labelPlacement, 'left');
  });

  testWidgets('on a wide screen the list and the editor sit side by side', (tester) async {
    await pump(tester, UiFormGlobalSettings.fromJson({
      'version': 1,
      'sources': [
        {'type': 'people', 'label': 'People', 'url': 'https://api.example.com/p', 'valueField': 'id', 'labelField': 'name'},
      ],
    }), size: const Size(1100, 1800));
    await tapText(tester, 'People');
    expect(find.text('Lists'), findsNothing, reason: 'no back button when both show');
    expect(find.text('Add a list'), findsOneWidget);
    expect(find.text('Where to ask'), findsOneWidget);
  });

  testWidgets('golden: phone, a list being edited after a test', (tester) async {
    asked.clear();
    final s = UiFormGlobalSettings.fromJson({
      'version': 1,
      'sources': [
        {'type': 'students', 'label': 'Students', 'url': 'https://api.example.com/students', 'itemsPath': 'data', 'valueField': 'id', 'labelField': '{first} {last}'},
      ],
    });
    await expectThemedGoldenOf(tester, 'global_settings_phone', (context) => SingleChildScrollView(child: UiFormGlobalSettingsEditor(settings: s, httpSources: http, onChanged: (_) {})));
  });
}

/// Both themes side by side (like `expectThemedGolden`), after opening the list and running its test.
Future<void> expectThemedGoldenOf(WidgetTester tester, String name, WidgetBuilder build) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(390 * 2, 2050) * 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(
    home: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final th in const [UiThemeName.dark, UiThemeName.light])
        SizedBox(width: 390, child: UiThemeScope(theme: th, child: Padding(padding: const EdgeInsets.all(16), child: Builder(builder: build)))),
    ]),
  ));
  await tester.pumpAndSettle();
  for (final label in ['Students', 'Run test']) {
    for (final e in find.text(label).evaluate().toList()) {
      await tester.tap(find.byWidget(e.widget).first, warnIfMissed: false);
      await tester.pumpAndSettle();
    }
  }
  await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/$name.png'));
}
