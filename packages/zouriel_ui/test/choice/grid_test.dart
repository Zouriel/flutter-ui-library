import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
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

  group('UiChoiceGrid align and tone', () {
    const scale = [
      UiChoice(value: '5', label: 'Very satisfied', tone: UiChoiceTone.success),
      UiChoice(value: '4', label: 'Satisfied', tone: UiChoiceTone.info),
      UiChoice(value: '3', label: 'Neutral', tone: UiChoiceTone.neutral),
      UiChoice(value: '2', label: 'Dissatisfied', tone: UiChoiceTone.warning),
      UiChoice(value: '1', label: 'Very dissatisfied', tone: UiChoiceTone.danger, description: 'Tell us why'),
    ];
    BoxDecoration box(WidgetTester tester, String label) =>
        tester.widget<AnimatedContainer>(find.ancestor(of: find.text(label), matching: find.byType(AnimatedContainer)).first).decoration! as BoxDecoration;
    Rect tileRect(WidgetTester tester, String label) => tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(AnimatedContainer)).first);
    double tickOpacity(WidgetTester tester, String label) => tester
        .widget<AnimatedOpacity>(find.descendant(of: find.ancestor(of: find.text(label), matching: find.byType(Stack)).first, matching: find.byKey(const ValueKey('ui-choice-tick'))))
        .opacity;

    testWidgets('center centres compact words across and down; start keeps them at the start edge', (tester) async {
      for (final align in UiChoiceAlign.values) {
        await pumpUi(tester, SizedBox(width: 360, child: UiChoiceGrid<String>(options: scale, value: null, minTile: 100, align: align, onChanged: (_) {})));
        // 3 columns: Very satisfied, Satisfied, Neutral / Dissatisfied, Very dissatisfied (+ description).
        final tile = tileRect(tester, 'Dissatisfied');
        final label = tester.getRect(find.text('Dissatisfied'));
        if (align == UiChoiceAlign.center) {
          expect(label.center.dx, closeTo(tile.center.dx, 1), reason: 'centred across');
          expect(label.center.dy, closeTo(tile.center.dy, 1), reason: 'centred down beside a taller neighbour');
          expect(tester.getRect(find.text('Tell us why')).center.dx, closeTo(tileRect(tester, 'Very dissatisfied').center.dx, 1));
        } else {
          expect(label.left, closeTo(tile.left + 1 + 12, 1), reason: 'border + toned padding');
          expect(label.top, closeTo(tile.top + 1 + 16, 1));
        }
        expect(tileRect(tester, 'Dissatisfied').height, tileRect(tester, 'Very dissatisfied').height, reason: 'a row shares its height');
      }
    });

    testWidgets('a toned tile is tinted at rest and takes its tone, a 2px edge and a tick when chosen; no tone looks as before', (tester) async {
      await pumpUi(tester, SizedBox(width: 360, child: UiChoiceGrid<String>(
          options: [...scale, const UiChoice(value: 'x', label: 'Plain')], value: '5', onChanged: (_) {})));
      final t = tester.element(find.byType(UiChoiceGrid<String>)).ui;
      final chosen = box(tester, 'Very satisfied');
      expect(chosen.color, Color.lerp(t.surface, t.success, 0.1));
      expect((chosen.border! as Border).top.color, t.success);
      expect((chosen.border! as Border).top.width, 2);
      expect(tickOpacity(tester, 'Very satisfied'), 1);
      final rest = box(tester, 'Dissatisfied');
      expect(rest.color, Color.lerp(t.surface, t.warning, 0.05));
      expect((rest.border! as Border).top.color, Color.lerp(t.border, t.warning, 0.5));
      expect(tickOpacity(tester, 'Dissatisfied'), 0);
      final plain = box(tester, 'Plain');
      expect(plain.color, t.surface);
      expect((plain.border! as Border).top.color, t.border);
      expect(find.ancestor(of: find.text('Plain'), matching: find.byType(Stack)), findsNothing, reason: 'no tick badge without a tone');
      // Each tone draws from its own token.
      for (final (label, color) in [('Satisfied', t.info), ('Neutral', t.textMuted), ('Very dissatisfied', t.danger)]) {
        expect(box(tester, label).color, Color.lerp(t.surface, color, 0.05), reason: label);
      }
    });

    testWidgets('hover strengthens the wash and the edge', (tester) async {
      await pumpUi(tester, SizedBox(width: 360, child: UiChoiceGrid<String>(options: scale, value: null, onChanged: (_) {})));
      final t = tester.element(find.byType(UiChoiceGrid<String>)).ui;
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Neutral')));
      await tester.pumpAndSettle();
      expect(box(tester, 'Neutral').color, Color.lerp(t.surface, t.textMuted, 0.08));
      expect((box(tester, 'Neutral').border! as Border).top.color, Color.lerp(t.border, t.textMuted, 0.8));
      await mouse.removePointer();
    });

    testWidgets('keeps the label and description AA on every toned fill, and the tick 3:1, in every theme', (tester) async {
      double lum(Color c) {
        double f(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
      }
      double ratio(Color a, Color b) {
        final x = lum(a), y = lum(b);
        return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
      }
      final fails = <String>[];
      for (final theme in UiThemeName.values) {
        for (final chosen in [null, ...scale.map((c) => c.value)]) {
          await pumpUi(tester, SizedBox(width: 360, child: UiChoiceGrid<String>(options: scale, value: chosen, onChanged: (_) {})), theme: theme);
          final t = uiThemeTokens[theme]!;
          final page = Color.alphaBlend(t.surface, t.bg);
          for (final c in scale) {
            if (chosen != null && c.value != chosen) continue;
            final fill = Color.alphaBlend(box(tester, c.label).color!, page);
            for (final text in [c.label, if (c.description != null) c.description!]) {
              final fg = Color.alphaBlend(tester.renderObject<RenderParagraph>(find.text(text)).text.style!.color!, fill);
              final r = ratio(fg, fill);
              if (r < 4.5) fails.add('${theme.name}/${c.label}${chosen == null ? '' : ' chosen'}: "$text" ${r.toStringAsFixed(2)}:1');
            }
          }
        }
        final t = uiThemeTokens[theme]!;
        for (final (name, color, ink) in [('primary', t.primary, t.primaryContrast), ('success', t.success, t.successContrast), ('info', t.info, t.infoContrast),
            ('warning', t.warning, t.warningContrast), ('danger', t.danger, t.dangerContrast), ('neutral', t.textMuted, t.surface)]) {
          final badge = Color.alphaBlend(color, Color.alphaBlend(t.surface, t.bg));
          final r = ratio(Color.alphaBlend(ink, badge), badge);
          if (r < 3) fails.add('${theme.name}/$name: tick ${r.toStringAsFixed(2)}:1');
        }
      }
      expect(fails, isEmpty);
    });

    testWidgets('keyboard still chooses toned tiles; semantics unchanged; the tick is not announced', (tester) async {
      final handle = tester.ensureSemantics();
      String? last;
      await pumpUi(tester, SizedBox(width: 360, child: Host<String?>(initial: '4', builder: (v, set) => UiChoiceGrid<String>(
          label: 'Satisfaction', options: scale, value: v, align: UiChoiceAlign.center, onChanged: (n) { last = n; set(n); }))));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(last, '3');
      expect(tester.getSemantics(find.text('Neutral')), isSemantics(isChecked: true, isInMutuallyExclusiveGroup: true, isFocused: true));
      expect(find.bySemanticsLabel(RegExp('tick', caseSensitive: false)), findsNothing);
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

  testWidgets('golden: a toned, centred satisfaction scale on the violet liquid themes', (tester) async {
    await expectThemedGolden(tester, 'grid_tones', height: 200, themes: const [UiThemeName.violetDark, UiThemeName.violet], (context) {
      return UiChoiceGrid<String>(
        minTile: 104,
        align: UiChoiceAlign.center,
        options: const [
          UiChoice(value: '5', label: 'Very satisfied', tone: UiChoiceTone.success),
          UiChoice(value: '4', label: 'Satisfied', tone: UiChoiceTone.info),
          UiChoice(value: '3', label: 'Neutral', tone: UiChoiceTone.neutral),
          UiChoice(value: '2', label: 'Dissatisfied', tone: UiChoiceTone.warning),
          UiChoice(value: '1', label: 'Very dissatisfied', tone: UiChoiceTone.danger, description: 'Tell us why'),
        ],
        value: '4',
        onChanged: (_) {},
      );
    });
  });

  testWidgets('golden: choice grid and anchor picker', (tester) async {
    await expectThemedGolden(tester, 'grid', height: 680, (context) {
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
          UiChoiceGrid<String>(
            minTile: 96,
            align: UiChoiceAlign.center,
            options: const [
              UiChoice(value: '5', label: 'Very satisfied', tone: UiChoiceTone.success),
              UiChoice(value: '4', label: 'Satisfied', tone: UiChoiceTone.info),
              UiChoice(value: '3', label: 'Neutral', tone: UiChoiceTone.neutral),
              UiChoice(value: '2', label: 'Dissatisfied', tone: UiChoiceTone.warning),
              UiChoice(value: '1', label: 'Very dissatisfied', tone: UiChoiceTone.danger),
            ],
            value: '4',
            onChanged: (_) {},
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
