import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// A pushed page with a sheet over it and a header Back button (Navigator.maybePop), as an app
/// screen has.
class _Page {
  int snap;
  final log = <int>[];

  /// Escapes the sheet let through to the page.
  int pageEscapes = 0;
  _Page(this.snap);
}

Future<_Page> _pushed(WidgetTester tester, {required List<double> snaps, int snap = 0}) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final p = _Page(snap);
  await tester.pumpWidget(UiApp(
    home: Builder(
      builder: (context) => Center(
        child: UiButton(
          label: 'Go',
          onPressed: () => Navigator.of(context).push(UiPageRoute<void>(
            builder: (context) => StatefulBuilder(
              builder: (context, set) => Focus(
                onKeyEvent: (_, e) {
                  if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) p.pageEscapes++;
                  return KeyEventResult.ignored;
                },
                child: Stack(children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: UiButton(label: 'Back', onPressed: () => Navigator.maybePop(context)),
                  ),
                  UiBottomSheet(
                    snaps: snaps,
                    snap: p.snap,
                    title: 'Doctors',
                    // Keeps the header Back reachable at the tallest snap, as on a real screen.
                    topInset: 56,
                    onSnapChanged: (i) => set(() {
                      p.snap = i;
                      p.log.add(i);
                    }),
                    child: Column(children: [for (var i = 0; i < 20; i++) SizedBox(height: 40, child: Text('Row $i'))]),
                  ),
                ]),
              ),
            ),
          )),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Go'));
  await tester.pumpAndSettle();
  expect(find.text('Doctors'), findsOneWidget);
  return p;
}

bool _onPage(WidgetTester tester) => find.text('Doctors').evaluate().isNotEmpty;

Future<void> _system(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

Future<void> _header(WidgetTester tester) async {
  expect(find.text('Back').hitTestable(), findsOneWidget);
  await tester.tap(find.text('Back'));
  await tester.pumpAndSettle();
}

UiBottomSheetState _state(WidgetTester tester) => tester.state<UiBottomSheetState>(find.byType(UiBottomSheet));

void main() {
  const peek = [0.3, 0.55, 1.0];

  testWidgets('persistent: only a sheet whose smallest snap is above 0', (tester) async {
    await _pushed(tester, snaps: peek);
    expect(_state(tester).persistent, isTrue);
    expect(_state(tester).isOpen, isTrue);
    await _system(tester);
    await _pushed(tester, snaps: const [0, 0.5, 1]);
    expect(_state(tester).persistent, isFalse);
  });

  testWidgets('a persistent sheet at its smallest snap lets system back leave the page', (tester) async {
    final p = await _pushed(tester, snaps: peek);
    await _system(tester);
    expect(_onPage(tester), isFalse);
    expect(find.text('Go'), findsOneWidget);
    expect(p.log, isEmpty);
  });

  testWidgets('a persistent sheet at its smallest snap lets a header Back (maybePop) leave the page', (tester) async {
    final p = await _pushed(tester, snaps: peek);
    await _header(tester);
    expect(_onPage(tester), isFalse);
    expect(p.log, isEmpty);
  });

  for (final from in [1, 2]) {
    testWidgets('from snap $from, system back first collapses to the smallest snap, then leaves', (tester) async {
      final p = await _pushed(tester, snaps: peek, snap: from);
      await _system(tester);
      expect(_onPage(tester), isTrue);
      expect(p.snap, 0);
      expect(p.log, [0]);
      expect(tester.getTopLeft(find.byType(FocusScope).last).dy, closeTo(844 - (844 - 56) * 0.3, 1));
      await _system(tester);
      expect(_onPage(tester), isFalse);
    });
  }

  testWidgets('from the top snap, a header Back first collapses, then leaves', (tester) async {
    final p = await _pushed(tester, snaps: peek, snap: 2);
    await _header(tester);
    expect(_onPage(tester), isTrue);
    expect(p.snap, 0);
    await _header(tester);
    expect(_onPage(tester), isFalse);
  });

  testWidgets('a sheet that can close keeps today\'s Back: close to 0, then leave', (tester) async {
    final p = await _pushed(tester, snaps: const [0, 0.5, 1], snap: 2);
    await _system(tester);
    expect(_onPage(tester), isTrue);
    expect(p.snap, 0);
    await _system(tester);
    expect(_onPage(tester), isFalse);

    final q = await _pushed(tester, snaps: const [0, 0.5, 1], snap: 1);
    await _header(tester);
    expect(_onPage(tester), isTrue);
    expect(q.snap, 0);
    await _header(tester);
    expect(_onPage(tester), isFalse);
  });

  testWidgets('Escape collapses a persistent sheet to its smallest snap and no further', (tester) async {
    final p = await _pushed(tester, snaps: peek, snap: 2);
    final handle = tester.widget<UiInteractive>(find.byWidgetPredicate((w) => w is UiInteractive && (w.semanticLabel?.startsWith('Make') ?? false))).focusNode!;
    handle.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(p.snap, 0);
    expect(p.pageEscapes, 0, reason: 'the sheet used that Escape');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(p.snap, 0);
    expect(p.log, [0]);
    expect(p.pageEscapes, 1, reason: 'at its smallest snap the sheet lets Escape through');
    expect(_onPage(tester), isTrue, reason: 'Escape never leaves the page');
    expect(find.text('Row 0').hitTestable(), findsOneWidget, reason: 'still showing at its peek height');
  });
}
