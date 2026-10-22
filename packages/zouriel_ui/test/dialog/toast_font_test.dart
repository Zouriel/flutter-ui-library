import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// 0.44.2: UiToastHost.textStyle gives toasts an app font, as textStyle does on the text fields
/// (the Dhirumi nurse app: a Thaana name in "New message from ..." came out as boxes). Checked on
/// the style the paragraph is laid out with, not the Text widget's style argument: Text merges
/// into DefaultTextStyle, which can re-apply the library font package.

// "Aishath Nasma" in Thaana.
final _thaana = String.fromCharCodes(const [0x0787, 0x07A7, 0x0787, 0x07A8, 0x079D, 0x07A6, 0x078C, 0x07AA, 0x0020, 0x0782, 0x07A6, 0x0790, 0x07B0, 0x0789, 0x07A7]);

Future<UiToastController> _host(WidgetTester tester, TextStyle? style) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final c = UiToastController();
  addTearDown(c.dispose);
  await tester.pumpWidget(UiApp(
    builder: (context, child) => UiToastHost(controller: c, position: UiToastPosition.topCenter, textStyle: style, child: child!),
    home: const SizedBox.expand(),
  ));
  c.show('New message from $_thaana', title: _thaana, duration: Duration.zero, action: UiToastAction(label: 'ހުޅުވާ', run: () {}));
  await tester.pumpAndSettle();
  return c;
}

TextStyle _drawn(WidgetTester tester, String text) => tester.renderObject<RenderParagraph>(find.text(text)).text.style!;

void main() {
  testWidgets('a fontFamilyFallback reaches the title, the message and the action label as given; the library font stays first', (tester) async {
    await _host(tester, const TextStyle(fontFamilyFallback: ['Faruma', 'Noto Sans Thaana']));
    final lib = tester.element(find.byType(UiToastView)).uiText.body.fontFamily;
    for (final text in [_thaana, 'New message from $_thaana', 'ހުޅުވާ']) {
      final s = _drawn(tester, text);
      expect(s.fontFamilyFallback, ['Faruma', 'Noto Sans Thaana'], reason: text);
      expect(s.fontFamily, lib, reason: '$text: Latin and digits stay in the library font');
    }
    // The toast's own look is kept: size, weight, the muted message colour.
    final t = tester.element(find.byType(UiToastView)).ui;
    expect(_drawn(tester, _thaana).fontWeight, FontWeight.w600);
    expect(_drawn(tester, _thaana).fontSize, t.fontSizeSm);
    expect(_drawn(tester, 'New message from $_thaana').color, t.textMuted);
  });

  testWidgets("an app fontFamily is drawn as 'Faruma', not 'packages/zouriel_ui/Faruma'", (tester) async {
    await _host(tester, const TextStyle(fontFamily: 'Faruma'));
    for (final text in [_thaana, 'New message from $_thaana', 'ހުޅުވާ']) {
      expect(_drawn(tester, text).fontFamily, 'Faruma', reason: text);
    }
  });

  testWidgets('without textStyle nothing changes: the library font, no fallback', (tester) async {
    await _host(tester, null);
    final lib = tester.element(find.byType(UiToastView)).uiText.body.fontFamily;
    for (final text in [_thaana, 'New message from $_thaana', 'ހުޅުވާ']) {
      expect(_drawn(tester, text).fontFamily, lib, reason: text);
      expect(_drawn(tester, text).fontFamilyFallback, anyOf(isNull, isEmpty), reason: text);
    }
  });
}
