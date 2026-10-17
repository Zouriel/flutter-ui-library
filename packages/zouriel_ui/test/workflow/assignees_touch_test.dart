import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/editors.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

Future<void> _pump(WidgetTester tester, List<UiWfAssignee> value, ValueChanged<List<UiWfAssignee>> onChanged) =>
    pumpUi(tester, SizedBox(width: 360, child: WfAssigneesEditor(value: value, onChanged: onChanged)));

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
    expect(tester.getSize(find.byType(DecoratedBox).first).height, 24);
    // A tap near the target's edge, well outside the 22px cross, still removes the person.
    final box = tester.getRect(target.first);
    await tester.tapAt(box.topLeft + const Offset(4, 4));
    expect(changed, hasLength(1));
  });

  testWidgets('with a mouse the chip keeps its compact 24px row', variant: TargetPlatformVariant.only(TargetPlatform.linux), (tester) async {
    await _pump(tester, people, (_) {});
    expect(tester.getSize(find.bySemanticsLabel(RegExp('^Remove ')).first).height, lessThan(30));
  });
}
