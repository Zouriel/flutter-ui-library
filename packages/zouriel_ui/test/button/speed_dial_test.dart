import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

const _actions = [
  UiSpeedDialAction(id: 'upload', label: 'Add photos & videos', icon: UiIcon(HugeIcons.strokeRoundedImageUpload)),
  UiSpeedDialAction(id: 'camera', label: 'Open the camera', icon: UiIcon(HugeIcons.strokeRoundedCamera01)),
];

Future<void> _pumpDial(
  WidgetTester tester, {
  Key? key,
  List<UiSpeedDialAction> actions = _actions,
  UiFabTone tone = UiFabTone.inverted,
  UiFabPosition position = UiFabPosition.bottomEnd,
  TextDirection dir = TextDirection.ltr,
  Widget? icon,
  bool? rotateIcon,
  bool? open,
  ValueChanged<bool>? onOpenChanged,
  ValueChanged<String>? onAction,
  bool disabled = false,
  bool disableAnimations = false,
  FocusNode? focusNode,
  VoidCallback? onBackgroundTap,
}) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  tester.view.padding = FakeViewPadding(bottom: 16 * tester.view.devicePixelRatio);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(
    home: Directionality(
      textDirection: dir,
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
          child: UiFabHost(
            position: position,
            fab: UiSpeedDial(
              key: key,
              actions: actions,
              label: 'Add media',
              closeLabel: 'Close add media options',
              actionsLabel: 'Add media options',
              tone: tone,
              icon: icon,
              rotateIcon: rotateIcon,
              open: open,
              onOpenChanged: onOpenChanged,
              onAction: onAction,
              disabled: disabled,
              focusNode: focusNode,
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: UiButton(label: 'Behind', onPressed: onBackgroundTap ?? () {}),
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('toggles open/closed, rotates + 45deg to x, and announces expanded state', (tester) async {
    final sem = tester.ensureSemantics();
    final changes = <bool>[];
    await _pumpDial(tester, onOpenChanged: changes.add);

    expect(find.text('Add photos & videos'), findsNothing);
    expect(tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns, 0.0);
    var data = tester.getSemantics(find.bySemanticsLabel('Add media')).getSemanticsData();
    expect(data.flagsCollection.isExpanded, Tristate.isFalse);

    await tester.tap(find.bySemanticsLabel('Add media'));
    await tester.pumpAndSettle();

    expect(changes, [true]);
    expect(find.text('Add photos & videos'), findsOneWidget);
    expect(find.text('Open the camera'), findsOneWidget);
    expect(tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns, 0.125);
    data = tester.getSemantics(find.bySemanticsLabel('Close add media options')).getSemanticsData();
    expect(data.flagsCollection.isExpanded, Tristate.isTrue);

    await tester.tap(find.bySemanticsLabel('Close add media options'));
    await tester.pumpAndSettle();

    expect(changes, [true, false]);
    expect(find.text('Add photos & videos'), findsNothing);
    expect(tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns, 0.0);
    sem.dispose();
  });

  testWidgets('controlled open + onOpenChanged opens and closes cleanly', (tester) async {
    var open = false;
    final picked = <String>[];
    late StateSetter setHost;
    await tester.pumpWidget(UiApp(
      home: StatefulBuilder(
        builder: (context, setState) {
          setHost = setState;
          return UiFabHost(
            fab: UiSpeedDial(
              actions: _actions,
              label: 'Add media',
              closeLabel: 'Close add media options',
              tone: UiFabTone.inverted,
              open: open,
              onOpenChanged: (v) => setState(() => open = v),
              onAction: picked.add,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Add media'));
    await tester.pumpAndSettle();
    expect(open, isTrue);
    expect(find.text('Add photos & videos'), findsOneWidget);

    await tester.tap(find.text('Add photos & videos'));
    await tester.pumpAndSettle();
    expect(open, isFalse);
    expect(picked, ['upload']);
    expect(find.text('Add photos & videos'), findsNothing);

    setHost(() => open = true);
    await tester.pumpAndSettle();
    expect(find.text('Open the camera'), findsOneWidget);

    setHost(() => open = false);
    await tester.pumpAndSettle();
    expect(find.text('Open the camera'), findsNothing);
  });

  testWidgets('stacks smaller round FABs above trigger with label pills to their start side (LTR and RTL)', (tester) async {
    await _pumpDial(tester);
    await tester.tap(find.bySemanticsLabel('Add media'));
    await tester.pumpAndSettle();

    final trigger = tester.getRect(find.bySemanticsLabel('Close add media options'));
    final uploadFab = tester.getRect(find.bySemanticsLabel('Add photos & videos'));
    final cameraFab = tester.getRect(find.bySemanticsLabel('Open the camera'));
    final uploadPill = tester.getRect(find.text('Add photos & videos'));
    final cameraPill = tester.getRect(find.text('Open the camera'));

    // Both actions sit above the trigger, camera (index 1) above upload (index 0).
    expect(uploadFab.bottom, lessThan(trigger.top));
    expect(cameraFab.bottom, lessThan(uploadFab.top));
    // Action FABs are centred horizontally over the trigger.
    expect(uploadFab.center.dx, closeTo(trigger.center.dx, 0.5));
    expect(cameraFab.center.dx, closeTo(trigger.center.dx, 0.5));
    // In LTR, label pills sit to the left (start) of their round FABs.
    expect(uploadPill.right, lessThan(uploadFab.left));
    expect(cameraPill.right, lessThan(cameraFab.left));

    // In RTL, label pills sit to the right (start) of their round FABs.
    await _pumpDial(tester, key: const ValueKey('rtl'), dir: TextDirection.rtl);
    await tester.tap(find.bySemanticsLabel('Add media'));
    await tester.pumpAndSettle();

    final rtlUploadFab = tester.getRect(find.bySemanticsLabel('Add photos & videos'));
    final rtlUploadPill = tester.getRect(find.text('Add photos & videos'));
    expect(rtlUploadPill.left, greaterThan(rtlUploadFab.right));
  });

  testWidgets('tapping action pill or action FAB emits action id and closes; disabled actions are ignored', (tester) async {
    final picked = <String>[];
    final focus = FocusNode(debugLabel: 'test trigger');
    addTearDown(focus.dispose);
    await _pumpDial(
      tester,
      actions: const [
        UiSpeedDialAction(id: 'upload', label: 'Add photos & videos', icon: UiIcon(HugeIcons.strokeRoundedImageUpload)),
        UiSpeedDialAction(id: 'camera', label: 'Open the camera', icon: UiIcon(HugeIcons.strokeRoundedCamera01), disabled: true),
      ],
      onAction: picked.add,
      focusNode: focus,
    );

    await tester.tap(find.bySemanticsLabel('Add media'));
    await tester.pumpAndSettle();

    // Disabled pill and button do not fire or close.
    await tester.tap(find.text('Open the camera'));
    await tester.tap(find.bySemanticsLabel('Open the camera'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(picked, isEmpty);
    expect(find.text('Add photos & videos'), findsOneWidget);

    // Tapping enabled label pill fires action and closes.
    await tester.tap(find.text('Add photos & videos'));
    await tester.pumpAndSettle();
    expect(picked, ['upload']);
    expect(find.text('Add photos & videos'), findsNothing);

    // Tapping enabled action FAB fires action and closes.
    await tester.tap(find.bySemanticsLabel('Add media'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Add photos & videos'));
    await tester.pumpAndSettle();
    expect(picked, ['upload', 'upload']);
    expect(find.text('Add photos & videos'), findsNothing);
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('outside tap dismisses without clicking underlying button; Escape dismisses and restores focus', (tester) async {
    var behindTaps = 0;
    final focus = FocusNode(debugLabel: 'test trigger');
    addTearDown(focus.dispose);
    await _pumpDial(tester, focusNode: focus, onBackgroundTap: () => behindTaps++);

    // Outside tap over the underlying button closes dial and absorbs the tap.
    await tester.tap(find.bySemanticsLabel('Add media'));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.text('Behind')));
    await tester.pumpAndSettle();
    expect(find.text('Add photos & videos'), findsNothing);
    expect(behindTaps, 0);

    // Escape closes dial and restores focus to trigger.
    await tester.tap(find.bySemanticsLabel('Add media'));
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Add photos & videos'), findsNothing);
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('projected UiShutterLoader stays still at rest, does not rotate, and plays once on open and once on close', (tester) async {
    var cycles = 0;
    await _pumpDial(
      tester,
      icon: UiShutterLoader(size: 32, decorative: true, onCycleEnd: () => cycles++),
    );

    // Still at rest: no cycleEnd after a full shutter cycle elapses.
    await tester.pump(uiShutterCycle + const Duration(milliseconds: 100));
    expect(cycles, 0);
    expect(tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns, 0.0);

    // Opening plays one burst cycle and does not rotate the shutter.
    await tester.tap(find.bySemanticsLabel('Add media'));
    await tester.pump();
    expect(tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns, 0.0);
    await tester.pump(uiShutterCycle + const Duration(milliseconds: 50));
    expect(cycles, 1);

    // Stays still while open.
    await tester.pump(uiShutterCycle + const Duration(milliseconds: 100));
    expect(cycles, 1);

    // Closing plays a second burst cycle.
    await tester.tap(find.bySemanticsLabel('Close add media options'));
    await tester.pump();
    await tester.pump(uiShutterCycle + const Duration(milliseconds: 50));
    expect(cycles, 2);
  });

  testWidgets('staggered entrance leads bottom action before top action; reduced motion skips animation', (tester) async {
    await _pumpDial(tester, disableAnimations: false);
    await tester.tap(find.bySemanticsLabel('Add media'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Mid-entrance: upload (index 0) is further along in opacity than camera (index 1).
    final opacities = tester.widgetList<Opacity>(find.byType(Opacity)).toList();
    // Column renders top-to-bottom: index 1 (camera) first, index 0 (upload) second.
    expect(opacities, hasLength(2));
    expect(opacities[1].opacity, greaterThan(opacities[0].opacity));
    await tester.pumpAndSettle();

    // Reduced motion jumps straight open and straight closed on the first frame.
    await _pumpDial(tester, key: const ValueKey('reduced'), disableAnimations: true);
    await tester.tap(find.bySemanticsLabel('Add media'));
    await tester.pump();
    expect(find.byType(Opacity), findsNothing);
    expect(find.text('Add photos & videos'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Close add media options'));
    await tester.pump();
    expect(find.text('Add photos & videos'), findsNothing);
  });

  testWidgets('meets Android tap-target, label and contrast guidelines when open', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final sem = tester.ensureSemantics();
    await _pumpDial(tester);
    await tester.tap(find.bySemanticsLabel('Add media'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    sem.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('golden: inverted speed dial open with shutter trigger in dark and light', (tester) async {
    debugDisableShadows = false;
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(780, 260) * 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(
      theme: UiThemeName.dark,
      home: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final th in const [UiThemeName.dark, UiThemeName.light])
            SizedBox(
              width: 390,
              child: UiThemeScope(
                theme: th,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Align(
                    alignment: AlignmentDirectional.bottomEnd,
                    child: UiSpeedDial(
                      actions: _actions,
                      label: 'Add media',
                      closeLabel: 'Close add media options',
                      tone: UiFabTone.inverted,
                      open: true,
                      onOpenChanged: (_) {},
                      icon: const UiShutterLoader(size: 32, decorative: true, still: true),
                      onAction: (_) {},
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ));
    await tester.pumpAndSettle();
    try {
      await expectLater(find.byType(UiApp), matchesGoldenFile('goldens/speed_dial_open.png'));
    } finally {
      debugDisableShadows = true;
    }
  });
}
