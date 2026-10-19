import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

void main() {
  testWidgets('switch, textarea and token input take sm for dense panels', (tester) async {
    double fontOf(Finder f) => tester.widget<Text>(find.descendant(of: f, matching: find.byType(Text)).first).style?.fontSize ??
        DefaultTextStyle.of(tester.element(find.descendant(of: f, matching: find.byType(Text)).first)).style.fontSize!;
    late UiTokens t;
    await pumpUi(
      tester,
      Builder(builder: (context) {
        t = context.ui;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          UiSwitch(key: const Key('md'), value: true, onChanged: (_) {}, label: 'On'),
          UiSwitch(key: const Key('sm'), value: true, onChanged: (_) {}, label: 'On', size: UiSize.sm),
          const SizedBox(width: 300, child: UiTextarea(key: Key('ta'), value: 'x', size: UiSize.sm)),
          SizedBox(width: 300, child: UiTokenInput(key: const Key('ti'), value: const [UiTokenRun.text('x')], onChanged: (_) {}, multiline: false, size: UiSize.sm)),
        ]);
      }),
    );
    expect(fontOf(find.byKey(const Key('md'))), t.fontSizeMd);
    expect(fontOf(find.byKey(const Key('sm'))), t.fontSizeSm);
    expect(tester.getSize(find.byKey(const Key('sm'))).height, lessThan(tester.getSize(find.byKey(const Key('md'))).height + 0.1));
    final editable = tester.widget<EditableText>(find.descendant(of: find.byKey(const Key('ta')), matching: find.byType(EditableText)));
    expect(editable.style.fontSize, t.fontSizeSm);
    final token = tester.widget<EditableText>(find.descendant(of: find.byKey(const Key('ti')), matching: find.byType(EditableText)));
    expect(token.style.fontSize, t.fontSizeSm);
  });
}
