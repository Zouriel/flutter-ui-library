import 'dart:ui' show CheckedState, GestureSettings;

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// A parent that holds the value, as an app would, and records what the switch reports.
class _Host extends StatefulWidget {
  const _Host({required this.changes, required this.presses, this.disabled = false, this.apps = UiMessengerApp.values, this.sublabel});
  final List<UiMessengerApp> changes;
  final List<UiMessengerApp> presses;
  final bool disabled;
  final List<UiMessengerApp> apps;
  final String? sublabel;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late UiMessengerApp value = widget.apps.first;

  @override
  Widget build(BuildContext context) => UiMessengerSwitch(
        value: value,
        apps: widget.apps,
        sublabel: widget.sublabel,
        disabled: widget.disabled,
        onChanged: (v) {
          widget.changes.add(v);
          setState(() => value = v);
        },
        onPressed: widget.presses.add,
      );
}

Finder get _pill => find.byKey(const ValueKey('ui-mswitch-pill'));
Finder _dot(UiMessengerApp a) => find.byKey(ValueKey('ui-mswitch-dot-${a.name}'));
UiMessengerApp _current(WidgetTester tester) => tester.widget<UiMessengerSwitch>(find.byType(UiMessengerSwitch)).value;

/// A phone's touch slop (Flutter tests default to 18; a real Android device reports about 8dp).
void _phoneSlop(WidgetTester tester) {
  tester.view.gestureSettings = GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
  addTearDown(tester.view.reset);
}

/// A finger drag across the pill in [steps] timed moves (16ms apart), like a real swipe.
Future<void> _swipe(WidgetTester tester, Offset by, {int steps = 10, Duration step = const Duration(milliseconds: 16)}) async {
  final g = await tester.startGesture(tester.getCenter(_pill));
  for (var i = 0; i < steps; i++) {
    await g.moveBy(by / steps.toDouble(), timeStamp: step * (i + 1));
    await tester.pump(step);
  }
  await g.up(timeStamp: step * (steps + 1));
  await tester.pumpAndSettle();
}

Future<void> _pump(WidgetTester tester, Widget child, {Size size = const Size(390, 844), TextDirection dir = TextDirection.ltr}) =>
    pumpUi(tester, SizedBox(key: UniqueKey(), width: size.width, child: Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Directionality(textDirection: dir, child: child))), size: size);

void main() {
  group('swipe', () {
    testWidgets('finger left = next, right = previous, with a phone\'s slop; wraps; never presses', (tester) async {
      _phoneSlop(tester);
      final changes = <UiMessengerApp>[], presses = <UiMessengerApp>[];
      await _pump(tester, _Host(changes: changes, presses: presses));
      expect(_current(tester), UiMessengerApp.whatsapp);
      await _swipe(tester, const Offset(-80, 0));
      expect(_current(tester), UiMessengerApp.viber);
      await _swipe(tester, const Offset(-80, 4));
      expect(_current(tester), UiMessengerApp.telegram);
      await _swipe(tester, const Offset(-80, 0));
      expect(_current(tester), UiMessengerApp.whatsapp);
      await _swipe(tester, const Offset(80, 0));
      expect(_current(tester), UiMessengerApp.telegram);
      expect(changes, [UiMessengerApp.viber, UiMessengerApp.telegram, UiMessengerApp.whatsapp, UiMessengerApp.telegram]);
      expect(presses, isEmpty);
    });

    testWidgets('a short slow drag or a vertical drag changes nothing and presses nothing', (tester) async {
      _phoneSlop(tester);
      final changes = <UiMessengerApp>[], presses = <UiMessengerApp>[];
      await _pump(tester, _Host(changes: changes, presses: presses));
      // 30px over 600ms: under 40 and far under a fling.
      await _swipe(tester, const Offset(-30, 0), steps: 20, step: const Duration(milliseconds: 30));
      await _swipe(tester, const Offset(10, 60));
      expect(changes, isEmpty);
      expect(presses, isEmpty);
    });

    testWidgets('a quick flick under 40px counts as a fling', (tester) async {
      _phoneSlop(tester);
      final changes = <UiMessengerApp>[];
      await _pump(tester, _Host(changes: changes, presses: []));
      // 30px in 30ms: about 1000 px/s.
      await _swipe(tester, const Offset(-30, 0), steps: 3, step: const Duration(milliseconds: 10));
      expect(changes, [UiMessengerApp.viber]);
    });

    testWidgets('mirrored in RTL: finger right = next', (tester) async {
      _phoneSlop(tester);
      final changes = <UiMessengerApp>[];
      await _pump(tester, _Host(changes: changes, presses: []), dir: TextDirection.rtl);
      await _swipe(tester, const Offset(80, 0));
      expect(changes, [UiMessengerApp.viber]);
    });
  });

  testWidgets('chevrons step with wrap-around; disabled with one app', (tester) async {
    final changes = <UiMessengerApp>[];
    await _pump(tester, _Host(changes: changes, presses: []));
    await tester.tap(find.byKey(const ValueKey('ui-mswitch-prev')));
    await tester.pumpAndSettle();
    expect(_current(tester), UiMessengerApp.telegram);
    await tester.tap(find.byKey(const ValueKey('ui-mswitch-next')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ui-mswitch-next')));
    await tester.pumpAndSettle();
    expect(changes, [UiMessengerApp.telegram, UiMessengerApp.whatsapp, UiMessengerApp.viber]);
    final one = <UiMessengerApp>[];
    await _pump(tester, _Host(changes: one, presses: [], apps: const [UiMessengerApp.viber]));
    await tester.tap(find.byKey(const ValueKey('ui-mswitch-next')), warnIfMissed: false);
    await _swipe(tester, const Offset(-80, 0));
    expect(one, isEmpty);
  });

  testWidgets('keys on the pill: arrows step (wrap), Home/End; Enter presses; RTL swaps Left/Right', (tester) async {
    final changes = <UiMessengerApp>[], presses = <UiMessengerApp>[];
    await _pump(tester, _Host(changes: changes, presses: presses));
    final focus = Focus.of(tester.element(find.descendant(of: _pill, matching: find.byType(GestureDetector)).first));
    focus.requestFocus();
    await tester.pump();
    for (final k in [LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.end, LogicalKeyboardKey.home]) {
      await tester.sendKeyEvent(k);
      await tester.pump();
    }
    expect(changes, [
      UiMessengerApp.viber, UiMessengerApp.telegram, UiMessengerApp.whatsapp, // right, down, right (wraps)
      UiMessengerApp.telegram, UiMessengerApp.viber, // left (wraps back), up
      UiMessengerApp.telegram, UiMessengerApp.whatsapp, // end, home
    ]);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(presses, [UiMessengerApp.whatsapp, UiMessengerApp.whatsapp]);

    final rtl = <UiMessengerApp>[];
    await _pump(tester, _Host(changes: rtl, presses: []), dir: TextDirection.rtl);
    Focus.of(tester.element(find.descendant(of: _pill, matching: find.byType(GestureDetector)).first)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(rtl, [UiMessengerApp.viber]);
  });

  testWidgets('dots: a tap selects; arrows on a dot move the choice and the focus', (tester) async {
    final changes = <UiMessengerApp>[];
    await _pump(tester, _Host(changes: changes, presses: []));
    await tester.tap(_dot(UiMessengerApp.telegram));
    await tester.pumpAndSettle();
    expect(_current(tester), UiMessengerApp.telegram);
    await tester.tap(_dot(UiMessengerApp.telegram));
    expect(changes, [UiMessengerApp.telegram]);
    Focus.of(tester.element(find.descendant(of: _dot(UiMessengerApp.telegram), matching: find.byType(GestureDetector)).first)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_current(tester), UiMessengerApp.whatsapp);
    final f = Focus.of(tester.element(find.descendant(of: _dot(UiMessengerApp.whatsapp), matching: find.byType(GestureDetector)).first));
    expect(f.hasFocus, isTrue);
  });

  testWidgets('a tap presses with the current app; disabled does not, but still switches', (tester) async {
    final presses = <UiMessengerApp>[];
    await _pump(tester, _Host(changes: [], presses: presses));
    await tester.tap(find.byKey(const ValueKey('ui-mswitch-next')));
    await tester.pumpAndSettle();
    await tester.tap(_pill);
    expect(presses, [UiMessengerApp.viber]);
    final dis = <UiMessengerApp>[], disChanges = <UiMessengerApp>[];
    await _pump(tester, _Host(changes: disChanges, presses: dis, disabled: true));
    await tester.tap(_pill);
    expect(dis, isEmpty);
    await tester.tap(find.byKey(const ValueKey('ui-mswitch-next')));
    expect(disChanges, [UiMessengerApp.viber]);
    final op = tester.widget<Opacity>(find.ancestor(of: find.byKey(const ValueKey('ui-mswitch-fill')), matching: find.byType(Opacity)).first);
    expect(op.opacity, 0.5);
  });

  testWidgets('layout: centred in a wider parent, at most 360 wide, logo centred on the pill, targets', (tester) async {
    await _pump(tester, _Host(changes: [], presses: [], sublabel: 'Next: Aisha'), size: const Size(700, 600));
    final all = tester.getRect(find.byKey(const ValueKey('ui-mswitch')));
    expect(all.width, 360);
    final left = all.left - 0, right = 700 - all.right;
    // ignore: avoid_print
    print('switch centring: left gap $left, right gap $right');
    expect((left - right).abs(), lessThanOrEqualTo(0.5));
    final fill = tester.getRect(find.byKey(const ValueKey('ui-mswitch-fill')));
    expect(fill.height, greaterThanOrEqualTo(52));
    for (final app in UiMessengerApp.values) {
      await tester.tap(_dot(app));
      await tester.pumpAndSettle();
      final logo = tester.getRect(find.byKey(const ValueKey('ui-mswitch-logo')));
      final size = UiMessengerSwitch.logoSize(app);
      expect(logo.size, Size(size, size));
      // ignore: avoid_print
      print('switch logo $app: dy ${(logo.center.dy - fill.center.dy).toStringAsFixed(3)}');
      expect((logo.center.dy - fill.center.dy).abs(), lessThanOrEqualTo(0.5));
      // The content group is centred on the pill.
      final label = tester.getRect(find.byKey(const ValueKey('ui-mswitch-label')));
      final sub = tester.getRect(find.byKey(const ValueKey('ui-mswitch-sublabel')));
      final group = (logo.left + (label.right > sub.right ? label.right : sub.right)) / 2;
      expect((group - fill.center.dx).abs(), lessThanOrEqualTo(0.5));
      expect(label.left, sub.left);
    }
    for (final k in ['ui-mswitch-prev', 'ui-mswitch-next']) {
      final r = tester.getRect(find.byKey(ValueKey(k)));
      expect(r.width, greaterThanOrEqualTo(44));
      expect(r.height, greaterThanOrEqualTo(44));
    }
    for (final app in UiMessengerApp.values) {
      final r = tester.getRect(_dot(app));
      expect(r.width, greaterThanOrEqualTo(24));
      expect(r.height, greaterThanOrEqualTo(24));
    }
    // The dots row is centred under the pill row.
    final d0 = tester.getRect(_dot(UiMessengerApp.whatsapp)), d2 = tester.getRect(_dot(UiMessengerApp.telegram));
    expect(((d0.left + d2.right) / 2 - all.center.dx).abs(), lessThanOrEqualTo(0.5));
    expect(d0.top - fill.bottom, greaterThanOrEqualTo(8));
  });

  testWidgets('a 360 screen: the label wraps rather than being cut; the pill grows; the sublabel keeps one line', (tester) async {
    for (final app in UiMessengerApp.values) {
      await pumpUi(tester, SizedBox(key: UniqueKey(), width: 360, child: Padding(padding: const EdgeInsets.all(16), child: UiMessengerSwitch(value: app, sublabel: 'Next: Aishath Mohamed Abdulla Hassan', onChanged: (_) {}))), size: const Size(360, 740));
      expect(tester.takeException(), isNull);
      final label = tester.renderObject<RenderParagraph>(find.descendant(of: find.byKey(const ValueKey('ui-mswitch-label')), matching: find.byType(RichText)));
      expect(label.didExceedMaxLines, isFalse, reason: app.name);
      final sub = tester.renderObject<RenderParagraph>(find.descendant(of: find.byKey(const ValueKey('ui-mswitch-sublabel')), matching: find.byType(RichText)));
      expect(sub.maxLines, 1);
      final fill = tester.getRect(find.byKey(const ValueKey('ui-mswitch-fill')));
      final text = tester.getRect(find.byKey(const ValueKey('ui-mswitch-label')));
      expect(fill.height, greaterThanOrEqualTo(52));
      // ignore: avoid_print
      print('360 screen $app: label ${text.height.toStringAsFixed(0)} tall, pill ${fill.height.toStringAsFixed(0)} tall');
      expect(fill.top <= text.top && fill.bottom >= text.bottom, isTrue);
    }
  });

  testWidgets('a narrow parent: the control takes the parent width', (tester) async {
    await _pump(tester, _Host(changes: [], presses: []), size: const Size(300, 600));
    expect(tester.getRect(find.byKey(const ValueKey('ui-mswitch'))).width, 300);
    expect(tester.takeException(), isNull);
  });

  testWidgets('semantics: the pill\'s name, hint and state; the dots a radio group', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _Host(changes: [], presses: [], sublabel: 'Next: Aisha'));
    final pill = tester.getSemantics(_pill).getSemanticsData();
    expect(pill.label, 'Send next on WhatsApp, Next: Aisha');
    expect(pill.hint, 'Swipe or use the arrow keys to change channel');
    expect(pill.flagsCollection.isButton, isTrue);
    expect(find.bySemanticsLabel('Previous channel'), findsOneWidget);
    expect(find.bySemanticsLabel('Next channel'), findsOneWidget);
    expect(tester.getSemantics(find.byKey(const ValueKey('ui-mswitch-dots'))).label, 'Channel');
    for (final app in UiMessengerApp.values) {
      final d = tester.getSemantics(find.bySemanticsLabel(UiMessengerBrand.name(app))).getSemanticsData();
      expect(d.flagsCollection.isInMutuallyExclusiveGroup, isTrue, reason: app.name);
      expect(d.flagsCollection.isChecked == CheckedState.isTrue, app == UiMessengerApp.whatsapp, reason: app.name);
    }
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('a value change slides the content and fades the fill; no motion when animations are off', (tester) async {
    Widget build(UiMessengerApp v) => UiMessengerSwitch(value: v, onChanged: (_) {});
    await _pump(tester, build(UiMessengerApp.whatsapp));
    await _pump(tester, build(UiMessengerApp.viber));
    // pumpUi settles; re-run by hand to watch the middle.
    await tester.pumpWidget(UiApp(home: Align(alignment: Alignment.topCenter, child: build(UiMessengerApp.whatsapp))));
    await tester.pumpAndSettle();
    await tester.pumpWidget(UiApp(home: Align(alignment: Alignment.topCenter, child: build(UiMessengerApp.viber))));
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byKey(const ValueKey(UiMessengerApp.whatsapp)), findsOneWidget, reason: 'the old content is still fading out');
    final mid = tester.getRect(find.byKey(const ValueKey(UiMessengerApp.viber)));
    await tester.pumpAndSettle();
    final end = tester.getRect(find.byKey(const ValueKey(UiMessengerApp.viber)));
    expect(find.byKey(const ValueKey(UiMessengerApp.whatsapp)), findsNothing);
    // It slid in from the end side (a step forward).
    expect(mid.left, greaterThan(end.left));

    await tester.pumpWidget(UiApp(home: MediaQuery(data: const MediaQueryData(disableAnimations: true), child: Align(alignment: Alignment.topCenter, child: build(UiMessengerApp.whatsapp)))));
    await tester.pumpAndSettle();
    await tester.pumpWidget(UiApp(home: MediaQuery(data: const MediaQueryData(disableAnimations: true), child: Align(alignment: Alignment.topCenter, child: build(UiMessengerApp.telegram)))));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey(UiMessengerApp.whatsapp)), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('golden: the switch on each app, with a sublabel, disabled', (tester) async {
    await expectThemedGolden(tester, 'messenger_switch', height: 520, (context) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: [
        UiMessengerSwitch(value: UiMessengerApp.whatsapp, sublabel: 'Next: Aisha', onChanged: (_) {}, onPressed: (_) {}),
        UiMessengerSwitch(value: UiMessengerApp.viber, onChanged: (_) {}, onPressed: (_) {}),
        UiMessengerSwitch(value: UiMessengerApp.telegram, sublabel: 'Next: Hassan Abdulla Mohamed', onChanged: (_) {}, onPressed: (_) {}),
        UiMessengerSwitch(value: UiMessengerApp.whatsapp, disabled: true, label: 'Everyone has been sent', onChanged: (_) {}),
      ]);
    });
  });
}
