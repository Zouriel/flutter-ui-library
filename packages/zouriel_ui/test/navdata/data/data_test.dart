import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../../helpers.dart';

const _nodes = [
  UiTreeNode(label: 'src', value: 'src', icon: HugeIcons.strokeRoundedFolder01, children: [
    UiTreeNode(label: 'app.ts', value: 'app', icon: HugeIcons.strokeRoundedFile01),
    UiTreeNode(label: 'lib', value: 'lib', children: [UiTreeNode(label: 'util.ts', value: 'util')]),
  ]),
  UiTreeNode(label: 'docs', value: 'docs', children: [UiTreeNode(label: 'guide.md', value: 'guide')]),
  UiTreeNode(label: 'README', value: 'readme'),
];

/// A tree with its selection held by the test, like `[(selected)]`.
class _Host extends StatefulWidget {
  const _Host({this.selected, this.picked});
  final String? selected;
  final List<String>? picked;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String? sel = widget.selected;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 390,
        child: UiTree(
          label: 'Files',
          nodes: _nodes,
          selected: sel,
          onSelect: (n) {
            widget.picked?.add(n.value);
            setState(() => sel = n.value);
          },
        ),
      );
}

String? get _focused {
  final l = FocusManager.instance.primaryFocus?.debugLabel;
  return l != null && l.startsWith('tree ') ? l.substring(5) : l;
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey k, {String? character}) async {
  await tester.sendKeyEvent(k, character: character);
  await tester.pump();
}

Finder _row(String label) => find.ancestor(of: find.text(label), matching: find.byType(UiInteractive)).first;

/// Focuses a row the way a keyboard user would land on it.
Future<void> _focusRow(WidgetTester tester, String label) async {
  final node = tester.widget<UiInteractive>(_row(label)).focusNode!;
  node.requestFocus();
  await tester.pump();
}

void main() {
  group('UiTree', () {
    testWidgets('rows are read with level, position, expanded and selected state', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const _Host(selected: 'readme'));
      final src = tester.getSemantics(_row('src')).getSemanticsData();
      expect(src.label, 'src');
      expect(src.hint, 'level 1, 1 of 3');
      expect(src.flagsCollection.isExpanded, Tristate.isFalse);
      expect(src.hasAction(SemanticsAction.expand), isTrue);
      expect(src.hasAction(SemanticsAction.collapse), isFalse);
      final readme = tester.getSemantics(_row('README')).getSemanticsData();
      expect(readme.flagsCollection.isSelected, Tristate.isTrue);
      expect(readme.flagsCollection.isExpanded, Tristate.none);
      expect(find.bySemanticsLabel('Files'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('one tab stop: the first item, then the selected one', (tester) async {
      await pumpUi(tester, const _Host());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focused, 'src');
      await pumpUi(tester, const _Host(selected: 'readme'));
      await tester.pumpWidget(const SizedBox()); // fresh tree
      await pumpUi(tester, const _Host(selected: 'readme'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focused, 'readme');
    });

    testWidgets('Up/Down through visible items, Home/End to the ends', (tester) async {
      await pumpUi(tester, const _Host());
      await _focusRow(tester, 'src');
      await _press(tester, LogicalKeyboardKey.arrowRight); // open src
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused, 'app');
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused, 'lib');
      await _press(tester, LogicalKeyboardKey.arrowDown); // lib is closed: util is skipped
      expect(_focused, 'docs');
      await _press(tester, LogicalKeyboardKey.end);
      expect(_focused, 'readme');
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused, 'readme');
      await _press(tester, LogicalKeyboardKey.home);
      expect(_focused, 'src');
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_focused, 'src');
    });

    testWidgets('Right opens then enters; Left closes then goes to the parent', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const _Host());
      await _focusRow(tester, 'src');
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(tester.getSemantics(_row('src')).getSemanticsData().flagsCollection.isExpanded, Tristate.isTrue);
      expect(_focused, 'src');
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_focused, 'app');
      await _press(tester, LogicalKeyboardKey.arrowRight); // leaf: nothing
      expect(_focused, 'app');
      await _press(tester, LogicalKeyboardKey.arrowLeft); // leaf: to parent
      expect(_focused, 'src');
      await _press(tester, LogicalKeyboardKey.arrowLeft); // open: close
      expect(find.text('app.ts'), findsNothing);
      expect(_focused, 'src');
      await _press(tester, LogicalKeyboardKey.arrowLeft); // closed root: nothing
      expect(_focused, 'src');
      handle.dispose();
    });

    testWidgets('Enter and Space select', (tester) async {
      final picked = <String>[];
      await pumpUi(tester, _Host(picked: picked));
      await _focusRow(tester, 'README');
      await _press(tester, LogicalKeyboardKey.enter);
      await _focusRow(tester, 'docs');
      await _press(tester, LogicalKeyboardKey.space);
      expect(picked, ['readme', 'docs']);
    });

    testWidgets('type-ahead jumps by first letter, wrapping; unknown letters do nothing', (tester) async {
      await pumpUi(tester, const _Host());
      await _focusRow(tester, 'src');
      await _press(tester, LogicalKeyboardKey.keyR, character: 'r');
      expect(_focused, 'readme');
      await _press(tester, LogicalKeyboardKey.keyS, character: 'S');
      expect(_focused, 'src');
      await _press(tester, LogicalKeyboardKey.keyZ, character: 'z');
      expect(_focused, 'src');
    });

    testWidgets('* expands every sibling, one level only', (tester) async {
      await pumpUi(tester, const _Host());
      await _focusRow(tester, 'README');
      await _press(tester, LogicalKeyboardKey.digit8, character: '*'); // Shift+8
      expect(find.text('app.ts'), findsOneWidget);
      expect(find.text('guide.md'), findsOneWidget);
      expect(find.text('util.ts'), findsNothing);
    });

    testWidgets('the chevron toggles without selecting; the row selects', (tester) async {
      final picked = <String>[];
      await pumpUi(tester, _Host(picked: picked));
      final chev = find.descendant(of: _row('src'), matching: find.byType(GestureDetector)).last;
      await tester.tap(chev);
      await tester.pump();
      expect(find.text('app.ts'), findsOneWidget);
      expect(picked, isEmpty);
      await tester.tap(find.text('app.ts'));
      await tester.pump();
      expect(picked, ['app']);
      // Children are indented by 16 per level.
      expect(tester.getTopLeft(find.text('app.ts')).dx - tester.getTopLeft(find.text('src')).dx, closeTo(16, 0.5));
    });

    testWidgets('collapsing over the focused item moves focus to the collapsed parent', (tester) async {
      await pumpUi(tester, const _Host());
      await _focusRow(tester, 'src');
      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused, 'app');
      await tester.tap(find.descendant(of: _row('src'), matching: find.byType(GestureDetector)).last);
      await tester.pump();
      expect(find.text('app.ts'), findsNothing);
      expect(_focused, 'src');
    });

    testWidgets('a screen reader can expand and collapse a row', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const _Host());
      final node = tester.getSemantics(_row('docs'));
      node.owner!.performAction(node.id, SemanticsAction.expand);
      await tester.pump();
      expect(find.text('guide.md'), findsOneWidget);
      final open = tester.getSemantics(_row('docs'));
      expect(open.getSemanticsData().hasAction(SemanticsAction.collapse), isTrue);
      open.owner!.performAction(open.id, SemanticsAction.collapse);
      await tester.pump();
      expect(find.text('guide.md'), findsNothing);
      handle.dispose();
    });
  });

  group('UiTimeline / UiDescriptionList / UiCodeBlock', () {
    testWidgets('timeline is a list; the connector stops at the last event', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const SizedBox(width: 390, child: UiTimeline(items: [
        UiTimelineItem(title: 'Created', meta: '09:00'),
        UiTimelineItem(title: 'Paid', tone: UiStatus.success, icon: HugeIcons.strokeRoundedTick02),
        UiTimelineItem(title: 'Shipped', description: 'Courier picked it up'),
      ])));
      expect(tester.getSemantics(find.byType(UiTimeline)).getSemanticsData().role, SemanticsRole.list);
      // Two connectors for three events.
      final lines = find.descendant(of: find.byType(UiTimeline), matching: find.byWidgetPredicate((w) => w is ColoredBox));
      expect(lines, findsNWidgets(2));
      // With an icon marker the marker column is 20 wide, so titles line up at 20 + 12.
      expect(tester.getTopLeft(find.text('Shipped')).dx, 32);
      handle.dispose();
    });

    testWidgets('description list: row layout beside, stacked below; narrow rows stack', (tester) async {
      const items = [UiDescriptionItem(term: 'Status', detail: 'Active'), UiDescriptionItem(term: 'Plan', detail: 'Studio')];
      await pumpUi(tester, const SizedBox(width: 390, child: UiDescriptionList(items: items)));
      expect(tester.getTopLeft(find.text('Active')).dx, 140 + 16);
      await pumpUi(tester, const SizedBox(width: 390, child: UiDescriptionList(items: items, layout: UiDescriptionLayout.stacked)));
      expect(tester.getTopLeft(find.text('Active')).dy, greaterThan(tester.getBottomLeft(find.text('Status')).dy - 1));
      await pumpUi(tester, const SizedBox(width: 250, child: UiDescriptionList(items: items)));
      expect(tester.getTopLeft(find.text('Active')).dx, 0);
    });

    testWidgets('description list pairs are read together', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const SizedBox(width: 390, child: UiDescriptionList(items: [UiDescriptionItem(term: 'Status', detail: 'Active')])));
      expect(find.bySemanticsLabel('Status\nActive'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('code block copies, says so, and resets; a refused clipboard says it failed', (tester) async {
      String? copied;
      var fail = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          if (fail) throw PlatformException(code: 'denied');
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpUi(tester, const SizedBox(width: 390, child: UiCodeBlock(code: 'final x = 1;\n\tprint(x);', language: 'dart')));
      expect(find.text('DART'), findsOneWidget);
      // Icon plus label, like the other copy buttons; the icon follows the state.
      expect(find.byWidgetPredicate((w) => w is UiIcon && w.icon == HugeIcons.strokeRoundedCopy01), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(copied, 'final x = 1;\n\tprint(x);');
      expect(find.text('Copied'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is UiIcon && w.icon == HugeIcons.strokeRoundedTick02), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text('Copy'), findsOneWidget);
      fail = true;
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(find.text('Copy failed'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1600));
    });

    testWidgets('long code lines scroll instead of wrapping', (tester) async {
      await pumpUi(tester, SizedBox(width: 300, child: UiCodeBlock(code: 'x' * 200)));
      expect(tester.getSize(find.byType(UiCodeBlock)).width, 300);
      expect(tester.getSize(find.textContaining('xxxx')).height, lessThan(30));
      expect(tester.takeException(), isNull);
      // The cut-off right edge fades out.
      expect(find.descendant(of: find.byType(UiScrollFade), matching: find.byType(ShaderMask)), findsOneWidget);
    });
  });

  testWidgets('guidelines: tap targets, labels, contrast', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final handle = tester.ensureSemantics();
    try {
      await pumpUi(tester, Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: [
          const UiTimeline(items: [UiTimelineItem(title: 'Created', meta: 'Monday'), UiTimelineItem(title: 'Shipped', description: 'Courier picked it up')]),
          const UiDescriptionList(items: [UiDescriptionItem(term: 'Status', detail: 'Active')]),
          const UiCodeBlock(code: 'final answer = 42;', language: 'dart'),
        ]),
      ));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      // Tree rows: short labels beside muted icons fool the pixel sampler (it picks the icon's
      // antialiased edge as the text colour), so targets are checked on screen, colours on tokens.
      await pumpUi(tester, UiTree(nodes: _nodes, selected: 'readme', onSelect: (_) {}));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      for (final th in UiThemeName.values) {
        final t = uiThemeTokens[th]!;
        double ratio(Color x, Color y) {
          final lx = x.computeLuminance(), ly = y.computeLuminance();
          return ((lx > ly ? lx : ly) + 0.05) / ((lx > ly ? ly : lx) + 0.05);
        }
        expect(ratio(t.text, t.bg), greaterThanOrEqualTo(4.5), reason: '$th row');
        expect(ratio(t.text, uiMix(t.selected, t.selected.a, t.bg).withValues(alpha: 1)), greaterThanOrEqualTo(4.5), reason: '$th selected row');
      }
    } finally {
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('golden: tree, timeline, description list, code block', (tester) async {
    await expectThemedGolden(tester, 'data', height: 900, (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        UiTree(nodes: _nodes, selected: 'app', initiallyExpanded: const {'src', 'lib'}, onSelect: (_) {}),
        const UiTimeline(items: [
          UiTimelineItem(title: 'Order placed', meta: '09:12', description: 'Two items, paid by card'),
          UiTimelineItem(title: 'Payment confirmed', meta: '09:13', tone: UiStatus.success),
          UiTimelineItem(title: 'Address check', meta: '10:40', tone: UiStatus.warning, description: 'Waiting on the courier'),
          UiTimelineItem(title: 'Cancelled item', tone: UiStatus.danger),
        ]),
        const UiTimeline(items: [
          UiTimelineItem(title: 'Draft', icon: HugeIcons.strokeRoundedFile01, tone: UiStatus.neutral),
          UiTimelineItem(title: 'Published', icon: HugeIcons.strokeRoundedTick02, tone: UiStatus.success, meta: 'Today'),
        ]),
        const UiDescriptionList(items: [
          UiDescriptionItem(term: 'Status', detail: 'Active'),
          UiDescriptionItem(term: 'Plan', detail: 'Studio, billed yearly with a long description that wraps'),
        ]),
        const UiCodeBlock(language: 'dart', code: "UiButton(\n  label: 'Save',\n  onPressed: save,\n)"),
      ],
    ));
  });
}
