import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('a disabled control is reported as disabled, so dimmed text passes the contrast check', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const Padding(padding: EdgeInsets.all(16), child: UiButton(label: 'Disabled', onPressed: null)));
    final data = tester.getSemantics(find.text('Disabled')).getSemanticsData();
    expect(data.flagsCollection.isEnabled.toString(), contains('isFalse'));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
