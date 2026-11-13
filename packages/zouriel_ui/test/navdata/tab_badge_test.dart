import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// `UiTab.badge` (0.79): a count after the label, like the web `ui-tab [badge]`.
void main() {
  Widget tabs(String? unread) => SizedBox(
        width: 390,
        child: UiTabs(label: 'Portfolio', tabs: [
          const UiTab(label: 'Page', child: Text('page panel')),
          UiTab(label: 'Enquiries', badge: unread, badgeLabel: unread == null ? null : '$unread new', child: const Text('enquiries panel')),
          const UiTab(label: 'Inbox', icon: HugeIcons.strokeRoundedInbox, iconOnly: true, badge: '2', child: Text('inbox panel')),
        ]),
      );

  testWidgets('shows the count after the label; screen readers hear badgeLabel', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, tabs('3'));
    expect(find.text('3'), findsOneWidget);
    expect(tester.getTopLeft(find.text('3')).dx, greaterThan(tester.getTopRight(find.text('Enquiries')).dx));
    // The tab is one merged node: its label, then the badge's words (not the bare number).
    expect(find.bySemanticsLabel(RegExp(r'^Enquiries\s+3 new$')), findsOneWidget);
    // An icon-only tab carries the count in its name.
    expect(find.bySemanticsLabel('Inbox, 2'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('nothing shows for null or 0', (tester) async {
    await pumpUi(tester, tabs('0'));
    expect(find.text('0'), findsNothing);
    await pumpUi(tester, tabs(null));
    expect(find.text('3'), findsNothing);
    expect(find.text('Enquiries'), findsOneWidget);
  });
}
