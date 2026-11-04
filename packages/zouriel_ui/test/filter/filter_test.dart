import 'dart:ui' show CheckedState;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

const people = UiFilterSection(
  id: 'who',
  title: 'Uploaded by',
  multiple: true,
  allLabel: 'Everyone',
  allCount: 12,
  options: [UiFilterOption(id: 'aisha', label: 'Aisha', count: 7), UiFilterOption(id: 'ali', label: 'Ali', count: 5)],
);
const kind = UiFilterSection(
  id: 'kind',
  title: 'Type',
  options: [UiFilterOption(id: 'photo', label: 'Photos', count: 9), UiFilterOption(id: 'video', label: 'Videos', count: 3)],
);
final many = UiFilterSection(
  id: 'who',
  title: 'Uploaded by',
  multiple: true,
  allLabel: 'Everyone',
  options: [for (var i = 0; i < 10; i++) UiFilterOption(id: 'p$i', label: i == 3 ? 'Mariyam' : 'Guest $i', count: 1)],
);

/// A page holding the value, the way an app does: 12 items, 7 by Aisha, 5 by Ali, 3 of them videos.
class _Host extends StatefulWidget {
  const _Host({this.initial = const {}});
  final UiFilterValue initial;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late UiFilterValue value = widget.initial;
  final changes = <UiFilterValue>[];
  static final items = [for (var i = 0; i < 12; i++) (who: i < 7 ? 'aisha' : 'ali', video: i % 4 == 0)];

  int get shown => items.where((it) {
        final v = uiFilterPrune(const [people, kind], value);
        return (v['who'] == null || v['who']!.contains(it.who)) && (v['kind'] == null || v['kind']!.contains(it.video ? 'video' : 'photo'));
      }).length;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        UiFilter(
          sections: const [people, kind],
          value: value,
          resultCount: shown,
          onChanged: (v) => setState(() {
            changes.add(v);
            value = v;
          }),
        ),
        UiFilterChips(sections: const [people, kind], value: value, onChanged: (v) => setState(() => value = v)),
        Text('shown $shown'),
      ]);
}

bool? _checked(WidgetTester tester, String label) {
  final data = tester.getSemantics(find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}(, \\d+)?\$'))).getSemanticsData();
  return switch (data.flagsCollection.isChecked) { CheckedState.isTrue => true, CheckedState.isFalse => false, _ => null };
}

void main() {
  group('filter model', () {
    test('counts every chosen option', () {
      expect(uiFilterCount(const {}), 0);
      expect(uiFilterCount(null), 0);
      expect(uiFilterCount(const {'who': ['aisha', 'ali'], 'kind': ['video']}), 3);
    });

    test('lists active filters in the panel order, leaving out unknown ids', () {
      expect(uiActiveFilters(const [people, kind], const {'kind': ['video'], 'who': ['ali', 'gone', 'aisha']}), const [
        UiActiveFilter(section: 'who', option: 'aisha', label: 'Aisha'),
        UiActiveFilter(section: 'who', option: 'ali', label: 'Ali'),
        UiActiveFilter(section: 'kind', option: 'video', label: 'Videos'),
      ]);
    });

    test('prunes choices the sections no longer offer, and empty sections', () {
      expect(uiFilterPrune(const [people, kind], const {'who': ['gone'], 'kind': ['video'], 'other': ['x']}), {'kind': ['video']});
      expect(uiFilterPrune(const [kind], const {'kind': ['photo', 'video']}), {'kind': ['photo']});
    });

    test('toggles checkboxes and radios, and removes sections left empty', () {
      UiFilterValue v = {};
      v = uiFilterToggle(people, v, 'aisha');
      v = uiFilterToggle(people, v, 'ali');
      expect(v, {'who': ['aisha', 'ali']});
      v = uiFilterToggle(kind, v, 'photo');
      v = uiFilterToggle(kind, v, 'video');
      expect(v['kind'], ['video']);
      v = uiFilterToggle(kind, v, 'video');
      expect(v.containsKey('kind'), isFalse);
      v = uiFilterRemove(v, 'who', 'aisha');
      expect(v, {'who': ['ali']});
      expect(uiFilterSet(v, 'who', const []), isEmpty);
    });
  });

  group('UiFilterButton', () {
    testWidgets('reads Filter, with a count bubble and "Filter, 2 on" while filters are on', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, UiFilterButton(count: 0, onPressed: () {}));
      expect(find.text('Filter'), findsOneWidget);
      expect(find.byType(UiButtonBadge), findsNothing);
      await pumpUi(tester, UiFilterButton(count: 2, onPressed: () {}));
      expect(find.text('2'), findsOneWidget);
      expect(find.bySemanticsLabel('Filter, 2 on'), findsOneWidget);
      await pumpUi(tester, UiFilterButton(count: 14, onPressed: () {}));
      expect(find.text('9+'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('UiFilterPanel', () {
    Future<List<UiFilterValue>> pump(WidgetTester tester, {List<UiFilterSection>? sections, UiFilterValue initial = const {}}) async {
      final changes = <UiFilterValue>[];
      var value = initial;
      await pumpUi(
        tester,
        SizedBox(
          width: 390,
          height: 800,
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => UiFilterPanel(
                sections: sections ?? const [people, kind],
                value: value,
                onChanged: (v) => setState(() {
                  changes.add(v);
                  value = v;
                }),
              ),
            ),
          ),
        ),
      );
      return changes;
    }

    testWidgets('shows each section as a titled group with an "all" row and counts', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      for (final t in ['Uploaded by', 'Everyone', '12', 'Aisha', '7', 'Ali', '5', 'Type', 'All', 'Photos', 'Videos']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(_checked(tester, 'Everyone'), isTrue);
      expect(_checked(tester, 'Aisha'), isFalse);
      expect(find.byType(UiCheckMark), findsNWidgets(3));
      expect(find.byType(UiRadioMark), findsNWidgets(3));
      handle.dispose();
    });

    testWidgets('changes the value at once, several people at a time, and "all" clears the section', (tester) async {
      final handle = tester.ensureSemantics();
      final changes = await pump(tester);
      await tester.tap(find.text('Aisha'));
      await tester.pump();
      await tester.tap(find.text('Ali'));
      await tester.pump();
      expect(changes.last, {'who': ['aisha', 'ali']});
      expect(_checked(tester, 'Everyone'), isFalse);
      await tester.tap(find.text('Videos'));
      await tester.pump();
      expect(changes.last, {'who': ['aisha', 'ali'], 'kind': ['video']});
      await tester.tap(find.text('Everyone'));
      await tester.pump();
      expect(changes.last, {'kind': ['video']});
      // Tapping "all" again changes nothing.
      final before = changes.length;
      await tester.tap(find.text('Everyone'));
      await tester.pump();
      expect(changes.length, before);
      expect(_checked(tester, 'Everyone'), isTrue);
      handle.dispose();
    });

    testWidgets('gets a search field from 8 options that narrows the rows', (tester) async {
      await pump(tester);
      expect(find.byType(UiSearchInput), findsNothing);
      await pump(tester, sections: [many]);
      expect(find.byType(UiSearchInput), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'mari');
      await tester.pump();
      expect(find.text('Mariyam'), findsOneWidget);
      expect(find.text('Guest 0'), findsNothing);
      expect(find.text('Everyone'), findsNothing);
      await tester.enterText(find.byType(EditableText), 'zzz');
      await tester.pump();
      expect(find.text('No results'), findsOneWidget);
    });

    testWidgets('rows are at least 44px tall and meet the tap target guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      for (final t in ['Everyone', 'Aisha', 'Photos']) {
        // The painted row, not the touch padding UiInteractive adds around it.
        final row = find.ancestor(of: find.text(t), matching: find.byType(AnimatedContainer)).first;
        expect(tester.getSize(row).height, greaterThanOrEqualTo(44), reason: t);
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  group('UiFilter', () {
    testWidgets('is a bottom sheet on a phone that changes the page as you tap, with Show N', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const _Host());
      expect(find.text('shown 12'), findsOneWidget);
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      expect(find.byType(UiBottomSheet), findsOneWidget);
      expect(find.byType(UiOverlayPanel), findsNothing);
      expect(find.text('Show 12'), findsOneWidget);
      await tester.tap(find.text('Ali'));
      await tester.pumpAndSettle();
      // The page behind has the new value, the sheet shows it, and the footer counts it.
      expect(find.text('shown 5'), findsOneWidget);
      expect(_checked(tester, 'Ali'), isTrue);
      expect(find.text('Show 5'), findsOneWidget);
      expect(find.bySemanticsLabel('Filter, 1 on'), findsOneWidget);
      await tester.tap(find.text('Show 5'));
      await tester.pumpAndSettle();
      expect(find.byType(UiBottomSheet), findsNothing);
      // The chip is under the button; its remove button turns the filter off.
      expect(find.byType(UiChip), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Remove Ali'));
      await tester.pumpAndSettle();
      expect(find.text('shown 12'), findsOneWidget);
      expect(find.byType(UiChip), findsNothing);
      handle.dispose();
    });

    testWidgets('Clear all in the sheet turns everything off', (tester) async {
      await pumpUi(tester, const _Host(initial: {'who': ['ali'], 'kind': ['video']}));
      expect(find.text('shown 1'), findsOneWidget);
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(UiFilterFooter), matching: find.text('Clear all')));
      await tester.pumpAndSettle();
      expect(find.text('shown 12'), findsOneWidget);
      expect(find.text('Show 12'), findsOneWidget);
    });

    testWidgets('is a popover under the button on a wide screen; Escape closes it', (tester) async {
      await pumpUi(tester, const _Host(), size: const Size(1200, 800));
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      expect(find.byType(UiOverlayPanel), findsOneWidget);
      expect(find.byType(UiBottomSheet), findsNothing);
      final button = tester.getRect(find.byType(UiFilterButton));
      final panel = tester.getRect(find.byType(UiOverlayPanel));
      expect(panel.top, greaterThan(button.bottom - 1));
      expect(panel.width, 340);
      await tester.tap(find.text('Videos'));
      await tester.pumpAndSettle();
      expect(find.text('shown 3'), findsOneWidget);
      expect(find.text('Show 3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(UiOverlayPanel), findsNothing);
      // Tapping the button opens and closes it.
      await tester.tap(find.byType(UiFilterButton));
      await tester.pumpAndSettle();
      expect(find.byType(UiOverlayPanel), findsOneWidget);
      await tester.tap(find.byType(UiFilterButton));
      await tester.pumpAndSettle();
      expect(find.byType(UiOverlayPanel), findsNothing);
    });
  });

  group('UiFilterChips', () {
    testWidgets('shows a removable chip for each filter that is on, then Clear all; nothing when none', (tester) async {
      UiFilterValue value = const {'who': ['aisha', 'ali'], 'kind': ['video']};
      await pumpUi(tester, StatefulBuilder(builder: (context, setState) => SizedBox(width: 390, child: UiFilterChips(sections: const [people, kind], value: value, onChanged: (v) => setState(() => value = v)))));
      expect(find.byType(UiChip), findsNWidgets(3));
      expect(find.text('Videos'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Remove Aisha'));
      await tester.pump();
      expect(value, {'who': ['ali'], 'kind': ['video']});
      await tester.tap(find.text('Clear all'));
      await tester.pump();
      expect(value, isEmpty);
      expect(find.byType(UiChip), findsNothing);
      expect(find.text('Clear all'), findsNothing);
    });
  });

  testWidgets('chips wrap with the same gap between rows as between chips (space2, as the web)', (tester) async {
    final sections = [
      UiFilterSection(id: 'w', title: 'W', multiple: true, options: [for (final n in ['Aisha Ahmed', 'Mohamed Ibrahim', 'Shaina', 'Fathimath Zahra']) UiFilterOption(id: n, label: n)]),
    ];
    await pumpUi(tester, SizedBox(width: 300, child: UiFilterChips(sections: sections, value: {'w': [for (final o in sections.first.options) o.id]}, onChanged: (_) {})));
    final wrap = tester.widget<Wrap>(find.descendant(of: find.byType(UiFilterChips), matching: find.byType(Wrap)));
    final t = tester.element(find.byType(UiFilterChips)).ui;
    expect([wrap.spacing, wrap.runSpacing], [t.space2, t.space2]);
  });

  testWidgets('golden: button, chips and panel, dark and light', (tester) async {
    await expectThemedGolden(
      tester,
      'filter',
      (context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [UiFilterButton(count: 0, onPressed: () {}), const SizedBox(width: 8), UiFilterButton(count: 2, onPressed: () {})]),
        const SizedBox(height: 8),
        UiFilterChips(sections: const [people, kind], value: const {'who': ['aisha'], 'kind': ['video']}, onChanged: (_) {}),
        const SizedBox(height: 8),
        UiFilterPanel(sections: const [people, kind], value: const {'who': ['aisha'], 'kind': ['video']}, onChanged: (_) {}),
        const SizedBox(height: 8),
        UiFilterFooter(count: 2, resultCount: 2, onClearAll: () {}, onDone: () {}),
      ]),
      height: 720,
    );
  });
}
