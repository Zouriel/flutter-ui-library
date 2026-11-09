import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/design_tools_page.dart';

/// 0.67.0 showcase demo: the image editor.

void main() {
  testWidgets('image editor demo: loads the photo, erases with a finger, crops to 1:1 and exports', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    tester.view.gestureSettings = ui.GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const UiApp(home: DesignToolsPage()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    final editor = find.byType(UiImageEditor);
    await tester.ensureVisible(editor);
    await tester.pumpAndSettle();
    final c = tester.widget<UiImageEditor>(editor).controller;
    // Real image decoding only finishes outside the test's fake clock: load again inside runAsync.
    await tester.runAsync(() async {
      await c.loadImage(imageEditorDemoPicture);
      for (var i = 0; i < 100 && !c.loaded; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
    expect(c.loaded, isTrue);
    expect(c.naturalSize, const Size(1200, 800));
    expect(find.textContaining('Crop 1200 x 800 at 0, 0'), findsOneWidget);

    // One finger erases across the middle.
    final box = tester.getRect(editor);
    final g = await tester.startGesture(box.center - const Offset(80, 0), kind: PointerDeviceKind.touch);
    for (var i = 1; i <= 8; i++) {
      await g.moveTo(box.center + Offset(-80 + i * 20, 0));
    }
    await g.up();
    await tester.pump();
    expect(c.canUndo, isTrue);
    expect(c.dirty, isTrue);

    await tester.ensureVisible(find.text('Crop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crop'));
    await tester.pump();
    await tester.tap(find.text('1:1'));
    await tester.pump();
    expect(c.crop, const UiImageCrop(200, 0, 800, 800));

    await tester.ensureVisible(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Export'));
      for (var i = 0; i < 100 && find.textContaining('Exported:').evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pump();
    expect(find.textContaining('Exported: 800 x 800 PNG'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
