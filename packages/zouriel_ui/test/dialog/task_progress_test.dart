import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// A page with a button that opens the progress dialog and records when it completes.
class _Opener extends StatelessWidget {
  const _Opener({required this.controller, required this.onDone, this.closeAtOnce = false});
  final UiTaskProgressController controller;
  final VoidCallback onDone;
  final bool closeAtOnce;

  @override
  Widget build(BuildContext context) {
    return UiButton(
      label: 'Save 40 photos',
      onPressed: () {
        showUiTaskProgress(context: context, controller: controller, title: 'Saving photos').then((_) => onDone());
        if (closeAtOnce) controller.close();
      },
    );
  }
}

void main() {
  group('UiTaskProgressController', () {
    test('update, cancel and close notify once each and keep their values', () {
      final c = UiTaskProgressController(total: 40, detail: 'IMG_1.jpg');
      var n = 0;
      c.addListener(() => n++);
      expect((c.done, c.total, c.detail, c.cancelled, c.closed), (0, 40, 'IMG_1.jpg', false, false));
      c.update(done: 12, detail: 'IMG_13.jpg');
      expect((c.done, c.total, c.detail), (12, 40, 'IMG_13.jpg'));
      c.update(done: 12);
      expect(n, 1, reason: 'no change, no notification');
      c.cancel();
      c.cancel();
      expect(c.cancelled, isTrue);
      c.close();
      c.close();
      expect(c.closed, isTrue);
      expect(n, 3);
      c.dispose();
    });
  });

  group('UiTaskProgress', () {
    testWidgets('title, "12 of 40", detail and a bar on the 0-100 scale; Cancel turns into Stopping', (tester) async {
      final handle = tester.ensureSemantics();
      final c = UiTaskProgressController(total: 40, done: 12, detail: 'IMG_0013.jpg');
      addTearDown(c.dispose);
      await pumpUi(tester, SizedBox(width: 360, child: UiTaskProgress(controller: c, title: 'Saving photos')));
      expect(find.text('Saving photos'), findsOneWidget);
      expect(find.text('12 of 40'), findsOneWidget);
      expect(find.text('IMG_0013.jpg'), findsOneWidget);
      expect(tester.widget<UiProgressBar>(find.byType(UiProgressBar)).value, 30, reason: '0-100, not 0-1');
      expect(tester.getSemantics(find.byType(UiProgressBar)).getSemanticsData().value, '30%');

      c.update(done: 40);
      await tester.pump();
      expect(find.text('40 of 40'), findsOneWidget);
      expect(tester.widget<UiProgressBar>(find.byType(UiProgressBar)).value, 100);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(c.cancelled, isTrue);
      expect(find.text('Stopping…'), findsOneWidget);
      final b = tester.widget<UiButton>(find.byType(UiButton));
      expect(b.loading, isTrue);
      expect(b.onPressed, isNull);
      handle.dispose();
    });

    testWidgets('total 0: no count and an indeterminate bar; a custom cancel label', (tester) async {
      final c = UiTaskProgressController();
      addTearDown(c.dispose);
      // The sweeping bar never settles: pump frames by hand.
      await tester.pumpWidget(UiApp(home: Align(alignment: Alignment.topLeft, child: SizedBox(width: 360, child: UiTaskProgress(controller: c, title: 'Preparing', cancelLabel: 'Stop')))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining(' of '), findsNothing);
      expect(tester.widget<UiProgressBar>(find.byType(UiProgressBar)).value, isNull);
      expect(find.text('Stop'), findsOneWidget);
    });

    testWidgets('golden: running and stopping', (tester) async {
      final a = UiTaskProgressController(total: 40, done: 12, detail: 'IMG_0013.jpg');
      final b = UiTaskProgressController(total: 40, done: 31)..cancel();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await expectThemedGolden(
        tester,
        'task_progress',
        height: 340,
        (context) => Column(spacing: 24, children: [
          UiTaskProgress(controller: a, title: 'Saving photos'),
          UiTaskProgress(controller: b, title: 'Saving photos'),
        ]),
      );
    });
  });

  group('showUiTaskProgress', () {
    testWidgets('opens a dialog that the barrier does not close; close() closes it and the future completes', (tester) async {
      final c = UiTaskProgressController(total: 3);
      addTearDown(c.dispose);
      var done = false;
      await pumpUi(tester, _Opener(controller: c, onDone: () => done = true));
      await tester.tap(find.text('Save 40 photos'));
      await tester.pumpAndSettle();
      expect(find.byType(UiTaskProgress), findsOneWidget);
      await tester.tapAt(const Offset(4, 800));
      await tester.pumpAndSettle();
      expect(find.byType(UiTaskProgress), findsOneWidget, reason: 'the barrier does not close it');
      expect(c.cancelled, isFalse);

      c.update(done: 3);
      c.close();
      await tester.pumpAndSettle();
      expect(find.byType(UiTaskProgress), findsNothing);
      expect(done, isTrue);
    });

    testWidgets('Cancel cancels; the dialog stays, Stopping, until close()', (tester) async {
      final c = UiTaskProgressController(total: 3);
      addTearDown(c.dispose);
      await pumpUi(tester, _Opener(controller: c, onDone: () {}));
      await tester.tap(find.text('Save 40 photos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      // The busy spinner never settles.
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.cancelled, isTrue);
      expect(find.text('Stopping…'), findsOneWidget);
      c.close();
      await tester.pumpAndSettle();
      expect(find.byType(UiTaskProgress), findsNothing);
    });

    testWidgets('back and Escape cancel instead of closing', (tester) async {
      final c = UiTaskProgressController(total: 3);
      addTearDown(c.dispose);
      await pumpUi(tester, _Opener(controller: c, onDone: () {}));
      await tester.tap(find.text('Save 40 photos'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.cancelled, isTrue, reason: 'back = cancel');
      expect(find.byType(UiTaskProgress), findsOneWidget);
      c.close();
      await tester.pumpAndSettle();

      final c2 = UiTaskProgressController(total: 3);
      addTearDown(c2.dispose);
      await pumpUi(tester, _Opener(controller: c2, onDone: () {}));
      await tester.tap(find.text('Save 40 photos'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));
      expect(c2.cancelled, isTrue, reason: 'Escape = cancel');
      expect(find.byType(UiTaskProgress), findsOneWidget);
      c2.close();
      await tester.pumpAndSettle();
    });

    testWidgets('close() before the route has finished opening (or before showing) still closes it', (tester) async {
      final c = UiTaskProgressController(total: 3);
      addTearDown(c.dispose);
      var done = false;
      await pumpUi(tester, _Opener(controller: c, onDone: () => done = true, closeAtOnce: true));
      await tester.tap(find.text('Save 40 photos'));
      await tester.pumpAndSettle();
      expect(find.byType(UiTaskProgress), findsNothing);
      expect(done, isTrue);

      // Already closed: nothing opens and it completes at once.
      done = false;
      await tester.tap(find.text('Save 40 photos'));
      await tester.pump();
      expect(find.byType(UiTaskProgress), findsNothing);
      await tester.pumpAndSettle();
      expect(done, isTrue);

      // Closed mid-animation.
      final c2 = UiTaskProgressController(total: 3);
      addTearDown(c2.dispose);
      var done2 = false;
      await pumpUi(tester, _Opener(controller: c2, onDone: () => done2 = true));
      await tester.tap(find.text('Save 40 photos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      c2.close();
      await tester.pumpAndSettle();
      expect(find.byType(UiTaskProgress), findsNothing);
      expect(done2, isTrue);
    });

    testWidgets('closes from under a dialog opened over it, leaving that one open', (tester) async {
      final c = UiTaskProgressController(total: 3);
      addTearDown(c.dispose);
      late BuildContext page;
      await pumpUi(tester, Builder(builder: (context) {
        page = context;
        return _Opener(controller: c, onDone: () {});
      }));
      await tester.tap(find.text('Save 40 photos'));
      await tester.pumpAndSettle();
      showUiConfirm(context: page, message: 'Over it');
      await tester.pumpAndSettle();
      c.close();
      await tester.pumpAndSettle();
      expect(find.byType(UiTaskProgress), findsNothing);
      expect(find.text('Over it'), findsOneWidget);
    });

    testWidgets('semantics: the title names the dialog; the bar is labelled with it', (tester) async {
      final handle = tester.ensureSemantics();
      final c = UiTaskProgressController(total: 4, done: 1);
      addTearDown(c.dispose);
      await pumpUi(tester, _Opener(controller: c, onDone: () {}), theme: UiThemeName.light);
      await tester.tap(find.text('Save 40 photos'));
      await tester.pumpAndSettle();
      final title = tester.getSemantics(find.text('Saving photos')).getSemanticsData();
      expect(title.flagsCollection.namesRoute, isTrue);
      expect(title.flagsCollection.isHeader, isTrue);
      final bar = tester.getSemantics(find.byType(UiProgressBar)).getSemanticsData();
      expect(bar.label, 'Saving photos');
      expect(bar.value, '25%');
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
