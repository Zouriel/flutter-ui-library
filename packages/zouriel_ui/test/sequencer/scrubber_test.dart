import 'dart:ui' show SemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

class _Host extends StatefulWidget {
  const _Host();
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  double value = 300;
  double zoom = 0.25;
  int presses = 0;
  final settles = <double>[];

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 360,
        child: UiScrubber(
          length: 2000,
          value: value,
          onChanged: (v) => setState(() => value = v),
          zoom: zoom,
          onZoomChanged: (z) => setState(() => zoom = z),
          end: 1500,
          lanes: const [UiScrubberLane(start: 0, end: 400), UiScrubberLane(start: 200, end: 900, selected: true)],
          onSettle: settles.add,
          onLongPress: () => presses++,
        ),
      );
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

void main() {
  test('packs lanes that overlap into separate rows, and ones that do not into one', () {
    final overlapping = uiPackScrubberLanes(const [UiScrubberLane(start: 0, end: 400), UiScrubberLane(start: 200, end: 900)]);
    expect(overlapping.tops[0], isNot(overlapping.tops[1]));
    final apart = uiPackScrubberLanes(const [UiScrubberLane(start: 0, end: 400), UiScrubberLane(start: 500, end: 900)]);
    expect(apart.tops[0], apart.tops[1]);
    expect(apart.height, 30);
    // Never more than six rows: the seventh reuses the first.
    final many = uiPackScrubberLanes([for (var i = 0; i < 7; i++) const UiScrubberLane(start: 0, end: 10)]);
    expect(many.tops[6], many.tops[0]);
  });

  testWidgets('a drag scrubs (content follows the finger) and settles once', (tester) async {
    await pumpUi(tester, const _Host());
    final g = await tester.startGesture(tester.getCenter(find.byType(UiScrubber)));
    await g.moveBy(const Offset(-20, 0));
    await g.moveBy(const Offset(-20, 0));
    await tester.pump(const Duration(milliseconds: 200));
    await g.up();
    await tester.pumpAndSettle();
    // 40px left at 0.25 px a unit: 160 units on.
    expect(_host(tester).value, closeTo(460, 1));
    expect(_host(tester).settles, hasLength(1));
    expect(_host(tester).presses, 0);
  });

  testWidgets('a flick glides on past where the finger let go', (tester) async {
    await pumpUi(tester, const _Host());
    await tester.flingFrom(tester.getCenter(find.byType(UiScrubber)), const Offset(-60, 0), 800);
    await tester.pump();
    final atRelease = _host(tester).value;
    await tester.pumpAndSettle();
    expect(_host(tester).value, greaterThan(atRelease));
    expect(_host(tester).settles, hasLength(1));
  });

  testWidgets('holding still is a long press, and the playhead stays where it was', (tester) async {
    await pumpUi(tester, const _Host());
    final g = await tester.startGesture(tester.getCenter(find.byType(UiScrubber)));
    await g.moveBy(const Offset(3, 1));
    await tester.pump(const Duration(milliseconds: 600));
    await g.up();
    await tester.pumpAndSettle();
    expect(_host(tester).presses, 1);
    expect(_host(tester).value, 300);
  });

  testWidgets('a slider from the keyboard and to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const _Host());
    final node = tester.getSemantics(find.bySemanticsLabel('Position'));
    expect(node.getSemanticsData().flagsCollection.isSlider, isTrue);
    expect(node.value, '300');
    tester.binding.pipelineOwner.semanticsOwner!.performAction(node.id, SemanticsAction.increase);
    await tester.pump();
    expect(_host(tester).value, 320);

    Focus.of(tester.element(find.descendant(of: find.byType(UiScrubber), matching: find.byType(Container)).first)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(_host(tester).value, 2000);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(_host(tester).value, 1800);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(_host(tester).value, 0);
    expect(tester.getSize(find.byType(UiScrubber)).height, greaterThanOrEqualTo(48));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('golden: sections, ticks, lanes and the end', (tester) async {
    await expectThemedGolden(tester, 'scrubber', height: 150, (context) => const Column(spacing: 12, children: [
          UiScrubber(
            length: 3376,
            value: 900,
            markers: [UiScrubberMarker(at: 0, label: 'Intro'), UiScrubberMarker(at: 700, label: 'Story'), UiScrubberMarker(at: 1500, label: 'Gallery'), UiScrubberMarker(at: 2600, label: 'RSVP')],
            ticks: [UiScrubberTick(at: 900, active: true), UiScrubberTick(at: 1000), UiScrubberTick(at: 1250)],
          ),
          UiScrubber(
            length: 3376,
            value: 900,
            end: 1300,
            lanes: [UiScrubberLane(start: 0, end: 800), UiScrubberLane(start: 300, end: 1400, selected: true), UiScrubberLane(start: 900, end: 1900, muted: true)],
          ),
        ]));
  });
}
