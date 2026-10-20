import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/main.dart';
import 'package:zouriel_ui_showcase/pages/find_doctor_page.dart';
import 'package:zouriel_ui_showcase/pages/registry.dart';

void main() {
  // Through the real shell, which adds the sea backdrop around the page when the theme turns
  // Maldives. That once rebuilt the page itself, whose leaving undid the switch, whose return redid
  // it: the theme flipped every frame for ever.
  testWidgets('opened from the shell menu, the switch happens once and settles', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    final c = UiThemeController(theme: UiThemeName.lightTeal);
    var switches = 0;
    c.addListener(() => switches++);
    await tester.pumpWidget(ShowcaseApp(controller: c));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.bySemanticsLabel('Open menu'));
    await tester.pump(const Duration(seconds: 1));
    final menu = find.byType(Scrollable).last;
    final entry = find.descendant(of: menu, matching: find.text('Find Doctor (Maldives)'));
    await tester.scrollUntilVisible(entry, 120, scrollable: menu);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(entry);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(c.theme, UiThemeName.maldives);
    expect(switches, 1);
    // Leaving for another page puts the old theme back, and that too settles.
    await tester.tap(find.bySemanticsLabel('Open menu'));
    await tester.pump(const Duration(seconds: 1));
    final first = find.descendant(of: find.byType(Scrollable).last, matching: find.text(showcasePages.first.label));
    await tester.scrollUntilVisible(first, -120, scrollable: find.byType(Scrollable).last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(first);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(c.theme, UiThemeName.lightTeal);
    expect(switches, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    debugDefaultTargetPlatformOverride = null;
  });

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

  testWidgets('opened at night (Maldives Dark), the page keeps it, with no switch either way', (tester) async {
    final c = UiThemeController(theme: UiThemeName.maldivesDark);
    var switches = 0;
    c.addListener(() => switches++);
    final show = ValueNotifier(true);
    addTearDown(show.dispose);
    await tester.pumpWidget(UiApp(
      controller: c,
      home: ValueListenableBuilder<bool>(valueListenable: show, builder: (_, on, _) => on ? const FindDoctorPage() : const SizedBox()),
    ));
    await tester.pump();
    await tester.pump();
    expect(c.theme, UiThemeName.maldivesDark);
    show.value = false;
    await tester.pump();
    await tester.pump();
    expect(c.theme, UiThemeName.maldivesDark);
    expect(switches, 0);
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
