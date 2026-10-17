import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

class NavigationPage extends StatefulWidget {
  const NavigationPage({super.key});

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  int _tab = 0;
  int _iconTab = 0;
  String _side = 'inbox';
  String _bottom = 'home';
  String? _crumb;
  int _page = 4;
  int _step = 1;
  String? _menu;
  final ScrollController _anchorScroll = ScrollController();
  final List<GlobalKey> _anchorKeys = [for (var i = 0; i < 4; i++) GlobalKey()];

  @override
  void dispose() {
    _anchorScroll.dispose();
    super.dispose();
  }

  static const _menus = [
    UiMenubarMenu(label: 'File', items: [
      UiMenubarItem(label: 'New file', value: 'new'),
      UiMenubarItem(label: 'Open', value: 'open'),
      UiMenubarItem(label: 'Save', value: 'save', disabled: true),
      UiMenubarItem(label: 'Export as PDF', value: 'export'),
    ]),
    UiMenubarMenu(label: 'Edit', items: [UiMenubarItem(label: 'Undo', value: 'undo'), UiMenubarItem(label: 'Redo', value: 'redo')]),
    UiMenubarMenu(label: 'View', items: [UiMenubarItem(label: 'Zoom in', value: 'zoom-in'), UiMenubarItem(label: 'Zoom out', value: 'zoom-out')]),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final sections = ['Overview', 'Install', 'Usage', 'FAQ'];
    return DocPage(
      eyebrow: 'Components',
      title: 'Navigation',
      lead: 'Move between views: app bar, tabs, side nav, bottom nav, breadcrumbs, pagination, stepper, menubar and anchor nav.',
      children: [
        DocSection(
          name: 'Navbar',
          widget: 'UiNavbar',
          summary: 'The top bar (an app bar): brand on the left, links in the middle, actions on the right, 52px tall. Narrower than breakpoint (768) it wraps instead of truncating: brand and actions stay on the first row and the links move underneath, scrolling sideways if they still do not fit. glass gives a frosted surface; with a label it is a navigation landmark. safeArea pads it under the status bar when drawn edge to edge.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            UiNavbar(
              label: 'Main',
              brand: const Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: [UiIcon(HugeIcons.strokeRoundedChartLineData01), Text('Acme')]),
              links: [for (final l in ['Docs', 'Pricing', 'Blog', 'Changelog']) UiButton(label: l, variant: UiButtonVariant.ghost, size: UiSize.sm, onPressed: () {})],
              actions: [
                UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedSearch01), label: 'Search', size: UiSize.sm, onPressed: () {}),
                UiButton(label: 'Sign in', size: UiSize.sm, onPressed: () {}),
              ],
            ),
            UiNavbar(
              glass: true,
              brand: const Text('Glass'),
              actions: [UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedMenu01), label: 'Menu', size: UiSize.sm, onPressed: () {})],
            ),
          ]),
          code: "UiNavbar(\n  label: 'Main',\n  brand: Text('Acme'),\n  links: [UiButton(label: 'Docs', variant: UiButtonVariant.ghost, onPressed: openDocs)],\n  actions: [UiButton(label: 'Sign in', onPressed: signIn)],\n)",
          api: const [
            ApiRow('brand', 'Widget?', 'Logo and name; text is bold with tight tracking.'),
            ApiRow('links / actions', 'List<Widget>', 'Middle and right slots.'),
            ApiRow('label', 'String?', 'Makes it a navigation landmark with this name.'),
            ApiRow('glass / radius', 'bool?', 'Default to UiConfig.'),
            ApiRow('breakpoint', 'double', 'Width below which the links wrap to their own row.', def: '768'),
            ApiRow('safeArea', 'bool', 'Pad by the status bar height.', def: 'false'),
          ],
        ),
        DocSection(
          name: 'Tabs',
          widget: 'UiTabs · UiTab',
          summary: 'Tabs over panels. One tab stop; Left/Right select the next tab (wrapping, skipping disabled ones), Home/End jump to the ends. The strip scrolls sideways when the tabs do not fit and keeps the selected one in view. Inactive panels stay mounted, so their state survives, but take no space and are hidden from screen readers. A tab may carry a Hugeicons icon; with iconOnly the label stays its accessible name, and an all-icon strip shares the width evenly.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space4, children: [
            UiTabs(
              selectedIndex: _tab,
              onChanged: (i) => setState(() => _tab = i),
              tabs: const [
                UiTab(label: 'Overview', child: UiText('Everything at a glance.')),
                UiTab(label: 'Activity', icon: HugeIcons.strokeRoundedChartLineData01, child: UiText('Recent changes.')),
                UiTab(label: 'Billing', disabled: true, child: SizedBox()),
                UiTab(label: 'Audit log', child: UiText('Who did what, and when.')),
                UiTab(label: 'Settings', child: UiText('Preferences.')),
              ],
            ),
            UiTabs(
              label: 'Sections',
              selectedIndex: _iconTab,
              onChanged: (i) => setState(() => _iconTab = i),
              tabs: const [
                UiTab(label: 'Home', icon: HugeIcons.strokeRoundedHome01, iconOnly: true, child: UiText('Home panel')),
                UiTab(label: 'Search', icon: HugeIcons.strokeRoundedSearch01, iconOnly: true, child: UiText('Search panel')),
                UiTab(label: 'Settings', icon: HugeIcons.strokeRoundedSettings01, iconOnly: true, child: UiText('Settings panel')),
              ],
            ),
          ]),
          code: "UiTabs(\n  selectedIndex: tab,\n  onChanged: (i) => setState(() => tab = i),\n  tabs: [\n    UiTab(label: 'Overview', child: OverviewPanel()),\n    UiTab(label: 'Billing', disabled: true, child: BillingPanel()),\n  ],\n)",
          api: const [
            ApiRow('tabs', 'List<UiTab>', 'label, child, icon, iconOnly, disabled.'),
            ApiRow('selectedIndex', 'int', 'The open tab.', def: '0'),
            ApiRow('onChanged', 'ValueChanged<int>?', 'A new tab was chosen.'),
            ApiRow('label', 'String', 'Accessible name of the strip.', def: "'Tabs'"),
          ],
        ),
        DocSection(
          name: 'Side nav',
          widget: 'UiSideNav',
          summary: 'Vertical grouped navigation: an app sidebar, or the content of a drawer on phones. active is the selected value; a tap reports the item through onNavigate (and its value through onChanged), so map it to a route yourself. The active item is tinted, marked with a primary bar and announced as selected. Items may have a Hugeicons icon and a badge; on touch screens every row is 48dp tall.',
          demo: SizedBox(
            width: 280,
            child: UiSideNav(
              active: _side,
              onChanged: (v) => setState(() => _side = v),
              groups: const [
                UiSideNavGroup(label: 'Workspace', items: [
                  UiSideNavItem(label: 'Inbox', value: 'inbox', icon: HugeIcons.strokeRoundedInbox, badge: '12'),
                  UiSideNavItem(label: 'Calendar', value: 'calendar', icon: HugeIcons.strokeRoundedCalendar01),
                  UiSideNavItem(label: 'Archive', value: 'archive', icon: HugeIcons.strokeRoundedFolder01, disabled: true),
                ]),
                UiSideNavGroup(label: 'Account', items: [UiSideNavItem(label: 'Settings', value: 'settings', icon: HugeIcons.strokeRoundedSettings01)]),
              ],
            ),
          ),
          code: "UiSideNav(\n  active: route,\n  onNavigate: (item) => go(item.value),\n  groups: [\n    UiSideNavGroup(label: 'Workspace', items: [\n      UiSideNavItem(label: 'Inbox', value: 'inbox', icon: HugeIcons.strokeRoundedInbox, badge: '12'),\n    ]),\n  ],\n)",
          api: const [
            ApiRow('groups', 'List<UiSideNavGroup>', 'Optional label + items (label, value, icon, badge, disabled).'),
            ApiRow('active', 'String?', 'Value of the current item.'),
            ApiRow('onNavigate / onChanged', 'ValueChanged', 'The tapped item / its value.'),
            ApiRow('label', 'String', 'Landmark name.', def: "'Sidebar'"),
            ApiRow('scrollable', 'bool', 'Wrap in a scroll view (for a drawer).', def: 'false'),
          ],
        ),
        DocSection(
          name: 'Breadcrumbs',
          widget: 'UiBreadcrumbs',
          summary: 'The trail to the current page, in a navigation landmark named Breadcrumb. The last item is the current page (plain text, announced as selected); earlier items are links reported through onNavigate. Crumbs are at least 24px and padded to 48dp on touch; long labels are cut with an ellipsis. When the trail does not fit on one line, the middle collapses into a "more" button that shows the full path.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
            UiBreadcrumbs(
              onNavigate: (c) => setState(() => _crumb = c.label),
              items: const [
                UiBreadcrumb(label: 'Home'),
                UiBreadcrumb(label: 'Projects'),
                UiBreadcrumb(label: 'Website redesign'),
                UiBreadcrumb(label: 'Design system'),
                UiBreadcrumb(label: 'Buttons'),
              ],
            ),
            UiText(_crumb == null ? 'Tap a crumb.' : 'Navigate to: $_crumb', variant: UiTextVariant.caption),
          ]),
          code: "UiBreadcrumbs(\n  items: [UiBreadcrumb(label: 'Home', value: '/'), UiBreadcrumb(label: 'Settings')],\n  onNavigate: (crumb) => go(crumb.value),\n)",
          api: const [
            ApiRow('items', 'List<UiBreadcrumb>', 'label and an optional value; the last is the current page.'),
            ApiRow('onNavigate', 'ValueChanged<UiBreadcrumb>?', 'An earlier crumb was tapped.'),
            ApiRow('separator', 'String', 'Text between crumbs.', def: "'/'"),
            ApiRow('collapse', 'bool', 'Collapse the middle when it does not fit.', def: 'true'),
          ],
        ),
        DocSection(
          name: 'Pagination',
          widget: 'UiPagination',
          summary: 'Previous/next around page numbers. Always shows the first and last page and siblings either side of the current one; gaps become an ellipsis. The current page is announced as selected. It fits itself to its width: fewer siblings first, then a compact "Page 4 of 12" between the arrows on a very narrow screen.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
            UiPagination(page: _page, total: 12, onChanged: (p) => setState(() => _page = p)),
            SizedBox(width: 220, child: UiPagination(page: _page, total: 12, onChanged: (p) => setState(() => _page = p))),
          ]),
          code: 'UiPagination(page: page, total: 12, onChanged: (p) => setState(() => page = p))',
          api: const [
            ApiRow('page', 'int', '1-based current page.'),
            ApiRow('total', 'int', 'Number of pages.'),
            ApiRow('onChanged', 'ValueChanged<int>?', 'The new page, clamped to 1..total.'),
            ApiRow('siblings', 'int', 'Pages shown either side of the current one.', def: '1'),
            ApiRow('label', 'String', 'Landmark name.', def: "'Pagination'"),
          ],
        ),
        DocSection(
          name: 'Stepper',
          widget: 'UiStepper',
          summary: 'Progress through ordered steps; display only. Steps before active are done (a filled marker whose check draws itself in), active is current. Horizontal when the labels fit, otherwise vertical, so no label is hidden on a phone. Each step is read as "Step 2 of 4, Shipping, current". A vertical stepper shows a body under each step (details, history, actions); the dots variant is a compact strip of dots: finished and current steps in the tone (the current one ringed), steps not reached in the text colour. tone: success colours finished steps green.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space4, children: [
            UiStepper(active: _step, steps: const [UiStep(label: 'Cart'), UiStep(label: 'Pay'), UiStep(label: 'Done')]),
            UiStepper(active: _step, steps: const [
              UiStep(label: 'Account', description: 'Email and password'),
              UiStep(label: 'Shipping', description: 'Where it goes'),
              UiStep(label: 'Payment'),
              UiStep(label: 'Review'),
            ]),
            UiStepper(
              active: _step,
              axis: Axis.vertical,
              tone: UiStepperTone.success,
              label: 'Checkout',
              steps: const [UiStep(label: 'Cart'), UiStep(label: 'Pay'), UiStep(label: 'Done')],
              body: (context, i, state) => Text(switch (state) { UiStepState.done => 'Done', UiStepState.active => 'In progress', UiStepState.todo => 'Not started' },
                  style: context.uiText.caption),
            ),
            UiStepper(active: _step, variant: UiStepperVariant.dots, tone: UiStepperTone.success, label: 'Checkout progress', steps: const [UiStep(label: 'Cart'), UiStep(label: 'Pay'), UiStep(label: 'Done')]),
            Row(spacing: t.space2, children: [
              UiButton(label: 'Back', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: _step > 0 ? () => setState(() => _step--) : null),
              UiButton(label: 'Next', size: UiSize.sm, onPressed: _step < 3 ? () => setState(() => _step++) : null),
            ]),
          ]),
          code: "UiStepper(active: 1, steps: [\n  UiStep(label: 'Account', description: 'Email and password'),\n  UiStep(label: 'Shipping'),\n  UiStep(label: 'Review'),\n])",
          api: const [
            ApiRow('steps', 'List<UiStep>', 'label and an optional description.'),
            ApiRow('active', 'int', 'Index of the current step.', def: '0'),
            ApiRow('axis', 'Axis?', 'Force a direction; by default horizontal when it fits.'),
            ApiRow('variant', 'UiStepperVariant', 'standard, or dots: small dots only, labels kept for screen readers.', def: 'standard'),
            ApiRow('tone', 'UiStepperTone', 'The colour of finished and current steps: primary or success.', def: 'primary'),
            ApiRow('body', 'Widget? Function(context, index, UiStepState)?', 'Content under each step in a vertical stepper; return null for none.'),
            ApiRow('label', 'String?', 'An accessible name for the list of steps.'),
          ],
        ),
        DocSection(
          name: 'Menubar',
          widget: 'UiMenubar',
          summary: 'An application menu bar with dropdowns, one open at a time. On a phone (narrower than breakpoint) it becomes a single overflow button for the app bar, opening one panel with every menu as a titled group. Keyboard: Left/Right move between top items (and switch the open menu), Down opens one and focuses its first item; inside a menu Up/Down, Home and End move, Escape closes it and returns focus to its top item, Tab closes it. Panels flip or shift to stay on screen.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            Row(children: [
              const Expanded(child: UiText('Overflow (phone)', variant: UiTextVariant.caption)),
              UiMenubar(menus: _menus, onSelect: (i) => setState(() => _menu = i.label)),
            ]),
            Align(alignment: Alignment.centerLeft, child: UiMenubar(menus: _menus, breakpoint: 0, onSelect: (i) => setState(() => _menu = i.label))),
            UiText(_menu == null ? 'Choose a command.' : 'Chose: $_menu', variant: UiTextVariant.caption),
          ]),
          code: "UiMenubar(\n  menus: [\n    UiMenubarMenu(label: 'File', items: [UiMenubarItem(label: 'New file', value: 'new')]),\n  ],\n  onSelect: (item) => run(item.value),\n)",
          api: const [
            ApiRow('menus', 'List<UiMenubarMenu>', 'label + items (label, value, disabled).'),
            ApiRow('onSelect', 'ValueChanged<UiMenubarItem>?', 'A command was chosen.'),
            ApiRow('breakpoint', 'double', 'Width below which it collapses to an overflow button.', def: '600'),
            ApiRow('overflowLabel', 'String', 'Accessible name of the overflow button.', def: "'Menu'"),
          ],
        ),
        DocSection(
          name: 'Bottom nav',
          widget: 'UiBottomNav',
          summary: 'The mobile bottom bar: equal-width destinations with an icon over a short label, the active one in the primary colour. A set of buttons, not tabs: the active one is announced as selected, and a badge is read after the label. It adds the bottom safe area under its 56px row; place it at the bottom of your screen.',
          demo: UiBottomNav(
            active: _bottom,
            onChanged: (v) => setState(() => _bottom = v),
            safeArea: false,
            items: const [
              UiBottomNavItem(label: 'Home', value: 'home', icon: HugeIcons.strokeRoundedHome01),
              UiBottomNavItem(label: 'Search', value: 'search', icon: HugeIcons.strokeRoundedSearch01),
              UiBottomNavItem(label: 'Alerts', value: 'alerts', icon: HugeIcons.strokeRoundedNotification01, badge: '3'),
              UiBottomNavItem(label: 'Profile', value: 'me', icon: HugeIcons.strokeRoundedUserCircle),
            ],
          ),
          code: "UiBottomNav(\n  active: tab,\n  onChanged: (v) => setState(() => tab = v),\n  items: [\n    UiBottomNavItem(label: 'Home', value: 'home', icon: HugeIcons.strokeRoundedHome01),\n    UiBottomNavItem(label: 'Alerts', value: 'alerts', icon: HugeIcons.strokeRoundedNotification01, badge: '3'),\n  ],\n)",
          api: const [
            ApiRow('items', 'List<UiBottomNavItem>', 'label, value, icon, badge.'),
            ApiRow('active', 'String?', 'Value of the current item.'),
            ApiRow('onChanged', 'ValueChanged<String>?', 'An item was tapped.'),
            ApiRow('label', 'String?', 'Landmark name; set it when a screen has two navigations.'),
            ApiRow('glass / radius', 'bool?', 'Default to UiConfig.'),
            ApiRow('iconSize', 'double', 'Icon size.', def: '22'),
            ApiRow('safeArea', 'bool', 'Pad by the system navigation bar.', def: 'true'),
          ],
        ),
        DocSection(
          name: 'Anchor nav',
          widget: 'UiAnchorNav',
          summary: 'A scrollspy for a long scroll view: highlights the section being read and scrolls to a section when its link is tapped. Pass the scroll view\'s controller and the sections (each with a GlobalKey placed on the section). A section counts as being read once its top passes 35% of the way down, below a header of offset px. Axis.horizontal makes a scrolling strip for the top of a phone screen. Scroll the box below.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            UiAnchorNav(
              controller: _anchorScroll,
              axis: Axis.horizontal,
              items: [for (var i = 0; i < sections.length; i++) UiAnchorItem(key: _anchorKeys[i], label: sections[i])],
            ),
            SizedBox(
              height: 260,
              child: SingleChildScrollView(
                controller: _anchorScroll,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var i = 0; i < sections.length; i++)
                    Padding(
                      key: _anchorKeys[i],
                      padding: EdgeInsets.symmetric(vertical: t.space4),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
                        UiText(sections[i], variant: UiTextVariant.h4, heading: false),
                        for (var p = 0; p < 3; p++) const UiText('Body text of this section, long enough to scroll past and watch the highlight follow.', variant: UiTextVariant.caption),
                      ]),
                    ),
                ]),
              ),
            ),
          ]),
          code: "final scroll = ScrollController();\nfinal intro = GlobalKey(), usage = GlobalKey();\n\nUiAnchorNav(controller: scroll, items: [\n  UiAnchorItem(key: intro, label: 'Intro'),\n  UiAnchorItem(key: usage, label: 'Usage'),\n])\nSingleChildScrollView(controller: scroll, child: Column(children: [\n  IntroSection(key: intro), UsageSection(key: usage),\n]))",
          api: const [
            ApiRow('items', 'List<UiAnchorItem>', 'key (on the section) and label.'),
            ApiRow('controller', 'ScrollController', 'The scroll view to follow.'),
            ApiRow('offset', 'double', 'Height of a header covering the top.', def: '0'),
            ApiRow('axis', 'Axis', 'vertical list or horizontal strip.', def: 'vertical'),
            ApiRow('label', 'String', 'Landmark name.', def: "'On this page'"),
          ],
        ),
      ],
    );
  }
}
