import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// 0.46.3: `mineSide: UiChatBubbleSide.right` keeps your own messages on the physical right and the other
/// side's on the left in LTR and RTL (the chat-app habit), with the tucked corner and the meta line
/// following, while each message's text keeps its own direction. The default (`end`) is unchanged.
void main() {
  const row = 358.0;
  const thaana = 'ޝުކުރިއްޔާ، މެންދުރު ފަހުން';
  const latin = 'Is 3 pm okay?';

  Widget page({required TextDirection dir, UiChatBubbleSide? side}) => Directionality(
        textDirection: dir,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: row,
            child: Column(key: const Key('row'), mainAxisSize: MainAxisSize.min, children: [
              UiChatBubble(key: const Key('them'), mineSide: side, meta: '09:40', child: const Text(latin)),
              UiChatBubble(key: const Key('me'), mine: true, mineSide: side, meta: '09:41', child: const Text(thaana)),
              UiChatBubble(key: const Key('meLatin'), mine: true, mineSide: side, meta: '09:41', child: const Text(latin)),
              UiChatBubble(key: const Key('themThaana'), mineSide: side, meta: '09:42', child: const Text(thaana)),
            ]),
          ),
        ),
      );

  Rect bubble(WidgetTester tester, Key k) => tester.getRect(find.descendant(of: find.byKey(k), matching: find.byType(Container)).first);
  Rect rowRect(WidgetTester tester) => tester.getRect(find.byKey(const Key('row')));
  BorderRadius corners(WidgetTester tester, Key k) {
    final c = tester.widget<Container>(find.descendant(of: find.byKey(k), matching: find.byType(Container)).first);
    final dir = Directionality.of(tester.element(find.byKey(k)));
    return (c.decoration! as BoxDecoration).borderRadius!.resolve(dir);
  }

  RenderParagraph para(WidgetTester tester, Key k, String text) => tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byKey(k), matching: find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText() == text)));

  /// Expects [k] at the physical right (or left) of the row, with its tucked corner at that bottom corner.
  void expectAt(WidgetTester tester, Key k, {required bool right}) {
    final b = bubble(tester, k), r = rowRect(tester);
    if (right) {
      expect(b.right, closeTo(r.right, 0.5), reason: '$k should sit at the right of the row');
      expect(b.left, greaterThan(r.left + 1), reason: '$k should not fill the row');
    } else {
      expect(b.left, closeTo(r.left, 0.5), reason: '$k should sit at the left of the row');
      expect(b.right, lessThan(r.right - 1), reason: '$k should not fill the row');
    }
    final c = corners(tester, k);
    if (right) {
      expect(c.bottomRight.x, lessThan(c.bottomLeft.x), reason: '$k tucked corner should be at the bottom right');
    } else {
      expect(c.bottomLeft.x, lessThan(c.bottomRight.x), reason: '$k tucked corner should be at the bottom left');
    }
  }

  for (final dir in TextDirection.values) {
    testWidgets('${dir.name} + right: yours on the right, theirs on the left, meta right, text in its own direction', (tester) async {
      await pumpUi(tester, page(dir: dir, side: UiChatBubbleSide.right));
      expect(tester.takeException(), isNull);
      expectAt(tester, const Key('me'), right: true);
      expectAt(tester, const Key('meLatin'), right: true);
      expectAt(tester, const Key('them'), right: false);
      expectAt(tester, const Key('themThaana'), right: false);
      for (final k in const [Key('me'), Key('them')]) {
        final meta = para(tester, k, k == const Key('me') ? '09:41' : '09:40');
        expect(meta.textAlign, TextAlign.right, reason: '$k meta should align to the bubble right');
      }
      // Thaana reads right to left and Latin left to right, whatever the page.
      expect(para(tester, const Key('me'), thaana).textDirection, TextDirection.rtl);
      expect(para(tester, const Key('themThaana'), thaana).textDirection, TextDirection.rtl);
      expect(para(tester, const Key('meLatin'), latin).textDirection, TextDirection.ltr);
      expect(para(tester, const Key('them'), latin).textDirection, TextDirection.ltr);
    });
  }

  testWidgets('rtl + default: unchanged, yours at the inline end (the left)', (tester) async {
    await pumpUi(tester, page(dir: TextDirection.rtl));
    expectAt(tester, const Key('me'), right: false);
    expectAt(tester, const Key('them'), right: true);
    // Text follows the page, as before.
    expect(para(tester, const Key('meLatin'), latin).textDirection, TextDirection.rtl);
    expect(para(tester, const Key('me'), '09:41').textAlign, TextAlign.end);
  });

  testWidgets('ltr + default: unchanged, yours on the right', (tester) async {
    await pumpUi(tester, page(dir: TextDirection.ltr));
    expectAt(tester, const Key('me'), right: true);
    expectAt(tester, const Key('them'), right: false);
    expect(para(tester, const Key('me'), thaana).textDirection, TextDirection.ltr);
  });

  testWidgets('follows UiConfig.chatMineSide when unset, and its own mineSide wins', (tester) async {
    Future<void> pump(UiChatBubbleSide? side) async {
      await tester.pumpWidget(UiApp(
        theme: UiThemeName.dark,
        config: const UiConfig(chatMineSide: UiChatBubbleSide.right),
        home: Align(alignment: Alignment.topLeft, child: page(dir: TextDirection.rtl, side: side)),
      ));
      await tester.pumpAndSettle();
    }

    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await pump(null);
    expectAt(tester, const Key('me'), right: true);
    expectAt(tester, const Key('them'), right: false);
    await pump(UiChatBubbleSide.end);
    expectAt(tester, const Key('me'), right: false);
    expect(const UiConfig().chatMineSide, UiChatBubbleSide.end);
  });

  test('uiChatTextDirection reads the first strong character', () {
    expect(uiChatTextDirection(const Text(thaana)), TextDirection.rtl);
    expect(uiChatTextDirection(const Text(latin)), TextDirection.ltr);
    expect(uiChatTextDirection(const Text('3 ޕީއެމް')), TextDirection.rtl);
    expect(uiChatTextDirection(const Text('2468')), isNull);
    expect(uiChatTextDirection(const Text.rich(TextSpan(text: 'Hi ޝުކުރިއްޔާ'))), TextDirection.ltr);
    expect(uiChatTextDirection(const SizedBox()), isNull);
  });
}
