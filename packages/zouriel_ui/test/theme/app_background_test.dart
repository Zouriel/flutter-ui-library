import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

void main() {
  testWidgets('a transparent UiApp background stays transparent through a pushed page route', (tester) async {
    await tester.pumpWidget(UiApp(
      background: const Color(0x00000000),
      home: UiButton(label: 'Open', onPressed: () => Navigator.of(tester.element(find.text('Open'))).pushNamed('/next')),
      routes: {'/next': (_) => const Text('Next page')},
    ));
    await tester.pumpAndSettle();

    for (final box in tester.widgetList<ColoredBox>(find.byType(ColoredBox))) {
      expect(box.color.a, 0, reason: 'transparent UiApp must not paint an opaque root background');
    }

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Next page'), findsOneWidget);
    for (final box in tester.widgetList<ColoredBox>(find.byType(ColoredBox))) {
      expect(box.color.a, 0, reason: 'transparent UiApp must not paint an opaque page background');
    }
  });
}
