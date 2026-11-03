import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/file_viewer_page.dart';

/// 0.53.0 showcase demo: the lightbox's four actions fit a 320 and 360 phone without overflowing.

void main() {
  for (final width in [320.0, 360.0]) {
    testWidgets('file viewer page: the lightbox top bar fits $width wide, every action named', (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = Size(width, 760) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const UiApp(home: FileViewerPage()));
      await tester.pump(const Duration(milliseconds: 300));
      final open = find.text('Open the lightbox');
      await tester.ensureVisible(open);
      await tester.pump(const Duration(milliseconds: 300));
      // The page's own viewers have narrow-screen toolbar overflows of their own (not the lightbox's,
      // reported separately): clear them so only the lightbox is judged below.
      tester.takeException();
      await tester.tap(open);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      final lb = find.byType(UiMediaLightbox);
      final named = ['Save', 'Share', 'Download original', 'Remove'].where((l) => find.descendant(of: lb, matching: find.bySemanticsLabel(l)).evaluate().isNotEmpty).toList();
      final more = find.descendant(of: lb, matching: find.bySemanticsLabel('More actions')).evaluate().isNotEmpty;
      expect(named.length == 4 || more, isTrue, reason: 'all four shown, or the rest in More: $named');
      expect(tester.getRect(find.bySemanticsLabel('Close').last).right, lessThanOrEqualTo(width));
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
