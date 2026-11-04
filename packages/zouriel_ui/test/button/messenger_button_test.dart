import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart' show kPressTimeout;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/core/svg_path.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

const _apps = UiMessengerApp.values;
Finder _in(Key key, Finder f) => find.descendant(of: find.byKey(key), matching: f);
Rect _box(WidgetTester tester, Key key) => tester.getRect(_in(key, find.byKey(const ValueKey('ui-messenger-box'))));
Rect _logo(WidgetTester tester, Key key) => tester.getRect(_in(key, find.byType(UiMessengerLogo)));

void main() {
  group('brand colours', () {
    test('every ink passes AA on every fill stop, also under the hover and press veils', () {
      const white = Color(0xFFFFFFFF);
      for (final app in _apps) {
        for (final fill in UiMessengerBrand.fill(app)) {
          for (final veil in [0.0, 0.10, 0.18]) {
            final bg = Color.alphaBlend(white.withValues(alpha: veil), fill);
            final ratio = uiContrast(UiMessengerBrand.ink(app), bg);
            expect(ratio, greaterThanOrEqualTo(4.5), reason: '$app ink on $fill with a $veil veil: $ratio');
          }
        }
      }
      expect(UiMessengerBrand.fill(UiMessengerApp.telegram), hasLength(2));
      // White words would fail on Viber's purple: the reason its ink is black.
      expect(uiContrast(white, UiMessengerBrand.viberFill), lessThan(4.5));
    });

    test('logo path data is the official files\' verbatim', () {
      final official = jsonDecode(File('test/button/fixtures/messenger_logos.json').readAsStringSync()) as Map<String, dynamic>;
      for (final app in _apps) {
        final want = [for (final p in official[app.name] as List) ((p as List)[0] as bool, p[1] as String)];
        expect(uiMessengerLogoPaths[app], want, reason: app.name);
      }
      expect(uiMessengerLogoPaths[UiMessengerApp.viber]!.map((p) => p.$1), [false, false, false, true]);
    });

    test('every logo parses and fills its viewBox', () {
      for (final app in _apps) {
        final vb = UiMessengerBrand.viewBox(app);
        var bounds = Rect.zero;
        for (final (evenOdd, d) in uiMessengerLogoPaths[app]!) {
          final b = uiParseSvgPath(d, fillType: evenOdd ? PathFillType.evenOdd : PathFillType.nonZero).getBounds();
          bounds = bounds.isEmpty ? b : bounds.expandToInclude(b);
        }
        expect(bounds.left, greaterThanOrEqualTo(-1), reason: app.name);
        expect(bounds.top, greaterThanOrEqualTo(-1), reason: app.name);
        expect(bounds.right, lessThanOrEqualTo(vb.width + 1), reason: app.name);
        expect(bounds.bottom, lessThanOrEqualTo(vb.height + 1), reason: app.name);
        // Telegram's plane sits inside its disc; the others fill most of their box.
        expect(bounds.width, greaterThan(vb.width * (app == UiMessengerApp.telegram ? 0.4 : 0.9)), reason: app.name);
      }
    });
  });

  test('logo sizes, and Telegram\'s stops banded to its logo box', () {
    expect([for (final a in _apps) UiMessengerBrand.logoSize(a)], [22, 22, 28]);
    final g = UiMessengerBrand.fillGradient(UiMessengerApp.telegram) as LinearGradient;
    expect(g.colors, [UiMessengerBrand.telegramTop, UiMessengerBrand.telegramBottom]);
    expect(g.stops![0], closeTo(8 / 44, 1e-9));
    expect(g.stops![1], closeTo(36 / 44, 1e-9));
  });

  testWidgets('Telegram\'s button uses the banded gradient', (tester) async {
    await pumpUi(tester, UiMessengerButton(app: UiMessengerApp.telegram, onPressed: () {}));
    final deco = tester.widget<Container>(find.byKey(const ValueKey('ui-messenger-box'))).decoration! as BoxDecoration;
    expect((deco.gradient! as LinearGradient).stops, [8 / 44, 36 / 44]);
    expect(tester.getSize(find.byType(UiMessengerLogo)), const Size(28, 28));
  });

  group('svg path parser', () {
    test('relative commands and implicit repeats', () {
      final p = uiParseSvgPath('m10 10 l10 0 0 10 -10 0z m30 0 h5 v5 h-5 z');
      expect(p.getBounds(), const Rect.fromLTRB(10, 10, 45, 20));
      expect(p.contains(const Offset(15, 15)), isTrue);
      expect(p.contains(const Offset(42, 12)), isTrue);
      expect(p.contains(const Offset(30, 15)), isFalse);
    });

    test('numbers run together and exponents', () {
      final p = uiParseSvgPath('M.5-.3L1e1,1E1L1.5.5Z');
      final b = p.getBounds();
      expect(b.left, closeTo(0.5, 1e-6));
      expect(b.top, closeTo(-0.3, 1e-6));
      expect(b.right, 10);
      expect(b.bottom, 10);
    });

    test('S and T reflect the previous control point; absolute H V', () {
      // getBounds includes control points: only a mirrored first control (10,10) reaches y = 10.
      final s = uiParseSvgPath('M0 0C0 -10 10 -10 10 0S20 0 20 0').getBounds();
      expect(s, const Rect.fromLTRB(0, -10, 20, 10));
      final q = uiParseSvgPath('M0 0Q5 -10 10 0T20 0').getBounds();
      expect(q, const Rect.fromLTRB(0, -10, 20, 10));
      expect(uiParseSvgPath('M0 0q5 -10 10 0t10 0').getBounds(), q);
      expect(uiParseSvgPath('M0 0c0 -10 10 -10 10 0s10 0 10 0').getBounds(), s);
      // A T after a non-quadratic uses the current point as its control: a straight line.
      expect(uiParseSvgPath('M0 0L10 0T20 0').getBounds(), const Rect.fromLTRB(0, 0, 20, 0));
      expect(uiParseSvgPath('M1 1H9V9H1Z').getBounds(), const Rect.fromLTRB(1, 1, 9, 9));
    });

    test('rejects arcs and bad data', () {
      expect(() => uiParseSvgPath('M0 0A5 5 0 0 1 10 0'), throwsFormatException);
      expect(() => uiParseSvgPath('10 10'), throwsFormatException);
      expect(() => uiParseSvgPath('M0 0L5'), throwsFormatException);
    });
  });

  group('layout', () {
    Future<void> centring(WidgetTester tester, {required UiMessengerCompact compact, required bool expand, required bool label}) async {
      await pumpUi(
        tester,
        SizedBox(
          width: 360,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 16, children: [
            for (final app in _apps) UiMessengerButton(key: ValueKey(app), app: app, compact: compact, expand: expand, onPressed: () {}),
          ]),
        ),
      );
      for (final app in _apps) {
        final key = ValueKey(app);
        final box = _box(tester, key);
        final logo = _logo(tester, key);
        expect(box.height, 44);
        final ls = UiMessengerBrand.logoSize(app);
        expect(logo.size, Size(ls, ls));
        expect((logo.center.dy - box.center.dy).abs(), lessThanOrEqualTo(0.5), reason: '$app logo dy');
        if (label) {
          final text = tester.getRect(_in(key, find.text(UiMessengerBrand.name(app))));
          final group = (logo.left + text.right) / 2;
          // ignore: avoid_print
          print('centring ${compact.name}${expand ? '+expand' : ''} $app: logo dy ${(logo.center.dy - box.center.dy).toStringAsFixed(3)}, label dy ${(text.center.dy - box.center.dy).toStringAsFixed(3)}, group dx ${(group - box.center.dx).toStringAsFixed(3)}');
          expect((text.center.dy - box.center.dy).abs(), lessThanOrEqualTo(0.5), reason: '$app label dy');
          expect((group - box.center.dx).abs(), lessThanOrEqualTo(0.5), reason: '$app group dx');
          expect(text.left - logo.right, 8);
        } else {
          expect(_in(key, find.byType(Text)), findsNothing);
          // ignore: avoid_print
          print('centring ${compact.name}${expand ? '+expand' : ''} $app: logo dx ${(logo.center.dx - box.center.dx).toStringAsFixed(3)}, dy ${(logo.center.dy - box.center.dy).toStringAsFixed(3)}');
          expect((logo.center.dx - box.center.dx).abs(), lessThanOrEqualTo(0.5), reason: '$app logo dx');
        }
        if (expand) expect(box.width, 360);
      }
    }

    testWidgets('labelled: logo and label centred as a group, 44 high, hugging', (tester) async {
      await centring(tester, compact: UiMessengerCompact.off, expand: false, label: true);
      final box = _box(tester, const ValueKey(UiMessengerApp.whatsapp));
      final text = tester.getRect(find.text('WhatsApp'));
      // 12 + logo + 8 + label + 12.
      expect(box.width, closeTo(12 + 22 + 8 + text.width + 12, 0.01));
      final tg = _box(tester, const ValueKey(UiMessengerApp.telegram));
      expect(tg.width, closeTo(12 + 28 + 8 + tester.getRect(find.text('Telegram')).width + 12, 0.01));
    });

    testWidgets('compact: a 44x44 square with the logo in the middle', (tester) async {
      await centring(tester, compact: UiMessengerCompact.on, expand: false, label: false);
      expect(_box(tester, const ValueKey(UiMessengerApp.viber)).size, const Size(44, 44));
    });

    testWidgets('expand: full width, the group still centred', (tester) async {
      await centring(tester, compact: UiMessengerCompact.off, expand: true, label: true);
    });

    testWidgets('expand + compact: the logo centred in the full width', (tester) async {
      await centring(tester, compact: UiMessengerCompact.on, expand: true, label: false);
    });

    testWidgets('expanded in a row: equal widths', (tester) async {
      await pumpUi(
        tester,
        SizedBox(
          width: 360,
          child: Row(spacing: 8, children: [
            for (final app in _apps) Expanded(child: UiMessengerButton(key: ValueKey(app), app: app, expand: true, onPressed: () {})),
          ]),
        ),
      );
      final widths = [for (final app in _apps) _box(tester, ValueKey(app)).width];
      for (final w in widths) {
        expect(w, closeTo((360 - 16) / 3, 0.001));
      }
    });

    testWidgets('compact auto: the whole label when it fits, else the logo alone; never an ellipsis', (tester) async {
      for (final app in _apps) {
        for (final label in [null, 'Message on ${UiMessengerBrand.name(app)}']) {
          await pumpUi(tester, UiMessengerButton(key: const ValueKey('probe'), app: app, label: label, onPressed: () {}));
          final need = tester.widget<UiMessengerButton>(find.byKey(const ValueKey('probe'))).labelledWidth(tester.element(find.byKey(const ValueKey('probe'))));
          // The hugging labelled button is exactly that wide.
          expect(_box(tester, const ValueKey('probe')).width, closeTo(need, 0.01));
          final words = label ?? UiMessengerBrand.name(app);
          for (final (w, labelled) in [(need - 0.5, false), (need + 0.5, true), (need + 40, true)]) {
            await pumpUi(tester, SizedBox(width: w, child: UiMessengerButton(key: const ValueKey('b'), app: app, label: label, expand: true, compact: UiMessengerCompact.auto, onPressed: () {})));
            expect(find.text(words), labelled ? findsOneWidget : findsNothing, reason: '$app "$words" at $w (needs $need)');
            if (labelled) {
              final para = tester.renderObject<RenderParagraph>(_in(const ValueKey('b'), find.byType(RichText)));
              expect(para.didExceedMaxLines, isFalse, reason: '$app at $w');
            }
          }
        }
      }
    });

    testWidgets('compact auto follows the text scale', (tester) async {
      Future<void> at(double scale) => pumpUi(tester, MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: SizedBox(width: 140, child: UiMessengerButton(app: UiMessengerApp.whatsapp, expand: true, compact: UiMessengerCompact.auto, onPressed: () {})),
          ));
      await at(1);
      expect(find.text('WhatsApp'), findsOneWidget);
      await at(1.6);
      expect(find.text('WhatsApp'), findsNothing);
    });

    testWidgets('a long label ends in an ellipsis without overflow', (tester) async {
      await pumpUi(tester, SizedBox(width: 140, child: UiMessengerButton(key: const ValueKey('b'), app: UiMessengerApp.whatsapp, label: 'Send the invitation on WhatsApp', onPressed: () {})));
      expect(tester.takeException(), isNull);
      expect(_box(tester, const ValueKey('b')).width, 140);
      final para = tester.renderObject<RenderParagraph>(_in(const ValueKey('b'), find.byType(RichText)));
      expect(para.didExceedMaxLines, isTrue);
    });
  });

  testWidgets('off and on work inside intrinsic sizing (a narrow table\'s cells)', (tester) async {
    await pumpUi(tester, IntrinsicWidth(child: Column(children: [
      UiMessengerButton(app: UiMessengerApp.whatsapp, onPressed: () {}),
      UiMessengerButton(app: UiMessengerApp.viber, compact: UiMessengerCompact.on, ticked: true, onPressed: () {}),
    ])));
    expect(tester.takeException(), isNull);
    await pumpUi(tester, UiTable<Map<String, Object?>>(
      columns: [UiColumn(key: 'app', header: 'Chat', cellBuilder: (context, row) => UiMessengerButton(app: UiMessengerApp.telegram, compact: UiMessengerCompact.on, onPressed: () {}))],
      data: const [{'app': 1}],
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(UiMessengerLogo), findsOneWidget);
  });

  group('tick badge', () {
    testWidgets('the same place on every button: centred 3px inside the top-end corner', (tester) async {
      for (final compact in [UiMessengerCompact.off, UiMessengerCompact.on]) {
        for (final expand in [false, true]) {
          await pumpUi(
            tester,
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: 300,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 16, children: [
                  for (final app in _apps) UiMessengerButton(key: ValueKey(app), app: app, ticked: true, compact: compact, expand: expand, onPressed: () {}),
                ]),
              ),
            ),
          );
          for (final app in _apps) {
            final key = ValueKey(app);
            final box = _box(tester, key);
            final tick = tester.getRect(_in(key, find.byKey(const ValueKey('ui-messenger-tick'))));
            expect(tick.size, const Size(18, 18));
            expect(tick.top - box.top, -6, reason: '$app $compact $expand');
            expect(tick.right - box.right, 6, reason: '$app $compact $expand');
            expect(tick.center - box.topRight, const Offset(-3, 3));
          }
        }
      }
    });

    testWidgets('at the top-left in RTL', (tester) async {
      await pumpUi(tester, Directionality(textDirection: TextDirection.rtl, child: Align(alignment: Alignment.topRight, child: Padding(padding: const EdgeInsets.all(20), child: UiMessengerButton(key: const ValueKey('b'), app: UiMessengerApp.viber, ticked: true, onPressed: () {})))));
      final box = _box(tester, const ValueKey('b'));
      final tick = tester.getRect(find.byKey(const ValueKey('ui-messenger-tick')));
      expect(tick.center - box.topLeft, const Offset(3, 3));
    });

    testWidgets('ticked still fires; the badge takes no hits; disabled does not fire', (tester) async {
      var n = 0;
      await pumpUi(tester, Padding(padding: const EdgeInsets.all(20), child: UiMessengerButton(app: UiMessengerApp.whatsapp, ticked: true, onPressed: () => n++)));
      await tester.tap(find.byType(UiMessengerButton));
      expect(n, 1);
      // A tap on the badge's part over the button still reaches the button.
      await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('ui-messenger-tick'))) + const Offset(-4, 4));
      expect(n, 2);
      await pumpUi(tester, const Padding(padding: EdgeInsets.all(20), child: UiMessengerButton(app: UiMessengerApp.whatsapp, ticked: true, onPressed: null)));
      await tester.tap(find.byType(UiMessengerButton), warnIfMissed: false);
      expect(n, 2);
      final op = tester.widget<Opacity>(find.descendant(of: find.byType(UiMessengerButton), matching: find.byType(Opacity)).first);
      expect(op.opacity, 0.5);
    });

    testWidgets('a tooltip shows the tick label on long press', (tester) async {
      await pumpUi(tester, Padding(padding: const EdgeInsets.all(40), child: UiMessengerButton(app: UiMessengerApp.telegram, ticked: true, tickLabel: 'Opened 14:05', onPressed: () {})));
      expect(find.byType(UiTooltip), findsOneWidget);
      await tester.longPress(find.byType(UiMessengerButton));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Opened 14:05'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('no tooltip without a tick label, or when not ticked', (tester) async {
      await pumpUi(tester, UiMessengerButton(app: UiMessengerApp.telegram, ticked: true, onPressed: () {}));
      expect(find.byType(UiTooltip), findsNothing);
      await pumpUi(tester, UiMessengerButton(app: UiMessengerApp.telegram, tickLabel: 'x', onPressed: () {}));
      expect(find.byType(UiTooltip), findsNothing);
    });
  });

  group('semantics', () {
    testWidgets('one button named by the label, plus the tick label when ticked', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, Column(mainAxisSize: MainAxisSize.min, children: [
        UiMessengerButton(key: const ValueKey('a'), app: UiMessengerApp.whatsapp, onPressed: () {}),
        UiMessengerButton(key: const ValueKey('b'), app: UiMessengerApp.viber, ticked: true, onPressed: () {}),
        UiMessengerButton(key: const ValueKey('c'), app: UiMessengerApp.telegram, ticked: true, tickLabel: 'Opened 14:05', compact: UiMessengerCompact.on, semanticLabel: 'Send to Aisha on Telegram', onPressed: () {}),
        UiMessengerButton(key: const ValueKey('d'), app: UiMessengerApp.viber, label: 'Chat', compact: UiMessengerCompact.on, onPressed: () {}),
      ]));
      expect(find.bySemanticsLabel('WhatsApp'), findsOneWidget);
      expect(find.bySemanticsLabel('Viber, Opened'), findsOneWidget);
      expect(find.bySemanticsLabel('Send to Aisha on Telegram, Opened 14:05'), findsOneWidget);
      // Icon only keeps the full name.
      expect(find.bySemanticsLabel('Chat'), findsOneWidget);
      final data = tester.getSemantics(find.bySemanticsLabel('Viber, Opened')).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('the Dhivehi tick word', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(UiApp(
        theme: UiThemeName.dark,
        config: const UiConfig(strings: UiStrings.dv),
        home: Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.all(20), child: UiMessengerButton(key: const ValueKey('a'), app: UiMessengerApp.whatsapp, ticked: true, onPressed: () {}))),
      ));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('WhatsApp, ${UiStrings.dv.messengerOpened}'), findsOneWidget);
      handle.dispose();
    });
  });

  testWidgets('hover and press lay a white veil over the fill', (tester) async {
    await pumpUi(tester, Padding(padding: const EdgeInsets.all(20), child: UiMessengerButton(key: const ValueKey('b'), app: UiMessengerApp.viber, onPressed: () {})));
    Color? veil() => (tester.widget<Container>(find.byKey(const ValueKey('ui-messenger-box'))).foregroundDecoration as BoxDecoration?)?.color;
    expect(veil(), isNull);
    final g = await tester.startGesture(tester.getCenter(find.byType(UiMessengerButton)));
    // A long press competes with the tap, so the press shows after the tap's short delay.
    await tester.pump(kPressTimeout);
    expect(veil(), const Color(0xFFFFFFFF).withValues(alpha: 0.18));
    await g.up();
    await tester.pumpAndSettle();
    expect(veil(), isNull);
  });

  group('0.58: size sm', () {
    test('sm logo sizes and Telegram\'s band on the 28px box', () {
      expect([for (final a in _apps) UiMessengerBrand.logoSize(a, UiMessengerSize.sm)], [16, 16, 20]);
      expect([for (final a in _apps) UiMessengerBrand.logoSize(a, UiMessengerSize.md)], [22, 22, 28]);
      expect(UiMessengerBrand.heightFor(UiMessengerSize.sm), 28);
      final g = UiMessengerBrand.fillGradient(UiMessengerApp.telegram, height: 28, logo: 20) as LinearGradient;
      expect(g.stops![0], closeTo(4 / 28, 1e-9));
      expect(g.stops![1], closeTo(24 / 28, 1e-9));
    });

    for (final theme in [UiThemeName.light, UiThemeName.dark]) {
    testWidgets('icon-only in $theme: a 28x28 painted box centred in a 44x44 hit area; logo centred', (tester) async {
      await pumpUi(tester, theme: theme, Padding(
        padding: const EdgeInsets.all(20),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final app in _apps) UiMessengerButton(key: ValueKey(app), app: app, size: UiMessengerSize.sm, compact: UiMessengerCompact.on, onPressed: () {}),
        ]),
      ));
      for (final app in _apps) {
        final key = ValueKey(app);
        final box = _box(tester, key);
        final hit = tester.getRect(_in(key, find.byKey(const ValueKey('ui-messenger-hit'))));
        final logo = _logo(tester, key);
        expect(box.size, const Size(28, 28));
        expect(hit.size, const Size(44, 44));
        expect(hit.center, box.center);
        final ls = UiMessengerBrand.logoSize(app, UiMessengerSize.sm);
        expect(logo.size, Size(ls, ls));
        // ignore: avoid_print
        print('sm centring $theme $app: logo dx ${(logo.center.dx - box.center.dx).toStringAsFixed(3)}, dy ${(logo.center.dy - box.center.dy).toStringAsFixed(3)}');
        expect((logo.center - box.center).distance, lessThanOrEqualTo(0.5));
        final deco = tester.widget<Container>(_in(key, find.byKey(const ValueKey('ui-messenger-box')))).decoration! as BoxDecoration;
        expect(deco.borderRadius, BorderRadius.circular(tester.element(find.byKey(key)).uiTheme.radius()));
        if (app == UiMessengerApp.telegram) expect((deco.gradient! as LinearGradient).stops, [4 / 28, 24 / 28]);
      }
    });
    }

    testWidgets('sm labelled: 13/600/18 words, 8 padding, 6 gap, centred', (tester) async {
      await pumpUi(tester, Padding(padding: const EdgeInsets.all(20), child: UiMessengerButton(key: const ValueKey('b'), app: UiMessengerApp.viber, size: UiMessengerSize.sm, onPressed: () {})));
      final box = _box(tester, const ValueKey('b'));
      final logo = _logo(tester, const ValueKey('b'));
      final text = tester.getRect(find.text('Viber'));
      final style = tester.renderObject<RenderParagraph>(find.byType(RichText)).text.style!;
      expect(style.fontSize, 13);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.height! * style.fontSize!, closeTo(18, 0.001));
      expect(box.height, 28);
      expect(logo.left - box.left, 8);
      expect(text.left - logo.right, 6);
      expect(box.right - text.right, closeTo(8, 0.01));
      expect((text.center.dy - box.center.dy).abs(), lessThanOrEqualTo(0.5));
      expect(_box(tester, const ValueKey('b')).width, closeTo(tester.widget<UiMessengerButton>(find.byKey(const ValueKey('b'))).labelledWidth(tester.element(find.byKey(const ValueKey('b')))), 0.01));
    });

    for (final theme in [UiThemeName.light, UiThemeName.dark]) {
    testWidgets('sm tick badge in $theme: 12px, centred 2px inside the top-end corner, 8px tick', (tester) async {
      await pumpUi(tester, Padding(
        padding: const EdgeInsets.all(20),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final app in _apps) UiMessengerButton(key: ValueKey(app), app: app, size: UiMessengerSize.sm, compact: UiMessengerCompact.on, ticked: true, onPressed: () {}),
        ]),
      ));
      for (final app in _apps) {
        final key = ValueKey(app);
        final box = _box(tester, key);
        final tick = tester.getRect(_in(key, find.byKey(const ValueKey('ui-messenger-tick'))));
        expect(tick.size, const Size(12, 12));
        expect(tick.center - box.topRight, const Offset(-2, 2));
        expect(tester.widget<UiIcon>(_in(key, find.byType(UiIcon))).size, 8);
        final deco = tester.widget<Container>(_in(key, find.byKey(const ValueKey('ui-messenger-tick')))).decoration! as BoxDecoration;
        expect(deco.boxShadow!.single.spreadRadius, 2);
      }
    });
    }

    testWidgets('a tap 7px outside the painted box still presses an sm button', (tester) async {
      var n = 0;
      await pumpUi(tester, Padding(padding: const EdgeInsets.all(40), child: UiMessengerButton(key: const ValueKey('b'), app: UiMessengerApp.whatsapp, size: UiMessengerSize.sm, compact: UiMessengerCompact.on, onPressed: () => n++)));
      final box = _box(tester, const ValueKey('b'));
      await tester.tapAt(box.topLeft - const Offset(7, 7));
      await tester.tapAt(box.bottomRight + const Offset(7, 7));
      expect(n, 2);
      // 9px out is past the 44 area (8 around the 28 box).
      await tester.tapAt(box.topLeft - const Offset(9, 9));
      expect(n, 2);
    });
  });

  for (final theme in [UiThemeName.light, UiThemeName.dark]) {
    testWidgets('badge ring: success is at least 3:1 on the surface in $theme, on every app', (tester) async {
      await pumpUi(tester, Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(spacing: 12, runSpacing: 12, children: [
          for (final app in _apps) UiMessengerButton(key: ValueKey(app), app: app, ticked: true, onPressed: () {}),
        ]),
      ), theme: theme);
      for (final app in _apps) {
        final deco = tester.widget<Container>(_in(ValueKey(app), find.byKey(const ValueKey('ui-messenger-tick')))).decoration! as BoxDecoration;
        final ratio = uiContrast(deco.color!, deco.boxShadow!.single.color);
        expect(ratio, greaterThanOrEqualTo(3), reason: '$theme $app: $ratio');
        expect(deco.boxShadow!.single.color, tester.element(find.byKey(ValueKey(app))).ui.surface);
      }
    });
  }

  group('long press', () {
    testWidgets('never presses, with or without a tooltip', (tester) async {
      var n = 0;
      for (final ticked in [false, true]) {
        await pumpUi(tester, Padding(padding: const EdgeInsets.all(40), child: UiMessengerButton(app: UiMessengerApp.whatsapp, ticked: ticked, tickLabel: ticked ? 'Opened 14:05' : null, onPressed: () => n++)));
        await tester.longPress(find.byType(UiMessengerButton));
        await tester.pump(const Duration(milliseconds: 100));
        if (ticked) expect(find.text('Opened 14:05'), findsOneWidget);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(n, 0, reason: 'ticked: $ticked');
        // A plain tap still works.
        await tester.tap(find.byType(UiMessengerButton));
        expect(n, 1, reason: 'ticked: $ticked');
        n = 0;
      }
    });
  });

  testWidgets('every app renders on every platform (only the caller hides one)', (tester) async {
    for (final p in [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux]) {
      debugDefaultTargetPlatformOverride = p;
      await pumpUi(tester, Column(mainAxisSize: MainAxisSize.min, children: [
        for (final app in _apps) UiMessengerButton(app: app, onPressed: () {}),
        UiContactChannels(phone: '+960 777 1234', messengers: [for (final app in _apps) UiMessengerChannel(app: app)], onMessengerPressed: (_) {}),
        UiMessengerSwitch(value: UiMessengerApp.viber, onChanged: (_) {}),
      ]));
      for (final app in _apps) {
        expect(find.text(UiMessengerBrand.name(app)), findsOneWidget, reason: '$p $app button');
        expect(find.byWidgetPredicate((w) => w is UiMessengerLogo && w.app == app), findsNWidgets(app == UiMessengerApp.viber ? 4 : 3), reason: '$p $app');
      }
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('golden: the three, labelled, compact, ticked, disabled, expanded', (tester) async {
    await expectThemedGolden(tester, 'messenger_buttons', height: 520, (context) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 14, children: [
        Wrap(spacing: 8, runSpacing: 12, children: [for (final app in _apps) UiMessengerButton(app: app, onPressed: () {})]),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final app in _apps) UiMessengerButton(app: app, compact: UiMessengerCompact.on, onPressed: () {}),
          for (final app in _apps) UiMessengerButton(app: app, compact: UiMessengerCompact.on, ticked: true, onPressed: () {}),
        ]),
        Wrap(spacing: 12, runSpacing: 12, children: [for (final app in _apps) UiMessengerButton(app: app, ticked: true, onPressed: () {})]),
        Wrap(spacing: 8, runSpacing: 12, children: [for (final app in _apps) UiMessengerButton(app: app, onPressed: null)]),
        Row(spacing: 8, children: [for (final app in _apps) Expanded(child: UiMessengerButton(app: app, expand: true, ticked: app == UiMessengerApp.viber, compact: UiMessengerCompact.auto, onPressed: () {}))]),
        // sm: icon-only 28px boxes, ticked, and labelled.
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (final app in _apps) UiMessengerButton(app: app, size: UiMessengerSize.sm, compact: UiMessengerCompact.on, onPressed: () {}),
          for (final app in _apps) UiMessengerButton(app: app, size: UiMessengerSize.sm, compact: UiMessengerCompact.on, ticked: true, onPressed: () {}),
        ]),
        Wrap(spacing: 8, runSpacing: 4, children: [for (final app in _apps) UiMessengerButton(app: app, size: UiMessengerSize.sm, onPressed: () {})]),
      ]);
    });
  });
}
