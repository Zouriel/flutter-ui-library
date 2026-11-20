import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

void main() {
  testWidgets('drag is bounded, locks the non-overflow axis, works in a scroll view, and Save reports the draft', (tester) async {
    final image = await _image(tester, 200, 100);
    final saved = <UiRepositionPosition>[];
    tester.view.gestureSettings = ui.GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
    addTearDown(tester.view.reset);
    await pumpUi(tester, SingleChildScrollView(child: SizedBox(
      height: 900,
      child: Align(alignment: Alignment.topLeft, child: SizedBox.square(
        dimension: 100,
        child: UiReposition(image: image, imageSize: const Size(200, 100), active: true, onSave: saved.add),
      )),
    )));

    final state = tester.state<UiRepositionState>(find.byType(UiReposition));
    expect(state.editorOpen, isTrue);
    expect(state.frameReady, isTrue);
    expect(state.layoutReady, isTrue);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(state.draftPosition, const UiRepositionPosition());

    await tester.dragFrom(const Offset(50, 50), const Offset(30, 30), kind: PointerDeviceKind.touch);
    await tester.pump();
    expect(state.draftPosition.x, closeTo(25, 1)); // the 100px frame is edited at the 120px minimum
    expect(state.draftPosition.y, 50);
    expect(tester.getTopLeft(find.byType(SingleChildScrollView)), Offset.zero);

    await tester.dragFrom(const Offset(50, 50), const Offset(500, 0), kind: PointerDeviceKind.touch);
    await tester.pump();
    expect(state.draftPosition.x, 0);
    await tester.tap(find.text('Save'));
    expect(saved.single.x, 0);
    expect(saved.single.y, 50);
  });

  testWidgets('keyboard moves only the overflow axis, Enter saves, Escape cancels and restores', (tester) async {
    final image = await _image(tester, 200, 100);
    UiRepositionPosition? saved;
    var cancelled = 0;
    await pumpUi(tester, SizedBox.square(
      dimension: 100,
      child: UiReposition(
        image: image,
        imageSize: const Size(200, 100),
        active: true,
        position: const UiRepositionPosition(x: 40, y: 25),
        onSave: (p) => saved = p,
        onCancel: () => cancelled++,
      ),
    ));
    final state = tester.state<UiRepositionState>(find.byType(UiReposition));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(state.draftPosition, const UiRepositionPosition(x: 41, y: 25));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(saved, state.draftPosition);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(cancelled, 1);
    expect(state.draftPosition, const UiRepositionPosition(x: 40, y: 25));
  });

  testWidgets('scrim and editor semantics exist only while active and no route is pushed', (tester) async {
    final image = await _image(tester, 200, 100);
    final observer = _RouteObserver();
    var active = false;
    late StateSetter set;
    await tester.pumpWidget(UiApp(navigatorObservers: [observer], home: StatefulBuilder(builder: (context, update) {
      set = update;
      return Align(alignment: Alignment.topLeft, child: SizedBox.square(dimension: 100, child: UiReposition(image: image, imageSize: const Size(200, 100), active: active)));
    })));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsNothing);
    set(() => active = true);
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    expect(find.bySemanticsLabel('Reposition photo'), findsOneWidget);
    expect(observer.pushes, 1); // the app's initial route only
    set(() => active = false);
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsNothing);
    expect(find.bySemanticsLabel('Reposition photo'), findsNothing);
    expect(observer.pushes, 1);
  });

  testWidgets('cover hero and circle avatar render their saved focal point', (tester) async {
    final image = await _image(tester, 200, 100);
    await pumpUi(tester, Column(children: [
      SizedBox(width: 200, height: 100, child: UiCoverHero(image: image, position: const UiRepositionPosition(x: 20, y: 80))),
      SizedBox.square(dimension: 64, child: UiAvatar(image: image, position: const UiRepositionPosition(x: 80, y: 20))),
    ]));
    final alignments = tester.widgetList<Image>(find.byType(Image)).map((i) => i.alignment).whereType<Alignment>().toList();
    expect(alignments.any((a) => (a.x + .6).abs() < .001 && (a.y - .6).abs() < .001), isTrue);
    expect(alignments.any((a) => (a.x - .6).abs() < .001 && (a.y + .6).abs() < .001), isTrue);
  });

  testWidgets('active state golden', (tester) async {
    final image = await _image(tester, 240, 120);
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390, 300) * 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(home: Padding(
      padding: const EdgeInsets.only(left: 70, top: 70),
      child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 250, height: 100, child: UiReposition(image: image, imageSize: const Size(240, 120), active: true))),
    )));
    await tester.pumpAndSettle();
    await expectLater(find.byType(UiApp), matchesGoldenFile('goldens/reposition_active.png'));
  });

  testWidgets('a tiny frame is edited at 120px as an overlay: host size and page layout stay put', (tester) async {
    final image = await _image(tester, 200, 100);
    await pumpUi(tester, Align(alignment: Alignment.topLeft, child: Padding(
      padding: const EdgeInsets.only(left: 100, top: 100),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox.square(dimension: 36, child: UiReposition(image: image, imageSize: const Size(200, 100), circle: true, active: true)),
        const SizedBox(key: ValueKey('below'), width: 10, height: 10),
      ]),
    )));
    final state = tester.state<UiRepositionState>(find.byType(UiReposition));
    final frame = state.editorFrame!;
    expect(frame.width, greaterThanOrEqualTo(120));
    expect(frame.height, greaterThanOrEqualTo(120));
    expect(frame.center.dx, closeTo(118, 0.01));
    expect(tester.getSize(find.byType(UiReposition)), const Size(36, 36));
    expect(tester.getTopLeft(find.byKey(const ValueKey('below'))), const Offset(100, 136));
  });

  testWidgets('Save/Cancel bar stays inside the viewport with a 16px gutter for a frame at the left edge', (tester) async {
    final image = await _image(tester, 200, 100);
    await pumpUi(tester, Align(alignment: Alignment.topLeft, child: Padding(
      padding: const EdgeInsets.only(left: 4, top: 100),
      child: SizedBox.square(dimension: 100, child: UiReposition(image: image, imageSize: const Size(200, 100), active: true)),
    )));
    final view = tester.view.physicalSize / tester.view.devicePixelRatio;
    final bar = tester.getRect(find.ancestor(of: find.text('Cancel'), matching: find.byType(Padding)).first);
    final save = tester.getRect(find.text('Save'));
    expect(tester.getTopLeft(find.text('Cancel')).dx, greaterThanOrEqualTo(16));
    expect(save.right, lessThanOrEqualTo(view.width - 16));
    expect(bar.left, greaterThanOrEqualTo(16 - 0.01));
  });
}

class _RouteObserver extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) { pushes++; }

}

Future<_TestImage> _image(WidgetTester tester, int width, int height) async {
  late ui.Image image;
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..shader = ui.Gradient.linear(
      Offset.zero, Offset(width.toDouble(), height.toDouble()), const [Color(0xFF3B6EA8), Color(0xFFE0B860)],
    ));
    canvas.drawCircle(Offset(width * .72, height * .35), height * .2, Paint()..color = const Color(0xFFFFFFFF));
    image = await recorder.endRecording().toImage(width, height);
  });
  return _TestImage(image);
}

class _TestImage extends ImageProvider<_TestImage> {
  const _TestImage(this.image);
  final ui.Image image;
  @override
  Future<_TestImage> obtainKey(ImageConfiguration configuration) => Future.value(this);
  @override
  ImageStreamCompleter loadImage(_TestImage key, ImageDecoderCallback decode) => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image.clone())));
  @override
  bool operator ==(Object other) => other is _TestImage && identical(other.image, image);
  @override
  int get hashCode => identityHashCode(image);
}
