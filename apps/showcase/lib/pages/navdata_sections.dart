import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

// Sections added to the Data and Feedback pages by the navdata port. Kept in their own file so the
// pages' other sections stay untouched.

/// Data display: table, list, tree, tree table, accordion, stat card, description list, timeline,
/// code block, link and kbd.
List<Widget> navdataDataSections() => const [
      _TableSection(),
      _ListSection(),
      _TreeSection(),
      _TreeTableSection(),
      _AccordionSection(),
      _StatCardSection(),
      _DescriptionListSection(),
      _TimelineSection(),
      _CodeBlockSection(),
      _LinkKbdSection(),
    ];

/// Feedback: progress circle, meter, empty state, result.
List<Widget> navdataFeedbackSections() => const [
      _ProgressCircleSection(),
      _MeterSection(),
      _EmptyStateSection(),
      _ResultSection(),
    ];

typedef _Member = Map<String, Object?>;

/// An empty cell shows a dash (as on the web) rather than a blank.
String _orDash(Object? v, _Member _) => v == null ? '\u2014' : '$v';

class _TableSection extends StatefulWidget {
  const _TableSection();
  @override
  State<_TableSection> createState() => _TableSectionState();
}

class _TableSectionState extends State<_TableSection> {
  List<_Member> _rows = [
    {'name': 'Aminath Shareef', 'role': 'Owner', 'seats': 12},
    {'name': 'ali zahir', 'role': 'Editor', 'seats': 3},
    {'name': 'Item 10', 'role': 'Viewer', 'seats': null},
    {'name': 'Item 9', 'role': 'Viewer', 'seats': 1},
  ];
  int _selected = 0;
  String? _last;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return DocSection(
      name: 'Table',
      widget: 'UiTable<T>',
      summary: 'A data table with tap-to-sort headers, optional row selection and per-row actions. Sorting cycles ascending, descending, unsorted; numbers compare as numbers, text naturally and case-insensitively ("Item 9" before "Item 10"), and empty cells go last. Selection is tracked by row identity and forgets rows that leave data; the header box shows "some" for a partial selection. Row actions are real buttons that can be off per row and named per row. With no rows it shows emptyText. On a narrow screen the table keeps its natural width and scrolls sideways.',
      demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
        UiTable<_Member>(
          selectable: true,
          onSelectionChanged: (rows) => setState(() => _selected = rows.length),
          columns: const [
            UiColumn(key: 'name', header: 'Name', sortable: true),
            UiColumn(key: 'role', header: 'Role', sortable: true),
            UiColumn(key: 'seats', header: 'Seats', sortable: true, align: UiColumnAlign.end, format: _orDash),
          ],
          data: _rows,
          actions: [
            UiRowAction(label: 'Edit', run: (r) => setState(() => _last = 'Edit ${r['name']}'), semanticLabel: (r) => 'Edit ${r['name']}'),
            UiRowAction(
              label: 'Remove',
              disabled: (r) => r['role'] == 'Owner',
              run: (r) => setState(() {
                _rows = [..._rows]..remove(r);
                _last = 'Removed ${r['name']}';
              }),
            ),
          ],
        ),
        UiText('$_selected selected${_last == null ? '' : ' · $_last'}', variant: UiTextVariant.caption),
        const UiTable<_Member>(columns: [UiColumn(key: 'name', header: 'Name'), UiColumn(key: 'role', header: 'Role')], data: [], emptyText: 'No members yet'),
      ]),
      code: "UiTable<Map<String, Object?>>(\n  selectable: true,\n  columns: [\n    UiColumn(key: 'name', header: 'Name', sortable: true),\n    UiColumn(key: 'seats', header: 'Seats', sortable: true, align: UiColumnAlign.end, format: (v, _) => v == null ? '\\u2014' : '\$v'),\n  ],\n  data: rows,\n  actions: [UiRowAction(label: 'Edit', run: edit)],\n  onSelectionChanged: (rows) => setState(() => picked = rows),\n)",
      api: const [
        ApiRow('columns', 'List<UiColumn<T>>', 'key, header, sortable, align, value (reader), format.'),
        ApiRow('data', 'List<T>', 'Rows; maps are read by column key.'),
        ApiRow('selectable', 'bool', 'Adds a checkbox column.', def: 'false'),
        ApiRow('actions', 'List<UiRowAction<T>>', 'label, run, disabled(row), semanticLabel(row).'),
        ApiRow('emptyText', 'String', 'Shown with no rows.', def: "'No data'"),
        ApiRow('onSelectionChanged', 'ValueChanged<List<T>>?', 'The selected rows after each change.'),
      ],
    );
  }
}

class _ListSection extends StatefulWidget {
  const _ListSection();
  @override
  State<_ListSection> createState() => _ListSectionState();
}

class _ListSectionState extends State<_ListSection> {
  int _sel = 1;

  @override
  Widget build(BuildContext context) {
    final names = ['Aminath Shareef', 'Ali Zahir', 'Hawwa Nashidha'];
    final roles = ['Owner', 'Editor', 'Viewer'];
    return DocSection(
      name: 'List',
      widget: 'UiList · UiListItem',
      summary: 'Rows with optional leading and trailing widgets (trailing in the muted colour), announced as a list. With onTap a row is a button, 48dp tall on touch, with an inset focus ring; selected tints it and is announced; enabled: false fades it. bordered draws a rounded border with rules between rows.',
      demo: UiList(bordered: true, children: [
        for (var i = 0; i < 3; i++)
          UiListItem(
            leading: const UiIcon(HugeIcons.strokeRoundedUserCircle),
            trailing: Text(roles[i]),
            selected: _sel == i,
            enabled: i != 2,
            onTap: () => setState(() => _sel = i),
            child: Text(names[i]),
          ),
      ]),
      code: "UiList(bordered: true, children: [\n  UiListItem(\n    leading: UiIcon(HugeIcons.strokeRoundedUserCircle),\n    trailing: Text('Owner'),\n    selected: true,\n    onTap: open,\n    child: Text('Aminath Shareef'),\n  ),\n])",
      api: const [
        ApiRow('UiList.bordered', 'bool', 'Border and row rules.', def: 'false'),
        ApiRow('child / leading / trailing', 'Widget', 'Row content.'),
        ApiRow('onTap', 'VoidCallback?', 'Makes the row a button.'),
        ApiRow('selected', 'bool', 'Tinted and announced.', def: 'false'),
        ApiRow('enabled', 'bool', 'Fades and ignores taps when false.', def: 'true'),
      ],
    );
  }
}

const _files = [
  UiTreeNode(label: 'src', value: 'src', icon: HugeIcons.strokeRoundedFolder01, children: [
    UiTreeNode(label: 'app.dart', value: 'app', icon: HugeIcons.strokeRoundedFile01),
    UiTreeNode(label: 'widgets', value: 'widgets', icon: HugeIcons.strokeRoundedFolder01, children: [
      UiTreeNode(label: 'button.dart', value: 'button', icon: HugeIcons.strokeRoundedFile01),
      UiTreeNode(label: 'card.dart', value: 'card', icon: HugeIcons.strokeRoundedFile01),
    ]),
  ]),
  UiTreeNode(label: 'test', value: 'test', icon: HugeIcons.strokeRoundedFolder01, children: [
    UiTreeNode(label: 'app_test.dart', value: 'app_test', icon: HugeIcons.strokeRoundedFile01),
  ]),
  UiTreeNode(label: 'README.md', value: 'readme', icon: HugeIcons.strokeRoundedFile01),
];

class _TreeSection extends StatefulWidget {
  const _TreeSection();
  @override
  State<_TreeSection> createState() => _TreeSectionState();
}

class _TreeSectionState extends State<_TreeSection> {
  String? _sel = 'app';

  @override
  Widget build(BuildContext context) => DocSection(
        name: 'Tree',
        widget: 'UiTree',
        summary: 'An expandable hierarchy with single selection. A tap on a row selects it; a tap on the chevron opens or closes it without selecting. Rows are read with their level and position, expanded and selected state, and offer expand/collapse actions to screen readers. Keyboard: one tab stop; Up/Down, Home/End move; Right opens then enters; Left closes then goes to the parent; Enter/Space select; * opens every sibling; typing a letter jumps to the next item starting with it.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: context.ui.space2, children: [
          UiTree(label: 'Files', nodes: _files, selected: _sel, initiallyExpanded: const {'src'}, onSelect: (n) => setState(() => _sel = n.value)),
          UiText('Selected: ${_sel ?? 'nothing'}', variant: UiTextVariant.caption),
        ]),
        code: "UiTree(\n  label: 'Files',\n  nodes: [\n    UiTreeNode(label: 'src', value: 'src', icon: HugeIcons.strokeRoundedFolder01, children: [...]),\n  ],\n  selected: selected,\n  onSelect: (node) => setState(() => selected = node.value),\n)",
        api: const [
          ApiRow('nodes', 'List<UiTreeNode>', 'label, value, icon, children.'),
          ApiRow('selected', 'String?', 'Value of the selected node.'),
          ApiRow('onSelect', 'ValueChanged<UiTreeNode>?', 'A node was chosen.'),
          ApiRow('label', 'String?', 'Accessible name.'),
          ApiRow('initiallyExpanded', 'Set<String>', 'Values open at first.', def: '{}'),
        ],
      );
}

class _TreeTableSection extends StatelessWidget {
  const _TreeTableSection();

  @override
  Widget build(BuildContext context) => const DocSection(
        name: 'Tree table',
        widget: 'UiTreeTable',
        summary: 'A table whose first column is an expandable tree. Parent rows have a chevron button ("Expand Q1", with its expanded state) that shows their children indented below. Scrolls sideways on narrow screens.',
        demo: UiTreeTable(
          firstHeader: 'Period',
          initiallyExpanded: {'q1'},
          columns: [
            UiTreeTableColumn(key: 'revenue', header: 'Revenue', align: UiColumnAlign.end),
            UiTreeTableColumn(key: 'orders', header: 'Orders', align: UiColumnAlign.end),
          ],
          rows: [
            UiTreeTableRow(label: 'Q1', value: 'q1', data: {'revenue': '32,400', 'orders': 410}, children: [
              UiTreeTableRow(label: 'January', value: 'jan', data: {'revenue': '10,100', 'orders': 120}),
              UiTreeTableRow(label: 'February', value: 'feb', data: {'revenue': '9,800', 'orders': 131}),
              UiTreeTableRow(label: 'March', value: 'mar', data: {'revenue': '12,500', 'orders': 159}),
            ]),
            UiTreeTableRow(label: 'Q2', value: 'q2', data: {'revenue': '41,000', 'orders': 502}, children: [
              UiTreeTableRow(label: 'April', value: 'apr', data: {'revenue': '13,000', 'orders': 160}),
            ]),
          ],
        ),
        code: "UiTreeTable(\n  columns: [UiTreeTableColumn(key: 'revenue', header: 'Revenue', align: UiColumnAlign.end)],\n  rows: [\n    UiTreeTableRow(label: 'Q1', value: 'q1', data: {'revenue': '32,400'}, children: [...]),\n  ],\n)",
        api: [
          ApiRow('rows', 'List<UiTreeTableRow>', 'label, value, data (by column key), children.'),
          ApiRow('columns', 'List<UiTreeTableColumn>', 'key, header, align.'),
          ApiRow('firstHeader', 'String', 'Header of the tree column.', def: "'Name'"),
          ApiRow('initiallyExpanded', 'Set<String>', 'Rows open at first.', def: '{}'),
        ],
      );
}

class _AccordionSection extends StatelessWidget {
  const _AccordionSection();

  @override
  Widget build(BuildContext context) => DocSection(
        name: 'Accordion',
        widget: 'UiAccordion · UiAccordionItem',
        summary: 'Titled panels that open and close. Opening one closes the others unless multiple. The title row is a heading and an expandable button (48dp on touch); a closed panel is hidden from screen readers and focus. An item on its own toggles itself.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: context.ui.space4, children: const [
          UiAccordion(initiallyOpen: {0}, children: [
            UiAccordionItem(title: 'What ships with the library?', child: Text('Components, 13 themes, the form engine and the file viewers.')),
            UiAccordionItem(title: 'Does it use Material?', child: Text('No. It builds on the widgets layer, so it looks like this design everywhere.')),
            UiAccordionItem(title: 'Can I change the radius?', child: Text('Yes, with UiConfig(radius: false).')),
          ]),
          UiAccordion(multiple: true, children: [
            UiAccordionItem(title: 'Multiple: first', child: Text('Stays open when you open the second.')),
            UiAccordionItem(title: 'Multiple: second', child: Text('Both can be open.')),
          ]),
        ]),
        code: "UiAccordion(multiple: false, initiallyOpen: {0}, children: [\n  UiAccordionItem(title: 'Shipping', child: Text('Ships in 2 days.')),\n  UiAccordionItem(title: 'Returns', child: Text('30 days.')),\n])",
        api: const [
          ApiRow('children', 'List<UiAccordionItem>', 'title and child.'),
          ApiRow('multiple', 'bool', 'Allow several open at once.', def: 'false'),
          ApiRow('initiallyOpen', 'Set<int>', 'Open at first.', def: '{}'),
          ApiRow('onChanged', 'ValueChanged<Set<int>>?', 'The open set after each toggle.'),
        ],
      );
}

class _StatCardSection extends StatelessWidget {
  const _StatCardSection();

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return DocSection(
      name: 'Stat card',
      widget: 'UiStatCard',
      summary: 'A KPI tile: label, a large value, an optional delta with a drawn up or down marker (green up, red down; the direction is also spoken) and an optional icon. Read by screen readers as one sentence. glass and radius follow UiConfig.',
      demo: DocGrid(minWidth: 170, minColumns: 2, maxColumns: 3, gap: t.space3, equalHeight: true, children: const [
        UiStatCard(label: 'Revenue', value: r'$48.2k', delta: '12.5%', icon: UiIcon(HugeIcons.strokeRoundedDollar01)),
        UiStatCard(label: 'Churn', value: '2.1%', delta: '0.4%', trend: UiTrend.down),
        UiStatCard(label: 'Active users', value: '1,204'),
      ]),
      code: "UiStatCard(label: 'Revenue', value: r'\$48.2k', delta: '12.5%', icon: UiIcon(HugeIcons.strokeRoundedDollar01))\nUiStatCard(label: 'Churn', value: '2.1%', delta: '0.4%', trend: UiTrend.down)",
      api: const [
        ApiRow('label / value', 'String', 'What is measured, and its value.'),
        ApiRow('delta', 'String?', 'The change, e.g. "12%".'),
        ApiRow('trend', 'UiTrend', 'up (green) or down (red).', def: 'up'),
        ApiRow('icon', 'Widget?', 'Corner icon, muted.'),
        ApiRow('glass / radius', 'bool?', 'Default to UiConfig.'),
      ],
    );
  }
}

class _DescriptionListSection extends StatelessWidget {
  const _DescriptionListSection();

  @override
  Widget build(BuildContext context) => DocSection(
        name: 'Description list',
        widget: 'UiDescriptionList',
        summary: 'Key/value pairs. row puts the term in a 140px column beside the detail and stacks on a very narrow width (stackBelow); stacked puts it above. Each pair is read together.',
        demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: context.ui.space4, children: const [
          UiDescriptionList(items: [
            UiDescriptionItem(term: 'Status', detail: 'Active'),
            UiDescriptionItem(term: 'Plan', detail: 'Studio, billed yearly'),
            UiDescriptionItem(term: 'Renews', detail: '14 March 2027'),
          ]),
          UiDescriptionList(layout: UiDescriptionLayout.stacked, items: [UiDescriptionItem(term: 'Stacked term', detail: 'The detail sits below.')]),
        ]),
        code: "UiDescriptionList(items: [\n  UiDescriptionItem(term: 'Status', detail: 'Active'),\n  UiDescriptionItem(term: 'Plan', detail: 'Studio'),\n])",
        api: const [
          ApiRow('items', 'List<UiDescriptionItem>', 'term and detail.'),
          ApiRow('layout', 'UiDescriptionLayout', 'row or stacked.', def: 'row'),
          ApiRow('termWidth', 'double', 'Term column width in row layout.', def: '140'),
          ApiRow('stackBelow', 'double', 'Row layout stacks below this width.', def: '300'),
        ],
      );
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection();

  @override
  Widget build(BuildContext context) => DocSection(
        name: 'Timeline',
        widget: 'UiTimeline',
        summary: 'A vertical sequence of events joined by a line, read as a list. Each event has a tone-coloured dot, or with an icon a 20px marker; a title with optional meta (usually a time) and a description. Markers carry a ring in ringColor so the line breaks around them; set it to the colour behind the timeline.',
        demo: UiTimeline(ringColor: context.ui.surfaceSubtle, items: const [
          UiTimelineItem(title: 'Order placed', meta: '09:12', description: 'Two items, paid by card'),
          UiTimelineItem(title: 'Payment confirmed', meta: '09:13', tone: UiStatus.success, icon: HugeIcons.strokeRoundedTick02),
          UiTimelineItem(title: 'Address check', meta: '10:40', tone: UiStatus.warning, description: 'Waiting on the courier'),
          UiTimelineItem(title: 'Delivered', tone: UiStatus.neutral),
        ]),
        code: "UiTimeline(items: [\n  UiTimelineItem(title: 'Order placed', meta: '09:12'),\n  UiTimelineItem(title: 'Paid', tone: UiStatus.success, icon: HugeIcons.strokeRoundedTick02),\n])",
        api: const [
          ApiRow('items', 'List<UiTimelineItem>', 'title, description, meta, tone, icon.'),
          ApiRow('ringColor', 'Color?', 'Ring around the markers.', def: 'surface'),
        ],
      );
}

class _CodeBlockSection extends StatelessWidget {
  const _CodeBlockSection();

  @override
  Widget build(BuildContext context) => const DocSection(
        name: 'Code block',
        widget: 'UiCodeBlock',
        summary: 'A monospace code panel with a language label and a Copy button. Lines keep their breaks and indentation and scroll sideways instead of wrapping. After copying the button says "Copied" for a moment, or "Copy failed" if the clipboard refused; both are announced.',
        demo: UiCodeBlock(language: 'dart', code: "UiButton(\n  label: 'Save',\n  onPressed: save,\n) // a long trailing comment that scrolls sideways rather than wrapping onto the next line"),
        code: "UiCodeBlock(language: 'dart', code: source)",
        api: [
          ApiRow('code', 'String', 'The code; tabs become two spaces.'),
          ApiRow('language', 'String', 'Label in the bar.', def: "'text'"),
          ApiRow('radius', 'bool', 'Rounded corners.', def: 'true'),
        ],
      );
}

class _LinkKbdSection extends StatefulWidget {
  const _LinkKbdSection();
  @override
  State<_LinkKbdSection> createState() => _LinkKbdSectionState();
}

class _LinkKbdSectionState extends State<_LinkKbdSection> {
  String? _opened;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return DocSection(
      name: 'Link & kbd',
      widget: 'UiLink · UiKbd',
      summary: 'UiLink is themed link text, underlined at rest so it never relies on colour alone, in primary, muted or plain tone. The app opens the address in onTap; href is reported to accessibility services, and external adds an arrow and tells screen readers it leaves the app. UiKbd is a key-cap hint sized from the surrounding text.',
      demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
        Wrap(spacing: t.space4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          UiLink('Read the docs', href: 'https://example.com/docs', onTap: () => setState(() => _opened = 'docs')),
          UiLink('Muted', tone: UiLinkTone.muted, onTap: () => setState(() => _opened = 'muted')),
          UiLink('GitHub', external: true, href: 'https://github.com', onTap: () => setState(() => _opened = 'GitHub')),
        ]),
        Row(spacing: t.space1, children: const [UiKbd('Ctrl'), UiKbd('Shift'), UiKbd('P'), SizedBox(width: 8), UiText('opens the command palette', variant: UiTextVariant.caption)]),
        UiText(_opened == null ? 'Tap a link.' : 'Would open: $_opened', variant: UiTextVariant.caption),
      ]),
      code: "UiLink('Docs', href: url, onTap: () => launchUrl(Uri.parse(url)))\nUiLink('GitHub', external: true, onTap: openGitHub)\nUiKbd('Ctrl')",
      api: const [
        ApiRow('UiLink(label)', 'String', 'Link text.'),
        ApiRow('onTap', 'VoidCallback?', 'Open the address.'),
        ApiRow('href', 'String?', 'Reported to accessibility services.'),
        ApiRow('external', 'bool', 'Arrow marker; says it leaves the app.', def: 'false'),
        ApiRow('tone', 'UiLinkTone', 'primary, muted, plain.', def: 'primary'),
        ApiRow('UiKbd(key)', 'String', 'Key text; semanticLabel for symbols.'),
      ],
    );
  }
}

class _ProgressCircleSection extends StatefulWidget {
  const _ProgressCircleSection();
  @override
  State<_ProgressCircleSection> createState() => _ProgressCircleSectionState();
}

class _ProgressCircleSectionState extends State<_ProgressCircleSection> {
  double _v = 60;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return DocSection(
      name: 'Progress circle',
      widget: 'UiProgressCircle',
      summary: 'The round sibling of the progress bar: determinate when value (0–100) is set, otherwise a turning arc that keeps moving, slower, under reduced motion. showValue writes the percentage in the middle (size 40 or more). Announced with its label and percentage.',
      demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
        Row(spacing: t.space4, children: [
          UiProgressCircle(value: _v, size: 56, showValue: true, label: 'Upload'),
          UiProgressCircle(value: _v, tone: UiStatus.success),
          UiProgressCircle(value: _v, tone: UiStatus.danger, size: 28, strokeWidth: 3),
          const UiProgressCircle(label: 'Loading'),
        ]),
        Row(spacing: t.space2, children: [
          UiButton(label: '−10', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() => _v = (_v - 10).clamp(0, 100))),
          UiButton(label: '+10', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() => _v = (_v + 10).clamp(0, 100))),
        ]),
      ]),
      code: "UiProgressCircle(value: 60, size: 56, showValue: true, label: 'Upload')\nUiProgressCircle() // indeterminate",
      api: const [
        ApiRow('value', 'double?', '0–100; null for indeterminate.'),
        ApiRow('size / strokeWidth', 'double', 'Diameter and ring width.', def: '40 / 4'),
        ApiRow('tone', 'UiStatus', 'Arc colour.', def: 'primary'),
        ApiRow('showValue', 'bool', 'Percentage in the middle.', def: 'false'),
        ApiRow('label', 'String', 'Accessible name.', def: "'Progress'"),
      ],
    );
  }
}

class _MeterSection extends StatefulWidget {
  const _MeterSection();
  @override
  State<_MeterSection> createState() => _MeterSectionState();
}

class _MeterSectionState extends State<_MeterSection> {
  double _kb = 520;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return DocSection(
      name: 'Meter',
      widget: 'UiMeter',
      summary: 'A measurement against a budget, such as file size against a limit. Unlike a progress bar it is not a task finishing: it turns warning past warnAt and danger past dangerAt (default max), and says so in its text ("Getting large", "Over the limit"), so colour is never the only signal. A tick marks warnAt.',
      demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
        UiMeter(value: _kb, max: 800, warnAt: 600, label: 'Bundle size', valueText: '${_kb.round()} KB of 800 KB'),
        Row(spacing: t.space2, children: [
          UiButton(label: '−100 KB', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() => _kb = (_kb - 100).clamp(0, 1000))),
          UiButton(label: '+100 KB', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() => _kb = (_kb + 100).clamp(0, 1000))),
        ]),
      ]),
      code: "UiMeter(value: 520, max: 800, warnAt: 600, label: 'Bundle size', valueText: '520 KB of 800 KB')",
      api: const [
        ApiRow('value', 'double', 'The measurement.'),
        ApiRow('max', 'double', 'The budget.', def: '100'),
        ApiRow('warnAt / dangerAt', 'double?', 'Thresholds; danger defaults to max.'),
        ApiRow('label', 'String?', 'Name, shown and announced.'),
        ApiRow('valueText', 'String?', 'How the value is written.', def: "'value / max'"),
        ApiRow('warnText / dangerText', 'String', 'Status words.', def: "'Getting large' / 'Over the limit'"),
      ],
    );
  }
}

class _EmptyStateSection extends StatelessWidget {
  const _EmptyStateSection();

  @override
  Widget build(BuildContext context) => DocSection(
        name: 'Empty state',
        widget: 'UiEmptyState',
        summary: 'A centred placeholder for empty content: an optional icon, a heading (default "Nothing here yet"), a description and actions that wrap.',
        demo: UiEmptyState(
          icon: const UiIcon(HugeIcons.strokeRoundedInbox),
          heading: 'No messages',
          description: 'When someone writes to you, the conversation shows up here.',
          actions: [
            UiButton(label: 'New message', size: UiSize.sm, onPressed: () {}),
            UiButton(label: 'Refresh', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () {}),
          ],
        ),
        code: "UiEmptyState(\n  icon: UiIcon(HugeIcons.strokeRoundedInbox),\n  heading: 'No messages',\n  description: 'When someone writes to you, it shows up here.',\n  actions: [UiButton(label: 'New message', onPressed: compose)],\n)",
        api: const [
          ApiRow('heading', 'String', 'Title.', def: "'Nothing here yet'"),
          ApiRow('description', 'String?', 'Muted text under it.'),
          ApiRow('icon', 'Widget?', '32px, muted.'),
          ApiRow('actions', 'List<Widget>', 'Buttons below.'),
        ],
      );
}

class _ResultSection extends StatefulWidget {
  const _ResultSection();
  @override
  State<_ResultSection> createState() => _ResultSectionState();
}

class _ResultSectionState extends State<_ResultSection> {
  UiResultStatus _status = UiResultStatus.success;

  static const _copy = {
    UiResultStatus.success: ('Payment received', 'We emailed the receipt to you.'),
    UiResultStatus.error: ('Payment failed', 'Your card was declined. Nothing was charged.'),
    UiResultStatus.info: ('Check your inbox', 'We sent a sign-in link.'),
    UiResultStatus.warning: ('Almost out of space', 'Delete old files to keep uploading.'),
    UiResultStatus.notFound: ('Page not found', 'The page moved or never existed.'),
    UiResultStatus.serverError: ('Something went wrong', 'Try again in a minute.'),
  };

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final (title, sub) = _copy[_status]!;
    return DocSection(
      name: 'Result',
      widget: 'UiResult',
      summary: 'A full-page outcome: success, error, info, warning, not found (the web 404) or server error (500). A tinted glyph in a circle, a title announced as a heading, a subtitle and actions.',
      demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
        Wrap(spacing: t.space2, runSpacing: t.space2, children: [
          for (final s in UiResultStatus.values)
            UiButton(label: s.name, size: UiSize.sm, variant: s == _status ? UiButtonVariant.primary : UiButtonVariant.outline, onPressed: () => setState(() => _status = s)),
        ]),
        UiResult(status: _status, title: title, subtitle: sub, actions: [UiButton(label: 'Continue', size: UiSize.sm, onPressed: () {})]),
      ]),
      code: "UiResult(\n  status: UiResultStatus.notFound,\n  title: 'Page not found',\n  subtitle: 'The page moved or never existed.',\n  actions: [UiButton(label: 'Go home', onPressed: goHome)],\n)",
      api: const [
        ApiRow('status', 'UiResultStatus', 'success, error, info, warning, notFound, serverError.', def: 'info'),
        ApiRow('title', 'String', 'Heading.'),
        ApiRow('subtitle', 'String?', 'Muted text under it.'),
        ApiRow('actions', 'List<Widget>', 'Buttons below.'),
      ],
    );
  }
}
