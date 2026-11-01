import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

void main() {
  testWidgets('empty, the field has the row, so its placeholder is not cut short', (tester) async {
    await pumpUi(tester, const SizedBox(width: 320, child: UiMultiSelect(options: [UiComboboxOption(label: 'A', value: 'a')], placeholder: 'Pick roles')));
    await tester.pump();
    expect(tester.getSize(find.byType(EditableText)).width, greaterThan(200));
  });

  testWidgets('with a choice, the field sits after the chip and fits on its row', (tester) async {
    await pumpUi(tester, const SizedBox(width: 320, child: UiMultiSelect(options: [UiComboboxOption(label: 'A', value: 'a')], value: ['a'], placeholder: 'Pick roles')));
    await tester.pump();
    expect(find.text('A'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(EditableText)).width, lessThan(200));
  });
}
