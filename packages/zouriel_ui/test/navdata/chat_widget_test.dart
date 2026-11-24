import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

void main() {
  testWidgets('UiChatWidget floating launcher, unread badge, teaser dismiss, and open/close', (tester) async {
    bool open = false;
    bool teaserDismissed = false;

    await pumpUi(
      tester,
      size: const Size(900, 700),
      StatefulBuilder(
        builder: (context, setState) => SizedBox(
          width: 900,
          height: 700,
          child: Stack(
            children: [
              UiChatWidget(
                open: open,
                onOpenChanged: (v) => setState(() => open = v),
                unread: 3,
                title: 'Addu Assistant',
                subtitle: 'Online',
                notice: 'Answers cite their source.',
                teaser: 'Hi there!',
                onTeaserDismissed: () => teaserDismissed = true,
                quickActions: UiChatActions(
                  actions: const [UiChatAction(id: 'a', label: 'Action A')],
                  onPick: (_) {},
                ),
                footer: UiChatComposer(onSend: (_) {}),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    UiChatBubble(child: Text('Hello!')),
                    UiChatSource(label: 'Guide', href: 'https://example.com'),
                    UiChatTyping(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.text('Hi there!'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Dismiss'));
    await tester.pumpAndSettle();
    expect(teaserDismissed, isTrue);
    expect(find.text('Hi there!'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Open the assistant'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(open, isTrue);
    expect(find.text('Addu Assistant'), findsOneWidget);
    expect(find.text('Answers cite their source.'), findsOneWidget);
    expect(find.text('Hello!'), findsOneWidget);
    expect(find.text('Action A'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(open, isFalse);
  });

  testWidgets('UiChatComposer sends trimmed text on Enter and clears', (tester) async {
    final sent = <String>[];
    await pumpUi(
      tester,
      SizedBox(
        width: 360,
        child: UiChatComposer(
          attach: true,
          onSend: sent.add,
        ),
      ),
    );

    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), '  Hello council  ');
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Send'));
    await tester.pump();
    expect(sent, ['Hello council']);
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, '');
  });

  testWidgets('UiChatActions emits pick and respects disabled', (tester) async {
    String? picked;
    await pumpUi(
      tester,
      UiChatActions(
        actions: const [
          UiChatAction(id: 'fill', label: 'Fill It In'),
          UiChatAction(id: 'open', label: 'Open'),
        ],
        onPick: (id) => picked = id,
      ),
    );

    await tester.tap(find.text('Fill It In'));
    await tester.pump();
    expect(picked, 'fill');

    picked = null;
    await pumpUi(
      tester,
      UiChatActions(
        disabled: true,
        actions: const [UiChatAction(id: 'fill', label: 'Fill It In')],
        onPick: (id) => picked = id,
      ),
    );
    await tester.tap(find.text('Fill It In'));
    await tester.pump();
    expect(picked, isNull);
  });

  testWidgets('UiChatWidget semantics and tap target guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await pumpUi(
        tester,
        size: const Size(900, 700),
        SizedBox(
          width: 900,
          height: 700,
          child: Stack(
            children: [
              UiChatWidget(
                open: true,
                title: 'Addu Assistant',
                notice: 'Answers cite their source.',
                footer: UiChatComposer(attach: true),
                child: const UiChatBubble(child: Text('Hello')),
              ),
            ],
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('chat widget pieces golden', (tester) async {
    await expectThemedGolden(
      tester,
      'chat_widget_pieces',
      width: 390,
      height: 360,
      (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: context.ui.space2,
        children: const [
          UiChatBubble(child: Text('You can apply online before 1 December 2026.')),
          UiChatSource(label: 'HR-REQ-2026-0014', href: 'https://example.com'),
          UiChatActions(actions: [UiChatAction(id: 'fill', label: 'Fill It In for Me')]),
          UiChatTyping(),
          UiChatComposer(attach: true),
        ],
      ),
    );
  });
}
