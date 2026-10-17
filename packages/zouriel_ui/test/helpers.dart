import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// Pumps [child] inside a themed app (default Winter Dark) at phone width.
Future<void> pumpUi(WidgetTester tester, Widget child, {UiThemeName theme = UiThemeName.dark, Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(theme: theme, home: Align(alignment: Alignment.topLeft, child: child)));
  await tester.pumpAndSettle();
}

/// A golden of [build] rendered side by side in Winter Dark and Winter Light (plus any [extra]
/// themes), each on its own background, so one image covers both modes.
Future<void> expectThemedGolden(
  WidgetTester tester,
  String name,
  Widget Function(BuildContext context) build, {
  List<UiThemeName> themes = const [UiThemeName.dark, UiThemeName.light],
  double width = 390,
  double height = 300,
}) async {
  // Real, soft shadows (flutter_test draws them as hard shapes by default). Reset before the test
  // ends: the framework checks debug flags before tear-downs run.
  debugDisableShadows = false;
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = Size(width * themes.length, height) * 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(
    theme: themes.first,
    home: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final th in themes)
          SizedBox(
            width: width,
            child: UiThemeScope(
              theme: th,
              child: Padding(padding: const EdgeInsets.all(16), child: Builder(builder: build)),
            ),
          ),
      ],
    ),
  ));
  await tester.pump(const Duration(milliseconds: 400));
  try {
    await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/$name.png'));
  } finally {
    debugDisableShadows = true;
  }
}
