import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// The sheet's surface: the FocusScope wrapping its panel.
Rect _surface(WidgetTester tester) => tester.getRect(find.descendant(of: find.byType(UiBottomSheet), matching: find.byType(FocusScope)).last);

Future<List<double>> _sheet(WidgetTester tester, {required double width, double? maxWidth, bool backdrop = false, TextDirection dir = TextDirection.ltr}) async {
  tester.view.physicalSize = Size(width, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final covers = <double>[];
  await tester.pumpWidget(UiApp(
    home: Directionality(
      textDirection: dir,
      child: Stack(children: [
        const Center(child: Text('Page')),
        UiBottomSheet(
          // A fresh sheet per setup, so each reports its own cover.
          key: ValueKey((width, maxWidth, backdrop, dir)),
          snaps: const [0.3, 0.6],
          title: 'Doctors',
          maxWidth: maxWidth,
          backdrop: backdrop,
          onCoverChanged: covers.add,
          child: const Text('Body'),
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
  return covers;
}

void main() {
  for (final dir in TextDirection.values) {
    testWidgets('on a wide screen maxWidth caps the sheet and centres it (${dir.name})', (tester) async {
      await _sheet(tester, width: 1280, maxWidth: 560, dir: dir);
      final r = _surface(tester);
      expect(r.width, closeTo(560, 0.5));
      expect(r.left, closeTo((1280 - 560) / 2, 0.5));
      expect(r.top, closeTo(844 - 844 * 0.3, 1));
      // Handle and title row are inside the capped surface.
      final title = tester.getRect(find.text('Doctors'));
      expect(title.left, greaterThanOrEqualTo(r.left));
      expect(title.right, lessThanOrEqualTo(r.right));
      final handle = tester.getRect(find.byWidgetPredicate((w) => w is UiInteractive && (w.semanticLabel?.startsWith('Make') ?? false)));
      expect(handle.center.dx, closeTo(640, 0.5));
      expect(handle.width, lessThanOrEqualTo(560.5));
    });
  }

  testWidgets('below maxWidth (and without one) it is the full width', (tester) async {
    await _sheet(tester, width: 390, maxWidth: 560);
    expect(_surface(tester).width, closeTo(390, 0.5));
    expect(_surface(tester).left, 0);
    await _sheet(tester, width: 1280);
    expect(_surface(tester).width, closeTo(1280, 0.5));
  });

  testWidgets('the cover it reports is the same height with or without the cap', (tester) async {
    final full = await _sheet(tester, width: 1280);
    final capped = await _sheet(tester, width: 1280, maxWidth: 560);
    expect(full.last, closeTo(844 * 0.3, 0.5));
    expect(capped.last, full.last);
  });

  testWidgets('the sides beside a capped sheet stay usable, and a modal backdrop still covers the whole screen', (tester) async {
    await _sheet(tester, width: 1280, maxWidth: 560);
    // Beside the sheet, at its height: the page, not the sheet, gets the hit.
    final besides = tester.hitTestOnBinding(const Offset(40, 800)).path.map((e) => e.target).whereType<RenderObject>();
    expect(besides.any((o) => _inSheet(tester, o)), isFalse);
    final inside = tester.hitTestOnBinding(const Offset(640, 800)).path.map((e) => e.target).whereType<RenderObject>();
    expect(inside.any((o) => _inSheet(tester, o)), isTrue);
    await _sheet(tester, width: 1280, maxWidth: 560, backdrop: true);
    expect(tester.getRect(find.byType(UiBackdrop)), const Rect.fromLTWH(0, 0, 1280, 844));
  });
}

/// Whether [o] belongs to the sheet's own surface.
bool _inSheet(WidgetTester tester, RenderObject o) {
  final surface = tester.renderObject(find.descendant(of: find.byType(UiBottomSheet), matching: find.byType(FocusScope)).last);
  for (RenderObject? n = o; n != null; n = n.parent) {
    if (n == surface) return true;
  }
  return false;
}
