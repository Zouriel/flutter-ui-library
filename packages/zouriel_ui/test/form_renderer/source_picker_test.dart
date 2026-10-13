import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fakes.dart';

class _Host extends StatefulWidget {
  const _Host({required this.source, this.multiple = false, this.params = const {}, required this.log});
  final UiFbOptionSourceDef source;
  final bool multiple;
  final Map<String, Object?> params;
  final List<Object?> log;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Object? value;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 340,
        child: UiFbSourcePicker(
          source: widget.source,
          params: widget.params,
          multiple: widget.multiple,
          value: value,
          label: 'Student',
          onChanged: (v) => setState(() {
            value = v;
            widget.log.add(v);
          }),
        ),
      );
}

Finder get _rows => find.descendant(of: find.byType(ListView), matching: find.byType(UiInteractive));
List<String> _labels(WidgetTester tester) => [
      for (final e in find.descendant(of: find.byType(ListView), matching: find.byType(Text)).evaluate()) (e.widget as Text).data ?? '',
    ];

void main() {
  testWidgets('opens on the first page and loads the next as the list scrolls to its end', (tester) async {
    final src = peopleSource();
    await pumpUi(tester, _Host(source: src.def, log: []));
    await tester.tap(find.byType(UiFbSourcePicker));
    await tester.pumpAndSettle();
    expect(src.calls, hasLength(1));
    expect((src.calls[0].query, src.calls[0].page, src.calls[0].pageSize), ('', 1, 20));
    expect(_labels(tester).first, 'Person 1');
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(src.calls.map((c) => c.page), containsAllInOrder([1, 2]));
    expect(tester.state<UiFbSourcePickerState>(find.byType(UiFbSourcePicker)).isOpen, isTrue);
  });

  testWidgets('searches after a pause in typing, and picks with the keyboard as {value, label}', (tester) async {
    final src = peopleSource();
    final log = <Object?>[];
    await pumpUi(tester, _Host(source: src.def, log: log));
    await tester.tap(find.byType(UiFbSourcePicker));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Person 4');
    await tester.pump(const Duration(milliseconds: 100));
    expect(src.calls, hasLength(1), reason: 'still waiting for the pause');
    expect(find.text('Searching…'), findsNothing);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(src.calls, hasLength(2));
    expect((src.calls[1].query, src.calls[1].page), ('Person 4', 1));
    expect(_labels(tester).take(3), ['Person 4', 'Person 40', 'Person 41']);
    // Typing makes the first match active; ArrowDown moves on to the second.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log.last, {'value': 'S139', 'label': 'Person 40'});
    expect(tester.state<UiFbSourcePickerState>(find.byType(UiFbSourcePicker)).isOpen, isFalse);
    expect(find.text('Person 40'), findsOneWidget, reason: 'the chosen label shows in the box');
  });

  testWidgets('collects several as chips in multiple mode; Backspace removes the last', (tester) async {
    final src = peopleSource();
    final log = <Object?>[];
    await pumpUi(tester, _Host(source: src.def, multiple: true, log: log));
    await tester.tap(find.byType(UiFbSourcePicker));
    await tester.pumpAndSettle();
    await tester.tap(_rows.at(0));
    await tester.pump();
    await tester.tap(_rows.at(2));
    await tester.pump();
    expect(log.last, [
      {'value': 'S100', 'label': 'Person 1'},
      {'value': 'S102', 'label': 'Person 3'},
    ]);
    expect(find.bySemanticsLabel('Remove Person 3'), findsOneWidget);
    expect(tester.state<UiFbSourcePickerState>(find.byType(UiFbSourcePicker)).isOpen, isTrue, reason: 'multiple keeps the list open');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(log.last, [
      {'value': 'S100', 'label': 'Person 1'},
    ]);
  });

  testWidgets('waits for a required setting, then offers a retry when the list fails', (tester) async {
    var fail = true;
    final calls = <UiFbSourceQuery>[];
    final flaky = UiFbOptionSource(
      type: 'students',
      label: 'Students',
      params: const [UiFbSourceParamSpec(key: 'faculty', label: 'Faculty', required: true)],
      search: (q) {
        calls.add(q);
        if (fail) throw StateError('down');
        return UiFbSourcePage(items: people.take(3).toList(), hasMore: false);
      },
    );
    final params = ValueNotifier<Map<String, Object?>>({});
    await pumpUi(
      tester,
      ValueListenableBuilder(valueListenable: params, builder: (context, p, _) => _Host(source: flaky, params: p, log: [])),
    );
    await tester.tap(find.byType(UiFbSourcePicker));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(find.text('Choose faculty first.'), findsOneWidget);
    params.value = {'faculty': 'health'};
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
    expect(find.text('Couldn’t load the list.'), findsOneWidget);
    fail = false;
    await tester.tap(find.bySemanticsLabel('Try again'));
    await tester.pumpAndSettle();
    expect(_rows, findsNWidgets(3));
  });

  testWidgets('a newer search aborts the one still running, whose late reply is ignored', (tester) async {
    final pending = <UiFbSourceQuery>[];
    final aborted = <int>[];
    final slow = UiFbOptionSource(
      type: 's',
      label: 'Students',
      search: (q) async {
        pending.add(q);
        q.signal.onAbort(() => aborted.add(q.page));
        await Future<void>.delayed(Duration(milliseconds: q.query.isEmpty ? 800 : 100));
        return UiFbSourcePage(items: [UiFbSourceItem(value: q.query, label: q.query.isEmpty ? 'From the first search' : 'Match for ${q.query}')], hasMore: false);
      },
    );
    await pumpUi(tester, _Host(source: slow, log: []));
    await tester.tap(find.byType(UiFbSourcePicker));
    await tester.pump();
    expect(find.text('Searching…'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'ami');
    await tester.pump(const Duration(milliseconds: 260));
    expect(pending, hasLength(2));
    expect(pending.first.signal.aborted, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Match for ami'), findsOneWidget);
    expect(find.text('From the first search'), findsNothing);
  });

  testWidgets('says when nothing matches, and asks for more letters below the minimum', (tester) async {
    final src = peopleSource();
    final picky = UiFbOptionSource(type: 'p', label: 'People', minQueryLength: 2, search: src.def.search);
    await pumpUi(tester, _Host(source: picky, log: []));
    await tester.tap(find.byType(UiFbSourcePicker));
    await tester.pumpAndSettle();
    expect(find.text('Type at least 2 characters to search.'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'zz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('No matches for “zz”.'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tester.state<UiFbSourcePickerState>(find.byType(UiFbSourcePicker)).isOpen, isFalse);
  });

  testWidgets('meets the tap-target and label guidelines, open and closed', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, _Host(source: peopleSource().def, multiple: true, log: []));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(find.byType(UiFbSourcePicker));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await tester.tap(_rows.at(0));
    await tester.pump();
    // (Contrast is checked before a chip exists: the sampler reads a chip's 1px tinted border as its
    // text colour. The chip is the library's multi-select chip; see the golden.)
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('golden: single and multiple pickers, one open', (tester) async {
    final src = peopleSource();
    await expectThemedGolden(
      tester,
      'source_picker',
      (context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
        UiFbSourcePicker(source: src.def, value: const {'value': 'S100', 'label': 'Person 1'}, label: 'One', onChanged: (_) {}),
        UiFbSourcePicker(
          source: src.def,
          multiple: true,
          label: 'Several',
          value: const [
            {'value': 'S100', 'label': 'Person 1'},
            {'value': 'S101', 'label': 'Person 2'},
          ],
          onChanged: (_) {},
        ),
        UiFbSourcePicker(source: src.def, label: 'Empty', placeholder: 'Search students…', onChanged: (_) {}),
      ]),
      height: 520,
    );
    await tester.tap(find.descendant(of: find.byType(UiFbSourcePicker).at(1), matching: find.byType(EditableText)));
    await tester.pumpAndSettle();
    expect(tester.state<UiFbSourcePickerState>(find.byType(UiFbSourcePicker).at(1)).isOpen, isTrue);
    await expectLater(find.byType(UiApp), matchesGoldenFile('goldens/source_picker_open.png'));
  });
}
