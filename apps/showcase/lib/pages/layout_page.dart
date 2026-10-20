import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

/// A labelled cell for the layout demos.
class _Cell extends StatelessWidget {
  const _Cell(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Container(
      padding: EdgeInsets.all(t.space2),
      decoration: BoxDecoration(color: t.surfaceRaised, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radiusSm)),
      child: UiText(text, variant: UiTextVariant.caption),
    );
  }
}

class LayoutPage extends StatefulWidget {
  const LayoutPage({super.key});

  @override
  State<LayoutPage> createState() => _LayoutPageState();
}

class _LayoutPageState extends State<LayoutPage> {
  double _minCol = 100;
  bool _sectionsOpen = true;
  double _split = 40;
  double _panel = 120;
  bool _drawer = false;
  String _nav = 'Home';

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return DocPage(
      eyebrow: 'Layout',
      title: 'Layout & grid',
      lead: 'Structural primitives: grid, stack, spacer, container, aspect ratio, scroll area, splitter, resize handle, panel section and the sidebar app shell.',
      children: [
        DocSection(
          name: 'Floating panel',
          widget: 'UiFloatingPanel',
          summary: 'A raised surface floating over the bottom (or top) of a Stack: the details card over a map. Put it in the Stack directly. Non-modal: it takes no focus and only its own box takes touches, so what is around it stays usable and draggable. It sits 16px in from the edges plus the safe-area insets, up to 480 wide and centred, so it fits a 390px phone with a 16px gutter. With semanticLabel it is a named container.',
          demo: SizedBox(
            height: 260,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(t.radius),
              child: Stack(children: [
                Positioned.fill(child: ColoredBox(color: t.surfaceSubtle, child: Center(child: UiText('The map', variant: UiTextVariant.caption)))),
                UiFloatingPanel(
                  semanticLabel: 'Nurse',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, spacing: t.space1, children: const [
                    UiText('Aminath Hassan, RN', variant: UiTextVariant.label),
                    UiText('12 min away · Home visits', variant: UiTextVariant.caption),
                  ]),
                ),
              ]),
            ),
          ),
          code: '''Stack(children: [
  UiMap(...),
  UiFloatingPanel(semanticLabel: 'Nurse', child: NurseCard()),
])''',
          api: const [
            ApiRow('child', 'Widget', 'The content.'),
            ApiRow('placement', 'UiFloatingPanelPlacement', 'bottom or top of the Stack.', def: 'bottom'),
            ApiRow('semanticLabel', 'String?', 'Names it for screen readers.'),
            ApiRow('maxWidth', 'double', 'Its widest.', def: '480'),
            ApiRow('glass / radius', 'bool?', 'Default to UiConfig.'),
          ],
        ),
        DocSection(
          name: 'Grid',
          widget: 'UiGrid',
          summary: 'Equal columns with a token gap: a fixed count (columns), or responsive with minColumnWidth, which fits as many columns of at least that width as there is room for (CSS auto-fit: a short last row of items widens to fill). Cells in a row share the row\'s height.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            UiGrid(minColumnWidth: _minCol, gap: 2, children: [for (var i = 1; i <= 6; i++) _Cell(i == 2 ? 'Cell $i\nis taller' : 'Cell $i')]),
            Wrap(spacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              for (final w in [80.0, 100.0, 140.0])
                UiButton(label: 'min ${w.round()}', size: UiSize.sm, variant: _minCol == w ? UiButtonVariant.primary : UiButtonVariant.outline, onPressed: () => setState(() => _minCol = w)),
            ]),
            UiGrid(columns: 4, gap: 1, children: [for (var i = 1; i <= 4; i++) _Cell('1/4')]),
          ]),
          code: 'UiGrid(minColumnWidth: 100, gap: 2, children: cells)\nUiGrid(columns: 4, gap: 1, children: cells)',
          api: const [
            ApiRow('columns', 'int', 'Fixed column count.', def: '12'),
            ApiRow('minColumnWidth', 'double?', 'Responsive: the narrowest a column may be. Overrides columns.'),
            ApiRow('gap', 'int', 'Spacing step: 0, 1, 2, 3, 4, 6, 8, 12, 20 (4 to 80 px).', def: '4'),
            ApiRow('collapseEmptyColumns', 'bool', 'auto-fit (true) or auto-fill (false) with minColumnWidth.', def: 'true'),
          ],
        ),
        DocSection(
          name: 'Stack & spacer',
          widget: 'UiStack · UiSpacer',
          summary: 'UiStack is a row or column with a token gap, cross-axis align and main-axis justify; wrap flows a row onto more lines. A stretched row is as tall as its tallest child. UiSpacer takes the free space in a row or column, pushing its neighbours apart.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            const UiStack(direction: Axis.horizontal, gap: 2, children: [_Cell('Logo'), UiSpacer(), _Cell('Sign in'), _Cell('Menu')]),
            const UiStack(direction: Axis.horizontal, wrap: true, gap: 2, children: [_Cell('Design'), _Cell('Build'), _Cell('Ship'), _Cell('Measure'), _Cell('Learn'), _Cell('Repeat')]),
            const UiStack(gap: 1, align: UiStackAlign.center, children: [_Cell('Centred'), _Cell('column')]),
          ]),
          code: 'UiStack(direction: Axis.horizontal, gap: 2, children: [\n  logo, const UiSpacer(), signIn, menu,\n])',
          api: const [
            ApiRow('direction', 'Axis', 'Row or column.', def: 'vertical'),
            ApiRow('gap', 'int', 'Spacing step.', def: '3'),
            ApiRow('align', 'UiStackAlign', 'start, center, end, stretch.', def: 'stretch'),
            ApiRow('justify', 'UiStackJustify', 'start, center, end, spaceBetween.', def: 'start'),
            ApiRow('wrap', 'bool', 'Flow onto more lines.', def: 'false'),
            ApiRow('UiSpacer.flex', 'int', 'Share of the free space.', def: '1'),
          ],
        ),
        DocSection(
          name: 'Container',
          widget: 'UiContainer',
          summary: 'Centres its child at a maximum width with 16px side padding: sm 640, md 860, lg 1100, xl 1320, full unlimited. On a phone it is simply the padded width.',
          demo: const UiContainer(size: UiContainerSize.sm, child: _Cell('Max 640 wide, centred')),
          code: 'UiContainer(size: UiContainerSize.md, child: page)',
          api: const [ApiRow('size', 'UiContainerSize', 'sm, md, lg, xl, full.', def: 'lg')],
        ),
        DocSection(
          name: 'Aspect ratio',
          widget: 'UiAspectRatio',
          summary: 'Holds its child at a width:height ratio. The child is stretched to fill and anything outside is clipped, so give images BoxFit.cover.',
          demo: UiAspectRatio(
            ratio: 16 / 9,
            borderRadius: BorderRadius.circular(t.radiusLg),
            child: DecoratedBox(decoration: BoxDecoration(gradient: t.gradientBrand.toGradient()), child: Center(child: UiText('16 : 9', variant: UiTextVariant.h3, color: t.primaryContrast))),
          ),
          code: 'UiAspectRatio(ratio: 16 / 9, child: Image(image: photo, fit: BoxFit.cover))',
          api: const [
            ApiRow('ratio', 'double', 'Width divided by height.', def: '16 / 9'),
            ApiRow('borderRadius', 'BorderRadius?', 'Clip to rounded corners.'),
          ],
        ),
        DocSection(
          name: 'Scroll area',
          widget: 'UiScrollArea',
          summary: 'A scroll box with a thin themed scrollbar and a max height. It scrolls on the chosen axis and clips the other; shorter content hugs.',
          demo: UiScrollArea(
            maxHeight: 140,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 1; i <= 12; i++) Padding(padding: EdgeInsets.symmetric(vertical: t.space1), child: UiText('Row $i')),
            ]),
          ),
          code: 'UiScrollArea(maxHeight: 140, axis: UiScrollAxis.y, child: list)',
          api: const [
            ApiRow('maxHeight', 'double', 'Height before it scrolls.', def: '240'),
            ApiRow('axis', 'UiScrollAxis', 'y, x or both.', def: 'y'),
            ApiRow('controller', 'ScrollController?', 'The main axis controller.'),
          ],
        ),
        DocSection(
          name: 'Splitter',
          widget: 'UiSplitter',
          summary: 'Two panes with a draggable divider, for tablets and wide layouts. The first pane stays between 10% and 90%. The divider\'s grab area is 20dp either side on touch; it is a slider for TalkBack and the keyboard (Left/Up shrink the first pane by 2%, Right/Down grow it). Give it a bounded height.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            SizedBox(
              height: 160,
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
                child: UiSplitter(
                  ratio: _split,
                  onRatioChanged: (r) => setState(() => _split = r),
                  first: const Center(child: _Cell('Files')),
                  second: const Center(child: _Cell('Preview')),
                ),
              ),
            ),
            UiText('First pane: ${_split.round()}%', variant: UiTextVariant.caption),
          ]),
          code: 'UiSplitter(\n  ratio: split,\n  onRatioChanged: (r) => setState(() => split = r),\n  first: explorer,\n  second: viewer,\n)',
          api: const [
            ApiRow('first / second', 'Widget', 'The panes (start or top first).'),
            ApiRow('axis', 'Axis', 'horizontal: side by side; vertical: stacked.', def: 'horizontal'),
            ApiRow('ratio / onRatioChanged', 'double? / ValueChanged<double>?', 'The first pane\'s share, 10–90. Null keeps it inside.'),
            ApiRow('initialRatio', 'double', 'Starting share when uncontrolled.', def: '50'),
            ApiRow('label', 'String', 'The divider\'s accessible name.', def: "'Resize panes'"),
          ],
        ),
        DocSection(
          name: 'Resize handle',
          widget: 'UiResizeHandle',
          summary: 'A draggable edge that sets the size of the panel next to it. Put it on the panel\'s inner edge: a bottom panel\'s handle sits on its top, so dragging up grows it. Letting go near one of snaps settles on it; a double tap cycles the snaps. Keys: arrows by 16px (Shift 64), Home/End to min/max.',
          demo: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
            child: Column(children: [
              UiResizeHandle(size: _panel, min: 60, max: 240, snaps: const [80, 160], onChanged: (v) => setState(() => _panel = v)),
              SizedBox(height: _panel, child: Center(child: UiText('Panel: ${_panel.round()}px', variant: UiTextVariant.caption))),
            ]),
          ),
          code: 'UiResizeHandle(\n  size: height,\n  min: 60, max: 240, snaps: const [80, 160],\n  edge: UiResizeEdge.top,\n  onChanged: (v) => setState(() => height = v),\n)',
          api: const [
            ApiRow('size / onChanged', 'double / ValueChanged<double>', 'The panel size in px.'),
            ApiRow('min / max', 'double', 'Limits.', def: '0 / 10000'),
            ApiRow('snaps', 'List<double>', 'Sizes a release settles on.'),
            ApiRow('edge', 'UiResizeEdge', 'Where the handle sits on the panel.', def: 'top'),
            ApiRow('snapDistance', 'double', 'How near counts as a snap.', def: '28'),
            ApiRow('onResizeEnd', 'ValueChanged<double>?', 'After a drag, key or snap.'),
          ],
        ),
        DocSection(
          name: 'Panel section',
          widget: 'UiPanelSection',
          summary: 'A dense, collapsible titled group for inspector and settings panels. The heading is a button announced as expanded or collapsed; a collapsed body is not built. Header actions go in actions; collapsible false gives a fixed heading.',
          demo: Container(
            // Clip so a heading's hover fill and the section lines stay inside the rounded corners.
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
            child: Column(children: [
              UiPanelSection(
                title: 'Sections',
                badge: '4',
                open: _sectionsOpen,
                onOpenChanged: (v) => setState(() => _sectionsOpen = v),
                actions: [UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedAdd01), label: 'Add section', size: UiSize.sm, onPressed: () {})],
                child: const UiText('Hero, About, Gallery, RSVP'),
              ),
              const UiPanelSection(title: 'Theme colours', initiallyOpen: false, child: UiText('Primary, accent, surface')),
              const UiPanelSection(title: 'Layout', collapsible: false, divider: false, child: UiText('Always shown')),
            ]),
          ),
          code: "UiPanelSection(\n  title: 'Sections',\n  badge: '4',\n  actions: [addButton],\n  child: list,\n)",
          api: const [
            ApiRow('title', 'String', 'Heading, also the group\'s name.'),
            ApiRow('divider', 'bool', 'The line under the section; false on the last one in a bordered panel.', def: 'true'),
            ApiRow('open / onOpenChanged', 'bool? / ValueChanged<bool>?', 'Controlled open state; null keeps it inside.'),
            ApiRow('initiallyOpen', 'bool', 'Uncontrolled start.', def: 'true'),
            ApiRow('collapsible', 'bool', 'False shows a fixed heading.', def: 'true'),
            ApiRow('badge', 'String?', 'Small count after the title.'),
            ApiRow('actions', 'List<Widget>', 'Header controls.'),
          ],
        ),
        DocSection(
          name: 'Sidebar layout',
          widget: 'UiSidebarLayout',
          summary: 'An app shell: a sidebar beside the page under a top bar when there is room; at or below breakpoint the sidebar becomes a drawer opened by a built-in menu button over a dimmed backdrop. Tapping the backdrop, Escape and the system back gesture close it; while open the page behind is hidden from screen readers. Widening past the breakpoint closes it. The slide is instant under reduced motion.',
          demo: SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(t.radius),
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border.all(color: t.border)),
                child: UiSidebarLayout(
                  open: _drawer,
                  onOpenChanged: (v) => setState(() => _drawer = v),
                  sidebarWidth: 200,
                  header: UiText(_nav, variant: UiTextVariant.h5),
                  sidebar: ListView(padding: EdgeInsets.all(t.space2), children: [
                    for (final n in ['Home', 'Projects', 'Settings'])
                      UiButton(
                        label: n,
                        block: true,
                        variant: n == _nav ? UiButtonVariant.secondary : UiButtonVariant.ghost,
                        onPressed: () => setState(() {
                          _nav = n;
                          _drawer = false;
                        }),
                      ),
                  ]),
                  body: UiText('The $_nav page. Below 860px wide (this demo) the sidebar is a drawer.'),
                ),
              ),
            ),
          ),
          code: "UiSidebarLayout(\n  breakpoint: 860,\n  sidebar: nav,\n  header: const UiText('Title'),\n  body: page,\n)",
          api: const [
            ApiRow('sidebar / header / body', 'Widget', 'The navigation, the top-bar content and the page.'),
            ApiRow('breakpoint', 'double', 'Widest layout that still uses the drawer.', def: '860'),
            ApiRow('sidebarWidth', 'double', 'Sidebar width (drawer: at most 84%).', def: '248'),
            ApiRow('open / onOpenChanged', 'bool? / ValueChanged<bool>?', 'Drive the drawer (close it on navigation).'),
            ApiRow('padding', 'EdgeInsetsGeometry?', 'Around the page: 24, or 16 in drawer mode.'),
            ApiRow('scrollBody', 'bool', 'Wrap the body in a scroll view.', def: 'true'),
          ],
          callbacks: const [ApiRow('toggle() / close()', 'UiSidebarLayoutState', 'Through a GlobalKey.')],
        ),
      ],
    );
  }
}
