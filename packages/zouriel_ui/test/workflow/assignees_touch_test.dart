import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/editors.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

Future<void> _pump(WidgetTester tester, List<UiWfAssignee> value, ValueChanged<List<UiWfAssignee>> onChanged) =>
    pumpUi(tester, SizedBox(width: 360, child: WfAssigneesEditor(value: value, onChanged: onChanged)));

/// The tinted chip of each person (not whatever DecoratedBox happens to come first).
final _chip = find.byKey(const ValueKey('wf-person-chip'));

void main() {
  final people = [UiWfAssignee.fromJson({'role': 'reviewer'}), UiWfAssignee.fromJson({'role': 'finance'})];

  testWidgets('on a phone each chip’s remove target is a full 48px square while the chip stays 24px', variant: TargetPlatformVariant.only(TargetPlatform.android), (tester) async {
    List<UiWfAssignee>? changed;
    await _pump(tester, people, (v) => changed = v);
    final target = find.bySemanticsLabel(RegExp('^Remove '));
    expect(target, findsNWidgets(2));
    final size = tester.getSize(target.first);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(tester.getSize(_chip.first).height, 24);
    // A tap near the target's edge, well outside the 22px cross, still removes the person.
    final box = tester.getRect(target.first);
    await tester.tapAt(box.topLeft + const Offset(4, 4));
    expect(changed, hasLength(1));
  });

  testWidgets('with a mouse the chip keeps its compact 24px row', variant: TargetPlatformVariant.only(TargetPlatform.linux), (tester) async {
    await _pump(tester, people, (_) {});
    expect(tester.getSize(find.bySemanticsLabel(RegExp('^Remove ')).first).height, lessThan(30));
  });

  Future<({Rect chip, Rect label, Rect cross, Rect target})> measure(WidgetTester tester) async {
    await _pump(tester, people, (_) {});
    final chip = tester.getRect(_chip.first);
    final label = tester.getRect(find.descendant(of: _chip.first, matching: find.text('reviewer')));
    final target = find.bySemanticsLabel(RegExp('^Remove ')).first;
    final cross = tester.getRect(find.descendant(of: find.byType(WfAssigneesEditor), matching: find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 22)).first);
    return (chip: chip, label: label, cross: cross, target: tester.getRect(target));
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
    testWidgets('the label and the cross sit in the middle of the chip (${platform.name})', variant: TargetPlatformVariant.only(platform), (tester) async {
      final m = await measure(tester);
      expect(m.label.center.dy, moreOrLessEquals(m.chip.center.dy, epsilon: 0.5));
      expect(m.cross.center.dy, moreOrLessEquals(m.chip.center.dy, epsilon: 0.5));
      // The cross is the chip's last 22px, and the target is centred on it.
      expect(m.cross.right, moreOrLessEquals(m.chip.right, epsilon: 0.5));
      expect(m.target.center.dx, moreOrLessEquals(m.cross.center.dx, epsilon: 0.5));
      expect(m.target.center.dy, moreOrLessEquals(m.cross.center.dy, epsilon: 0.5));
    });
  }

  testWidgets('the tinted chip is as wide on touch as with a mouse', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final mouse = (await measure(tester)).chip.width;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final touch = (await measure(tester)).chip.width;
    debugDefaultTargetPlatformOverride = null;
    expect(touch, mouse);
  });
}
