import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// 0.40.0: the sheet holds still while someone types in it on a phone (the web bug: it jumped and
/// re-opened while typing the island). A 390x844 Android phone, the keyboard through viewInsets.

/// Snaps sized to the space the keyboard leaves, as Dhirumi's Find a nurse screen does: the peek must
/// show 320px of content, so a shorter screen has fewer steps.
List<double> _viewportSnaps(double height) {
  final room = math.max(1.0, height - 56);
  final peek = (320 / room).clamp(0.2, 1.0);
  final out = <double>[];
  for (final s in [(math.max(0.3, peek) * 100).round() / 100, 0.55, 1.0]) {
    if (out.isEmpty || s > out.last) out.add(s);
  }
  return out;
}

class _Host {
  int snap = 1;
  List<double>? fixed;
  final log = <int>[];
  final island = FocusNode(debugLabel: 'island');
  final building = FocusNode(debugLabel: 'building');
  final islandText = TextEditingController();
  final buildingText = TextEditingController();
  late StateSetter set;
  void dispose() {
    island.dispose();
    building.dispose();
    islandText.dispose();
    buildingText.dispose();
  }
}

Widget _field(TextEditingController c, FocusNode f) => SizedBox(
      height: 40,
      child: EditableText(controller: c, focusNode: f, style: const TextStyle(fontSize: 14), cursorColor: const Color(0x00000000), backgroundCursorColor: const Color(0x00000000)),
    );

Future<_Host> _pump(WidgetTester tester, {List<double>? fixed}) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final h = _Host()..fixed = fixed;
  addTearDown(h.dispose);
  await tester.pumpWidget(UiApp(
    home: StatefulBuilder(builder: (context, set) {
      h.set = set;
      final mq = MediaQuery.of(context);
      final snaps = h.fixed ?? _viewportSnaps(mq.size.height - mq.viewInsets.bottom);
      return Stack(children: [
        UiBottomSheet(
          snaps: snaps,
          snap: h.snap,
          title: 'Where should the nurse come?',
          closable: false,
          topInset: 56,
          onSnapChanged: (i) => set(() {
            h.snap = i;
            h.log.add(i);
          }),
          child: Column(children: [_field(h.islandText, h.island), _field(h.buildingText, h.building)]),
        ),
      ]);
    }),
  ));
  await tester.pumpAndSettle();
  return h;
}

UiBottomSheetState _state(WidgetTester tester) => tester.state<UiBottomSheetState>(find.byType(UiBottomSheet));

/// The sheet's top edge on screen (its title row).
double _top(WidgetTester tester) => tester.getTopLeft(find.text('Where should the nurse come?')).dy;

/// The keyboard slides up over a few frames, as the platform reports it.
Future<void> _keyboard(WidgetTester tester, double to, {void Function()? each}) async {
  final dpr = tester.view.devicePixelRatio;
  for (final k in [80.0, 180.0, 280.0, to]) {
    tester.view.viewInsets = FakeViewPadding(bottom: k * dpr);
    await tester.pump(const Duration(milliseconds: 16));
    each?.call();
  }
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  var value = '';
  for (final ch in text.split('')) {
    value += ch;
    tester.testTextInput.enterText(value);
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A test on an Android phone (the platform override is undone before the binding checks it).
void _phone(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  _phone('snaps sized to the space above the keyboard: stays open at its full height, no exception, no re-open loop', (tester) async {
    final h = await _pump(tester);
    expect(h.snap, 1);
    h.island.requestFocus();
    await tester.pumpAndSettle();
    expect(h.log, [2]); // risen once, on focus
    await _keyboard(tester, 336, each: () {
      expect(tester.takeException(), isNull);
      expect(_state(tester).isOpen, isTrue);
    });
    // The app's snaps lost their middle step; the sheet stays at the full one.
    final top = _top(tester);
    expect(h.island.hasFocus, isTrue);
    await _type(tester, 'Hulhumale');
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(_top(tester), top);
    }
    expect(h.islandText.text, 'Hulhumale');
    expect(h.island.hasFocus, isTrue);
    // The keyboard goes: back to three steps, still the full one.
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_state(tester).isOpen, isTrue);
    expect(h.snap, 2);
  });

  _phone('fixed snaps: one rise on focus, the keyboard opening and typing never move it again', (tester) async {
    final h = await _pump(tester, fixed: const [0.3, 0.55, 1]);
    h.island.requestFocus();
    await tester.pumpAndSettle();
    expect(h.log, [2]);
    await _keyboard(tester, 336);
    final top = _top(tester);
    await _type(tester, 'Maafushi');
    await tester.pumpAndSettle();
    expect(_top(tester), top);
    expect(h.log, [2]); // no re-expansion per keystroke or per viewInsets change
  });

  _phone('focus leaving the field and coming straight back does not raise a sheet the person lowered', (tester) async {
    final h = await _pump(tester, fixed: const [0.3, 0.55, 1]);
    h.island.requestFocus();
    await tester.pumpAndSettle();
    h.set(() => h.snap = 1); // lowered to see the map
    await tester.pumpAndSettle();
    h.island.unfocus();
    await tester.pump(const Duration(milliseconds: 100));
    h.island.requestFocus();
    await tester.pumpAndSettle();
    expect(h.snap, 1);
    // A different field is a new focus.
    h.building.requestFocus();
    await tester.pumpAndSettle();
    expect(h.snap, 2);
  });

  _phone('focus that really left and came back later raises it again', (tester) async {
    final h = await _pump(tester, fixed: const [0.3, 0.55, 1]);
    h.island.requestFocus();
    await tester.pumpAndSettle();
    h.set(() => h.snap = 1);
    await tester.pumpAndSettle();
    h.island.unfocus();
    await tester.pump(const Duration(milliseconds: 700));
    h.island.requestFocus();
    await tester.pumpAndSettle();
    expect(h.snap, 2);
  });

  _phone('an index past the end reads as the last snap, never closed', (tester) async {
    final h = await _pump(tester, fixed: const [0.3, 0.55, 1]);
    h.set(() => h.snap = 5);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_state(tester).isOpen, isTrue);
    expect(_top(tester), lessThan(56 + 60));
  });
}
