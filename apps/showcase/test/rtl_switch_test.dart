import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/docs/doc.dart';
import 'package:zouriel_ui_showcase/main.dart';

/// The bar's RTL · Dhivehi switch (0.46.0) mirrors every page and switches the library's words.
void main() {
  testWidgets('the bar toggle flips the app to RTL with Dhivehi strings and back', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    final c = UiThemeController();
    addTearDown(c.dispose);
    final rtl = ValueNotifier(false);
    addTearDown(rtl.dispose);
    await tester.pumpWidget(ShowcaseApp(controller: c, rtl: rtl));
    await tester.pump(const Duration(seconds: 1));
    final page = find.byType(DocPage);
    expect(Directionality.of(tester.element(page)), TextDirection.ltr);
    final menuLtr = tester.getRect(find.bySemanticsLabel('Open menu'));

    await tester.tap(find.text('RTL · ދިވެހި'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(rtl.value, isTrue);
    expect(Directionality.of(tester.element(page)), TextDirection.rtl);
    expect(UiTheme.of(tester.element(page)).config.strings, UiStrings.dv);
    // The menu button moved to the right-hand end of the bar.
    expect(tester.getRect(find.bySemanticsLabel('Open menu')).left, greaterThan(menuLtr.left + 200));

    await tester.tap(find.text('RTL · ދިވެހި'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(Directionality.of(tester.element(page)), TextDirection.ltr);
    expect(UiTheme.of(tester.element(page)).config.strings.close, 'Close');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    debugDefaultTargetPlatformOverride = null;
  });
}
