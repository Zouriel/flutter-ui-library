import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

// 0.87.0: UiDateTimePicker, a date and a time for one local date-time.

/// A picker that keeps what it emits, logging each value.
Widget _picker(List<String?> log, {String? value, double width = 390, String? min, String? max, int step = 60, String defaultTime = '09:00', String? dateLabel, String? timeLabel}) {
  var v = value;
  return StatefulBuilder(
    builder: (context, set) => SizedBox(
      width: width,
      child: UiDateTimePicker(
        value: v,
        min: min,
        max: max,
        step: step,
        defaultTime: defaultTime,
        dateLabel: dateLabel,
        timeLabel: timeLabel,
        onChanged: (x) => set(() {
          v = x;
          log.add(x);
        }),
      ),
    ),
  );
}

Future<void> _pickDay(WidgetTester tester, String day) async {
  await tester.tap(find.byType(UiDatePicker));
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(day));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => uiToday = () => DateTime(2026, 10, 13));
  tearDown(() => uiToday = DateTime.now);

  testWidgets('picking a date before a time emits it with defaultTime, and the time field shows it', (tester) async {
    final handle = tester.ensureSemantics();
    final log = <String?>[];
    await pumpUi(tester, _picker(log, defaultTime: '10:30'));
    expect(tester.getSemantics(find.bySemanticsLabel('Time')).getSemanticsData().value, isEmpty);
    await _pickDay(tester, 'October 20, 2026');
    expect(log, ['2026-10-20T10:30']);
    expect(tester.getSemantics(find.bySemanticsLabel('Time')).getSemanticsData().value, '10:30');
    handle.dispose();
  });

  testWidgets('changing the time emits the date with the new time; a new date keeps the time', (tester) async {
    final handle = tester.ensureSemantics();
    final log = <String?>[];
    await pumpUi(tester, _picker(log, value: '2026-10-20T09:15', step: 900));
    expect(find.text('October 20, 2026'), findsOneWidget);
    expect(find.text('09:15'), findsOneWidget);
    await tester.tap(find.byType(UiTimePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('10 hours'));
    await tester.pump();
    expect(log.last, '2026-10-20T10:15');
    await tester.tapAt(const Offset(380, 830));
    await tester.pumpAndSettle();
    await _pickDay(tester, 'October 22, 2026');
    expect(log.last, '2026-10-22T10:15');
    handle.dispose();
  });

  testWidgets('a time picked before a date waits for the date', (tester) async {
    final handle = tester.ensureSemantics();
    final log = <String?>[];
    await pumpUi(tester, _picker(log, step: 900));
    await tester.tap(find.byType(UiTimePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('01 hours'));
    await tester.pump();
    expect(log, isEmpty, reason: 'no date yet: nothing to emit');
    await tester.tapAt(const Offset(380, 830));
    await tester.pumpAndSettle();
    await _pickDay(tester, 'October 20, 2026');
    expect(log, ['2026-10-20T01:00']);
    handle.dispose();
  });

  testWidgets('seconds when step is under 60', (tester) async {
    final log = <String?>[];
    await pumpUi(tester, _picker(log, step: 1));
    await _pickDay(tester, 'October 20, 2026');
    expect(log, ['2026-10-20T09:00:00']);
  });

  testWidgets('min and max limit the calendar by their date part', (tester) async {
    await pumpUi(tester, _picker([], min: '2026-10-10T08:00', max: '2026-10-20'));
    final date = tester.widget<UiDatePicker>(find.byType(UiDatePicker));
    expect(date.min, '2026-10-10');
    expect(date.max, '2026-10-20');
  });

  testWidgets('side by side over 320px: the date takes the rest, the time 136px; stacked at 320 and below', (tester) async {
    await pumpUi(tester, _picker([], width: 390));
    final date = tester.getRect(find.byType(UiDatePicker)), time = tester.getRect(find.byType(UiTimePicker));
    expect(time.width, 136);
    expect(date.top, time.top);
    expect(date.width + time.width, lessThan(390));
    expect(date.width, greaterThan(200));
    await pumpUi(tester, _picker([], width: 321));
    expect(tester.getRect(find.byType(UiTimePicker)).top, tester.getRect(find.byType(UiDatePicker)).top, reason: 'side by side just over 320');
    await pumpUi(tester, _picker([], width: 320));
    expect(tester.getRect(find.byType(UiTimePicker)).top, greaterThan(tester.getRect(find.byType(UiDatePicker)).bottom), reason: 'stacked at 320, the web container query');
    await pumpUi(tester, _picker([], width: 300));
    final d = tester.getRect(find.byType(UiDatePicker)), t = tester.getRect(find.byType(UiTimePicker));
    expect(t.top, greaterThan(d.bottom));
    expect(d.width, 300);
    expect(t.width, 300);
  });

  testWidgets('a wide box: the time stays 136px', (tester) async {
    await pumpUi(tester, _picker([], width: 1200), size: const Size(1440, 900));
    expect(tester.getSize(find.byType(UiTimePicker)).width, 136);
    expect(tester.getSize(find.byType(UiDatePicker)).width, greaterThan(1000));
  });

  testWidgets('the parts are named from the strings (English, Dhivehi) or by dateLabel / timeLabel', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, _picker([]));
    expect(find.bySemanticsLabel('Date'), findsOneWidget);
    expect(find.bySemanticsLabel('Time'), findsOneWidget);
    await tester.pumpWidget(UiApp(
      key: UniqueKey(),
      textDirection: TextDirection.ltr,
      config: const UiConfig(strings: UiStrings.dv),
      home: Align(alignment: Alignment.topLeft, child: _picker([])),
    ));
    expect(find.bySemanticsLabel('ތާރީޚު'), findsOneWidget);
    expect(find.bySemanticsLabel('ގަޑި'), findsOneWidget);
    await pumpUi(tester, _picker([], dateLabel: 'Start date', timeLabel: 'Start time'));
    expect(find.bySemanticsLabel('Start date'), findsOneWidget);
    expect(find.bySemanticsLabel('Start time'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a value from outside replaces both parts; null clears them', (tester) async {
    String? v = '2026-10-20T09:15';
    late StateSetter set;
    await pumpUi(tester, StatefulBuilder(builder: (context, s) {
      set = s;
      return SizedBox(width: 390, child: UiDateTimePicker(value: v, onChanged: (_) {}));
    }));
    set(() => v = '2026-11-02T18:45');
    await tester.pump();
    expect(find.text('November 2, 2026'), findsOneWidget);
    expect(find.text('18:45'), findsOneWidget);
    set(() => v = null);
    await tester.pump();
    expect(find.text('18:45'), findsNothing);
    expect(find.text('November 2, 2026'), findsNothing);
  });

  testWidgets('guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, _picker([], value: '2026-10-20T09:15'));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('golden: side by side and stacked', (tester) async {
    await expectThemedGolden(
      tester,
      'date_time_picker',
      (context) => Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 16, children: [
        const UiDateTimePicker(value: '2026-10-20T09:15'),
        const SizedBox(width: 280, child: UiDateTimePicker(value: '2026-10-20T14:30')),
        const UiDateTimePicker(),
      ]),
      height: 290,
    );
  });
}
