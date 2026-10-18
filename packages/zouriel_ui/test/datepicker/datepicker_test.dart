import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../forms_text/overlay_helpers.dart';
import '../helpers.dart';

/// The keyboard-focused day: the one cell drawing the focus ring.
String? _ringDay(WidgetTester tester) {
  for (final e in find.byType(AnimatedContainer).evaluate()) {
    final w = e.widget as AnimatedContainer;
    final d = w.decoration;
    if (d is BoxDecoration && (d.boxShadow?.isNotEmpty ?? false)) {
      final text = find.descendant(of: find.byWidget(w), matching: find.byType(Text)).evaluate();
      if (text.isNotEmpty) return (text.first.widget as Text).data;
    }
  }
  return null;
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pump();
}

void main() {
  setUp(() => uiToday = () => DateTime(2026, 10, 13));
  tearDown(() => uiToday = DateTime.now);

  group('date helpers', () {
    test('iso helpers roll over like JavaScript dates', () {
      expect(uiIsoOf(2026, 0, 0), '2025-12-31');
      expect(uiIsoOf(2026, 1, 29), '2026-03-01');
      expect(uiDaysInMonth(2024, 1), 29);
      expect(uiParseIsoDate('2026-10-13'), DateTime(2026, 10, 13));
      expect(uiParseIsoDate('13/10/2026'), isNull);
      expect(uiFormatIsoDate(null, '2026-10-13'), 'October 13, 2026');
      expect(uiFormatIsoDate(null, '2026-10-13', short: true), 'Oct 13, 2026');
      expect(uiWeekdayNames(null).first, 'Sun');
    });
  });

  group('calendar', () {
    testWidgets('opens on the month of its value; days are buttons named with the full date', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, UiCalendar(value: '2026-03-05', onChanged: (_) {}));
      expect(find.text('March'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      final day = tester.getSemantics(find.bySemanticsLabel('March 5, 2026')).getSemanticsData();
      expect(day.flagsCollection.isButton, isTrue);
      expect(day.flagsCollection.isSelected.toString(), contains('isTrue'));
      expect(find.bySemanticsLabel('March 6, 2026'), findsOneWidget);
      // March 2026 starts on a Sunday, so the 1st is in the first column.
      expect(tester.getRect(find.text('1')).left, lessThan(tester.getRect(find.text('2')).left));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('today is marked; tapping a day picks it; min/max block days', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      await pumpUi(tester, UiCalendar(min: '2026-10-05', max: '2026-10-20', onChanged: log.add));
      expect(tester.getSemantics(find.bySemanticsLabel('October 13, 2026')).getSemanticsData().hint, 'Today');
      await tester.tap(find.text('15'));
      expect(log, ['2026-10-15']);
      await tester.tap(find.text('3'));
      await tester.tap(find.text('25'));
      expect(log, ['2026-10-15'], reason: 'outside min/max');
      expect(tester.getSemantics(find.bySemanticsLabel('October 3, 2026')).getSemanticsData().flagsCollection.isEnabled.toString(), contains('isFalse'));
      handle.dispose();
    });

    testWidgets('previous / next month buttons', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, UiCalendar(value: '2026-01-10', onChanged: (_) {}));
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pump();
      expect(find.text('December'), findsOneWidget);
      expect(find.text('2025'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pump();
      expect(find.text('February'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('day grid keyboard: arrows by day and week across months, Page keys by month, Home/End, Enter picks', (tester) async {
      final log = <String>[];
      await pumpUi(tester, UiCalendar(value: '2026-10-31', onChanged: log.add));
      // Tab past the heading controls into the grid: prev, month, year, next, days.
      for (var i = 0; i < 5; i++) {
        await _key(tester, LogicalKeyboardKey.tab);
      }
      expect(_ringDay(tester), '31', reason: 'the chosen day holds the tab stop');
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(find.text('November'), findsOneWidget);
      expect(_ringDay(tester), '1');
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(find.text('October'), findsOneWidget);
      expect(_ringDay(tester), '25');
      await _key(tester, LogicalKeyboardKey.home);
      expect(_ringDay(tester), '1');
      await _key(tester, LogicalKeyboardKey.end);
      expect(_ringDay(tester), '31');
      await _key(tester, LogicalKeyboardKey.pageDown);
      expect(find.text('November'), findsOneWidget);
      expect(_ringDay(tester), '30', reason: 'clamped to the shorter month');
      await _key(tester, LogicalKeyboardKey.pageUp);
      expect(_ringDay(tester), '30');
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(log, ['2026-10-29']);
    });

    testWidgets('month grid: opens on the month in view, arrows by one and by a row of three, Page keys by year, Enter picks', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, UiCalendar(value: '2026-05-10', onChanged: (_) {}));
      await tester.tap(find.bySemanticsLabel('Choose month, May'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Months of 2026'), findsOneWidget);
      // Keyboard focus is in the grid, on May; show the ring as for keyboard users.
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      await tester.pump();
      expect(_ringDay(tester), 'May');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_ringDay(tester), 'Aug');
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_ringDay(tester), 'Sep');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_ringDay(tester), 'Dec', reason: 'a move off the grid stays put');
      await _key(tester, LogicalKeyboardKey.home);
      expect(_ringDay(tester), 'Jan');
      await _key(tester, LogicalKeyboardKey.pageDown);
      expect(find.text('2027'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.end);
      await _key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('December'), findsOneWidget);
      expect(find.text('2027'), findsOneWidget);
      expect(_ringDay(tester), '1', reason: 'focus moves to the day grid');
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
      handle.dispose();
    });

    testWidgets('year grid: pages of 12, arrows turn the page, Enter goes to the month grid', (tester) async {
      final handle = tester.ensureSemantics();
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      await pumpUi(tester, UiCalendar(value: '2026-05-10', onChanged: (_) {}));
      await tester.tap(find.bySemanticsLabel('Choose year, 2026'));
      await tester.pumpAndSettle();
      expect(find.text('2016 – 2027'), findsOneWidget);
      expect(_ringDay(tester), '2026');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_ringDay(tester), '2029');
      expect(find.text('2028 – 2039'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.pageUp);
      expect(_ringDay(tester), '2017');
      await tester.tap(find.bySemanticsLabel('Previous years'));
      await tester.pump();
      expect(find.text('2004 – 2015'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.home);
      expect(_ringDay(tester), '2004');
      await _key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Months of 2004'), findsOneWidget);
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
      handle.dispose();
    });
  });

  group('date picker', () {
    testWidgets('shows the date as text; tapping opens the calendar on the chosen day; picking closes', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      var v = '2026-02-14';
      await pumpUi(tester, StatefulBuilder(builder: (context, set) => SizedBox(
            width: 300,
            child: UiDatePicker(value: v, label: 'Due', onChanged: (x) => set(() {
              v = x;
              log.add(x);
            })),
          )));
      expect(find.text('February 14, 2026'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Due')).getSemanticsData().value, 'February 14, 2026');
      await tester.tap(find.byType(UiDatePicker));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Choose a date'), findsOneWidget);
      expect(find.text('February'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('February 20, 2026'));
      await tester.pumpAndSettle();
      expect(log, ['2026-02-20']);
      expect(find.bySemanticsLabel('Choose a date'), findsNothing);
      expect(find.text('February 20, 2026'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('keyboard: ArrowDown opens with focus on today; Escape closes and returns to the field', (tester) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      final log = <String>[];
      await pumpUi(tester, SizedBox(width: 300, child: UiDatePicker(label: 'Due', onChanged: log.add)));
      await _key(tester, LogicalKeyboardKey.tab);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(find.text('October'), findsOneWidget);
      expect(_ringDay(tester), '13');
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await _key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('October'), findsNothing);
      expect(log, isEmpty);
      // Focus is back on the field: Enter opens it again, then Enter picks.
      await _key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(log, ['2026-10-13']);
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
    });

    testWidgets('an empty value is no date: the placeholder shows and the calendar opens on today', (tester) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      await pumpUi(tester, SizedBox(width: 300, child: UiDatePicker(label: 'Due', value: '', onChanged: (_) {})));
      expect(find.text('Select a date'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.tab);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(find.text('October'), findsOneWidget);
      expect(_ringDay(tester), '13');
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
    });

    testWidgets('Tab stays inside the popover', (tester) async {
      await pumpUi(tester, Column(children: [
        SizedBox(width: 300, child: UiDatePicker(label: 'Due', onChanged: (_) {})),
        const SizedBox(width: 300, child: UiInput(semanticLabel: 'After')),
      ]));
      await tester.tap(find.byType(UiDatePicker));
      await tester.pumpAndSettle();
      for (var i = 0; i < 8; i++) {
        await _key(tester, LogicalKeyboardKey.tab);
      }
      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isFalse);
      expect(find.bySemanticsLabel('Choose a date'), findsOneWidget);
    });

    testWidgets('a tap outside closes it', (tester) async {
      await pumpUi(tester, SizedBox(width: 300, child: UiDatePicker(label: 'Due', onChanged: (_) {})));
      await tester.tap(find.byType(UiDatePicker));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 800));
      await tester.pumpAndSettle();
      expect(find.text('October'), findsNothing);
    });

    testWidgets('golden: date picker open', (tester) async {
      await expectOverlayGolden(tester, 'date_picker', height: 520, (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [UiFormField(label: 'Due date', child: UiDatePicker(value: '2026-10-21', min: '2026-10-05', onChanged: (_) {}))],
      ), open: () async {
        await tester.tap(find.byType(UiDatePicker));
        await tester.pump();
        await tester.pump();
      });
    });
  });

  group('date range picker', () {
    test('picking: start, then end (an earlier end swaps), then a new range', () {
      var r = UiDateRange.empty;
      r = UiDateRangePicker.nextRange(r, '2026-10-10');
      expect(r, const UiDateRange(start: '2026-10-10'));
      r = UiDateRangePicker.nextRange(r, '2026-10-04');
      expect(r, const UiDateRange(start: '2026-10-04', end: '2026-10-10'));
      r = UiDateRangePicker.nextRange(r, '2026-10-20');
      expect(r, const UiDateRange(start: '2026-10-20'));
    });

    testWidgets('taps build the range; the band and the footer follow; opens on the start month', (tester) async {
      final handle = tester.ensureSemantics();
      var r = const UiDateRange(start: '2026-03-03');
      await pumpUi(tester, StatefulBuilder(builder: (context, set) => UiDateRangePicker(value: r, onChanged: (x) => set(() => r = x))));
      expect(find.text('March'), findsOneWidget);
      await tester.tap(find.text('6'));
      await tester.pump();
      expect(r, const UiDateRange(start: '2026-03-03', end: '2026-03-06'));
      expect(find.bySemanticsLabel('From Mar 3, 2026 to Mar 6, 2026'), findsOneWidget);
      final inside = tester.getSemantics(find.bySemanticsLabel('March 4, 2026')).getSemanticsData();
      expect(inside.flagsCollection.isSelected.toString(), contains('isTrue'));
      final outside = tester.getSemantics(find.bySemanticsLabel('March 9, 2026')).getSemanticsData();
      expect(outside.flagsCollection.isSelected.toString(), isNot(contains('isTrue')));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('golden: calendar and range', (tester) async {
      await expectThemedGolden(tester, 'calendars', height: 860, (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          UiCalendar(value: '2026-10-21', max: '2026-10-28', onChanged: (_) {}),
          UiDateRangePicker(value: const UiDateRange(start: '2026-10-08', end: '2026-10-15'), onChanged: (_) {}),
        ],
      ));
    });
  });
}
