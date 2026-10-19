import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

const _rows = [
  UiSequencerRow(id: 'a', label: 'Title', kind: 'Text', start: 10, end: 40, keyframes: [UiSequencerKeyframe(id: 'k1', at: 0.5, label: 'Fade')]),
  UiSequencerRow(id: 'b', label: 'Photo', start: 50, end: 80, fixed: true),
  UiSequencerRow(id: 'c', label: 'Logo', start: 20, end: 60, locked: true),
];

/// A host that applies every change, like a real app would, and records them.
class _Host extends StatefulWidget {
  const _Host({this.showLabels = true, this.rowHeight = 30, this.end, this.endDraggable = false, this.compact = false, this.rows = _rows});
  final bool showLabels;
  final double rowHeight;
  final double? end;
  final bool endDraggable;
  final bool compact;
  final List<UiSequencerRow> rows;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<UiSequencerRow> rows = widget.rows;
  double playhead = 0;
  String? selected;
  String? keyframe;
  double zoom = 1;
  final ranges = <UiSequencerRangeChange>[];
  final keys = <UiSequencerKeyframeChange>[];
  final deletes = <String>[];
  final menus = <UiSequencerKeyframeRef>[];
  final reorders = <(String, int)>[];
  final ends = <(double, bool)>[];
  final scrubs = <double>[];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 600,
      height: 200,
      child: UiSequencer(
        rows: rows,
        length: 100,
        markers: const [UiSequencerMarker(at: 0, label: 'Intro'), UiSequencerMarker(at: 45, label: 'Gallery')],
        showLabels: widget.showLabels,
        compact: widget.compact,
        rowHeight: widget.rowHeight,
        end: widget.end,
        endDraggable: widget.endDraggable,
        playhead: playhead,
        onPlayheadChanged: (v) => setState(() => playhead = v),
        zoom: zoom,
        onZoomChanged: (z) => setState(() => zoom = z),
        selectedRowId: selected,
        onSelectedRowIdChanged: (v) => setState(() => selected = v),
        selectedKeyframeId: keyframe,
        onSelectedKeyframeIdChanged: (v) => setState(() => keyframe = v),
        onRangeChange: (c) => setState(() {
          ranges.add(c);
          rows = [for (final r in rows) r.id == c.rowId ? r.copyWith(start: c.start, end: c.end) : r];
        }),
        onKeyframeChange: keys.add,
        onKeyframeDelete: (r, k) => deletes.add(k),
        onKeyframeMenu: menus.add,
        onRowReorder: (id, to) => reorders.add((id, to)),
        onEndChange: (e, f) => ends.add((e, f)),
        onScrub: scrubs.add,
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester, Widget host) async {
  await pumpUi(tester, host, size: const Size(800, 400));
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));
Finder _bar(String label) => find.bySemanticsLabel(RegExp('^$label: '));

/// Semantics on: the tests find parts by their accessible names.
void _testWidgets(String description, WidgetTesterCallback body) => testWidgets(description, body, semanticsEnabled: true);

void main() {
  _testWidgets('draws labels, a ruler with markers, and a bar per row', (tester) async {
    await _pump(tester, const _Host());
    expect(find.text('LAYERS'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Intro'), findsOneWidget);
    expect(find.bySemanticsLabel('Title: 10 to 40'), findsOneWidget);
    expect(find.bySemanticsLabel('Keyframe Fade at 50%'), findsOneWidget);
  });

  _testWidgets('a mouse drag moves a bar, snapping to a marker, and reports final once', (tester) async {
    await _pump(tester, const _Host());
    final bar = tester.getRect(_bar('Title'));
    // 400px of lane for 100 units: 4px a unit. Move by ~33 units: the start lands near 43 and snaps to the marker at 45.
    final g = await tester.startGesture(bar.centerLeft + const Offset(20, 0), kind: PointerDeviceKind.mouse);
    // 136px is 34 units: the start lands on 44, within 6px (1.5 units) of the marker at 45.
    await g.moveBy(const Offset(20, 0));
    await g.moveBy(const Offset(116, 0));
    await tester.pump();
    await g.up();
    await tester.pump();
    final h = _host(tester);
    expect(h.ranges.where((r) => r.isFinal), hasLength(1));
    expect(h.ranges.last, const UiSequencerRangeChange(rowId: 'a', start: 45, end: 75, isFinal: true));
    expect(h.ranges.first.isFinal, isFalse);
  });

  _testWidgets('the edges trim; a fixed bar has none and a locked one does not move', (tester) async {
    await _pump(tester, const _Host());
    final bar = tester.getRect(_bar('Title'));
    // The end edge sits just outside the bar's right side.
    final g = await tester.startGesture(bar.centerRight + const Offset(6, 0), kind: PointerDeviceKind.mouse);
    await g.moveBy(const Offset(10, 0));
    await g.moveBy(const Offset(30, 0));
    await g.up();
    await tester.pump();
    final last = _host(tester).ranges.last;
    expect(last.start, 10);
    expect(last.end, closeTo(50, 0.01));
    expect(last.isFinal, isTrue);

    // Photo is fixed: just past its end there's no edge, only its lane (which moves the playhead).
    final photo = tester.getRect(_bar('Photo'));
    final g1 = await tester.startGesture(photo.centerRight + const Offset(6, 0), kind: PointerDeviceKind.mouse);
    await g1.moveBy(const Offset(40, 0));
    await g1.up();
    await tester.pump();
    expect(_host(tester).ranges.where((r) => r.rowId == 'b'), isEmpty);

    final locked = tester.getRect(_bar('Logo'));
    final g2 = await tester.startGesture(locked.center, kind: PointerDeviceKind.mouse);
    await g2.moveBy(const Offset(40, 0));
    await g2.up();
    await tester.pump();
    expect(_host(tester).ranges.where((r) => r.rowId == 'c'), isEmpty);
  });

  _testWidgets('keyboard: a focused bar moves and trims; a diamond retimes, deletes and asks for its menu', (tester) async {
    await _pump(tester, const _Host());
    final bar = Focus.of(tester.element(find.descendant(of: _bar('Title'), matching: find.byType(MouseRegion)).first));
    bar.requestFocus();
    await tester.pump();
    expect(_host(tester).selected, 'a');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_host(tester).ranges.last, const UiSequencerRangeChange(rowId: 'a', start: 11, end: 41, isFinal: true));
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
    await tester.pump();
    expect(_host(tester).ranges.last.end, closeTo(42, 1e-9));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(_host(tester).ranges.last.start, closeTo(1, 1e-9));

    final diamond = Focus.of(tester.element(find.descendant(of: find.bySemanticsLabel('Keyframe Fade at 50%'), matching: find.byType(MouseRegion)).first));
    diamond.requestFocus();
    await tester.pump();
    expect(_host(tester).keyframe, 'k1');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(_host(tester).keys.last.at, closeTo(0.51, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    expect(_host(tester).deletes, ['k1']);
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    expect(_host(tester).menus.single.keyframeId, 'k1');
  });

  _testWidgets('a long press on a diamond asks for its menu; a tap on a lane moves the playhead', (tester) async {
    await _pump(tester, const _Host());
    await tester.longPress(find.bySemanticsLabel('Keyframe Fade at 50%'));
    await tester.pump();
    expect(_host(tester).menus, hasLength(1));
    // An empty stretch of Photo's lane, at 30% along the timeline (which runs 12px in from each end).
    final photo = tester.getRect(_bar('Photo'));
    await tester.tapAt(Offset(200 + 12 + (400 - 24) * 0.3, photo.center.dy));
    await tester.pump();
    expect(_host(tester).playhead, closeTo(30, 0.5));
    expect(_host(tester).scrubs, hasLength(1));
  });

  _testWidgets('bars only: a tap selects the bar and shows its name for a moment', (tester) async {
    await _pump(tester, const _Host(showLabels: false, end: 70));
    expect(find.text('LAYERS'), findsNothing);
    expect(find.text('Title'), findsNothing);
    await tester.tap(_bar('Title'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_host(tester).selected, 'a');
    expect(find.text('Title'), findsOneWidget);
    expect(find.bySemanticsLabel('Hide Title'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('Title'), findsNothing);
  });

  _testWidgets('bars only: holding a bar lifts it, then it follows the finger', (tester) async {
    await _pump(tester, const _Host(showLabels: false));
    final bar = tester.getRect(_bar('Title'));
    final g = await tester.startGesture(bar.centerLeft + const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 500));
    // 600px of lane for 100 units: 6px a unit; 60px is 10 units.
    await g.moveBy(const Offset(30, 0));
    await g.moveBy(const Offset(30, 0));
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(_host(tester).ranges.last, const UiSequencerRangeChange(rowId: 'a', start: 20, end: 50, isFinal: true));
    expect(find.text('Title'), findsNothing);
  });

  _testWidgets('bars only: a swipe that starts moving before the hold changes nothing', (tester) async {
    await _pump(tester, const _Host(showLabels: false));
    final bar = tester.getRect(_bar('Title'));
    final g = await tester.startGesture(bar.centerLeft + const Offset(30, 0));
    await g.moveBy(const Offset(40, 20));
    await tester.pump(const Duration(milliseconds: 500));
    await g.up();
    await tester.pump();
    expect(_host(tester).ranges, isEmpty);
    expect(find.text('Title'), findsNothing);
  });

  _testWidgets('a ruler label moves past the End grip sitting on it, never under it', (tester) async {
    await _pump(tester, const _Host(end: 47, endDraggable: true));
    expect(find.text('Intro'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    final grip = tester.getRect(find.bySemanticsLabel('Drag to change where it ends'));
    final label = tester.getRect(find.text('Gallery'));
    expect(label.left, greaterThanOrEqualTo(grip.right + 4 - 0.01)); // beside the grip, not under it
    await _pump(tester, const _Host(end: 90, endDraggable: true));
    expect(tester.getRect(find.text('Gallery')).left, lessThan(grip.right)); // back at its line, which the grip covered
  });

  _testWidgets('a draggable end reports past the timeline too, and once more when let go; arrows move it', (tester) async {
    await _pump(tester, const _Host(end: 60, endDraggable: true, rows: []));
    expect(find.text('Nothing here yet'), findsOneWidget);
    final handle = find.bySemanticsLabel('Drag to change where it ends');
    expect(handle, findsOneWidget);
    final g = await tester.startGesture(tester.getCenter(handle), kind: PointerDeviceKind.mouse);
    await g.moveBy(const Offset(40, 0));
    await g.moveTo(const Offset(1000, 10));
    await g.up();
    await tester.pump();
    final ends = _host(tester).ends;
    expect(ends.last.$2, isTrue);
    expect(ends.last.$1, greaterThan(100));
    expect(ends.any((e) => !e.$2), isTrue);

    Focus.of(tester.element(find.descendant(of: handle, matching: find.byType(Container)).first)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(_host(tester).ends.last, (61.0, true));
  });

  _testWidgets('rows are never shorter than 25px, and a keyframe has a full-size target', (tester) async {
    await _pump(tester, const _Host(rowHeight: 18));
    expect(tester.getSize(find.descendant(of: _bar('Title'), matching: find.byType(MouseRegion)).first).height, 24);
    // Touch platform (tests run as Android): 48 wide and the full row tall, centred on its keyframe.
    final d = tester.getSize(find.bySemanticsLabel('Keyframe Fade at 50%'));
    expect(d.width, 48);
    expect(d.height, 25);
  });

  _testWidgets('compact keeps the name and visibility toggle; drops the kind and lock', (tester) async {
    await _pump(tester, const _Host(compact: true));
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('TEXT'), findsNothing);
    expect(find.bySemanticsLabel('Hide Title'), findsOneWidget);
    expect(find.bySemanticsLabel('Lock Title'), findsNothing);
  });

  _testWidgets('semantics and guidelines', (tester) async {
    await _pump(tester, const _Host());
    expect(tester.getSemantics(find.bySemanticsLabel('Playhead')).getSemanticsData().flagsCollection.isSlider, isTrue);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  _testWidgets('golden: labelled timeline', (tester) async {
    await expectThemedGolden(tester, 'sequencer', width: 600, height: 210, (context) => const SizedBox(
          height: 170,
          child: UiSequencer(
            rows: _rows,
            length: 100,
            playhead: 30,
            selectedRowId: 'a',
            markers: [UiSequencerMarker(at: 0, label: 'Intro'), UiSequencerMarker(at: 45, label: 'Gallery'), UiSequencerMarker(at: 80, label: 'RSVP')],
            labelWidth: 240,
          ),
        ));
  });

  _testWidgets('golden: bars only with a name tip, past the end shaded', (tester) async {
    await expectThemedGolden(tester, 'sequencer_bars', height: 170, (context) => const SizedBox(
          height: 130,
          child: UiSequencer(rows: _rows, length: 100, showLabels: false, end: 70, playhead: 30, selectedRowId: 'a', endDraggable: true),
        ));
    await tester.tap(_bar('Title').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/sequencer_bars_tip.png'));
    await tester.pump(const Duration(seconds: 3));
  });
}
