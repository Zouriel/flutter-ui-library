import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// [expectThemedGolden] with a hook that runs between building and capturing (tap, drag, advance
/// an animation), for the media/behaviour/fx areas whose interesting states are mid-gesture.
Future<void> expectThemedGoldenAfter(
  WidgetTester tester,
  String name,
  Widget Function(BuildContext context) build, {
  Future<void> Function(WidgetTester tester)? before,
  List<UiThemeName> themes = const [UiThemeName.dark, UiThemeName.light],
  double width = 390,
  double height = 300,
  Duration settle = const Duration(milliseconds: 400),
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = Size(width * themes.length, height) * 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(
    theme: themes.first,
    home: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final th in themes)
          SizedBox(
            width: width,
            child: UiThemeScope(theme: th, child: Padding(padding: const EdgeInsets.all(16), child: Builder(builder: build))),
          ),
      ],
    ),
  ));
  await tester.pump(settle);
  if (before != null) await before(tester);
  await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/$name.png'));
}

/// A small decoded test image of [w]×[h] in a vertical two-colour gradient, so tests and goldens
/// show real pixels without network or asset access.
Future<MemoryImage> testImage(WidgetTester tester, {int w = 64, int h = 48, int seed = 0}) async {
  late Uint8List bytes;
  await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final colors = [
      [const Color(0xFF3B6EA8), const Color(0xFFE0B860)],
      [const Color(0xFF7A4FA0), const Color(0xFF66C2A5)],
      [const Color(0xFFB34A3C), const Color(0xFFF2E1C2)],
    ][seed % 3];
    c.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h.toDouble()), colors));
    c.drawCircle(Offset(w * 0.7, h * 0.35), h * 0.18, Paint()..color = const Color(0xFFFFFFFF));
    final img = await rec.endRecording().toImage(w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    bytes = data!.buffer.asUint8List();
  });
  return MemoryImage(bytes);
}

/// [pumpUi] for content that animates forever (a spinner): pumps a few frames instead of settling.
Future<void> pumpUiFrames(WidgetTester tester, Widget child, {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(home: Align(alignment: Alignment.topLeft, child: child)));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
