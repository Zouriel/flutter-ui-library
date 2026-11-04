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

/// A guest card: a 16px padded box, as an app would put it.
Widget _card(Widget child, {double width = 390}) => SizedBox(width: width, child: Padding(padding: const EdgeInsets.all(16), child: child));

UiContactChannels _channels({
  String? email = 'aisha@example.com',
  UiEmailStatus status = UiEmailStatus.none,
  String? error,
  bool busy = false,
  String? phone = '+960 777 1234',
  List<UiMessengerChannel> messengers = _all,
  VoidCallback? onSend,
  VoidCallback? onRetry,
  ValueChanged<UiMessengerApp>? onApp,
  String? emailTickLabel,
  String? emailLabel,
}) =>
    UiContactChannels(
      email: email,
      emailStatus: status,
      emailError: error,
      emailBusy: busy,
      emailTickLabel: emailTickLabel,
      emailLabel: emailLabel,
      phone: phone,
      messengers: messengers,
      onEmailSend: onSend ?? () {},
      onEmailRetry: onRetry ?? () {},
      onMessengerPressed: onApp ?? (_) {},
    );

List<Rect> _rects(WidgetTester tester, Key key) => [for (final e in find.byKey(key).evaluate()) tester.getRect(find.byWidget(e.widget))];

void main() {
  testWidgets('columns line up: labels and values start at the same x in every row; buttons start at the value x', (tester) async {
    await pumpUi(tester, _card(_channels()));
    final labels = _rects(tester, const ValueKey('ui-contact-label'));
    final values = _rects(tester, const ValueKey('ui-contact-value'));
    expect(labels, hasLength(2));
    expect(values, hasLength(2));
    expect(labels[0].left, labels[1].left);
    expect(labels[0].width, labels[1].width);
    expect(labels[0].width, greaterThanOrEqualTo(64));
    expect(values[0].left, values[1].left);
    expect(values[0].left - labels[0].right, 12);
    final apps = tester.getRect(find.byKey(const ValueKey('ui-contact-messengers')));
    final firstButton = tester.getRect(find.byType(UiMessengerButton).first);
    expect(firstButton.left, values[0].left);
    expect(apps.right, 390 - 16);
    // Rows 8 apart, each at least 32 tall; the messenger row has 6 above the buttons for the badges.
    final rows = [tester.getRect(find.byKey(const ValueKey('ui-contact-status'))), values[1]];
    expect(rows[0].height, greaterThanOrEqualTo(32));
    expect(firstButton.top - apps.top, greaterThanOrEqualTo(6));
  });

  testWidgets('a long label widens the label column for every row', (tester) async {
    await pumpUi(tester, _card(_channels(emailLabel: 'Email address at work')));
    final labels = _rects(tester, const ValueKey('ui-contact-label'));
    expect(labels[0].width, greaterThan(64));
    expect(labels[1].width, labels[0].width);
    final values = _rects(tester, const ValueKey('ui-contact-value'));
    expect(values[0].left, values[1].left);
  });

  testWidgets('status column: at least 44 wide, content at the inline end; the value takes the rest', (tester) async {
    await pumpUi(tester, _card(_channels(status: UiEmailStatus.sent)));
    final status = tester.getRect(find.byKey(const ValueKey('ui-contact-status')));
    expect(status.width, 44);
    expect(status.right, 390 - 16);
    final tick = tester.getRect(find.byKey(const ValueKey('ui-contact-sent')));
    expect(tick.width, 44);
    expect(tick.right, status.right);
    // The value column runs up to 12 before the status column (its Text hugs, so check its parent).
    final valueCol = tester.getRect(find.ancestor(of: find.byKey(const ValueKey('ui-contact-value')).first, matching: find.byType(Expanded)).first);
    expect(status.left - valueCol.right, 12);
    await pumpUi(tester, _card(_channels()));
    final send = tester.getRect(find.byKey(const ValueKey('ui-contact-send')));
    expect(send.right, 390 - 16);
    expect(tester.getRect(find.byKey(const ValueKey('ui-contact-status'))).width, greaterThanOrEqualTo(44));
  });

  testWidgets('email states: Send, the sent tick, Retry with its error, a spinner while busy', (tester) async {
    final handle = tester.ensureSemantics();
    var sent = 0, retried = 0;
    for (final st in [UiEmailStatus.none, UiEmailStatus.skipped]) {
      await pumpUi(tester, _card(_channels(status: st, onSend: () => sent++)));
      expect(find.text('Send'), findsOneWidget);
      await tester.tap(find.text('Send'));
    }
    expect(sent, 2);
    for (final st in [UiEmailStatus.sent, UiEmailStatus.delivered]) {
      await pumpUi(tester, _card(_channels(status: st)));
      expect(find.byKey(const ValueKey('ui-contact-sent')), findsOneWidget);
      expect(find.bySemanticsLabel('Sent'), findsOneWidget);
      expect(find.byType(UiButton), findsNothing);
    }
    await pumpUi(tester, _card(_channels(status: UiEmailStatus.sent, emailTickLabel: 'Emailed 4 Nov, 7:02 pm')));
    expect(find.bySemanticsLabel(RegExp('Emailed 4 Nov')), findsOneWidget);
    expect(find.byType(UiTooltip), findsWidgets);
    for (final st in [UiEmailStatus.failed, UiEmailStatus.bounced]) {
      await pumpUi(tester, _card(_channels(status: st, error: 'Mailbox full', onRetry: () => retried++)));
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Mailbox full'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      // Retry is described by the error.
      expect(tester.getSemantics(find.text('Retry')).getSemanticsData().hint, 'Mailbox full');
      // The error starts in the value column, under the row.
      final err = tester.getRect(find.byKey(const ValueKey('ui-contact-error')));
      final value = _rects(tester, const ValueKey('ui-contact-value'))[0];
      expect(err.left, value.left);
      expect(err.top, greaterThan(value.bottom));
    }
    expect(retried, 2);
    // The spinner never settles: pump frames by hand.
    await tester.pumpWidget(UiApp(theme: UiThemeName.dark, home: Align(alignment: Alignment.topLeft, child: _card(_channels(status: UiEmailStatus.failed, busy: true)))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(UiSpinner), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    handle.dispose();
  });

  testWidgets('rows only for what is given; hidden messengers are left out', (tester) async {
    await pumpUi(tester, _card(_channels(email: null)));
    expect(find.text('Email'), findsNothing);
    expect(find.text('Number'), findsOneWidget);
    await pumpUi(tester, _card(_channels(phone: '')));
    expect(find.text('Number'), findsNothing);
    expect(find.byType(UiMessengerButton), findsNothing);
    await pumpUi(tester, _card(_channels(messengers: const [UiMessengerChannel(app: UiMessengerApp.whatsapp), UiMessengerChannel(app: UiMessengerApp.viber, hidden: true)])));
    expect(find.byType(UiMessengerButton), findsOneWidget);
    await pumpUi(tester, _card(_channels(messengers: const [UiMessengerChannel(app: UiMessengerApp.viber, hidden: true)])));
    expect(find.byKey(const ValueKey('ui-contact-messengers')), findsNothing);
  });

  testWidgets('narrow (a 360 phone, padded card): all three fit, icon only, names kept', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, _card(_channels(), width: 360), size: const Size(360, 740));
    expect(tester.takeException(), isNull);
    final buttons = [for (final e in find.byType(UiMessengerButton).evaluate()) tester.getRect(find.byWidget(e.widget))];
    expect(buttons, hasLength(3));
    expect(buttons.last.right, lessThanOrEqualTo(360 - 16 + 0.001));
    expect(buttons.map((r) => r.width.toStringAsFixed(3)).toSet(), hasLength(1));
    expect(buttons[1].left - buttons[0].right, closeTo(8, 0.01));
    for (final name in ['WhatsApp', 'Viber', 'Telegram']) {
      expect(find.text(name), findsNothing);
    }
    expect(find.bySemanticsLabel('Send to Aisha on WhatsApp'), findsOneWidget);
    expect(find.bySemanticsLabel('Viber, Opened 14:05'), findsOneWidget);
    expect(find.bySemanticsLabel('Telegram'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('wide: the buttons show their names', (tester) async {
    await pumpUi(tester, _card(_channels(), width: 640), size: const Size(700, 600));
    for (final name in ['WhatsApp', 'Viber', 'Telegram']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('two or three buttons at any width: whole names or logos alone, never an ellipsis', (tester) async {
    const two = [UiMessengerChannel(app: UiMessengerApp.whatsapp), UiMessengerChannel(app: UiMessengerApp.telegram)];
    var labelled = 0, icons = 0;
    for (final list in [two, _all]) {
      for (var w = 300.0; w <= 720; w += 12) {
        await pumpUi(tester, _card(_channels(messengers: list), width: w), size: Size(w + 20, 700));
        expect(tester.takeException(), isNull);
        for (final p in tester.renderObjectList<RenderParagraph>(find.descendant(of: find.byType(UiMessengerButton), matching: find.byType(RichText)))) {
          expect(p.didExceedMaxLines, isFalse, reason: '${list.length} buttons at $w: "${p.text.toPlainText()}"');
          labelled++;
        }
        final shown = tester.renderObjectList<RenderParagraph>(find.descendant(of: find.byType(UiMessengerButton), matching: find.byType(RichText))).length;
        // Never mixed: all names or none.
        expect(shown == 0 || shown == list.length, isTrue, reason: '${list.length} buttons at $w: $shown labelled');
        icons += list.length - shown;
      }
    }
    // Both outcomes happen across the range.
    expect(labelled, greaterThan(0));
    expect(icons, greaterThan(0));
  });

  testWidgets('the row never mixes: one name that does not fit turns every button icon-only', (tester) async {
    double need(UiMessengerApp app) => UiMessengerButton(app: app, onPressed: () {}).labelledWidth(tester.element(find.byType(UiContactChannels)));
    await pumpUi(tester, SizedBox(width: 600, child: _channels()), size: const Size(700, 600));
    final viber = need(UiMessengerApp.viber), whatsapp = need(UiMessengerApp.whatsapp), telegram = need(UiMessengerApp.telegram);
    expect(viber, lessThan(whatsapp));
    // Each share between Viber's need and the others': Viber alone would fit.
    final each = (viber + (whatsapp < telegram ? whatsapp : telegram)) / 2;
    final valueStart = tester.getRect(find.byType(UiMessengerButton).first).left - tester.getRect(find.byType(UiContactChannels)).left;
    // ignore: avoid_print
    print('needs: viber $viber, whatsapp $whatsapp, telegram $telegram; value column at $valueStart');
    final width = valueStart + each * 3 + 16;
    await pumpUi(tester, SizedBox(width: width, child: _channels()), size: const Size(700, 600));
    final share = tester.getSize(find.descendant(of: find.byKey(const ValueKey(UiMessengerApp.viber)), matching: find.byKey(const ValueKey('ui-messenger-box')))).width;
    expect(share, closeTo(each, 0.01));
    expect(share, greaterThanOrEqualTo(viber));
    for (final name in ['WhatsApp', 'Viber', 'Telegram']) {
      expect(find.text(name), findsNothing, reason: name);
    }
    // Enough for every name: all three labelled.
    final all = valueStart + [viber, whatsapp, telegram].reduce((a, b) => a > b ? a : b) * 3 + 16 + 1;
    await pumpUi(tester, SizedBox(width: all, child: _channels()), size: const Size(700, 600));
    for (final name in ['WhatsApp', 'Viber', 'Telegram']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('pressing a messenger reports its app', (tester) async {
    final got = <UiMessengerApp>[];
    await pumpUi(tester, _card(_channels(onApp: got.add), width: 640), size: const Size(700, 600));
    await tester.tap(find.text('Telegram'));
    await tester.tap(find.text('Viber'));
    expect(got, [UiMessengerApp.telegram, UiMessengerApp.viber]);
  });

  testWidgets('a long address ends in an ellipsis with the full text in a tooltip', (tester) async {
    const long = 'aisha.mohamed.abdulla.the.second@a-very-long-domain.example.com';
    await pumpUi(tester, _card(_channels(email: long)));
    expect(tester.takeException(), isNull);
    expect(find.byWidgetPredicate((w) => w is UiTooltip && w.message == long), findsOneWidget);
  });

  testWidgets('golden: a guest card (sent, failed) at phone width', (tester) async {
    await expectThemedGolden(tester, 'contact_channels', height: 620, (context) {
      final t = context.ui;
      Widget card(Widget child) => Container(
            padding: EdgeInsets.all(t.space4),
            decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radiusLg)),
            child: child,
          );
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
        card(_channels(status: UiEmailStatus.sent, emailTickLabel: 'Emailed 7:02 pm')),
        card(_channels(status: UiEmailStatus.bounced, error: 'The address bounced: mailbox not found.', messengers: const [
          UiMessengerChannel(app: UiMessengerApp.whatsapp, ticked: true),
          UiMessengerChannel(app: UiMessengerApp.viber),
          UiMessengerChannel(app: UiMessengerApp.telegram),
        ])),
        card(_channels(busy: true, messengers: const [UiMessengerChannel(app: UiMessengerApp.whatsapp), UiMessengerChannel(app: UiMessengerApp.telegram)])),
      ]);
    });
  });
}
