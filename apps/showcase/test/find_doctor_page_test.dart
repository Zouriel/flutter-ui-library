import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/find_doctor_page.dart';

void main() {
  testWidgets('Find Doctor switches the app to Maldives and back on leaving', (tester) async {
    final c = UiThemeController(theme: UiThemeName.lightTeal);
    final show = ValueNotifier(true);
    addTearDown(show.dispose);
    await tester.pumpWidget(UiApp(
      controller: c,
      home: ValueListenableBuilder<bool>(valueListenable: show, builder: (_, on, _) => on ? const FindDoctorPage() : const SizedBox()),
    ));
    await tester.pump();
    expect(c.theme, UiThemeName.maldives);
    show.value = false;
    await tester.pump();
    await tester.pump();
    expect(c.theme, UiThemeName.lightTeal);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a theme picked while on the page stays after leaving', (tester) async {
    final c = UiThemeController(theme: UiThemeName.dark);
    final show = ValueNotifier(true);
    addTearDown(show.dispose);
    await tester.pumpWidget(UiApp(
      controller: c,
      home: ValueListenableBuilder<bool>(valueListenable: show, builder: (_, on, _) => on ? const FindDoctorPage() : const SizedBox()),
    ));
    await tester.pump();
    c.set(UiThemeName.goldBlack);
    await tester.pump();
    show.value = false;
    await tester.pump();
    await tester.pump();
    expect(c.theme, UiThemeName.goldBlack);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
