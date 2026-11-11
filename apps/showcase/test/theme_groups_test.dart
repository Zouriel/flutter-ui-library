import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui_showcase/main.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

void main() {
  testWidgets('the theme sheet lists the current themes, then a Legacy group with the legacy ones', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    final c = UiThemeController();
    addTearDown(c.dispose);
    await tester.pumpWidget(ShowcaseApp(controller: c));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Navy Dark'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final legacyHead = tester.getTopLeft(find.text('Legacy')).dy;
    for (final label in ['Navy Light', 'Rugged', 'Violet Dark', 'Maldives Dark']) {
      expect(tester.getTopLeft(find.text(label).last).dy, lessThan(legacyHead), reason: label);
    }
    for (final label in ['Winter Dark (legacy)', 'Light Teal (legacy)', 'Gold Red (legacy)']) {
      expect(tester.getTopLeft(find.text(label)).dy, greaterThan(legacyHead), reason: label);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the shell puts the liquid backdrop behind the page in the liquid themes only', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    final c = UiThemeController(theme: UiThemeName.glacier);
    addTearDown(c.dispose);
    await tester.pumpWidget(ShowcaseApp(controller: c));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(UiLiquidBackdrop), findsOneWidget);
    c.set(UiThemeName.dark);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(UiLiquidBackdrop), findsNothing);
    c.set(UiThemeName.cocoaDark);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(UiLiquidBackdrop), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
