import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

Finder rims() => find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter is UiGlassRimPainter);

void main() {
  test('every glass surface in the library draws the rim', () {
    // A file that paints a glass fill (the glass tints) also wraps it in UiGlassRim. The media viewer's
    // chrome sits over photos, never over the liquid backdrop, so it is left out (as on the web).
    final glassFill = RegExp(r'\b(t\.glassBg|t\.glassPanelBg|uiGlassSheetTint\()');
    final skip = {'theme/theme.dart', 'theme/glass_sheet.dart', 'theme/glass_rim.dart', 'file_viewer/viewer_overlay.dart', 'map/navigation_view.dart'};
    final missing = <String>[];
    var seen = 0;
    for (final f in Directory('lib/src').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final rel = f.path.substring('lib/src/'.length);
      if (skip.contains(rel)) continue;
      final src = f.readAsStringSync();
      if (!glassFill.hasMatch(src)) continue;
      seen++;
      if (!src.contains('UiGlassRim(')) missing.add(rel);
    }
    expect(seen, greaterThanOrEqualTo(13));
    expect(missing, isEmpty);
  });

  testWidgets('paints a 1px edge and a brighter top band inside the border', (tester) async {
    const top = Color(0xd9ffffff);
    const edge = Color(0x66ffffff);
    final painter = UiGlassRimPainter(top: top, edge: edge, borderRadius: BorderRadius.circular(8));
    final px = await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      painter.paint(Canvas(rec), const Size(100, 40));
      final img = await rec.endRecording().toImage(100, 40);
      final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      int alpha(int x, int y) => data.getUint8((y * 100 + x) * 4 + 3);
      return {'top': alpha(50, 1), 'side': alpha(1, 20), 'border': alpha(0, 20), 'inside': alpha(50, 20), 'below-top': alpha(50, 3)};
    });
    expect(px!['border'], 0, reason: 'the 1px border is left alone');
    expect(px['inside'], 0);
    expect(px['below-top'], 0);
    expect(px['side']!, greaterThan(80));
    expect(px['top']!, greaterThan(px['side']!));
  });

  for (final glassTheme in [UiThemeName.rugged, UiThemeName.violetDark]) {
    testWidgets('lights the rim on glass in ${glassTheme.name}, and not on solid surfaces', (tester) async {
      await pumpUi(
        tester,
        Column(children: [
          const UiCard(glass: true, child: Text('glass')),
          const UiStatCard(label: 'Visits', value: '12', glass: true),
          UiButton(glass: true, onPressed: () {}, child: const Text('Glass')),
          const UiCard(glass: false, child: Text('solid')),
        ]),
        theme: glassTheme,
      );
      expect(rims(), findsNWidgets(3));
    });
  }

  testWidgets('draws nothing extra on glass in themes that do not light it (Navy, maldives, legacy)', (tester) async {
    for (final th in [UiThemeName.dark, UiThemeName.light, UiThemeName.maldives, UiThemeName.goldBlack]) {
      await pumpUi(tester, const Column(children: [UiCard(glass: true, child: Text('glass')), UiStatCard(label: 'a', value: '1', glass: true)]), theme: th);
      expect(rims(), findsNothing, reason: th.name);
    }
  });
}
