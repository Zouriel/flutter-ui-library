import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/docs/doc.dart';
import 'package:zouriel_ui_showcase/main.dart';

/// The theme sheet's density switch (0.45.0) changes the whole app's density.
void main() {
  testWidgets('the theme sheet switches the app to compact and back', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    final c = UiThemeController();
    addTearDown(c.dispose);
    await tester.pumpWidget(ShowcaseApp(controller: c));
    await tester.pump(const Duration(seconds: 1));
    expect(UiTheme.of(tester.element(find.byType(DocPage))).compact, isFalse);

    await tester.tap(find.text('Winter Dark'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Compact'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(c.config.density, UiDensity.compact);
    expect(UiTheme.of(tester.element(find.byType(DocPage))).tokens.fontSizeMd, 14);

    await tester.tap(find.text('Comfortable'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(UiTheme.of(tester.element(find.byType(DocPage))).tokens.fontSizeMd, 15);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    debugDefaultTargetPlatformOverride = null;
  });
}
