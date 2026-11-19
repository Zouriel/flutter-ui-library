import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

void main() {
  group('showUiBottomSheet', () {
    testWidgets('opens with title, body, footerLeading, footer and completes with popped value', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);

      late BuildContext hostContext;
      await tester.pumpWidget(UiApp(
        home: Builder(builder: (ctx) {
          hostContext = ctx;
          return const SizedBox.shrink();
        }),
      ));

      final future = showUiBottomSheet<String>(
        context: hostContext,
        title: 'Feed photos',
        builder: (ctx) => const UiText('Pick up to six photos.'),
        footerLeadingBuilder: (ctx) => const UiText('3 / 6', variant: UiTextVariant.caption),
        footerBuilder: (ctx) => Row(
          mainAxisSize: MainAxisSize.min,
          spacing: ctx.ui.space2,
          children: [
            UiButton(label: 'Clear', variant: UiButtonVariant.ghost, size: UiSize.sm, onPressed: () {}),
            UiButton(label: 'Save', size: UiSize.sm, onPressed: () => Navigator.pop(ctx, 'saved')),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UiBottomSheet), findsOneWidget);
      expect(find.text('Feed photos'), findsOneWidget);
      expect(find.text('Pick up to six photos.'), findsOneWidget);
      expect(find.text('3 / 6'), findsOneWidget);

      // Leading counter sits left of the action buttons in LTR.
      final counterRect = tester.getRect(find.text('3 / 6'));
      final clearRect = tester.getRect(find.widgetWithText(UiButton, 'Clear'));
      final saveRect = tester.getRect(find.widgetWithText(UiButton, 'Save'));
      expect(counterRect.right, lessThan(clearRect.left));
      expect(clearRect.right, lessThan(saveRect.left));

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(await future, 'saved');
      expect(find.byType(UiBottomSheet), findsNothing);
    });

    testWidgets('close button, backdrop tap and Escape each close it; closeOnBackdrop/Escape false keep it open', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);

      late BuildContext hostContext;
      await tester.pumpWidget(UiApp(
        home: Builder(builder: (ctx) {
          hostContext = ctx;
          return const SizedBox.shrink();
        }),
      ));

      // 1. Close button
      var future = showUiBottomSheet<void>(context: hostContext, title: 'Sheet', builder: (_) => const UiText('Body'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(UiDialogCloseButton));
      await tester.pumpAndSettle();
      expect(find.byType(UiBottomSheet), findsNothing);
      await future;

      // 2. Backdrop tap above the sheet
      future = showUiBottomSheet<void>(context: hostContext, title: 'Sheet', snaps: const [0, 0.5], builder: (_) => const UiText('Body'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();
      expect(find.byType(UiBottomSheet), findsNothing);
      await future;

      // 3. Escape closes by default
      future = showUiBottomSheet<void>(context: hostContext, title: 'Sheet', builder: (_) => const UiText('Body'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(UiBottomSheet), findsNothing);
      await future;

      // 4. closeOnBackdrop: false and closeOnEscape: false keep it open
      future = showUiBottomSheet<void>(
        context: hostContext,
        title: 'Locked',
        snaps: const [0, 0.5],
        closeOnBackdrop: false,
        closeOnEscape: false,
        builder: (_) => const UiText('Body'),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();
      expect(find.text('Locked'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Locked'), findsOneWidget);

      Navigator.of(hostContext, rootNavigator: true).pop();
      await tester.pumpAndSettle();
      await future;
    });
  });

  group('showUiModal(sheetBelow:) & footerLeading', () {
    testWidgets('opens UiBottomSheet below sheetBelow (390px) and UiModal at/above sheetBelow (1024px)', (tester) async {
      // Narrow viewport -> bottom sheet
      tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);

      late BuildContext hostContext;
      await tester.pumpWidget(UiApp(
        home: Builder(builder: (ctx) {
          hostContext = ctx;
          return const SizedBox.shrink();
        }),
      ));

      final narrowFuture = showUiModal<String>(
        context: hostContext,
        title: 'Responsive',
        sheetBelow: 768,
        sheetSnaps: const [0, 0.85],
        builder: (_) => const UiText('Content'),
        footerLeadingBuilder: (_) => const UiText('3 / 6', variant: UiTextVariant.caption),
        footerBuilder: (ctx) => UiButton(label: 'Done', size: UiSize.sm, onPressed: () => Navigator.pop(ctx, 'narrow')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UiBottomSheet), findsOneWidget);
      expect(find.byType(UiModal), findsNothing);
      expect(find.text('3 / 6'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(await narrowFuture, 'narrow');

      // Wide viewport -> centred modal
      tester.view.physicalSize = const Size(1024, 768) * tester.view.devicePixelRatio;
      await tester.pumpAndSettle();

      final wideFuture = showUiModal<String>(
        context: hostContext,
        title: 'Responsive',
        sheetBelow: 768,
        builder: (_) => const UiText('Content'),
        footerLeadingBuilder: (_) => const UiText('3 / 6', variant: UiTextVariant.caption),
        footerBuilder: (ctx) => UiButton(label: 'Done', size: UiSize.sm, onPressed: () => Navigator.pop(ctx, 'wide')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UiModal), findsOneWidget);
      expect(find.byType(UiBottomSheet), findsNothing);
      expect(find.text('3 / 6'), findsOneWidget);

      final counterRect = tester.getRect(find.text('3 / 6'));
      final doneRect = tester.getRect(find.widgetWithText(UiButton, 'Done'));
      expect(counterRect.right, lessThan(doneRect.left));

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(await wideFuture, 'wide');
    });

    testWidgets('mirrors footerLeading and footer in RTL for both UiModal and UiBottomSheet', (tester) async {
      tester.view.physicalSize = const Size(480, 700) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(UiApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: UiModal(
            title: 'RTL Modal',
            footerLeading: const UiText('3 / 6', variant: UiTextVariant.caption),
            footer: UiButton(label: 'Save', size: UiSize.sm, onPressed: () {}),
            child: const UiText('Body'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final counterRect = tester.getRect(find.text('3 / 6'));
      final saveRect = tester.getRect(find.widgetWithText(UiButton, 'Save'));
      // In RTL, inline-start (counter) is to the right of inline-end (Save).
      expect(counterRect.left, greaterThan(saveRect.right));
    });

    testWidgets('meets tap-target, label and contrast guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(480, 700) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(UiApp(
        home: UiModal(
          title: 'Feed photos',
          footerLeading: const UiText('3 / 6', variant: UiTextVariant.caption),
          footer: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              UiButton(label: 'Clear', variant: UiButtonVariant.ghost, size: UiSize.sm, onPressed: () {}),
              UiButton(label: 'Save', size: UiSize.sm, onPressed: () {}),
            ],
          ),
          child: const UiText('Select up to six cover photos.'),
        ),
      ));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('golden: modal and bottom sheet footers with footerLeading', (tester) async {
      await expectThemedGolden(
        tester,
        'modal_footer_leading',
        (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            UiModal(
              title: 'Feed photos',
              footerLeading: const UiText('3 / 6', variant: UiTextVariant.caption),
              footer: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: context.ui.space2,
                children: [
                  UiButton(label: 'Clear', variant: UiButtonVariant.ghost, size: UiSize.sm, onPressed: () {}),
                  UiButton(label: 'Save', size: UiSize.sm, onPressed: () {}),
                ],
              ),
              child: const UiText('Choose up to six photos for the event cover.', variant: UiTextVariant.caption),
            ),
            Expanded(
              child: Stack(
                children: [
                  const SizedBox.expand(),
                  UiBottomSheet(
                    title: 'Feed photos',
                    snaps: const [0.95],
                    snap: 0,
                    footerLeading: const UiText('3 / 6', variant: UiTextVariant.caption),
                    footer: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: context.ui.space2,
                      children: [
                        UiButton(label: 'Clear', variant: UiButtonVariant.ghost, size: UiSize.sm, onPressed: () {}),
                        UiButton(label: 'Save', size: UiSize.sm, onPressed: () {}),
                      ],
                    ),
                    child: const UiText('Choose up to six photos for the event cover.', variant: UiTextVariant.caption),
                  ),
                ],
              ),
            ),
          ],
        ),
        height: 520,
      );
    });
  });
}
