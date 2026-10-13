import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'host.dart';

const _presets = [
  UiChoice(value: 'fade', label: 'Fade', group: 'Entrances'),
  UiChoice(value: 'slide', label: 'Slide', group: 'Entrances'),
  UiChoice(value: 'zoom', label: 'Zoom', group: 'Entrances', disabled: true),
  UiChoice(value: 'pulse', label: 'Pulse', group: 'Loops', description: 'Gentle beat'),
  UiChoice(value: 'spin', label: 'Spin', group: 'Loops'),
];

void main() {
  group('UiChoiceGrid', () {
    testWidgets('tap chooses and picks; picking the chosen tile again still fires onPicked', (tester) async {
      final picked = <String>[];
      String? last;
      await pumpUi(tester, SizedBox(width: 360, child: Host<String?>(initial: null, builder: (v, set) => UiChoiceGrid<String>(
        options: _presets, value: v, onChanged: (n) { last = n; set(n); }, onPicked: (c) => picked.add(c.value)))));
      await tester.tap(find.text('Slide'));
      await tester.pump();
      await tester.tap(find.text('Slide'));
      await tester.tap(find.text('Zoom'));
      expect(last, 'slide');
      expect(picked, ['slide', 'slide']);
    });

    testWidgets('arrows move in reading order across groups, skipping disabled; Home/End; one tab stop', (tester) async {
      String? last;
      await pumpUi(tester, SizedBox(width: 360, child: Column(children: [
        Host<String?>(initial: 'slide', builder: (v, set) => UiChoiceGrid<String>(options: _presets, value: v, onChanged: (n) { last = n; set(n); })),
        UiButton(label: 'After', onPressed: () {}),
      ])));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'roving 1');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(last, 'pulse', reason: 'skips the disabled Zoom and crosses into the next group');
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(last, 'spin');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(last, 'spin', reason: 'stops at the end');
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(last, 'fade');
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'roving 0');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, isNot(startsWith('roving')));
    });

    testWidgets('columns fill the width with tiles at least minTile wide; rows share a height', (tester) async {
      await pumpUi(tester, SizedBox(width: 300, child: UiChoiceGrid<String>(options: _presets, value: null, minTile: 88, onChanged: (_) {})));
      // (300 + 8) / (88 + 8) = 3 columns of (300 - 16) / 3.
      final w = tester.getSize(find.ancestor(of: find.text('Fade'), matching: find.byType(UiInteractive))).width;
      expect(w, closeTo(284 / 3, 0.01));
      final pulse = tester.getSize(find.ancestor(of: find.text('Pulse'), matching: find.byType(AnimatedContainer)).first).height;
      final spin = tester.getSize(find.ancestor(of: find.text('Spin'), matching: find.byType(AnimatedContainer)).first).height;
      expect(spin, pulse, reason: 'a tile without a description stretches to its row');
      expect(find.text('Entrances'), findsOneWidget);
      expect(find.text('Loops'), findsOneWidget);
    });

    testWidgets('tileBuilder draws art and sees the selected state', (tester) async {
      await pumpUi(tester, SizedBox(width: 360, child: UiChoiceGrid<String>(options: _presets, value: 'fade', onChanged: (_) {},
          tileBuilder: (context, item, selected) => Text(selected ? 'ON ${item.label}' : 'art'))));
      expect(find.text('ON Fade'), findsOneWidget);
      expect(find.text('art'), findsNWidgets(4));
    });

    testWidgets('semantics: a named radio group with exclusive tiles and group headings', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, SizedBox(width: 360, child: UiChoiceGrid<String>(label: 'Effects', options: _presets, value: 'spin', onChanged: (_) {})));
      expect(tester.getSemantics(find.bySemanticsLabel('Effects')).getSemanticsData().role, SemanticsRole.radioGroup);
      expect(tester.getSemantics(find.text('Spin')), isSemantics(isChecked: true, isInMutuallyExclusiveGroup: true));
      expect(tester.getSemantics(find.text('Fade')), isSemantics(isChecked: false, isInMutuallyExclusiveGroup: true));
      expect(tester.getSemantics(find.text('Loops')), isSemantics(isHeader: true));
      handle.dispose();
    });
  });

  group('UiAnchorPicker', () {
    testWidgets('tap picks a point; arrows move and clamp; dots are named', (tester) async {
      final handle = tester.ensureSemantics();
      UiAnchor? last;
      await pumpUi(tester, Host<UiAnchor?>(initial: null, builder: (v, set) => UiAnchorPicker(value: v, onChanged: (n) { last = n; set(n); })));
      expect(tester.getSemantics(find.bySemanticsLabel('Centre')), isSemantics(isChecked: true, isInMutuallyExclusiveGroup: true));
      await tester.tap(find.bySemanticsLabel('Top right'));
      await tester.pump();
      expect(last, const UiAnchor(1, 0));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(last, const UiAnchor(1, 0), reason: 'clamps at the edge');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(last, const UiAnchor(0.5, 0.5));
      expect(tester.getSemantics(find.bySemanticsLabel('Centre')), isSemantics(isFocused: true, isChecked: true));
      handle.dispose();
    });

    testWidgets('a value between the dots shows none chosen; Tab still enters at the centre', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, UiAnchorPicker(value: const UiAnchor(0.3, 0.7), onChanged: (_) {}));
      for (final n in ['Top left', 'Centre', 'Bottom right']) {
        expect(tester.getSemantics(find.bySemanticsLabel(n)), isSemantics(isChecked: false));
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.getSemantics(find.bySemanticsLabel('Centre')), isSemantics(isFocused: true));
      handle.dispose();
    });

    testWidgets('disabled ignores taps', (tester) async {
      await pumpUi(tester, const UiAnchorPicker(value: UiAnchor.centre, onChanged: null));
      await tester.tapAt(tester.getTopLeft(find.byType(UiAnchorPicker)) + const Offset(10, 10));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('meets the Android tap-target, labelled-target and contrast guidelines', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final handle = tester.ensureSemantics();
    await pumpUi(tester, Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 16, children: [
        UiChoiceGrid<String>(options: _presets.where((p) => !p.disabled).toList(), value: 'fade', onChanged: (_) {}),
        UiAnchorPicker(value: UiAnchor.centre, onChanged: (_) {}),
      ]),
    ));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('golden: choice grid and anchor picker', (tester) async {
    await expectThemedGolden(tester, 'grid', height: 520, (context) {
      final t = context.ui;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          UiChoiceGrid<String>(options: _presets, value: 'pulse', onChanged: (_) {}),
          UiChoiceGrid<String>(
            minTile: 100,
            options: const [UiChoice(value: 'a', label: 'Sunrise'), UiChoice(value: 'b', label: 'Ocean'), UiChoice(value: 'c', label: 'Forest')],
            value: 'b',
            onChanged: (_) {},
            tileBuilder: (context, item, selected) => Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: selected ? t.primary : t.border, borderRadius: BorderRadius.circular(t.radiusSm)),
            ),
          ),
          Row(spacing: 16, children: [
            UiAnchorPicker(value: const UiAnchor(0, 0), onChanged: (_) {}),
            UiAnchorPicker(value: const UiAnchor(1, 0.5), onChanged: null),
          ]),
        ],
      );
    });
  });
}
