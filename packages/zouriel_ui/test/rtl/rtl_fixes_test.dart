import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

// 0.46.1: three RTL / Thaana defects found by the Dhirumi web app, checked in the Flutter twin too.
// 1. An empty auto-direction field shows its placeholder at the start of an RTL page (the right).
// 2. A field clears when its value is set to '' straight after typing.
// 3. Thaana's marks below the line stay inside a UiBadge (and UiChip) pill.

/// A Thaana font for the ink check: MV Faruma (what the apps bundle) when this machine has it, else
/// Noto Sans Thaana. Neither ships with the library (Faruma is not ours to redistribute).
const _thaanaFonts = [
  '/home/zouriel/personal/dhirumi/brand/fonts/Faruma.ttf',
  '/usr/share/fonts/noto/NotoSansThaana-Regular.ttf',
];
String? _thaanaFont() {
  final env = Platform.environment['THAANA_FONT'];
  if (env != null && File(env).existsSync()) return env;
  for (final f in _thaanaFonts) {
    if (File(f).existsSync()) return f;
  }
  return null;
}

Future<void> _app(WidgetTester tester, Widget child, {TextDirection dir = TextDirection.rtl, UiConfig config = const UiConfig(), UiThemeName theme = UiThemeName.light}) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(theme: theme, config: config, textDirection: dir, home: Align(alignment: AlignmentDirectional.topStart, child: child)));
  await tester.pumpAndSettle();
}

/// The placeholder's paragraph: where its text starts and ends, in global coordinates.
({double left, double right}) _hintInk(WidgetTester tester, String hint) {
  final p = tester.renderObject<RenderParagraph>(find.text(hint));
  final box = p.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: hint.length));
  final origin = p.localToGlobal(Offset.zero);
  final left = box.map((b) => b.left).reduce((a, b) => a < b ? a : b) + origin.dx;
  final right = box.map((b) => b.right).reduce((a, b) => a > b ? a : b) + origin.dx;
  return (left: left, right: right);
}

void main() {
  group('empty auto-direction fields show the placeholder at the start (0.46.1)', () {
    const hint = 'ނަން ލިޔުއްވާ';
    for (final dir in [UiTextDir.auto, null]) {
      testWidgets('UiInput / UiTextarea, dir $dir, in RTL: the hint sits at the right; in LTR at the left', (tester) async {
        for (final page in TextDirection.values) {
          for (final field in ['input', 'textarea']) {
            final key = GlobalKey();
            await _app(
              tester,
              SizedBox(
                key: key,
                width: 300,
                child: field == 'input' ? UiInput(dir: dir, placeholder: hint) : UiTextarea(dir: dir, placeholder: hint, rows: 1),
              ),
              dir: page,
            );
            final frame = tester.getRect(find.byKey(key));
            final ink = _hintInk(tester, hint);
            final reason = '$field dir=$dir page=$page frame=$frame ink=$ink';
            if (page == TextDirection.rtl) {
              expect(frame.right - ink.right, lessThan(24), reason: reason);
              expect(ink.left - frame.left, greaterThan(100), reason: reason);
            } else {
              expect(ink.left - frame.left, lessThan(24), reason: reason);
              expect(frame.right - ink.right, greaterThan(100), reason: reason);
            }
          }
        }
      });
    }

    testWidgets('typed Latin text in an RTL page turns an auto field left to right, and clearing it goes back', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await _app(tester, SizedBox(width: 300, child: UiInput(controller: c, dir: UiTextDir.auto, placeholder: hint)));
      TextDirection dirOfEditor() => tester.widget<EditableText>(find.byType(EditableText)).textDirection ?? Directionality.of(tester.element(find.byType(EditableText)));
      expect(dirOfEditor(), TextDirection.rtl);
      c.text = 'hello';
      await tester.pump();
      expect(dirOfEditor(), TextDirection.ltr);
      c.text = '';
      await tester.pump();
      expect(dirOfEditor(), TextDirection.rtl);
      expect(find.text(hint), findsOneWidget);
    });
  });

  group('fields clear when the value is set to "" straight after typing (0.46.1)', () {
    for (final field in ['input', 'textarea']) {
      testWidgets('$field, controlled with value / onChanged', (tester) async {
        var value = '';
        late StateSetter rebuild;
        await _app(
          tester,
          StatefulBuilder(builder: (context, setState) {
            rebuild = setState;
            return SizedBox(
              width: 300,
              child: field == 'input'
                  ? UiInput(value: value, onChanged: (v) => value = v, placeholder: 'Message')
                  : UiTextarea(value: value, onChanged: (v) => value = v, placeholder: 'Message', rows: 1),
            );
          }),
          dir: TextDirection.ltr,
        );
        await tester.enterText(find.byType(EditableText), 'hello');
        expect(value, 'hello');
        // Send: the app sets '' at once, without a frame in between.
        rebuild(() => value = '');
        await tester.pump();
        expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, '');
        // A parent that never stored the typed text (it stays '') still clears the field on rebuild.
        await tester.enterText(find.byType(EditableText), 'again');
        value = '';
        rebuild(() {});
        await tester.pump();
        expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, '');
      });

      testWidgets('$field, with a controller', (tester) async {
        final c = TextEditingController();
        addTearDown(c.dispose);
        await _app(
          tester,
          SizedBox(width: 300, child: field == 'input' ? UiInput(controller: c) : UiTextarea(controller: c, rows: 1)),
          dir: TextDirection.ltr,
        );
        await tester.enterText(find.byType(EditableText), 'hello');
        c.clear();
        await tester.pump();
        expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, '');
        expect(c.text, '');
      });
    }
  });

  group('Thaana marks stay inside badge and chip pills (0.46.1)', () {
    final font = _thaanaFont();
    setUpAll(() async {
      if (font == null) return;
      final loader = FontLoader('AuditThaana')..addFont(Future.value(ByteData.sublistView(File(font).readAsBytesSync())));
      await loader.load();
    });

    /// The rows of dark ink (the text) of [pill] drawn black on white, against the pill's box.
    Future<({double top, double bottom, double height})> inkGaps(WidgetTester tester, Widget pill, {required TextDirection dir, UiDensity density = UiDensity.comfortable}) async {
      const boundary = Key('boundary'), pillKey = Key('pill');
      await _app(
        tester,
        RepaintBoundary(
          key: boundary,
          child: Container(
            color: const Color(0xFFFFFFFF),
            padding: const EdgeInsets.all(10),
            child: KeyedSubtree(key: pillKey, child: pill),
          ),
        ),
        dir: dir,
        config: UiConfig(fontFamilyFallback: const ['AuditThaana'], density: density),
      );
      final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundary));
      const scale = 4.0;
      final image = (await tester.runAsync(() => ro.toImage(pixelRatio: scale)))!;
      final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!.buffer.asUint8List();
      final w = image.width, h = image.height;
      image.dispose();
      var top = h, bottom = -1;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          if (bytes[i] < 90 && bytes[i + 1] < 90 && bytes[i + 2] < 90 && bytes[i + 3] > 200) {
            if (y < top) top = y;
            if (y > bottom) bottom = y;
          }
        }
      }
      final origin = ro.localToGlobal(Offset.zero);
      final pillRect = tester.getRect(find.byKey(pillKey)).shift(-origin);
      // The visible pill is the decorated box inside (a chip on a phone sits in a taller touch row).
      final deco = find.descendant(of: find.byKey(pillKey), matching: find.byType(DecoratedBox)).first;
      final r = tester.getRect(deco).shift(-origin);
      expect(pillRect.contains(r.center), isTrue);
      return (top: top / scale - r.top - 1, bottom: r.bottom - 1 - (bottom + 1) / scale, height: r.height);
    }

    const thaana = ['ދުވަސް ޓީއްގައި ކުރީ', 'މިހާރު ހުޅުވާލާފައި', 'ބުރާސްފަތި'];
    for (final density in [UiDensity.comfortable, UiDensity.compact]) {
      testWidgets('UiBadge in RTL ($density): every Thaana label keeps 1px inside the border', (tester) async {
        for (final label in thaana) {
          final g = await inkGaps(tester, UiBadge(label: label), dir: TextDirection.rtl, density: density);
          expect(g.top, greaterThanOrEqualTo(1), reason: '$label $g');
          expect(g.bottom, greaterThanOrEqualTo(1), reason: '$label $g');
        }
      }, skip: font == null /* no Thaana font on this machine: set THAANA_FONT */);

      testWidgets('UiChip in RTL ($density): Thaana keeps 1px inside the border', (tester) async {
        for (final label in thaana) {
          final g = await inkGaps(tester, UiChip(label: label), dir: TextDirection.rtl, density: density);
          expect(g.top, greaterThanOrEqualTo(1), reason: '$label $g');
          expect(g.bottom, greaterThanOrEqualTo(1), reason: '$label $g');
        }
      }, skip: font == null /* no Thaana font on this machine: set THAANA_FONT */);
    }

    testWidgets('a Thaana label in an LTR app gets the room too; Latin badges keep their height (within 2px)', (tester) async {
      final g = await inkGaps(tester, const UiBadge(label: 'ދުވަސް ޓީއްގައި ކުރީ'), dir: TextDirection.ltr);
      expect(g.bottom, greaterThanOrEqualTo(1), reason: '$g');
      for (final density in [UiDensity.comfortable, UiDensity.compact]) {
        final ltr = await inkGaps(tester, const UiBadge(label: 'Verified 46 min ago'), dir: TextDirection.ltr, density: density);
        final rtl = await inkGaps(tester, const UiBadge(label: 'Verified 46 min ago'), dir: TextDirection.rtl, density: density);
        final base = density == UiDensity.compact ? 18.0 : 20.0;
        expect((ltr.height - base).abs(), lessThanOrEqualTo(2), reason: 'LTR $density ${ltr.height}');
        expect((rtl.height - base).abs(), lessThanOrEqualTo(2), reason: 'RTL $density ${rtl.height}');
      }
    }, skip: font == null /* no Thaana font on this machine: set THAANA_FONT */);
  });
}
