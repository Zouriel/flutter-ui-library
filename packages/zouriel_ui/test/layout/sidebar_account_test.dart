import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

const _name = 'Aishath Mohamed Ibrahim';
const _role = 'Clerk · Secretariat';

Widget _footer(Widget child, {double width = 240, TextDirection dir = TextDirection.ltr}) =>
    Directionality(textDirection: dir, child: SizedBox(width: width, child: child));

void main() {
  group('UiSidebarAccount', () {
    testWidgets('shows the initials avatar, name, subtitle, badge, hint and chevron', (tester) async {
      await pumpUi(tester, _footer(UiSidebarAccount(
        name: _name,
        subtitle: _role,
        badge: 'Read-only',
        badgeTone: UiStatus.warning,
        hint: 'Switch test account',
        onPressed: () {},
      )));
      expect(find.text('AI'), findsOneWidget);
      expect(find.text(_name), findsOneWidget);
      expect(find.text(_role), findsOneWidget);
      expect(find.text('Switch test account'), findsOneWidget);
      expect(tester.widget<UiBadge>(find.byType(UiBadge)).tone, UiStatus.warning);
      expect(find.byType(UiIcon), findsOneWidget);
    });

    testWidgets('leaves out what is not given, and the chevron when told to', (tester) async {
      await pumpUi(tester, _footer(UiSidebarAccount(name: _name, showChevron: false, onPressed: () {})));
      expect(find.text(_name), findsOneWidget);
      expect(find.byType(UiBadge), findsNothing);
      expect(find.byType(UiIcon), findsNothing);
      expect(tester.getSemantics(find.byType(UiSidebarAccount)).getSemanticsData().label, _name);
    });

    testWidgets('is one button named by the name, subtitle and badge, with the hint as its hint', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, _footer(UiSidebarAccount(name: _name, subtitle: _role, badge: 'Read-only', hint: 'Switch test account', onPressed: () {})));
      final data = tester.getSemantics(find.byType(UiSidebarAccount)).getSemanticsData();
      expect(data.label, '$_name, $_role, Read-only');
      expect(data.hint, 'Switch test account');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, Tristate.isTrue);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('takes the full width of its footer and at least the touch height', (tester) async {
      await pumpUi(tester, _footer(UiSidebarAccount(name: _name, subtitle: _role, onPressed: () {})));
      final box = tester.getSize(find.byType(AnimatedContainer));
      expect(box.width, 240);
      expect(box.height, greaterThanOrEqualTo(uiMinTouchTarget));
    });

    testWidgets('tap, Enter and Space press it', (tester) async {
      var presses = 0;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpUi(tester, _footer(UiSidebarAccount(name: _name, focusNode: focus, onPressed: () => presses++)));
      await tester.tap(find.byType(UiSidebarAccount));
      expect(presses, 1);
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(presses, 3);
    });

    testWidgets('disabled: not pressable, announced as disabled; enabled again it presses', (tester) async {
      final handle = tester.ensureSemantics();
      var presses = 0;
      Widget build(bool disabled) => _footer(UiSidebarAccount(name: _name, disabled: disabled, onPressed: () => presses++));
      await pumpUi(tester, build(true));
      await tester.tap(find.byType(UiSidebarAccount), warnIfMissed: false);
      expect(presses, 0);
      expect(tester.getSemantics(find.byType(UiSidebarAccount)).getSemanticsData().flagsCollection.isEnabled, Tristate.isFalse);
      await tester.pumpWidget(UiApp(theme: UiThemeName.dark, home: Align(alignment: Alignment.topLeft, child: build(false))));
      await tester.tap(find.byType(UiSidebarAccount));
      expect(presses, 1);
      handle.dispose();
    });

    testWidgets('long names and subtitles end in an ellipsis on one line', (tester) async {
      final long = 'Aishath ${'Mohamed ' * 8}Didi';
      final role = 'Senior Clerk · ${'Secretariat ' * 6}Office';
      await pumpUi(tester, _footer(width: 200, UiSidebarAccount(name: long, subtitle: role, badge: 'Read-only', onPressed: () {})));
      expect(tester.takeException(), isNull);
      for (final text in [long, role]) {
        final p = tester.renderObject<RenderParagraph>(find.text(text));
        expect(p.maxLines, 1);
        expect(p.overflow, TextOverflow.ellipsis);
        expect(p.didExceedMaxLines, isTrue);
      }
      // The badge keeps its size beside a long name.
      expect(tester.getRect(find.byType(UiBadge)).right, lessThanOrEqualTo(tester.getRect(find.byType(UiSidebarAccount)).right));
    });

    testWidgets('right to left: the avatar on the right, the chevron on the left', (tester) async {
      await pumpUi(tester, _footer(dir: TextDirection.rtl, UiSidebarAccount(name: _name, subtitle: _role, onPressed: () {})));
      final avatar = tester.getRect(find.byType(UiAvatar));
      final name = tester.getRect(find.text(_name));
      final chevron = tester.getRect(find.byType(UiIcon));
      expect(avatar.left, greaterThan(name.right));
      expect(chevron.right, lessThan(name.left));
      await pumpUi(tester, _footer(UiSidebarAccount(name: _name, subtitle: _role, onPressed: () {})));
      expect(tester.getRect(find.byType(UiAvatar)).right, lessThan(tester.getRect(find.text(_name)).left));
    });

    testWidgets('collapsed: only the avatar, the same name, and the label as a tooltip', (tester) async {
      final handle = tester.ensureSemantics();
      var presses = 0;
      await pumpUi(tester, _footer(width: 64, UiSidebarAccount(name: _name, subtitle: _role, hint: 'Switch test account', collapsed: true, onPressed: () => presses++)));
      expect(find.byType(UiAvatar), findsOneWidget);
      expect(find.text(_name), findsNothing);
      expect(find.text('Switch test account'), findsNothing);
      expect(find.byType(UiIcon), findsNothing);
      expect(tester.widget<UiTooltip>(find.byType(UiTooltip)).message, '$_name, $_role');
      final data = tester.getSemantics(find.byType(UiAvatar)).getSemanticsData();
      expect(data.label, '$_name, $_role');
      expect(data.hint, isEmpty);
      expect(tester.getSize(find.byType(AnimatedContainer)).width, lessThan(64));
      await tester.tap(find.byType(UiAvatar));
      expect(presses, 1);
      handle.dispose();
    });

    testWidgets('not collapsed: no tooltip', (tester) async {
      await pumpUi(tester, _footer(UiSidebarAccount(name: _name, onPressed: () {})));
      expect(find.byType(UiTooltip), findsNothing);
    });

    testWidgets('as a UiMenu trigger: opens the menu, says it is expanded, and gets focus back', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpUi(tester, Padding(
        padding: const EdgeInsets.only(top: 400),
        child: _footer(UiMenu(
          items: const [UiMenuItem(label: 'Profile', value: 'profile'), UiMenuItem(label: 'Sign out', value: 'out', danger: true)],
          onSelect: (i) => log.add(i.value),
          builder: (context, toggle, open) => UiSidebarAccount(name: _name, subtitle: _role, focusNode: focus, expanded: open, onPressed: toggle),
        )),
      ));
      SemanticsData data() => tester.getSemantics(find.byType(UiSidebarAccount)).getSemanticsData();
      expect(data().flagsCollection.isExpanded, Tristate.isFalse);
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Sign out'), findsOneWidget);
      expect(data().flagsCollection.isExpanded, Tristate.isTrue);
      expect(data().label, '$_name, $_role');
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(log, ['out']);
      expect(find.text('Sign out'), findsNothing);
      expect(data().flagsCollection.isExpanded, Tristate.isFalse);
      expect(focus.hasFocus, isTrue);
      handle.dispose();
    });

    testWidgets('fills the sidebar footer of UiSidebarLayout', (tester) async {
      await pumpUi(tester, SizedBox(
        width: 1000,
        height: 600,
        child: UiSidebarLayout(
          sidebarWidth: 240,
          sidebar: const SizedBox(height: 100),
          sidebarFooter: UiSidebarAccount(name: _name, subtitle: _role, onPressed: () {}),
          body: const SizedBox(),
        ),
      ), size: const Size(1000, 600));
      final account = tester.getRect(find.byType(AnimatedContainer).last);
      expect(account.width, greaterThan(200));
      expect(account.bottom, greaterThan(500));
    });

    testWidgets('golden', (tester) async {
      await expectThemedGolden(tester, 'sidebar_account', height: 380, (context) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
          UiSidebarAccount(name: 'Aishath Mohamed', subtitle: _role, onPressed: () {}),
          UiSidebarAccount(name: 'Ali Hassan Didi', subtitle: 'Director · Planning', badge: 'Read-only', badgeTone: UiStatus.warning, hint: 'Switch test account', onPressed: () {}),
          UiSidebarAccount(name: 'Aishath ${'Mohamed ' * 6}', subtitle: 'Senior Clerk · Secretariat of the City Council', expanded: true, onPressed: () {}),
          UiSidebarAccount(name: 'Disabled Person', subtitle: _role, disabled: true, onPressed: () {}),
          Align(alignment: AlignmentDirectional.centerStart, child: UiSidebarAccount(name: 'Ali Hassan', collapsed: true, onPressed: () {})),
        ]);
      });
    });
  });
}
