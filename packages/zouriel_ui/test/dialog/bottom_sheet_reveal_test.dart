import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// 0.47.3: a focused field in a sheet is never left behind its sticky footer or the keyboard. Dhirumi's
/// Find a nurse form: focusing "Contact phone" (its last field) left it under the "Find a nurse" bar
/// while she typed, because the body's viewport runs on under the footer and the platform's own
/// "show the caret" counted it as visible. A 390x844 phone.

final _footerButton = find.text('Find a nurse');

Widget _field(int i, FocusNode node, TextEditingController c) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: SizedBox(
        key: ValueKey('field-$i'),
        height: 48,
        child: EditableText(controller: c, focusNode: node, style: const TextStyle(fontSize: 14), cursorColor: const Color(0x00000000), backgroundCursorColor: const Color(0x00000000)),
      ),
    );

Future<List<FocusNode>> _pump(WidgetTester tester, {required int count, double keyboard = 0, List<double> snaps = const [0.5, 1.0], int snap = 1}) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * tester.view.devicePixelRatio);
  addTearDown(tester.view.reset);
  final nodes = [for (var i = 0; i < count; i++) FocusNode(debugLabel: 'field $i')];
  final texts = [for (var i = 0; i < count; i++) TextEditingController()];
  addTearDown(() {
    for (final n in nodes) {
      n.dispose();
    }
    for (final c in texts) {
      c.dispose();
    }
  });
  await tester.pumpWidget(UiApp(
    home: Stack(children: [
      UiBottomSheet(
        snaps: snaps,
        snap: snap,
        title: 'Ask a nurse to visit',
        closable: false,
        expandOnFocus: false,
        footer: UiButton(label: 'Find a nurse', block: true, onPressed: () {}),
        child: Column(children: [for (var i = 0; i < count; i++) _field(i, nodes[i], texts[i])]),
      ),
    ]),
  ));
  await tester.pumpAndSettle();
  return nodes;
}

double _footerTop(WidgetTester tester) =>
    tester.getTopLeft(find.ancestor(of: _footerButton, matching: find.byKey(const ValueKey('ui-bottom-sheet-footer')))).dy;

void main() {
  testWidgets('the last field, under the footer, scrolls clear of it when it takes focus', (tester) async {
    final nodes = await _pump(tester, count: 12);
    final last = find.byKey(const ValueKey('field-11'));
    expect(tester.getBottomLeft(last).dy, greaterThan(_footerTop(tester)), reason: 'the setup: it starts behind the footer');

    nodes.last.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(last).dy, lessThanOrEqualTo(_footerTop(tester)), reason: 'clear of the footer');
    expect(tester.getTopLeft(last).dy, greaterThan(tester.getBottomLeft(find.text('Ask a nurse to visit')).dy), reason: 'and below the title');
  });

  testWidgets('with the keyboard up, a field low in the form sits above the footer, which sits on the keyboard', (tester) async {
    final nodes = await _pump(tester, count: 12, keyboard: 300);
    final field = find.byKey(const ValueKey('field-9'));
    nodes[9].requestFocus();
    await tester.pumpAndSettle();
    final footerTop = _footerTop(tester);
    expect(footerTop, lessThanOrEqualTo(844 - 300 + 0.5), reason: 'the footer rests on the keyboard');
    expect(tester.getBottomLeft(field).dy, lessThanOrEqualTo(footerTop));
    expect(tester.getTopLeft(field).dy, greaterThanOrEqualTo(tester.getBottomLeft(find.text('Ask a nurse to visit')).dy));
  });

  testWidgets('the keyboard opening after focus moves the field up with it', (tester) async {
    final nodes = await _pump(tester, count: 12);
    final field = find.byKey(const ValueKey('field-7'));
    nodes[7].requestFocus();
    await tester.pumpAndSettle();
    // The keyboard slides up over a few frames.
    for (final k in [100.0, 200.0, 300.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: k * tester.view.devicePixelRatio);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(field).dy, lessThanOrEqualTo(_footerTop(tester)));
  });

  testWidgets('a field already in view does not move', (tester) async {
    final nodes = await _pump(tester, count: 12);
    final first = find.byKey(const ValueKey('field-0'));
    final before = tester.getTopLeft(first).dy;
    nodes.first.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(first).dy, before);
  });
}
