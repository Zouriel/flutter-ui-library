import 'dart:ui' show GestureSettings;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// 0.41.3, from the owner's phone test of Dhirumi: "filling out fields in the bottom drawer is weird
/// cause the keyboard hides the drawer and doesnt push it up". A bottom UiDrawer (the nurse app's
/// cancel reason and work summary, the customer app's medicine search) stayed at the screen edge
/// with the keyboard over it: only left and right drawers read MediaQuery.viewInsets.

Future<void> _open(WidgetTester tester, {UiDrawerSide side = UiDrawerSide.bottom, Size size = const Size(390, 844)}) async {
  final dpr = tester.view.devicePixelRatio;
  tester.view.physicalSize = size * dpr;
  tester.view.gestureSettings = GestureSettings(physicalTouchSlop: 8 * dpr);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(
    theme: UiThemeName.maldives,
    home: Builder(
      builder: (context) => Center(
        child: UiButton(
          label: 'Open',
          onPressed: () => showUiDrawer<void>(
            context: context,
            side: side,
            title: 'Why cancel?',
            builder: (_) => const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              UiFormField(label: 'Reason', child: UiInput(value: '', semanticLabel: 'Reason')),
              SizedBox(height: 120),
              UiFormField(label: 'Note', child: UiInput(value: '', semanticLabel: 'Note')),
            ]),
            footerBuilder: (_) => UiButton(label: 'Cancel the job', block: true, onPressed: () {}),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.descendant(of: find.byWidgetPredicate((w) => w is UiInput && w.semanticLabel == label), matching: find.byType(EditableText));

/// The keyboard slides up over a few frames, as the platform reports it.
Future<void> _keyboard(WidgetTester tester, double to) async {
  final dpr = tester.view.devicePixelRatio;
  addTearDown(tester.view.resetViewInsets);
  for (var i = 1; i <= 8; i++) {
    tester.view.viewInsets = FakeViewPadding(bottom: to * dpr * i / 8);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a bottom drawer rises onto the keyboard: the focused field and the footer stay above it', (tester) async {
    await _open(tester);
    final before = tester.getRect(find.text('Why cancel?'));
    await tester.tap(_field('Note'));
    await _keyboard(tester, 300);
    const kbTop = 844.0 - 300;
    expect(tester.getRect(_field('Note')).bottom, lessThanOrEqualTo(kbTop), reason: 'the focused field is above the keyboard');
    expect(tester.getRect(find.text('Cancel the job')).bottom, lessThanOrEqualTo(kbTop), reason: 'the footer rests on the keyboard');
    expect(tester.getRect(find.text('Why cancel?')).top, lessThan(before.top), reason: 'the drawer rose');
    expect(tester.getRect(find.text('Why cancel?')).top, greaterThanOrEqualTo(0));
    // The keyboard goes: back to the screen edge.
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Why cancel?')).top, closeTo(before.top, 0.5));
  });

  testWidgets('on a short phone it shrinks to the space the keyboard leaves', (tester) async {
    await _open(tester, size: const Size(360, 600));
    await tester.tap(_field('Reason'));
    await _keyboard(tester, 300);
    expect(tester.getRect(find.text('Why cancel?')).top, greaterThanOrEqualTo(0), reason: 'the title stays on screen');
    expect(tester.getRect(find.text('Cancel the job')).bottom, lessThanOrEqualTo(300));
    expect(tester.getRect(_field('Reason')).bottom, lessThanOrEqualTo(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets("Find a nurse's sheet over its footer bar: the focused field and the footer are above the keyboard and the sheet rose", (tester) async {
    final dpr = tester.view.devicePixelRatio;
    tester.view.physicalSize = const Size(390, 844) * dpr;
    tester.view.gestureSettings = GestureSettings(physicalTouchSlop: 8 * dpr);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(theme: UiThemeName.maldives, home: const _FindNurse()));
    await tester.pumpAndSettle();
    final before = tester.getRect(find.text('Ask a nurse to visit'));
    await tester.tap(_field('Building'));
    await _keyboard(tester, 300);
    const kbTop = 844.0 - 300;
    expect(tester.getRect(find.text('Find a nurse')).bottom, lessThanOrEqualTo(kbTop));
    final f = tester.getRect(_field('Building'));
    expect(f.bottom, lessThanOrEqualTo(kbTop - 73), reason: 'above the footer bar too');
    expect(f.top, greaterThanOrEqualTo(0));
    expect(tester.getRect(find.text('Ask a nurse to visit')).top, lessThan(before.top), reason: 'it rose to its tallest snap');
  });

  testWidgets('side and top drawers are unchanged by the keyboard', (tester) async {
    await _open(tester, side: UiDrawerSide.top);
    final top = tester.getRect(find.text('Why cancel?'));
    await tester.tap(_field('Reason'));
    await _keyboard(tester, 300);
    expect(tester.getRect(find.text('Why cancel?')), top);
  });
}

/// Find a nurse's own tree (Dhirumi): a page frame that lifts the body above the keyboard and removes
/// the insets, a map, the sheet resting on an offset footer bar. Checked on a phone emulator in
/// 0.41.3: this one already rose onto the keyboard; kept so it stays that way.
class _FindNurse extends StatelessWidget {
  const _FindNurse();
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: Stack(children: [
            const Positioned.fill(child: ColoredBox(color: Color(0xffd1e6e9))),
            UiBottomSheet(
              glass: true,
              snaps: const [0.3, 0.55, 1],
              snap: 1,
              title: 'Ask a nurse to visit',
              closable: false,
              offset: 73,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final l in ['Island', 'Building', 'Floor', 'Apartment', 'Notes', 'Name', 'Phone'])
                  Padding(padding: const EdgeInsets.only(bottom: 24), child: UiFormField(label: l, child: UiInput(value: '', semanticLabel: l))),
              ]),
            ),
            Positioned(left: 0, right: 0, bottom: 0, height: 73, child: Center(child: UiButton(label: 'Find a nurse', onPressed: () {}))),
          ]),
        ),
      );
}
