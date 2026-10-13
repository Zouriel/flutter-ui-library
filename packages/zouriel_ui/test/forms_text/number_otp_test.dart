import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// A controlled number input that records every change.
class _Num extends StatefulWidget {
  const _Num({this.initial, this.min, this.max, this.precision, this.label = '', required this.log});
  final num? initial;
  final num? min, max;
  final int? precision;
  final String label;
  final List<num?> log;
  @override
  State<_Num> createState() => _NumState();
}

class _NumState extends State<_Num> {
  late num? v = widget.initial;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 300,
        child: UiNumberInput(
          value: v,
          min: widget.min,
          max: widget.max,
          precision: widget.precision,
          label: widget.label,
          semanticLabel: 'Amount',
          onChanged: (x) => setState(() {
            v = x;
            widget.log.add(x);
          }),
        ),
      );
}

EditableText _editable(WidgetTester tester, [int i = 0]) => tester.widget<EditableText>(find.byType(EditableText).at(i));

void main() {
  group('number input', () {
    testWidgets('a typed value in range passes at once; out of range waits and clamps on Enter', (tester) async {
      final log = <num?>[];
      await pumpUi(tester, _Num(initial: 10, min: 4, max: 100, log: log));
      // "18" with a minimum of 4: the "1" must not be raised to 4 while typing.
      await tester.enterText(find.byType(EditableText), '1');
      expect(log, isEmpty);
      await tester.enterText(find.byType(EditableText), '18');
      expect(log, [18]);
      expect(_editable(tester).controller.text, '18');
      await tester.enterText(find.byType(EditableText), '1000');
      expect(log, [18]);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(log.last, 100);
      expect(_editable(tester).controller.text, '100');
    });

    testWidgets('leaving the field clamps; an emptied field is null; an unchanged field is quiet', (tester) async {
      final log = <num?>[];
      await pumpUi(tester, Column(children: [_Num(initial: 5, min: 0, max: 10, log: log), const SizedBox(width: 300, child: UiInput(semanticLabel: 'Other'))]));
      await tester.tap(find.byType(EditableText).first);
      await tester.pump();
      await tester.tap(find.byType(EditableText).last);
      await tester.pump();
      expect(log, isEmpty, reason: 'focusing and leaving without a change is not a change');
      await tester.enterText(find.byType(EditableText).first, '-3');
      await tester.tap(find.byType(EditableText).last);
      await tester.pump();
      expect(log.last, 0);
      await tester.enterText(find.byType(EditableText).first, '');
      await tester.tap(find.byType(EditableText).last);
      await tester.pump();
      expect(log.last, isNull);
    });

    testWidgets('focus selects the number so typing replaces it', (tester) async {
      await pumpUi(tester, _Num(initial: 42, log: []));
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(_editable(tester).controller.selection, const TextSelection(baseOffset: 0, extentOffset: 2));
    });

    testWidgets('steppers and arrow keys step, clamped and rounded to precision', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <num?>[];
      await pumpUi(tester, _Num(initial: 9.5, max: 10, precision: 1, log: log));
      await tester.tap(find.bySemanticsLabel('Increment'));
      await tester.pump();
      expect(log.last, 10);
      await tester.tap(find.bySemanticsLabel('Decrement'));
      await tester.pump();
      expect(log.last, 9);
      await tester.tap(find.byType(EditableText));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(log.last, 10);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(log.last, 9);
      // Side by side at the end, each a full touch target.
      final dec = tester.getRect(find.bySemanticsLabel('Decrement'));
      final inc = tester.getRect(find.bySemanticsLabel('Increment'));
      expect(dec.right, inc.left);
      expect(dec.top, inc.top);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('dragging the label scrubs the value by step per 2px', (tester) async {
      final log = <num?>[];
      await pumpUi(tester, _Num(initial: 10, label: 'X', log: log));
      final start = tester.getCenter(find.text('X'));
      final g = await tester.startGesture(start);
      await g.moveBy(const Offset(20, 0));
      await tester.pump();
      await g.moveBy(const Offset(20, 0));
      await tester.pump();
      await g.up();
      expect(log.last, 30);
    });
  });

  group('otp input', () {
    testWidgets('typing fills a cell and moves on; holes keep their positions', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      await pumpUi(tester, UiOtpInput(length: 4, onChanged: log.add));
      expect(find.bySemanticsLabel('Digit 1'), findsOneWidget);
      expect(find.bySemanticsLabel('One-time code'), findsOneWidget);
      await tester.tap(find.byType(EditableText).first);
      await tester.enterText(find.byType(EditableText).at(0), '1');
      expect(log.last, '1');
      expect(_editable(tester, 1).focusNode.hasFocus, isTrue);
      await tester.enterText(find.byType(EditableText).at(1), '2');
      // Skip the third cell.
      await tester.enterText(find.byType(EditableText).at(3), '4');
      expect(log.last, '12 4');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('a value written back fills the same cells', (tester) async {
      await pumpUi(tester, const UiOtpInput(length: 4, value: '1 3'));
      expect([for (var i = 0; i < 4; i++) _editable(tester, i).controller.text], ['1', '', '3', '']);
    });

    testWidgets('non-digits are refused in a numeric code', (tester) async {
      final log = <String>[];
      await pumpUi(tester, UiOtpInput(length: 4, onChanged: log.add));
      await tester.enterText(find.byType(EditableText).first, 'a');
      expect(log, isEmpty);
      expect(_editable(tester).controller.text, '');
    });

    testWidgets('a whole code pasted or autofilled into any cell fills from the first', (tester) async {
      final log = <String>[];
      await pumpUi(tester, UiOtpInput(length: 6, onChanged: log.add));
      await tester.enterText(find.byType(EditableText).at(5), '123456');
      expect(log.last, '123456');
      expect([for (var i = 0; i < 6; i++) _editable(tester, i).controller.text].join(), '123456');
    });

    testWidgets('Backspace in an empty cell and the arrow keys move between cells', (tester) async {
      await pumpUi(tester, const UiOtpInput(length: 4, value: '12'));
      await tester.tap(find.byType(EditableText).at(2));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(_editable(tester, 1).focusNode.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(_editable(tester, 0).focusNode.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_editable(tester, 1).focusNode.hasFocus, isTrue);
    });

    test('incomplete-code validation matches the web', () {
      final v = UiOtpInput.validator(length: 4);
      expect(v(''), isNull, reason: 'empty is valid; add required to make it mandatory');
      expect(v('12'), isNotNull);
      expect(v('12 4'), isNotNull, reason: 'a hole is incomplete');
      expect(v('1234'), isNull);
      expect(UiOtpInput.filledCount('12 4', 4), 3);
    });

    testWidgets('in a Form, an incomplete code fails validation', (tester) async {
      final form = GlobalKey<FormState>();
      await pumpUi(tester, Form(
        key: form,
        child: UiFormField<String>.validated(
          label: 'Code',
          validator: UiOtpInput.validator(length: 4),
          builder: (f) => UiOtpInput(length: 4, value: f.value, onChanged: f.didChange),
        ),
      ));
      await tester.enterText(find.byType(EditableText).first, '1');
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Enter all 4 characters (1 of 4 so far)'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).first, '1234');
      expect(form.currentState!.validate(), isTrue);
    });
  });

  group('editable text', () {
    testWidgets('tap opens a field with the text selected; Enter commits', (tester) async {
      final log = <String>[];
      await pumpUi(tester, UiEditableText(value: 'Roadmap', semanticLabel: 'Board name', onChanged: log.add));
      await tester.tap(find.text('Roadmap'));
      await tester.pumpAndSettle();
      final e = _editable(tester);
      expect(e.focusNode.hasFocus, isTrue);
      expect(e.controller.selection, const TextSelection(baseOffset: 0, extentOffset: 7));
      await tester.enterText(find.byType(EditableText), 'Q4 plan');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(log, ['Q4 plan']);
      expect(find.byType(EditableText), findsNothing);
    });

    testWidgets('Escape cancels; Enter on the focused view opens it', (tester) async {
      final log = <String>[];
      await pumpUi(tester, UiEditableText(value: 'Roadmap', semanticLabel: 'Board name', onChanged: log.add));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'Changed');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      expect(find.text('Roadmap'), findsOneWidget);
    });

    testWidgets('is named with its label and text, and shows the pencil on touch', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, UiEditableText(value: 'Roadmap', semanticLabel: 'Board name', onChanged: (_) {}));
      expect(find.bySemanticsLabel('Board name: Roadmap'), findsOneWidget);
      expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 1);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
