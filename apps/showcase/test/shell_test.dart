import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/docs/doc.dart';
import 'package:zouriel_ui_showcase/main.dart';
import 'package:zouriel_ui_showcase/pages/registry.dart';

/// Every page, opened from the phone menu, fills the screen's width. The window page (a Stack of
/// positioned layers) once collapsed to zero width because the shell handed pages a loose width.
void main() {
  for (final p in showcasePages) {
    testWidgets('${p.label} fills the width on a phone', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ShowcaseApp(controller: UiThemeController()));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.bySemanticsLabel('Open menu'));
      await tester.pump(const Duration(seconds: 1));
      // The menu builds its rows lazily: scroll it until this page's row exists.
      // The open drawer is drawn over the page, so its list is the last scrollable in the tree.
      final menu = find.byType(Scrollable).last;
      final entry = find.descendant(of: menu, matching: find.text(p.label));
      await tester.scrollUntilVisible(entry, 120, scrollable: menu);
      await tester.ensureVisible(entry);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(entry);
      await tester.pump(const Duration(seconds: 1));
      final page = find.byType(DocPage);
      expect(page, findsOneWidget);
      expect(tester.getRect(page).width, 390);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
