import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// 0.42.2: a chat bubble must keep a short word on one line and wrap long text at 80% of the row,
/// whatever its parent does with it (the web bubble broke "okay" as "ok/ay" in a column aligned to
/// the start). Phone width: a 390 view with 16 gutters, so a 358 row.
void main() {
  const row = 358.0;
  final url = 'https://example.com/${'a1b2c3d4e5' * 18}'; // 200 characters, no break opportunity
  const longText = 'Arriving in about ten minutes, the traffic near the harbour is slow today. Is there parking nearby?';

  Widget page(Widget child, {TextDirection dir = TextDirection.ltr}) => Directionality(
        textDirection: dir,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: row, child: child)),
      );

  RenderParagraph para(WidgetTester tester, Key k) =>
      tester.renderObject<RenderParagraph>(find.descendant(of: find.byKey(k), matching: find.byType(RichText)).first);
  int lines(WidgetTester tester, Key k) {
    final p = para(tester, k);
    final text = p.text.toPlainText();
    return p.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: text.length)).map((b) => b.top.round()).toSet().length;
  }

  Rect bubble(WidgetTester tester, Key k) => tester.getRect(find.descendant(of: find.byKey(k), matching: find.byType(Container)).first);
  Rect rowRect(WidgetTester tester) => tester.getRect(find.byKey(const Key('row')));

  void expectSide(WidgetTester tester, Key k, {required bool mine, required TextDirection dir}) {
    final b = bubble(tester, k), r = rowRect(tester);
    final end = mine == (dir == TextDirection.ltr);
    if (end) {
      expect(b.right, closeTo(r.right, 0.5), reason: '$k should sit at the right of the row');
    } else {
      expect(b.left, closeTo(r.left, 0.5), reason: '$k should sit at the left of the row');
    }
  }

  void expectWrapsInside(WidgetTester tester, Key k, double width) {
    final b = bubble(tester, k);
    expect(b.width, lessThanOrEqualTo(width * 0.8 + 0.5), reason: 'bubble ${b.width} wider than 80% of $width');
    expect(lines(tester, k), greaterThan(1));
    final p = para(tester, k);
    expect(p.size.width, lessThanOrEqualTo(b.width), reason: 'text runs outside its bubble');
  }

  for (final dir in TextDirection.values) {
    for (final align in [CrossAxisAlignment.start, CrossAxisAlignment.end, CrossAxisAlignment.center, CrossAxisAlignment.stretch]) {
      testWidgets('column ${align.name}, ${dir.name}: "okay" on one line at its own side, long text wraps at 80%', (tester) async {
        await pumpUi(
          tester,
          page(
            dir: dir,
            Column(key: const Key('row'), crossAxisAlignment: align, mainAxisSize: MainAxisSize.min, children: [
              const UiChatBubble(key: Key('them'), child: Text('okay')),
              const UiChatBubble(key: Key('me'), mine: true, child: Text('okay')),
              const UiChatBubble(key: Key('meta'), mine: true, meta: '09:41 · Read', child: Text('ok')),
              UiChatBubble(key: const Key('url'), child: Text(url)),
              const UiChatBubble(key: Key('long'), mine: true, child: Text(longText)),
            ]),
          ),
        );
        expect(tester.takeException(), isNull);
        for (final k in const [Key('them'), Key('me'), Key('meta')]) {
          expect(lines(tester, k), 1, reason: '$k wrapped');
        }
        expectSide(tester, const Key('them'), mine: false, dir: dir);
        expectSide(tester, const Key('me'), mine: true, dir: dir);
        expectSide(tester, const Key('url'), mine: false, dir: dir);
        expectSide(tester, const Key('long'), mine: true, dir: dir);
        expectWrapsInside(tester, const Key('url'), row);
        expectWrapsInside(tester, const Key('long'), row);
      });
    }
  }

  testWidgets('inside an IntrinsicWidth: lays out, one line, at its side', (tester) async {
    await pumpUi(
      tester,
      page(Column(key: const Key('row'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        const IntrinsicWidth(child: UiChatBubble(key: Key('them'), child: Text('okay'))),
        const IntrinsicWidth(child: UiChatBubble(key: Key('meta'), meta: '09:41 · Read', child: Text('ok'))),
        IntrinsicWidth(child: UiChatBubble(key: const Key('url'), child: Text(url))),
      ])),
    );
    expect(tester.takeException(), isNull);
    expect(lines(tester, const Key('them')), 1);
    expect(lines(tester, const Key('meta')), 1);
    expectSide(tester, const Key('them'), mine: false, dir: TextDirection.ltr);
    expectWrapsInside(tester, const Key('url'), row);
  });

  for (final dir in TextDirection.values) {
    testWidgets('in a Row, ${dir.name}: short stays on one line, long wraps at 80% of the screen without overflowing', (tester) async {
      await pumpUi(
        tester,
        page(
          dir: dir,
          Column(key: const Key('row'), crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [UiChatBubble(key: Key('them'), child: Text('okay'))]),
            Row(children: [UiChatBubble(key: const Key('url'), child: Text(url))]),
            const Row(children: [Expanded(child: UiChatBubble(key: Key('me'), mine: true, child: Text('okay')))]),
          ]),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(lines(tester, const Key('them')), 1);
      expect(lines(tester, const Key('me')), 1);
      expectSide(tester, const Key('me'), mine: true, dir: dir);
      // A Row gives its children unbounded width; the bubble falls back to 80% of the screen.
      expectWrapsInside(tester, const Key('url'), 390);
      final b = bubble(tester, const Key('url'));
      expect(b.left, greaterThanOrEqualTo(-0.5));
      expect(b.right, lessThanOrEqualTo(390.5));
    });
  }
}
