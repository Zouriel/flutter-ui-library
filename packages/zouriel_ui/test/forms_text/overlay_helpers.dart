import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// Like `expectThemedGolden`, but captures the whole app overlay so an open popover (a list, a
/// calendar) is in the image. One image per theme (`<name>_<theme>.png`), since opening a popover
/// in one half would close the other's. [open] runs after the first pump, e.g. to tap the trigger.
Future<void> expectOverlayGolden(
  WidgetTester tester,
  String name,
  Widget Function(BuildContext context) build, {
  Future<void> Function()? open,
  List<UiThemeName> themes = const [UiThemeName.dark, UiThemeName.light],
  double width = 390,
  double height = 420,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = Size(width, height) * 2;
  addTearDown(tester.view.reset);
  for (final th in themes) {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(UiApp(
      theme: th,
      home: Padding(padding: const EdgeInsets.all(16), child: Builder(builder: build)),
    ));
    await tester.pump();
    if (open != null) await open();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(Overlay).first, matchesGoldenFile('goldens/${name}_${th.name}.png'));
  }
}
