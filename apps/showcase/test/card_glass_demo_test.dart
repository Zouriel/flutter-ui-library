import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/data_page.dart';

void main() {
  testWidgets('card glass demo shows all strengths over the image backdrop', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const UiApp(home: DataPage()));
    await tester.pumpAndSettle();
    final demo = find.byKey(const ValueKey('card-glass-demo'));
    await tester.scrollUntilVisible(demo, 400, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.runAsync(() => precacheImage(const AssetImage('assets/demo/poster.jpg'), tester.element(demo)));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('frosted'), findsOneWidget);
    expect(find.text('clear'), findsOneWidget);
    expect(find.text('liquid'), findsOneWidget);
    await expectLater(demo, matchesGoldenFile('goldens/card_glass_demo.png'));
  });
}
