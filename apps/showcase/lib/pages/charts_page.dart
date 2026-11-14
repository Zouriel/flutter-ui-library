import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
final _days = [for (var i = 0; i < 30; i++) i < 17 ? 'Oct ${i + 15}' : 'Nov ${i - 16}'];
const _signUps = <num>[12, 18, 9, 14, 22, 31, 27, 16, 11, 19, 24, 38, 35, 21, 17, 13, 20, 26, 42, 39, 23, 18, 15, 28, 33, 47, 44, 29, 25, 36];
const _money = [
  UiBarChartSeries(name: 'Income', values: [4200, 5100, 4800, 6300, 7200, 6900, 8100, 7600, 5400, -1200, 6800, 9300]),
  UiBarChartSeries(name: 'Spending', values: [3100, 3400, 3900, 4100, 4600, 5200, 4900, 5300, 5800, 4400, 4700, 5600]),
];

String _mvr(num v) {
  final digits = v.abs().round().toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return 'MVR ${v < 0 ? '-' : ''}$grouped';
}

/// The Charts page: the bar chart with plain columns, grouped bars, value labels and no data.
class ChartsPage extends StatefulWidget {
  const ChartsPage({super.key});

  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  int? _day;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final text = context.uiText;
    return DocPage(
      eyebrow: 'Components',
      title: 'Charts',
      lead: 'A bar chart for dashboards: thin columns from a zero baseline, a quiet grid, and colours each theme has checked for colour-blind readers. Screen readers can walk through every number.',
      children: [
        DocSection(
          name: 'Bar chart',
          widget: 'UiBarChart',
          summary: 'One series draws plain columns and needs no legend: say what is plotted in the heading above it. Bars are 24 wide at most and the y axis starts at zero on round numbers. Tap a category, hover it with a mouse, or focus the chart and use the left and right arrow keys: a small panel shows its values. When there are more labels than fit, only every few are shown, counted back from the latest. With minCategoryWidth the plot scrolls sideways inside the chart once it gets narrower than that for every category, starting at the latest; the y axis stays where it is. Set selectedIndex and onCategorySelect to let people choose a category: the chosen one is tinted and its label is bold with a rule above it. Screen readers hear the chart\'s name and one category with its numbers, and move between categories with the increase and decrease actions.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            Text('Sign-ups a day, last 30 days', style: text.label),
            UiBarChart(
              key: const ValueKey('charts-daily'),
              semanticLabel: 'Sign-ups a day, last 30 days',
              categories: _days,
              series: const [UiBarChartSeries(name: 'Sign-ups', values: _signUps)],
              minCategoryWidth: 14,
              selectedIndex: _day,
              onCategorySelect: (i) => setState(() => _day = i),
            ),
            Text(_day == null ? 'Choose a day.' : '${_days[_day!]}: ${_signUps[_day!]} sign-ups', key: const ValueKey('charts-daily-picked'), style: text.caption),
          ]),
          code: '''UiBarChart(
  semanticLabel: 'Sign-ups a day, last 30 days',
  categories: days,
  series: [UiBarChartSeries(name: 'Sign-ups', values: signUps)],
  minCategoryWidth: 14,
  selectedIndex: day,
  onCategorySelect: (i) => setState(() => day = i),
)''',
          shapes: 'UiBarChartSeries({required String name, required List<num> values, Color? color})',
          api: const [
            ApiRow('semanticLabel', 'String (required)', 'The chart\'s name for screen readers (the web ariaLabel).'),
            ApiRow('categories', 'List<String>', 'The x labels, one per category, oldest first.', def: '[]'),
            ApiRow('series', 'List<UiBarChartSeries>', 'One to four series. One draws plain columns; more draw grouped bars with a legend. A missing value counts as 0.', def: '[]'),
            ApiRow('formatValue', 'String Function(num)?', 'Formats a number for the axis, the panel, the value labels and screen readers.', def: 'locale number'),
            ApiRow('height', 'double', 'Height of the plot. The x labels and the legend come on top of it.', def: '220'),
            ApiRow('showValues', 'bool', 'A value above each bar, in text ink. For charts with a few bars.', def: 'false'),
            ApiRow('selectedIndex', 'int?', 'The chosen category: tinted, its label bold with a rule above it.'),
            ApiRow('minCategoryWidth', 'double?', 'Least width of one category. Narrower than that for all of them, the plot scrolls sideways inside the chart, starting at the latest.'),
            ApiRow('emptyLabel', 'String?', 'Shown over the axes when there is no data or every value is 0.', def: 'No data'),
          ],
          callbacks: const [
            ApiRow('onCategorySelect', 'ValueChanged<int>?', 'A category was tapped, clicked, or chosen with Enter or Space: its index.'),
          ],
        ),
        DocSection(
          name: 'Grouped bars',
          widget: 'UiBarChart(series: [...])',
          summary: 'Two to four series sit side by side in each category, 2 apart, with a legend above. Series take the theme\'s chart colours in order (chart1 to chart4 in the tokens), or their own color. Names are always written in text colours, never in the series colour. Values below zero hang under the zero line. formatValue formats the axis, the panel and the value labels.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            Text('Income and spending by month', style: text.label),
            const UiBarChart(key: ValueKey('charts-grouped'), semanticLabel: 'Income and spending by month', categories: _months, series: _money, formatValue: _mvr, minCategoryWidth: 44),
          ]),
          code: '''UiBarChart(
  semanticLabel: 'Income and spending by month',
  categories: months,
  series: [
    UiBarChartSeries(name: 'Income', values: income),
    UiBarChartSeries(name: 'Spending', values: spending),
  ],
  formatValue: mvr,
  minCategoryWidth: 44,
)''',
        ),
        DocSection(
          name: 'Value labels',
          widget: 'UiBarChart(showValues: true)',
          summary: 'showValues writes each value above its bar, in text ink. Use it when there are only a few bars; with many, leave the numbers to the axis and the panel.',
          demo: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
                Text('Events this month and last', style: text.label),
                const UiBarChart(
                  key: ValueKey('charts-values'),
                  semanticLabel: 'Events this month and last',
                  categories: ['Last month', 'This month'],
                  series: [UiBarChartSeries(name: 'Events', values: [18, 27])],
                  showValues: true,
                  height: 160,
                ),
              ]),
            ),
          ),
          code: '''UiBarChart(
  semanticLabel: 'Events this month and last',
  categories: ['Last month', 'This month'],
  series: [UiBarChartSeries(name: 'Events', values: [18, 27])],
  showValues: true,
  height: 160,
)''',
        ),
        DocSection(
          name: 'No data',
          widget: 'UiBarChart(emptyLabel:)',
          summary: 'With no values, or when every value is zero, the axes stay and a quiet line says so. emptyLabel sets the words; without it the built-in No data is shown in the app\'s language.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            Text('Sales by month', style: text.label),
            const UiBarChart(key: ValueKey('charts-empty'), semanticLabel: 'Sales by month', categories: _months, series: [UiBarChartSeries(name: 'Sales', values: [])], emptyLabel: 'No data yet', height: 160),
          ]),
          code: '''UiBarChart(
  semanticLabel: 'Sales by month',
  categories: months,
  series: [UiBarChartSeries(name: 'Sales', values: [])],
  emptyLabel: 'No data yet',
  height: 160,
)''',
        ),
      ],
    );
  }
}
