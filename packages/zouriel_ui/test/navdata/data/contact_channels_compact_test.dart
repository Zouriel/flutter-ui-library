import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../../helpers.dart';

const _all = [
  UiMessengerChannel(app: UiMessengerApp.whatsapp, semanticLabel: 'Send to Aisha on WhatsApp'),
  UiMessengerChannel(app: UiMessengerApp.viber, ticked: true, tickLabel: 'Opened 14:05'),
  UiMessengerChannel(app: UiMessengerApp.telegram),
];

UiContactChannels _compact({
  String? email = 'aisha@example.com',
  UiEmailStatus status = UiEmailStatus.sent,
  String? error,
  bool busy = false,
  String? phone = '+44 7400 123456',
  List<UiMessengerChannel> messengers = _all,
  ValueChanged<UiMessengerApp>? onApp,
  VoidCallback? onSend,
  VoidCallback? onRetry,
}) =>
    UiContactChannels(
      layout: UiContactLayout.compact,
      email: email,
      emailStatus: status,
      emailError: error,
      emailBusy: busy,
      emailTickLabel: 'Emailed 19:02',
      phone: phone,
      messengers: messengers,
      onEmailSend: onSend ?? () {},
      onEmailRetry: onRetry ?? () {},
      onMessengerPressed: onApp ?? (_) {},
    );

/// The block in a card on a [screen]-wide phone: 8 page margin + 12 card padding each side.
Widget _card(Widget child, {double screen = 390}) => SizedBox(
      width: screen,
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );

Rect _key(WidgetTester tester, String k) => tester.getRect(find.byKey(ValueKey(k)).first);
List<Rect> _boxes(WidgetTester tester) => [
      for (final e in find.descendant(of: find.byKey(const ValueKey('ui-contact-messengers')), matching: find.byKey(const ValueKey('ui-messenger-box'))).evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];

/// The right edge of the text actually drawn (not the box), for the value whose text is [text].
double _textRight(WidgetTester tester, String text) {
  final f = find.descendant(of: find.byWidgetPredicate((w) => w is Text && w.data == text), matching: find.byType(RichText));
  final p = tester.renderObject<RenderParagraph>(f);
  return tester.getTopLeft(f).dx + p.textSize.width;
}

void main() {
  for (final theme in [UiThemeName.light, UiThemeName.dark]) {
    for (final screen in [390.0, 1440.0]) {
      testWidgets('$theme at $screen: one line each, state after the text, buttons at the end of the number line, 64 tall', (tester) async {
        await pumpUi(tester, _card(_compact(), screen: screen), size: Size(screen, 800), theme: theme);
        expect(tester.takeException(), isNull);
        final block = tester.getRect(find.byType(UiContactChannels));
        expect(block.width, screen - 40);
        // No label column: the words "Email" / "Number" aren't drawn.
        expect(find.text('Email'), findsNothing);
        expect(find.text('Number'), findsNothing);
        final tick = _key(tester, 'ui-contact-sent');
        final emailRight = _textRight(tester, 'aisha@example.com');
        final emailText = tester.getRect(find.text('aisha@example.com'));
        expect(tick.left - emailRight, lessThanOrEqualTo(12));
        expect(tick.left - emailRight, greaterThanOrEqualTo(0));
        expect(tick.size, const Size(16, 16));
        expect((tick.center.dy - emailText.center.dy).abs(), lessThanOrEqualTo(0.5));
        final number = tester.getRect(find.text('+44 7400 123456'));
        final boxes = _boxes(tester);
        expect(boxes, hasLength(3));
        for (final b in boxes) {
          expect(b.size, const Size(28, 28));
          expect((b.center.dy - number.center.dy).abs(), lessThanOrEqualTo(0.5), reason: 'same line as the number');
        }
        expect((boxes.last.right - block.right).abs(), lessThanOrEqualTo(0.5), reason: 'at the block\'s end edge');
        expect(boxes[1].left - boxes[0].right, 8);
        // Value text starts after a 16 icon and an 8 gap.
        expect(emailText.left - block.left, 24);
        expect(number.left - block.left, 24);
        // ignore: avoid_print
        print('compact $theme $screen: block ${block.height.toStringAsFixed(1)} tall, tick ${(tick.left - emailRight).toStringAsFixed(1)} after the text, buttons end ${(boxes.last.right - block.right).toStringAsFixed(2)} from the edge, dy ${(boxes.first.center.dy - number.center.dy).toStringAsFixed(2)}');
        expect(block.height, lessThanOrEqualTo(76));
        expect(block.height, 64);
      });
    }
  }

  testWidgets('narrow: the buttons go under the number at indent 24, left-aligned', (tester) async {
    await pumpUi(tester, SizedBox(width: 200, child: _compact()));
    expect(tester.takeException(), isNull);
    final block = tester.getRect(find.byType(UiContactChannels));
    final number = tester.getRect(find.text('+44 7400 123456'));
    final boxes = _boxes(tester);
    expect(boxes.first.left - block.left, 24);
    expect(boxes.first.top, greaterThanOrEqualTo(number.bottom));
    expect(boxes.last.right, lessThan(block.right));
    // ignore: avoid_print
    print('narrow 200: buttons at y ${(boxes.first.top - block.top).toStringAsFixed(1)}, x ${(boxes.first.left - block.left).toStringAsFixed(1)}; block ${block.height.toStringAsFixed(1)} tall');
  });

  testWidgets('the wrap is measured, not a breakpoint: just enough room keeps one line, one px less wraps', (tester) async {
    const phone = '+44 7400 123456';
    await pumpUi(tester, SizedBox(width: 600, child: _compact(email: null, phone: phone)));
    final ctx = tester.element(find.byType(UiContactChannels));
    final t = ctx.ui;
    final style = ctx.uiText.body.copyWith(fontSize: t.fontSizeMd, height: 20 / t.fontSizeMd);
    final p = TextPainter(text: TextSpan(text: phone, style: style), textDirection: TextDirection.ltr)..layout();
    final need = 24 + p.width + 8 + UiContactChannels.buttonsWidth(3);
    p.dispose();
    for (final (w, oneLine) in [(need.ceilToDouble() + 1, true), (need.floorToDouble() - 1, false)]) {
      await pumpUi(tester, SizedBox(key: UniqueKey(), width: w, child: _compact(email: null, phone: phone)));
      final number = tester.getRect(find.text(phone));
      final boxes = _boxes(tester);
      expect((boxes.first.center.dy - number.center.dy).abs() < 0.5, oneLine, reason: 'at $w (needs $need)');
    }
  });

  testWidgets('email states sit right after the text: Send, Retry with the error under it, a spinner', (tester) async {
    var sent = 0, retried = 0;
    await pumpUi(tester, _card(_compact(status: UiEmailStatus.none, onSend: () => sent++)));
    final r1 = _textRight(tester, 'aisha@example.com');
    expect(_key(tester, 'ui-contact-send').left - r1, inInclusiveRange(0, 12));
    await tester.tap(find.text('Send'));
    expect(sent, 1);
    // The small button keeps its touch target, but the line stays 28 (the block 64 tall).
    expect(tester.getRect(find.byType(UiContactChannels)).height, 64);
    final send = tester.getRect(find.descendant(of: find.byKey(const ValueKey('ui-contact-send')), matching: find.byType(AnimatedContainer)).first);
    // ignore: avoid_print
    print('Send button painted ${send.height.toStringAsFixed(1)} tall in a 28 line');
    await tester.tapAt(Offset(send.center.dx, send.top - 8));
    expect(sent, 2, reason: '8px above the painted Send is still its touch target');
    await pumpUi(tester, _card(_compact(status: UiEmailStatus.bounced, error: 'Mailbox not found', onRetry: () => retried++)));
    expect(_key(tester, 'ui-contact-retry').left - _textRight(tester, 'aisha@example.com'), inInclusiveRange(0, 12));
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
    final err = _key(tester, 'ui-contact-error');
    final email = tester.getRect(find.text('aisha@example.com'));
    expect(err.left, email.left);
    final line = tester.getRect(find.ancestor(of: find.text('aisha@example.com'), matching: find.byType(Row)).first);
    expect(err.top - line.bottom, closeTo(4, 0.001));
    await tester.pumpWidget(UiApp(home: Align(alignment: Alignment.topLeft, child: _card(_compact(status: UiEmailStatus.none, busy: true)))));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_key(tester, 'ui-contact-busy').left - _textRight(tester, 'aisha@example.com'), inInclusiveRange(0, 12));
  });

  testWidgets('never wider than its parent: long values ellipsize at 220 wide, no overflow', (tester) async {
    await pumpUi(tester, SizedBox(width: 220, child: _compact(email: 'aishath.mohamed.abdulla.hassan@example.com', phone: '+960 777 1234 5678 9012 3456', status: UiEmailStatus.none)));
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byType(UiContactChannels)).width, 220);
    expect(tester.getRect(find.byKey(const ValueKey('ui-contact-send'))).right, lessThanOrEqualTo(220));
    // Wrapped: the number line is 28 tall and the icon centres on the number.
    final number = tester.getRect(find.text('+960 777 1234 5678 9012 3456'));
    final icon = tester.getRect(find.byType(UiIcon).at(1));
    expect((icon.center.dy - number.center.dy).abs(), lessThanOrEqualTo(0.5));
  });

  testWidgets('a long address shrinks with an ellipsis; the tick stays in view', (tester) async {
    const long = 'aishath.mohamed.abdulla.hassan@a-very-long-domain.example.com';
    await pumpUi(tester, _card(_compact(email: long)));
    expect(tester.takeException(), isNull);
    final block = tester.getRect(find.byType(UiContactChannels));
    expect(_key(tester, 'ui-contact-sent').right, lessThanOrEqualTo(block.right));
    expect(find.byWidgetPredicate((w) => w is UiTooltip && w.message == long), findsOneWidget);
  });

  testWidgets('semantics: "Email, …" and "Number, …"; tick name; buttons keep their names', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, _card(_compact()));
    expect(find.bySemanticsLabel('Email, aisha@example.com'), findsOneWidget);
    expect(find.bySemanticsLabel('Number, +44 7400 123456'), findsOneWidget);
    expect(find.bySemanticsLabel('Emailed 19:02'), findsOneWidget);
    expect(find.bySemanticsLabel('Send to Aisha on WhatsApp'), findsOneWidget);
    expect(find.bySemanticsLabel('Viber, Opened 14:05'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('44px hit areas: taps 7px above and below the 28px line, and the split gap, reach the right button', (tester) async {
    for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
      final got = <UiMessengerApp>[];
      await pumpUi(tester, Directionality(textDirection: dir, child: _card(_compact(onApp: got.add))));
      final boxes = _boxes(tester);
      final apps = [UiMessengerApp.whatsapp, UiMessengerApp.viber, UiMessengerApp.telegram];
      for (var i = 0; i < 3; i++) {
        await tester.tapAt(boxes[i].center);
        await tester.tapAt(Offset(boxes[i].center.dx, boxes[i].top - 7));
        await tester.tapAt(Offset(boxes[i].center.dx, boxes[i].bottom + 7));
      }
      expect(got, [for (final a in apps) ...[a, a, a]], reason: '$dir');
      got.clear();
      // 3px either side of the gap between the first two painted boxes.
      final (l, r) = dir == TextDirection.ltr ? (0, 1) : (1, 0);
      await tester.tapAt(Offset(boxes[l].right + 3, boxes[l].center.dy));
      await tester.tapAt(Offset(boxes[r].left - 3, boxes[r].center.dy));
      expect(got, [apps[l], apps[r]], reason: '$dir');
      // 9px out is past the hit area.
      got.clear();
      await tester.tapAt(Offset(boxes[0].center.dx, boxes[0].bottom + 9));
      expect(got, isEmpty, reason: '$dir');
    }
  });

  testWidgets('RTL: the buttons at the inline end (the left edge)', (tester) async {
    await pumpUi(tester, Directionality(textDirection: TextDirection.rtl, child: _card(_compact())));
    final block = tester.getRect(find.byType(UiContactChannels));
    final boxes = _boxes(tester);
    final leftmost = boxes.map((b) => b.left).reduce((a, b) => a < b ? a : b);
    expect((leftmost - block.left).abs(), lessThanOrEqualTo(0.5));
    expect(tester.getRect(find.text('aisha@example.com')).right, block.right - 24);
  });

  testWidgets('golden: compact cards (sent, failed, not sent, a narrow wrap)', (tester) async {
    await expectThemedGolden(tester, 'contact_channels_compact', height: 600, (context) {
      final t = context.ui;
      Widget card(Widget child, {double? width}) => Container(
            width: width,
            padding: EdgeInsets.all(t.space3),
            decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radiusLg)),
            child: child,
          );
      return Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [
        card(_compact()),
        card(_compact(status: UiEmailStatus.bounced, error: 'The address bounced: mailbox not found.', messengers: const [
          UiMessengerChannel(app: UiMessengerApp.whatsapp, ticked: true),
          UiMessengerChannel(app: UiMessengerApp.viber),
          UiMessengerChannel(app: UiMessengerApp.telegram),
        ])),
        card(_compact(status: UiEmailStatus.none, phone: null)),
        card(_compact(email: null, phone: '+1 202 555 0123')),
        card(_compact(status: UiEmailStatus.none), width: 230),
      ]);
    });
  });
}
