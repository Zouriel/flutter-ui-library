import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/media_page.dart';
import 'package:zouriel_ui_showcase/pages/navdata_sections.dart';

/// 0.65.0 showcase demos: the tree's layers panel and the device frame's zoom bar.

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(home: home));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  test('applyTreeMove takes a node out and puts it back where the move says', () {
    const nodes = [
      UiTreeNode(label: 'A', value: 'a'),
      UiTreeNode(label: 'G', value: 'g', children: [UiTreeNode(label: 'B', value: 'b')]),
      UiTreeNode(label: 'C', value: 'c'),
    ];
    List<String> flat(List<UiTreeNode> l) => [for (final n in l) ...[n.value, for (final c in flat(n.children)) '${n.value}/$c']];
    expect(flat(applyTreeMove(nodes, const UiTreeMove(value: 'c', parent: null, index: 0))), ['c', 'a', 'g', 'g/b']);
    expect(flat(applyTreeMove(nodes, const UiTreeMove(value: 'a', parent: 'g', index: 1))), ['g', 'g/b', 'g/a', 'c']);
    expect(flat(applyTreeMove(nodes, const UiTreeMove(value: 'b', parent: null, index: 3))), ['a', 'g', 'c', 'b']);
  });

  testWidgets('layers demo: hiding a layer mutes it without selecting it; Alt+Down reorders', (tester) async {
    await _pump(tester, SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: navdataDataSections())));
    expect(tester.takeException(), isNull);
    final hide = find.bySemanticsLabel('Hide Names');
    await tester.ensureVisible(hide);
    await tester.pumpAndSettle();
    final layers = find.byWidgetPredicate((w) => w is UiTree && w.label == 'Layers');
    expect(tester.widget<UiTree>(layers).selectedValues, ['names']);
    await tester.tap(hide);
    await tester.pump();
    final tree = tester.widget<UiTree>(layers);
    expect(tree.nodes.first.muted, isTrue);
    expect(tree.selectedValues, ['names']);
    expect(find.bySemanticsLabel('Show Names'), findsOneWidget);

    // Keyboard reorder: Names moves below Photo group.
    final names = find.descendant(of: layers, matching: find.ancestor(of: find.text('Names'), matching: find.byType(UiInteractive))).first;
    tester.widget<UiInteractive>(names).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(tester.widget<UiTree>(layers).nodes.map((n) => n.value).take(2), ['photos', 'names']);
    expect(find.textContaining('last moved: names to top #1'), findsOneWidget);
  });

  testWidgets('device frame demo: zoom buttons step through the zooms, Fit goes back to 100%', (tester) async {
    await _pump(tester, const MediaPage());
    final zoomIn = find.bySemanticsLabel('Zoom in');
    await tester.ensureVisible(zoomIn);
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    await tester.tap(zoomIn);
    await tester.pump();
    await tester.tap(zoomIn);
    await tester.pump();
    expect(find.text('200%'), findsOneWidget);
    expect(tester.widget<UiDeviceFrame>(find.byType(UiDeviceFrame)).zoom, 2);
    await tester.tap(find.text('Fit'));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Zoom out'));
    await tester.pump();
    expect(find.text('75%'), findsOneWidget);
  });
}
