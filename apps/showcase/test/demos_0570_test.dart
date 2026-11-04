import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/messenger_sections.dart';

/// 0.57.0 showcase demos: messenger buttons, contact channels, the table's custom cells, phone input.

Future<void> _pump(WidgetTester tester, Widget section) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(home: SingleChildScrollView(padding: const EdgeInsets.all(16), child: section)));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('messenger buttons: a press ticks the button with a time', (tester) async {
    await _pump(tester, const MessengerButtonSection());
    expect(tester.takeException(), isNull);
    final first = find.byType(UiMessengerButton).first;
    expect(tester.widget<UiMessengerButton>(first).ticked, isFalse);
    await tester.tap(first);
    await tester.pump();
    expect(tester.widget<UiMessengerButton>(first).ticked, isTrue);
    expect(tester.widget<UiMessengerButton>(first).tickLabel, startsWith('Opened '));
    expect(find.text('WhatsApp pressed'), findsOneWidget);
  });

  testWidgets('contact channels: pressing a messenger ticks it; Retry shows a spinner, then the tick', (tester) async {
    await _pump(tester, const ContactChannelsSection());
    expect(tester.takeException(), isNull);
    final telegram = find.bySemanticsLabel('Send to Aisha on Telegram');
    expect(telegram, findsOneWidget);
    await tester.tap(find.byType(UiMessengerButton).at(2));
    await tester.pump();
    expect(tester.widget<UiMessengerButton>(find.byType(UiMessengerButton).at(2)).ticked, isTrue);
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.byType(UiSpinner), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Retry'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('table custom cells: badges and messenger buttons in cells', (tester) async {
    await _pump(tester, const TableCellSection());
    expect(tester.takeException(), isNull);
    expect(find.descendant(of: find.byType(UiTable<({String name, String status, bool opened})>), matching: find.byType(UiBadge)), findsNWidgets(3));
    await tester.tap(find.byType(UiMessengerButton).first);
    await tester.pump();
    expect(find.text('WhatsApp for Aisha Mohamed'), findsOneWidget);
  });

  testWidgets('phone input: the value shows live; the form validates', (tester) async {
    await _pump(tester, const PhoneInputSection());
    expect(tester.takeException(), isNull);
    expect(find.text('Value: null'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).first, '07700 900123');
    await tester.pump();
    expect(find.text('Value: +447700900123'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Fix the errors'), findsOneWidget);
  });
}
