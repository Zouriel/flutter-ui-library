import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

class _Event {
  const _Event(this.id, this.title, {this.locked = false});
  final String id;
  final String title;
  final bool locked;
}

const _events = [
  _Event('a', 'Dinner'),
  _Event('b', 'Locked party', locked: true),
  _Event('c', 'Beach trip'),
];

void _phoneSlop(WidgetTester tester) {
  tester.view.gestureSettings = ui.GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
  addTearDown(tester.view.resetGestureSettings);
}

Widget _tile(BuildContext context, _Event ev) {
  final t = context.ui;
  return Container(
    key: ValueKey('tile-${ev.id}'),
    height: 64,
    padding: EdgeInsets.symmetric(horizontal: t.space3),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: t.surfaceRaised,
      borderRadius: BorderRadius.circular(t.radius),
      border: Border.all(color: t.border),
    ),
    child: UiText(ev.title, variant: UiTextVariant.label),
  );
}

Widget _board({
  List<_Event> events = _events,
  bool scrollable = false,
  Map<String, FocusNode>? focusNodes,
  void Function(String from, String onto)? onDrop,
  void Function(String id)? onStart,
  void Function(String id)? onCancel,
  void Function(String id)? onEnd,
  void Function(String id, bool over)? onHover,
}) {
  return Builder(builder: (context) {
    final t = context.ui;
    final items = [
      for (final ev in events)
        Padding(
          padding: EdgeInsets.only(bottom: t.space3),
          child: UiDropTarget<_Event>(
            key: ValueKey('drop-${ev.id}'),
            label: ev.title,
            accepts: (p) => !ev.locked && p.id != ev.id,
            onDropped: (p) => onDrop?.call(p.id, ev.id),
            onHoverChanged: (over) => onHover?.call(ev.id, over),
            child: UiDragItem<_Event>(
              key: ValueKey('drag-${ev.id}'),
              data: ev,
              label: ev.title,
              focusNode: focusNodes?[ev.id],
              onDragStart: (p) => onStart?.call(p.id),
              onDragCancel: (p) => onCancel?.call(p.id),
              onDragEnd: (p) => onEnd?.call(p.id),
              child: _tile(context, ev),
            ),
          ),
        ),
    ];

    if (scrollable) {
      return SizedBox(
        width: 390,
        height: 600,
        child: ListView(
          padding: EdgeInsets.all(t.space4),
          children: [
            ...items,
            const SizedBox(height: 1000),
          ],
        ),
      );
    }
    return SizedBox(
      width: 360,
      child: Padding(
        padding: EdgeInsets.all(t.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items,
        ),
      ),
    );
  });
}

void main() {
  group('UiDragItem & UiDropTarget', () {
    testWidgets('mouse drag starts after movement, dims source, shows ghost, highlights valid target and drops', (tester) async {
      final starts = <String>[];
      final ends = <String>[];
      final cancels = <String>[];
      final hovers = <(String, bool)>[];
      final drops = <(String, String)>[];

      await pumpUi(
        tester,
        _board(
          onStart: starts.add,
          onEnd: ends.add,
          onCancel: cancels.add,
          onHover: (id, over) => hovers.add((id, over)),
          onDrop: (from, onto) => drops.add((from, onto)),
        ),
      );

      final startCenter = tester.getCenter(find.byKey(const ValueKey('tile-a')));
      final targetCenter = tester.getCenter(find.byKey(const ValueKey('tile-c')));

      final g = await tester.startGesture(startCenter, kind: ui.PointerDeviceKind.mouse);
      await g.moveTo(startCenter + const Offset(20, 0));
      await tester.pump();

      expect(starts, ['a']);
      expect(find.byKey(const ValueKey('ui-drag-ghost')), findsOneWidget);
      final opacity = tester.widget<Opacity>(
        find.descendant(of: find.byKey(const ValueKey('drag-a')), matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, closeTo(0.4, 0.01));

      await g.moveTo(targetCenter);
      await tester.pump();
      expect(hovers, [('c', true)]);

      await g.up();
      await tester.pumpAndSettle();

      expect(drops, [('a', 'c')]);
      expect(ends, ['a']);
      expect(cancels, isEmpty);
      expect(find.byKey(const ValueKey('ui-drag-ghost')), findsNothing);
      final coordinator = UiDragCoordinator.of(tester.element(find.byKey(const ValueKey('drag-a'))));
      expect(coordinator.lastAnnouncement, 'Dropped Dinner on Beach trip');
    });

    testWidgets('accepts predicate blocks invalid targets from highlighting or receiving drops', (tester) async {
      final hovers = <(String, bool)>[];
      final drops = <(String, String)>[];
      final cancels = <String>[];

      await pumpUi(
        tester,
        _board(
          onHover: (id, over) => hovers.add((id, over)),
          onDrop: (from, onto) => drops.add((from, onto)),
          onCancel: cancels.add,
        ),
      );

      final startCenter = tester.getCenter(find.byKey(const ValueKey('tile-a')));
      final lockedCenter = tester.getCenter(find.byKey(const ValueKey('tile-b')));

      final g = await tester.startGesture(startCenter, kind: ui.PointerDeviceKind.mouse);
      await g.moveTo(lockedCenter);
      await tester.pump();
      expect(hovers, isEmpty);

      await g.up();
      await tester.pumpAndSettle();
      expect(drops, isEmpty);
      expect(cancels, ['a']);
    });

    testWidgets('Escape cancels an active pointer drag without dropping', (tester) async {
      final drops = <(String, String)>[];
      final cancels = <String>[];
      final ends = <String>[];

      await pumpUi(
        tester,
        _board(
          onDrop: (from, onto) => drops.add((from, onto)),
          onCancel: cancels.add,
          onEnd: ends.add,
        ),
      );

      final startCenter = tester.getCenter(find.byKey(const ValueKey('tile-a')));
      final targetCenter = tester.getCenter(find.byKey(const ValueKey('tile-c')));

      final g = await tester.startGesture(startCenter, kind: ui.PointerDeviceKind.mouse);
      await g.moveTo(targetCenter);
      await tester.pump();
      expect(find.byKey(const ValueKey('ui-drag-ghost')), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await g.up();
      await tester.pumpAndSettle();

      expect(drops, isEmpty);
      expect(cancels, ['a']);
      expect(ends, ['a']);
      expect(find.byKey(const ValueKey('ui-drag-ghost')), findsNothing);
    });

    testWidgets('touch inside a Scrollable: quick swipe scrolls, long press drags and drops', (tester) async {
      _phoneSlop(tester);
      final starts = <String>[];
      final drops = <(String, String)>[];

      await pumpUi(
        tester,
        _board(
          scrollable: true,
          onStart: starts.add,
          onDrop: (from, onto) => drops.add((from, onto)),
        ),
      );

      // Quick touch swipe scrolls the ListView and never starts a drag.
      await tester.drag(find.byKey(const ValueKey('tile-a')), const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(starts, isEmpty);
      expect(drops, isEmpty);
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(scrollable.position.pixels, greaterThan(0));

      // Scroll back to top, then long press and drag onto tile C.
      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();

      final startCenter = tester.getCenter(find.byKey(const ValueKey('tile-a')));
      final targetCenter = tester.getCenter(find.byKey(const ValueKey('tile-c')));

      final g = await tester.startGesture(startCenter, kind: ui.PointerDeviceKind.touch);
      await tester.pump(uiLongPressDuration + const Duration(milliseconds: 50));
      expect(starts, ['a']);
      expect(find.byKey(const ValueKey('ui-drag-ghost')), findsOneWidget);

      await g.moveTo(targetCenter);
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();

      expect(drops, [('a', 'c')]);
      expect(find.byKey(const ValueKey('ui-drag-ghost')), findsNothing);
    });

    testWidgets('keyboard pick-up cycles valid targets, drops with announcement, and cancels on Escape', (tester) async {
      final nodes = {'a': FocusNode(), 'b': FocusNode(), 'c': FocusNode()};
      addTearDown(() {
        for (final n in nodes.values) {
          n.dispose();
        }
      });
      final drops = <(String, String)>[];
      final cancels = <String>[];
      final hovers = <(String, bool)>[];

      await pumpUi(
        tester,
        _board(
          focusNodes: nodes,
          onDrop: (from, onto) => drops.add((from, onto)),
          onCancel: cancels.add,
          onHover: (id, over) => hovers.add((id, over)),
        ),
      );

      nodes['a']!.requestFocus();
      await tester.pump();

      // Space picks up A; only C is valid (A is self, B is locked).
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(hovers, [('c', true)]);

      // Enter drops onto C.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(drops, [('a', 'c')]);
      final coordinator = UiDragCoordinator.of(tester.element(find.byKey(const ValueKey('drag-a'))));
      expect(coordinator.lastAnnouncement, 'Dropped Dinner on Beach trip');

      // Pick up again and Escape cancels.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(cancels, ['a']);
      expect(drops.length, 1);
    });

    testWidgets('reduced motion skips the ghost lift animation', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(UiApp(
        theme: UiThemeName.dark,
        config: const UiConfig(animations: false),
        home: Align(alignment: Alignment.topLeft, child: _board()),
      ));
      await tester.pumpAndSettle();

      final startCenter = tester.getCenter(find.byKey(const ValueKey('tile-a')));
      final g = await tester.startGesture(startCenter, kind: ui.PointerDeviceKind.mouse);
      await g.moveTo(startCenter + const Offset(20, 0));
      await tester.pump();

      final ghost = find.byKey(const ValueKey('ui-drag-ghost'));
      expect(ghost, findsOneWidget);
      expect(find.descendant(of: ghost, matching: find.byType(TweenAnimationBuilder<double>)), findsNothing);
      final transform = tester.widget<Transform>(
        find.descendant(of: ghost, matching: find.byType(Transform)).first,
      );
      expect(transform.transform.getMaxScaleOnAxis(), 1.0);

      await g.up();
      await tester.pumpAndSettle();
    });

    testWidgets('semantics and accessibility guidelines pass', (tester) async {
      final sem = tester.ensureSemantics();
      try {
        await pumpUi(tester, _board());

        final data = tester.getSemantics(find.byKey(const ValueKey('drag-a'))).getSemanticsData();
        expect(data.label, contains('Dinner'));
        expect(data.hint, contains('Long press'));

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        sem.dispose();
      }
    });

    testWidgets('golden: resting and hovered drop target in dark and light', (tester) async {
      await expectThemedGolden(
        tester,
        'drag_targets',
        (context) {
          final t = context.ui;
          final r = BorderRadius.circular(t.radius);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: t.space3,
            children: [
              Opacity(
                opacity: 0.4,
                child: _tile(context, const _Event('a', 'Dinner (dragging)')),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: r,
                  boxShadow: [
                    BoxShadow(color: t.bg, spreadRadius: 2, blurRadius: 0),
                    BoxShadow(color: t.accent, spreadRadius: 4, blurRadius: 0),
                  ],
                ),
                child: _tile(context, const _Event('c', 'Beach trip (valid target)')),
              ),
              _tile(context, const _Event('b', 'Locked party', locked: true)),
            ],
          );
        },
        height: 280,
      );
    });
  });
}
