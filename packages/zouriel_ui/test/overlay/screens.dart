import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// Phone screens side by side, one per theme, each with its own [Navigator] so routes and
/// overlays opened from [page] render inside that screen (and in that theme). For goldens of
/// things that cover the screen: modals, drawers, sheets, toasts, menus.
Future<void> pumpScreens(
  WidgetTester tester,
  WidgetBuilder page, {
  List<UiThemeName> themes = const [UiThemeName.dark, UiThemeName.light],
  Size screen = const Size(360, 640),
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = Size(screen.width * themes.length + 8 * (themes.length - 1), screen.height) * 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(
    theme: themes.first,
    home: Row(
      key: const Key('screens'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        for (final th in themes)
          SizedBox(
            width: screen.width,
            child: UiThemeScope(
              theme: th,
              child: MediaQuery(
                data: MediaQueryData(size: screen, padding: padding),
                child: ClipRect(child: Navigator(onGenerateRoute: (s) => UiPageRoute<void>(settings: s, builder: page))),
              ),
            ),
          ),
      ],
    ),
  ));
  await tester.pumpAndSettle();
}

/// The golden of the screens pumped by [pumpScreens].
Future<void> expectScreensGolden(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await expectLater(find.byKey(const Key('screens')), matchesGoldenFile('goldens/$name.png'));
}
