import 'dart:ui' show GestureSettings, Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

const _cats = ['Jan', 'Feb', 'Mar'];
const _series = [
  UiBarChartSeries(name: 'Income', values: [100, 50, -25]),
  UiBarChartSeries(name: 'Spending', values: [40, 75, 10]),
];
String _usd(num v) => '\$${v.round()}';

Widget _chart({
  List<String> categories = _cats,
  List<UiBarChartSeries> series = _series,
  bool showValues = false,
  int? selectedIndex,
  ValueChanged<int>? onCategorySelect,
  double? minCategoryWidth,
  String? emptyLabel,
  double width = 358,
}) =>
    SizedBox(
      width: width,
      child: UiBarChart(
        semanticLabel: 'Income and spending',
        categories: categories,
        series: series,
        formatValue: _usd,
        showValues: showValues,
        selectedIndex: selectedIndex,
        onCategorySelect: onCategorySelect,
        minCategoryWidth: minCategoryWidth,
        emptyLabel: emptyLabel,
      ),
    );

Finder _k(String key) => find.byKey(ValueKey(key));
Rect _bar(WidgetTester tester, int i, int k) => tester.getRect(_k('ui-bar-chart-bar-$i-$k'));
BoxDecoration _barDecoration(WidgetTester tester, int i, int k) =>
    tester.renderObject<RenderDecoratedBox>(find.descendant(of: _k('ui-bar-chart-bar-$i-$k'), matching: find.byType(DecoratedBox))).decoration as BoxDecoration;
TextStyle _style(WidgetTester tester, Finder f) => tester.renderObject<RenderParagraph>(f).text.style!;
String? _tipText(WidgetTester tester, String part) {
  final f = _k('ui-bar-chart-tip-$part');
  return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
}

final _days = [for (var i = 0; i < 30; i++) i < 17 ? 'Oct ${i + 15}' : 'Nov ${i - 16}'];
const _daily = [UiBarChartSeries(name: 'Sign-ups', values: [12, 18, 9, 14, 22, 31, 27, 16, 11, 19, 24, 38, 35, 21, 17, 13, 20, 26, 42, 39, 23, 18, 15, 28, 33, 47, 44, 29, 25, 36])];

void main() {
  group('uiChartScale', () {
    test('starts at zero and ends on a round number, with three or four gridlines above the baseline', () {
      expect(uiChartScale([12, 87, 40]).ticks, [0, 25, 50, 75, 100]);
      expect(uiChartScale([47]).ticks, [0, 20, 40, 60]);
      expect(uiChartScale([9300, 4200]).ticks, [0, 2500, 5000, 7500, 10000]);
      expect(uiChartScale([0.3, 0.1]).ticks, [0, 0.1, 0.2, 0.3]);
      expect(uiChartScale([47]).max, 60);
    });

    test('never starts above zero, however large the smallest value', () {
      expect(uiChartScale([900, 950, 1000]).min, 0);
    });

    test('makes room under the zero line for negative values, and keeps a tick on zero', () {
      final s = uiChartScale([9300, -1200, 4000]);
      expect([s.min, s.max], [-2500, 10000]);
      expect(s.ticks, [-2500, 0, 2500, 5000, 7500, 10000]);
      expect(uiChartScale([-40, -10]).ticks, [-40, -30, -20, -10, 0]);
    });

    test('gives all-zero, empty and non-finite data a flat scale with one tick', () {
      for (final values in <List<num>>[[], [0, 0, 0], [double.nan, double.infinity]]) {
        final s = uiChartScale(values);
        expect([s.min, s.max], [0, 1]);
        expect(s.ticks, [0]);
      }
    });
  });

  group('uiChartLabels', () {
    test('shows every label when they fit', () {
      expect(uiChartLabels([30, 30, 30], 60).map((l) => l.index), [0, 1, 2]);
    });

    test('thins 30 daily labels to every few, counted back from the latest', () {
      final shown = uiChartLabels(List.filled(30, 40), 14);
      expect(shown.map((l) => l.index), [4, 9, 14, 19, 24, 29]);
      expect(shown.last, const UiChartLabel(29, UiChartLabelAlign.end));
    });

    test('drops a first label that would touch its neighbour once pulled in from the edge', () {
      expect(uiChartLabels(List.filled(7, 40), 12).map((l) => l.index), [6]);
      expect(uiChartLabels(List.filled(9, 40), 12).map((l) => l.index), [2, 8]);
    });

    test('shows every label for a band of zero', () {
      expect(uiChartLabels([40, 40], 0), hasLength(2));
    });
  });

  group('UiBarChart', () {
    testWidgets('draws grouped bars from the zero line: thin, 2 apart, never overlapping, negatives below', (tester) async {
      await pumpUi(tester, _chart());
      final zero = tester.getRect(_k('ui-bar-chart-grid-zero')).bottom;
      for (var i = 0; i < 3; i++) {
        final a = _bar(tester, i, 0), b = _bar(tester, i, 1);
        expect(a.width, moreOrLessEquals(24));
        expect(b.width, moreOrLessEquals(24));
        expect(b.left - a.right, moreOrLessEquals(2), reason: 'the surface gap');
        expect(a.overlaps(b), isFalse);
      }
      expect(_bar(tester, 0, 1).left, greaterThan(_bar(tester, 0, 0).right));
      expect(_bar(tester, 1, 0).left, greaterThan(_bar(tester, 0, 1).right), reason: 'groups do not touch');
      // Scale: -25 to 100, plot 220 high, so 100 is 176 tall and 40 is 70.4.
      expect(_bar(tester, 0, 0).bottom, zero);
      expect(_bar(tester, 0, 0).height, moreOrLessEquals(176));
      expect(_bar(tester, 0, 1).height, moreOrLessEquals(70.4));
      final neg = _bar(tester, 2, 0);
      expect(neg.top, zero, reason: 'a negative bar hangs from the zero line');
      expect(neg.height, moreOrLessEquals(44));
      expect(_barDecoration(tester, 0, 0).borderRadius, const BorderRadius.vertical(top: Radius.circular(4)));
      expect(_barDecoration(tester, 2, 0).borderRadius, const BorderRadius.vertical(bottom: Radius.circular(4)));
      expect([for (var i = 0; i < 6; i++) tester.widget<Text>(_k('ui-bar-chart-tick-$i')).data], [r'$-25', r'$0', r'$25', r'$50', r'$75', r'$100']);
    });

    testWidgets('colours series from the chart tokens in order, or from their own colour', (tester) async {
      await pumpUi(tester, _chart());
      final t = tester.element(find.byType(UiBarChart)).ui;
      expect(_barDecoration(tester, 0, 0).color, t.chart1);
      expect(_barDecoration(tester, 0, 1).color, t.chart2);
      expect(t.chart1, isNot(t.chart2));
      const own = Color(0xFF010203);
      await pumpUi(tester, _chart(series: const [UiBarChartSeries(name: 'A', values: [1, 2, 3], color: own)]));
      expect(_barDecoration(tester, 0, 0).color, own);
    });

    testWidgets('shows a legend for two or more series, none for one, with names in text colours', (tester) async {
      await pumpUi(tester, _chart());
      final t = tester.element(find.byType(UiBarChart)).ui;
      expect(tester.widget<Text>(_k('ui-bar-chart-legend-0')).data, 'Income');
      expect(tester.widget<Text>(_k('ui-bar-chart-legend-1')).data, 'Spending');
      expect(_style(tester, _k('ui-bar-chart-legend-0')).color, t.textSecondary);
      await pumpUi(tester, _chart(series: [_series.first]));
      expect(_k('ui-bar-chart-legend-0'), findsNothing);
    });

    testWidgets('shows a category\'s values when the mouse is over its band: value first, then the name', (tester) async {
      await pumpUi(tester, _chart(), size: const Size(800, 600));
      expect(_k('ui-bar-chart-tip'), findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      // Over the band but beside the bars: the band is the target.
      final plot = tester.getRect(_k('ui-bar-chart-plot'));
      await mouse.moveTo(Offset(_bar(tester, 1, 0).left - 20, plot.top + 4));
      await tester.pumpAndSettle();
      expect(_tipText(tester, 'title'), 'Feb');
      expect([_tipText(tester, 'value-0'), _tipText(tester, 'name-0')], [r'$50', 'Income']);
      expect([_tipText(tester, 'value-1'), _tipText(tester, 'name-1')], [r'$75', 'Spending']);
      final tip = tester.getRect(_k('ui-bar-chart-tip'));
      final chart = tester.getRect(find.byType(UiBarChart));
      expect(tip.left >= chart.left && tip.right <= chart.right, isTrue, reason: 'inside the chart');
      expect(tip.overlaps(tester.getRect(_k('ui-bar-chart-band-1'))), isFalse, reason: 'beside its band');
      // The panel goes to the side with more room: right of the first category, left of the last.
      await mouse.moveTo(Offset(_bar(tester, 0, 0).center.dx, plot.top + 4));
      await tester.pumpAndSettle();
      expect(_tipText(tester, 'title'), 'Jan');
      expect(tester.getRect(_k('ui-bar-chart-tip')).left, greaterThanOrEqualTo(tester.getRect(_k('ui-bar-chart-band-0')).right));
      expect(tester.getRect(_k('ui-bar-chart-tip')).right, lessThanOrEqualTo(chart.right));
      await mouse.moveTo(Offset(_bar(tester, 2, 0).center.dx, plot.top + 4));
      await tester.pumpAndSettle();
      expect(_tipText(tester, 'title'), 'Mar');
      expect(tester.getRect(_k('ui-bar-chart-tip')).right, lessThanOrEqualTo(tester.getRect(_k('ui-bar-chart-band-2')).left));
      expect(tester.getRect(_k('ui-bar-chart-tip')).left, greaterThanOrEqualTo(chart.left));
      await mouse.moveTo(const Offset(700, 500));
      await tester.pumpAndSettle();
      expect(_k('ui-bar-chart-tip'), findsNothing);
    });

    testWidgets('moves between categories with the arrow keys, the panel following', (tester) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      final picked = <int>[];
      await pumpUi(tester, _chart(onCategorySelect: picked.add));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_tipText(tester, 'title'), 'Mar', reason: 'focus starts at the latest');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(_tipText(tester, 'title'), 'Feb');
      expect(_tipText(tester, 'value-1'), r'$75');
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(_tipText(tester, 'title'), 'Jan');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(picked, [0]);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_tipText(tester, 'title'), 'Mar');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_k('ui-bar-chart-tip'), findsNothing);
    });

    testWidgets('a tap chooses the category and shows its values; the chosen one is marked beyond colour', (tester) async {
      int? sel;
      await pumpUi(tester, StatefulBuilder(builder: (context, setState) => _chart(selectedIndex: sel, onCategorySelect: (i) => setState(() => sel = i))));
      expect(_k('ui-bar-chart-selected-rule'), findsNothing);
      await tester.tapAt(tester.getRect(_k('ui-bar-chart-plot')).topLeft + Offset(_bar(tester, 1, 0).left - tester.getRect(_k('ui-bar-chart-plot')).left, 6));
      await tester.pumpAndSettle();
      expect(sel, 1);
      expect(_tipText(tester, 'title'), 'Feb');
      final rule = tester.getRect(_k('ui-bar-chart-selected-rule'));
      final band = tester.getRect(_k('ui-bar-chart-band-1'));
      expect([rule.left, rule.width, rule.height], [band.left, band.width, 2]);
      expect(_style(tester, _k('ui-bar-chart-label-1')).fontWeight, FontWeight.w600);
      expect(_style(tester, _k('ui-bar-chart-label-0')).fontWeight, isNot(FontWeight.w600));
      final t = tester.element(find.byType(UiBarChart)).ui;
      expect(_style(tester, _k('ui-bar-chart-label-1')).color, t.text);
      // A tap outside puts the panel away.
      await tester.tapAt(const Offset(380, 800));
      await tester.pumpAndSettle();
      expect(_k('ui-bar-chart-tip'), findsNothing);
    });

    testWidgets('gives screen readers the name and every category\'s numbers', (tester) async {
      final handle = tester.ensureSemantics();
      final picked = <int>[];
      await pumpUi(tester, _chart(onCategorySelect: picked.add, selectedIndex: 2));
      SemanticsData data() => tester.getSemantics(find.byType(UiBarChart)).getSemanticsData();
      expect(data().label, 'Income and spending');
      expect(data().value, r'Mar: Income $-25, Spending $10');
      expect(data().hasAction(SemanticsAction.increase), isTrue);
      expect(data().flagsCollection.isSelected, Tristate.isTrue);
      tester.semantics.performAction(find.semantics.byLabel('Income and spending'), SemanticsAction.decrease);
      await tester.pumpAndSettle();
      expect(data().value, r'Feb: Income $50, Spending $75');
      tester.semantics.performAction(find.semantics.byLabel('Income and spending'), SemanticsAction.decrease);
      await tester.pumpAndSettle();
      expect(data().value, r'Jan: Income $100, Spending $40');
      tester.semantics.performAction(find.semantics.byLabel('Income and spending'), SemanticsAction.tap);
      expect(picked, [0]);
      // The drawing itself adds no stray nodes: one node carries it all.
      expect(find.semantics.byLabel('Income'), findsNothing);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('writes a value on each bar only with showValues, above it or under a negative one', (tester) async {
      await pumpUi(tester, _chart());
      expect(_k('ui-bar-chart-value-0-0'), findsNothing);
      await pumpUi(tester, _chart(showValues: true));
      final t = tester.element(find.byType(UiBarChart)).ui;
      expect(tester.widget<Text>(_k('ui-bar-chart-value-0-0')).data, r'$100');
      expect(tester.widget<Text>(_k('ui-bar-chart-value-2-0')).data, r'$-25');
      expect(_style(tester, _k('ui-bar-chart-value-0-0')).color, t.text);
      expect(tester.getRect(_k('ui-bar-chart-value-0-0')).bottom, lessThanOrEqualTo(_bar(tester, 0, 0).top));
      expect(tester.getRect(_k('ui-bar-chart-value-2-0')).top, greaterThanOrEqualTo(_bar(tester, 2, 0).bottom));
      // Centred on its bar.
      expect(tester.getRect(_k('ui-bar-chart-value-0-0')).center.dx, moreOrLessEquals(_bar(tester, 0, 0).center.dx, epsilon: 0.6));
    });

    testWidgets('keeps the axes and says there is no data when every value is zero or missing', (tester) async {
      for (final values in const <List<num>>[[0, 0, 0], []]) {
        await pumpUi(tester, _chart(series: [UiBarChartSeries(name: 'Sales', values: values)], emptyLabel: 'No data yet'));
        expect(tester.widget<Text>(_k('ui-bar-chart-empty')).data, 'No data yet');
        expect(_k('ui-bar-chart-bar-0-0'), findsNothing);
        expect(_k('ui-bar-chart-grid-zero'), findsOneWidget);
        expect(_k('ui-bar-chart-label-0'), findsOneWidget);
      }
      await pumpUi(tester, _chart(series: const []));
      expect(tester.widget<Text>(_k('ui-bar-chart-empty')).data, 'No data');
      await pumpUi(tester, _chart());
      expect(_k('ui-bar-chart-empty'), findsNothing);
    });

    testWidgets('draws at most four series', (tester) async {
      await pumpUi(tester, _chart(series: [for (var i = 0; i < 6; i++) UiBarChartSeries(name: 'S$i', values: const [1, 2, 3])]));
      expect(_k('ui-bar-chart-bar-0-3'), findsOneWidget);
      expect(_k('ui-bar-chart-bar-0-4'), findsNothing);
    });

    testWidgets('thins the x labels of 30 days so none overlap or leave the plot', (tester) async {
      await pumpUi(tester, _chart(categories: _days, series: _daily));
      final shown = [for (var i = 0; i < 30; i++) if (_k('ui-bar-chart-label-$i').evaluate().isNotEmpty) i];
      expect(shown.length, inInclusiveRange(4, 8));
      expect(shown.last, 29, reason: 'the latest is always labelled');
      final rects = [for (final i in shown) tester.getRect(_k('ui-bar-chart-label-$i'))];
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].left, greaterThanOrEqualTo(rects[i - 1].right + 4), reason: 'labels ${shown[i - 1]} and ${shown[i]}');
      }
      final scroller = tester.getRect(_k('ui-bar-chart-scroller'));
      expect(rects.first.left, greaterThanOrEqualTo(scroller.left));
      expect(rects.last.right, lessThanOrEqualTo(scroller.right + 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolls sideways inside itself on a phone, starting at the latest, inside a page that scrolls down', (tester) async {
      // A phone's touch slop (8dp); the test default of 18 hides gesture conflicts.
      tester.view.gestureSettings = GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
      addTearDown(tester.view.resetGestureSettings);
      final page = ScrollController();
      addTearDown(page.dispose);
      await pumpUi(
        tester,
        SizedBox(
          width: 390,
          height: 844,
          child: ListView(controller: page, padding: const EdgeInsets.all(16), children: [
            _chart(categories: _days, series: _daily, minCategoryWidth: 24),
            const SizedBox(height: 1200),
          ]),
        ),
      );
      expect(tester.takeException(), isNull);
      final chart = tester.getRect(find.byType(UiBarChart));
      expect(chart.right, lessThanOrEqualTo(390 - 16), reason: 'the chart stays inside the page');
      final scroller = tester.getRect(_k('ui-bar-chart-scroller'));
      final position = tester.state<ScrollableState>(find.descendant(of: _k('ui-bar-chart-scroller'), matching: find.byType(Scrollable))).position;
      expect(position.maxScrollExtent, moreOrLessEquals(30 * 24 - scroller.width), reason: 'the plot is as wide as its categories need');
      // Starts at the latest: the last day's bar is in view, the first is not.
      expect(_bar(tester, 29, 0).right, lessThanOrEqualTo(scroller.right));
      expect(_bar(tester, 29, 0).left, greaterThan(scroller.left));
      expect(_bar(tester, 0, 0).right, lessThan(scroller.left));
      final tick = tester.getRect(_k('ui-bar-chart-tick-0'));

      // A sideways drag moves the plot, not the page; the y axis stays put.
      await tester.dragFrom(scroller.center, const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(150));
      expect(page.offset, 0);
      expect(tester.getRect(_k('ui-bar-chart-tick-0')), tick);
      expect(_bar(tester, 29, 0).left, greaterThan(scroller.right), reason: 'the latest scrolled out');
      // A drag down on the chart scrolls the page, not the plot.
      final before = position.pixels;
      await tester.dragFrom(tester.getRect(_k('ui-bar-chart-scroller')).center, const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(page.offset, greaterThan(80));
      expect(position.pixels, before);
    });

    testWidgets('does not scroll when the categories fit', (tester) async {
      await pumpUi(tester, _chart(minCategoryWidth: 44));
      final position = tester.state<ScrollableState>(find.descendant(of: _k('ui-bar-chart-scroller'), matching: find.byType(Scrollable))).position;
      expect(position.maxScrollExtent, 0);
    });

    testWidgets('mirrors under RTL: the first category at the right, the y axis at the right', (tester) async {
      await pumpUi(tester, Directionality(textDirection: TextDirection.rtl, child: _chart()));
      expect(_bar(tester, 0, 0).left, greaterThan(_bar(tester, 2, 0).left));
      expect(tester.getRect(_k('ui-bar-chart-tick-0')).left, greaterThan(_bar(tester, 0, 0).right));
      expect(tester.takeException(), isNull);
    });

    testWidgets('golden: grouped bars with a chosen month, dark and light', (tester) async {
      await expectThemedGolden(
        tester,
        'bar_chart_grouped',
        (context) => const UiBarChart(
          semanticLabel: 'Income and spending',
          categories: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
          series: [
            UiBarChartSeries(name: 'Income', values: [4200, 5100, 4800, -1200, 7200, 6900]),
            UiBarChartSeries(name: 'Spending', values: [3100, 3400, 3900, 4100, 4600, 5200]),
          ],
          selectedIndex: 4,
        ),
        themes: const [UiThemeName.dark, UiThemeName.light, UiThemeName.oxblood, UiThemeName.oxbloodDark],
        height: 360,
      );
    });

    testWidgets('golden: value labels and the empty state', (tester) async {
      await expectThemedGolden(
        tester,
        'bar_chart_values_empty',
        (context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 24, children: const [
          UiBarChart(semanticLabel: 'Events', categories: ['Last month', 'This month'], series: [UiBarChartSeries(name: 'Events', values: [18, 27])], showValues: true, height: 140),
          UiBarChart(semanticLabel: 'Sales', categories: ['Jan', 'Feb', 'Mar'], series: [UiBarChartSeries(name: 'Sales', values: [])], emptyLabel: 'No data yet', height: 120),
        ]),
        height: 420,
      );
    });
  });
}
