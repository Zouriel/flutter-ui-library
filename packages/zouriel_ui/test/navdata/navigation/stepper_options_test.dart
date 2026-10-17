import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../../helpers.dart';

const steps = [UiStep(label: 'One'), UiStep(label: 'Two'), UiStep(label: 'Three')];

void main() {
  group('UiStepper options', () {
    testWidgets('vertical: each step shows its body with its index and state', (tester) async {
      await pumpUi(
        tester,
        SizedBox(width: 300, child: UiStepper(steps: steps, active: 1, axis: Axis.vertical, body: (context, i, state) => Text('$i:${state.name}'))),
      );
      expect(find.text('0:done'), findsOneWidget);
      expect(find.text('1:active'), findsOneWidget);
      expect(find.text('2:todo'), findsOneWidget);
    });

    testWidgets('a body that returns null takes no room', (tester) async {
      await pumpUi(tester, SizedBox(width: 300, child: UiStepper(steps: steps, active: 1, axis: Axis.vertical, body: (context, i, state) => null)));
      expect(find.text('One'), findsOneWidget);
    });

    for (final axis in Axis.values) {
      testWidgets('dots ($axis): 30px from dot to dot, a line of 8 with 6 clear on each side, like the web', (tester) async {
        await pumpUi(tester, UiStepper(steps: steps, active: 1, variant: UiStepperVariant.dots, axis: axis, label: 'Progress'));
        final dots = find.descendant(of: find.byType(UiStepper), matching: find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 10 && w.constraints?.maxHeight == 10));
        expect(dots, findsNWidgets(3));
        final a = tester.getRect(dots.at(0)), b = tester.getRect(dots.at(1));
        // The web: a 10px dot, then 6 + 8 + 6 (the bar and its margins; vertically padding-bottom 20 with the bar from 16 to 24).
        expect(axis == Axis.horizontal ? b.left - a.left : b.top - a.top, 30);
      });
    }

    testWidgets('golden: dots, the current ring clear of the lines', (tester) async {
      await expectThemedGolden(
        tester,
        'stepper_dots',
        (context) => const Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 48, children: [
          UiStepper(steps: steps, active: 1, variant: UiStepperVariant.dots, label: 'Progress'),
          UiStepper(steps: steps, active: 1, variant: UiStepperVariant.dots, axis: Axis.vertical, tone: UiStepperTone.success, label: 'Progress'),
        ]),
        width: 240,
        height: 120,
      );
    });

    testWidgets('dots: no numbers, each dot read with its state, in the tone', (tester) async {
      final h = tester.ensureSemantics();
      await pumpUi(tester, const UiStepper(steps: steps, active: 1, variant: UiStepperVariant.dots, tone: UiStepperTone.success, label: 'Progress'));
      expect(find.text('1'), findsNothing);
      expect(find.text('One'), findsNothing);
      expect(find.bySemanticsLabel('One, done'), findsOneWidget);
      expect(find.bySemanticsLabel('Two, current'), findsOneWidget);
      expect(find.bySemanticsLabel('Three, not reached'), findsOneWidget);
      final dots = tester.widgetList<Container>(find.descendant(of: find.byType(UiStepper), matching: find.byType(Container)))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.shape == BoxShape.circle)
          .toList();
      final t = tester.element(find.byType(UiStepper)).ui;
      expect(dots.map((d) => d.color), [t.success, t.success, t.text]);
      expect(dots[1].boxShadow, isNotNull); // the current dot is ringed
      h.dispose();
    });

    testWidgets('vertical dots stack in a column', (tester) async {
      await pumpUi(tester, const UiStepper(steps: steps, active: 0, variant: UiStepperVariant.dots, axis: Axis.vertical));
      final size = tester.getSize(find.byType(UiStepper));
      expect(size.height, greaterThan(size.width));
    });
  });

  group('UiDrawerPeek', () {
    testWidgets('slides a drawer over the page without blocking it', (tester) async {
      var taps = 0;
      var open = true;
      late StateSetter set;
      await pumpUi(
        tester,
        StatefulBuilder(builder: (context, s) {
          set = s;
          return SizedBox(
            width: 390,
            height: 800,
            child: UiDrawerPeek(
              open: open,
              title: 'Peek',
              onClose: () => s(() => open = false),
              drawer: (context) => const Text('Inside'),
              child: Align(alignment: Alignment.topLeft, child: UiButton(label: 'Behind', onPressed: () => taps++)),
            ),
          );
        }),
      );
      expect(find.text('Inside'), findsOneWidget);
      await tester.tap(find.text('Behind'));
      expect(taps, 1); // the page under a peek still works
      set(() => open = false);
      await tester.pumpAndSettle();
      expect(find.text('Inside'), findsNothing);
    });
  });
}
